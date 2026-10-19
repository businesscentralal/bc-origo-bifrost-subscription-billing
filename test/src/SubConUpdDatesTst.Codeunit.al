namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>
/// #36: Subscription.Contract.UpdateLineDates runs Microsoft's codeunit 8058 through a Job Queue Entry,
/// refuses a caller without BIFROST Force ori, and never queues a second pending entry.
/// </summary>
codeunit 95711 "Sub Con UpdDates Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA36', Locked = true;
        HeaderNoTok: Label 'XSBA36SUB', Locked = true;
        ContractNoTok: Label 'XSBA36CC', Locked = true;
        VendorContractNoTok: Label 'XSBA36VC', Locked = true;

    /// <summary>AC01, AC03, AC05: an ended, fully invoiced line and its customer and vendor contract lines are closed in a foreground run.</summary>
    [Test]
    procedure UpdateLineDates_EndedLine_ClosesLineAndContractLines()
    var
        SubscriptionLine: Record "Subscription Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        JobQueueEntry: Record "Job Queue Entry";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        CustomerLineEntryNo: Integer;
        VendorLineEntryNo: Integer;
        OpenLineEntryNo: Integer;
    begin
        // [GIVEN] A Subscription with an ended, fully invoiced customer line, an ended vendor line and a running line
        Initialize();
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        TestLib.CreateCustomerContract(ContractNoTok, '');
        TestLib.CreateVendorContract(VendorContractNoTok, '');
        CustomerLineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, Today() - 100, Today() - 10, Today() - 9);
        TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, CustomerLineEntryNo);
        VendorLineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Vendor, VendorContractNoTok, Today() - 100, Today() - 10, Today() - 9);
        TestLib.CreateVendorContractLine(VendorContractNoTok, HeaderNoTok, VendorLineEntryNo);
        OpenLineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, Today() - 100, 0D, Today() + 20);
        TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, OpenLineEntryNo);
        Commit();

        // [WHEN] The type runs in the default foreground mode
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateLineDates", '', RequestJson, false);

        // [THEN] The run succeeded and the entry was removed again
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual('foreground', TestLib.GetText(ResponseJson, 'runMode'), 'The default run mode is foreground.');
        Assert.IsFalse(TestLib.GetBoolean(ResponseJson, 'alreadyQueued'), 'No entry was pending.');
        Assert.AreEqual('Success', TestLib.GetText(ResponseJson, 'result'), 'The job queue run must succeed.');
        Assert.IsTrue(TestLib.GetInteger(ResponseJson, 'subscriptionLinesClosed') >= 2, 'At least the two ended lines must be counted as closed.');
        JobQueueEntry.SetRange("Object ID to Run", 8058);
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        Assert.RecordIsEmpty(JobQueueEntry);

        // [THEN] The ended lines and their contract lines are closed; the running line is not
        SubscriptionLine.Get(CustomerLineEntryNo);
        Assert.IsTrue(SubscriptionLine.Closed, 'The ended customer line must be closed.');
        SubscriptionLine.Get(VendorLineEntryNo);
        Assert.IsTrue(SubscriptionLine.Closed, 'The ended vendor line must be closed.');
        SubscriptionLine.Get(OpenLineEntryNo);
        Assert.IsFalse(SubscriptionLine.Closed, 'A line without an end date stays open.');
        CustSubContractLine.SetRange("Subscription Line Entry No.", CustomerLineEntryNo);
        CustSubContractLine.FindFirst();
        Assert.IsTrue(CustSubContractLine.Closed, 'The customer contract line of the ended line must be closed.');
        VendSubContractLine.SetRange("Subscription Line Entry No.", VendorLineEntryNo);
        VendSubContractLine.FindFirst();
        Assert.IsTrue(VendSubContractLine.Closed, 'The vendor contract line of the ended line must be closed.');
        Initialize();
    end;

    /// <summary>AC02, AC06: a caller without BIFROST Force ori is refused with PermissionDenied before anything is created.</summary>
    [Test]
    procedure UpdateLineDates_WithoutForce_IsRefused()
    var
        JobQueueEntry: Record "Job Queue Entry";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntriesBefore: Integer;
    begin
        // [GIVEN] A user with Bifrost full access but without BIFROST Force ori
        Initialize();
        JobQueueEntry.SetRange("Object ID to Run", 8058);
        EntriesBefore := JobQueueEntry.Count();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST Full ori');

        // [WHEN] The type is called
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateLineDates", '', RequestJson, false);
        LowerPermissions.StopLoggingNAVPermissions();

        // [THEN] It is refused with a structured PermissionDenied error that names the permission set, and nothing is queued
        TestLib.AssertRefused(ResponseJson, 'BIFROST Force ori');
        Assert.AreEqual('PermissionDenied', TestLib.GetText(ResponseJson, 'code'), 'The refusal must carry the PermissionDenied code.');
        Assert.AreEqual(EntriesBefore, JobQueueEntry.Count(), 'A refused call must not create a Job Queue Entry.');
    end;

    /// <summary>AC04: while an entry for codeunit 8058 is pending, the type returns it and creates or runs nothing.</summary>
    [Test]
    procedure UpdateLineDates_PendingEntry_ReturnsExistingEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        PendingId: Guid;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A Ready Job Queue Entry for codeunit 8058 and an ended line
        Initialize();
        TestLib.CreateSubscriptionHeader(HeaderNoTok);
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, '', Today() - 100, Today() - 10, Today() - 9);
        PendingId := CreateGuid();
        JobQueueEntry.Init();
        JobQueueEntry.ID := PendingId;
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := 8058;
        JobQueueEntry.Description := 'X pending 8058 fixture';
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry.Insert(false);
        Commit();

        // [WHEN] The type is called in background mode
        RequestJson.Add('runMode', 'BACKGROUND');
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateLineDates", '', RequestJson, false);

        // [THEN] The pending entry is returned; no second entry exists and the line was not touched
        TestLib.AssertSuccess(ResponseJson);
        Assert.IsTrue(TestLib.GetBoolean(ResponseJson, 'alreadyQueued'), 'The pending entry must be reported.');
        Assert.AreEqual(Format(PendingId, 0, 4), TestLib.GetText(ResponseJson, 'jobQueueEntryId'), 'The existing entry must be returned.');
        Assert.AreEqual('Ready', TestLib.GetText(ResponseJson, 'jobQueueStatus'), 'The status of the pending entry must be returned.');
        JobQueueEntry.Reset();
        JobQueueEntry.SetRange("Object ID to Run", 8058);
        Assert.AreEqual(1, JobQueueEntry.Count(), 'No second entry may be created.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.IsFalse(SubscriptionLine.Closed, 'Nothing may run while an entry is pending.');
        Initialize();
    end;

    /// <summary>AC06: an unknown run mode is refused with the localized parameter error.</summary>
    [Test]
    procedure UpdateLineDates_UnknownRunMode_IsRefused()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        // [GIVEN] No pending entry
        Initialize();

        // [WHEN] runMode is neither foreground nor background
        RequestJson.Add('runMode', 'later');
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Contract.UpdateLineDates", '', RequestJson, false);

        // [THEN] The call is refused and names the parameter
        TestLib.AssertRefused(ResponseJson, 'runMode');
    end;

    local procedure Initialize()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", 8058);
        JobQueueEntry.DeleteAll(false);
        TestLib.DeleteFixture(PrefixTok);
        Commit();
    end;
}
