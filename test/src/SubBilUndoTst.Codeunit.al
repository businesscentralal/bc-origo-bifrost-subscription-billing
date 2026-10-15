namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// #37: Subscription.Billing.ClearProposal and Subscription.Billing.DeleteDocuments undo a billing run.
/// The proposal is seeded the way Microsoft's billing proposal leaves it: a billing line for the
/// period and the Subscription Line's Next Billing Date moved past it.
/// </summary>
codeunit 95712 "Sub Bil Undo Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA37', Locked = true;
        TemplateTok: Label 'XSBA37T', Locked = true;
        HeaderNoTok: Label 'XSBA37SUB', Locked = true;
        ContractNoTok: Label 'XSBA37CC', Locked = true;
        InvoiceNoTok: Label 'XSBA37INV', Locked = true;
        PostedNoTok: Label 'XSBA37PST', Locked = true;

    /// <summary>AC01, AC03, AC05: clearing a proposal deletes its lines and restores the Next Billing Date.</summary>
    [Test]
    procedure ClearProposal_DeletesLinesAndRestoresNextBillingDate()
    var
        BillingLine: Record "Billing Line";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
        PeriodStart: Date;
    begin
        // [GIVEN] A proposal line for one month and the Subscription Line moved past that month
        Initialize();
        PeriodStart := DMY2Date(1, 1, Date2DMY(WorkDate(), 3));
        LineEntryNo := CreateProposal(PeriodStart, '');

        // [WHEN] The proposal of the template is cleared
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.ClearProposal", TemplateTok, RequestJson, false);

        // [THEN] The line is gone and the Subscription Line is due again from the period start
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'billingLinesDeleted'), 'One proposal line must be deleted.');
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'subscriptionLinesReset'), 'One Subscription Line must be reset.');
        BillingLine.SetRange("Billing Template Code", TemplateTok);
        Assert.RecordIsEmpty(BillingLine);
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(PeriodStart, SubscriptionLine."Next Billing Date", 'The Next Billing Date must be restored to the start of the cleared period.');
    end;

    /// <summary>AC01, AC06: a proposal line that is already on a document is refused and nothing is deleted.</summary>
    [Test]
    procedure ClearProposal_LineOnDocument_IsRefused()
    var
        BillingLine: Record "Billing Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] A proposal line that sits on a document
        Initialize();
        CreateProposal(DMY2Date(1, 1, Date2DMY(WorkDate(), 3)), InvoiceNoTok);

        // [WHEN] The proposal is cleared
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.ClearProposal", TemplateTok, RequestJson, false);

        // [THEN] The call is refused, names the undo type for documents, and the line stays
        TestLib.AssertRefused(ResponseJson, 'Subscription.Billing.DeleteDocuments');
        BillingLine.SetRange("Billing Template Code", TemplateTok);
        Assert.RecordIsNotEmpty(BillingLine);
    end;

    /// <summary>AC06, edge: without a template or a contract the call is refused; an unknown template is refused by name.</summary>
    [Test]
    procedure ClearProposal_NoSelectionOrUnknownTemplate_IsRefused()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] No fixture
        Initialize();

        // [WHEN] Neither billingTemplateCode nor contractNo is sent
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.ClearProposal", '', RequestJson, false);

        // [THEN] The call asks for one of them
        TestLib.AssertRefused(ResponseJson, 'contractNo');

        // [WHEN] An unknown template is named
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.ClearProposal", 'XSBA37NONE', RequestJson, false);

        // [THEN] The template is named in the refusal
        TestLib.AssertRefused(ResponseJson, 'XSBA37NONE');
    end;

    /// <summary>AC02, AC03, AC05: deleting the documents removes the invoice and puts its billing line back in the proposal.</summary>
    [Test]
    procedure DeleteDocuments_ReturnsBillingLineToProposal()
    var
        BillingLine: Record "Billing Line";
        SalesHeader: Record "Sales Header";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] An unposted sales invoice made from a template proposal line
        Initialize();
        CreateSalesInvoice();
        CreateProposal(DMY2Date(1, 1, Date2DMY(WorkDate(), 3)), InvoiceNoTok);

        // [WHEN] The documents of the template are deleted
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.DeleteDocuments", TemplateTok, RequestJson, false);

        // [THEN] The invoice is gone and its billing line is back in the proposal, without a document
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'documentsDeleted'), 'One document must be deleted.');
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'billingLinesReturnedToProposal'), 'The billing line must be back in the proposal.');
        Assert.IsFalse(SalesHeader.Get(SalesHeader."Document Type"::Invoice, InvoiceNoTok), 'The unposted invoice must be deleted.');
        BillingLine.SetRange("Billing Template Code", TemplateTok);
        BillingLine.FindFirst();
        Assert.AreEqual('', BillingLine."Document No.", 'The billing line must no longer name the document.');
    end;

    /// <summary>AC02, AC06: a posted document number is refused by name.</summary>
    [Test]
    procedure DeleteDocuments_PostedDocument_IsRefused()
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] A posted sales invoice
        Initialize();
        SalesInvoiceHeader.Init();
        SalesInvoiceHeader."No." := PostedNoTok;
        SalesInvoiceHeader.Insert(false);

        // [WHEN] Its number is passed to DeleteDocuments
        RequestJson.Add('documentNo', PostedNoTok);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.DeleteDocuments", TemplateTok, RequestJson, false);

        // [THEN] The call is refused because the document is posted, and the posted invoice is untouched
        TestLib.AssertRefused(ResponseJson, 'is posted');
        Assert.IsTrue(SalesInvoiceHeader.Get(PostedNoTok), 'A posted invoice must never be touched.');
        SalesInvoiceHeader.Delete(false);
    end;

    /// <summary>Edge: a template without documents deletes nothing and still succeeds.</summary>
    [Test]
    procedure DeleteDocuments_NoDocuments_SucceedsWithZero()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] A template whose proposal line is on no document
        Initialize();
        CreateProposal(DMY2Date(1, 1, Date2DMY(WorkDate(), 3)), '');

        // [WHEN] Its documents are deleted
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.DeleteDocuments", TemplateTok, RequestJson, false);

        // [THEN] Nothing is deleted
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'documentsDeleted'), 'No document exists to delete.');
    end;

    local procedure Initialize()
    var
        BillingTemplate: Record "Billing Template";
        SalesHeader: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        TestLib.DeleteFixture(PrefixTok);
        if SalesHeader.Get(SalesHeader."Document Type"::Invoice, InvoiceNoTok) then
            SalesHeader.Delete(false);
        if SalesInvoiceHeader.Get(PostedNoTok) then
            SalesInvoiceHeader.Delete(false);
        BillingTemplate.SetFilter(Code, PrefixTok + '*');
        BillingTemplate.DeleteAll(false);
        BillingTemplate.Init();
        BillingTemplate.Code := TemplateTok;
        BillingTemplate.Description := 'X Branch A undo fixture';
        BillingTemplate.Partner := BillingTemplate.Partner::Customer;
        BillingTemplate.Insert(false);
        Commit();
    end;

    /// <summary>Seeds a customer contract with one Subscription Line and one proposal line for the month from PeriodStart.</summary>
    local procedure CreateProposal(PeriodStart: Date; DocumentNo: Code[20]) LineEntryNo: Integer
    var
        BillingLine: Record "Billing Line";
        PeriodEnd: Date;
    begin
        PeriodEnd := CalcDate('<CM>', PeriodStart);
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateCustomerContract(ContractNoTok, '');
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, CalcDate('<-1Y>', PeriodStart), 0D, PeriodEnd + 1);
        TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, LineEntryNo);
        BillingLine.Init();
        BillingLine."Billing Template Code" := TemplateTok;
        BillingLine.Partner := BillingLine.Partner::Customer;
        BillingLine."Subscription Contract No." := ContractNoTok;
        BillingLine."Subscription Header No." := HeaderNoTok;
        BillingLine."Subscription Line Entry No." := LineEntryNo;
        BillingLine."Billing from" := PeriodStart;
        BillingLine."Billing to" := PeriodEnd;
        if DocumentNo <> '' then begin
            BillingLine."Document Type" := BillingLine."Document Type"::Invoice;
            BillingLine."Document No." := DocumentNo;
        end;
        BillingLine.Insert(false);
        Commit();
    end;

    local procedure CreateSalesInvoice()
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
    begin
        Customer.SetRange(Blocked, Customer.Blocked::" ");
        Customer.FindFirst();
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;
        SalesHeader."No." := InvoiceNoTok;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", Customer."No.");
        SalesHeader.Modify(true);
        Commit();
    end;
}
