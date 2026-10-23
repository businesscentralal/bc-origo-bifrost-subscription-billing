namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.CreateProposal</c> Bifrost message type.
/// Runs Microsoft's "Create Billing Proposal" over a Billing Template for a billing date
/// and an optional billing-to date, filling the Billing Line table with proposal lines.
/// A plain Data.Records.Set cannot do this because the proposal is produced by a codeunit
/// that walks every due Subscription Line and derives the periods to bill.
/// </summary>
codeunit 10035045 "Sub Bil CrProposal Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        DescriptionLbl: Label 'Creates billing proposal lines for a Billing Template and a billing date. Returns the number of proposal lines created and the contracts they cover.', MaxLength = 250, Comment = 'is-IS=Býr til reikningstillögulínur fyrir reikningssniðmát og reikningsdagsetningu. Skilar fjölda tillögulína sem urðu til og þeim samningum sem þær ná yfir.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Template");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create billing proposal, run recurring billing, which contracts are due, billing proposal for template, generate billing lines, bill due subscription lines, start a billing run, proposal for billing date', Comment = 'is-IS=stofna reikningstillögu, keyra endurtekna reikningagerð, hvaða samningar eru á gjalddaga, reikningstillaga fyrir sniðmát, útbúa reikningslínur, reikningsfæra gjaldfallnar áskriftarlínur, hefja reikningagerð, tillaga fyrir reikningsdagsetningu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a billing proposal: generates billing proposal lines under a Billing Template for the Subscription Lines due on a billing date, without creating any document. Irreversible, because Microsoft commits the lines in batches. Next review with Subscription.Billing.PreviewDocuments and create documents with Subscription.Billing.CreateDocuments; undo with Subscription.Billing.ClearProposal.', Comment = 'is-IS=Stofna reikningstillögu: býr til tillögulínur undir reikningssniðmáti fyrir þær áskriftarlínur sem eru á gjalddaga á reikningsdagsetningu, án þess að búa til nokkurt skjal. Óafturkræf aðgerð, því Microsoft vistar línurnar í hópum. Næst er tillagan yfirfarin með Subscription.Billing.PreviewDocuments og skjöl stofnuð með Subscription.Billing.CreateDocuments; til að afturkalla skal nota Subscription.Billing.ClearProposal.';
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
        Parameters := ContractParts.BillingProposalParameters();
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
        Examples.Add(ContractMgt.Example('Propose a monthly run',
            '{"type":"Subscription.Billing.CreateProposal","subject":"MONTHLY","data":{"billingDate":"2026-08-31","billingToDate":"2026-09-30"}}',
            '{"status":"Success","billingTemplateCode":"MONTHLY","billingDate":"2026-08-31","billingToDate":"2026-09-30","proposalLinesCreated":12,"proposalLineCount":12,"contracts":["CC000010","CC000011"]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates billing proposal lines (Billing Line) for a Billing Template: every Subscription Line due on or before the billing date that matches the ' +
            'template''s filter is proposed. Nothing is invoiced; Subscription.Billing.CreateDocuments turns the proposal into documents.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('proposalLinesCreated counts what this call added; proposalLineCount and contracts cover every proposal line now standing for the template, including ' +
            'earlier runs. The run is not one transaction: Microsoft commits the proposal lines every CommitBatchSize (50) contracts, also under Omit Commit, ' +
            'so an error after such a commit leaves those lines in place. Subscription.Billing.ClearProposal undoes a proposal, also a partial one. ' +
            ContractParts.BooleanNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Billing.CreateProposal');
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

        if not Codeunit.Run(Codeunit::"Sub Bil CrProposal Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Runs the billing proposal. Called directly, or by OnRun when ExecuteBifrostTask runs this codeunit in its own transaction.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        BillingLine: Record "Billing Line";
        BillingTemplate: Record "Billing Template";
        BillingProposal: Codeunit "Billing Proposal";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractsArray: JsonArray;
        ContractNos: List of [Code[20]];
        ContractNo: Code[20];
        BillingTemplateCode: Code[20];
        BillingDate: Date;
        BillingToDate: Date;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(RequestJson, 'billingTemplateCode', Argument, true);
        BillingDate := Helper.GetDateOrDefault(RequestJson, 'billingDate', WorkDate());
        BillingToDate := Helper.GetDate(RequestJson, 'billingToDate', false);

        if not BillingTemplate.Get(BillingTemplateCode) then
            Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateNotFoundErr, BillingTemplateCode), 'billingTemplateCode', Format(BillingTemplateCode, 0, 9));

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        LinesBefore := BillingLine.Count();

        BillingProposal.CreateBillingProposal(BillingTemplateCode, BillingDate, BillingToDate, Helper.GetBoolean(RequestJson, 'automatedBilling', true));

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        LinesAfter := BillingLine.Count();

        BillingLine.SetLoadFields("Subscription Contract No.");
        if BillingLine.FindSet() then
            repeat
                if not ContractNos.Contains(BillingLine."Subscription Contract No.") then
                    if BillingLine."Subscription Contract No." <> '' then
                        ContractNos.Add(BillingLine."Subscription Contract No.");
            until BillingLine.Next() = 0;
        foreach ContractNo in ContractNos do
            ContractsArray.Add(ContractNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        ResponseJson.Add('billingDate', Helper.FormatDate(BillingDate));
        ResponseJson.Add('billingToDate', Helper.FormatDate(BillingToDate));
        ResponseJson.Add('proposalLinesCreated', LinesAfter - LinesBefore);
        ResponseJson.Add('proposalLineCount', LinesAfter);
        ResponseJson.Add('contracts', ContractsArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
