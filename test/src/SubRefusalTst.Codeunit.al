namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>Issue 62 request preflight regressions: aggregate value errors before any business lookup or write.</summary>
codeunit 95723 "Sub Refusal Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Sub Helper ori";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC02_MissingValues_Aggregate_EN()
    begin
        AssertMissingValues(1033);
    end;

    [Test]
    procedure Scenario_AC02_MissingValues_Aggregate_IS()
    begin
        AssertMissingValues(1039);
    end;

    local procedure AssertMissingValues(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Errors: JsonArray;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Line.Create", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Missing required values must be refused before record lookup.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Errors := TestLibrary.ReadArray(Response, 'errors');
        Assert.AreEqual(2, Errors.Count(), 'The header and package problems must both be returned.');
        AssertProblem(Response, 'MissingParameter', 'subscriptionHeaderNo', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'subscriptionPackageCode', '<missing>');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC01_OneMissingValue_SingleError_EN()
    begin
        AssertSingleMissing(1033);
    end;

    [Test]
    procedure Scenario_AC01_OneMissingValue_SingleError_IS()
    begin
        AssertSingleMissing(1039);
    end;

    local procedure AssertSingleMissing(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('subscriptionHeaderNo', 'XS62-OWN-IDENTIFIER');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Line.Create", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Missing package must be answered before looking up the header.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MissingParameter', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('subscriptionPackageCode', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.IsFalse(Response.Contains('errors'), 'A single error stays a single answer.');
        Assert.IsTrue(Response.Contains('expected'), 'Expected must be present.');
        Assert.IsTrue(Response.Contains('nextStep'), 'Recovery must be present.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC02_BadDateAndPartner_Aggregate()
    begin
        AssertBadDateAndPartner(1033);
    end;

    [Test]
    procedure Scenario_AC02_BadDateAndPartner_Aggregate_IS()
    begin
        AssertBadDateAndPartner(1039);
    end;

    local procedure AssertBadDateAndPartner(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('contractNo', 'XS62-NO-LOOKUP');
        Request.Add('currencyFactorDate', 'not-a-date');
        Request.Add('partner', 'unknown-partner');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'All value problems are collected before contract lookup.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), TestLibrary.AsText(Response));
        AssertProblem(Response, 'InvalidParameterFormat', 'currencyFactorDate', 'not-a-date');
        AssertProblem(Response, 'InvalidParameter', 'partner', 'unknown-partner');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC03_InvalidBase64_IsSanitized_EN()
    begin
        AssertInvalidBase64(1033);
    end;

    [Test]
    procedure Scenario_AC03_InvalidBase64_IsSanitized_IS()
    begin
        AssertInvalidBase64(1039);
    end;

    local procedure AssertInvalidBase64(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        ErrorText: Text;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('supplierNo', 'XS62-NO-LOOKUP');
        Request.Add('contentBase64', '%%%');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Usage.ImportData", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Bad base64 is rejected before supplier lookup or file writes.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('InvalidParameterFormat', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('contentBase64', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        ErrorText := TestLibrary.ReadText(Response, 'error');
        Assert.IsFalse(ErrorText.Contains('padding'), 'Raw .NET decode detail must not escape.');
        Assert.IsTrue(ErrorText.Contains('base64'), 'The error must identify the encoding.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC02_SubjectFallback_IsAccepted()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('subscriptionPackageCode', 'XS62-PACKAGE');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Line.Create", Request);
        TempArgument.Subject := 'XS62-SUBJECT';
        Assert.IsTrue(Helper.ValidateRequest(TempArgument), 'A valid subject supplies the required header parameter.');
    end;

    [Test]
    procedure Scenario_AC02_EmptyFilter_StillClearsFilter()
    var
        BillingTemplate: Record "Billing Template";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        BillingTemplate.Init();
        BillingTemplate.Code := 'XS62-TEMPLATE';
        BillingTemplate.Insert(false);
        Request.Add('billingTemplateCode', BillingTemplate.Code);
        Request.Add('filter', '');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.SetTemplateFilter", Request);
        Assert.IsTrue(Helper.ValidateRequest(TempArgument), 'An explicitly empty filter remains valid.');
    end;

    [Test]
    procedure Scenario_AC02_UnknownTemplateAndBadDate_Aggregate()
    begin
        AssertUnknownTemplateAndBadDate(1033);
    end;

    [Test]
    procedure Scenario_AC02_UnknownTemplateAndBadDate_Aggregate_IS()
    begin
        AssertUnknownTemplateAndBadDate(1039);
    end;

    local procedure AssertUnknownTemplateAndBadDate(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('billingTemplateCode', 'XS62-UNKNOWN');
        Request.Add('billingDate', 'not-a-date');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'The template lookup must not hide a bad date, or vice versa.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), TestLibrary.AsText(Response));
        AssertProblem(Response, 'InvalidParameterFormat', 'billingDate', 'not-a-date');
        AssertProblem(Response, 'RecordNotFound', 'billingTemplateCode', 'XS62-UNKNOWN');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC01_RecordNotFound_Context_EN()
    begin
        AssertRecordRefusal(1033);
    end;

    [Test]
    procedure Scenario_AC01_RecordNotFound_Context_IS()
    begin
        AssertRecordRefusal(1039);
    end;

    local procedure AssertRecordRefusal(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Implementation: Codeunit "Sub Con GetLines Impl ori";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('contractNo', 'XS62-OWN-NONEXISTENT');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.GetLines", Request);
        asserterror Implementation.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('RecordNotFound', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('contractNo', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.AreEqual('XS62-OWN-NONEXISTENT', TestLibrary.ReadText(Response, 'received'), TestLibrary.AsText(Response));
        Assert.IsTrue(TestLibrary.ReadText(Response, 'expected') <> '', 'Expected must guide the caller.');
        Assert.IsTrue(TestLibrary.ReadText(Response, 'nextStep') <> '', 'Recovery must guide the caller.');
        if LanguageId = 1039 then
            Assert.IsTrue(TestLibrary.ReadText(Response, 'nextStep').Contains('Leiðréttu'), 'Recovery must be Icelandic.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC02_TwoNestedDocuments_CollectAllMissingValues()
    begin
        AssertTwoNestedDocuments(1033);
    end;

    [Test]
    procedure Scenario_AC02_TwoNestedDocuments_CollectAllMissingValues_IS()
    begin
        AssertTwoNestedDocuments(1039);
    end;

    local procedure AssertTwoNestedDocuments(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Item: JsonObject;
        Documents: JsonArray;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Documents.Add(Item.Clone());
        Documents.Add(Item.Clone());
        Request.Add('documents', Documents);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Both nested documents are validated before any lookup or post.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(6, TestLibrary.ReadArray(Response, 'errors').Count(), 'All three required values on both documents must be reported.');
        AssertProblem(Response, 'MissingParameter', 'documents[0].partner', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'documents[0].documentType', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'documents[0].documentNo', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'documents[1].partner', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'documents[1].documentType', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'documents[1].documentNo', '<missing>');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC02_ObjectInsteadOfScalar_IsStructuredBeforeLookup()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        InvalidValue: JsonObject;
        Response: JsonObject;
    begin
        InvalidValue.Add('ownMalformedValue', 'XS62');
        Request.Add('contractNo', InvalidValue);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'An object value is a structured request problem, never a runtime conversion error.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('InvalidParameterFormat', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('contractNo', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
    end;

    [Test]
    procedure Scenario_AC02_SelectionArray_CollectsEachBadEntry()
    begin
        AssertSelectionEntries(1033);
    end;

    [Test]
    procedure Scenario_AC02_SelectionArray_CollectsEachBadEntry_IS()
    begin
        AssertSelectionEntries(1039);
    end;

    local procedure AssertSelectionEntries(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Entries.Add('bad-one');
        Entries.Add('bad-two');
        Request.Add('contractNo', 'XS62-NO-LOOKUP');
        Request.Add('subscriptionLineEntryNos', Entries);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.GetLines", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Every selection value is checked before the contract lookup.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), 'Both malformed entry numbers must be returned.');
        AssertProblem(Response, 'InvalidParameterFormat', 'subscriptionLineEntryNos[0]', 'bad-one');
        AssertProblem(Response, 'InvalidParameterFormat', 'subscriptionLineEntryNos[1]', 'bad-two');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC03_CreateDocuments_PostingFailureNamesDocument_EN()
    begin
        AssertPostingFailure(1033);
    end;

    [Test]
    procedure Scenario_AC03_CreateDocuments_PostingFailureNamesDocument_IS()
    begin
        AssertPostingFailure(1039);
    end;

    local procedure AssertPostingFailure(LanguageId: Integer)
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        FailureTest: Codeunit "Sub Posting Failure Test ori";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, CustomerContract."No.");
        Request.Add('billingTemplateCode', BillingTemplate.Code);
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", Request);
        FailureTest.SetCustomer(CustomerContract."Sell-to Customer No.");
        BindSubscription(FailureTest);
        Request.Add('postDocuments', true);
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", Request);
        UnbindSubscription(FailureTest);
        Assert.AreEqual('Error', TestLibrary.ReadText(Response, 'status'), TestLibrary.AsText(Response));
        Assert.AreEqual('BusinessCentralError', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreNotEqual('', FailureTest.GetDocumentNo(), 'The actual posting event must have been reached.');
        Assert.AreEqual(FailureTest.GetDocumentNo(), TestLibrary.ReadText(Response, 'documentNo'), 'The failing posting document must be captured, never inferred from a list.');
        Assert.AreEqual('documentNo', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.AreEqual(FailureTest.GetDocumentNo(), TestLibrary.ReadText(Response, 'received'), TestLibrary.AsText(Response));
        Assert.IsTrue(TestLibrary.ReadText(Response, 'nextStep') <> '', 'Posting failure must explain recovery.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC04_RequiredUsageEntry_HelpListsRealPreflightCodes()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        ContractText: Text;
    begin
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Usage.Process", Contract);
        ContractText := TestLibrary.AsText(Contract);
        Assert.IsTrue(ContractText.Contains('MissingParameter'), 'Usage.Process help must list its required-entry refusal.');
        Assert.IsTrue(ContractText.Contains('InvalidParameterFormat'), 'Usage.Process help must list shape validation.');
        Clear(Contract);
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", Contract);
        ContractText := TestLibrary.AsText(Contract);
        Assert.IsTrue(ContractText.Contains('MissingParameter'), 'Usage.DeleteData help must list its required-entry refusal.');
        Assert.IsTrue(ContractText.Contains('InvalidParameterFormat'), 'Usage.DeleteData help must list shape validation.');
    end;

    [Test]
    procedure Review_ContextFields_EN()
    begin
        AssertReviewContextFields(1033);
    end;

    [Test]
    procedure Review_ContextFields_IS()
    begin
        AssertReviewContextFields(1039);
    end;

    local procedure AssertReviewContextFields(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        DeleteDocuments: Codeunit "Sub Bil DelDocs Impl ori";
        DeferralRelease: Codeunit "Sub Def Release Impl ori";
        Disconnect: Codeunit "Sub Usg Disconnect Impl ori";
        Request: JsonObject;
        PreviousLanguage: Integer;
        RequestedDate: Date;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        Request.Add('documentNo', 'ZZ62-OWN-MISSING');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.DeleteDocuments", Request);
        asserterror DeleteDocuments.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'RecordNotFound', 'documentNo', 'ZZ62-OWN-MISSING');

        Clear(Request);
        RequestedDate := CalcDate('<+1D>', WorkDate());
        Request.Add('postingDate', Helper.FormatDate(RequestedDate));
        Request.Add('postUntilDate', Helper.FormatDate(RequestedDate));
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Deferral.Release", Request);
        asserterror DeferralRelease.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'PreconditionFailed', 'postingDate', Helper.FormatDate(RequestedDate));

        Clear(Request);
        Request.Add('subscriptionLineEntryNo', 2147483000);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Usage.DisconnectSubscription", Request);
        asserterror Disconnect.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'RecordNotFound', 'subscriptionLineEntryNo', '2147483000');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Review_LengthAndNestedShape_EN()
    begin
        AssertLengthAndNestedShape(1033);
    end;

    [Test]
    procedure Review_LengthAndNestedShape_IS()
    begin
        AssertLengthAndNestedShape(1039);
    end;

    local procedure AssertLengthAndNestedShape(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Document: JsonObject;
        BadShape: JsonObject;
        Documents: JsonArray;
        LongIdentifier: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LongIdentifier := 'ZZ62-1234567890123456789';
        Request.Add('contractNo', LongIdentifier);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.GetLines", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Preflight must reject an overlong identifier.');
        AssertRefusalFields(TempArgument.GetResponseJson(), 'InvalidParameterFormat', 'contractNo', LongIdentifier);
        asserterror Helper.GetCode20(Request, 'contractNo', true);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'InvalidParameterFormat', 'contractNo', LongIdentifier);
        Clear(Request);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.GetLines", Request);
        TempArgument.Subject := CopyStr(LongIdentifier, 1, MaxStrLen(TempArgument.Subject));
        asserterror Helper.GetSubjectOr(Request, 'contractNo', TempArgument, true);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'InvalidParameterFormat', 'contractNo', LongIdentifier);

        Document.Add('partner', 'Vendor');
        Document.Add('documentType', 'Invoice');
        Document.Add('documentNo', BadShape);
        Documents.Add(Document);
        Request.Add('documents', Documents);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'A nested object cannot be a document number.');
        AssertRefusalFields(TempArgument.GetResponseJson(), 'InvalidParameterFormat', 'documents[0].documentNo', '{}');
        Assert.IsFalse(TestLibrary.ReadText(TempArgument.GetResponseJson(), 'error').Contains('Expected .'), 'Expected cannot be empty.');
        Assert.IsFalse(TestLibrary.ReadText(TempArgument.GetResponseJson(), 'error').Contains('Væntanlegt er .'), 'Icelandic expected cannot be empty.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Review_UnknownEnumValue_IsStructured()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Prepare(TempArgument, Enum::"Message Type ori".FromInteger(2147483000), Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'An unavailable enum ordinal must not access list item zero.');
        AssertRefusalFields(TempArgument.GetResponseJson(), 'InvalidParameter', 'type', '2147483000');
    end;

    [Test]
    procedure Review_DomainSelections_EN()
    begin
        AssertDomainSelections(1033);
    end;

    [Test]
    procedure Review_DomainSelections_IS()
    begin
        AssertDomainSelections(1039);
    end;

    local procedure AssertDomainSelections(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        PurchaseHeader: Record "Purchase Header";
        ExchangeRates: Codeunit "Sub Con UpdFCY Impl ori";
        Extend: Codeunit "Sub Ren Extend Impl ori";
        CreateQuote: Codeunit "Sub Ren CrQuote Impl ori";
        ClearProposal: Codeunit "Sub Bil ClrProposal Impl ori";
        Preview: Codeunit "Sub Con PrvInvoice Impl ori";
        AddLines: Codeunit "Sub Vend AddToInv Impl ori";
        Request: JsonObject;
        LineNos: JsonArray;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        CustomerContract.Init();
        CustomerContract."No." := 'ZZ62-OWN-CONTRACT';
        CustomerContract."Currency Code" := 'USD';
        CustomerContract.Insert(false);
        Request.Add('contractNo', CustomerContract."No.");
        Request.Add('currencyFactorDate', Helper.FormatDate(WorkDate()));
        Request.Add('currencyFactor', 0);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", Request);
        asserterror ExchangeRates.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'PreconditionFailed', 'currencyFactorDate', Helper.FormatDate(WorkDate()));

        SubscriptionHeader.Init();
        SubscriptionHeader."No." := 'ZZ62-OWN-HEADER';
        SubscriptionHeader.Insert(false);
        Clear(Request);
        Request.Add('subscriptionHeaderNo', SubscriptionHeader."No.");
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Renewal.Extend", Request);
        asserterror Extend.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'MissingParameter', 'customerContractNo', '<missing>');
        Assert.IsTrue(TestLibrary.ReadText(TempArgument.GetResponseJson(), 'expected').Contains('customerContractNo') and TestLibrary.ReadText(TempArgument.GetResponseJson(), 'expected').Contains('vendorContractNo'), 'Expected must explain both accepted alternatives.');

        Clear(Request);
        // An expected error rolls back prior SQL fixtures; seed this independent scenario again.
        CustomerContract.Init();
        CustomerContract."No." := 'ZZ62-OWN-CONTRACT';
        CustomerContract.Insert(false);
        LineNos.Add(2147483000);
        Request.Add('contractNo', CustomerContract."No.");
        Request.Add('contractLineNos', LineNos);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Renewal.CreateQuote", Request);
        asserterror CreateQuote.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'RecordNotFound', 'contractLineNos', '2147483000');

        BillingTemplate.Init();
        BillingTemplate.Code := 'ZZ62-OWN-TEMPLATE';
        BillingTemplate.Insert(false);
        BillingLine.Init();
        BillingLine."Billing Template Code" := BillingTemplate.Code;
        BillingLine."Document No." := 'ZZ62-OWN-DOCUMENT';
        BillingLine.Insert(false);
        Clear(Request);
        Request.Add('billingTemplateCode', BillingTemplate.Code);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.ClearProposal", Request);
        asserterror ClearProposal.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'PreconditionFailed', 'billingTemplateCode', BillingTemplate.Code);

        CustomerContract.Init();
        CustomerContract."No." := 'ZZ62-OWN-CONTRACT';
        CustomerContract.Insert(false);
        Clear(BillingLine);
        BillingLine.Init();
        BillingLine."Subscription Contract No." := 'ZZ62-OWN-FOREIGN';
        BillingLine.Insert(false);
        Clear(Request);
        Request.Add('contractNo', CustomerContract."No.");
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.PreviewInvoice", Request);
        asserterror Preview.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'PreconditionFailed', 'contractNo', CustomerContract."No.");

        Clear(BillingLine);
        BillingLine.Init();
        BillingLine."Subscription Contract No." := 'ZZ62-OWN-FOREIGN';
        BillingLine.Insert(false);
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Invoice;
        PurchaseHeader."No." := 'ZZ62-OWN-INVOICE';
        PurchaseHeader.Insert(false);
        Clear(Request);
        Request.Add('purchaseInvoiceNo', PurchaseHeader."No.");
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", Request);
        asserterror AddLines.PerformWrite(TempArgument);
        TempArgument.RespondWithLastError();
        AssertRefusalFields(TempArgument.GetResponseJson(), 'PreconditionFailed', 'purchaseInvoiceNo', PurchaseHeader."No.");
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertRefusalFields(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; ExpectedReceived: Text)
    begin
        Assert.AreEqual('Error', TestLibrary.ReadText(Response, 'status'), TestLibrary.AsText(Response));
        Assert.AreEqual(ExpectedCode, TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(ExpectedParameter, TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.IsFalse(TestLibrary.ReadText(Response, 'parameter').Contains('|'), 'The parameter must name an actual request field; alternatives belong in expected.');
        Assert.AreEqual(ExpectedReceived, TestLibrary.ReadText(Response, 'received'), TestLibrary.AsText(Response));
        Assert.AreNotEqual('', TestLibrary.ReadText(Response, 'expected'), 'Expected cannot be empty.');
        Assert.AreNotEqual('', TestLibrary.ReadText(Response, 'nextStep'), 'Recovery cannot be empty.');
    end;

    [Test]
    procedure Review_MissingAlternatives_AggregatesBeforeLookup_EN()
    begin
        AssertMissingAlternatives(1033);
    end;

    [Test]
    procedure Review_MissingAlternatives_AggregatesBeforeLookup_IS()
    begin
        AssertMissingAlternatives(1039);
    end;

    local procedure AssertMissingAlternatives(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Renewal.Extend", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'The missing header and missing contract choice must both be collected before a lookup.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), TestLibrary.AsText(Response));
        AssertProblem(Response, 'MissingParameter', 'subscriptionHeaderNo', '<missing>');
        AssertProblem(Response, 'MissingParameter', 'customerContractNo', '<missing>');
        AssertAggregateFields(Response);
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertProblem(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; ExpectedReceived: Text)
    var
        Problems: JsonArray;
        Problem: JsonToken;
        Entry: JsonObject;
    begin
        Problems := TestLibrary.ReadArray(Response, 'errors');
        foreach Problem in Problems do begin
            Entry := Problem.AsObject();
            if TestLibrary.ReadText(Entry, 'parameter') = ExpectedParameter then begin
                Assert.AreEqual(ExpectedCode, TestLibrary.ReadText(Entry, 'code'), TestLibrary.AsText(Entry));
                Assert.AreEqual(ExpectedReceived, TestLibrary.ReadText(Entry, 'received'), TestLibrary.AsText(Entry));
                if ExpectedParameter in ['currencyFactorDate', 'billingDate'] then
                    Assert.AreEqual('YYYY-MM-DD', TestLibrary.ReadText(Entry, 'expected'), 'Date errors must name the accepted format.');
                exit;
            end;
        end;
        Assert.Fail('No problem names ' + ExpectedParameter + ': ' + TestLibrary.AsText(Response));
    end;

    local procedure AssertAggregateFields(Response: JsonObject)
    var
        Problems: JsonArray;
        Problem: JsonToken;
        Entry: JsonObject;
    begin
        Problems := TestLibrary.ReadArray(Response, 'errors');
        foreach Problem in Problems do begin
            Entry := Problem.AsObject();
            Assert.AreNotEqual('', TestLibrary.ReadText(Entry, 'code'), 'Each problem needs its code.');
            Assert.AreNotEqual('', TestLibrary.ReadText(Entry, 'parameter'), 'Each problem needs its parameter.');
            Assert.AreNotEqual('', TestLibrary.ReadText(Entry, 'received'), 'Each problem needs its received value.');
            Assert.AreNotEqual('', TestLibrary.ReadText(Entry, 'expected'), 'Each problem needs a meaningful expected value.');
            Assert.IsTrue(TestLibrary.ReadText(Entry, 'nextStep').Contains(TestLibrary.ReadText(Entry, 'parameter')), 'Recovery must name the corresponding parameter.');
            Assert.IsFalse(TestLibrary.ReadText(Entry, 'error').Contains('Expected .'), 'An empty allowed list must not become an empty expected clause.');
            Assert.IsFalse(TestLibrary.ReadText(Entry, 'error').Contains('Væntanlegt er .'), 'Icelandic expected text must not be empty.');
        end;
    end;

    local procedure Prepare(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; Request: JsonObject)
    begin
        TempArgument.Reset();
        TempArgument.DeleteAll(false);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(false);
        TempArgument.SetRequestJson(Request);
    end;
}
