namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Usage.Process</c> Cloud Event message type.
/// Runs one or more of the usage data processing stages (Process Imported Lines,
/// Create Usage Data Billing, Process Usage Data Billing) over an existing Usage Data Import
/// entry. Microsoft's own dispatcher, the table procedure UsageDataImport.ProcessUsageDataImport,
/// is internal, so this replicates its stage-by-stage dispatch using the accessible codeunits
/// directly - a plain Data.Records.Set cannot run these processing codeunits.
/// </summary>
codeunit 10035054 "CE Sub Usg Process Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        NotFoundErr: Label 'The Usage Data Import entry %1 does not exist.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er ekki til.';
        AlreadyClosedErr: Label 'Usage Data Import entry %1 is already Closed and cannot be processed again.', Comment = '%1 = entry no.||is-IS=Innflutningsfærslan %1 fyrir notkunargögn er þegar lokuð og er ekki hægt að vinna aftur.';
        UnknownStepErr: Label '''%1'' is not a known processing step. Use ProcessImportedLines, CreateUsageDataBilling or ProcessUsageDataBilling.', Comment = '%1 = step name||is-IS=''%1'' er ekki þekkt vinnsluskref. Notaðu ProcessImportedLines, CreateUsageDataBilling eða ProcessUsageDataBilling.';
        CreateImportedLinesTok: Label 'CreateImportedLines', Locked = true;
        ProcessImportedLinesTok: Label 'ProcessImportedLines', Locked = true;
        CreateUsageDataBillingTok: Label 'CreateUsageDataBilling', Locked = true;
        ProcessUsageDataBillingTok: Label 'ProcessUsageDataBilling', Locked = true;
        DescriptionLbl: Label 'Runs the usage data processing stages (Process Imported Lines, Create Usage Data Billing, Process Usage Data Billing) over an existing Usage Data Import entry and reports the outcome of each stage.', MaxLength = 250, Comment = 'is-IS=Keyrir vinnsluskref notkunargagna (Process Imported Lines, Create Usage Data Billing, Process Usage Data Billing) á fyrirliggjandi innflutningsfærslu fyrir notkunargögn og skilar niðurstöðu hvers skrefs.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Usage Data Import");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Usage.Process');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Advances an existing Usage Data Import entry (table 8013) through its remaining processing');
        HelpBuilder.AppendLine('stages: turning imported lines into billable quantities, creating Usage Data Billing rows');
        HelpBuilder.AppendLine('(table 8006), and processing those rows into Billing Line entries. Each requested stage runs');
        HelpBuilder.AppendLine('Microsoft''s own processing codeunit for that step, in its own committed transaction, so a');
        HelpBuilder.AppendLine('failure in a later stage does not undo an earlier one.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| usageDataImportEntryNo | Integer | Yes | The Usage Data Import entry to process. May also be supplied as the message subject when the subject is numeric. |');
        HelpBuilder.AppendLine('| steps | Array of Text | No | Which stages to run, in any subset of CreateImportedLines, ProcessImportedLines, CreateUsageDataBilling, ProcessUsageDataBilling. Defaults to the last three, always executed in that order regardless of the order given. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`CreateImportedLines` re-parses the Usage Data Blob that `Subscription.Usage.ImportData`');
        HelpBuilder.AppendLine('already stored into Usage Data Generic Import rows. It is not in the default set, because');
        HelpBuilder.AppendLine('the import call runs it once already - ask for it when the first parse failed on a setup');
        HelpBuilder.AppendLine('problem, such as a Data Exchange Definition that did not match the file, and you want to');
        HelpBuilder.AppendLine('retry without re-sending the file.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "usageDataImportEntryNo": 137,');
        HelpBuilder.AppendLine('  "steps": ["ProcessImportedLines", "CreateUsageDataBilling"]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "usageDataImportEntryNo": 137,');
        HelpBuilder.AppendLine('  "steps": [');
        HelpBuilder.AppendLine('    { "step": "ProcessImportedLines", "status": "Ok", "reason": "" },');
        HelpBuilder.AppendLine('    { "step": "CreateUsageDataBilling", "status": "Ok", "reason": "" }');
        HelpBuilder.AppendLine('  ],');
        HelpBuilder.AppendLine('  "processingStatus": "Ok",');
        HelpBuilder.AppendLine('  "usageDataBillingCount": 10,');
        HelpBuilder.AppendLine('  "usageDataBillingErrorCount": 0');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`processingStatus` is the entry''s status after the last requested stage. `usageDataBillingCount`');
        HelpBuilder.AppendLine('and `usageDataBillingErrorCount` count Usage Data Billing rows (table 8006) for this entry,');
        HelpBuilder.AppendLine('the second filtered to rows whose own Processing Status is Error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The entry does not exist | The Usage Data Import entry %1 does not exist. |');
        HelpBuilder.AppendLine('| The entry is already Closed | Usage Data Import entry %1 is already Closed and cannot be processed again. |');
        HelpBuilder.AppendLine('| An unknown step name is given | ''%1'' is not a known processing step. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine('A stage that fails on its own data (for example a row with a missing price) is still reported');
        HelpBuilder.AppendLine('as a successful call - check each entry in `steps` and `processingStatus`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. It advances an existing Usage Data Import entry through its');
        HelpBuilder.AppendLine('processing stages, creating Usage Data Billing rows; it does not post anything by itself.');
        HelpBuilder.AppendLine('Each requested stage commits once it completes, so a partially requested run cannot be');
        HelpBuilder.AppendLine('rolled back as a whole - rerun the remaining steps instead.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Usage.ImportData`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    var
        WriteProcess: Codeunit "CE Sub Write Process ori";
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
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
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

        EntryNo := 0;
        if Argument.Subject <> '' then
            Evaluate(EntryNo, Argument.Subject, 9);
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
