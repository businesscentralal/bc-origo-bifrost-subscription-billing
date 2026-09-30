namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Analysis.Recalculate</c> Bifrost message type.
/// Rebuilds Subscription Contract analysis entries by running Microsoft's "Create Contract
/// Analysis" report. The report has no request page and no parameters of its own - it always
/// analyses as of the system date and walks every Subscription Line with a contract - so a plain
/// Data.Records.Set cannot do this: the analysis snapshot has to be produced by the report.
/// </summary>
codeunit 10035056 "Sub Ana Recalc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        DescriptionLbl: Label 'Rebuilds Subscription Contract analysis entries as of today by running Microsoft''s Create Contract Analysis report across every Subscription Line with a contract.', MaxLength = 250, Comment = 'is-IS=Endurbyggir greiningarfærslur áskriftarsamnings miðað við daginn í dag með því að keyra skýrslu Microsoft, Create Contract Analysis, á allar áskriftarlínur með samningi.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Sub. Contr. Analysis Entry");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Analysis.Recalculate, Subscription, Analysis, Recalculate, contract analysis', Comment = 'is-IS=Subscription.Analysis.Recalculate, áskrift, greining, endurreikna, samningsgreining';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Analysis.Recalculate: Rebuilds contract analysis entries. Read-only.', Comment = 'is-IS=Subscription.Analysis.Recalculate: Endurreiknar greiningarfærslur samninga. Lesaðgerð.';
    begin
        exit(SelectionLbl);
    end;
    procedure GetEnvelope(var Envelope: JsonObject): Boolean begin Envelope := ContractParts.GetEnvelope(ContractType()); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin Target := ContractParts.GetTarget(ContractType()); exit(Target.Count() > 0); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin Parameters := ContractParts.GetParameters(ContractType()); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean begin Response := ContractParts.GetResponse(ContractType()); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean begin Errors := ContractParts.GetErrors(ContractType()); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean begin Effect := ContractParts.GetEffect(ContractType()); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean begin Related := ContractParts.GetRelated(ContractType()); exit(Related.Count() > 0); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin Clear(Overview); exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin Clear(Notes); exit(false); end;
    local procedure ContractType(): Text begin exit('Subscription.Analysis.Recalculate'); end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AnaHelp: Codeunit "Sub Ana Help ori";
    begin
        Argument.SetResponseMarkdown(AnaHelp.GetHelpMarkdown('Subscription.Analysis.Recalculate'));
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

    /// <summary>Runs the contract analysis report and reports how many entries it added. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        SubContrAnalysisEntry.SetLoadFields("Entry No.");
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
