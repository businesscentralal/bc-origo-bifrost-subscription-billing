namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Posts documents a billing run left unposted, and refuses a foreign or already posted document (#52).
/// </summary>
codeunit 95718 "Sub PostDocs Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC03_PostDocuments_PostsBillingInvoice_AndRefusesItAgain()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        SalesHeader: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
        PostedNo: Code[20];
    begin
        // Issue #52, AC03 | Time: WorkDate() is the document and posting date | Risk: None
        // [GIVEN] An unposted sales invoice created by a billing run
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, CustomerContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", TemplateRequest(BillingTemplate.Code));
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Invoice, DocumentNo), 'The billing run must leave the sales invoice unposted.');

        // [WHEN] Subscription.Billing.PostDocuments posts that invoice
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Customer', 'Invoice', DocumentNo));

        // [THEN] The invoice is posted
        Assert.AreEqual('Success', TestLibrary.ReadText(ResponseJson, 'status'), TestLibrary.AsText(ResponseJson));
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'postedCount'), 'One document must be posted.');
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        PostedNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'postedDocumentNo'), 1, MaxStrLen(PostedNo));
        Assert.IsTrue(SalesInvoiceHeader.Get(PostedNo), 'The posted sales invoice must exist.');
        Assert.IsFalse(SalesHeader.Get(SalesHeader."Document Type"::Invoice, DocumentNo), 'The unposted sales invoice must be gone.');

        // [WHEN] The same invoice is posted again
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Customer', 'Invoice', DocumentNo));

        // [THEN] The second call is refused because the document is already posted
        Assert.ExpectedError('already posted');
    end;

    [Test]
    procedure Scenario_AC03_PostDocuments_RefusesForeignSalesInvoice()
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
    begin
        // Issue #52, AC03 foreign | Time: none | Risk: None
        // [GIVEN] A sales invoice that Subscription Billing did not create
        TestLibrary.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Invoice, Customer."No.");

        // [WHEN] Subscription.Billing.PostDocuments is asked to post it
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Customer', 'Invoice', SalesHeader."No."));

        // [THEN] The call is refused and names Sales.Document.Post, and the invoice stays unposted
        Assert.ExpectedError('Sales.Document.Post');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Invoice, SalesHeader."No."), 'The foreign invoice must stay unposted.');
    end;

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC01_PostDocuments_PostsVendorInvoice()
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        PurchaseHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
        PostedNo: Code[20];
    begin
        // Issue #52, AC01 vendor | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted purchase invoice from a billing run (CreateDocuments never posts purchase documents)
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Vendor, VendorContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));
        RequestJson := TemplateRequest(BillingTemplate.Code);
        RequestJson.Add('postDocuments', true);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", RequestJson);
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The purchase invoice must still be open.');

        // [WHEN] Subscription.Billing.PostDocuments posts it
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Vendor', 'Invoice', DocumentNo));

        // [THEN] The purchase invoice is posted and carries a vendor invoice number
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'postedCount'), TestLibrary.AsText(ResponseJson));
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        PostedNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'postedDocumentNo'), 1, MaxStrLen(PostedNo));
        Assert.AreNotEqual('', TestLibrary.ReadText(DocumentToken.AsObject(), 'vendorInvoiceNo'), 'The answer must name the vendor invoice number.');
        Assert.IsTrue(PurchInvHeader.Get(PostedNo), 'The posted purchase invoice must exist.');
        Assert.AreNotEqual('', PurchInvHeader."Vendor Invoice No.", 'Vendor Invoice No. must be filled before posting.');
        Assert.IsFalse(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The unposted purchase invoice must be gone.');
    end;

    local procedure TemplateRequest(TemplateCode: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('billingTemplateCode', TemplateCode);
    end;

    local procedure DocumentsRequest(Partner: Text; DocumentType: Text; DocumentNo: Code[20]) RequestJson: JsonObject
    var
        Documents: JsonArray;
        DocumentJson: JsonObject;
    begin
        DocumentJson.Add('partner', Partner);
        DocumentJson.Add('documentType', DocumentType);
        DocumentJson.Add('documentNo', DocumentNo);
        Documents.Add(DocumentJson);
        RequestJson.Add('documents', Documents);
    end;

    [MessageHandler]
    procedure BillingMessageHandler(Message: Text[1024])
    begin
        // Microsoft reports the documents it created, and posting may report the posted number.
    end;
}
