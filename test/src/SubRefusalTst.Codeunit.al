namespace Origo.Bifrost.SubscriptionBilling.Test;

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
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('contractNo', 'XS62-NO-LOOKUP');
        Request.Add('currencyFactorDate', 'not-a-date');
        Request.Add('partner', 'unknown-partner');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'All value problems are collected before contract lookup.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), TestLibrary.AsText(Response));
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
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('billingTemplateCode', 'XS62-UNKNOWN');
        Request.Add('billingDate', 'not-a-date');
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'The template lookup must not hide a bad date, or vice versa.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(2, TestLibrary.ReadArray(Response, 'errors').Count(), TestLibrary.AsText(Response));
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
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Item: JsonObject;
        Documents: JsonArray;
        Response: JsonObject;
    begin
        Documents.Add(Item.Clone());
        Documents.Add(Item.Clone());
        Request.Add('documents', Documents);
        Prepare(TempArgument, Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", Request);
        Assert.IsFalse(Helper.ValidateRequest(TempArgument), 'Both nested documents are validated before any lookup or post.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('MultipleErrors', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual(6, TestLibrary.ReadArray(Response, 'errors').Count(), 'All three required values on both documents must be reported.');
    end;

    local procedure Prepare(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; Request: JsonObject)
    begin
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(false);
        TempArgument.SetRequestJson(Request);
    end;
}
