namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 63 regressions for contract-scoped analysis and vendor invoice identity checks.</summary>
codeunit 95722 "Sub Data Safety Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        TestLib: Codeunit "Sub Test Lib ori";

    [Test]
    procedure Scenario_AC01_Analysis_OnlyRequestedContract_EN()
    begin
        AssertScopedAnalysis(1033);
    end;

    [Test]
    procedure Scenario_AC01_Analysis_OnlyRequestedContract_IS()
    begin
        AssertScopedAnalysis(1039);
    end;

    [Test]
    procedure Scenario_AC01_AmbiguousPartnerNumber_Refused_EN()
    begin
        AssertAmbiguousPartnerNumber(1033);
    end;

    [Test]
    procedure Scenario_AC01_AmbiguousPartnerNumber_Refused_IS()
    begin
        AssertAmbiguousPartnerNumber(1039);
    end;

    local procedure AssertAmbiguousPartnerNumber(LanguageId: Integer)
    var
        Contract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
        CollisionVendor: Record "Vendor Subscription Contract";
        Subscription: Record "Subscription Header";
        VendorSubscription: Record "Subscription Header";
        Entry: Record "Sub. Contr. Analysis Entry";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        BeforeCount: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.CreateBillableCustomerContract(Contract, Subscription, 0D);
        TestLibrary.CreateBillableVendorContract(VendorContract, VendorSubscription);
        if VendorContract."No." <> Contract."No." then begin
            CollisionVendor.Init();
            CollisionVendor."No." := Contract."No.";
            CollisionVendor."Buy-from Vendor No." := VendorContract."Buy-from Vendor No.";
            CollisionVendor.Insert(false);
        end;
        BeforeCount := Entry.Count();
        Request.Add('contractNo', Contract."No.");
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", Request);
        Assert.AreEqual('AmbiguousRecord', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('contractNo', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.IsTrue(TestLibrary.ReadText(Response, 'nextStep') <> '', 'The caller must get a correction.');
        Assert.AreEqual(BeforeCount, Entry.Count(), 'An ambiguous number may not analyse either partner.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertScopedAnalysis(LanguageId: Integer)
    var
        Contract: Record "Customer Subscription Contract";
        OtherContract: Record "Customer Subscription Contract";
        Subscription: Record "Subscription Header";
        OtherSubscription: Record "Subscription Header";
        Entry: Record "Sub. Contr. Analysis Entry";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        BeforeCount: Integer;
    begin
        // [GIVEN] Two independent billable contracts with no analysis entries.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.CreateBillableCustomerContract(Contract, Subscription, 0D);
        TestLibrary.CreateBillableCustomerContract(OtherContract, OtherSubscription, 0D);
        BeforeCount := Entry.Count();
        Request.Add('contractNo', Contract."No.");

        // [WHEN] Analysis is requested for the first contract.
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", Request);

        // [THEN] The physical table and counts agree, and the second contract was not analysed.
        Assert.AreEqual(BeforeCount + 1, Entry.Count(), 'Only one physical analysis entry may be added company-wide.');
        Assert.AreEqual(1, TestLibrary.ReadInteger(Response, 'entriesCreated'), TestLibrary.AsText(Response));
        Entry.SetRange("Subscription Contract No.", OtherContract."No.");
        Assert.RecordIsEmpty(Entry);
        Entry.SetRange("Subscription Contract No.", Contract."No.");
        Assert.AreEqual(Entry.Count(), TestLibrary.ReadInteger(Response, 'totalEntries'), 'Counts must describe stored rows.');
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", Request);
        Assert.AreEqual(0, TestLibrary.ReadInteger(Response, 'entriesCreated'), 'Repeat analysis must be idempotent.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC01_UnknownContract_RefusedBeforeWrite_EN()
    begin
        AssertUnknownContract(1033);
    end;

    [Test]
    procedure Scenario_AC01_UnknownContract_RefusedBeforeWrite_IS()
    begin
        AssertUnknownContract(1039);
    end;

    local procedure AssertUnknownContract(LanguageId: Integer)
    var
        Entry: Record "Sub. Contr. Analysis Entry";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        BeforeCount: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.InitSubscriptionBilling();
        BeforeCount := Entry.Count();
        Request.Add('contractNo', 'XS63-NONEXISTENT');
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate", Request);
        Assert.AreEqual('RecordNotFound', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.AreEqual('contractNo', TestLibrary.ReadText(Response, 'parameter'), TestLibrary.AsText(Response));
        Assert.AreEqual(BeforeCount, Entry.Count(), 'A refusal may not analyse any contract.');
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC03_ForeignContract_RefusedBeforeBilling_EN()
    begin
        AssertForeignContract(1033);
    end;

    [Test]
    procedure Scenario_AC03_ForeignContract_RefusedBeforeBilling_IS()
    begin
        AssertForeignContract(1039);
    end;

    local procedure AssertForeignContract(LanguageId: Integer)
    var
        Contract: Record "Vendor Subscription Contract";
        OtherContract: Record "Vendor Subscription Contract";
        Subscription: Record "Subscription Header";
        OtherSubscription: Record "Subscription Header";
        Invoice: Record "Purchase Header";
        Line: Record "Purchase Line";
        BillingLine: Record "Billing Line";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        BeforeCount: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.CreateBillableVendorContract(Contract, Subscription);
        TestLibrary.CreateBillableVendorContract(OtherContract, OtherSubscription);
        Assert.AreNotEqual(Contract."Buy-from Vendor No.", OtherContract."Buy-from Vendor No.", 'The fixture must have two vendors.');
        Invoice.Init();
        Invoice."Document Type" := Invoice."Document Type"::Invoice;
        Invoice.Insert(true);
        Invoice.Validate("Buy-from Vendor No.", Contract."Buy-from Vendor No.");
        Invoice.Modify(true);
        BeforeCount := BillingLine.Count();
        Request.Add('contractNo', OtherContract."No.");
        Commit();
        Response := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", Invoice."No.", Request, false);
        Assert.AreEqual('ConflictingIdentifiers', TestLib.GetText(Response, 'code'), 'Another vendor must be refused explicitly.');
        Assert.AreEqual(BeforeCount, BillingLine.Count(), 'A refused contract must not create billing lines.');
        Line.SetRange("Document Type", Invoice."Document Type");
        Line.SetRange("Document No.", Invoice."No.");
        Assert.RecordIsEmpty(Line);
        GlobalLanguage(PreviousLanguage);
    end;
    [Test]
    procedure Scenario_AC02_ImportFailure_ReturnsRetainedEntry_EN()
    begin
        AssertRetainedImport(1033);
    end;

    [Test]
    procedure Scenario_AC02_ImportFailure_ReturnsRetainedEntry_IS()
    begin
        AssertRetainedImport(1039);
    end;

    local procedure AssertRetainedImport(LanguageId: Integer)
    var
        Supplier: Record "Usage Data Supplier";
        Import: Record "Usage Data Import";
        DataBlob: Record "Usage Data Blob";
        LibraryUtility: Codeunit "Library - Utility";
        Request: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A test-owned supplier deliberately missing its generic import setup.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TestLibrary.InitSubscriptionBilling();
        Supplier.Init();
        Supplier."No." := CopyStr(LibraryUtility.GenerateRandomCode20(Supplier.FieldNo("No."), Database::"Usage Data Supplier"), 1, MaxStrLen(Supplier."No."));
        Supplier.Type := Enum::"Usage Data Supplier Type"::Generic;
        Supplier.Insert(false);
        Request.Add('supplierNo', Supplier."No.");
        Request.Add('content', 'Quantity' + '\n' + '1');

        // [WHEN] Parsing fails after the file has been stored.
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.ImportData", Request);

        // [THEN] The error identifies the retained data and explains how to remove or retry it.
        Assert.AreEqual('Error', TestLibrary.ReadText(Response, 'status'), TestLibrary.AsText(Response));
        EntryNo := TestLibrary.ReadInteger(Response, 'usageDataImportEntryNo');
        Assert.AreEqual('BusinessCentralError', TestLibrary.ReadText(Response, 'code'), TestLibrary.AsText(Response));
        Assert.IsTrue(TestLibrary.ReadText(Response, 'nextStep').Contains('Subscription.Usage.DeleteData'), 'A caller must be able to find the cleanup action.');
        Assert.IsTrue(Import.Get(EntryNo), 'The returned entry must name the stored import.');
        Assert.AreEqual(Supplier."No.", Import."Supplier No.", 'The returned import must belong to this supplier.');
        DataBlob.SetRange("Usage Data Import Entry No.", EntryNo);
        Assert.RecordIsNotEmpty(DataBlob);
        Import.Delete(true);
        Assert.RecordIsEmpty(DataBlob);
        Supplier.Delete(false);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC05_Usage_ReportsChildError_EN()
    begin
        AssertChildStatus(1033);
    end;

    [Test]
    procedure Scenario_AC05_Usage_ReportsChildError_IS()
    begin
        AssertChildStatus(1039);
    end;

    local procedure AssertChildStatus(LanguageId: Integer)
    var
        Import: Record "Usage Data Import";
        ImportedLine: Record "Usage Data Generic Import";
        Request: JsonObject;
        Response: JsonObject;
        Steps: JsonArray;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A real import header at None and its own line in Error.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Import.Init();
        Import.Insert(false);
        ImportedLine.Init();
        ImportedLine."Usage Data Import Entry No." := Import."Entry No.";
        ImportedLine."Processing Status" := ImportedLine."Processing Status"::Error;
        ImportedLine.Insert(false);
        Request.Add('usageDataImportEntryNo', Import."Entry No.");
        Request.Add('steps', Steps);

        // [WHEN] The current processing result is reported without rerunning any steps.
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.Process", Request);

        // [THEN] An erroneous child may not be hidden behind the header's None.
        Assert.AreEqual('Error', TestLibrary.ReadText(Response, 'processingStatus'), TestLibrary.AsText(Response));
        ImportedLine.Delete(false);
        Import.Delete(false);
        GlobalLanguage(PreviousLanguage);
    end;

}
