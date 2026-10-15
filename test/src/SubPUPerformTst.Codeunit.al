namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// #45 AC02, AC06: Subscription.PriceUpdate.Perform. The perform tests of Microsoft's
/// "Contract Price Proposal Test" (codeunit 139690, BCApps releases/28.x a674a13) that need no posting,
/// ported onto this app's copy through the public dispatcher with the same assertions, plus the refusals,
/// the template filter, the committing path and a failed line.
/// </summary>
codeunit 95743 "Sub PU Perform Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryRandom: Codeunit "Library - Random";
        TestLib: Codeunit "Sub PU Test Lib ori";

    [Test]
    procedure Perform_DeletesTheProposalLines()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
    begin
        // Port of TestIfContractPriceUpdateLinesAreDeletedAfterPerformPriceUpdate | #45 AC02 | Time: WorkDate-relative | Risk: None
        // [GIVEN] A Recent Item Prices proposal one month ahead.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Recent Item Prices", 0, CalcDate('<1M>', WorkDate()), CalcDate('<1M>', WorkDate()));
        // [WHEN] It is performed.
        ResponseJson := TestLib.InvokePerform('', true);
        // [THEN] No proposal line is left.
        TestLib.AssertSuccess(ResponseJson, 'Perform must succeed.');
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure Perform_FuturePerformDate_WritesPlannedSubscriptionLines()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        TempContractPriceUpdateLine: Record "Sub. Contr. Price Update Line" temporary;
        PlannedSubscriptionLine: Record "Planned Subscription Line";
        PriceUpdateTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
    begin
        // Port of TestPlannedServiceCommitmentAfterPerformPriceUpdate | #45 AC02 | Time: WorkDate-relative | Risk: None
        // [GIVEN] A proposal whose Perform Update On is after the lines' Next Billing Date.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Recent Item Prices", 0, CalcDate('<2M>', WorkDate()), CalcDate('<1M>', WorkDate()));
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindSet();
        repeat
            TempContractPriceUpdateLine := ContractPriceUpdateLine;
            TempContractPriceUpdateLine.Insert(false);
        until ContractPriceUpdateLine.Next() = 0;
        // [WHEN] It is performed.
        ResponseJson := TestLib.InvokePerform(PriceUpdateTemplate.Code, true);
        // [THEN] Every line got a Planned Subscription Line carrying the new prices, as Microsoft writes it.
        Assert.AreEqual(TempContractPriceUpdateLine.Count(), TestLib.ReadInteger(ResponseJson, 'plannedSubscriptionLinesCreated'), 'Every line must be planned.');
        Assert.AreEqual(0, TestLib.ReadInteger(ResponseJson, 'subscriptionLinesUpdated'), 'No line may change now.');
        TempContractPriceUpdateLine.FindSet();
        repeat
            PlannedSubscriptionLine.Get(TempContractPriceUpdateLine."Subscription Line Entry No.");
            PlannedSubscriptionLine.TestField(Price, TempContractPriceUpdateLine."New Price");
            PlannedSubscriptionLine.TestField("Calculation Base %", TempContractPriceUpdateLine."New Calculation Base %");
            PlannedSubscriptionLine.TestField("Calculation Base Amount", TempContractPriceUpdateLine."New Calculation Base");
            PlannedSubscriptionLine.TestField(Amount, TempContractPriceUpdateLine."New Amount");
            PlannedSubscriptionLine.TestField("Next Price Update", CalcDate(PriceUpdateTemplate."Price Binding Period", TempContractPriceUpdateLine."Perform Update On"));
            PlannedSubscriptionLine.TestField("Discount %", TempContractPriceUpdateLine."Discount %");
            PlannedSubscriptionLine.TestField("Discount Amount", TempContractPriceUpdateLine."Discount Amount");
            PlannedSubscriptionLine.TestField("Type Of Update", Enum::"Type Of Price Update"::"Price Update");
            PlannedSubscriptionLine.TestField("Perform Update On", TempContractPriceUpdateLine."Perform Update On");
        until TempContractPriceUpdateLine.Next() = 0;
    end;

    [Test]
    procedure Perform_LineBilledUpToTheUpdate_UpdatesSubscriptionLineAndArchives()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        TempContractPriceUpdateLine: Record "Sub. Contr. Price Update Line" temporary;
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        TempSubscriptionLine: Record "Subscription Line" temporary;
        ResponseJson: JsonObject;
    begin
        // Port of TestServiceCommitmentAfterPerformPriceUpdate | #45 AC02 | Time: WorkDate-relative | Risk: None
        // Microsoft bills the lines up to the update first; here their Next Billing Date is set beyond the update
        // date, the state that billing leaves, so no posting is needed.
        // [GIVEN] A Calculation Base by % proposal that takes effect on or before the lines' Next Billing Date.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Calculation Base by %", LibraryRandom.RandDec(100, 2), WorkDate(), CalcDate('<1M>', WorkDate()));
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindSet();
        repeat
            TempContractPriceUpdateLine := ContractPriceUpdateLine;
            TempContractPriceUpdateLine.Insert(false);
            SubscriptionLine.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
            TempSubscriptionLine := SubscriptionLine;
            TempSubscriptionLine.Insert(false);
        until ContractPriceUpdateLine.Next() = 0;
        // [WHEN] It is performed.
        ResponseJson := TestLib.InvokePerform(PriceUpdateTemplate.Code, true);
        // [THEN] The Subscription Lines carry the new prices and one archive entry each with the old ones.
        Assert.AreEqual(TempContractPriceUpdateLine.Count(), TestLib.ReadInteger(ResponseJson, 'subscriptionLinesUpdated'), 'Every line must update now.');
        TempContractPriceUpdateLine.FindSet();
        repeat
            SubscriptionLine.Get(TempContractPriceUpdateLine."Subscription Line Entry No.");
            SubscriptionLine.TestField(Price, TempContractPriceUpdateLine."New Price");
            SubscriptionLine.TestField("Calculation Base %", TempContractPriceUpdateLine."New Calculation Base %");
            SubscriptionLine.TestField("Calculation Base Amount", TempContractPriceUpdateLine."New Calculation Base");
            SubscriptionLine.TestField(Amount, TempContractPriceUpdateLine."New Amount");
            SubscriptionLine.TestField("Next Price Update", TempContractPriceUpdateLine."Next Price Update");
            SubscriptionLine.TestField("Discount %", TempContractPriceUpdateLine."Discount %");
            SubscriptionLine.TestField("Discount Amount", TempContractPriceUpdateLine."Discount Amount");
            TempSubscriptionLine.Get(SubscriptionLine."Entry No.");
            AssertArchivedOnce(TempSubscriptionLine, CalcDate('<-1D>', TempContractPriceUpdateLine."Perform Update On"));
        until TempContractPriceUpdateLine.Next() = 0;
    end;

    [Test]
    procedure Perform_LineWithPlannedLine_IsSkippedAndDeleted()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PlannedSubscriptionLine: Record "Planned Subscription Line";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        OldPrice: Decimal;
        ResponseJson: JsonObject;
    begin
        // #45 AC02 edge case (codeunit 8013 exits when a Planned Subscription Line exists) | Time: WorkDate-relative | Risk: None
        // [GIVEN] A proposal, after which one of its Subscription Lines got a Planned Subscription Line.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Price by %", 10, WorkDate(), CalcDate('<1M>', WorkDate()));
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindFirst();
        SubscriptionLine.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
        OldPrice := SubscriptionLine.Price;
        PlannedSubscriptionLine.TransferFields(SubscriptionLine);
        PlannedSubscriptionLine.Insert(false);
        // [WHEN] The proposal is performed.
        ResponseJson := TestLib.InvokePerform(PriceUpdateTemplate.Code, true);
        // [THEN] That line is unchanged, its price update line is gone, and the answer counts it as skipped.
        Assert.AreEqual(1, TestLib.ReadInteger(ResponseJson, 'linesSkipped'), 'The line with a Planned Subscription Line must be skipped.');
        SubscriptionLine.Get(SubscriptionLine."Entry No.");
        Assert.AreEqual(OldPrice, SubscriptionLine.Price, 'A skipped line must keep its price.');
        ContractPriceUpdateLine.Reset();
        ContractPriceUpdateLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure Perform_WithTemplate_LeavesOtherTemplatesLines()
    var
        FirstContract: Record "Customer Subscription Contract";
        SecondContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        FirstTemplate: Record "Price Update Template";
        SecondTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
    begin
        // #45 AC02, Origo addition: the optional template filter | Time: WorkDate-relative | Risk: None
        // [GIVEN] Proposals under two templates.
        SeedAndPropose(FirstContract, FirstTemplate, Enum::"Price Update Method"::"Price by %", 10, WorkDate(), CalcDate('<1M>', WorkDate()));
        SeedContractAndProposeAgain(SecondContract, SecondTemplate);
        // [WHEN] Only the first template is performed.
        ResponseJson := TestLib.InvokePerform(FirstTemplate.Code, true);
        // [THEN] Only its lines are gone.
        Assert.AreEqual(FirstTemplate.Code, TestLib.ReadText(ResponseJson, 'priceUpdateTemplateCode'), 'The answer must name the template.');
        ContractPriceUpdateLine.SetRange("Price Update Template Code", FirstTemplate.Code);
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
        ContractPriceUpdateLine.SetRange("Price Update Template Code", SecondTemplate.Code);
        Assert.RecordIsNotEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure Perform_CommittingRun_KeepsAFailedLineAndAnswersError()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        BrokenLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateTemplate: Record "Price Update Template";
        ResponseJson: JsonObject;
    begin
        // #45 AC02 (PerformPriceUpdate keeps a line whose Codeunit.Run fails) | Time: WorkDate-relative | Risk: commits inside the test
        // [GIVEN] A proposal plus one line whose Subscription Line does not exist.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Price by %", 10, WorkDate(), CalcDate('<1M>', WorkDate()));
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        ContractPriceUpdateLine.FindFirst();
        BrokenLine := ContractPriceUpdateLine;
        BrokenLine."Entry No." := 0;
        BrokenLine."Subscription Line Entry No." := 2147483647;
        BrokenLine.Insert(false);
        Commit(); // Microsoft's tests commit before PerformPriceUpdate too.
        // [WHEN] The committing path performs the proposal.
        ResponseJson := TestLib.InvokePerform(PriceUpdateTemplate.Code, false);
        // [THEN] The good lines are performed, the broken one stays, and the answer is a structured Error.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'A failed line must make the answer an Error.');
        Assert.AreEqual(1, TestLib.ReadInteger(ResponseJson, 'linesFailed'), 'One line failed.');
        Assert.AreEqual('false', TestLib.ReadText(ResponseJson, 'rolledBack'), 'Committed lines are not rolled back.');
        Assert.AreEqual(1, ContractPriceUpdateLine.Count(), 'Only the failed line may be left.');
        ContractPriceUpdateLine.FindFirst();
        Assert.AreEqual(2147483647, ContractPriceUpdateLine."Subscription Line Entry No.", 'The failed line must be the one left.');
    end;

    [Test]
    procedure Perform_EmptyProposal_IsRefused()
    var
        ResponseJson: JsonObject;
    begin
        // #45 AC02 refusal | Time: none | Risk: None
        // [GIVEN] No proposal lines at all.
        TestLib.Initialize();
        // [WHEN] Perform is called.
        ResponseJson := TestLib.InvokePerform('', true);
        // [THEN] It is refused and says what to do.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'An empty proposal must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains('Subscription.PriceUpdate.CreateProposal'), 'The error must point to CreateProposal.');
    end;

    [Test]
    procedure Perform_TemplateWithoutLines_IsRefused()
    var
        CustomerContract: Record "Customer Subscription Contract";
        PriceUpdateTemplate: Record "Price Update Template";
        EmptyTemplate: Record "Price Update Template";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        ResponseJson: JsonObject;
    begin
        // #45 AC02 refusal | Time: WorkDate-relative | Risk: None
        // [GIVEN] Lines under one template and none under another.
        SeedAndPropose(CustomerContract, PriceUpdateTemplate, Enum::"Price Update Method"::"Price by %", 10, WorkDate(), CalcDate('<1M>', WorkDate()));
        TestLib.CreatePriceUpdateTemplate(EmptyTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 1, '<0D>', '<1Y>', '<12M>');
        // [WHEN] The empty template is performed.
        ResponseJson := TestLib.InvokePerform(EmptyTemplate.Code, true);
        // [THEN] It is refused and the other template's lines are untouched.
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'A template without lines must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains(EmptyTemplate.Code), 'The error must name the template.');
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplate.Code);
        Assert.RecordIsNotEmpty(ContractPriceUpdateLine);
    end;

    [Test]
    procedure Perform_UnknownTemplate_IsRefused()
    var
        ResponseJson: JsonObject;
    begin
        // #45 AC06 refusal | Time: none | Risk: None
        TestLib.Initialize();
        ResponseJson := TestLib.InvokePerform('XPUNOSUCHTEMPLATE', true);
        Assert.AreEqual('Error', TestLib.ReadText(ResponseJson, 'status'), 'An unknown template must be refused.');
        Assert.IsTrue(TestLib.ReadText(ResponseJson, 'error').Contains('XPUNOSUCHTEMPLATE'), 'The error must name the template.');
    end;

    local procedure SeedAndPropose(var CustomerContract: Record "Customer Subscription Contract"; var PriceUpdateTemplate: Record "Price Update Template"; PriceUpdateMethod: Enum "Price Update Method"; UpdateValuePct: Decimal; PerformUpdateOnDate: Date; NextBillingDate: Date)
    var
        ResponseJson: JsonObject;
    begin
        TestLib.Initialize();
        SeedContract(CustomerContract, NextBillingDate);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, PriceUpdateMethod, UpdateValuePct, '<12M>', '<24M>', '<12M>');
        CustomerContract.SetRange("No.", CustomerContract."No.");
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), CustomerContract.GetView(false));
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate()), PerformUpdateOnDate);
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'The fixture must propose both lines.');
    end;

    local procedure SeedContractAndProposeAgain(var CustomerContract: Record "Customer Subscription Contract"; var PriceUpdateTemplate: Record "Price Update Template")
    var
        ResponseJson: JsonObject;
    begin
        SeedContract(CustomerContract, CalcDate('<1M>', WorkDate()));
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 3, '<0D>', '<24M>', '<12M>');
        CustomerContract.SetRange("No.", CustomerContract."No.");
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), CustomerContract.GetView(false));
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, 0D, WorkDate());
        Assert.AreEqual(2, TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'The second fixture must propose both lines.');
    end;

    local procedure SeedContract(var CustomerContract: Record "Customer Subscription Contract"; NextBillingDate: Date)
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        TestLib.CreateCustomer(Customer);
        TestLib.CreateItem(Item, LibraryRandom.RandDecInRange(100, 1000, 2), LibraryRandom.RandDecInRange(10, 100, 2));
        TestLib.CreateCustomerContract(CustomerContract, Customer);
        TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, Customer."No.", LibraryRandom.RandDecInRange(1, 10, 2));
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", LibraryRandom.RandDecInRange(100, 1000, 1), 100, LibraryRandom.RandDec(50, 1), NextBillingDate, 0D);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", LibraryRandom.RandDecInRange(100, 1000, 1), 100, LibraryRandom.RandDec(50, 1), NextBillingDate, 0D);
    end;

    local procedure AssertArchivedOnce(OldSubscriptionLine: Record "Subscription Line"; ExpectedPerformUpdateOn: Date)
    var
        SubscriptionLineArchive: Record "Subscription Line Archive";
    begin
        // Port of TestIfArchivedServiceCommitmentIsCreated, plus Perform Update On.
        SubscriptionLineArchive.SetRange("Original Entry No.", OldSubscriptionLine."Entry No.");
        Assert.AreEqual(1, SubscriptionLineArchive.Count(), 'Service commitment was not archived properly on after perform price update');
        SubscriptionLineArchive.FindLast();
        SubscriptionLineArchive.TestField(Price, OldSubscriptionLine.Price);
        SubscriptionLineArchive.TestField(Amount, OldSubscriptionLine.Amount);
        SubscriptionLineArchive.TestField("Calculation Base %", OldSubscriptionLine."Calculation Base %");
        SubscriptionLineArchive.TestField("Calculation Base Amount", OldSubscriptionLine."Calculation Base Amount");
        SubscriptionLineArchive.TestField("Type Of Update", Enum::"Type Of Price Update"::"Price Update");
        SubscriptionLineArchive.TestField("Perform Update On", ExpectedPerformUpdateOn);
    end;
}
