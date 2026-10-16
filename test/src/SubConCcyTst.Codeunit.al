namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Refuses a generic Currency Code write on a customer or vendor subscription contract (#51).
/// The supported path is Subscription.Contract.UpdateExchangeRates.
/// </summary>
codeunit 95717 "Sub Con Ccy Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        UpdateExchangeRatesTok: Label 'Subscription.Contract.UpdateExchangeRates', Locked = true;

    [Test]
    procedure Scenario_AC01_CustomerCurrencyWrite_IsRefusedAndLeavesTheValue()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
        PreviousCurrencyCode: Code[10];
    begin
        // Issue #51, AC01 | Time: none | Risk: None
        // [GIVEN] A customer subscription contract
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        PreviousCurrencyCode := CustomerContract."Currency Code";

        // [WHEN] A generic write changes Currency Code
        asserterror CustomerContract.Validate("Currency Code", 'EUR');

        // [THEN] The write is refused and names the supported message type, and the stored value is unchanged
        Assert.ExpectedError(UpdateExchangeRatesTok);
        CustomerContract.Get(CustomerContract."No.");
        Assert.AreEqual(PreviousCurrencyCode, CustomerContract."Currency Code", 'Currency Code must stay unchanged.');
    end;

    [Test]
    procedure Scenario_AC01_CustomerCurrencySameValue_IsAllowed()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
    begin
        // Issue #51, AC01 edge case | Time: none | Risk: None
        // [GIVEN] A customer subscription contract
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");

        // [WHEN] Currency Code is validated to the value it already has
        CustomerContract.Validate("Currency Code", CustomerContract."Currency Code");

        // [THEN] The no-op is allowed
        CustomerContract.Get(CustomerContract."No.");
    end;

    [Test]
    procedure Scenario_AC01_VendorCurrencyWrite_IsRefusedAndLeavesTheValue()
    var
        VendorContract: Record "Vendor Subscription Contract";
        Vendor: Record Vendor;
        PreviousCurrencyCode: Code[10];
    begin
        // Issue #51, AC01 | Time: none | Risk: None
        // [GIVEN] A vendor subscription contract
        TestLibrary.CreateVendor(Vendor);
        TestLibrary.CreateVendorContract(VendorContract, Vendor."No.");
        PreviousCurrencyCode := VendorContract."Currency Code";

        // [WHEN] A generic write changes Currency Code
        asserterror VendorContract.Validate("Currency Code", 'EUR');

        // [THEN] The write is refused and names the supported message type, and the stored value is unchanged
        Assert.ExpectedError(UpdateExchangeRatesTok);
        VendorContract.Get(VendorContract."No.");
        Assert.AreEqual(PreviousCurrencyCode, VendorContract."Currency Code", 'Currency Code must stay unchanged.');
    end;

    [Test]
    procedure Scenario_AC01_VendorCurrencySameValue_IsAllowed()
    var
        VendorContract: Record "Vendor Subscription Contract";
        Vendor: Record Vendor;
    begin
        // Issue #51, AC01 edge case | Time: none | Risk: None
        // [GIVEN] A vendor subscription contract
        TestLibrary.CreateVendor(Vendor);
        TestLibrary.CreateVendorContract(VendorContract, Vendor."No.");

        // [WHEN] Currency Code is validated to the value it already has
        VendorContract.Validate("Currency Code", VendorContract."Currency Code");

        // [THEN] The no-op is allowed
        VendorContract.Get(VendorContract."No.");
    end;
}
