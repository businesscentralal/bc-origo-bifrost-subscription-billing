namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Renewal.CreateQuote</c> Bifrost message type.
/// Builds the Sub. Contract Renewal Line rows for a Customer Subscription Contract and runs
/// Microsoft's fully public <c>Codeunit "Create Sub. Contract Renewal"</c> to turn them into a
/// sales quote. A plain Data.Records.Set cannot do this because the renewal lines have to be
/// derived, one per still-open Subscription Line, from the contract's own service commitments
/// before the quote-creating codeunit can run - and Microsoft's own interactive wrapper around
/// that codeunit (StartContractRenewalFromContract, BatchCreateContractRenewal, OpenSalesQuotes)
/// is internal and expects a user at a request page, so this codeunit bypasses it entirely.
/// </summary>
codeunit 10035052 "Sub Ren CrQuote Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = customer contract no.||is-IS=Áskriftarsamningur viðskiptamanns ''%1'' er ekki til.';
        NoRenewableLinesErr: Label 'The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed.', Comment = '%1 = customer contract no.||is-IS=Áskriftarsamningur viðskiptamanns ''%1'' er ekki með neinar áskriftarlínur sem hægt er að endurnýja.';
        QuoteNotCreatedErr: Label 'Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''.', Comment = '%1 = customer contract no.||is-IS=Create Sub. Contract Renewal bjó ekki til sölutilboð fyrir áskriftarsamning viðskiptamanns ''%1''.';
        DescriptionLbl: Label 'Builds contract renewal lines from a Customer Subscription Contract''s Subscription Lines and creates a renewal sales quote from them.', MaxLength = 250, Comment = 'is-IS=Býr til endurnýjunarlínur samnings út frá áskriftarlínum áskriftarsamnings viðskiptamanns og útbýr endurnýjunarsölutilboð út frá þeim.';
        UnknownContractLineErr: Label 'Line %1 of contractLineNos is not a line of Customer Subscription Contract ''%2''.', Comment = '%1 = contract line number, %2 = customer contract no.||is-IS=Lína %1 í contractLineNos er ekki lína í áskriftarsamningi viðskiptamanns ''%2''.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Customer Subscription Contract");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create renewal quote, renew contract, renewal quotation, quote for contract renewal, renew subscription lines, create sales quote for renewal, contract renewal lines, renew a customer contract', Comment = 'is-IS=stofna endurnýjunartilboð, endurnýja samning, endurnýjunartilboð, tilboð vegna endurnýjunar samnings, endurnýja áskriftarlínur, stofna sölutilboð vegna endurnýjunar, endurnýjunarlínur samnings, endurnýja samning viðskiptamanns';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a renewal quote: builds renewal lines from the lines of a customer contract that have an end date and creates a sales quote from them. Irreversible. To extend a Subscription directly without a quote use Subscription.Renewal.Extend.', Comment = 'is-IS=Stofna endurnýjunartilboð: býr til endurnýjunarlínur úr þeim línum áskriftarsamnings viðskiptamanns sem hafa lokadagsetningu og stofnar sölutilboð út frá þeim. Óafturkræf aðgerð. Til að framlengja áskrift beint án tilboðs skal nota Subscription.Renewal.Extend.';
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
        Parameters := ContractParts.RenewalQuoteParameters();
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
        Examples.Add(ContractMgt.Example('Renew a contract',
            '{"type":"Subscription.Renewal.CreateQuote","subject":"CC000010"}',
            '{"status":"Success","contractNo":"CC000010","renewalLinesCreated":4,"salesQuoteNo":"SQ000123"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates a renewal sales quote for a Customer Subscription Contract through Microsoft''s renewal creation, without the interactive renewal ' +
            'wrapper, its dialog or request page.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Renewal lines left from an earlier run against the contract are deleted first. A renewal line is then built for every Subscription Line of the ' +
            'contract that has an end date and that Microsoft accepts for renewal. contractLineNos limits this to the listed contract lines; without it every ' +
            'line with an end date is renewed, as before. A listed line without an end date is passed over, and when no listed line can be renewed the call ' +
            'is refused. Nothing is posted. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Renewal.CreateQuote');
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

        if not Codeunit.Run(Codeunit::"Sub Ren CrQuote Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Builds the renewal lines for the contract and creates the renewal sales quote.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        SubContractRenewalLine: Record "Sub. Contract Renewal Line";
        CreateSubContractRenewal: Codeunit "Create Sub. Contract Renewal";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        SalesQuoteNo: Code[20];
        SelectedLineNos: Dictionary of [Integer, Boolean];
        SelectedLineNo: Integer;
        RenewalLinesCreated: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(RequestJson, 'contractNo', Argument, true);
        Helper.GetEntryNoSelection(RequestJson, 'contractLineNos', SelectedLineNos);

        if not CustomerSubscriptionContract.Get(ContractNo) then
            Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ContractNotFoundErr, ContractNo), 'contractNo', Format(ContractNo, 0, 9));
        foreach SelectedLineNo in SelectedLineNos.Keys() do
            if not CustSubContractLine.Get(ContractNo, SelectedLineNo) then
                Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownContractLineErr, SelectedLineNo, ContractNo), 'contractLineNos', Format(SelectedLineNo, 0, 9));

        SubContractRenewalLine.SetRange("Linked to Sub. Contract No.", ContractNo);
        if not SubContractRenewalLine.IsEmpty() then
            SubContractRenewalLine.DeleteAll(true);

        CustSubContractLine.Reset();
        CustSubContractLine.SetRange("Subscription Contract No.", ContractNo);
        CustSubContractLine.SetLoadFields("Subscription Contract No.", "Line No.", "Subscription Line Entry No.");
        if CustSubContractLine.FindSet() then
            repeat
                if (CustSubContractLine."Subscription Line Entry No." <> 0) and
                   ((SelectedLineNos.Count() = 0) or SelectedLineNos.ContainsKey(CustSubContractLine."Line No."))
                then
                    if SubscriptionLine.Get(CustSubContractLine."Subscription Line Entry No.") then
                        if SubscriptionLine."Subscription Line End Date" <> 0D then begin
                            Clear(SubContractRenewalLine);
                            if SubContractRenewalLine.InitFromServiceCommitment(SubscriptionLine) then begin
                                SubContractRenewalLine.Insert(false);
                                RenewalLinesCreated += 1;
                            end;
                        end;
            until CustSubContractLine.Next() = 0;

        if RenewalLinesCreated = 0 then
            Helper.RaiseRefusal("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoRenewableLinesErr, ContractNo), 'contractNo', Format(ContractNo, 0, 9));

        SubContractRenewalLine.Reset();
        SubContractRenewalLine.SetRange("Subscription Contract No.", ContractNo);
        SubContractRenewalLine.SetRange(Partner, Enum::"Service Partner"::Customer);

        Clear(CreateSubContractRenewal);
        // Call this without consuming the Boolean, so a failure inside Microsoft's codeunit
        // propagates instead of being caught here. The renewal lines above are already written in
        // this transaction, and Business Central cannot roll a caught Codeunit.Run back to a
        // savepoint once that is true - it abandons the whole transaction and reports only
        // "An error occurred and the transaction is stopped", losing the real reason. Letting the
        // error travel up to the single isolation boundary, ExecuteBifrostTask running this codeunit, rolls the
        // renewal lines back with it and keeps Microsoft's own message intact.
        CreateSubContractRenewal.Run(SubContractRenewalLine);

        SalesQuoteNo := CreateSubContractRenewal.GetSalesQuoteNo();
        if SalesQuoteNo = '' then
            Helper.RaiseRefusal("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(QuoteNotCreatedErr, ContractNo), 'contractNo', Format(ContractNo, 0, 9));

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('renewalLinesCreated', RenewalLinesCreated);
        ResponseJson.Add('salesQuoteNo', SalesQuoteNo);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
