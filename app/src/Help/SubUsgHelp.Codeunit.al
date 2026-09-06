namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Usage.ImportData</c> and <c>Subscription.Usage.Process</c> Bifrost message types.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035071 "Sub Usg Help ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the Markdown help document for the given message key. Returns an empty
    /// text when the key is not one of the message types covered by this codeunit.
    /// </summary>
    internal procedure GetHelpMarkdown(MessageKey: Text): Text
    var
        HelpBuilder: TextBuilder;
    begin
        case MessageKey of
            'Subscription.Usage.ImportData':
                begin
                    HelpBuilder.AppendLine('# Subscription.Usage.ImportData');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Creates a Usage Data Import header (table 8013) and a Usage Data Blob (table 8011) holding');
                    HelpBuilder.AppendLine('the supplied file, then runs Microsoft''s "Import And Process Usage Data" codeunit with the');
                    HelpBuilder.AppendLine('"Create Imported Lines" processing step, which parses the file into Usage Data Generic Import');
                    HelpBuilder.AppendLine('rows (table 8018). This only creates the imported lines - it does not turn them into billable');
                    HelpBuilder.AppendLine('quantities. Call `Subscription.Usage.Process` afterwards, or set `runProcessing` to also run the');
                    HelpBuilder.AppendLine('next processing step immediately.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| supplierNo | Code[20] | Yes | The Usage Data Supplier the file was received from. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| fileName | Text | No | The source file name recorded on the Usage Data Blob. Defaults to ''bifrost-usage.csv''. |');
                    HelpBuilder.AppendLine('| content | Text | No* | The raw file content as text, for example a CSV payload. |');
                    HelpBuilder.AppendLine('| contentBase64 | Text | No* | The file content, base64 encoded. Use this for non-text payloads. |');
                    HelpBuilder.AppendLine('| runProcessing | Boolean | No | Defaults to false. When true, also runs the ''Process Imported Lines'' step after the import. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('* Exactly one of `content` or `contentBase64` must be supplied.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "supplierNo": "USUP0010",');
                    HelpBuilder.AppendLine('  "fileName": "august-usage.csv",');
                    HelpBuilder.AppendLine('  "content": "SubscriptionID,ProductID,Quantity\n1001,PROD1,10",');
                    HelpBuilder.AppendLine('  "runProcessing": true');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "usageDataImportEntryNo": 137,');
                    HelpBuilder.AppendLine('  "processingStatus": "Ok",');
                    HelpBuilder.AppendLine('  "reason": "",');
                    HelpBuilder.AppendLine('  "importedLineCount": 10');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`reason` is only populated when `processingStatus` is `Error`. `importedLineCount` counts the');
                    HelpBuilder.AppendLine('Usage Data Generic Import rows now standing for this Usage Data Import entry.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| Neither content nor contentBase64 was supplied | The request must supply either ''content'' or ''contentBase64'' for the usage data file. |');
                    HelpBuilder.AppendLine('| supplierNo is missing | The request is missing the required parameter ''supplierNo''. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine('A file that parses with row level problems is still a success - check `processingStatus` and');
                    HelpBuilder.AppendLine('`reason`, and inspect the Usage Data Import entry in the client for row level detail.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes. It creates a new Usage Data Import entry and its imported lines;');
                    HelpBuilder.AppendLine('it does not post anything and does not touch existing Subscription data. The write runs in');
                    HelpBuilder.AppendLine('an isolated transaction that rolls back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Usage.Process`');
                end;
            'Subscription.Usage.Process':
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
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
