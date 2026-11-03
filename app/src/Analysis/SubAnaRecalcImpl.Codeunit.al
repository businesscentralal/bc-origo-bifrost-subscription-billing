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
    TableNo = "Message Argument ori";

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
        KeywordsLbl: Label 'recalculate contract analysis, refresh contract analysis, contract analysis entries, rebuild contract analysis, subscription analysis, update the analysis, contract analysis report, analysis for this month', Comment = 'is-IS=endurreikna samningagreiningu, uppfæra samningagreiningu, greiningarfærslur samninga, endurbyggja samningagreiningu, áskriftargreining, uppfæra greininguna, skýrsla um samningagreiningu, greining fyrir þennan mánuð';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Rebuild contract analysis: adds this month''s analysis entries for every Subscription Line that has a contract, across all contracts, and skips lines that already have one. Writes analysis entries only and posts nothing. To release deferred revenue or cost use Subscription.Deferral.Release.', Comment = 'is-IS=Endurbyggja samningagreiningu: bætir við greiningarfærslum þessa mánaðar fyrir allar áskriftarlínur sem eru á samningi, þvert á alla samninga, og sleppir línum sem hafa þegar færslu. Skrifar eingöngu greiningarfærslur og bókar ekkert. Til að losa frestaðar tekjur eða kostnað skal nota Subscription.Deferral.Release.';
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
        Parameters := ContractParts.AnalysisParameters();
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
        Examples.Add(ContractMgt.Example('Recalculate and count one contract',
            '{"type":"Subscription.Analysis.Recalculate","data":{"contractNo":"CC000010"}}',
            '{"status":"Success","analysisDate":"2026-08-30","entriesCreated":4,"totalEntries":96}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs Microsoft''s Create Contract Analysis report, which adds Sub. Contr. Analysis Entry rows for every Subscription Line that belongs to a contract, as of ' +
            'the system date. Use it to bring the contract analysis up to date for the current month; a line that already has an entry for the month is skipped, so repeating ' +
            'the call in the same month changes nothing.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('The report takes no parameters: it always analyses as of the system date, not the work date, always covers every contract, and only adds. A line that ' +
            'already has an entry for the current month is skipped, so a second call in the same month adds nothing and still succeeds. contractNo only narrows ' +
            'the counts in the answer. The report writes only the analysis entries; no ledger, contract or Subscription Line changes. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Analysis.Recalculate');
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

        if not Codeunit.Run(Codeunit::"Sub Ana Recalc Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Runs the contract analysis report and reports how many entries it added. Called directly, or by OnRun when ExecuteBifrostTask runs this codeunit in its own transaction.</summary>
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
