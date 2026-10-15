namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC06 and AC07: Renewal.Extend extends a Subscription onto a contract
/// through Microsoft's Extend Sub. Contract Mgt., and Renewal.CreateQuote builds a renewal sales
/// quote for a contract whose lines have an end date. Every test seeds its own contract.
/// </summary>
codeunit 95776 "Sub Renewal Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC06_Extend_AddsPackageLinesOntoContract()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        ExtraPackage: Record "Subscription Package";
        RequestJson: JsonObject;
        PackageCodes: JsonArray;
        ResponseJson: JsonObject;
        NewEntryNoToken: JsonToken;
    begin
        // Issue #43, AC06 | Time: the Subscription's Provision Start Date (work date) starts the new lines | Risk: None
        // [GIVEN] A customer contract with one line, and an extra package for the same item
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreatePackage(ExtraPackage, true, false, false);
        TestLibrary.AssignPackageToItem(SubscriptionHeader."Source No.", ExtraPackage.Code, false);

        // [WHEN] Subscription.Renewal.Extend extends the Subscription onto the contract with the extra package
        PackageCodes.Add(ExtraPackage.Code);
        RequestJson.Add('subscriptionHeaderNo', SubscriptionHeader."No.");
        RequestJson.Add('customerContractNo', CustomerContract."No.");
        RequestJson.Add('subscriptionPackageCodes', PackageCodes);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Renewal.Extend", RequestJson);

        // [THEN] The standard package and the extra package add one line each, both start on the
        // Provision Start Date and both are attached to the contract
        Assert.AreEqual(2, TestLibrary.ReadInteger(ResponseJson, 'newSubscriptionLineCount'), 'The standard and the extra package must each add a line.');
        Assert.AreEqual(2, TestLibrary.ReadInteger(ResponseJson, 'custContractLinesCreated'), 'Both new lines must be attached to the contract.');
        foreach NewEntryNoToken in TestLibrary.ReadArray(ResponseJson, 'newSubscriptionLineEntryNos') do begin
            SubscriptionLine.Get(NewEntryNoToken.AsValue().AsInteger());
            Assert.AreEqual(SubscriptionHeader."No.", SubscriptionLine."Subscription Header No.", 'The new line must belong to the Subscription.');
            Assert.AreEqual(SubscriptionHeader."Provision Start Date", SubscriptionLine."Subscription Line Start Date", 'The new line must start on the Provision Start Date.');
            Assert.AreEqual(CustomerContract."No.", SubscriptionLine."Subscription Contract No.", 'The new line must be on the contract.');
        end;
        CustSubContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordCount(CustSubContractLine, 3);
    end;

    [Test]
    procedure Scenario_AC06_Extend_WithoutContract_IsRefused()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        RequestJson: JsonObject;
        LineCountBefore: Integer;
    begin
        // Issue #43, AC06 refusal | Time: none | Risk: None
        // [GIVEN] A Subscription with lines
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        LineCountBefore := SubscriptionLine.Count();

        // [WHEN] Renewal.Extend names neither a customer nor a vendor contract
        RequestJson.Add('subscriptionHeaderNo', SubscriptionHeader."No.");
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Renewal.Extend", RequestJson);

        // [THEN] The call is refused and no line is added
        Assert.ExpectedError('customerContractNo');
        Assert.AreEqual(LineCountBefore, SubscriptionLine.Count(), 'A refused call must add no line.');
    end;

    [Test]
    procedure Scenario_AC07_CreateQuote_CreatesRenewalSalesQuote()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SubContractRenewalLine: Record "Sub. Contract Renewal Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        SalesQuoteNo: Code[20];
    begin
        // Issue #43, AC07 | Time: lines end 12 months after the work date month | Risk: None
        // [GIVEN] A customer contract whose line has an end date
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, CalcDate('<CM+11M>', WorkDate()));

        // [WHEN] Subscription.Renewal.CreateQuote runs for the contract
        RequestJson.Add('contractNo', CustomerContract."No.");
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Renewal.CreateQuote", RequestJson);

        // [THEN] A renewal sales quote for the contract customer exists with a line, built from one renewal line
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'renewalLinesCreated'), 'One renewal line must be built.');
        SalesQuoteNo := CopyStr(TestLibrary.ReadText(ResponseJson, 'salesQuoteNo'), 1, MaxStrLen(SalesQuoteNo));
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Quote, SalesQuoteNo), 'The renewal sales quote must exist.');
        Assert.AreEqual(CustomerContract."Sell-to Customer No.", SalesHeader."Sell-to Customer No.", 'The quote must be for the contract customer.');
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("No.", '<>%1', '');
        Assert.RecordIsNotEmpty(SalesLine);
        SubContractRenewalLine.SetRange("Linked to Sub. Contract No.", CustomerContract."No.");
        Assert.RecordIsNotEmpty(SubContractRenewalLine);
    end;

    [Test]
    procedure Scenario_AC07_CreateQuote_OpenEndedLines_IsRefused()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        RequestJson: JsonObject;
    begin
        // Issue #43, AC07 refusal | Time: none | Risk: None
        // [GIVEN] A customer contract whose line has no end date
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);

        // [WHEN] Renewal.CreateQuote runs for it
        RequestJson.Add('contractNo', CustomerContract."No.");
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Renewal.CreateQuote", RequestJson);

        // [THEN] The call is refused: nothing can be renewed
        Assert.ExpectedError(CustomerContract."No.");
    end;
}
