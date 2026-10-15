namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.Currency;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.Asset;
using Microsoft.Pricing.Calculation;
using Microsoft.Pricing.PriceList;
using Microsoft.Pricing.Source;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// #45 AC01, AC06: Subscription.PriceUpdate.CreateProposal. The proposal tests of Microsoft's
/// "Contract Price Proposal Test" (codeunit 139690, BCApps releases/28.x a674a13) ported onto this app's
/// copy through the public dispatcher, with the same assertions, plus the refusals and edge cases of the
/// message type itself.
/// </summary>
codeunit 95742 "Sub PU Proposal Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryRandom: Codeunit "Library - Random";
        TestLib: Codeunit "Sub PU Test Lib ori";

    [Test]
    procedure CreateProposal_CalculationBaseByPercentage()
    var
        Currency: Record Currency;
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        NewDiscountAmount: Decimal;
        NewServiceAmount: Decimal;
    begin
        // Port of CreateContractPriceUpdateProposalCalculationBaseByPercentage | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Customer Subscription Lines and a Calculation Base by % template.
        CreateProposalForCustomerLines(PriceUpdateTemplate, Enum::"Price Update Method"::"Calculation Base by %", LibraryRandom.RandDec(100, 2));
        // [THEN] Every line keeps the old base and takes the template's percentage, rounded as Microsoft rounds.
        Currency.InitRoundingPrecision();
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindSet();
        repeat
            SubscriptionLine.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
            AssertOldValues(ContractPriceUpdateLine, SubscriptionLine);
            ContractPriceUpdateLine.TestField("New Calculation Base %", PriceUpdateTemplate."Update Value %");
            ContractPriceUpdateLine.TestField("New Calculation Base", ContractPriceUpdateLine."Old Calculation Base");
            Assert.AreNearlyEqual(Round(ContractPriceUpdateLine."New Calculation Base" * ContractPriceUpdateLine."New Calculation Base %" / 100, Currency."Unit-Amount Rounding Precision"), ContractPriceUpdateLine."New Price", 0.01, 'New Price was not calculated properly');
            ContractPriceUpdateLine.TestField("Additional Amount", ContractPriceUpdateLine."New Amount" - ContractPriceUpdateLine."Old Amount");
            NewServiceAmount := Round(ContractPriceUpdateLine."New Price" * ContractPriceUpdateLine.Quantity, Currency."Amount Rounding Precision");
            NewDiscountAmount := Round(ContractPriceUpdateLine."Discount %" * NewServiceAmount / 100, Currency."Amount Rounding Precision");
            Assert.AreEqual(Round(ContractPriceUpdateLine."Discount Amount", Currency."Amount Rounding Precision"), NewDiscountAmount, 'Discount Amount was not calculated properly');
            Assert.AreEqual(NewServiceAmount - NewDiscountAmount, ContractPriceUpdateLine."New Amount", 'New Service Amount was not calculated properly');
        until ContractPriceUpdateLine.Next() = 0;
    end;

    [Test]
    procedure CreateProposal_PriceByPercentage()
    var
        Currency: Record Currency;
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        NewDiscountAmount: Decimal;
        NewServiceAmount: Decimal;
    begin
        // Port of CreateContractPriceUpdateProposalPriceByPercentage | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Customer Subscription Lines and a Price by % template.
        CreateProposalForCustomerLines(PriceUpdateTemplate, Enum::"Price Update Method"::"Price by %", LibraryRandom.RandDec(100, 2));
        // [THEN] Base and price rise by the percentage; the base % stays.
        Currency.InitRoundingPrecision();
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindSet();
        repeat
            SubscriptionLine.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
            AssertOldValues(ContractPriceUpdateLine, SubscriptionLine);
            ContractPriceUpdateLine.TestField("New Calculation Base %", ContractPriceUpdateLine."Old Calculation Base %");
            ContractPriceUpdateLine.TestField("New Calculation Base", Round(ContractPriceUpdateLine."Old Calculation Base" + ContractPriceUpdateLine."Old Calculation Base" * PriceUpdateTemplate."Update Value %" / 100, Currency."Amount Rounding Precision"));
            ContractPriceUpdateLine.TestField("New Price", Round(ContractPriceUpdateLine."Old Price" + ContractPriceUpdateLine."Old Price" * PriceUpdateTemplate."Update Value %" / 100, Currency."Unit-Amount Rounding Precision"));
            ContractPriceUpdateLine.TestField("Additional Amount", ContractPriceUpdateLine."New Amount" - ContractPriceUpdateLine."Old Amount");
            NewServiceAmount := Round(ContractPriceUpdateLine."New Price" * ContractPriceUpdateLine.Quantity, Currency."Amount Rounding Precision");
            NewDiscountAmount := Round(ContractPriceUpdateLine."Discount %" * NewServiceAmount / 100, Currency."Amount Rounding Precision");
            Assert.AreEqual(Round(ContractPriceUpdateLine."Discount Amount", Currency."Amount Rounding Precision"), NewDiscountAmount, 'Discount Amount was not calculated properly');
            Assert.AreEqual(NewServiceAmount - NewDiscountAmount, ContractPriceUpdateLine."New Amount", '"New Service Amount" was not calculated properly');
        until ContractPriceUpdateLine.Next() = 0;
    end;

    [Test]
    procedure CreateProposal_RecentItemPrices()
    var
        Currency: Record Currency;
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        NewDiscountAmount: Decimal;
        NewServiceAmount: Decimal;
    begin
        // Port of CreateContractPriceUpdateProposalRecentItemPrices | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Customer Subscription Lines and a Recent Item Prices template.
        CreateProposalForCustomerLines(PriceUpdateTemplate, Enum::"Price Update Method"::"Recent Item Prices", 0);
        // [THEN] The base is read again from the item price; the base % stays.
        Currency.InitRoundingPrecision();
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindSet();
        repeat
            SubscriptionLine.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
            AssertOldValues(ContractPriceUpdateLine, SubscriptionLine);
            ContractPriceUpdateLine.TestField("New Calculation Base %", ContractPriceUpdateLine."Old Calculation Base %");
            ContractPriceUpdateLine.TestField("New Price", Round(ContractPriceUpdateLine."New Calculation Base" * ContractPriceUpdateLine."New Calculation Base %" / 100, Currency."Unit-Amount Rounding Precision"));
            ContractPriceUpdateLine.TestField("Additional Amount", ContractPriceUpdateLine."New Amount" - ContractPriceUpdateLine."Old Amount");
            NewServiceAmount := Round(ContractPriceUpdateLine."New Price" * ContractPriceUpdateLine.Quantity, Currency."Amount Rounding Precision");
            NewDiscountAmount := Round(ContractPriceUpdateLine."Discount %" * NewServiceAmount / 100, Currency."Amount Rounding Precision");
            Assert.AreEqual(Round(ContractPriceUpdateLine."Discount Amount", Currency."Amount Rounding Precision"), NewDiscountAmount, 'Discount Amount was not calculated properly');
            Assert.AreEqual(NewServiceAmount - NewDiscountAmount, ContractPriceUpdateLine."New Amount", '"New Service Amount" was not calculated properly');
        until ContractPriceUpdateLine.Next() = 0;
    end;

    [Test]
    procedure CreateProposal_TemplateFilters()
    var
        ContractType: Record "Subscription Contract Type";
        CustomerContract: Record "Customer Subscription Contract";
        DummyContract: Record "Customer Subscription Contract";
        DummyLine: Record "Subscription Line";
        DummyHeader: Record "Subscription Header";
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        LineFilterText: Text;
        HeaderFilterText: Text;
        BadHeaderFilterText: Text;
        ContractFilterText: Text;
        CustomerOnlyFilterText: Text;
        SerialNo: Code[50];
        i: Integer;
    begin
        // Port of TestContractPriceUpdateTemplateFilters | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] 12 contracts with one line each: every 2nd contract has a contract type, every 3rd subscription
        // a serial number, every 4th line an end date.
        TestLib.Initialize();
        ContractType.Init();
        ContractType.Code := 'XPUCTYPE';
        ContractType.Description := 'X price update';
        if not ContractType.Insert(false) then;
        SerialNo := 'XPUSERIAL';
        TestLib.CreateCustomer(Customer);
        TestLib.CreateItem(Item, 100, 50);
        for i := 1 to 12 do begin
            TestLib.CreateCustomerContract(CustomerContract, Customer);
            if i mod 2 = 0 then begin
                CustomerContract."Contract Type" := ContractType.Code;
                CustomerContract.Modify(false);
            end;
            TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, Customer."No.", 1);
            if i mod 3 = 0 then begin
                SubscriptionHeader."Serial No." := SerialNo;
                SubscriptionHeader.Modify(false);
            end;
            TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 100, 100, 0, CalcDate('<1M>', WorkDate()), 0D);
            if i mod 4 = 0 then begin
                SubscriptionLine."Subscription Line End Date" := 99991231D;
                SubscriptionLine.Modify(false);
            end;
        end;
        DummyLine.SetRange("Subscription Line End Date", 99991231D);
        LineFilterText := DummyLine.GetView(false);
        DummyHeader.SetRange("Serial No.", SerialNo);
        HeaderFilterText := DummyHeader.GetView(false);
        DummyHeader.SetRange("Source No.", 'XPUNOSUCHITEM');
        BadHeaderFilterText := DummyHeader.GetView(false);
        // Every case is limited to this test's customer, so lines other tests left behind cannot match.
        DummyContract.SetRange("Sell-to Customer No.", Customer."No.");
        CustomerOnlyFilterText := DummyContract.GetView(false);
        DummyContract.SetRange("Contract Type", ContractType.Code);
        ContractFilterText := DummyContract.GetView(false);

        // [WHEN] Templates with every combination of filters create proposals. [THEN] Microsoft's expected counts.
        AssertFilteredProposalCount(CustomerOnlyFilterText, '', '', 12);
        AssertFilteredProposalCount(ContractFilterText, '', '', 6);
        AssertFilteredProposalCount(CustomerOnlyFilterText, LineFilterText, '', 3);
        AssertFilteredProposalCount(CustomerOnlyFilterText, '', HeaderFilterText, 4);
        AssertFilteredProposalCount(ContractFilterText, LineFilterText, '', 3);
        AssertFilteredProposalCount(ContractFilterText, '', HeaderFilterText, 2);
        AssertFilteredProposalCount(CustomerOnlyFilterText, LineFilterText, HeaderFilterText, 1);
        AssertFilteredProposalCount(ContractFilterText, LineFilterText, HeaderFilterText, 1);
        AssertFilteredProposalCount(CustomerOnlyFilterText, '', BadHeaderFilterText, 0);
    end;

    [Test]
    procedure CreateProposal_LineWithoutNextPriceUpdate_IsIncluded()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
    begin
        // Port of TestIfServiceCommitmentWithoutNextPriceUpdateIsIncludedInContractPriceUpdateProposal | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Lines whose Next Price Update is empty.
        TestLib.Initialize();
        SeedContractWithLines(CustomerContract, 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Calculation Base by %", LibraryRandom.RandDec(100, 2), '<12M>', '<12M>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        // [WHEN] The proposal is created with the template's own dates.
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, 0D);
        // [THEN] The lines are proposed.
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        Assert.RecordIsNotEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure CreateProposal_ClosedLine_IsNotIncluded()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
    begin
        // Port of TestPriceUpdateProposalWithClosedServiceCommitment | #45 AC01 | Time: WorkDate-relative | Risk: None
        // [GIVEN] A contract whose first line is closed.
        TestLib.Initialize();
        SeedContractWithLines(CustomerContract, 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Calculation Base by %", LibraryRandom.RandDec(100, 2), '<12M>', '<12M>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        SubscriptionLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        SubscriptionLine.FindFirst();
        SubscriptionLine.Closed := true;
        SubscriptionLine.Modify(false);
        // [WHEN] The proposal is created.
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate()), WorkDate());
        // [THEN] The closed line is not proposed, the open one is.
        ContractPriceUpdateLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
        ContractPriceUpdateLine.SetRange("Subscription Line Entry No.");
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        Assert.RecordIsNotEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure UT_UpdatePerformUpdateOn_TakesLatestDate()
    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        SubscriptionLine: Record "Subscription Line";
        LineMgt: Codeunit "Sub PU Line Mgt ori";
        PerformUpdateOn: Date;
    begin
        // Port of UT_ContractPriceUpdateLine_UpdatePerformUpdateOn | #45 AC01 | Time: random dates | Risk: None
        // [GIVEN] A line whose Next Billing Date, Next Price Update and the requested date are increasing.
        SubscriptionLine.Init();
        SubscriptionLine."Next Billing Date" := LibraryRandom.RandDateFrom(WorkDate(), 12);
        SubscriptionLine."Next Price Update" := LibraryRandom.RandDateFrom(SubscriptionLine."Next Billing Date", 12);
        PerformUpdateOn := LibraryRandom.RandDateFrom(SubscriptionLine."Next Price Update", 12);
        // [WHEN] / [THEN] The latest date wins; without a requested date, the Next Price Update.
        LineMgt.UpdatePerformUpdateOn(ContractPriceUpdateLine, SubscriptionLine, PerformUpdateOn);
        Assert.AreEqual(PerformUpdateOn, ContractPriceUpdateLine."Perform Update On", 'UpdatePerformUpdateOn did not return correct value');
        LineMgt.UpdatePerformUpdateOn(ContractPriceUpdateLine, SubscriptionLine, 0D);
        Assert.AreEqual(SubscriptionLine."Next Price Update", ContractPriceUpdateLine."Perform Update On", 'UpdatePerformUpdateOn did not return correct value');
    end;

    [Test]
    [HandlerFunctions('ConfirmHandlerYes')]
    procedure CreateProposal_RecentItemPrices_UsesPriceOfSubscriptionUnitOfMeasure()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        UnitOfMeasure: Record "Unit of Measure";
        PriceListHeader: Record "Price List Header";
        PriceListLine: Record "Price List Line";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPriceCalculation: Codeunit "Library - Price Calculation";
    begin
        // Port of CreateCustomerPriceUpdateProposalUsesPriceOfSubscriptionUnitOfMeasure (scenario 648553, BCApps 28.7) | #45 AC01 | Time: WorkDate-relative | Risk: price setup
        // [GIVEN] A subscription in a unit of measure other than the base one, and a sales price list with a lower
        // price for the base unit of measure and a higher one for the subscription's.
        TestLib.Initialize();
        TestLib.CreateCustomer(Customer);
        LibraryPriceCalculation.EnableExtendedPriceCalculation();
        LibraryPriceCalculation.SetupDefaultHandler(Enum::"Price Calculation Handler"::"Business Central (Version 16.0)");
        TestLib.CreateItem(Item, 5, 1);
        LibraryInventory.CreateUnitOfMeasureCode(UnitOfMeasure);
        LibraryInventory.CreateItemUnitOfMeasure(ItemUnitOfMeasure, Item."No.", UnitOfMeasure.Code, 1);
        TestLib.CreateCustomerContract(CustomerContract, Customer);
        TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, Customer."No.", 1);
        SubscriptionHeader."Unit of Measure" := ItemUnitOfMeasure.Code;
        SubscriptionHeader.Modify(false);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 10, 100, 0, CalcDate('<1M>', WorkDate()), 0D);
        LibraryPriceCalculation.CreatePriceHeader(PriceListHeader, "Price Type"::Sale, "Price Source Type"::"All Customers", '');
        LibraryPriceCalculation.CreateSalesPriceLine(PriceListLine, PriceListHeader.Code, "Price Source Type"::"All Customers", '', "Price Asset Type"::Item, Item."No.");
        PriceListLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
        PriceListLine.Validate("Unit Price", 10);
        PriceListLine.Modify(true);
        LibraryPriceCalculation.CreateSalesPriceLine(PriceListLine, PriceListHeader.Code, "Price Source Type"::"All Customers", '', "Price Asset Type"::Item, Item."No.");
        PriceListLine.Validate("Unit of Measure Code", ItemUnitOfMeasure.Code);
        PriceListLine.Validate("Unit Price", 100);
        PriceListLine.Modify(true);
        PriceListHeader.Validate(Status, PriceListHeader.Status::Active);
        PriceListHeader.Modify(true);
        // [WHEN] The proposal is created with Recent Item Prices.
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Recent Item Prices", 0, '<12M>', '<12M>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate()), WorkDate());
        // [THEN] The new base is the price of the subscription's unit of measure.
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindFirst();
        Assert.AreEqual(100, ContractPriceUpdateLine."New Calculation Base", 'New Calculation Base must equal the sales price of the Subscription unit of measure');
    end;

    [Test]
    procedure CreateProposal_Response_ReportsCreatedLinesAndDates()
    var
        CustomerContract: Record "Customer Subscription Contract";
        PriceUpdateTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
        LinesToken: JsonToken;
    begin
        // #45 AC01, AC06 | Time: WorkDate-relative | Risk: None
        // [GIVEN] A contract with two eligible lines.
        TestLib.Initialize();
        SeedContractWithLines(CustomerContract, 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 5, '<1M>', '<1Y>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        // [WHEN] The proposal is created with the template's own dates.
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, 0D);
        // [THEN] The answer names the template, the dates the page would use, and both lines.
        TestLib.AssertSuccess(ResponseJson, 'The proposal must succeed.');
        Assert.AreEqual(PriceUpdateTemplate.Code, TestLib.ReadText(ResponseJson, 'priceUpdateTemplateCode'), 'Wrong template.');
        Assert.AreEqual('Price by %', TestLib.ReadText(ResponseJson, 'priceUpdateMethod'), 'The method must be the enum value name.');
        Assert.AreEqual(Format(CalcDate('<1Y>', WorkDate()), 0, 9), TestLib.ReadText(ResponseJson, 'includeLinesUpToDate'), 'The include date must default to the template formula.');
        Assert.AreEqual(Format(CalcDate('<1M>', WorkDate()), 0, 9), TestLib.ReadText(ResponseJson, 'performUpdateOnDate'), 'The perform date must default to the template formula.');
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'Both lines must be created.');
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'proposalLineCount'), 'Both lines must stand in the proposal.');
        ResponseJson.Get('lines', LinesToken);
        Assert.AreEqual(2, LinesToken.AsArray().Count(), 'Both lines must be listed.');
    end;

    [Test]
    procedure CreateProposal_SecondRun_SkipsLinesAlreadyProposed()
    var
        CustomerContract: Record "Customer Subscription Contract";
        PriceUpdateTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
    begin
        // #45 AC01 edge case | Time: WorkDate-relative | Risk: None
        // [GIVEN] A proposal already created for the lines.
        TestLib.Initialize();
        SeedContractWithLines(CustomerContract, 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 5, '<0D>', '<1Y>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, 0D);
        // [WHEN] It is created again.
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, 0D);
        // [THEN] Nothing new is created, as Microsoft skips lines that already have a price update line; the answer says why.
        TestLib.AssertSuccess(ResponseJson, 'An empty run is still a success.');
        Assert.AreEqual(0, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'No line may be proposed twice.');
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'proposalLineCount'), 'The earlier lines must stand.');
        Assert.AreNotEqual('', TestLib.ReadText(ResponseJson, 'message'), 'An empty run must explain itself.');
    end;

    [Test]
    procedure CreateProposal_ZeroItemPrice_CountsLineNotCreated()
    var
        Customer: Record Customer;
        CustomerContract: Record "Customer Subscription Contract";
        Item: Record Item;
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
    begin
        // #45 AC01 edge case (Microsoft's "line not created" notification) | Time: WorkDate-relative | Risk: None
        // [GIVEN] An item whose current price is zero.
        TestLib.Initialize();
        TestLib.CreateCustomer(Customer);
        TestLib.CreateItem(Item, 0, 0);
        TestLib.CreateCustomerContract(CustomerContract, Customer);
        TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, Customer."No.", 1);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 10, 100, 0, CalcDate('<1M>', WorkDate()), 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Recent Item Prices", 0, '<0D>', '<1Y>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        // [WHEN] The proposal is created.
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, 0D);
        // [THEN] The line is not created and is counted instead of a notification.
        Assert.AreEqual(0, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'A zero base must not be proposed.');
        Assert.AreEqual(1, TestLib.ReadInteger(ResponseJson, 'linesNotCreated'), 'The skipped line must be counted.');
    end;

    [Test]
    procedure CreateProposal_UnknownTemplate_IsRefused()
    var
        ResponseJson: JsonObject;
    begin
        // #45 AC06 refusal | Time: none | Risk: None
        TestLib.Initialize();
        // [WHEN] A template that does not exist is named.
        ResponseJson := TestLib.InvokeCreateProposalCommitted('XPUNOSUCHTEMPLATE', 0D, 0D);
        // [THEN] A structured error names it.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'An unknown template must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains('XPUNOSUCHTEMPLATE'), 'The error must name the template.');
    end;

    [Test]
    procedure CreateProposal_NoIncludeDate_IsRefusedWithMicrosoftMessage()
    var
        PriceUpdateTemplate: Record "Price Update Template";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        ResponseJson: JsonObject;
    begin
        // #45 AC06 refusal | Time: none | Risk: None
        // [GIVEN] A template without an include-up-to formula.
        TestLib.Initialize();
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 5, '<0D>', '', '<12M>');
        // [WHEN] No includeLinesUpToDate is sent.
        ResponseJson := TestLib.InvokeCreateProposalCommitted(PriceUpdateTemplate.Code, 0D, 0D);
        // [THEN] Microsoft's own error, and nothing is written.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'A missing include date must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains('Include Contract Lines up to Date'), 'Microsoft''s message is expected.');
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure CreateProposal_InvalidDate_IsRefused()
    var
        PriceUpdateTemplate: Record "Price Update Template";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // #45 AC06 refusal | Time: none | Risk: None
        TestLib.Initialize();
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 5, '<0D>', '<1Y>', '<12M>');
        RequestJson.Add('includeLinesUpToDate', '31.12.2027');
        // [WHEN] A date is not in ISO form, and the template is given as the subject.
        Commit();
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.PriceUpdate.CreateProposal", PriceUpdateTemplate.Code, RequestJson, false);
        // [THEN] The date parameter is named.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'A non-ISO date must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains('includeLinesUpToDate'), 'The error must name the parameter.');
    end;

    local procedure CreateProposalForCustomerLines(var PriceUpdateTemplate: Record "Price Update Template"; PriceUpdateMethod: Enum "Price Update Method"; UpdateValuePct: Decimal)
    var
        CustomerContract: Record "Customer Subscription Contract";
        ResponseJson: JsonObject;
    begin
        TestLib.Initialize();
        SeedContractWithLines(CustomerContract, 0D);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, PriceUpdateMethod, UpdateValuePct, '<12M>', '<12M>', '<12M>');
        TestLib.RestrictTemplateToContract(PriceUpdateTemplate, CustomerContract."No.");
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate()), WorkDate());
        TestLib.AssertSuccess(ResponseJson, 'The proposal must succeed.');
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'Both lines must be proposed.');
    end;

    /// <summary>One customer contract with two lines of random base and discount, as Microsoft's UpdateServiceCommitmentWithAmounts leaves them.</summary>
    local procedure SeedContractWithLines(var CustomerContract: Record "Customer Subscription Contract"; NextPriceUpdate: Date)
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        TestLib.CreateCustomer(Customer);
        TestLib.CreateItem(Item, LibraryRandom.RandDec(1000, 2), LibraryRandom.RandDec(1000, 2));
        TestLib.CreateCustomerContract(CustomerContract, Customer);
        TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, Customer."No.", LibraryRandom.RandDec(10, 5));
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", LibraryRandom.RandDec(1000, 1), 100, LibraryRandom.RandDec(100, 1), CalcDate('<1M>', WorkDate()), NextPriceUpdate);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", LibraryRandom.RandDec(1000, 1), 100, LibraryRandom.RandDec(100, 1), CalcDate('<1M>', WorkDate()), NextPriceUpdate);
    end;

    local procedure AssertOldValues(ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"; SubscriptionLine: Record "Subscription Line")
    begin
        ContractPriceUpdateLine.TestField("Old Price", SubscriptionLine.Price);
        ContractPriceUpdateLine.TestField("Old Calculation Base", SubscriptionLine."Calculation Base Amount");
        ContractPriceUpdateLine.TestField("Old Calculation Base %", SubscriptionLine."Calculation Base %");
        ContractPriceUpdateLine.TestField("Old Amount", SubscriptionLine.Amount);
    end;

    local procedure AssertFilteredProposalCount(ContractFilterText: Text; LineFilterText: Text; HeaderFilterText: Text; ExpectedCount: Integer)
    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
    begin
        ContractPriceUpdateLine.DeleteAll(false);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Calculation Base by %", LibraryRandom.RandDec(100, 2), '<12M>', '<12M>', '<12M>');
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), ContractFilterText);
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Filter"), HeaderFilterText);
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Line Filter"), LineFilterText);
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate()), WorkDate());
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        Assert.AreEqual(ExpectedCount, ContractPriceUpdateLine.Count(), 'Filtering failed.');
    end;

    [ConfirmHandler]
    procedure ConfirmHandlerYes(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
