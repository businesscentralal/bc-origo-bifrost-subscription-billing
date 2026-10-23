namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.Threading;

/// <summary>
/// Implements the <c>Subscription.Contract.UpdateLineDates</c> Bifrost message type (#36).
/// Rolling Subscription Line term dates forward and closing the lines that have ended is done by
/// <c>Subscription Header.UpdateServicesDates()</c>, which is internal in Microsoft's app. Microsoft
/// runs it over every Subscription through codeunit 8058 "Update Sub. Lines Term. Dates", whose
/// TableNo is "Job Queue Entry". That codeunit is internal too, but a Job Queue Entry may name it, so
/// this type creates a Job Queue Entry for codeunit 8058 and either runs it at once through the
/// Job Queue Dispatcher, the way the "Run once (foreground)" action of the Job Queue Entries page
/// does, or hands it to the job queue. Scheduling work through the job queue is reserved for holders
/// of BIFROST Force ori, as it is for a forced Job Queue Entry write through Data.Records.Set.
/// </summary>
codeunit 10035040 "Sub Con UpdDates Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        ForcePermissionErr: Label 'Subscription.Contract.UpdateLineDates schedules a Job Queue Entry, which needs the BIFROST Force ori permission set. Your user does not have it.', Comment = 'is-IS=Subscription.Contract.UpdateLineDates stofnar verkraðarfærslu, sem krefst heimildasamstæðunnar BIFROST Force ori. Notandinn þinn hefur hana ekki.';
        ForceExpectedTxt: Label 'the BIFROST Force ori permission set', Comment = 'is-IS=heimildasamstæðan BIFROST Force ori';
        ForceNextStepTxt: Label 'Ask an administrator to assign the BIFROST Force ori permission set to your user, then call again.', Comment = 'is-IS=Biddu kerfisstjóra að úthluta notandanum þínum heimildasamstæðunni BIFROST Force ori og kallaðu svo aftur.';
        InvalidRunModeErr: Label 'The parameter ''runMode'' must be either ''foreground'' or ''background'', not ''%1''.', Comment = '%1 = the supplied run mode||is-IS=Færibreytan ''runMode'' verður að vera annaðhvort ''foreground'' eða ''background'', ekki ''%1''.';
        JobDescriptionTxt: Label 'Bifrost: update Subscription Line term dates', Comment = 'is-IS=Bifröst: uppfæra samningstímadagsetningar áskriftarlína';
        DescriptionLbl: Label 'Closes ended Subscription Lines and their contract lines and rolls term dates forward for every Subscription, through a Job Queue Entry. Needs BIFROST Force ori.', MaxLength = 250, Comment = 'is-IS=Lokar áskriftarlínum sem er lokið og samningslínum þeirra og færir samningstímadagsetningar fram fyrir allar áskriftir með verkraðarfærslu. Krefst BIFROST Force ori.';
        ForegroundTok: Label 'foreground', Locked = true;
        BackgroundTok: Label 'background', Locked = true;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'update subscription line dates, close ended subscription lines, roll term dates forward, run term dates job, close fully invoiced lines, update line term dates, end of term processing, schedule term dates job queue', Comment = 'is-IS=uppfæra dagsetningar áskriftarlína, loka áskriftarlínum sem er lokið, færa tímadagsetningar fram, keyra tímadagsetningaverk, loka fullreikningsfærðum línum, uppfæra tímadagsetningar lína, vinnsla við lok tímabils, tímasetja tímadagsetningaverk í verkröð';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Update Subscription Line term dates: through a Job Queue Entry, closes the ended and fully invoiced Subscription Lines of every Subscription and rolls the term dates of the other lines forward. Irreversible, covers every Subscription in the company and needs the BIFROST Force ori permission set. To renew lines before they end use Subscription.Renewal.CreateQuote.', Comment = 'is-IS=Uppfæra tímadagsetningar áskriftarlína: lokar, með verkraðarfærslu, áskriftarlínum sem er lokið og eru fullreikningsfærðar í öllum áskriftum og færir tímadagsetningar hinna línanna fram. Óafturkræf aðgerð, nær til allra áskrifta í fyrirtækinu og krefst heimildasamstæðunnar BIFROST Force ori. Til að endurnýja línur áður en þeim lýkur skal nota Subscription.Renewal.CreateQuote.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope := ContractParts.GetEnvelope(ContractType());
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target := ContractParts.GetTarget(ContractType());
        exit(Target.Count() > 0);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := ContractParts.UpdateLineDatesParameters();
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response := ContractParts.GetResponse(ContractType());
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors := ContractParts.GetErrors(ContractType());
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect := ContractParts.GetEffect(ContractType());
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related := ContractParts.GetRelated(ContractType());
        exit(Related.Count() > 0);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow := ContractParts.GetWorkflow(ContractType());
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Run the line date update now',
            '{"type":"Subscription.Contract.UpdateLineDates","data":{}}',
            '{"status":"Success","runMode":"foreground","alreadyQueued":false,"jobQueueEntryId":"<guid>","jobQueueStatus":"Finished","result":"Success","error":"","subscriptionLinesClosed":3,"customerContractLinesClosed":2,"vendorContractLinesClosed":1}'));
        Examples.Add(ContractMgt.Example('Hand the update to the job queue',
            '{"type":"Subscription.Contract.UpdateLineDates","data":{"runMode":"background"}}',
            '{"status":"Success","runMode":"background","alreadyQueued":false,"jobQueueEntryId":"<guid>","jobQueueStatus":"Ready"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs Microsoft''s update of Subscription Line term dates through a Job Queue Entry. For every Subscription in the company it closes each ' +
            'Subscription Line whose end date has passed and that is fully invoiced, closes its customer or vendor contract line, and rolls the Term Until and ' +
            'Cancellation Possible Until dates of the other lines forward. runMode foreground (the default) runs the entry at once and reports what it closed; ' +
            'background hands it to the job queue and returns the entry.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The run is not limited to one contract: Microsoft''s update covers every Subscription and commits after each, also under Omit Commit, so a ' +
            'failure part way leaves the Subscriptions already updated in place. Customer and vendor contract lines are both covered. A line counts as ended when ' +
            'its end date is before today (the system date, not the work date) and its Next Billing Date is the day after the end date with no billing line ' +
            'pending. When a Job Queue Entry for this update is already Ready, Waiting or In Process, nothing new is created: the answer has alreadyQueued true and ' +
            'names that entry. In foreground mode the Job Queue Entry is deleted after the run, as the Run once (foreground) action does; its Job Queue Log Entry stays. ' +
            'The counts compare closed lines before and after the run, so a line another session closed meanwhile is counted too.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.UpdateLineDates');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformWrite(Rec);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not Helper.ValidateRequest(Argument) then
            exit;

        if not HasForcePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, ForcePermissionErr, '', '', ForceExpectedTxt, ForceNextStepTxt);
            exit;
        end;

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Con UpdDates Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Creates the Job Queue Entry for codeunit 8058 and runs or enqueues it. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        JobQueueEntry: Record "Job Queue Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        RunMode: Text;
        ClosedLinesBefore: Integer;
        ClosedCustomerLinesBefore: Integer;
        ClosedVendorLinesBefore: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        RunMode := LowerCase(Helper.GetText(RequestJson, 'runMode', false));
        if RunMode = '' then
            RunMode := ForegroundTok;
        if not (RunMode in [ForegroundTok, BackgroundTok]) then
            Helper.RaiseRefusal("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidRunModeErr, RunMode), 'runMode', Format(RunMode, 0, 9));

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('runMode', RunMode);

        if FindPendingEntry(JobQueueEntry) then begin
            ResponseJson.Add('alreadyQueued', true);
            ResponseJson.Add('jobQueueEntryId', Format(JobQueueEntry.ID, 0, 4));
            ResponseJson.Add('jobQueueStatus', FormatJobQueueStatus(JobQueueEntry.Status));
            Helper.RespondWithSuccess(Argument, ResponseJson);
            exit;
        end;
        ResponseJson.Add('alreadyQueued', false);

        if RunMode = BackgroundTok then begin
            EnqueueEntry(JobQueueEntry);
            ResponseJson.Add('jobQueueEntryId', Format(JobQueueEntry.ID, 0, 4));
            ResponseJson.Add('jobQueueStatus', FormatJobQueueStatus(JobQueueEntry.Status));
            Helper.RespondWithSuccess(Argument, ResponseJson);
            exit;
        end;

        CountClosedLines(ClosedLinesBefore, ClosedCustomerLinesBefore, ClosedVendorLinesBefore);
        RunEntryInForeground(ResponseJson);
        AddClosedLineCounts(ResponseJson, ClosedLinesBefore, ClosedCustomerLinesBefore, ClosedVendorLinesBefore);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// The force check Foundation applies to a forced Job Queue Entry write: write permission on its
    /// "Force Access ori" gate table, which only BIFROST Force ori grants. The table is internal to
    /// Foundation, so it is opened by number.
    /// </summary>
    local procedure HasForcePermission(): Boolean
    var
        ForceAccessRecRef: RecordRef;
        ForceAccessTableNo: Integer;
    begin
        // Table 10077900 "Force Access ori" in Bifrost Foundation (Setup/ForceAccess.Table.al).
        ForceAccessTableNo := 10077900;
        ForceAccessRecRef.Open(ForceAccessTableNo);
        exit(ForceAccessRecRef.WritePermission());
    end;

    local procedure FindPendingEntry(var JobQueueEntry: Record "Job Queue Entry"): Boolean
    begin
        JobQueueEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", UpdateTermDatesCodeunitId());
        JobQueueEntry.SetFilter(Status, '%1|%2|%3', JobQueueEntry.Status::Ready, JobQueueEntry.Status::Waiting, JobQueueEntry.Status::"In Process");
        exit(JobQueueEntry.FindFirst());
    end;

    local procedure InitEntry(var JobQueueEntry: Record "Job Queue Entry")
    begin
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := UpdateTermDatesCodeunitId();
        JobQueueEntry.Description := CopyStr(JobDescriptionTxt, 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := false;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
    end;

    local procedure EnqueueEntry(var JobQueueEntry: Record "Job Queue Entry")
    begin
        InitEntry(JobQueueEntry);
        JobQueueEntry.CheckRequiredPermissions();
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
    end;

    /// <summary>
    /// Runs a fresh Job Queue Entry for codeunit 8058 in this session, the way Job Queue Management.RunJobQueueEntryOnce
    /// does for the Run once (foreground) action, without its confirmation and progress dialog.
    /// </summary>
    local procedure RunEntryInForeground(var ResponseJson: JsonObject)
    var
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueLogEntry: Record "Job Queue Log Entry";
        EntryId: Guid;
        Succeeded: Boolean;
        RunError: Text;
    begin
        InitEntry(JobQueueEntry);
        JobQueueEntry.CheckRequiredPermissions();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(JobQueueEntry."User ID"));
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry.Insert(true);
        EntryId := JobQueueEntry.ID;
        // Codeunit.Run with a return value is not allowed inside an open write transaction.
        Commit();

        Succeeded := Codeunit.Run(Codeunit::"Job Queue Dispatcher", JobQueueEntry);
        if not Succeeded then begin
            RunError := GetLastErrorText();
            if Codeunit.Run(Codeunit::"Job Queue Error Handler", JobQueueEntry) then;
        end;

        ResponseJson.Add('jobQueueEntryId', Format(EntryId, 0, 4));
        JobQueueEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        if JobQueueEntry.Get(EntryId) then begin
            ResponseJson.Add('jobQueueStatus', FormatJobQueueStatus(JobQueueEntry.Status));
            if JobQueueEntry.Delete(true) then;
        end else
            ResponseJson.Add('jobQueueStatus', 'Finished');

        JobQueueLogEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        JobQueueLogEntry.SetLoadFields(ID, Status, "Error Message");
        JobQueueLogEntry.SetRange(ID, EntryId);
        if JobQueueLogEntry.FindLast() then begin
            ResponseJson.Add('result', FormatLogStatus(JobQueueLogEntry.Status));
            if RunError = '' then
                RunError := JobQueueLogEntry."Error Message";
        end else
            if Succeeded then
                ResponseJson.Add('result', 'Success')
            else
                ResponseJson.Add('result', 'Error');
        ResponseJson.Add('error', RunError);
    end;

    local procedure CountClosedLines(var ClosedLines: Integer; var ClosedCustomerLines: Integer; var ClosedVendorLines: Integer)
    var
        SubscriptionLine: Record "Subscription Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
    begin
        SubscriptionLine.ReadIsolation := IsolationLevel::ReadCommitted;
        SubscriptionLine.SetRange(Closed, true);
        ClosedLines := SubscriptionLine.Count();
        CustSubContractLine.ReadIsolation := IsolationLevel::ReadCommitted;
        CustSubContractLine.SetRange(Closed, true);
        ClosedCustomerLines := CustSubContractLine.Count();
        VendSubContractLine.ReadIsolation := IsolationLevel::ReadCommitted;
        VendSubContractLine.SetRange(Closed, true);
        ClosedVendorLines := VendSubContractLine.Count();
    end;

    local procedure AddClosedLineCounts(var ResponseJson: JsonObject; ClosedLinesBefore: Integer; ClosedCustomerLinesBefore: Integer; ClosedVendorLinesBefore: Integer)
    var
        ClosedLinesAfter: Integer;
        ClosedCustomerLinesAfter: Integer;
        ClosedVendorLinesAfter: Integer;
    begin
        CountClosedLines(ClosedLinesAfter, ClosedCustomerLinesAfter, ClosedVendorLinesAfter);
        ResponseJson.Add('subscriptionLinesClosed', ClosedLinesAfter - ClosedLinesBefore);
        ResponseJson.Add('customerContractLinesClosed', ClosedCustomerLinesAfter - ClosedCustomerLinesBefore);
        ResponseJson.Add('vendorContractLinesClosed', ClosedVendorLinesAfter - ClosedVendorLinesBefore);
    end;

    local procedure UpdateTermDatesCodeunitId(): Integer
    begin
        // Codeunit 8058 "Update Sub. Lines Term. Dates" in Microsoft Subscription Billing; internal, so referenced by number.
        exit(8058);
    end;

    /// <summary>Names a Job Queue Entry status with a stable token; Format() would return the caption in the caller's language.</summary>
    local procedure FormatJobQueueStatus(Status: Integer): Text
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        case Status of
            JobQueueEntry.Status::Ready:
                exit('Ready');
            JobQueueEntry.Status::"In Process":
                exit('In Process');
            JobQueueEntry.Status::Error:
                exit('Error');
            JobQueueEntry.Status::"On Hold":
                exit('On Hold');
            JobQueueEntry.Status::Finished:
                exit('Finished');
            JobQueueEntry.Status::"On Hold with Inactivity Timeout":
                exit('On Hold with Inactivity Timeout');
            JobQueueEntry.Status::Waiting:
                exit('Waiting');
        end;
        exit(Format(Status, 0, 9));
    end;

    local procedure FormatLogStatus(Status: Integer): Text
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
    begin
        case Status of
            JobQueueLogEntry.Status::Success:
                exit('Success');
            JobQueueLogEntry.Status::"In Process":
                exit('In Process');
            JobQueueLogEntry.Status::Error:
                exit('Error');
        end;
        exit(Format(Status, 0, 9));
    end;
}
