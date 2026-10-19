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
/// Posts documents a billing run left unposted, and refuses a foreign or already posted document and a
/// purchase document without the vendor's own document number (#52).
/// </summary>
codeunit 95718 "Sub PostDocs Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        LibrarySales: Codeunit "Library - Sales";
        IcelandicVendorNoTok: Label 'skjalanúmer lánardrottins', Locked = true;

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
    procedure Scenario_AC01_PostDocuments_PostsVendorInvoiceWithVendorInvoiceNo()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
        PostedNo: Code[20];
        VendorInvoiceNo: Text;
    begin
        // Issue #52, AC01 vendor | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted purchase invoice from a billing run (CreateDocuments never posts purchase documents)
        DocumentNo := CreateUnpostedVendorBillingInvoice();
        VendorInvoiceNo := 'XVPOST-' + DocumentNo;

        // [WHEN] Subscription.Billing.PostDocuments posts it with the vendor's invoice number on the entry
        RequestJson := DocumentsRequest('Vendor', 'Invoice', DocumentNo);
        SetEntryVendorInvoiceNo(RequestJson, VendorInvoiceNo);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", RequestJson);

        // [THEN] The purchase invoice is posted with exactly that vendor invoice number
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'postedCount'), TestLibrary.AsText(ResponseJson));
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        PostedNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'postedDocumentNo'), 1, MaxStrLen(PostedNo));
        Assert.AreEqual(VendorInvoiceNo, TestLibrary.ReadText(DocumentToken.AsObject(), 'vendorInvoiceNo'), 'The answer must name the vendor invoice number sent.');
        Assert.IsTrue(PurchInvHeader.Get(PostedNo), 'The posted purchase invoice must exist.');
        Assert.AreEqual(VendorInvoiceNo, PurchInvHeader."Vendor Invoice No.", 'The posted invoice must carry the vendor invoice number sent.');
        Assert.IsFalse(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The unposted purchase invoice must be gone.');
    end;

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC01_PostDocuments_TopLevelVendorInvoiceNo_PostsSingleVendorInvoice()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
        VendorInvoiceNo: Text;
    begin
        // Issue #52, AC01 edge case: one purchase document and a single top-level vendorInvoiceNo | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted purchase invoice from a billing run
        DocumentNo := CreateUnpostedVendorBillingInvoice();
        VendorInvoiceNo := 'XVTOP-' + DocumentNo;

        // [WHEN] The request sends vendorInvoiceNo once, at the top level
        RequestJson := DocumentsRequest('Vendor', 'Invoice', DocumentNo);
        RequestJson.Add('vendorInvoiceNo', VendorInvoiceNo);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", RequestJson);

        // [THEN] The invoice is posted with that number
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        Assert.IsTrue(PurchInvHeader.Get(CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'postedDocumentNo'), 1, 20)), TestLibrary.AsText(ResponseJson));
        Assert.AreEqual(VendorInvoiceNo, PurchInvHeader."Vendor Invoice No.", 'The top-level vendorInvoiceNo must be used.');
    end;

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC02_PostDocuments_VendorWithoutVendorInvoiceNo_IsRefused()
    var
        PurchaseHeader: Record "Purchase Header";
        ResponseJson: JsonObject;
        DocumentNo: Code[20];
    begin
        // Issue #52, AC02 refusal | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted purchase invoice from a billing run, with a blank Vendor Invoice No.
        DocumentNo := CreateUnpostedVendorBillingInvoice();
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo);
        Assert.AreEqual('', PurchaseHeader."Vendor Invoice No.", 'The fixture must start without a vendor invoice number.');

        // [WHEN] Subscription.Billing.PostDocuments is called without vendorInvoiceNo
        GlobalLanguage(1033);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Vendor', 'Invoice', DocumentNo));

        // [THEN] It is refused with a named error and nextStep, the document number is not used as the vendor's number, and nothing is posted
        Assert.AreEqual('Error', TestLibrary.ReadText(ResponseJson, 'status'), TestLibrary.AsText(ResponseJson));
        Assert.AreEqual('vendorInvoiceNo', TestLibrary.ReadText(ResponseJson, 'parameter'), 'The refusal must name vendorInvoiceNo.');
        Assert.IsTrue(TestLibrary.ReadText(ResponseJson, 'error').Contains('no vendor document number'), TestLibrary.AsText(ResponseJson));
        Assert.IsTrue(TestLibrary.ReadText(ResponseJson, 'nextStep').Contains('vendorInvoiceNo'), 'nextStep must say what to send.');
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo);
        Assert.AreEqual('', PurchaseHeader."Vendor Invoice No.", 'Vendor Invoice No. must not be invented from the document number.');
    end;

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC02_PostDocuments_VendorWithoutVendorInvoiceNo_IsRefusedInIcelandic()
    var
        PurchaseHeader: Record "Purchase Header";
        ResponseJson: JsonObject;
        DocumentNo: Code[20];
        ErrorText: Text;
    begin
        // Issue #52, AC02 lcid 1039 | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted purchase invoice from a billing run, with a blank Vendor Invoice No.
        DocumentNo := CreateUnpostedVendorBillingInvoice();

        // [WHEN] Subscription.Billing.PostDocuments is called without vendorInvoiceNo in Icelandic
        GlobalLanguage(1039);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", DocumentsRequest('Vendor', 'Invoice', DocumentNo));
        ErrorText := TestLibrary.ReadText(ResponseJson, 'error');
        GlobalLanguage(1033);

        // [THEN] The refusal is Icelandic and the document stays open
        Assert.IsTrue(ErrorText.Contains(IcelandicVendorNoTok), 'The refusal must be Icelandic in lcid 1039: ' + ErrorText);
        Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The purchase invoice must stay unposted.');
    end;

    [Test]
    [HandlerFunctions('BillingMessageHandler')]
    procedure Scenario_AC02_PostDocuments_VendorInvoiceNoOnCustomerEntry_IsRefused()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        SalesHeader: Record "Sales Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
    begin
        // Issue #52, AC02 edge case | Time: WorkDate() | Risk: None
        // [GIVEN] An unposted sales invoice created by a billing run
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, CustomerContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", TemplateRequest(BillingTemplate.Code));
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));

        // [WHEN] The customer entry carries vendorInvoiceNo
        RequestJson := DocumentsRequest('Customer', 'Invoice', DocumentNo);
        SetEntryVendorInvoiceNo(RequestJson, 'XV-NOT-FOR-SALES');
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", RequestJson);

        // [THEN] The call is refused and the sales invoice stays unposted
        Assert.ExpectedError('purchase documents only');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Invoice, DocumentNo), 'The sales invoice must stay unposted.');
    end;

    local procedure CreateUnpostedVendorBillingInvoice() DocumentNo: Code[20]
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        PurchaseHeader: Record "Purchase Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
    begin
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Vendor, VendorContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));
        RequestJson := TemplateRequest(BillingTemplate.Code);
        RequestJson.Add('postDocuments', true);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", RequestJson);
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The purchase invoice must still be open.');
    end;

    local procedure SetEntryVendorInvoiceNo(var RequestJson: JsonObject; VendorInvoiceNo: Text)
    var
        Token: JsonToken;
        EntryToken: JsonToken;
    begin
        RequestJson.Get('documents', Token);
        Token.AsArray().Get(0, EntryToken);
        EntryToken.AsObject().Add('vendorInvoiceNo', VendorInvoiceNo);
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
