namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC05: Billing.CreateProposal builds proposal lines for a Billing
/// Template, and Billing.CreateDocuments turns them into documents. With postDocuments = true the
/// sales invoice is posted and a purchase invoice is not. The templates filter on the test's own
/// contract, so demo contracts are never billed.
/// </summary>
codeunit 95775 "Sub Billing Run Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC05_CreateProposal_AddsLinesForTemplateContract()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        ResponseJson: JsonObject;
        ContractToken: JsonToken;
    begin
        // Issue #43, AC05 | Time: WorkDate() is the billing date | Risk: None
        // [GIVEN] A customer contract with a line due and a template that bills only that contract
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, CustomerContract."No.");

        // [WHEN] Subscription.Billing.CreateProposal runs the template
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));

        // [THEN] One proposal line exists for the contract, on no document yet
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'proposalLinesCreated'), 'One proposal line must be created.');
        TestLibrary.ReadArray(ResponseJson, 'contracts').Get(0, ContractToken);
        Assert.AreEqual(CustomerContract."No.", ContractToken.AsValue().AsText(), 'The proposal must name the contract.');
        BillingLine.SetRange("Billing Template Code", BillingTemplate.Code);
        BillingLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        Assert.RecordCount(BillingLine, 1);
    end;

    [Test]
    procedure Scenario_AC05_CreateProposal_UnknownTemplate_IsRefused()
    begin
        // Issue #43, AC05 refusal | Time: none | Risk: None
        // [WHEN] CreateProposal names a template that does not exist
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest('XNOTEMPLATE'));

        // [THEN] The call is refused naming the template
        Assert.ExpectedError('XNOTEMPLATE');
    end;

    [Test]
    procedure Scenario_AC05_CreateDocumentsPosted_PostsSalesInvoice()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
        DocumentNo: Code[20];
    begin
        // Issue #43, AC05 posted | Time: WorkDate() is the document and posting date | Risk: None
        // [GIVEN] A proposal for one customer contract
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, CustomerContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));

        // [WHEN] Subscription.Billing.CreateDocuments runs with postDocuments = true
        RequestJson := TemplateRequest(BillingTemplate.Code);
        RequestJson.Add('postDocuments', true);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", RequestJson);

        // [THEN] The sales invoice is posted for the contract customer and the proposal line is archived
        Assert.AreEqual('Success', TestLibrary.ReadText(ResponseJson, 'status'), 'CreateDocuments must succeed.');
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'documentCount'), 'One document must be created.');
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(SalesInvoiceHeader.Get(DocumentNo), 'The posted sales invoice must exist.');
        Assert.AreEqual(CustomerContract."Sell-to Customer No.", SalesInvoiceHeader."Sell-to Customer No.", 'The posted invoice must be for the contract customer.');
        BillingLine.SetRange("Billing Template Code", BillingTemplate.Code);
        Assert.RecordIsEmpty(BillingLine);
    end;

    [Test]
    procedure Scenario_AC05_CreateDocumentsPosted_LeavesPurchaseInvoiceUnposted()
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
    begin
        // Issue #43, AC05 vendor edge case | Time: WorkDate() | Risk: None
        // [GIVEN] A proposal for one vendor contract
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Vendor, VendorContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", TemplateRequest(BillingTemplate.Code));

        // [WHEN] Subscription.Billing.CreateDocuments runs with postDocuments = true
        RequestJson := TemplateRequest(BillingTemplate.Code);
        RequestJson.Add('postDocuments', true);
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", RequestJson);

        // [THEN] The purchase invoice exists unposted for the contract vendor
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'documentCount'), 'One document must be created.');
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        DocumentNo := CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, DocumentNo), 'The purchase invoice must stay unposted.');
        Assert.AreEqual(VendorContract."Buy-from Vendor No.", PurchaseHeader."Buy-from Vendor No.", 'The invoice must be for the contract vendor.');
        PurchInvHeader.SetRange("Pre-Assigned No.", DocumentNo);
        Assert.RecordIsEmpty(PurchInvHeader);
    end;

    [Test]
    procedure Scenario_AC05_CreateDocuments_NoProposal_AnswersNothingPending()
    var
        BillingTemplate: Record "Billing Template";
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC05 edge case | Time: none | Risk: None
        // [GIVEN] A template without proposal lines
        TestLibrary.InitSubscriptionBilling();
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, 'XNOCONTRACT');

        // [WHEN] CreateDocuments runs
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", TemplateRequest(BillingTemplate.Code));

        // [THEN] Nothing is created and the answer says so
        Assert.AreEqual(0, TestLibrary.ReadInteger(ResponseJson, 'documentCount'), 'No document must be created.');
        Assert.AreNotEqual('', TestLibrary.ReadText(ResponseJson, 'message'), 'The answer must say nothing was pending.');
    end;

    local procedure TemplateRequest(TemplateCode: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('billingTemplateCode', TemplateCode);
    end;
}
