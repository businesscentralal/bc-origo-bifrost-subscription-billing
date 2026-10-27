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
        AmbiguousErr: Label 'Contract number %1 identifies both a customer and a vendor subscription contract. Nothing was changed.', Comment = '%1 = contract number||is-IS=Samningsnúmer %1 auðkennir bæði áskriftarsamning viðskiptamanns og lánardrottins. Engu var breytt.';
        UniqueContractTxt: Label 'A contract number that identifies one customer or vendor subscription contract.', Comment = 'is-IS=Samningsnúmer sem auðkennir einn áskriftarsamning viðskiptamanns eða lánardrottins.';
        UniqueContractNextTxt: Label 'Use a unique contract number, or omit contractNo to analyse every contract.', Comment = 'is-IS=Notaðu ótvírætt samningsnúmer eða slepptu contractNo til að greina alla samninga.';
        NotFoundErr: Label 'Subscription Contract %1 does not exist.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur %1 er ekki til.';
        ExpectedContractTxt: Label 'An existing customer or vendor subscription contract number.', Comment = 'is-IS=Númer fyrirliggjandi áskriftarsamnings viðskiptamanns eða lánardrottins.';
        FindContractTxt: Label 'Choose an existing subscription contract and send its number as contractNo.', Comment = 'is-IS=Veldu fyrirliggjandi áskriftarsamning og sendu númer hans sem contractNo.';
        DescriptionLbl: Label 'Updates this month''s analysis entries for the given subscription contract, or all contracts when no contractNo is supplied. Existing entries are preserved.', MaxLength = 250, Comment = 'is-IS=Uppfærir greiningarfærslur þessa mánaðar fyrir tilgreindan áskriftarsamning eða alla samninga ef contractNo er ekki gefið. Fyrirliggjandi færslur haldast óbreyttar.';

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
        SelectionLbl: Label 'Recalculate contract analysis: adds this month''s entries for the given contract, or all contracts when contractNo is omitted. Existing entries are preserved. No documents are posted. To release deferrals use Subscription.Deferral.Release.', Comment = 'is-IS=Endurreikna samningagreiningu: bætir við færslum þessa mánaðar fyrir tilgreindan samning eða alla samninga ef contractNo vantar. Fyrirliggjandi færslur haldast óbreyttar. Engin skjöl eru bókuð. Til að losa frestanir skal nota Subscription.Deferral.Release.';
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
        Overview := 'Adds analysis entries for the selected subscription contract, or all contracts when contractNo is omitted, as of ' +
            'the system date. Use it to bring the contract analysis up to date for the current month; a line that already has an entry for the month is skipped, so repeating ' +
            'the call in the same month changes nothing.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Analysis uses the system date, not the work date, and only adds entries. contractNo limits both changes and counts to the given contract. A line that ' +
            'already has an entry for the current month is skipped, so a second call in the same month adds nothing and still succeeds. Without contractNo, ' +
            'all contracts are analysed. An unknown contract is refused before any write. Only analysis entries change; no ledger, contract or Subscription Line changes. ' +
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
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        MaxEntryNoBefore: Integer;
        EntriesCreated: Integer;
        TotalEntries: Integer;
        SelectedPartner: Enum "Service Partner";
        HasCustomer: Boolean;
        HasVendor: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);

        if ContractNo <> '' then begin
            HasCustomer := CustomerContract.Get(ContractNo);
            HasVendor := VendorContract.Get(ContractNo);
            if HasCustomer and HasVendor then begin
                Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, StrSubstNo(AmbiguousErr, ContractNo),
                    'contractNo', ContractNo, UniqueContractTxt, UniqueContractNextTxt);
                exit;
            end;
            if not HasCustomer and not HasVendor then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ContractNo),
                    'contractNo', ContractNo, ExpectedContractTxt, FindContractTxt);
                exit;
            end;
            if HasCustomer then
                SelectedPartner := SelectedPartner::Customer
            else
                SelectedPartner := SelectedPartner::Vendor;
        end;

        SubContrAnalysisEntry.Reset();
        SubContrAnalysisEntry.SetLoadFields("Entry No.");
        if SubContrAnalysisEntry.FindLast() then
            MaxEntryNoBefore := SubContrAnalysisEntry."Entry No."
        else
            MaxEntryNoBefore := 0;

        if ContractNo = '' then
            Report.Run(Report::"Create Contract Analysis", false, false)
        else
            CreateContractAnalysis(ContractNo, SelectedPartner);

        SubContrAnalysisEntry.Reset();
        SubContrAnalysisEntry.SetFilter("Entry No.", '>%1', MaxEntryNoBefore);
        if ContractNo <> '' then begin
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
            SubContrAnalysisEntry.SetRange(Partner, SelectedPartner);
        end;
        EntriesCreated := SubContrAnalysisEntry.Count();

        SubContrAnalysisEntry.Reset();
        if ContractNo <> '' then begin
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
            SubContrAnalysisEntry.SetRange(Partner, SelectedPartner);
        end;
        TotalEntries := SubContrAnalysisEntry.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('analysisDate', Helper.FormatDate(Today()));
        ResponseJson.Add('entriesCreated', EntriesCreated);
        ResponseJson.Add('totalEntries', TotalEntries);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
    // Keep the contract in a separate filter group: the standard report sets its own
    // nonblank contract filter in group 0 during OnPreDataItem.
    local procedure CreateContractAnalysis(ContractNo: Code[20]; SelectedPartner: Enum "Service Partner")
    var
        SubscriptionLine: Record "Subscription Line";
        CreateContractAnalysisReport: Report "Create Contract Analysis";
    begin
        SubscriptionLine.FilterGroup(2);
        SubscriptionLine.SetRange("Subscription Contract No.", ContractNo);
        SubscriptionLine.SetRange(Partner, SelectedPartner);
        SubscriptionLine.FilterGroup(0);
        CreateContractAnalysisReport.SetTableView(SubscriptionLine);
        CreateContractAnalysisReport.UseRequestPage(false);
        CreateContractAnalysisReport.RunModal();
    end;
}
