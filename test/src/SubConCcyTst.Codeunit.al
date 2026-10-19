namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Currency Code on customer and vendor subscription contracts is closed to Foundation's generic
/// Data.Records.Set write and names the supported path (#51). Every generic write goes through the
/// public Dispatcher ori; a direct Validate, the path the contract card takes, stays open.
/// </summary>
codeunit 95717 "Sub Con Ccy Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryERM: Codeunit "Library - ERM";
        TestLibrary: Codeunit "Sub Test Library ori";
        TestLib: Codeunit "Sub Test Lib ori";
        UpdateExchangeRatesTok: Label 'Subscription.Contract.UpdateExchangeRates', Locked = true;
        IcelandicHintTok: Label 'gjaldmiðilskóðanum', Locked = true;

    [Test]
    procedure Scenario_AC01_CustomerCurrencyDataRecordsSet_IsRefusedWithHint()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
        ResponseJson: JsonObject;
        PreviousCurrencyCode: Code[10];
    begin
        // Issue #51, AC01 | Time: none | Risk: None
        // [GIVEN] A customer subscription contract and an existing foreign currency
        GlobalLanguage(1033);
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        PreviousCurrencyCode := CustomerContract."Currency Code";

        // [WHEN] Data.Records.Set writes Currency Code
        ResponseJson := SetField(Database::"Customer Subscription Contract", CustomerContract."No.", 'CurrencyCode', LibraryERM.CreateCurrencyWithRandomExchRates());

        // [THEN] The write is refused, names the field, points to the supported path, and nothing changed
        TestLib.AssertRefused(ResponseJson, 'Currency Code');
        Assert.IsTrue(TestLib.GetText(ResponseJson, 'nextStep').Contains(UpdateExchangeRatesTok), 'nextStep must name the supported type.');
        CustomerContract.Get(CustomerContract."No.");
        Assert.AreEqual(PreviousCurrencyCode, CustomerContract."Currency Code", 'Currency Code must stay unchanged.');
    end;

    [Test]
    procedure Scenario_AC01_VendorCurrencyDataRecordsSet_IsRefusedWithHint()
    var
        VendorContract: Record "Vendor Subscription Contract";
        Vendor: Record Vendor;
        ResponseJson: JsonObject;
        PreviousCurrencyCode: Code[10];
    begin
        // Issue #51, AC01 | Time: none | Risk: None
        // [GIVEN] A vendor subscription contract and an existing foreign currency
        GlobalLanguage(1033);
        TestLibrary.CreateVendor(Vendor);
        TestLibrary.CreateVendorContract(VendorContract, Vendor."No.");
        PreviousCurrencyCode := VendorContract."Currency Code";

        // [WHEN] Data.Records.Set writes Currency Code
        ResponseJson := SetField(Database::"Vendor Subscription Contract", VendorContract."No.", 'CurrencyCode', LibraryERM.CreateCurrencyWithRandomExchRates());

        // [THEN] The write is refused, names the field, points to the supported path, and nothing changed
        TestLib.AssertRefused(ResponseJson, 'Currency Code');
        Assert.IsTrue(TestLib.GetText(ResponseJson, 'nextStep').Contains(UpdateExchangeRatesTok), 'nextStep must name the supported type.');
        VendorContract.Get(VendorContract."No.");
        Assert.AreEqual(PreviousCurrencyCode, VendorContract."Currency Code", 'Currency Code must stay unchanged.');
    end;

    [Test]
    procedure Scenario_AC02_CurrencyRefusal_IsLocalizedInIcelandic()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
        ResponseJson: JsonObject;
        NextStep: Text;
    begin
        // Issue #51, AC02 | Time: none | Risk: None
        // [GIVEN] A customer subscription contract, and Icelandic as the session language
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        GlobalLanguage(1039);

        // [WHEN] Data.Records.Set writes Currency Code
        ResponseJson := SetField(Database::"Customer Subscription Contract", CustomerContract."No.", 'CurrencyCode', LibraryERM.CreateCurrencyWithRandomExchRates());
        NextStep := TestLib.GetText(ResponseJson, 'nextStep');
        GlobalLanguage(1033);

        // [THEN] The hint is the Icelandic text and still names the supported type
        Assert.AreEqual('Error', TestLib.GetText(ResponseJson, 'status'), 'The write must be refused in lcid 1039.');
        Assert.IsTrue(NextStep.Contains(IcelandicHintTok), 'The hint must be Icelandic in lcid 1039: ' + NextStep);
        Assert.IsTrue(NextStep.Contains(UpdateExchangeRatesTok), 'The Icelandic hint must name the supported type.');
    end;

    [Test]
    procedure Scenario_AC01_OnlyCurrencyCodeIsRestricted()
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
    begin
        // Issue #51, AC01 edge case | Time: none | Risk: None
        // [GIVEN] The field discovery of both contract tables
        GlobalLanguage(1033);

        // [WHEN] Help.Fields.Get reports the write restriction of Currency Code and of a neighbour field
        // [THEN] Currency Code is closed and Description stays writable
        Assert.IsTrue(IsWriteRestricted(Database::"Customer Subscription Contract", CustomerContract.FieldNo("Currency Code")), 'Customer contract Currency Code must be write-restricted.');
        Assert.IsTrue(IsWriteRestricted(Database::"Vendor Subscription Contract", VendorContract.FieldNo("Currency Code")), 'Vendor contract Currency Code must be write-restricted.');
        Assert.IsFalse(IsWriteRestricted(Database::"Customer Subscription Contract", CustomerContract.FieldNo(Description)), 'Customer contract Description must stay writable.');
        Assert.IsFalse(IsWriteRestricted(Database::"Vendor Subscription Contract", VendorContract.FieldNo(Description)), 'Vendor contract Description must stay writable.');
    end;

    [Test]
    procedure Scenario_AC01_DirectValidateWithoutLines_StillSetsCurrency()
    var
        CustomerContract: Record "Customer Subscription Contract";
        Customer: Record Customer;
        CurrencyCode: Code[10];
    begin
        // Issue #51, AC01 edge case: the contract card and Microsoft's contract creation validate Currency Code directly
        // [GIVEN] A customer subscription contract without lines and an existing foreign currency
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        CurrencyCode := LibraryERM.CreateCurrencyWithRandomExchRates();

        // [WHEN] Currency Code is validated directly, as the page does
        CustomerContract.Validate("Currency Code", CurrencyCode);
        CustomerContract.Modify(true);

        // [THEN] The currency is stored; this app does not interfere with that path
        CustomerContract.Get(CustomerContract."No.");
        Assert.AreEqual(CurrencyCode, CustomerContract."Currency Code", 'A direct Validate must still set Currency Code.');
    end;

    local procedure SetField(TableNo: Integer; ContractNo: Code[20]; FieldName: Text; FieldValue: Text): JsonObject
    var
        RequestJson: JsonObject;
        Data: JsonArray;
        Entry: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
    begin
        PrimaryKey.Add('No_', ContractNo);
        Fields.Add(FieldName, FieldValue);
        Entry.Add('primaryKey', PrimaryKey);
        Entry.Add('fields', Fields);
        Data.Add(Entry);
        RequestJson.Add('tableName', Format(TableNo, 0, 9));
        RequestJson.Add('data', Data);
        exit(TestLib.Invoke(Enum::"Message Type ori"::"Data.Records.Set", '', RequestJson, true));
    end;

    local procedure IsWriteRestricted(TableNo: Integer; FieldNo: Integer): Boolean
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FieldNumbers: JsonArray;
        Token: JsonToken;
    begin
        FieldNumbers.Add(FieldNo);
        RequestJson.Add('fieldNumbers', FieldNumbers);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Help.Fields.Get", CopyStr(Format(TableNo, 0, 9), 1, 250), RequestJson, true);
        TestLib.AssertSuccess(ResponseJson);
        ResponseJson.Get('result', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'The requested field must exist.');
        Token.AsArray().Get(0, Token);
        Token.AsObject().Get('writeRestricted', Token);
        exit(Token.AsValue().AsBoolean());
    end;
}
