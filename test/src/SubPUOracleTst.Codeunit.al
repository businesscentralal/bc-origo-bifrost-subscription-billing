namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// #45 AC05: the oracle. Runs Microsoft's own price update logic, through the Create Proposal and Perform
/// Price Update actions of its public "Contract Price Update" page, and this app's copy of it, through the
/// public dispatcher, on the same data, and requires the same result field by field. Because the page runs
/// whatever Subscription Billing version is installed, these tests fail as soon as Microsoft changes the
/// behaviour the copy was taken from (BCApps releases/28.x, commit a674a13).
/// </summary>
codeunit 95741 "Sub PU Oracle Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub PU Test Lib ori";

    [Test]
    procedure Oracle_CreateProposal_CalculationBaseByPct_MatchesMicrosoft()
    begin
        // #45 AC01, AC05 | Time: WorkDate-relative | Risk: None
        AssertCustomerProposalMatchesMicrosoft(Enum::"Price Update Method"::"Calculation Base by %", 7.5);
    end;

    [Test]
    procedure Oracle_CreateProposal_PriceByPct_MatchesMicrosoft()
    begin
        // #45 AC01, AC05 | Time: WorkDate-relative | Risk: None
        AssertCustomerProposalMatchesMicrosoft(Enum::"Price Update Method"::"Price by %", 3.25);
    end;

    [Test]
    procedure Oracle_CreateProposal_RecentItemPrices_MatchesMicrosoft()
    begin
        // #45 AC01, AC05 | Time: WorkDate-relative | Risk: None
        AssertCustomerProposalMatchesMicrosoft(Enum::"Price Update Method"::"Recent Item Prices", 0);
    end;

    [Test]
    procedure Oracle_CreateProposal_VendorRecentItemPrices_MatchesMicrosoft()
    var
        PriceUpdateTemplate: Record "Price Update Template";
        TempMicrosoftLine: Record "Sub. Contr. Price Update Line" temporary;
        TempCopyLine: Record "Sub. Contr. Price Update Line" temporary;
        VendorContract: Record "Vendor Subscription Contract";
    begin
        // #45 AC01, AC05 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Vendor Subscription Lines on an item whose unit cost changed.
        TestLib.Initialize();
        SeedVendorScenario(VendorContract);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Vendor, Enum::"Price Update Method"::"Recent Item Prices", 0, '<0D>', '<1Y>', '<12M>');
        // [WHEN] Microsoft's page and the copy create the proposal on the same data.
        TestLib.RunMicrosoftCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempMicrosoftLine);
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempCopyLine);
        // [THEN] The proposals are identical.
        TestLib.AssertSameProposal(TempMicrosoftLine, TempCopyLine);
    end;

    [Test]
    procedure Oracle_CreateProposal_TemplateFilters_MatchMicrosoft()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SecondContract: Record "Customer Subscription Contract";
        PriceUpdateTemplate: Record "Price Update Template";
        SubscriptionLine: Record "Subscription Line";
        TempMicrosoftLine: Record "Sub. Contr. Price Update Line" temporary;
        TempCopyLine: Record "Sub. Contr. Price Update Line" temporary;
    begin
        // #45 AC01, AC05 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Two contracts, and a template whose contract and line filters keep part of one of them.
        TestLib.Initialize();
        SeedCustomerScenario(CustomerContract);
        SeedCustomerScenario(SecondContract);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Price by %", 4, '<0D>', '<1Y>', '<12M>');
        CustomerContract.SetRange("No.", CustomerContract."No.");
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), CustomerContract.GetView(false));
        SubscriptionLine.SetFilter("Calculation Base Amount", '>=%1', 100);
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Line Filter"), SubscriptionLine.GetView(false));
        // [WHEN] Microsoft's page and the copy create the proposal on the same data.
        TestLib.RunMicrosoftCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempMicrosoftLine);
        TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempCopyLine);
        // [THEN] Both select the same lines with the same prices.
        TestLib.AssertSameProposal(TempMicrosoftLine, TempCopyLine);
    end;

    [Test]
    procedure Oracle_Perform_UpdatesAndPlansLikeMicrosoft()
    var
        MicrosoftContract: Record "Customer Subscription Contract";
        CopyContract: Record "Customer Subscription Contract";
        MicrosoftTemplate: Record "Price Update Template";
        CopyTemplate: Record "Price Update Template";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        ResponseJson: JsonObject;
    begin
        // #45 AC02, AC05 | Time: WorkDate-relative | Risk: None
        // [GIVEN] Two identical contracts, each with lines that update now and lines that must be planned,
        // and two identical templates, each filtered to one of the contracts.
        TestLib.Initialize();
        SeedCustomerScenario(MicrosoftContract);
        SeedCustomerScenario(CopyContract);
        CreateContractTemplate(MicrosoftTemplate, MicrosoftContract);
        CreateContractTemplate(CopyTemplate, CopyContract);

        // [WHEN] Microsoft proposes and performs the first contract, and the copy the second.
        TestLib.RunMicrosoftCreateProposal(MicrosoftTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.RunMicrosoftPerform();
        ResponseJson := TestLib.InvokeCreateProposal(CopyTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        Assert.AreEqual('Success', TestLib.ReadText(ResponseJson, 'status'), 'The copy must create the proposal.');
        ResponseJson := TestLib.InvokePerform(CopyTemplate.Code, true);
        Assert.AreEqual('Success', TestLib.ReadText(ResponseJson, 'status'), 'The copy must perform the proposal.');

        // [THEN] Every Subscription Line, Planned Subscription Line and archive entry of the second contract equals its twin.
        ContractPriceUpdateLine.SetFilter("Price Update Template Code", '%1|%2', MicrosoftTemplate.Code, CopyTemplate.Code);
        Assert.RecordIsEmpty(ContractPriceUpdateLine);
        AssertContractsPerformedAlike(MicrosoftContract."No.", CopyContract."No.");
    end;

    local procedure AssertCustomerProposalMatchesMicrosoft(PriceUpdateMethod: Enum "Price Update Method"; UpdateValuePct: Decimal)
    var
        CustomerContract: Record "Customer Subscription Contract";
        PriceUpdateTemplate: Record "Price Update Template";
        TempMicrosoftLine: Record "Sub. Contr. Price Update Line" temporary;
        TempCopyLine: Record "Sub. Contr. Price Update Line" temporary;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] Customer Subscription Lines with different bases, discounts and dates, one of them excluded.
        TestLib.Initialize();
        SeedCustomerScenario(CustomerContract);
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, PriceUpdateMethod, UpdateValuePct, '<0D>', '<1Y>', '<12M>');
        // [WHEN] Microsoft's page creates the proposal, and then the copy creates it again on the same data.
        TestLib.RunMicrosoftCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempMicrosoftLine);
        ResponseJson := TestLib.InvokeCreateProposal(PriceUpdateTemplate.Code, CalcDate('<1Y>', WorkDate()), WorkDate());
        Assert.AreEqual(TempMicrosoftLine.Count(), TestLib.ReadInteger(ResponseJson, 'linesCreated'), 'linesCreated must count the lines created.');
        TestLib.TakeProposal(PriceUpdateTemplate.Code, TempCopyLine);
        // [THEN] The two proposals are identical, field by field.
        TestLib.AssertSameProposal(TempMicrosoftLine, TempCopyLine);
    end;

    /// <summary>
    /// One customer contract over two subscriptions: a line that can update now, a line that must be planned
    /// (Perform Update On after its Next Billing Date), a line with a later Next Price Update and an excluded line.
    /// </summary>
    local procedure SeedCustomerScenario(var CustomerContract: Record "Customer Subscription Contract")
    var
        Customer: Record Customer;
        Item: Record Item;
        FirstHeader: Record "Subscription Header";
        SecondHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        TestLib.CreateCustomer(Customer);
        TestLib.CreateItem(Item, 157.35, 61.2);
        TestLib.CreateCustomerContract(CustomerContract, Customer);
        TestLib.CreateSubscriptionHeader(FirstHeader, Item, Customer."No.", 3);
        TestLib.CreateSubscriptionHeader(SecondHeader, Item, Customer."No.", 2.5);
        TestLib.CreateSubscriptionLine(SubscriptionLine, FirstHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 123.45, 100, 10, CalcDate('<60D>', WorkDate()), 0D);
        TestLib.CreateSubscriptionLine(SubscriptionLine, FirstHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 80, 90, 0, CalcDate('<-5D>', WorkDate()), CalcDate('<-10D>', WorkDate()));
        TestLib.CreateSubscriptionLine(SubscriptionLine, SecondHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 200, 100, 5.5, CalcDate('<30D>', WorkDate()), CalcDate('<20D>', WorkDate()));
        TestLib.CreateSubscriptionLine(SubscriptionLine, SecondHeader, Enum::"Service Partner"::Customer, CustomerContract."No.", 50, 100, 0, CalcDate('<30D>', WorkDate()), 0D);
        SubscriptionLine."Exclude from Price Update" := true;
        SubscriptionLine.Modify(false);
    end;

    local procedure SeedVendorScenario(var VendorContract: Record "Vendor Subscription Contract")
    var
        Vendor: Record Vendor;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        TestLib.CreateVendor(Vendor);
        TestLib.CreateItem(Item, 157.35, 61.2);
        TestLib.CreateVendorContract(VendorContract, Vendor);
        TestLib.CreateSubscriptionHeader(SubscriptionHeader, Item, '', 4);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Vendor, VendorContract."No.", 55, 100, 0, CalcDate('<60D>', WorkDate()), 0D);
        TestLib.CreateSubscriptionLine(SubscriptionLine, SubscriptionHeader, Enum::"Service Partner"::Vendor, VendorContract."No.", 40, 120, 2, CalcDate('<15D>', WorkDate()), CalcDate('<15D>', WorkDate()));
        Item."Unit Cost" := 64.8;
        Item.Modify(false);
    end;

    local procedure CreateContractTemplate(var PriceUpdateTemplate: Record "Price Update Template"; CustomerContract: Record "Customer Subscription Contract")
    begin
        TestLib.CreatePriceUpdateTemplate(PriceUpdateTemplate, Enum::"Service Partner"::Customer, Enum::"Price Update Method"::"Calculation Base by %", 110, '<0D>', '<1Y>', '<12M>');
        CustomerContract.SetRange("No.", CustomerContract."No.");
        TestLib.WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), CustomerContract.GetView(false));
    end;

    local procedure AssertContractsPerformedAlike(MicrosoftContractNo: Code[20]; CopyContractNo: Code[20])
    var
        MicrosoftLine: Record "Subscription Line";
        CopyLine: Record "Subscription Line";
        UpdatedLines: Integer;
        PlannedLines: Integer;
    begin
        MicrosoftLine.SetRange("Subscription Contract No.", MicrosoftContractNo);
        CopyLine.SetRange("Subscription Contract No.", CopyContractNo);
        Assert.AreEqual(MicrosoftLine.Count(), CopyLine.Count(), 'Both contracts must hold the same number of Subscription Lines.');
        MicrosoftLine.SetAutoCalcFields("Planned Sub. Line exists");
        CopyLine.SetAutoCalcFields("Planned Sub. Line exists");
        MicrosoftLine.FindSet();
        CopyLine.FindSet();
        repeat
            Assert.AreEqual(MicrosoftLine.Price, CopyLine.Price, 'Price differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Calculation Base Amount", CopyLine."Calculation Base Amount", 'Calculation Base Amount differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Calculation Base %", CopyLine."Calculation Base %", 'Calculation Base % differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine.Amount, CopyLine.Amount, 'Amount differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Discount %", CopyLine."Discount %", 'Discount % differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Discount Amount", CopyLine."Discount Amount", 'Discount Amount differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Next Price Update", CopyLine."Next Price Update", 'Next Price Update differs from Microsoft.');
            Assert.AreEqual(Format(MicrosoftLine."Price Binding Period"), Format(CopyLine."Price Binding Period"), 'Price Binding Period differs from Microsoft.');
            Assert.AreEqual(MicrosoftLine."Planned Sub. Line exists", CopyLine."Planned Sub. Line exists", 'Planned Subscription Line differs from Microsoft.');
            if MicrosoftLine."Planned Sub. Line exists" then begin
                AssertPlannedLinesAlike(MicrosoftLine."Entry No.", CopyLine."Entry No.");
                PlannedLines += 1;
            end;
            if AssertArchivesAlike(MicrosoftLine."Entry No.", CopyLine."Entry No.") then
                UpdatedLines += 1;
        until (MicrosoftLine.Next() = 0) or (CopyLine.Next() = 0);
        Assert.IsTrue(PlannedLines > 0, 'The scenario must plan at least one line.');
        Assert.IsTrue(UpdatedLines > 0, 'The scenario must update at least one line now.');
    end;

    local procedure AssertPlannedLinesAlike(MicrosoftEntryNo: Integer; CopyEntryNo: Integer)
    var
        MicrosoftPlanned: Record "Planned Subscription Line";
        CopyPlanned: Record "Planned Subscription Line";
    begin
        MicrosoftPlanned.Get(MicrosoftEntryNo);
        CopyPlanned.Get(CopyEntryNo);
        Assert.AreEqual(MicrosoftPlanned.Price, CopyPlanned.Price, 'Planned Price differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Calculation Base Amount", CopyPlanned."Calculation Base Amount", 'Planned Calculation Base Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Calculation Base %", CopyPlanned."Calculation Base %", 'Planned Calculation Base % differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned.Amount, CopyPlanned.Amount, 'Planned Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Discount %", CopyPlanned."Discount %", 'Planned Discount % differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Discount Amount", CopyPlanned."Discount Amount", 'Planned Discount Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Next Price Update", CopyPlanned."Next Price Update", 'Planned Next Price Update differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Perform Update On", CopyPlanned."Perform Update On", 'Planned Perform Update On differs from Microsoft.');
        Assert.AreEqual(MicrosoftPlanned."Type Of Update", CopyPlanned."Type Of Update", 'Planned Type Of Update differs from Microsoft.');
        Assert.AreEqual(Format(MicrosoftPlanned."Price Binding Period"), Format(CopyPlanned."Price Binding Period"), 'Planned Price Binding Period differs from Microsoft.');
    end;

    local procedure AssertArchivesAlike(MicrosoftEntryNo: Integer; CopyEntryNo: Integer): Boolean
    var
        MicrosoftArchive: Record "Subscription Line Archive";
        CopyArchive: Record "Subscription Line Archive";
    begin
        MicrosoftArchive.SetRange("Original Entry No.", MicrosoftEntryNo);
        CopyArchive.SetRange("Original Entry No.", CopyEntryNo);
        Assert.AreEqual(MicrosoftArchive.Count(), CopyArchive.Count(), 'The number of archive entries differs from Microsoft.');
        if not MicrosoftArchive.FindLast() then
            exit(false);
        CopyArchive.FindLast();
        Assert.AreEqual(MicrosoftArchive.Price, CopyArchive.Price, 'Archived Price differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive.Amount, CopyArchive.Amount, 'Archived Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Calculation Base Amount", CopyArchive."Calculation Base Amount", 'Archived Calculation Base Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Calculation Base %", CopyArchive."Calculation Base %", 'Archived Calculation Base % differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Discount Amount", CopyArchive."Discount Amount", 'Archived Discount Amount differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Next Price Update", CopyArchive."Next Price Update", 'Archived Next Price Update differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Perform Update On", CopyArchive."Perform Update On", 'Archived Perform Update On differs from Microsoft.');
        Assert.AreEqual(MicrosoftArchive."Type Of Update", CopyArchive."Type Of Update", 'Archived Type Of Update differs from Microsoft.');
        exit(true);
    end;
}
