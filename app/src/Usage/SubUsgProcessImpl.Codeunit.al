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
codeunit 10035054 "Sub Usg Process Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        NotFoundErr: Label 'The Usage Data Import entry %1 does not exist.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er ekki til.';
        AlreadyClosedErr: Label 'Usage Data Import entry %1 is already Closed and cannot be processed again.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er þegar lokuð og er ekki hægt að vinna aftur.';
        InvalidSubjectErr: Label 'The subject ''%1'' is not a Usage Data Import entry number. Send the entry number as the subject, or as ''usageDataImportEntryNo'' in the request.', Comment = '%1 = the supplied subject||is-IS=Efnið ''%1'' er ekki færslunúmer innflutnings notkunargagna. Sendu færslunúmerið sem efni (subject) eða sem ''usageDataImportEntryNo'' í beiðninni.';
        UnknownStepErr: Label '''%1'' is not a known processing step. Use ProcessImportedLines, CreateUsageDataBilling or ProcessUsageDataBilling.', Comment = '%1 = step name||is-IS=''%1'' er ekki þekkt vinnsluskref. Notaðu ProcessImportedLines, CreateUsageDataBilling eða ProcessUsageDataBilling.';
        CreateImportedLinesTok: Label 'CreateImportedLines', Locked = true;
        ProcessImportedLinesTok: Label 'ProcessImportedLines', Locked = true;
        CreateUsageDataBillingTok: Label 'CreateUsageDataBilling', Locked = true;
        ProcessUsageDataBillingTok: Label 'ProcessUsageDataBilling', Locked = true;
        DescriptionLbl: Label 'Runs the usage data processing stages (Process Imported Lines, Create Usage Data Billing, Process Usage Data Billing) over an existing Usage Data Import entry and reports the outcome of each stage.', MaxLength = 250, Comment = 'is-IS=Keyrir vinnsluskref notkunargagna (Process Imported Lines, Create Usage Data Billing, Process Usage Data Billing) á fyrirliggjandi innflutningsfærslu fyrir notkunargögn og skilar niðurstöðu hvers skrefs.';

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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        UsgHelp: Codeunit "Sub Usg Help ori";
    begin
        Argument.SetResponseMarkdown(UsgHelp.GetHelpMarkdown('Subscription.Usage.Process'));
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteProcess: Codeunit "Sub Write Process ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        Clear(WriteProcess);
        if not WriteProcess.Run(Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Runs the requested processing stages over the Usage Data Import entry. Called directly, or through the isolated write process.</summary>
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
