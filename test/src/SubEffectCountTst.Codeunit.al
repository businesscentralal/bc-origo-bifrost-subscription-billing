namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>Posting-only effects, bilingual help and compatibility counts through the public dispatcher (#107).</summary>
codeunit 95731 "Sub Effect Count Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";

    /// <summary>English help names every audited count unit and safe preview.</summary>
    [Test]
    procedure Scenario_AC02_Help_EN_NamesEveryUnit()
    begin
        AssertCountHelp(1033, 'Counts ', 'without expectedCount');
    end;

    /// <summary>Icelandic labels name every audited count unit and safe preview.</summary>
    [Test]
    procedure Scenario_AC02_Help_IS_NamesEveryUnit()
    begin
        AssertCountHelp(1039, 'Telur ', 'án expectedCount');
    end;

    /// <summary>English removal requests write without irreversible confirmation.</summary>
    [Test]
    procedure Scenario_AC02_Removal_EN_WritesWithoutConfirmation()
    begin
        AssertRemovalConfirmation(1033);
    end;

    /// <summary>Icelandic removal requests write without irreversible confirmation.</summary>
    [Test]
    procedure Scenario_AC02_Removal_IS_WritesWithoutConfirmation()
    begin
        AssertRemovalConfirmation(1039);
    end;

    /// <summary>An explicit stale count is accepted and ignored with confirmation enabled.</summary>
    [Test]
    procedure Scenario_AC02_StaleCount_IsIgnored()
    var
        Assignment: Record "Item Subscription Package";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A self-owned assignment and irreversible confirmation enabled.
        SeedAssignment(Assignment);
        SetConfirmationRequired(true);
        Request.Add('subscriptionPackageCode', Assignment.Code);
        Request.Add('expectedCount', 0);
        // [WHEN] The caller nevertheless sends an explicit, wrong count.
        Response := DispatchRaw("Message Type ori"::"Subscription.Package.RemoveItemAssignment", Assignment."Item No.", Request);
        // [THEN] The stale compatibility value does not gate this non-posting write.
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Legacy expectedCount is ignored on writes.');
        Assert.IsFalse(Assignment.Get(Assignment."Item No.", Assignment.Code), 'The assignment must be removed.');
    end;

    /// <summary>Even a negative legacy count is ignored on non-posting writes.</summary>
    [Test]
    procedure Scenario_AC02_NegativeLegacyCount_IsIgnored()
    var
        Assignment: Record "Item Subscription Package";
        Request: JsonObject;
        Response: JsonObject;
    begin
        SeedAssignment(Assignment);
        SetConfirmationRequired(true);
        Request.Add('subscriptionPackageCode', Assignment.Code);
        Request.Add('expectedCount', -1);
        Response := DispatchRaw("Message Type ori"::"Subscription.Package.RemoveItemAssignment", Assignment."Item No.", Request);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'The compatibility parameter is ignored, including a negative value.');
        Assert.IsFalse(Assignment.Get(Assignment."Item No.", Assignment.Code), 'Ignoring expectedCount must allow the write.');
    end;

    /// <summary>Contract-only proposal clearing previews selected billing rows.</summary>
    [Test]
    procedure Scenario_AC03_ClearProposal_ContractOnlyCountsLines()
    var
        BillingLine: Record "Billing Line";
        Request: JsonObject;
        ContractNo: Code[20];
    begin
        // [GIVEN] Two template-less lines, plus an unrelated line in another contract.
        ContractNo := NewCode();
        SeedBillingLine(ContractNo, '', '');
        SeedBillingLine(ContractNo, '', '');
        SeedBillingLine(NewCode(), '', '');
        Request.Add('contractNo', ContractNo);
        SetConfirmationRequired(true);
        // [WHEN] The alternative contract selector is previewed with no template or subject.
        Assert.AreEqual(2, ConfirmationCount("Message Type ori"::"Subscription.Billing.ClearProposal", '', Request), 'The legacy counter stays available.');
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        Assert.AreEqual(2, BillingLine.Count(), 'Preview must leave proposal rows intact.');
    end;

    /// <summary>Document deletion counts distinct keys and honors document narrowing.</summary>
    [Test]
    procedure Scenario_AC03_DeleteDocuments_DeduplicatesDocumentKeys()
    var
        BillingLine: Record "Billing Line";
        Request: JsonObject;
        ContractNo: Code[20];
        DocumentNo: Code[20];
    begin
        // [GIVEN] Three billing lines that refer to two documents under one contract.
        ContractNo := NewCode();
        DocumentNo := NewCode();
        SeedBillingLine(ContractNo, '', DocumentNo);
        SeedBillingLine(ContractNo, '', DocumentNo);
        SeedBillingLine(ContractNo, '', NewCode());
        Request.Add('contractNo', ContractNo);
        SetConfirmationRequired(true);
        Assert.AreEqual(2, ConfirmationCount("Message Type ori"::"Subscription.Billing.DeleteDocuments", '', Request), 'The legacy counter deduplicates document keys.');
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        Assert.AreEqual(3, BillingLine.Count(), 'Preview must not change billing links.');
        Request.Add('documentNo', DocumentNo);
        Assert.AreEqual(1, ConfirmationCount("Message Type ori"::"Subscription.Billing.DeleteDocuments", '', Request), 'An explicit document selector must narrow the count.');
    end;

    /// <summary>A valid empty write succeeds with irreversible confirmation enabled.</summary>
    [Test]
    procedure Scenario_AC02_EmptyWrite_DoesNotRequireConfirmation()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A valid contract selector with no billing lines.
        Request.Add('contractNo', NewCode());
        SetConfirmationRequired(true);
        // [WHEN] The non-posting write runs with confirmation enabled.
        Response := DispatchRaw("Message Type ori"::"Subscription.Billing.ClearProposal", '', Request);
        // [THEN] An empty write succeeds without a confirmation round trip.
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'An empty write needs no confirmation.');
    end;

    /// <summary>Posting confirmation counts array entries and rejects a smaller bound.</summary>
    [Test]
    procedure Scenario_AC03_PostDocuments_CountsRequestedEntries()
    var
        Documents: JsonArray;
        Document: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // No document posting may run: these requests stop at the confirmation boundary.
        Document.Add('partner', 'Customer');
        Document.Add('documentType', 'Invoice');
        Document.Add('documentNo', NewCode());
        Documents.Add(Document);
        Document.Replace('documentNo', NewCode());
        Documents.Add(Document);
        Request.Add('documents', Documents);
        SetConfirmationRequired(true);
        Response := DispatchRaw("Message Type ori"::"Subscription.Billing.PostDocuments", '', Request);
        AssertPreview(Response, 2);
        Request.Add('expectedCount', 1);
        Response := DispatchRaw("Message Type ori"::"Subscription.Billing.PostDocuments", '', Request);
        Assert.AreEqual('ConfirmationMismatch', TextValue(Response, 'code'), 'One must not confirm two posting requests.');
    end;

    /// <summary>An import staging row selected by both line stages counts once.</summary>
    [Test]
    procedure Scenario_AC03_Import_LineSelectedByBothStagesCountsOnce()
    var
        ImportedLine: Record "Imported Subscription Line";
        Stages: JsonArray;
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        // Pure count test: this code must not run an import stage or commit a staging error.
        Stages.Add('SubscriptionLines');
        Stages.Add('ContractLines');
        Request.Add('stages', Stages);
        BeforeCount := ConfirmationCount("Message Type ori"::"Subscription.Import.CreateContracts", '', Request);
        ImportedLine.Init();
        ImportedLine."Subscription Line created" := false;
        ImportedLine."Sub. Contract Line created" := false;
        ImportedLine.Insert(false);
        Assert.AreEqual(BeforeCount + 1, ConfirmationCount("Message Type ori"::"Subscription.Import.CreateContracts", '', Request), 'One row selected by two stages must count once.');
        ImportedLine.Get(ImportedLine."Entry No.");
        Assert.AreEqual('', ImportedLine."Error Text", 'Counting must not process the staging row.');
        ImportedLine."Subscription Line created" := true;
        ImportedLine."Sub. Contract Line created" := true;
        ImportedLine.Modify(false);
        Assert.AreEqual(BeforeCount, ConfirmationCount("Message Type ori"::"Subscription.Import.CreateContracts", '', Request), 'Completed rows must not count.');
    end;

    /// <summary>Release confirmation includes due deferrals from both partners only.</summary>
    [Test]
    procedure Scenario_AC03_Deferrals_CountIncludesBothPartners()
    var
        CustomerDeferral: Record "Cust. Sub. Contract Deferral";
        VendorDeferral: Record "Vend. Sub. Contract Deferral";
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        // [GIVEN] A count baseline, then one due row from each partner and a future row.
        BeforeCount := ConfirmationCount("Message Type ori"::"Subscription.Deferral.Release", '', Request);
        CustomerDeferral.Init();
        CustomerDeferral."Posting Date" := WorkDate();
        CustomerDeferral.Insert(false);
        VendorDeferral.Init();
        VendorDeferral."Posting Date" := WorkDate();
        VendorDeferral.Insert(false);
        Assert.AreEqual(BeforeCount + 2, ConfirmationCount("Message Type ori"::"Subscription.Deferral.Release", '', Request), 'Both partners must contribute to the release bound.');
        VendorDeferral."Posting Date" := CalcDate('<1D>', WorkDate());
        VendorDeferral.Modify(false);
        Assert.AreEqual(BeforeCount + 1, ConfirmationCount("Message Type ori"::"Subscription.Deferral.Release", '', Request), 'Future deferrals must be outside the bound.');
        CustomerDeferral.Released := true;
        CustomerDeferral.Modify(false);
        Assert.AreEqual(BeforeCount, ConfirmationCount("Message Type ori"::"Subscription.Deferral.Release", '', Request), 'Released entries must be outside the bound.');
    end;

    /// <summary>An already queued term-date job creates no new work.</summary>
    [Test]
    procedure Scenario_AC03_PendingTermDateJob_CountsZero()
    var
        JobQueueEntry: Record "Job Queue Entry";
        Request: JsonObject;
    begin
        // The operation creates no new work when the same job is already pending.
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := 8058;
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry.Insert(false);
        Assert.AreEqual(0, ConfirmationCount("Message Type ori"::"Subscription.Contract.UpdateLineDates", '', Request), 'An already pending term-date run must count zero new work.');
        Assert.IsTrue(JobQueueEntry.Get(JobQueueEntry.ID), 'Preview must preserve the pending entry.');
    end;

    /// <summary>Existing rollback and read-only previews keep their effects.</summary>
    [Test]
    procedure Scenario_AC01_PreviewsAndWrites_KeepTheirEffects()
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Parameter: JsonToken;
        Name: JsonToken;
    begin
        Contract := "Message Type ori"::"Subscription.Contract.PreviewInvoice";
        Contract.GetEffect(Effect);
        Assert.AreEqual('write', TextValue(Effect, 'effect'), 'Rollback preview keeps its existing effect.');
        Contract.GetParameters(Parameters);
        foreach Parameter in Parameters do begin
            Parameter.AsObject().Get('name', Name);
            Assert.AreNotEqual('expectedCount', Name.AsValue().AsText(), 'Invoice preview must not gain a confirmation parameter.');
        end;
        Clear(Effect);
        Contract := "Message Type ori"::"Subscription.Billing.PreviewDocuments";
        Contract.GetEffect(Effect);
        Assert.AreEqual('read', TextValue(Effect, 'effect'), 'Read-only billing preview remains read.');
    end;

    /// <summary>Only the three posting-capable types declare irreversible across the complete app catalogue.</summary>
    [Test]
    procedure Scenario_AC01_AllTypes_OnlyPostingIsIrreversible()
    var
        MessageType: Enum "Message Type ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        TypeName: Text;
        Visited: Integer;
    begin
        foreach TypeName in MessageType.Names() do
            if TypeName.StartsWith('Subscription.') then begin
                Contract := TypeByName(TypeName);
                Clear(Effect);
                Contract.GetEffect(Effect);
                if PostingTypes().Contains(TypeName) then
                    Assert.AreEqual('irreversible', TextValue(Effect, 'effect'), TypeName)
                else
                    Assert.AreNotEqual('irreversible', TextValue(Effect, 'effect'), TypeName);
                Visited += 1;
            end;
        Assert.AreEqual(33, Visited, 'Walk every Subscription Billing type. Update the audit when the catalogue grows.');
    end;

    /// <summary>Every former irreversible write retains an optional ignored count and localized write help.</summary>
    [Test]
    procedure Scenario_AC03_Writes_HelpAndOptionalCount_BothLanguages()
    begin
        AssertWriteHelp(1033, 'Writes', 'ignored');
        AssertWriteHelp(1039, 'Skrifar', 'hunsuð');
    end;

    local procedure AssertWriteHelp(LanguageId: Integer; WriteWord: Text; IgnoredWord: Text)
    var
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        Parameters: JsonArray;
        Parameter: JsonToken;
        Token: JsonToken;
        TypeName: Text;
        Description: Text;
        PreviousLanguage: Integer;
        Found: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach TypeName in AuditedTypes() do
            if not PostingTypes().Contains(TypeName) then begin
                Contract := TypeByName(TypeName);
                Discovery := TypeByName(TypeName);
                Description := Discovery.GetSelectionDescription();
                Assert.IsTrue(Description.Contains(WriteWord), TypeName + ' must say it writes.');
                Assert.IsFalse(Description.ToLower().Contains('irreversible'), TypeName);
                Assert.IsFalse(Description.ToLower().Contains('óafturkræ'), TypeName);
                Clear(Parameters);
                Contract.GetParameters(Parameters);
                Found := 0;
                foreach Parameter in Parameters do
                    if TextValue(Parameter.AsObject(), 'name') = 'expectedCount' then begin
                        Found += 1;
                        Parameter.AsObject().Get('required', Token);
                        Assert.IsFalse(Token.AsValue().AsBoolean(), TypeName + ' count stays optional.');
                        Description := TextValue(Parameter.AsObject(), 'description');
                        Assert.IsTrue(Description.Contains(IgnoredWord), TypeName + ' contract explains compatibility in the session language.');
                        Assert.IsFalse(Description.Contains('ConfirmationRequired'), TypeName + ' has no count preview requirement.');
                    end;
                Assert.AreEqual(1, Found, TypeName + ' keeps expectedCount accepted.');
            end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertCountHelp(LanguageId: Integer; CountWord: Text; PreviewWords: Text)
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Parameter: JsonToken;
        Token: JsonToken;
        TypeName: Text;
        Description: Text;
        PreviousLanguage: Integer;
        ParameterCount: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach TypeName in PostingTypes() do begin
            Contract := TypeByName(TypeName);
            Clear(Effect);
            Clear(Parameters);
            Assert.IsTrue(Contract.GetEffect(Effect), TypeName);
            Assert.AreEqual('irreversible', TextValue(Effect, 'effect'), TypeName);
            Description := TextValue(Effect, 'changes');
            Assert.IsTrue(Description.Contains(CountWord), TypeName + ' must name the count unit in the requested language.');
            Assert.IsTrue(Description.Contains(PreviewWords), TypeName + ' must explain the non-writing preview.');
            Assert.IsTrue(Description.Contains('Max Count'), TypeName + ' must name the automation cap.');
            Contract.GetParameters(Parameters);
            ParameterCount := 0;
            foreach Parameter in Parameters do begin
                Parameter.AsObject().Get('name', Token);
                if Token.AsValue().AsText() = 'expectedCount' then begin
                    ParameterCount += 1;
                    Description := TextValue(Parameter.AsObject(), 'description');
                    Assert.IsTrue(Description.Contains(CountWord), TypeName + ' parameter must name its unit.');
                    Assert.IsTrue(Description.Contains(PreviewWords), TypeName + ' parameter must explain preview.');
                end;
            end;
            Assert.AreEqual(1, ParameterCount, TypeName + ' must declare expectedCount exactly once.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertRemovalConfirmation(LanguageId: Integer)
    var
        Assignment: Record "Item Subscription Package";
        ContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        Request: JsonObject;
        Response: JsonObject;
        HeaderNo: Code[20];
        ContractNo: Code[20];
        LineNo: Integer;
        EntryNo: Integer;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        SetConfirmationRequired(true);
        SeedAssignment(Assignment);
        Request.Add('subscriptionPackageCode', Assignment.Code);
        Response := DispatchRaw("Message Type ori"::"Subscription.Package.RemoveItemAssignment", Assignment."Item No.", Request);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Assignment removal needs no confirmation.');
        Assert.IsFalse(Assignment.Get(Assignment."Item No.", Assignment.Code), 'The assignment must be gone.');
        HeaderNo := NewCode();
        ContractNo := NewCode();
        TestLib.CreateSubscriptionHeader(HeaderNo);
        TestLib.CreateCustomerContract(ContractNo, '');
        EntryNo := TestLib.CreateSubscriptionLine(HeaderNo, "Service Partner"::Customer, ContractNo, WorkDate(), 0D, WorkDate());
        LineNo := TestLib.CreateCustomerContractLine(ContractNo, HeaderNo, EntryNo);
        Clear(Request);
        Request.Add('lineNo', LineNo);
        Response := DispatchRaw("Message Type ori"::"Subscription.Contract.RemoveLine", ContractNo, Request);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Line removal needs no confirmation.');
        Assert.IsFalse(ContractLine.Get(ContractNo, LineNo), 'The contract line must be deleted.');
        SubscriptionLine.Get(EntryNo);
        Assert.AreEqual('', SubscriptionLine."Subscription Contract No.", 'The Subscription Line must survive, detached.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure SeedAssignment(var Assignment: Record "Item Subscription Package")
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := NewCode();
        Item.Insert(false);
        Assignment.Init();
        Assignment."Item No." := Item."No.";
        Assignment.Code := NewCode();
        Assignment.Insert(false);
    end;

    local procedure SeedBillingLine(ContractNo: Code[20]; TemplateCode: Code[20]; DocumentNo: Code[20])
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.Init();
        BillingLine."Subscription Contract No." := ContractNo;
        BillingLine."Billing Template Code" := TemplateCode;
        BillingLine."Document No." := DocumentNo;
        BillingLine."Document Type" := BillingLine."Document Type"::Invoice;
        BillingLine.Insert(false);
    end;

    local procedure ConfirmationCount(MessageType: Enum "Message Type ori"; Subject: Text[250]; Request: JsonObject) Count: Integer
    var
        TempArgument: Record "Message Argument ori" temporary;
        Counter: Interface "Msg Confirm ori";
        Summary: Text;
    begin
        TempArgument.Init();
        TempArgument.Type := MessageType;
        TempArgument.Subject := Subject;
        // GetRequestJson reloads the request BLOB from the temporary row.
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Counter := MessageType;
        Assert.IsTrue(Counter.GetConfirmCount(TempArgument, Count, Summary), 'The counter must answer.');
    end;

    local procedure DispatchRaw(MessageType: Enum "Message Type ori"; Subject: Text[250]; Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", Subject, 'XSB93', 'application/json', RequestContent, ResponseContent, ContentType, true);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'The dispatcher must return JSON.');
    end;

    local procedure SetConfirmationRequired(Required: Boolean)
    var
        Setup: Record "Setup ori";
        SetupPage: TestPage "Setup ori";
    begin
        Setup.InsertIfNotExists();
        SetupPage.OpenEdit();
        SetupPage."Require Irreversible Confirm".SetValue(Required);
        SetupPage.Close();
    end;

    local procedure AssertPreview(Response: JsonObject; Count: Integer)
    begin
        Assert.AreEqual('ConfirmationRequired', TextValue(Response, 'code'), 'The call must stop before business writes.');
        Assert.AreEqual(Format(Count, 0, 9), TextValue(Response, 'expected'), 'The preview must return the documented count.');
    end;

    local procedure TextValue(Value: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Value.Get(Name, Token), 'Missing property ' + Name);
        exit(Token.AsValue().AsText());
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X93' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure TypeByName(TypeName: Text): Enum "Message Type ori"
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := "Message Type ori".Names();
        Ordinals := "Message Type ori".Ordinals();
        exit("Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(TypeName))));
    end;

    local procedure AuditedTypes() Types: List of [Text]
    begin
        Types.Add('Subscription.PriceUpdate.Perform');
        Types.Add('Subscription.Contract.CreateInvoice');
        Types.Add('Subscription.VendorContract.CreateInvoice');
        Types.Add('Subscription.Contract.UpdateLineDates');
        Types.Add('Subscription.Billing.CreateProposal');
        Types.Add('Subscription.Billing.CreateDocuments');
        Types.Add('Subscription.Renewal.Extend');
        Types.Add('Subscription.Renewal.CreateQuote');
        Types.Add('Subscription.Usage.ImportData');
        Types.Add('Subscription.Usage.Process');
        Types.Add('Subscription.Deferral.Release');
        Types.Add('Subscription.Import.CreateContracts');
        Types.Add('Subscription.Billing.ClearProposal');
        Types.Add('Subscription.Billing.DeleteDocuments');
        Types.Add('Subscription.Usage.ConnectSubscriptions');
        Types.Add('Subscription.Usage.DeleteData');
        Types.Add('Subscription.Billing.PostDocuments');
        Types.Add('Subscription.Contract.RemoveLine');
        Types.Add('Subscription.Package.RemoveItemAssignment');
    end;
    local procedure PostingTypes() Types: List of [Text]
    begin
        Types.Add('Subscription.Billing.CreateDocuments');
        Types.Add('Subscription.Billing.PostDocuments');
        Types.Add('Subscription.Deferral.Release');
    end;

}
