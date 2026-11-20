namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Help and refusal texts found in the 28.0.2 UAT (#102): the errors chapter must name the array
/// parameter each type really reads, an integer parameter must get an integer hint, and the
/// catalogue description must follow the caller's language (lcid 1033 and 1039).
/// </summary>
codeunit 95732 "Sub Help Names Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        CreateQuoteTok: Label 'Subscription.Renewal.CreateQuote', Locked = true;
        ConnectTok: Label 'Subscription.Usage.ConnectSubscriptions', Locked = true;
        GetLinesTok: Label 'Subscription.Contract.GetLines', Locked = true;
        WrongNameTok: Label 'subscriptionLineEntryNos', Locked = true;

    [Test]
    procedure Scenario_102AC01_CreateQuoteErrors_NameContractLineNos()
    var
        ContractText: Text;
    begin
        // [GIVEN] The contract of Subscription.Renewal.CreateQuote, whose array parameter is contractLineNos
        ContractText := GetContractText(CreateQuoteTok);

        // [THEN] The errors chapter names contractLineNos and never subscriptionLineEntryNos
        Assert.AreNotEqual(0, StrPos(ContractText, 'An entry of contractLineNos is not a whole number.'), ContractText);
        Assert.AreEqual(0, StrPos(ContractText, WrongNameTok), 'CreateQuote help must not name subscriptionLineEntryNos.');
    end;

    [Test]
    procedure Scenario_102AC01_ConnectErrors_NameEntryNos()
    var
        ContractText: Text;
    begin
        // [GIVEN] The contract of Subscription.Usage.ConnectSubscriptions, whose array parameter is entryNos
        ContractText := GetContractText(ConnectTok);

        // [THEN] The errors chapter names entryNos and never subscriptionLineEntryNos
        Assert.AreNotEqual(0, StrPos(ContractText, 'An entry of entryNos is not a whole number.'), ContractText);
        Assert.AreEqual(0, StrPos(ContractText, WrongNameTok), 'ConnectSubscriptions help must not name subscriptionLineEntryNos.');
    end;

    [Test]
    procedure Scenario_102AC01_GetLinesErrors_KeepSubscriptionLineEntryNos()
    var
        ContractText: Text;
    begin
        // [GIVEN] Edge case: a type that really reads subscriptionLineEntryNos
        ContractText := GetContractText(GetLinesTok);

        // [THEN] Its errors chapter still names that parameter
        Assert.AreNotEqual(0, StrPos(ContractText, 'An entry of subscriptionLineEntryNos is not a whole number.'), ContractText);
    end;

    [Test]
    procedure Scenario_102AC02_IntegerErrorContract_HasIntegerHint()
    var
        ContractText: Text;
    begin
        // [GIVEN] The contract of a type with integer parameters
        ContractText := GetContractText('Subscription.Contract.RemoveLine');

        // [THEN] The integer refusal shows a whole-number example, not a decimal one
        Assert.AreNotEqual(0, StrPos(ContractText, 'is not a valid whole number. Use digits only, for example 1234.'), ContractText);
        Assert.AreEqual(0, StrPos(ContractText, '1234.56'), 'An integer parameter must not get a decimal example.');
    end;

    [Test]
    procedure Scenario_102AC02_IntegerRefusal_EN()
    begin
        AssertIntegerRefusal(1033, 'is not a valid whole number. Use digits only, for example 1234.');
    end;

    [Test]
    procedure Scenario_102AC02_IntegerRefusal_IS()
    begin
        AssertIntegerRefusal(1039, 'er ekki gild heil tala. Notaðu eingöngu tölustafi, til dæmis 1234.');
    end;

    [Test]
    procedure Scenario_102AC02_DecimalRefusal_KeepsDecimalHint()
    var
        Helper: Codeunit "Sub Helper ori";
        RequestJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] Edge case: a decimal parameter that is not a number, read in English
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        RequestJson.Add('amount', 'abc');

        // [WHEN] It is read as a decimal
        asserterror Helper.GetDecimal(RequestJson, 'amount', true);
        GlobalLanguage(PreviousLanguage);

        // [THEN] The decimal hint stays
        Assert.ExpectedError('Use a decimal point, for example 1234.56.');
    end;

    [Test]
    procedure Scenario_102AC03_Description_FollowsLcid1033_FromIcelandicSession()
    begin
        AssertDescriptionLanguage(1039, 1033, CreateQuoteTok, 'Builds contract renewal lines');
        AssertDescriptionLanguage(1039, 1033, ConnectTok, 'Connects a usage data supplier');
    end;

    [Test]
    procedure Scenario_102AC03_Description_FollowsLcid1039_FromEnglishSession()
    begin
        AssertDescriptionLanguage(1033, 1039, CreateQuoteTok, 'Býr til endurnýjunarlínur');
        AssertDescriptionLanguage(1033, 1039, ConnectTok, 'Tengir áskriftir');
    end;

    local procedure AssertIntegerRefusal(LanguageId: Integer; ExpectedText: Text)
    var
        Helper: Codeunit "Sub Helper ori";
        RequestJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] An integer parameter written as a decimal, read in the given language
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        RequestJson.Add('lineNo', '12.5');

        // [WHEN] It is read as an integer
        asserterror Helper.GetInteger(RequestJson, 'lineNo', true);
        GlobalLanguage(PreviousLanguage);

        // [THEN] The refusal names the parameter and gives a whole-number example
        Assert.ExpectedError(ExpectedText);
        Assert.AreEqual(0, StrPos(GetLastErrorText(), '1234.56'), 'An integer refusal must not give a decimal example.');
    end;

    local procedure AssertDescriptionLanguage(SessionLanguageId: Integer; CallLanguageId: Integer; TypeName: Text; ExpectedStart: Text)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        MessageId: Guid;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        Description: Text;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A session in one language and a help call in the other
        RequestJson.Add('detail', 'summary');
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(SessionLanguageId);

        // [WHEN] Help.Implementation.Get is dispatched with the caller's lcid
        Dispatcher.EnqueueAndProcess(Enum::"Message Type ori"::"Help.Implementation.Get", Enum::"Message Version ori"::"1.0", CopyStr(TypeName, 1, 250), 'XSBA', 'application/json',
            RequestContent, EmptyTaskId, CallLanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        GlobalLanguage(PreviousLanguage);

        // [THEN] The catalogue description is in the caller's language, not the session's
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The dispatcher must return structured JSON.');
        Assert.IsTrue(ResponseJson.SelectToken('$.result[0].description', Token), ResponseText);
        Description := Token.AsValue().AsText();
        Assert.IsTrue(Description.StartsWith(ExpectedStart), StrSubstNo('lcid %1 from a %2 session: %3', CallLanguageId, SessionLanguageId, Description));
    end;

    local procedure GetContractText(TypeName: Text) Result: Text
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(TypeName)));
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
        Contract.WriteTo(Result);
    end;
}
