namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// #41: Subscription.Usage.DeleteData undoes a usage import (AC03), and Subscription.Renewal.CreateQuote
/// checks its new contractLineNos selection (AC06).
/// </summary>
codeunit 95716 "Sub Usg DelData Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA41U', Locked = true;
        SupplierNoTok: Label 'XSBA41USUP', Locked = true;
        HeaderNoTok: Label 'XSBA41USUB', Locked = true;
        ContractNoTok: Label 'XSBA41UCC', Locked = true;

    /// <summary>AC03: resetLines deletes the imported lines and usage billing, keeps the import and resets its status.</summary>
    [Test]
    procedure DeleteData_ResetLines_DeletesProcessedDataAndKeepsImport()
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBilling: Record "Usage Data Billing";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A processed import with imported lines and usage billing
        Initialize();
        EntryNo := CreateProcessedImport('');

        // [WHEN] Its data is reset
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", Format(EntryNo, 0, 9), RequestJson, false);

        // [THEN] The import stays, without lines, usage billing or status
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(2, TestLib.GetInteger(ResponseJson, 'usageDataBillingDeleted'), 'Both usage billing rows must be deleted.');
        Assert.IsFalse(TestLib.GetBoolean(ResponseJson, 'importDeleted'), 'resetLines keeps the import.');
        UsageDataImport.Get(EntryNo);
        Assert.AreEqual(UsageDataImport."Processing Status"::None, UsageDataImport."Processing Status", 'The status must be reset.');
        UsageDataBilling.SetRange("Usage Data Import Entry No.", EntryNo);
        Assert.RecordIsEmpty(UsageDataBilling);
        UsageDataGenericImport.SetRange("Usage Data Import Entry No.", EntryNo);
        Assert.RecordIsEmpty(UsageDataGenericImport);
    end;

    /// <summary>AC03: deleteImport deletes the import itself.</summary>
    [Test]
    procedure DeleteData_DeleteImport_DeletesImport()
    var
        UsageDataImport: Record "Usage Data Import";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A processed import
        Initialize();
        EntryNo := CreateProcessedImport('');

        // [WHEN] The import is deleted
        RequestJson.Add('usageDataImportEntryNo', EntryNo);
        RequestJson.Add('mode', 'DeleteImport');
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", '', RequestJson, false);

        // [THEN] It is gone
        TestLib.AssertSuccess(ResponseJson);
        Assert.IsTrue(TestLib.GetBoolean(ResponseJson, 'importDeleted'), 'The import must be reported as deleted.');
        Assert.IsFalse(UsageDataImport.Get(EntryNo), 'The import must be deleted.');
    end;

    /// <summary>AC03, AC07: an import with invoiced usage billing, and an unknown entry, are refused.</summary>
    [Test]
    procedure DeleteData_InvoicedOrUnknown_IsRefused()
    var
        UsageDataBilling: Record "Usage Data Billing";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] An import whose usage billing is on a document
        Initialize();
        EntryNo := CreateProcessedImport('XSBA41UDOC');

        // [WHEN] Its data is reset
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", Format(EntryNo, 0, 9), RequestJson, false);

        // [THEN] The call is refused, names the document, and nothing is deleted
        TestLib.AssertRefused(ResponseJson, 'XSBA41UDOC');
        UsageDataBilling.SetRange("Usage Data Import Entry No.", EntryNo);
        Assert.AreEqual(2, UsageDataBilling.Count(), 'A refused call must not delete usage billing.');

        // [WHEN] An entry number that does not exist is sent
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", '999999999', RequestJson, false);

        // [THEN] The entry is named
        TestLib.AssertRefused(ResponseJson, '999999999');
    end;

    /// <summary>AC06, AC07: a contractLineNos number that is not a line of the contract is refused before anything is built.</summary>
    [Test]
    procedure RenewalCreateQuote_UnknownContractLine_IsRefused()
    var
        SubContractRenewalLine: Record "Sub. Contract Renewal Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineNos: JsonArray;
    begin
        // [GIVEN] A contract with one line
        Initialize();
        CreateRenewableContract();

        // [WHEN] A quote is asked for a line the contract does not have
        LineNos.Add(99990000);
        RequestJson.Add('contractLineNos', LineNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Renewal.CreateQuote", ContractNoTok, RequestJson, false);

        // [THEN] The call is refused, names the line, and no renewal line exists
        TestLib.AssertRefused(ResponseJson, '99990000');
        SubContractRenewalLine.SetRange("Linked to Sub. Contract No.", ContractNoTok);
        Assert.RecordIsEmpty(SubContractRenewalLine);
    end;

    /// <summary>AC06, edge: when the only listed line has no end date, nothing can be renewed and the call is refused.</summary>
    [Test]
    procedure RenewalCreateQuote_ListedLineWithoutEndDate_IsRefused()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineNos: JsonArray;
    begin
        // [GIVEN] A contract whose second line has no end date
        Initialize();
        LineNos.Add(CreateRenewableContract());

        // [WHEN] Only that line is listed
        RequestJson.Add('contractLineNos', LineNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Renewal.CreateQuote", ContractNoTok, RequestJson, false);

        // [THEN] Nothing can be renewed
        TestLib.AssertRefused(ResponseJson, 'can be renewed');
    end;

    local procedure Initialize()
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBilling: Record "Usage Data Billing";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        UsageDataSupplier: Record "Usage Data Supplier";
    begin
        UsageDataImport.SetRange("Supplier No.", SupplierNoTok);
        if UsageDataImport.FindSet() then
            repeat
                UsageDataBilling.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");
                UsageDataBilling.DeleteAll(false);
                UsageDataGenericImport.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");
                UsageDataGenericImport.DeleteAll(false);
            until UsageDataImport.Next() = 0;
        UsageDataImport.DeleteAll(false);
        if UsageDataSupplier.Get(SupplierNoTok) then
            UsageDataSupplier.Delete(false);
        TestLib.DeleteFixture(PrefixTok);
        UsageDataSupplier.Init();
        UsageDataSupplier."No." := SupplierNoTok;
        UsageDataSupplier.Description := 'X Branch A usage supplier';
        UsageDataSupplier.Type := UsageDataSupplier.Type::Generic;
        UsageDataSupplier.Insert(false);
        Commit();
    end;

    /// <summary>Seeds a processed import with two imported lines and two usage billing rows, optionally on a document.</summary>
    local procedure CreateProcessedImport(DocumentNo: Code[20]) EntryNo: Integer
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBilling: Record "Usage Data Billing";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        i: Integer;
    begin
        UsageDataImport.Init();
        UsageDataImport."Supplier No." := SupplierNoTok;
        UsageDataImport.Description := 'X Branch A import';
        UsageDataImport."Processing Status" := UsageDataImport."Processing Status"::Ok;
        UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Process Imported Lines";
        UsageDataImport.Insert(false);
        EntryNo := UsageDataImport."Entry No.";
        for i := 1 to 2 do begin
            UsageDataGenericImport.Init();
            UsageDataGenericImport."Entry No." := 0;
            UsageDataGenericImport."Usage Data Import Entry No." := EntryNo;
            UsageDataGenericImport.Insert(false);
            UsageDataBilling.Init();
            UsageDataBilling."Entry No." := 0;
            UsageDataBilling."Usage Data Import Entry No." := EntryNo;
            if DocumentNo <> '' then begin
                UsageDataBilling."Document Type" := UsageDataBilling."Document Type"::Invoice;
                UsageDataBilling."Document No." := DocumentNo;
            end;
            UsageDataBilling.Insert(false);
        end;
        Commit();
    end;

    /// <summary>Seeds a customer contract with a line that ends and a line without end date; returns the Line No. of the second.</summary>
    local procedure CreateRenewableContract() OpenLineNo: Integer
    var
        EndingLineEntryNo: Integer;
        OpenLineEntryNo: Integer;
    begin
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateCustomerContract(ContractNoTok, '');
        EndingLineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, CalcDate('<-1Y>', WorkDate()), CalcDate('<+1M>', WorkDate()), WorkDate());
        TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, EndingLineEntryNo);
        OpenLineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, CalcDate('<-1Y>', WorkDate()), 0D, WorkDate());
        OpenLineNo := TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, OpenLineEntryNo);
        Commit();
    end;
}
