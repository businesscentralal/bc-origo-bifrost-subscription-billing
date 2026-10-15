namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC09 and AC10: Deferral.Release releases real contract deferrals of a
/// posted contract invoice and posts the release to the general ledger, and Analysis.Recalculate
/// adds contract analysis entries for a contract. Every test seeds its own contract.
/// </summary>
codeunit 95778 "Sub Deferral Analysis Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibrarySales: Codeunit "Library - Sales";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    [HandlerFunctions('DocumentsCreatedMessageHandler')]
    procedure Scenario_AC09_Release_ReleasesDeferralAndPostsToGL()
    var
        CustSubContractDeferral: Record "Cust. Sub. Contract Deferral";
        SourceCodeSetup: Record "Source Code Setup";
        GLEntry: Record "G/L Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PostedInvoiceNo: Code[20];
    begin
        // Issue #43, AC09 | Time: postingDate is the work date, the only date the release report uses | Risk: releases nothing else, other deferrals are set aside first
        // [GIVEN] A posted contract invoice whose first deferral posts on the work date
        PostedInvoiceNo := PostContractInvoiceWithDeferrals();
        CustSubContractDeferral.SetRange("Document No.", PostedInvoiceNo);
        Assert.RecordIsNotEmpty(CustSubContractDeferral);
        CustSubContractDeferral.SetFilter("Posting Date", '<=%1', WorkDate());
        CustSubContractDeferral.SetRange(Released, false);
        Assert.RecordIsNotEmpty(CustSubContractDeferral);

        // [WHEN] Subscription.Deferral.Release runs on the work date
        RequestJson.Add('postingDate', Format(WorkDate(), 0, 9));
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Deferral.Release", RequestJson);

        // [THEN] The deferral is released and a G/L entry with the release source code exists for the invoice
        Assert.IsTrue(TestLibrary.ReadInteger(ResponseJson, 'customerDeferralsReleased') >= 1, 'At least one customer deferral must be released.');
        Assert.RecordIsEmpty(CustSubContractDeferral);
        CustSubContractDeferral.SetRange(Released, true);
        CustSubContractDeferral.FindFirst();
        Assert.AreEqual(WorkDate(), CustSubContractDeferral."Release Posting Date", 'The release must post on the work date.');
        SourceCodeSetup.Get();
        GLEntry.SetRange("Document No.", PostedInvoiceNo);
        GLEntry.SetRange("Source Code", SourceCodeSetup."Sub. Contr. Deferrals Release");
        Assert.RecordIsNotEmpty(GLEntry);
    end;

    [Test]
    procedure Scenario_AC09_Release_OtherPostingDate_IsRefused()
    var
        RequestJson: JsonObject;
    begin
        // Issue #43, AC09 refusal | Time: postingDate one day after the work date | Risk: None
        // [WHEN] Deferral.Release names a posting date that is not the work date
        TestLibrary.InitSubscriptionBilling();
        RequestJson.Add('postingDate', Format(CalcDate('<+1D>', WorkDate()), 0, 9));
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Deferral.Release", RequestJson);

        // [THEN] The call is refused: the report always posts under the work date
        Assert.ExpectedError('postingDate');
    end;

    [Test]
    procedure Scenario_AC09_Release_PostUntilAfterPostingDate_IsRefused()
    var
        RequestJson: JsonObject;
    begin
        // Issue #43, AC09 edge case | Time: postUntilDate one day after the work date | Risk: None
        // [WHEN] postUntilDate is later than postingDate
        TestLibrary.InitSubscriptionBilling();
        RequestJson.Add('postingDate', Format(WorkDate(), 0, 9));
        RequestJson.Add('postUntilDate', Format(CalcDate('<+1D>', WorkDate()), 0, 9));
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Deferral.Release", RequestJson);

        // [THEN] The call is refused
        Assert.ExpectedError('postUntilDate');
    end;

    [Test]
    procedure Scenario_AC10_Recalculate_AddsAnalysisEntriesForContract()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubContrAnalysisEntry: Record "Sub. Contr. Analysis Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC10 | Time: the report analyses as of Today() | Risk: None
        // [GIVEN] A customer contract with one line and no analysis entries
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        SubContrAnalysisEntry.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordIsEmpty(SubContrAnalysisEntry);

        // [WHEN] Subscription.Analysis.Recalculate runs, narrowed to the contract
        RequestJson.Add('contractNo', CustomerContract."No.");
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", RequestJson);

        // [THEN] An analysis entry exists for the contract and the counts say so
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'entriesCreated'), 'One analysis entry must be added for the contract line.');
        Assert.AreEqual(1, TestLibrary.ReadInteger(ResponseJson, 'totalEntries'), 'The contract must have one analysis entry.');
        Assert.RecordCount(SubContrAnalysisEntry, 1);
    end;

    [Test]
    procedure Scenario_AC10_RecalculateTwice_AddsNothingTheSecondTime()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubContrAnalysisEntry: Record "Sub. Contr. Analysis Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // Issue #43, AC10 edge case | Time: both runs in the same month | Risk: None
        // [GIVEN] A contract that was analysed this month
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        RequestJson.Add('contractNo', CustomerContract."No.");
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", RequestJson);

        // [WHEN] Analysis.Recalculate runs again
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", RequestJson);

        // [THEN] Nothing is added for the contract
        Assert.AreEqual(0, TestLibrary.ReadInteger(ResponseJson, 'entriesCreated'), 'A line analysed this month must not be analysed again.');
        SubContrAnalysisEntry.SetRange("Subscription Contract No.", CustomerContract."No.");
        Assert.RecordCount(SubContrAnalysisEntry, 1);
    end;

    /// <summary>Bills a new customer contract with Subscription.Contract.CreateInvoice, posts the invoice and returns the posted invoice number.</summary>
    local procedure PostContractInvoiceWithDeferrals() PostedInvoiceNo: Code[20]
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SalesHeader: Record "Sales Header";
        BillingLine: Record "Billing Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentToken: JsonToken;
    begin
        SetAsideOtherDeferrals();
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        if not BillingLine.IsEmpty() then
            BillingLine.DeleteAll(false);
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        RequestJson.Add('contractNo', CustomerContract."No.");
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.CreateInvoice", RequestJson);
        TestLibrary.ReadArray(ResponseJson, 'documents').Get(0, DocumentToken);
        SalesHeader.Get(SalesHeader."Document Type"::Invoice, CopyStr(TestLibrary.ReadText(DocumentToken.AsObject(), 'documentNo'), 1, MaxStrLen(SalesHeader."No.")));
        PostedInvoiceNo := LibrarySales.PostSalesDocument(SalesHeader, false, true);
    end;

    /// <summary>Marks the unreleased deferrals that already exist as released, so the release in the test only touches the test's own invoice.</summary>
    local procedure SetAsideOtherDeferrals()
    var
        CustSubContractDeferral: Record "Cust. Sub. Contract Deferral";
        VendSubContractDeferral: Record "Vend. Sub. Contract Deferral";
    begin
        CustSubContractDeferral.SetRange(Released, false);
        if not CustSubContractDeferral.IsEmpty() then
            CustSubContractDeferral.ModifyAll(Released, true, false);
        VendSubContractDeferral.SetRange(Released, false);
        if not VendSubContractDeferral.IsEmpty() then
            VendSubContractDeferral.ModifyAll(Released, true, false);
    end;

    [MessageHandler]
    procedure DocumentsCreatedMessageHandler(Message: Text[1024])
    begin
        // Microsoft's Create Billing Documents reports what it created; an API session shows no message.
    end;
}
