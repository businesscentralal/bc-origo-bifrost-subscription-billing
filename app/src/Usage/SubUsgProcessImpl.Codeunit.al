namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Usage.Process</c> Bifrost message type.
/// Runs one or more of the usage data processing stages (Process Imported Lines,
/// Create Usage Data Billing, Process Usage Data Billing) over an existing Usage Data Import
/// entry. Microsoft's own dispatcher, the table procedure UsageDataImport.ProcessUsageDataImport,
/// is internal, so this replicates its stage-by-stage dispatch using the accessible codeunits
/// directly - a plain Data.Records.Set cannot run these processing codeunits.
/// </summary>
codeunit 10035054 "Sub Usg Process Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        NotFoundErr: Label 'The Usage Data Import entry %1 does not exist.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er ekki til.';
        AlreadyClosedErr: Label 'Usage Data Import entry %1 is already Closed and cannot be processed again.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er þegar lokuð og er ekki hægt að vinna aftur.';
        InvalidSubjectErr: Label 'The subject ''%1'' is not a Usage Data Import entry number. Send the entry number as the subject, or as ''usageDataImportEntryNo'' in the request.', Comment = '%1 = the supplied subject||is-IS=Efnið ''%1'' er ekki færslunúmer innflutnings notkunargagna. Sendu færslunúmerið sem efni (subject) eða sem ''usageDataImportEntryNo'' í beiðninni.';
        UnknownStepErr: Label '''%1'' is not a known processing step. Use ProcessImportedLines, CreateUsageDataBilling or ProcessUsageDataBilling.', Comment = '%1 = step name||is-IS=''%1'' er ekki þekkt vinnsluskref. Notaðu ProcessImportedLines, CreateUsageDataBilling eða ProcessUsageDataBilling.';
        CreateImportedLinesTok: Label 'CreateImportedLines', Locked = true;
        ProcessImportedLinesTok: Label 'ProcessImportedLines', Locked = true;
        CreateUsageDataBillingTok: Label 'CreateUsageDataBilling', Locked = true;
        ProcessUsageDataBillingTok: Label 'ProcessUsageDataBilling', Locked = true;
        DescriptionLbl: Label 'Runs the usage data processing stages (Process Imported Lines, Create Usage Data Billing, Process Usage Data Billing) over an existing Usage Data Import entry and reports the outcome of each stage.', MaxLength = 250, Comment = 'is-IS=Keyrir vinnsluskref notkunargagna (vinnsla innfluttra lína, stofnun og vinnsla notkunarreikningagerðar) á fyrirliggjandi innflutningsfærslu fyrir notkunargögn og skilar niðurstöðu hvers skrefs.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Usage Data Import");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'process usage data, process imported usage, create usage billing, process usage import, calculate billable usage, run usage processing steps, process imported lines, turn usage into billing lines', Comment = 'is-IS=vinna notkunargögn, vinna innflutta notkun, stofna notkunarreikningagerð, vinna innflutning notkunar, reikna reikningshæfa notkun, keyra vinnsluskref notkunar, vinna innfluttar línur, breyta notkun í reikningslínur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Process a usage import: runs the processing steps on an existing Usage Data Import and reports each step. Irreversible, since it commits before each step. Connect new supplier subscriptions first with Subscription.Usage.ConnectSubscriptions; to import a file use Subscription.Usage.ImportData; to start over use Subscription.Usage.DeleteData.', Comment = 'is-IS=Vinna úr innflutningi notkunar: keyrir vinnsluskrefin á fyrirliggjandi innflutningsfærslu notkunargagna og skilar niðurstöðu hvers skrefs. Óafturkræf aðgerð, því hún vistar á undan hverju skrefi. Fyrst eru nýjar áskriftir birgis tengdar með Subscription.Usage.ConnectSubscriptions; til að flytja inn skrá skal nota Subscription.Usage.ImportData; til að byrja upp á nýtt skal nota Subscription.Usage.DeleteData.';
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
        Parameters := ContractParts.UsageProcessParameters();
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
        Examples.Add(ContractMgt.Example('Process imported lines and create usage billing',
            '{"type":"Subscription.Usage.Process","subject":"137","data":{"steps":["ProcessImportedLines","CreateUsageDataBilling"]}}',
            '{"status":"Success","usageDataImportEntryNo":137,"steps":[{"step":"ProcessImportedLines","status":"Ok","reason":""},{"step":"CreateUsageDataBilling","status":"Ok","reason":""}],"processingStatus":"Ok","usageDataBillingCount":10,"usageDataBillingErrorCount":0}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs processing steps over an existing Usage Data Import: turning imported lines into quantities, creating Usage Data Billing rows, and processing ' +
            'those into billing lines. Each step runs Microsoft''s own processing for it. Use it after ' +
            'Subscription.Usage.ImportData when the file was not processed in the same call, once new supplier subscriptions are connected with Subscription.Usage.ConnectSubscriptions, ' +
            'or to run the remaining steps after one step failed.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Each step commits before it runs, so a later failure does not undo an earlier step; rerun the remaining steps instead. A step that fails on its own ' +
            'data is still a successful call: read status and reason of each entry in steps, and processingStatus. The status and reason an earlier step left are ' +
            'cleared before each step, so every entry reports its own outcome. Steps run in the order given, and a step named twice runs twice. ' +
            'CreateImportedLines parses the stored file again. It is not a default step, because Subscription.Usage.ImportData runs it already; ask for it after a ' +
            'setup problem, such as a Data Exchange Definition that did not match the file, to retry without sending the file again. ' +
            'A new supplier subscription must be connected to a Subscription before ProcessImportedLines can use it: run Subscription.Usage.ConnectSubscriptions first.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Usage.Process');
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

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Usg Process Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Runs the requested processing stages over the Usage Data Import entry. Called directly, or by OnRun when ExecuteBifrostTask runs this codeunit in its own transaction.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBilling: Record "Usage Data Billing";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StepsArray: JsonArray;
        StepNames: List of [Text];
        StepName: Text;
        EntryNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();

        // The subject is free text the caller chose. Say what is wrong with it rather than letting
        // Evaluate raise its own conversion error, which names neither the parameter nor the way out.
        EntryNo := 0;
        if Argument.Subject <> '' then
            if not Evaluate(EntryNo, Argument.Subject, 9) then
                Error(InvalidSubjectErr, Argument.Subject);
        if EntryNo = 0 then
            EntryNo := Helper.GetInteger(RequestJson, 'usageDataImportEntryNo', true);

        if not UsageDataImport.Get(EntryNo) then
            Error(NotFoundErr, EntryNo);
        // Microsoft's Create Usage Data Billing copies this record's filters and iterates them.
        // Get alone leaves the record unfiltered, so another open import could be processed and
        // returned to the next stage. Keep every stage scoped to the requested entry.
        UsageDataImport.SetRecFilter();
        if UsageDataImport."Processing Status" = UsageDataImport."Processing Status"::Closed then
            Error(AlreadyClosedErr, EntryNo);

        GetRequestedSteps(RequestJson, StepNames);

        foreach StepName in StepNames do
            RunStep(UsageDataImport, StepName, StepsArray);

        UsageDataImport.Get(EntryNo);

        UsageDataBilling.SetRange("Usage Data Import Entry No.", EntryNo);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('usageDataImportEntryNo', EntryNo);
        ResponseJson.Add('steps', StepsArray);
        ResponseJson.Add('processingStatus', Helper.FormatProcessingStatus(UsageDataImport."Processing Status"));
        ResponseJson.Add('usageDataBillingCount', UsageDataBilling.Count());
        UsageDataBilling.SetRange("Processing Status", UsageDataBilling."Processing Status"::Error);
        ResponseJson.Add('usageDataBillingErrorCount', UsageDataBilling.Count());
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure GetRequestedSteps(RequestJson: JsonObject; var StepNames: List of [Text])
    var
        StepToken: JsonToken;
        StepsArrayIn: JsonArray;
    begin
        Clear(StepNames);
        if Helper.TryGetArray(RequestJson, 'steps', StepsArrayIn) then begin
            foreach StepToken in StepsArrayIn do
                StepNames.Add(StepToken.AsValue().AsText());
            exit;
        end;
        StepNames.Add(ProcessImportedLinesTok);
        StepNames.Add(CreateUsageDataBillingTok);
        StepNames.Add(ProcessUsageDataBillingTok);
    end;

    local procedure RunStep(var UsageDataImport: Record "Usage Data Import"; StepName: Text; var StepsArray: JsonArray)
    var
        StepJson: JsonObject;
        StepOk: Boolean;
        StepReason: Text;
    begin
        // Business Central leaves the status and reason of the previous step standing on the
        // Usage Data Import and only overwrites them when a step has something to say. Clear them
        // first, so a step that succeeds after an earlier one failed is not reported as an error
        // carrying the earlier step's message.
        ResetStatus(UsageDataImport);

        case StepName of
            CreateImportedLinesTok:
                begin
                    UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Create Imported Lines";
                    UsageDataImport.Modify(false);
                    Commit();
                    // Safe to run unattended: the dispatcher only asks the supplier for a file
                    // when no unprocessed Usage Data Blob is standing for this import, and
                    // Subscription.Usage.ImportData always leaves one behind.
                    StepOk := Codeunit.Run(Codeunit::"Import And Process Usage Data", UsageDataImport);
                end;
            ProcessImportedLinesTok:
                begin
                    UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Process Imported Lines";
                    UsageDataImport.Modify(false);
                    Commit();
                    StepOk := Codeunit.Run(Codeunit::"Import And Process Usage Data", UsageDataImport);
                end;
            CreateUsageDataBillingTok:
                begin
                    UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Create Usage Data Billing";
                    UsageDataImport.Modify(false);
                    Commit();
                    StepOk := Codeunit.Run(Codeunit::"Create Usage Data Billing", UsageDataImport);
                end;
            ProcessUsageDataBillingTok:
                begin
                    UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Process Usage Data Billing";
                    UsageDataImport.Modify(false);
                    Commit();
                    StepOk := Codeunit.Run(Codeunit::"Process Usage Data Billing", UsageDataImport);
                end;
            else
                Error(UnknownStepErr, StepName);
        end;

        UsageDataImport.Get(UsageDataImport."Entry No.");

        StepReason := '';
        if UsageDataImport."Processing Status" = UsageDataImport."Processing Status"::Error then
            StepReason := UsageDataImport."Reason (Preview)";
        if (not StepOk) and (StepReason = '') then
            StepReason := GetLastErrorText();

        StepJson.Add('step', StepName);
        StepJson.Add('status', Helper.FormatProcessingStatus(UsageDataImport."Processing Status"));
        StepJson.Add('reason', StepReason);
        StepsArray.Add(StepJson);
    end;

    /// <summary>Clears the status a previous step left on the Usage Data Import, so the next step reports its own outcome.</summary>
    local procedure ResetStatus(var UsageDataImport: Record "Usage Data Import")
    begin
        UsageDataImport."Processing Status" := UsageDataImport."Processing Status"::None;
        UsageDataImport."Reason (Preview)" := '';
        Clear(UsageDataImport.Reason);
        UsageDataImport.Modify(false);
    end;
}
