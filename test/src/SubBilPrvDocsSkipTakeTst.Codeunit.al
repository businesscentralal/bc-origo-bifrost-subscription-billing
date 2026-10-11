namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// AC01–AC05 for issue #8: PreviewDocuments skip/take aligned with Foundation (omit→0/100,
/// negatives Error, take clamped to 1000, documentCount unpaginated, documents paged).
/// Invokes PerformWrite directly to avoid Foundation 110+ trial gate on the dispatcher.
/// </summary>
codeunit 95709 "Sub Bil PrvDocs SkipTst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TemplateCodeTok: Label 'BF8PAGE', Locked = true;

    [Test]
    procedure AC01_OmittedSkipTake_DefaultsTo0And100_AndPagesGroups()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Bil PrvDocs Impl ori";
        ResponseJson: JsonObject;
        Documents: JsonArray;
    begin
        // [SCENARIO] Omit skip/take with more than 100 groups → defaults 0/100, page size 100, documentCount is full total.
        Initialize();
        EnsureTemplate();
        EnsureDocumentGroups(105);

        InvokePreview(TempArgument, Impl, '');

        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'PreviewDocuments should succeed.');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'skip'), 'Omitted skip must default to 0.');
        Assert.AreEqual(100, ReadInteger(ResponseJson, 'take'), 'Omitted take must default to 100.');
        Assert.AreEqual(105, ReadInteger(ResponseJson, 'documentCount'), 'documentCount must be the unpaginated total.');
        Documents := ReadArray(ResponseJson, 'documents');
        Assert.AreEqual(100, Documents.Count(), 'documents must be the first page of 100 groups.');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'hasMore'), 'hasMore must be true when groups remain.');
    end;

    [Test]
    procedure AC02_NegativeSkip_FailsWithFoundationError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Bil PrvDocs Impl ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] skip: -1 → Foundation Error.
        Initialize();
        EnsureTemplate();

        RequestJson.Add('billingTemplateCode', TemplateCodeTok);
        RequestJson.Add('skip', -1);
        TempArgument.Init();
        TempArgument."Type" := Enum::"Message Type ori"::"Subscription.Billing.PreviewDocuments";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(RequestJson);

        asserterror Impl.PerformWrite(TempArgument);

        Assert.ExpectedError('skip must be zero or greater.');
    end;

    [Test]
    procedure AC03_NegativeTake_FailsWithFoundationError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Bil PrvDocs Impl ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] take: -1 → Foundation Error.
        Initialize();
        EnsureTemplate();

        RequestJson.Add('billingTemplateCode', TemplateCodeTok);
        RequestJson.Add('take', -1);
        TempArgument.Init();
        TempArgument."Type" := Enum::"Message Type ori"::"Subscription.Billing.PreviewDocuments";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(RequestJson);

        asserterror Impl.PerformWrite(TempArgument);

        Assert.ExpectedError('take must be zero or greater.');
    end;

    [Test]
    procedure AC04_TakeAbove1000_IsClampedTo1000()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Bil PrvDocs Impl ori";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] take above Foundation max → clamped to 1000 (not rejected). No product clamp below 1000.
        Initialize();
        EnsureTemplate();
        EnsureDocumentGroups(3);

        InvokePreview(TempArgument, Impl, '{"take":1001}');

        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'PreviewDocuments should succeed.');
        Assert.AreEqual(1000, ReadInteger(ResponseJson, 'take'), 'take above 1000 must clamp to 1000.');
        Assert.AreEqual(3, ReadInteger(ResponseJson, 'documentCount'), 'documentCount stays the true total.');
        Assert.AreEqual(3, ReadArray(ResponseJson, 'documents').Count(), 'All three groups fit in the clamped page.');
        Assert.IsFalse(ReadBoolean(ResponseJson, 'hasMore'), 'hasMore must be false when the page covers the total.');
    end;

    [Test]
    procedure AC05_ContractDocumentsPaginationLimits1000()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        SkipParameter: JsonObject;
        TakeParameter: JsonObject;
    begin
        // [SCENARIO] The PreviewDocuments contract documents skip and take with their defaults and the Foundation ceiling 1000.
        Initialize();

        // [WHEN] The contract chapters are read, as Help.Implementation.Get reads them
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Billing.PreviewDocuments", Contract);

        // [THEN] skip and take are parameters with their defaults, and the ceiling is stated
        Assert.IsTrue(FindParameter(Contract, 'skip', SkipParameter), 'The parameters chapter must document skip.');
        Assert.IsTrue(FindParameter(Contract, 'take', TakeParameter), 'The parameters chapter must document take.');
        Assert.AreEqual(0, ReadInteger(SkipParameter, 'default'), 'skip must default to 0.');
        Assert.AreEqual(100, ReadInteger(TakeParameter, 'default'), 'take must default to 100.');
        Assert.IsTrue(ReadText(TakeParameter, 'description').Contains('1000'), 'The take parameter must state the ceiling 1000.');
        Assert.IsTrue(ReadText(Contract, 'notes').Contains('hard maximum of 1000'), 'The notes must document the Foundation ceiling 1000.');
    end;

    [Test]
    procedure DocumentCountDivergesFromPage_WhenTakeIsSmaller()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Bil PrvDocs Impl ori";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] take=2 with 5 groups → documentCount=5, documents.Count=2, hasMore=true.
        Initialize();
        EnsureTemplate();
        EnsureDocumentGroups(5);

        InvokePreview(TempArgument, Impl, '{"take":2}');

        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual(5, ReadInteger(ResponseJson, 'documentCount'), 'documentCount is unpaginated.');
        Assert.AreEqual(2, ReadArray(ResponseJson, 'documents').Count(), 'documents is the page.');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'take'), 'take echoes the request.');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'hasMore'), 'hasMore when more groups remain.');
    end;

    local procedure Initialize()
    begin
        ClearTemplateLines();
    end;

    local procedure EnsureTemplate()
    var
        BillingTemplate: Record "Billing Template";
    begin
        if BillingTemplate.Get(TemplateCodeTok) then
            exit;
        BillingTemplate.Init();
        BillingTemplate.Code := TemplateCodeTok;
        BillingTemplate.Description := 'Bifrost #8 paging fixture';
        BillingTemplate.Partner := BillingTemplate.Partner::Customer;
        BillingTemplate.Insert(false);
    end;

    local procedure ClearTemplateLines()
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Billing Template Code", TemplateCodeTok);
        BillingLine.DeleteAll(false);
    end;

    local procedure EnsureDocumentGroups(GroupCount: Integer)
    var
        BillingLine: Record "Billing Line";
        Index: Integer;
        ContractNo: Code[20];
        NextEntryNo: Integer;
    begin
        // Isolate fixture rows, then allocate Entry Nos past any existing AutoIncrement/demo rows.
        // Insert(false) does not reliably advance SQL identity when demo data already occupies 1..n.
        ClearTemplateLines();
        NextEntryNo := NextBillingLineEntryNo();
        for Index := 1 to GroupCount do begin
            ContractNo := CopyStr(StrSubstNo('C%1', Format(100000 + Index)), 1, 20);

            BillingLine.Init();
            BillingLine."Entry No." := NextEntryNo;
            NextEntryNo += 1;
            BillingLine."Billing Template Code" := TemplateCodeTok;
            BillingLine."Document Type" := BillingLine."Document Type"::None;
            BillingLine.Partner := BillingLine.Partner::Customer;
            BillingLine."Partner No." := 'P00001';
            BillingLine."Subscription Contract No." := ContractNo;
            BillingLine.Amount := Index;
            BillingLine.Insert(false);
        end;
    end;

    local procedure NextBillingLineEntryNo(): Integer
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.Reset();
        if BillingLine.FindLast() then
            exit(BillingLine."Entry No." + 1);
        exit(1);
    end;

    local procedure InvokePreview(var TempArgument: Record "Message Argument ori" temporary; var Impl: Codeunit "Sub Bil PrvDocs Impl ori"; RequestJsonText: Text)
    var
        RequestJson: JsonObject;
    begin
        TempArgument.Reset();
        TempArgument.DeleteAll();
        TempArgument.Init();
        TempArgument."Type" := Enum::"Message Type ori"::"Subscription.Billing.PreviewDocuments";
        TempArgument.Insert(true);

        if RequestJsonText <> '' then
            RequestJson.ReadFrom(RequestJsonText)
        else
            Clear(RequestJson);
        if not RequestJson.Contains('billingTemplateCode') then
            RequestJson.Add('billingTemplateCode', TemplateCodeTok);
        TempArgument.SetRequestJson(RequestJson);

        Impl.PerformWrite(TempArgument);
    end;

    local procedure ReadText(Json: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Json.Get(Name, Token), StrSubstNo('Missing property %1', Name));
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadInteger(Json: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Json.Get(Name, Token), StrSubstNo('Missing property %1', Name));
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadBoolean(Json: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Json.Get(Name, Token), StrSubstNo('Missing property %1', Name));
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadArray(Json: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Json.Get(Name, Token), StrSubstNo('Missing property %1', Name));
        exit(Token.AsArray());
    end;

    local procedure FindParameter(Contract: JsonObject; Name: Text; var Parameter: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        foreach Token in ReadArray(Contract, 'parameters') do
            if ReadText(Token.AsObject(), 'name') = Name then begin
                Parameter := Token.AsObject();
                exit(true);
            end;
        exit(false);
    end;
}
