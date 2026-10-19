namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Vendor;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// #41: the should-have flows - AddLinesToInvoice (AC01), Billing.SetTemplateFilter (AC04),
/// Contract.RemoveLine and Package.RemoveItemAssignment (AC05).
/// </summary>
codeunit 95715 "Sub Should Have Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA41', Locked = true;
        HeaderNoTok: Label 'XSBA41SUB', Locked = true;
        ContractNoTok: Label 'XSBA41CC', Locked = true;
        VendorContractNoTok: Label 'XSBA41VC', Locked = true;
        TemplateTok: Label 'XSBA41T', Locked = true;
        InvoiceNoTok: Label 'XSBA41INV', Locked = true;
        PostedNoTok: Label 'XSBA41PST', Locked = true;
        PackageTok: Label 'XSBA41PKG', Locked = true;

    /// <summary>AC01: real vendor contract billing adds persisted lines only to the requested existing invoice.</summary>
    [Test]
    procedure AddLinesToInvoice_DueVendorLine_PersistsBilling()
    var
        VendorContract: Record "Vendor Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        BillingLine: Record "Billing Line";
        TestLibrary: Codeunit "Sub Test Library ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EntryNos: JsonArray;
    begin
        // [GIVEN] A validated billable vendor contract and an existing unposted invoice for its vendor.
        TestLibrary.CreateBillableVendorContract(VendorContract, SubscriptionHeader);
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Invoice;
        PurchaseHeader.Insert(true);
        PurchaseHeader.Validate("Buy-from Vendor No.", VendorContract."Buy-from Vendor No.");
        PurchaseHeader.Modify(true);
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.FindFirst();
        EntryNos.Add(SubscriptionLine."Entry No.");
        RequestJson.Add('subscriptionLineEntryNos', EntryNos);
        // [WHEN] Only the selected vendor subscription line is billed onto this invoice.
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", PurchaseHeader."No.", RequestJson, false);
        // [THEN] Response, physical purchase lines and linked billing lines agree.
        TestLib.AssertSuccess(ResponseJson);
        Assert.IsTrue(TestLib.GetInteger(ResponseJson, 'linesAdded') > 0, 'The invoice must gain purchase lines.');
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        Assert.AreEqual(PurchaseLine.Count(), TestLib.GetInteger(ResponseJson, 'linesAdded'), 'The response must count persisted lines.');
        PurchaseLine.CalcSums("Line Amount");
        Assert.AreNotEqual(0, PurchaseLine."Line Amount", 'The invoice must carry a billed amount.');
        BillingLine.SetRange("Subscription Contract No.", VendorContract."No.");
        BillingLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        BillingLine.SetRange("Document No.", PurchaseHeader."No.");
        Assert.RecordIsNotEmpty(BillingLine);
    end;

    /// <summary>AC01, edge: an invoice of a vendor without due contract lines gains nothing and the call succeeds.</summary>
    [Test]
    procedure AddLinesToInvoice_NoDueLines_SucceedsWithZero()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] An unposted purchase invoice of a vendor that has no vendor contract lines
        Initialize();
        CreatePurchaseInvoice();

        // [WHEN] The due vendor contract lines are added
        RequestJson.Add('contractNo', VendorContractNoTok);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", InvoiceNoTok, RequestJson, false);

        // [THEN] Nothing is added
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'linesAdded'), 'No line is due.');
    end;

    /// <summary>AC01, AC07: a posted invoice and a line of another vendor are refused.</summary>
    [Test]
    procedure AddLinesToInvoice_PostedOrOtherVendor_IsRefused()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A posted purchase invoice
        Initialize();
        PurchInvHeader.Init();
        PurchInvHeader."No." := PostedNoTok;
        PurchInvHeader.Insert(false);
        Commit();

        // [WHEN] Lines are added to it
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", PostedNoTok, RequestJson, false);

        // [THEN] The call is refused because the invoice is posted
        TestLib.AssertRefused(ResponseJson, 'is posted');

        // [GIVEN] An unposted invoice and a vendor contract line of another vendor
        CreatePurchaseInvoice();
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateVendorContract(VendorContractNoTok, 'XSBA41OTHER');
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Vendor, VendorContractNoTok, WorkDate(), 0D, WorkDate());
        TestLib.CreateVendorContractLine(VendorContractNoTok, HeaderNoTok, LineEntryNo);
        Commit();

        // [WHEN] That line is listed
        EntryNos.Add(LineEntryNo);
        RequestJson.Add('subscriptionLineEntryNos', EntryNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", InvoiceNoTok, RequestJson, false);

        // [THEN] The call is refused because the line belongs to another vendor
        TestLib.AssertRefused(ResponseJson, 'another vendor');
    end;

    /// <summary>AC04: a valid view is normalised and stored on the template.</summary>
    [Test]
    procedure BillingSetTemplateFilter_ValidView_IsStored()
    var
        BillingTemplate: Record "Billing Template";
        CustomerContract: Record "Customer Subscription Contract";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        FilterStream: InStream;
        StoredFilter: Text;
    begin
        // [GIVEN] A customer Billing Template
        Initialize();

        // [WHEN] A contract filter is written
        RequestJson.Add('filter', 'WHERE("No."=FILTER(XSBA41CC))');
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.SetTemplateFilter", TemplateTok, RequestJson, false);

        // [THEN] The stored view selects the intended contract and is the one reported
        TestLib.AssertSuccess(ResponseJson);
        BillingTemplate.Get(TemplateTok);
        BillingTemplate.CalcFields(Filter);
        BillingTemplate.Filter.CreateInStream(FilterStream, TextEncoding::UTF8);
        FilterStream.ReadText(StoredFilter);
        Assert.AreEqual(TestLib.GetText(ResponseJson, 'filter'), StoredFilter, 'The answer must report the stored filter.');
        CustomerContract.SetView(StoredFilter);
        Assert.AreEqual('XSBA41CC', CustomerContract.GetFilter("No."), 'The stored view must keep the contract filter.');
    end;

    /// <summary>AC04, AC07: a view with an unknown field is refused with a structured error and nothing is written.</summary>
    [Test]
    procedure BillingSetTemplateFilter_UnknownField_IsRefusedAndNothingWritten()
    var
        BillingTemplate: Record "Billing Template";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] A Billing Template without a filter
        Initialize();

        // [WHEN] A view with a mistyped field is sent
        RequestJson.Add('filter', 'WHERE(MistypedField=FILTER(1))');
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Billing.SetTemplateFilter", TemplateTok, RequestJson, false);

        // [THEN] The call is refused with a code and the template keeps no filter
        Assert.AreEqual('Error', TestLib.GetText(ResponseJson, 'status'), 'An invalid view must be refused.');
        Assert.AreNotEqual('', TestLib.GetText(ResponseJson, 'code'), 'The refusal must carry a code.');
        BillingTemplate.Get(TemplateTok);
        BillingTemplate.CalcFields(Filter);
        Assert.IsFalse(BillingTemplate.Filter.HasValue(), 'Nothing may be written.');
    end;

    /// <summary>AC05: an unbilled contract line is removed and its Subscription Line detached.</summary>
    [Test]
    procedure RemoveLine_UnbilledLine_IsRemoved()
    var
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
        LineNo: Integer;
    begin
        // [GIVEN] A customer contract line of an unbilled Subscription Line
        Initialize();
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateCustomerContract(ContractNoTok, '');
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, WorkDate(), 0D, WorkDate());
        LineNo := TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, LineEntryNo);
        Commit();

        // [WHEN] The line is removed
        RequestJson.Add('lineNo', LineNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.RemoveLine", ContractNoTok, RequestJson, false);

        // [THEN] The contract line is gone and the Subscription Line no longer names the contract
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(LineEntryNo, TestLib.GetInteger(ResponseJson, 'subscriptionLineEntryNo'), 'The detached line must be reported.');
        Assert.IsFalse(CustSubContractLine.Get(ContractNoTok, LineNo), 'The contract line must be deleted.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual('', SubscriptionLine."Subscription Contract No.", 'The Subscription Line must be detached from the contract.');
    end;

    /// <summary>AC05, AC07: a line on a billing line and a closed line are refused; an unknown line is refused by number.</summary>
    [Test]
    procedure RemoveLine_InBillingClosedOrUnknown_IsRefused()
    var
        BillingLine: Record "Billing Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
        LineNo: Integer;
    begin
        // [GIVEN] A contract line that is on a billing proposal line
        Initialize();
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateCustomerContract(ContractNoTok, '');
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, WorkDate(), 0D, WorkDate());
        LineNo := TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, LineEntryNo);
        BillingLine.Init();
        BillingLine.Partner := BillingLine.Partner::Customer;
        BillingLine."Subscription Contract No." := ContractNoTok;
        BillingLine."Subscription Contract Line No." := LineNo;
        BillingLine."Subscription Header No." := HeaderNoTok;
        BillingLine."Subscription Line Entry No." := LineEntryNo;
        BillingLine.Insert(false);
        Commit();

        // [WHEN] It is removed
        RequestJson.Add('lineNo', LineNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.RemoveLine", ContractNoTok, RequestJson, false);

        // [THEN] The call is refused and the line stays
        TestLib.AssertRefused(ResponseJson, 'billing line');
        Assert.IsTrue(CustSubContractLine.Get(ContractNoTok, LineNo), 'A refused line must stay.');

        // [WHEN] The billing line is gone but the contract line is closed
        BillingLine.Delete(false);
        CustSubContractLine.Closed := true;
        CustSubContractLine.Modify(false);
        Commit();
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.RemoveLine", ContractNoTok, RequestJson, false);

        // [THEN] The call is refused because the line is closed
        TestLib.AssertRefused(ResponseJson, 'is closed');

        // [WHEN] A line number the contract does not have is sent
        Clear(RequestJson);
        RequestJson.Add('lineNo', 99990000);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.RemoveLine", ContractNoTok, RequestJson, false);

        // [THEN] The line number is named
        TestLib.AssertRefused(ResponseJson, '99990000');
    end;

    /// <summary>AC05: a package assignment is removed; an assignment that does not exist is refused.</summary>
    [Test]
    procedure RemoveItemAssignment_RemovesAndRefusesUnknown()
    var
        ItemSubscriptionPackage: Record "Item Subscription Package";
        Item: Record Item;
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] An item with a package assignment
        Initialize();
        Item.FindFirst();
        ItemSubscriptionPackage.Init();
        ItemSubscriptionPackage."Item No." := Item."No.";
        ItemSubscriptionPackage.Code := PackageTok;
        ItemSubscriptionPackage.Standard := true;
        ItemSubscriptionPackage.Insert(false);
        Commit();

        // [WHEN] The assignment is removed
        RequestJson.Add('subscriptionPackageCode', PackageTok);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Package.RemoveItemAssignment", Item."No.", RequestJson, false);

        // [THEN] It is gone and was reported as standard
        TestLib.AssertSuccess(ResponseJson);
        Assert.IsTrue(TestLib.GetBoolean(ResponseJson, 'wasStandard'), 'The assignment was a standard package.');
        Assert.IsFalse(ItemSubscriptionPackage.Get(Item."No.", PackageTok), 'The assignment must be deleted.');

        // [WHEN] It is removed again
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Package.RemoveItemAssignment", Item."No.", RequestJson, false);

        // [THEN] The call is refused and names the package
        TestLib.AssertRefused(ResponseJson, PackageTok);
    end;

    local procedure Initialize()
    var
        BillingTemplate: Record "Billing Template";
        PurchaseHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        ItemSubscriptionPackage: Record "Item Subscription Package";
    begin
        TestLib.DeleteFixture(PrefixTok);
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, InvoiceNoTok) then
            PurchaseHeader.Delete(false);
        if PurchInvHeader.Get(PostedNoTok) then
            PurchInvHeader.Delete(false);
        ItemSubscriptionPackage.SetRange(Code, PackageTok);
        ItemSubscriptionPackage.DeleteAll(false);
        BillingTemplate.SetFilter(Code, PrefixTok + '*');
        BillingTemplate.DeleteAll(false);
        BillingTemplate.Init();
        BillingTemplate.Code := TemplateTok;
        BillingTemplate.Description := 'X Branch A filter fixture';
        BillingTemplate.Partner := BillingTemplate.Partner::Customer;
        BillingTemplate.Insert(false);
        Commit();
    end;

    local procedure CreatePurchaseInvoice()
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record Vendor;
    begin
        Vendor.SetRange(Blocked, Vendor.Blocked::" ");
        Vendor.FindFirst();
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Invoice;
        PurchaseHeader."No." := InvoiceNoTok;
        PurchaseHeader.Insert(true);
        PurchaseHeader.Validate("Buy-from Vendor No.", Vendor."No.");
        PurchaseHeader.Modify(true);
        Commit();
    end;
}
