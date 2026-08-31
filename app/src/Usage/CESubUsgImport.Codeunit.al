namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;
using System.Text;
using System.Utilities;

/// <summary>
/// Implements the <c>Subscription.Usage.ImportData</c> Cloud Event message type.
/// Imports a usage data file for metered Subscription Lines by writing the Usage Data Import
/// header and its Usage Data Blob directly (the tables are public) and then running Microsoft's
/// "Import And Process Usage Data" codeunit with the "Create Imported Lines" processing step.
/// A plain Data.Records.Set cannot do this because Microsoft's own entry points
/// (UsageDataImport.NewDataImport and UsageDataBlob.ImportFromFile) are internal, and creating
/// the imported lines requires running that codeunit, not just inserting rows.
/// </summary>
codeunit 10035053 "CE Sub Usg Import Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        NoContentErr: Label 'The request must supply either ''content'' (raw text) or ''contentBase64'' (base64 encoded) for the usage data file.', Comment = 'is-IS=Beiðnin verður að innihalda annaðhvort ''content'' (hreinan texta) eða ''contentBase64'' (base64 kóðað) fyrir notkunargögnin.';
        DefaultFileNameTok: Label 'cloudevents-usage.csv', Locked = true;
        DescriptionLbl: Label 'Imports a usage data file (as raw text or base64) for metered Subscription Lines and creates the imported usage data lines. Optionally also processes those lines into billable quantities.', MaxLength = 250, Comment = 'is-IS=Flytur inn skrá með notkunargögnum (sem hreinan texta eða base64) fyrir mældar áskriftarlínur og býr til innfluttar notkunargagnalínur. Að auki er hægt að vinna þær línur upp í reikningshæft magn.';

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
        HelpBuilder.AppendLine('| fileName | Text | No | The source file name recorded on the Usage Data Blob. Defaults to ''cloudevents-usage.csv''. |');
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

    /// <summary>Imports the usage data file and runs the import processing step. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBlob: Record "Usage Data Blob";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OutStr: OutStream;
        TempOutStr: OutStream;
        TempInStr: InStream;
        SupplierNo: Code[20];
        FileName: Text;
        Content: Text;
        ContentBase64: Text;
        RunProcessing: Boolean;
        ReasonText: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        SupplierNo := Helper.GetSubjectOr(Argument, RequestJson, 'supplierNo', true);
        FileName := Helper.GetText(RequestJson, 'fileName', false);
        if FileName = '' then
            FileName := DefaultFileNameTok;
        Content := Helper.GetText(RequestJson, 'content', false);
        ContentBase64 := Helper.GetText(RequestJson, 'contentBase64', false);
        RunProcessing := Helper.GetBoolean(RequestJson, 'runProcessing', false);

        if (Content = '') and (ContentBase64 = '') then
            Error(NoContentErr);

        UsageDataImport.Init();
        UsageDataImport."Entry No." := 0;
        UsageDataImport.Validate("Supplier No.", SupplierNo);
        UsageDataImport.Insert(true);

        UsageDataBlob.Init();
        UsageDataBlob."Entry No." := 0;
        UsageDataBlob."Usage Data Import Entry No." := UsageDataImport."Entry No.";
        UsageDataBlob.Insert(false);
        UsageDataBlob.Data.CreateOutStream(OutStr);
        if ContentBase64 <> '' then begin
            TempBlob.CreateOutStream(TempOutStr);
            Base64Convert.FromBase64(ContentBase64, TempOutStr);
            TempBlob.CreateInStream(TempInStr);
            CopyStream(OutStr, TempInStr);
        end else
            OutStr.WriteText(Content);
        UsageDataBlob.Source := CopyStr(FileName, 1, MaxStrLen(UsageDataBlob.Source));
        UsageDataBlob."Import Date" := Today();
        UsageDataBlob."Import Status" := UsageDataBlob."Import Status"::Ok;
        UsageDataBlob.Modify(false);

        UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Create Imported Lines";
        UsageDataImport.Modify(false);
        Commit();
        if not Codeunit.Run(Codeunit::"Import And Process Usage Data", UsageDataImport) then
            Error(GetLastErrorText());

        if RunProcessing then begin
            UsageDataImport.Get(UsageDataImport."Entry No.");
            UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::"Process Imported Lines";
            UsageDataImport.Modify(false);
            Commit();
            if not Codeunit.Run(Codeunit::"Import And Process Usage Data", UsageDataImport) then
                Error(GetLastErrorText());
        end;

        UsageDataImport.Get(UsageDataImport."Entry No.");

        ReasonText := '';
        if UsageDataImport."Processing Status" = UsageDataImport."Processing Status"::Error then
            ReasonText := UsageDataImport."Reason (Preview)";

        UsageDataGenericImport.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('usageDataImportEntryNo', UsageDataImport."Entry No.");
        ResponseJson.Add('processingStatus', Format(UsageDataImport."Processing Status", 0, 9));
        ResponseJson.Add('reason', ReasonText);
        ResponseJson.Add('importedLineCount', UsageDataGenericImport.Count());
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
