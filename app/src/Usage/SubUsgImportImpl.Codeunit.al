namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.Security.Encryption;
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
codeunit 10035053 "Sub Usg Import Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        SupplierNotFoundErr: Label 'The Usage Data Supplier ''%1'' does not exist.', Comment = '%1 = supplier number||is-IS=Birgir notkunargagna ''%1'' er ekki til.';
        InvalidBase64Err: Label 'The parameter contentBase64 is not valid base64.', Comment = 'is-IS=Færibreytan contentBase64 er ekki gilt base64.';
        Base64ExpectedTxt: Label 'A valid base64-encoded file.', Comment = 'is-IS=Gild base64-kóðuð skrá.';
        NoContentErr: Label 'The request must supply either ''content'' (raw text) or ''contentBase64'' (base64 encoded) for the usage data file.', Comment = 'is-IS=Beiðnin verður að innihalda annaðhvort ''content'' (hreinan texta) eða ''contentBase64'' (base64-kóðað) fyrir notkunargögnin.';
        DefaultFileNameTok: Label 'bifrost-usage.csv', Locked = true;
        DescriptionLbl: Label 'Imports a usage data file (as raw text or base64) for metered Subscription Lines and creates the imported usage data lines. Optionally also processes those lines into billable quantities.', MaxLength = 250, Comment = 'is-IS=Flytur inn skrá með notkunargögnum (sem hreinan texta eða base64) fyrir mældar áskriftarlínur og býr til innfluttar notkunargagnalínur. Einnig er hægt að vinna úr þessum línum og breyta þeim í reikningshæft magn.';

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
        KeywordsLbl: Label 'import usage data, upload usage file, import supplier usage, import metered usage, load usage csv, import consumption data, usage data import, import usage for billing', Comment = 'is-IS=flytja inn notkunargögn, hlaða upp notkunarskrá, flytja inn notkun birgis, flytja inn mælda notkun, hlaða inn notkunar csv, flytja inn neyslugögn, innflutningur notkunargagna, flytja inn notkun fyrir reikningagerð';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Import usage data: stores a supplier''s usage file (text or base64), parses it into imported lines and, with runProcessing, also processes them. Irreversible, since each step commits. For an import that is already stored use Subscription.Usage.Process; to undo one use Subscription.Usage.DeleteData.', Comment = 'is-IS=Flytja inn notkunargögn: vistar notkunarskrá birgis (texta eða base64), greinir hana í innfluttar línur og vinnur þær einnig með runProcessing. Óafturkræf aðgerð, því hvert skref vistar. Fyrir innflutning sem þegar er vistaður skal nota Subscription.Usage.Process; til að afturkalla innflutning skal nota Subscription.Usage.DeleteData.';
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
        Parameters := ContractParts.UsageImportParameters();
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
        Examples.Add(ContractMgt.Example('Import a CSV and process it',
            '{"type":"Subscription.Usage.ImportData","subject":"USUP0010","data":{"fileName":"august-usage.csv","content":"SubscriptionID,ProductID,Quantity\n1001,PROD1,10","runProcessing":true}}',
            '{"status":"Success","usageDataImportEntryNo":137,"processingStatus":"Ok","reason":"","importedLineCount":10}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Stores a usage data file from a Usage Data Supplier as a Usage Data Import with a Usage Data Blob, then runs Microsoft''s usage data ' +
            'import with the Create Imported Lines step, which parses the file into Usage Data Generic Import rows. Call Subscription.Usage.Process next, or set ' +
            'runProcessing.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('The call commits the import and the blob before Microsoft''s step runs, and commits again before Process Imported Lines, so an error after that leaves ' +
            'the import entry in place. A file that parses with row-level problems is still a success: check processingStatus and reason, and the import in the ' +
            'client for row detail. The blob is stamped Import Status Ok with the hash of its data, as Microsoft''s own file import does, because the Create Imported Lines step reads only Ok blobs. ' +
            ContractParts.BooleanNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Usage.ImportData');
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

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Usg Import Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Imports the usage data file and runs the import processing step. Called directly, or by OnRun when ExecuteBifrostTask runs this codeunit in its own transaction.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataBlob: Record "Usage Data Blob";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        TempBlob: Codeunit "Temp Blob";
        CryptographyManagement: Codeunit "Cryptography Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OutStr: OutStream;
        TempInStr: InStream;
        HashInStr: InStream;
        HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
        SupplierNo: Code[20];
        FileName: Text;
        Content: Text;
        ContentBase64: Text;
        RunProcessing: Boolean;
        ReasonText: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        SupplierNo := Helper.GetSubjectOr(RequestJson, 'supplierNo', Argument, true);
        FileName := Helper.GetText(RequestJson, 'fileName', false);
        if FileName = '' then
            FileName := DefaultFileNameTok;
        Content := Helper.GetText(RequestJson, 'content', false);
        ContentBase64 := Helper.GetText(RequestJson, 'contentBase64', false);
        RunProcessing := Helper.GetBoolean(RequestJson, 'runProcessing', false);

        if (Content = '') and (ContentBase64 = '') then
            Error(NoContentErr);

        if ContentBase64 <> '' then
            if not Helper.TryDecodeBase64(ContentBase64, TempBlob) then begin
                ClearLastError();
                Helper.RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidBase64Err, 'contentBase64', '[omitted]', Base64ExpectedTxt);
            end;

        if not UsageDataSupplier.Get(SupplierNo) then
            Error(SupplierNotFoundErr, SupplierNo);

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
            TempBlob.CreateInStream(TempInStr);
            CopyStream(OutStr, TempInStr);
        end else
            OutStr.WriteText(Content);
        UsageDataBlob.Source := CopyStr(FileName, 1, MaxStrLen(UsageDataBlob.Source));
        UsageDataBlob."Import Date" := Today();
        // Stamp the blob the way Microsoft's own file import (Usage Data Blob.ImportFromFile, internal)
        // does: Import Status Ok and the MD5 hash of the data. The generic connector's Create Imported
        // Lines step reads only blobs whose Import Status is Ok, so a blob left at None is never parsed
        // and the import ends with "No data found" (#43).
        UsageDataBlob.Modify(false);
        UsageDataBlob.CalcFields(Data);
        UsageDataBlob.Data.CreateInStream(HashInStr);
        UsageDataBlob."Data Hash Value" := CopyStr(CryptographyManagement.GenerateHash(HashInStr, HashAlgorithmType::MD5), 1, MaxStrLen(UsageDataBlob."Data Hash Value"));
        UsageDataBlob."Import Status" := Enum::"Processing Status"::Ok;
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
