namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>
/// Implements the <c>Subscription.Usage.ImportData</c> Bifrost message type.
/// Imports a usage data file for metered Subscription Lines by writing the Usage Data Import
/// header and its Usage Data Blob directly (the tables are public) and then running Microsoft's
/// "Import And Process Usage Data" codeunit with the "Create Imported Lines" processing step.
/// A plain Data.Records.Set cannot do this because Microsoft's own entry points
/// (UsageDataImport.NewDataImport and UsageDataBlob.ImportFromFile) are internal, and creating
/// the imported lines requires running that codeunit, not just inserting rows.
/// </summary>
codeunit 10035053 "Sub Usg Import Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        NoContentErr: Label 'The request must supply either ''content'' (raw text) or ''contentBase64'' (base64 encoded) for the usage data file.', Comment = 'is-IS=Beiðnin verður að innihalda annaðhvort ''content'' (hreinan texta) eða ''contentBase64'' (base64 kóðað) fyrir notkunargögnin.';
        DefaultFileNameTok: Label 'bifrost-usage.csv', Locked = true;
        DescriptionLbl: Label 'Imports a usage data file (as raw text or base64) for metered Subscription Lines and creates the imported usage data lines. Optionally also processes those lines into billable quantities.', MaxLength = 250, Comment = 'is-IS=Flytur inn skrá með notkunargögnum (sem hreinan texta eða base64) fyrir mældar áskriftarlínur og býr til innfluttar notkunargagnalínur. Að auki er hægt að vinna þær línur upp í reikningshæft magn.';

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
        Argument.SetResponseMarkdown(UsgHelp.GetHelpMarkdown('Subscription.Usage.ImportData'));
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

    /// <summary>Imports the usage data file and runs the import processing step. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        // Leave "Import Status" at None. Microsoft's connector picks up blobs that have not been
        // turned into imported lines yet and stamps Ok on them itself; a blob that already says Ok
        // is treated as done and silently skipped.
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
        ResponseJson.Add('processingStatus', Helper.FormatProcessingStatus(UsageDataImport."Processing Status"));
        ResponseJson.Add('reason', ReasonText);
        ResponseJson.Add('importedLineCount', UsageDataGenericImport.Count());
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
