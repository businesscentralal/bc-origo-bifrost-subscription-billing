namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.ClearProposal</c> Bifrost message type (#37).
/// Deletes the billing proposal lines of a Billing Template, optionally only those of one contract,
/// the way the Clear Billing Proposal action on the Recurring Billing page does for "Only current
/// billing template proposal". Microsoft's "Billing Proposal".DeleteBillingProposal is internal and
/// asks its question in a dialog, so the lines are deleted here with Delete(true): the Billing Line
/// OnDelete trigger resets the Next Billing Date of each Subscription Line and recalculates the
/// harmonized billing fields of the contract. A line already on a document is refused.
/// </summary>
codeunit 10035061 "Sub Bil ClrProposal Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateOrContractErr: Label 'The request must name a Billing Template in ''billingTemplateCode'' or the subject, or, for the billing lines without a Billing Template, a contract in ''contractNo''.', Comment = 'is-IS=Beiðnin verður að tilgreina reikningssniðmát í ''billingTemplateCode'' eða efninu, eða, fyrir reikningslínur án reikningssniðmáts, samning í ''contractNo''.';
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        LinesOnDocumentErr: Label '%1 billing line(s) of Billing Template ''%2'' are already on document %3. Delete the documents first with Subscription.Billing.DeleteDocuments, then clear the proposal.', Comment = '%1 = line count, %2 = billing template code, %3 = document number||is-IS=%1 reikningslína/-línur í reikningssniðmátinu ''%2'' eru þegar á skjali %3. Eyddu skjölunum fyrst með Subscription.Billing.DeleteDocuments og hreinsaðu síðan tillöguna.';
        DescriptionLbl: Label 'Deletes the billing proposal lines of a Billing Template, or of one contract under it, and resets the Next Billing Date of their Subscription Lines. Refuses lines already on a document.', MaxLength = 250, Comment = 'is-IS=Eyðir línum reikningstillögu í reikningssniðmáti, eða eins samnings undir því, og færir næstu reikningsdagsetningu áskriftarlína þeirra til baka. Hafnar línum sem eru þegar á skjali.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Line");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'clear billing proposal, delete billing proposal, undo billing proposal, remove proposal lines, reset next billing date, start the billing run over, cancel the proposal, clear proposal for contract', Comment = 'is-IS=hreinsa reikningstillögu, eyða reikningstillögu, afturkalla reikningstillögu, fjarlægja tillögulínur, færa næstu reikningsdagsetningu til baka, byrja reikningagerðina upp á nýtt, hætta við tillöguna, hreinsa tillögu fyrir samning';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Clear a billing proposal: deletes the proposal lines of a Billing Template, or of one contract, that are not on a document yet and resets the Next Billing Date of their Subscription Lines. Irreversible. If lines are already on documents, delete the documents first with Subscription.Billing.DeleteDocuments; to propose again use Subscription.Billing.CreateProposal.', Comment = 'is-IS=Hreinsa reikningstillögu: eyðir tillögulínum reikningssniðmáts, eða eins samnings, sem eru ekki enn á skjali og færir næstu reikningsdagsetningu áskriftarlína þeirra til baka. Óafturkræf aðgerð. Ef línur eru þegar á skjölum skal fyrst eyða skjölunum með Subscription.Billing.DeleteDocuments; til að gera tillögu aftur skal nota Subscription.Billing.CreateProposal.';
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
        Parameters := ContractParts.ClearProposalParameters();
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
        Examples.Add(ContractMgt.Example('Clear a monthly proposal',
            '{"type":"Subscription.Billing.ClearProposal","subject":"MONTHLY","data":{}}',
            '{"status":"Success","billingTemplateCode":"MONTHLY","contractNo":"","billingLinesDeleted":12,"subscriptionLinesReset":10,"contracts":["CC000010","CC000011"]}'));
        Examples.Add(ContractMgt.Example('Clear one contract only',
            '{"type":"Subscription.Billing.ClearProposal","subject":"MONTHLY","data":{"contractNo":"CC000010"}}',
            '{"status":"Success","billingTemplateCode":"MONTHLY","contractNo":"CC000010","billingLinesDeleted":2,"subscriptionLinesReset":2,"contracts":["CC000010"]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes the billing proposal lines (Billing Line) of a Billing Template that are not on a document yet, optionally only those of one contract. Each ' +
            'Subscription Line gets back the Next Billing Date it had before the proposal. This undoes Subscription.Billing.CreateProposal, also the part a failed ' +
            'run left behind after one of Microsoft''s commits.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Without billingTemplateCode the call works on the billing lines without a Billing Template, which Subscription.Contract.CreateInvoice and ' +
            'Subscription.VendorContract.CreateInvoice create; contractNo is then required. The lines are deleted newest billing period first, as Microsoft does, ' +
            'because only the last billing line of a Subscription Line may be deleted. When a later billing line of the same Subscription Line sits under another ' +
            'Billing Template, Business Central refuses and the call rolls back. When any Billing Template bills automatically, only a user with Auto Contract ' +
            'Billing in User Setup may clear a proposal, as in the client. Lines already on an unposted document are refused: delete the document first with ' +
            'Subscription.Billing.DeleteDocuments. Zero lines is still a success. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Billing.ClearProposal');
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

        if not Codeunit.Run(Codeunit::"Sub Bil ClrProposal Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes the selected billing proposal lines. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        BillingLine: Record "Billing Line";
        BillingTemplate: Record "Billing Template";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractsArray: JsonArray;
        ContractNos: List of [Code[20]];
        ResetLines: List of [Integer];
        ContractNo: Code[20];
        BillingTemplateCode: Code[20];
        LinesDeleted: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(RequestJson, 'billingTemplateCode', Argument, false);
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);

        if BillingTemplateCode = '' then begin
            if ContractNo = '' then
                Helper.RaiseRefusal("Bifrost Error Code ori"::MissingParameter, TemplateOrContractErr, 'billingTemplateCode|contractNo', '');
        end else
            if not BillingTemplate.Get(BillingTemplateCode) then
                Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateNotFoundErr, BillingTemplateCode), 'billingTemplateCode', Format(BillingTemplateCode, 0, 9));
        Helper.AssertMayClearBillingProposal();

        FilterProposal(BillingLine, BillingTemplateCode, ContractNo);
        BillingLine.SetFilter("Document No.", '<>%1', '');
        if BillingLine.FindFirst() then
            if ContractNo <> '' then
                Helper.RaiseRefusal("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinesOnDocumentErr, BillingLine.Count(), BillingTemplateCode, BillingLine."Document No."), 'contractNo', Format(ContractNo, 0, 9))
            else
                Helper.RaiseRefusal("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinesOnDocumentErr, BillingLine.Count(), BillingTemplateCode, BillingLine."Document No."), 'billingTemplateCode', Format(BillingTemplateCode, 0, 9));

        FilterProposal(BillingLine, BillingTemplateCode, ContractNo);
        BillingLine.SetCurrentKey("Subscription Header No.", "Subscription Line Entry No.", "Billing to");
        BillingLine.SetAscending("Billing to", false);
        if BillingLine.FindSet(true) then
            repeat
                if not ContractNos.Contains(BillingLine."Subscription Contract No.") then
                    if BillingLine."Subscription Contract No." <> '' then
                        ContractNos.Add(BillingLine."Subscription Contract No.");
                if not ResetLines.Contains(BillingLine."Subscription Line Entry No.") then
                    ResetLines.Add(BillingLine."Subscription Line Entry No.");
                BillingLine.Delete(true);
                LinesDeleted += 1;
            until BillingLine.Next() = 0;

        foreach ContractNo in ContractNos do
            ContractsArray.Add(ContractNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        ResponseJson.Add('contractNo', Helper.GetCode20(RequestJson, 'contractNo', false));
        ResponseJson.Add('billingLinesDeleted', LinesDeleted);
        ResponseJson.Add('subscriptionLinesReset', ResetLines.Count());
        ResponseJson.Add('contracts', ContractsArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure FilterProposal(var BillingLine: Record "Billing Line"; BillingTemplateCode: Code[20]; ContractNo: Code[20])
    begin
        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        if ContractNo <> '' then
            BillingLine.SetRange("Subscription Contract No.", ContractNo);
    end;
}
