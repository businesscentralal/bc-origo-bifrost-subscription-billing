namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the line type guard of <c>Subscription.Import.CreateContracts</c> (#6, #39): an omitted
/// Sub_ContractLineType (the Comment default) is refused, an explicit Comment row is imported as a
/// contract comment line only with allowCommentLines, and an Item row still creates its
/// Subscription Line.
/// </summary>
codeunit 95705 "Sub Imp CrContr Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        LineTypeRequiredTxt: Label 'Sub_ContractLineType is required: set it to Item or G/L Account, or to Comment and send allowCommentLines = true.', Locked = true;

    [Test]
    procedure Scenario_AC02_OmittedLineType_FailsSubscriptionLinesStage()
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        ResponseJson: JsonObject;
        StageJson: JsonObject;
        ErrorJson: JsonObject;
    begin
        // Issue #39, AC02 | Time: none | Risk: None
        // [GIVEN] A staged line whose Sub_ContractLineType was never set (Comment, the default)
        Initialize();
        StageCommentLine(ImportedSubscriptionLine, '');

        // [WHEN] The SubscriptionLines stage runs without allowCommentLines
        ResponseJson := RunImport('["SubscriptionLines"]', false);

        // [THEN] The row fails with the line type error and stays uncreated
        StageJson := GetStage(ResponseJson, 0);
        Assert.AreEqual(1, ReadInteger(StageJson, 'failed'), 'A Comment line type must fail the stage.');
        Assert.AreEqual(0, ReadInteger(StageJson, 'succeeded'), 'A Comment line type must not be counted as succeeded.');
        ErrorJson := GetError(ResponseJson, 0);
        Assert.AreEqual(LineTypeRequiredTxt, ReadText(ErrorJson, 'error'), 'The required line type error must be returned.');
        ImportedSubscriptionLine.Get(ImportedSubscriptionLine."Entry No.");
        Assert.IsFalse(ImportedSubscriptionLine."Subscription Line created", 'A failed row must stay uncreated.');
        Assert.AreEqual(LineTypeRequiredTxt, ImportedSubscriptionLine."Error Text", 'Error Text must be stored on the staging row.');
    end;

    [Test]
    procedure Scenario_AC02_DefaultCall_CreatesNoContractLineForOmittedType()
    var
        Customer: Record Customer;
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        ResponseJson: JsonObject;
    begin
        // Issue #6 AC-8, #39 AC02 | Time: none | Risk: None
        // [GIVEN] A staged Comment-default row for an existing customer contract
        Initialize();
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        StageCommentLine(ImportedSubscriptionLine, CustomerContract."No.");

        // [WHEN] All four stages run without allowCommentLines
        ResponseJson := RunImport('', false);

        // [THEN] SubscriptionLines fails the row, ContractLines skips it, and no contract line exists
        Assert.AreEqual(1, ReadInteger(FindStage(ResponseJson, 'SubscriptionLines'), 'failed'), 'SubscriptionLines must fail the row.');
        Assert.AreEqual(1, ReadInteger(FindStage(ResponseJson, 'ContractLines'), 'skipped'), 'ContractLines must skip the row SubscriptionLines failed.');
        Assert.AreEqual(0, ReadInteger(FindStage(ResponseJson, 'ContractLines'), 'succeeded'), 'ContractLines must not create a line for the failed row.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordIsEmpty(CustSubContractLine);
    end;

    [Test]
    procedure Scenario_AC02_ContractLinesOnly_RefusesCommentWithoutOptIn()
    var
        Customer: Record Customer;
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        ResponseJson: JsonObject;
        StageJson: JsonObject;
    begin
        // Issue #39, AC02 edge case | Time: none | Risk: None
        // [GIVEN] A staged Comment row and a call that runs only ContractLines, without the opt-in
        Initialize();
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        StageCommentLine(ImportedSubscriptionLine, CustomerContract."No.");

        // [WHEN] Only the ContractLines stage runs
        ResponseJson := RunImport('["ContractLines"]', false);

        // [THEN] The row fails in ContractLines with the line type error and no comment line is created
        StageJson := GetStage(ResponseJson, 0);
        Assert.AreEqual(1, ReadInteger(StageJson, 'failed'), 'ContractLines must refuse a Comment row without allowCommentLines.');
        Assert.AreEqual(LineTypeRequiredTxt, ReadText(GetError(ResponseJson, 0), 'error'), 'The line type error must be returned.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordIsEmpty(CustSubContractLine);
    end;

    [Test]
    procedure Scenario_AC01_CommentWithOptIn_CreatesContractCommentLine()
    var
        Customer: Record Customer;
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        ResponseJson: JsonObject;
        SubscriptionLinesStage: JsonObject;
        ContractLinesStage: JsonObject;
    begin
        // Issue #39, AC01 | Time: none | Risk: None
        // [GIVEN] A staged Comment row for an existing customer contract
        Initialize();
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        StageCommentLine(ImportedSubscriptionLine, CustomerContract."No.");

        // [WHEN] SubscriptionLines and ContractLines run with allowCommentLines = true
        ResponseJson := RunImport('["SubscriptionLines","ContractLines"]', true);

        // [THEN] SubscriptionLines skips the row and ContractLines creates the contract comment line
        SubscriptionLinesStage := FindStage(ResponseJson, 'SubscriptionLines');
        ContractLinesStage := FindStage(ResponseJson, 'ContractLines');
        Assert.AreEqual(1, ReadInteger(SubscriptionLinesStage, 'skipped'), 'SubscriptionLines must skip an opted-in Comment row.');
        Assert.AreEqual(0, ReadInteger(SubscriptionLinesStage, 'failed'), 'SubscriptionLines must not fail an opted-in Comment row.');
        Assert.AreEqual(1, ReadInteger(ContractLinesStage, 'succeeded'), 'ContractLines must create the comment line.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.IsTrue(CustSubContractLine.FindFirst(), 'A contract comment line must exist.');
        Assert.IsTrue(CustSubContractLine."Contract Line Type" = CustSubContractLine."Contract Line Type"::Comment, 'The contract line must be a comment line.');
        Assert.AreEqual(ImportedSubscriptionLine.Description, CustSubContractLine."Subscription Description", 'The comment text must come from the staged row.');
        ImportedSubscriptionLine.Get(ImportedSubscriptionLine."Entry No.");
        Assert.IsTrue(ImportedSubscriptionLine."Sub. Contract Line created", 'The staged row must be marked as processed.');
    end;

    [Test]
    procedure Scenario_AC04_ExplicitItemLine_CreatesSubscriptionLine()
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        ResponseJson: JsonObject;
        StageJson: JsonObject;
    begin
        // Issue #39, AC04 | Time: WorkDate() as line start | Risk: None
        // [GIVEN] A Subscription and a staged Item line for it, invoiced through a contract
        Initialize();
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        ImportedSubscriptionLine.Init();
        ImportedSubscriptionLine."Subscription Header No." := SubscriptionHeader."No.";
        ImportedSubscriptionLine.Partner := Enum::"Service Partner"::Customer;
        ImportedSubscriptionLine."Sub. Contract Line Type" := Enum::"Contract Line Type"::Item;
        ImportedSubscriptionLine."Invoicing via" := Enum::"Invoicing Via"::Contract;
        ImportedSubscriptionLine.Description := 'XIMPORT ITEM LINE';
        ImportedSubscriptionLine."Subscription Line Start Date" := WorkDate();
        ImportedSubscriptionLine."Calculation Base Amount" := 100;
        ImportedSubscriptionLine."Calculation Base %" := 100;
        Evaluate(ImportedSubscriptionLine."Billing Base Period", '<1M>');
        Evaluate(ImportedSubscriptionLine."Billing Rhythm", '<1M>');
        ImportedSubscriptionLine.Insert(true);

        // [WHEN] The SubscriptionLines stage runs
        ResponseJson := RunImport('["SubscriptionLines"]', false);

        // [THEN] The row succeeds and a real Subscription Line exists for it
        StageJson := GetStage(ResponseJson, 0);
        Assert.AreEqual(1, ReadInteger(StageJson, 'succeeded'), 'An Item row must create its Subscription Line.');
        Assert.AreEqual(0, ReadInteger(StageJson, 'failed'), 'An Item row must not fail.');
        ImportedSubscriptionLine.Get(ImportedSubscriptionLine."Entry No.");
        Assert.IsTrue(ImportedSubscriptionLine."Subscription Line created", 'The staged row must be marked as created.');
        Assert.AreNotEqual(0, ImportedSubscriptionLine."Subscription Line Entry No.", 'The staged row must point to its Subscription Line.');
        Assert.IsTrue(SubscriptionLine.Get(ImportedSubscriptionLine."Subscription Line Entry No."), 'The Subscription Line must exist.');
        Assert.AreEqual(SubscriptionHeader."No.", SubscriptionLine."Subscription Header No.", 'The line must belong to the Subscription.');
        Assert.AreEqual(WorkDate(), SubscriptionLine."Subscription Line Start Date", 'The start date must come from the staged row.');
    end;

    [Test]
    procedure Scenario_AC03_Contract_DocumentsAllowCommentLines()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
        Parameter: JsonToken;
        Found: Boolean;
    begin
        // Issue #39, AC03 | Time: none | Risk: None
        // [WHEN] The contract of the type is read
        Initialize();
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Import.CreateContracts", Contract);

        // [THEN] It documents the allowCommentLines opt-in as an optional boolean that defaults to false
        Contract.Get('parameters', Token);
        foreach Parameter in Token.AsArray() do
            if ReadText(Parameter.AsObject(), 'name') = 'allowCommentLines' then begin
                Found := true;
                Assert.AreEqual('boolean', ReadText(Parameter.AsObject(), 'type'), 'allowCommentLines must be a boolean.');
                Parameter.AsObject().Get('default', Token);
                Assert.IsFalse(Token.AsValue().AsBoolean(), 'allowCommentLines must default to false.');
            end;
        Assert.IsTrue(Found, 'The parameters chapter must document allowCommentLines.');
    end;

    local procedure Initialize()
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
    begin
        TestLibrary.InitSubscriptionBilling();
        ImportedSubscriptionLine.DeleteAll(false);
    end;

    local procedure StageCommentLine(var ImportedSubscriptionLine: Record "Imported Subscription Line"; ContractNo: Code[20])
    begin
        ImportedSubscriptionLine.Init();
        ImportedSubscriptionLine.Partner := Enum::"Service Partner"::Customer;
        ImportedSubscriptionLine."Subscription Contract No." := ContractNo;
        ImportedSubscriptionLine."Invoicing via" := Enum::"Invoicing Via"::Contract;
        ImportedSubscriptionLine.Description := 'XIMPORT COMMENT';
        ImportedSubscriptionLine.Insert(true);
    end;

    local procedure RunImport(StagesJson: Text; AllowCommentLines: Boolean): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Sub Imp CrContr Impl ori";
        RequestJson: JsonObject;
        StagesToken: JsonToken;
    begin
        if StagesJson <> '' then begin
            StagesToken.ReadFrom(StagesJson);
            RequestJson.Add('stages', StagesToken.AsArray());
        end;
        if AllowCommentLines then
            RequestJson.Add('allowCommentLines', true);
        TempArgument.Init();
        TempArgument."Type" := Enum::"Message Type ori"::"Subscription.Import.CreateContracts";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(RequestJson);
        // The stages run Microsoft's codeunits with Codeunit.Run and use its result, which needs a committed transaction.
        Commit();
        Impl.PerformWrite(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure GetStage(ResponseJson: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
    begin
        ResponseJson.Get('stages', Token);
        Token.AsArray().Get(Index, Token);
        exit(Token.AsObject());
    end;

    local procedure FindStage(ResponseJson: JsonObject; StageName: Text): JsonObject
    var
        Token: JsonToken;
        StageToken: JsonToken;
    begin
        ResponseJson.Get('stages', Token);
        foreach StageToken in Token.AsArray() do
            if ReadText(StageToken.AsObject(), 'stage') = StageName then
                exit(StageToken.AsObject());
        Assert.Fail('Stage ' + StageName + ' is missing from the response.');
    end;

    local procedure GetError(ResponseJson: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
    begin
        ResponseJson.Get('errors', Token);
        Token.AsArray().Get(Index, Token);
        exit(Token.AsObject());
    end;

    local procedure ReadInteger(Json: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Json.Get(Name, Token);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadText(Json: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Json.Get(Name, Token);
        exit(Token.AsValue().AsText());
    end;
}
