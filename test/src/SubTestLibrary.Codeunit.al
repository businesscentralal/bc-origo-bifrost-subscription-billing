namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Seeds the Microsoft Subscription Billing data the behaviour tests of this app need: setup with
/// number series, customers and vendors in local currency, subscription items, packages,
/// Subscriptions and contracts. Every record is created by the test that needs it, so no test
/// relies on demo data.
/// </summary>
codeunit 95770 "Sub Test Library ori"
{
    var
        LibraryERM: Codeunit "Library - ERM";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryUtility: Codeunit "Library - Utility";

    /// <summary>Makes sure Subscription Contract Setup has number series and default periods.</summary>
    procedure InitSubscriptionBilling()
    var
        SubscriptionContractSetup: Record "Subscription Contract Setup";
    begin
        if not SubscriptionContractSetup.Get() then begin
            SubscriptionContractSetup.Init();
            SubscriptionContractSetup.Insert(false);
        end;
        if SubscriptionContractSetup."Cust. Sub. Contract Nos." = '' then
            SubscriptionContractSetup."Cust. Sub. Contract Nos." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Vend. Sub. Contract Nos." = '' then
            SubscriptionContractSetup."Vend. Sub. Contract Nos." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Subscription Header No." = '' then
            SubscriptionContractSetup."Subscription Header No." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Contract Invoice Description" = SubscriptionContractSetup."Contract Invoice Description"::" " then
            SubscriptionContractSetup.ContractTextsCreateDefaults();
        Evaluate(SubscriptionContractSetup."Default Billing Base Period", '<1M>');
        Evaluate(SubscriptionContractSetup."Default Billing Rhythm", '<1M>');
        SubscriptionContractSetup.Modify(false);
    end;

    /// <summary>Creates a customer in local currency.</summary>
    /// <param name="Customer">Returns the created customer.</param>
    procedure CreateCustomer(var Customer: Record Customer)
    begin
        InitSubscriptionBilling();
        LibrarySales.CreateCustomer(Customer);
        Customer.Validate("Currency Code", '');
        Customer.Modify(false);
    end;

    /// <summary>Creates a vendor in local currency.</summary>
    /// <param name="Vendor">Returns the created vendor.</param>
    procedure CreateVendor(var Vendor: Record Vendor)
    begin
        InitSubscriptionBilling();
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Validate("Currency Code", '');
        Vendor.Modify(false);
    end;

    /// <summary>Creates a Customer Subscription Contract for the customer.</summary>
    /// <param name="CustomerContract">Returns the created contract.</param>
    /// <param name="CustomerNo">The Sell-to Customer No. of the contract.</param>
    procedure CreateCustomerContract(var CustomerContract: Record "Customer Subscription Contract"; CustomerNo: Code[20])
    begin
        InitSubscriptionBilling();
        CustomerContract.Init();
        CustomerContract.Insert(true);
        CustomerContract.Validate("Sell-to Customer No.", CustomerNo);
        CustomerContract.Modify(true);
    end;

    /// <summary>Creates a Vendor Subscription Contract for the vendor.</summary>
    /// <param name="VendorContract">Returns the created contract.</param>
    /// <param name="VendorNo">The Buy-from Vendor No. of the contract.</param>
    procedure CreateVendorContract(var VendorContract: Record "Vendor Subscription Contract"; VendorNo: Code[20])
    begin
        InitSubscriptionBilling();
        VendorContract.Init();
        VendorContract.Insert(true);
        VendorContract.Validate("Buy-from Vendor No.", VendorNo);
        VendorContract.Modify(true);
    end;

    /// <summary>
    /// Creates a non-inventory item with Subscription Option Service Commitment Item, so it is both the
    /// Subscription's source and its own invoicing item.
    /// </summary>
    /// <param name="Item">Returns the created item.</param>
    procedure CreateSubscriptionItem(var Item: Record Item)
    begin
        InitSubscriptionBilling();
        LibraryInventory.CreateNonInventoryTypeItem(Item);
        Item.Validate("Unit Price", 100);
        Item.Validate("Unit Cost", 60);
        Item.Validate("Subscription Option", Enum::"Item Service Commitment Type"::"Service Commitment Item");
        Item.Modify(true);
    end;

    /// <summary>
    /// Creates a Subscription Package with one line per partner given, billed monthly through a
    /// contract at the item price, with contract deferrals as requested.
    /// </summary>
    /// <param name="SubscriptionPackage">Returns the created package.</param>
    /// <param name="CustomerLine">Adds a customer line.</param>
    /// <param name="VendorLine">Adds a vendor line.</param>
    /// <param name="CreateDeferrals">Whether the lines create contract deferrals.</param>
    procedure CreatePackage(var SubscriptionPackage: Record "Subscription Package"; CustomerLine: Boolean; VendorLine: Boolean; CreateDeferrals: Boolean)
    begin
        SubscriptionPackage.Init();
        SubscriptionPackage.Code := CopyStr(LibraryUtility.GenerateRandomCode20(SubscriptionPackage.FieldNo(Code), Database::"Subscription Package"), 1, MaxStrLen(SubscriptionPackage.Code));
        SubscriptionPackage.Description := SubscriptionPackage.Code;
        SubscriptionPackage.Insert(true);
        if CustomerLine then
            AddPackageLine(SubscriptionPackage.Code, Enum::"Service Partner"::Customer, CreateDeferrals);
        if VendorLine then
            AddPackageLine(SubscriptionPackage.Code, Enum::"Service Partner"::Vendor, CreateDeferrals);
    end;

    /// <summary>Assigns the package to the item.</summary>
    /// <param name="ItemNo">The item.</param>
    /// <param name="PackageCode">The Subscription Package.</param>
    /// <param name="Standard">Whether the package is one of the item's standard packages.</param>
    procedure AssignPackageToItem(ItemNo: Code[20]; PackageCode: Code[20]; Standard: Boolean)
    var
        ItemSubscriptionPackage: Record "Item Subscription Package";
    begin
        ItemSubscriptionPackage.Init();
        ItemSubscriptionPackage."Item No." := ItemNo;
        ItemSubscriptionPackage.Validate(Code, PackageCode);
        ItemSubscriptionPackage.Standard := Standard;
        ItemSubscriptionPackage.Insert(false);
    end;

    /// <summary>Creates a Subscription Header for one unit of the item, used by the customer.</summary>
    /// <param name="SubscriptionHeader">Returns the created Subscription.</param>
    /// <param name="ItemNo">The source item.</param>
    /// <param name="CustomerNo">The End-User Customer No.; empty for a vendor-only Subscription.</param>
    procedure CreateSubscription(var SubscriptionHeader: Record "Subscription Header"; ItemNo: Code[20]; CustomerNo: Code[20])
    begin
        InitSubscriptionBilling();
        SubscriptionHeader.Init();
        SubscriptionHeader.Insert(true);
        SubscriptionHeader.SetHideValidationDialog(true);
        SubscriptionHeader.Type := Enum::"Service Object Type"::Item;
        SubscriptionHeader.Validate("Source No.", ItemNo);
        SubscriptionHeader.Validate(Quantity, 1);
        SubscriptionHeader."Provision Start Date" := WorkDate();
        if CustomerNo <> '' then
            SubscriptionHeader.Validate("End-User Customer No.", CustomerNo);
        SubscriptionHeader.Modify(true);
    end;

    /// <summary>
    /// Fills the Subscription contract accounts of the General Posting Setup for the posting groups,
    /// so billing documents can be created and posted.
    /// </summary>
    /// <param name="GenBusPostingGroup">The partner's Gen. Bus. Posting Group.</param>
    /// <param name="GenProdPostingGroup">The item's Gen. Prod. Posting Group.</param>
    procedure SetContractAccounts(GenBusPostingGroup: Code[20]; GenProdPostingGroup: Code[20])
    var
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        if not GeneralPostingSetup.Get(GenBusPostingGroup, GenProdPostingGroup) then
            LibraryERM.CreateGeneralPostingSetup(GeneralPostingSetup, GenBusPostingGroup, GenProdPostingGroup);
        if GeneralPostingSetup."Sales Account" = '' then
            GeneralPostingSetup."Sales Account" := LibraryERM.CreateGLAccountNo();
        if GeneralPostingSetup."Purch. Account" = '' then
            GeneralPostingSetup."Purch. Account" := LibraryERM.CreateGLAccountNo();
        GeneralPostingSetup."Cust. Sub. Contract Account" := GeneralPostingSetup."Sales Account";
        GeneralPostingSetup."Vend. Sub. Contract Account" := GeneralPostingSetup."Purch. Account";
        if GeneralPostingSetup."Cust. Sub. Contr. Def Account" = '' then
            GeneralPostingSetup."Cust. Sub. Contr. Def Account" := LibraryERM.CreateGLAccountNo();
        if GeneralPostingSetup."Vend. Sub. Contr. Def. Account" = '' then
            GeneralPostingSetup."Vend. Sub. Contr. Def. Account" := LibraryERM.CreateGLAccountNo();
        GeneralPostingSetup.Modify(false);
    end;

    local procedure AddPackageLine(PackageCode: Code[20]; Partner: Enum "Service Partner"; CreateDeferrals: Boolean)
    var
        SubscriptionPackageLine: Record "Subscription Package Line";
    begin
        SubscriptionPackageLine.SetRange("Subscription Package Code", PackageCode);
        if SubscriptionPackageLine.FindLast() then;
        SubscriptionPackageLine.Init();
        SubscriptionPackageLine."Subscription Package Code" := PackageCode;
        SubscriptionPackageLine."Line No." += 10000;
        SubscriptionPackageLine.Validate(Partner, Partner);
        SubscriptionPackageLine."Invoicing via" := Enum::"Invoicing Via"::Contract;
        SubscriptionPackageLine."Calculation Base Type" := Enum::"Calculation Base Type"::"Item Price";
        SubscriptionPackageLine."Calculation Base %" := 100;
        Evaluate(SubscriptionPackageLine."Billing Base Period", '<1M>');
        Evaluate(SubscriptionPackageLine."Billing Rhythm", '<1M>');
        Evaluate(SubscriptionPackageLine."Initial Term", '<12M>');
        Evaluate(SubscriptionPackageLine."Extension Term", '<12M>');
        Evaluate(SubscriptionPackageLine."Notice Period", '<1M>');
        if CreateDeferrals then
            SubscriptionPackageLine."Create Contract Deferrals" := Enum::"Create Contract Deferrals"::Yes
        else
            SubscriptionPackageLine."Create Contract Deferrals" := Enum::"Create Contract Deferrals"::No;
        SubscriptionPackageLine.Insert(false);
    end;
}
