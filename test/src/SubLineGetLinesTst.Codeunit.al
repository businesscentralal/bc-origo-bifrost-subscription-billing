namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC01 and AC02: Subscription.Line.Create applies a package through
/// Microsoft's package application, and Contract.GetLines and VendorContract.GetLines attach the
/// lines to a contract, all of them or a selection. Every test seeds its own data.
/// </summary>
codeunit 95773 "Sub Line GetLines Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC01_PackageApplied_CreatesLinesWithRequestedDates()
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        StartDate: Date;
        EndDate: Date;
    begin
        // Issue #43, AC01 | Time: WorkDate() based start and end dates | Risk: None
        // [GIVEN] A Subscription for a subscription item and a package with a customer and a vendor line
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, true, true, false);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        StartDate := CalcDate('<-CM>', WorkDate());
        EndDate := CalcDate('<CM+11M>', WorkDate());

        // [WHEN] Subscription.Line.Create applies the package with a start and an end date
        ResponseJson := TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, StartDate, EndDate);

        // [THEN] Two lines exist with the requested dates, the next billing date on the start date and the response lists them
        Assert.AreEqual(2, TestLibrary.ReadInteger(ResponseJson, 'linesCreated'), 'Both package lines must become Subscription Lines.');
        Assert.AreEqual(2, TestLibrary.ReadArray(ResponseJson, 'createdLines').Count(), 'createdLines must list both lines.');
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        Assert.RecordCount(SubscriptionLine, 2);
        SubscriptionLine.FindSet();
        repeat
            Assert.AreEqual(StartDate, SubscriptionLine."Subscription Line Start Date", 'The start date must be the requested one.');
            Assert.AreEqual(EndDate, SubscriptionLine."Subscription Line End Date", 'The end date must be the requested one.');
            Assert.AreEqual(StartDate, SubscriptionLine."Next Billing Date", 'The first billing date must be the start date.');
            Assert.AreEqual(SubscriptionPackage.Code, SubscriptionLine."Subscription Package Code", 'The line must name its package.');
            Assert.AreEqual('', SubscriptionLine."Subscription Contract No.", 'A new line is on no contract yet.');
        until SubscriptionLine.Next() = 0;
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        Assert.RecordCount(SubscriptionLine, 1);
    end;

    [Test]
    procedure Scenario_AC01_UnknownPackage_IsRefused()
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        // Issue #43, AC01 refusal | Time: WorkDate() | Risk: None
        // [GIVEN] A Subscription
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");

        // [WHEN] Subscription.Line.Create names a package that does not exist
        asserterror TestLibrary.RunLineCreate(SubscriptionHeader."No.", 'XNOPACKAGE', WorkDate(), 0D);

        // [THEN] The call is refused and no line is created
        Assert.ExpectedError('XNOPACKAGE');
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        Assert.RecordIsEmpty(SubscriptionLine);
    end;

    [Test]
    procedure Scenario_AC01_UsageBasedOnly_SkipsOtherPackageLines()
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC01 edge case | Time: WorkDate() | Risk: None
        // [GIVEN] A package with one ordinary and one usage-based customer line
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, true, false, false);
        TestLibrary.AddUsageBasedCustomerLine(SubscriptionPackage.Code);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");

        // [WHEN] Subscription.Line.Create runs with usageBasedBillingPackageLinesOnly = true
        RequestJson.Add('subscriptionHeaderNo', SubscriptionHeader."No.");
        RequestJson.Add('subscriptionPackageCode', SubscriptionPackage.Code);
        RequestJson.Add('usageBasedBillingPackageLinesOnly', true);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Line.Create", RequestJson);

        // [THEN] Only the usage-based line is created
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'linesCreated'), 'Only the usage-based line must be created.');
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.FindFirst();
        Assert.IsTrue(SubscriptionLine."Usage Based Billing", 'The created line must be the usage-based one.');
    end;

    [Test]
    procedure Scenario_AC02_ContractGetLines_AttachesAllCandidates()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
    begin
        // Issue #43, AC02 | Time: WorkDate() | Risk: None
        // [GIVEN] [WHEN] A customer contract whose Subscription's lines were attached with Subscription.Contract.GetLines
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);

        // [THEN] The line is on the contract and the contract has a line for it
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.FindFirst();
        Assert.AreEqual(CustomerContract."No.", SubscriptionLine."Subscription Contract No.", 'The Subscription Line must be stamped with the contract.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        CustSubContractLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        Assert.RecordCount(CustSubContractLine, 1);
    end;

    [Test]
    procedure Scenario_AC02_ContractGetLines_AttachesOnlySelectedLines()
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        ResponseJson: JsonObject;
        SelectedEntryNo: Integer;
    begin
        // Issue #43, AC02 selected | Time: WorkDate() | Risk: None
        // [GIVEN] A Subscription with two customer lines and a contract for its customer
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, true, false, false);
        TestLibrary.AddUsageBasedCustomerLine(SubscriptionPackage.Code);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.FindFirst();
        SelectedEntryNo := SubscriptionLine."Entry No.";

        // [WHEN] Subscription.Contract.GetLines selects one of the two lines
        EntryNos.Add(SelectedEntryNo);
        RequestJson.Add('contractNo', CustomerContract."No.");
        RequestJson.Add('subscriptionLineEntryNos', EntryNos);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.GetLines", RequestJson);

        // [THEN] Only the selected line is attached
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'linesAttached'), 'Only the selected line must be attached.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordCount(CustSubContractLine, 1);
        CustSubContractLine.FindFirst();
        Assert.AreEqual(SelectedEntryNo, CustSubContractLine."Subscription Line Entry No.", 'The contract line must be for the selected line.');
        SubscriptionLine.SetFilter("Entry No.", '<>%1', SelectedEntryNo);
        SubscriptionLine.FindFirst();
        Assert.AreEqual('', SubscriptionLine."Subscription Contract No.", 'The other line must stay unassigned.');
    end;

    [Test]
    procedure Scenario_AC02_ContractGetLines_SkipsOtherCustomersLines()
    var
        Customer: Record Customer;
        OtherCustomer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionHeader: Record "Subscription Header";
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC02 edge case | Time: WorkDate() | Risk: None
        // [GIVEN] A Subscription of one customer and a contract of another
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomer(OtherCustomer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, true, false, false);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.CreateCustomerContract(CustomerContract, OtherCustomer."No.");

        // [WHEN] Subscription.Contract.GetLines is restricted to that Subscription
        RequestJson.Add('contractNo', CustomerContract."No.");
        RequestJson.Add('subscriptionHeaderNo', SubscriptionHeader."No.");
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.GetLines", RequestJson);

        // [THEN] The line is skipped and the contract stays empty
        Assert.AreEqual(0, TestLibrary.ReadInteger(ResponseJson, 'linesAttached'), 'A line of another customer must not be attached.');
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'linesSkipped'), 'The line must be counted as skipped.');
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordIsEmpty(CustSubContractLine);
    end;

    [Test]
    procedure Scenario_AC02_VendorContractGetLines_AttachesAllCandidates()
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
    begin
        // Issue #43, AC02 vendor | Time: WorkDate() | Risk: None
        // [GIVEN] [WHEN] A vendor contract whose Subscription's vendor line was attached with Subscription.VendorContract.GetLines
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);

        // [THEN] The vendor line is on the contract
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.FindFirst();
        Assert.AreEqual(VendorContract."No.", SubscriptionLine."Subscription Contract No.", 'The vendor line must be stamped with the contract.');
        VendSubContractLine.SetRange("Subscription Contract No.", VendorContract."No.");
        VendSubContractLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        Assert.RecordCount(VendSubContractLine, 1);
    end;

    [Test]
    procedure Scenario_AC02_VendorContractGetLines_AttachesOnlySelectedLines()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        VendorContract: Record "Vendor Subscription Contract";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC02 vendor selected | Time: WorkDate() | Risk: None
        // [GIVEN] A Subscription with two vendor lines and a vendor contract
        TestLibrary.CreateVendor(Vendor);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, false, true, false);
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", '');
        TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.CreateVendorContract(VendorContract, Vendor."No.");
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.FindLast();

        // [WHEN] Subscription.VendorContract.GetLines selects the second line
        EntryNos.Add(SubscriptionLine."Entry No.");
        RequestJson.Add('contractNo', VendorContract."No.");
        RequestJson.Add('subscriptionLineEntryNos', EntryNos);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.VendorContract.GetLines", RequestJson);

        // [THEN] Only that line is attached
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'linesAttached'), 'Only the selected vendor line must be attached.');
        VendSubContractLine.SetRange("Subscription Contract No.", VendorContract."No.");
        Assert.RecordCount(VendSubContractLine, 1);
        VendSubContractLine.FindFirst();
        Assert.AreEqual(SubscriptionLine."Entry No.", VendSubContractLine."Subscription Line Entry No.", 'The contract line must be for the selected line.');
    end;
}
