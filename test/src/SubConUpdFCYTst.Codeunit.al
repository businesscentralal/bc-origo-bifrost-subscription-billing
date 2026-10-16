namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.Currency;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// #40: Subscription.Contract.UpdateExchangeRates recalculates a foreign-currency contract's Subscription
/// Lines from their local currency amounts, with the rate of the key date or a given factor.
/// </summary>
codeunit 95714 "Sub Con UpdFCY Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA40', Locked = true;
        HeaderNoTok: Label 'XSBA40SUB', Locked = true;
        ContractNoTok: Label 'XSBA40CC', Locked = true;
        VendorContractNoTok: Label 'XSBA40VC', Locked = true;
        CurrencyTok: Label 'XSBA40', Locked = true;

    /// <summary>AC02: with the rate of the key date (0.5) a line of 100 in local currency becomes 50, and the line carries the new factor.</summary>
    [Test]
    procedure UpdateExchangeRates_DefaultRate_RecalculatesFromLocalCurrency()
    var
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A customer contract in a currency whose rate is 0.5 and a line of 100 in local currency at an old factor of 1
        Initialize();
        LineEntryNo := CreateForeignCurrencyLine(Enum::"Service Partner"::Customer, ContractNoTok);

        // [WHEN] The exchange rates are updated without a factor
        RequestJson.Add('currencyFactorDate', Format(WorkDate(), 0, 9));
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", ContractNoTok, RequestJson, false);

        // [THEN] The line is recalculated with the rate of the key date
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'linesRecalculated'), 'One line must be recalculated.');
        Assert.AreEqual('0.5', TestLib.GetText(ResponseJson, 'currencyFactor'), 'The rate of the key date must be used.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(0.5, SubscriptionLine."Currency Factor", 'The line must carry the new factor.');
        Assert.AreEqual(WorkDate(), SubscriptionLine."Currency Factor Date", 'The line must carry the key date.');
        Assert.AreEqual(50, SubscriptionLine."Calculation Base Amount", 'The amount must be converted again from local currency.');
        Assert.AreEqual(50, SubscriptionLine.Price, 'The price must follow the calculation base.');
    end;

    /// <summary>AC02: a vendor contract with an explicit factor is recalculated the same way.</summary>
    [Test]
    procedure UpdateExchangeRates_VendorWithFactor_UsesGivenFactor()
    var
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A vendor contract line of 100 in local currency
        Initialize();
        LineEntryNo := CreateForeignCurrencyLine(Enum::"Service Partner"::Vendor, VendorContractNoTok);

        // [WHEN] The exchange rates are updated with a factor of 0.25
        RequestJson.Add('partner', 'vendor');
        RequestJson.Add('currencyFactor', 0.25);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", VendorContractNoTok, RequestJson, false);

        // [THEN] The given factor is used
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual('Vendor', TestLib.GetText(ResponseJson, 'partner'), 'The vendor contract must be named.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(0.25, SubscriptionLine."Currency Factor", 'The given factor must be stored.');
        Assert.AreEqual(25, SubscriptionLine."Calculation Base Amount", 'The amount must be converted with the given factor.');
    end;

    /// <summary>AC05: a contract in local currency and a factor of zero are refused, and nothing changes.</summary>
    [Test]
    procedure UpdateExchangeRates_LocalCurrencyOrZeroFactor_IsRefused()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A foreign currency line
        Initialize();
        LineEntryNo := CreateForeignCurrencyLine(Enum::"Service Partner"::Customer, ContractNoTok);

        // [WHEN] A factor of zero is sent
        RequestJson.Add('currencyFactor', 0);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", ContractNoTok, RequestJson, false);

        // [THEN] The call is refused and the line keeps its amounts
        TestLib.AssertRefused(ResponseJson, 'currencyFactor');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(100, SubscriptionLine."Calculation Base Amount", 'A refused call must not change the line.');

        // [WHEN] The contract is in local currency
        CustomerContract.Get(ContractNoTok);
        CustomerContract."Currency Code" := '';
        CustomerContract.Modify(false);
        Commit();
        Clear(RequestJson);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", ContractNoTok, RequestJson, false);

        // [THEN] The call is refused because there is no exchange rate to update
        TestLib.AssertRefused(ResponseJson, 'local currency');
    end;

    /// <summary>Edge: a line whose contract line is closed is skipped and counted.</summary>
    [Test]
    procedure UpdateExchangeRates_ClosedContractLine_IsSkipped()
    var
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A foreign currency line whose contract line is closed
        Initialize();
        LineEntryNo := CreateForeignCurrencyLine(Enum::"Service Partner"::Customer, ContractNoTok);
        CustSubContractLine.SetRange("Subscription Line Entry No.", LineEntryNo);
        CustSubContractLine.FindFirst();
        CustSubContractLine.Closed := true;
        CustSubContractLine.Modify(false);
        Commit();

        // [WHEN] The exchange rates are updated
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateExchangeRates", ContractNoTok, RequestJson, false);

        // [THEN] The line is skipped and unchanged
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'linesRecalculated'), 'A closed line must not be recalculated.');
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'linesSkipped'), 'The closed line must be counted as skipped.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(1, SubscriptionLine."Currency Factor", 'A skipped line keeps its factor.');
    end;

    local procedure Initialize()
    var
        Currency: Record Currency;
        CurrencyExchangeRate: Record "Currency Exchange Rate";
    begin
        TestLib.DeleteFixture(PrefixTok);
        CurrencyExchangeRate.SetRange("Currency Code", CurrencyTok);
        CurrencyExchangeRate.DeleteAll(false);
        if Currency.Get(CurrencyTok) then
            Currency.Delete(false);
        Currency.Init();
        Currency.Code := CurrencyTok;
        Currency.Description := 'X Branch A currency';
        Currency."Unit-Amount Rounding Precision" := 0.00001;
        Currency."Amount Rounding Precision" := 0.01;
        Currency.Insert(false);
        CurrencyExchangeRate.Init();
        CurrencyExchangeRate."Currency Code" := CurrencyTok;
        CurrencyExchangeRate."Starting Date" := CalcDate('<-1Y>', WorkDate());
        CurrencyExchangeRate."Exchange Rate Amount" := 1;
        CurrencyExchangeRate."Adjustment Exch. Rate Amount" := 1;
        CurrencyExchangeRate."Relational Exch. Rate Amount" := 2;
        CurrencyExchangeRate."Relational Adjmt Exch Rate Amt" := 2;
        CurrencyExchangeRate.Insert(false);
        Commit();
    end;

    /// <summary>Seeds a contract in the fixture currency with one line of 100 in local currency at a factor of 1.</summary>
    local procedure CreateForeignCurrencyLine(Partner: Enum "Service Partner"; ContractNo: Code[20]) LineEntryNo: Integer
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
    begin
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Partner, ContractNo, CalcDate('<-1M>', WorkDate()), 0D, WorkDate());
        if Partner = Partner::Vendor then begin
            TestLib.CreateVendorContract(ContractNo, '');
            VendorContract.Get(ContractNo);
            VendorContract."Currency Code" := CurrencyTok;
            VendorContract.Modify(false);
            TestLib.CreateVendorContractLine(ContractNo, HeaderNoTok, LineEntryNo);
        end else begin
            TestLib.CreateCustomerContract(ContractNo, '');
            CustomerContract.Get(ContractNo);
            CustomerContract."Currency Code" := CurrencyTok;
            CustomerContract.Modify(false);
            TestLib.CreateCustomerContractLine(ContractNo, HeaderNoTok, LineEntryNo);
        end;
        SubscriptionLine.Get(LineEntryNo);
        SubscriptionLine."Currency Code" := CurrencyTok;
        SubscriptionLine."Currency Factor" := 1;
        SubscriptionLine."Currency Factor Date" := CalcDate('<-1M>', WorkDate());
        SubscriptionLine."Calculation Base %" := 100;
        SubscriptionLine."Calculation Base Amount (LCY)" := 100;
        SubscriptionLine."Calculation Base Amount" := 100;
        SubscriptionLine.Price := 100;
        SubscriptionLine."Price (LCY)" := 100;
        SubscriptionLine.Amount := 100;
        SubscriptionLine."Amount (LCY)" := 100;
        SubscriptionLine.Modify(false);
        Commit();
    end;
}
