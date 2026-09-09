namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Analysis.Recalculate</c> Bifrost message type.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035073 "Sub Ana Help ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the Markdown help document for the given message key. Returns an empty
    /// text when the key is not one of the message types covered by this codeunit.
    /// </summary>
    procedure GetHelpMarkdown(MessageKey: Text): Text
    var
        HelpBuilder: TextBuilder;
    begin
        case MessageKey of
            'Subscription.Analysis.Recalculate':
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
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
