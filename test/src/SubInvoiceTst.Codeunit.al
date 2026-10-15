namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC03 and AC04: Contract.CreateInvoice and VendorContract.CreateInvoice
/// create an unposted sales or purchase invoice with the billed amount and link the billing lines
/// to it, and the two PreviewInvoice types leave nothing behind. Every test seeds its own contract.
/// </summary>
codeunit 95774 "Sub Invoice Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC03_ContractCreateInvoice_CreatesLinkedSalesInvoice()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingLine: Record "Billing Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
        DocumentJson: JsonToken;
        DocumentNo: Code[20];
    begin
        // Issue #43, AC03 | Time: WorkDate() is the billing, document and posting date | Risk: None
        // [GIVEN] A customer contract with one monthly line due on the work date
        ClearPendingProposals();
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);

        // [WHEN] Subscription.Contract.CreateInvoice bills it
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.CreateInvoice", ContractRequest(CustomerContract."No."));

        // [THEN] One unposted sales invoice exists for the customer with the line amount, and the billing line points to it
        Assert.AreEqual(1, TestLibrary.ReadArray(ResponseJson, 'documents').Count(), 'One document must be created.');
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentJson);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentJson.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.AreEqual('Invoice', TestLibrary.ReadText(DocumentJson.AsObject(), 'documentType'), 'The document must be an invoice.');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Invoice, DocumentNo), 'The sales invoice must exist.');
        Assert.AreEqual(CustomerContract."Sell-to Customer No.", SalesHeader."Sell-to Customer No.", 'The invoice must be for the contract customer.');
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("Line Amount", '<>0');
        SalesLine.CalcSums("Line Amount");
        BillingLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        BillingLine.SetRange("Document No.", DocumentNo);
        Assert.RecordIsNotEmpty(BillingLine);
        BillingLine.CalcSums(Amount);
        Assert.AreNotEqual(0, BillingLine.Amount, 'The billing lines must carry an amount.');
        Assert.AreEqual(BillingLine.Amount, SalesLine."Line Amount", 'The invoice must carry the billed amount.');
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'billingLineCount'), 'One billing line must be created.');
    end;

    [Test]
    procedure Scenario_AC03_ContractCreateInvoice_NothingDue_CreatesNothing()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingLine: Record "Billing Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC03 edge case | Time: billingDate before the work date | Risk: None
        // [GIVEN] A customer contract whose line starts on the work date
        ClearPendingProposals();
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);

        // [WHEN] CreateInvoice runs with a billing date before anything is due
        RequestJson := ContractRequest(CustomerContract."No.");
        RequestJson.Add('billingDate', Format(CalcDate('<-1D>', WorkDate()), 0, 9));
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.CreateInvoice", RequestJson);

        // [THEN] Nothing is billed and the answer says so
        Assert.AreEqual(0, TestLibrary.ReadInteger(ResponseJson, 'billingLineCount'), 'Nothing must be billed.');
        Assert.AreNotEqual('', TestLibrary.ReadText(ResponseJson, 'message'), 'The answer must say why nothing was billed.');
        BillingLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordIsEmpty(BillingLine);
    end;

    [Test]
    procedure Scenario_AC03_ContractCreateInvoice_UnknownContract_IsRefused()
    begin
        // Issue #43, AC03 refusal | Time: none | Risk: None
        // [WHEN] CreateInvoice names a contract that does not exist
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.CreateInvoice", ContractRequest('XNOCONTRACT'));

        // [THEN] The call is refused naming the contract
        Assert.ExpectedError('XNOCONTRACT');
    end;

    [Test]
    procedure Scenario_AC03_VendorContractCreateInvoice_CreatesLinkedPurchaseInvoice()
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingLine: Record "Billing Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentJson: JsonToken;
        DocumentNo: Code[20];
    begin
        // Issue #43, AC03 vendor | Time: WorkDate() | Risk: None
        // [GIVEN] A vendor contract with one monthly line due on the work date
        ClearPendingProposals();
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);

        // [WHEN] Subscription.VendorContract.CreateInvoice bills it with a vendor invoice number
        RequestJson := ContractRequest(VendorContract."No.");
        RequestJson.Add('vendorInvoiceNo', 'XVINV-' + VendorContract."No.");
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.VendorContract.CreateInvoice", RequestJson);

        // [THEN] One unposted purchase invoice exists with the billed amount and the vendor invoice number, linked from the billing line
        Assert.AreEqual(1, TestLibrary.ReadArray(ResponseJson, 'documents').Count(), 'One document must be created.');
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentJson);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentJson.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The purchase invoice must exist.');
        Assert.AreEqual(VendorContract."Buy-from Vendor No.", PurchaseHeader."Buy-from Vendor No.", 'The invoice must be for the contract vendor.');
        Assert.AreEqual('XVINV-' + VendorContract."No.", PurchaseHeader."Vendor Invoice No.", 'vendorInvoiceNo must be validated onto the invoice.');
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.CalcSums("Line Amount");
        BillingLine.SetRange("Subscription Contract No.", VendorContract."No.");
        BillingLine.SetRange("Document No.", DocumentNo);
        Assert.RecordIsNotEmpty(BillingLine);
        BillingLine.CalcSums(Amount);
        Assert.AreEqual(BillingLine.Amount, PurchaseLine."Line Amount", 'The invoice must carry the billed amount.');
    end;

    [Test]
    procedure Scenario_AC04_ContractPreviewInvoice_LeavesNothingBehind()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingLine: Record "Billing Line";
        SalesHeader: Record "Sales Header";
        ResponseJson: JsonObject;
        BillingLinesBefore: Integer;
        SalesHeadersBefore: Integer;
    begin
        // Issue #43, AC04 | Time: WorkDate() | Risk: None
        // [GIVEN] A customer contract with a line due, and the counts of billing lines and sales headers
        ClearPendingProposals();
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        BillingLinesBefore := BillingLine.Count();
        SalesHeadersBefore := SalesHeader.Count();

        // [WHEN] Subscription.Contract.PreviewInvoice runs
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.PreviewInvoice", ContractRequest(CustomerContract."No."));

        // [THEN] It reports the line it would bill, and no billing line or sales header remains
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'wouldBillLineCount'), 'The preview must report the due line.');
        Assert.AreEqual(BillingLinesBefore, BillingLine.Count(), 'The preview must delete its billing lines again.');
        Assert.AreEqual(SalesHeadersBefore, SalesHeader.Count(), 'The preview must create no sales document.');
    end;

    [Test]
    procedure Scenario_AC04_VendorContractPreviewInvoice_LeavesNothingBehind()
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingLine: Record "Billing Line";
        PurchaseHeader: Record "Purchase Header";
        ResponseJson: JsonObject;
        BillingLinesBefore: Integer;
        PurchaseHeadersBefore: Integer;
    begin
        // Issue #43, AC04 vendor | Time: WorkDate() | Risk: None
        // [GIVEN] A vendor contract with a line due, and the counts of billing lines and purchase headers
        ClearPendingProposals();
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);
        BillingLinesBefore := BillingLine.Count();
        PurchaseHeadersBefore := PurchaseHeader.Count();

        // [WHEN] Subscription.VendorContract.PreviewInvoice runs
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.VendorContract.PreviewInvoice", ContractRequest(VendorContract."No."));

        // [THEN] It reports the line it would bill, and no billing line or purchase header remains
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'wouldBillLineCount'), 'The preview must report the due line.');
        Assert.AreEqual(BillingLinesBefore, BillingLine.Count(), 'The preview must delete its billing lines again.');
        Assert.AreEqual(PurchaseHeadersBefore, PurchaseHeader.Count(), 'The preview must create no purchase document.');
    end;

    local procedure ContractRequest(ContractNo: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('contractNo', ContractNo);
    end;

    local procedure ClearPendingProposals()
    var
        BillingLine: Record "Billing Line";
    begin
        // The invoice types refuse to run while another contract has template-less proposal lines
        // that are on no document; demo data may have some.
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        if not BillingLine.IsEmpty() then
            BillingLine.DeleteAll(false);
    end;
}
