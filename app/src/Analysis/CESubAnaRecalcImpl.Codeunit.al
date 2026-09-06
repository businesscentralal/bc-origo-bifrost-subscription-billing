namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Analysis.Recalculate</c> Cloud Event message type.
/// Rebuilds Subscription Contract analysis entries by running Microsoft's "Create Contract
/// Analysis" report. The report has no request page and no parameters of its own - it always
/// analyses as of the system date and walks every Subscription Line with a contract - so a plain
/// Data.Records.Set cannot do this: the analysis snapshot has to be produced by the report.
/// </summary>
codeunit 10035056 "CE Sub Ana Recalc Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        DescriptionLbl: Label 'Rebuilds Subscription Contract analysis entries as of today by running Microsoft''s Create Contract Analysis report across every Subscription Line with a contract.', MaxLength = 250, Comment = 'is-IS=Endurbyggir greiningarfærslur áskriftarsamnings miðað við daginn í dag með því að keyra skýrslu Microsoft, Create Contract Analysis, á allar áskriftarlínur með samningi.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Sub. Contr. Analysis Entry");
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
        HelpBuilder.AppendLine('# Subscription.Analysis.Recalculate');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Runs Microsoft''s "Create Contract Analysis" report, which adds Sub. Contr. Analysis Entry');
        HelpBuilder.AppendLine('rows (table 8019) for every Subscription Line that belongs to a Subscription Contract.');
        HelpBuilder.AppendLine('Three facts about this report are important and cannot be changed by this message type:');
        HelpBuilder.AppendLine('the report takes no parameters and always analyses as of **today''s system date**, not a');
        HelpBuilder.AppendLine('date you choose; it covers **every** Subscription Line with a contract, never a single one;');
        HelpBuilder.AppendLine('and it is **additive only** - a line that already has an analysis entry for the current month');
        HelpBuilder.AppendLine('is skipped rather than recalculated, so calling this twice in the same month does not create');
        HelpBuilder.AppendLine('duplicate or refreshed entries for lines already analysed this month.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | No | Does **not** scope the run itself - the report always covers every contract. Only narrows the counts reported back to you, to this Subscription Contract. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "CC000010"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "analysisDate": "2026-08-30",');
        HelpBuilder.AppendLine('  "entriesCreated": 4,');
        HelpBuilder.AppendLine('  "totalEntries": 96');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`entriesCreated` counts the analysis entries this call added, and `totalEntries` is the total');
        HelpBuilder.AppendLine('number of analysis entries now on file. When `contractNo` is given both counts are narrowed to');
        HelpBuilder.AppendLine('that contract; otherwise they cover every Subscription Contract. A run where every line was');
        HelpBuilder.AppendLine('already analysed this month is still a success, with `entriesCreated` at 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| (none specific to this message type) | Errors return `{ "status": "Error", "error": "...", "callstack": "..." }`. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes, but only adds analysis entries - a reporting side table. It does');
        HelpBuilder.AppendLine('not post to the general ledger and does not change any Subscription Contract or Subscription');
        HelpBuilder.AppendLine('Line data. The write runs in an isolated transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Deferral.Release`');

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

    /// <summary>Runs the contract analysis report and reports how many entries it added. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        SubContrAnalysisEntry: Record "Sub. Contr. Analysis Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        MaxEntryNoBefore: Integer;
        EntriesCreated: Integer;
        TotalEntries: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);

        SubContrAnalysisEntry.Reset();
        if SubContrAnalysisEntry.FindLast() then
            MaxEntryNoBefore := SubContrAnalysisEntry."Entry No."
        else
            MaxEntryNoBefore := 0;

        Report.Run(Report::"Create Contract Analysis", false, false);

        SubContrAnalysisEntry.Reset();
        SubContrAnalysisEntry.SetFilter("Entry No.", '>%1', MaxEntryNoBefore);
        if ContractNo <> '' then
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
        EntriesCreated := SubContrAnalysisEntry.Count();

        SubContrAnalysisEntry.Reset();
        if ContractNo <> '' then
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
        TotalEntries := SubContrAnalysisEntry.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('analysisDate', Helper.FormatDate(Today()));
        ResponseJson.Add('entriesCreated', EntriesCreated);
        ResponseJson.Add('totalEntries', TotalEntries);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
