namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.Perform</c> Bifrost message type.
/// Applies the Contract Price Update Lines the way Perform Price Update on Microsoft's "Contract Price
/// Update" page does: each line updates its Subscription Line now (archiving the old prices) or, when the
/// change cannot take effect yet, writes a Planned Subscription Line; a processed line is deleted. Nothing
/// is posted. Microsoft's PerformPriceUpdate and codeunit 8013 "Process Price Update" are internal in
/// Business Central 28, so this runs "Sub PU Price Update Mgt ori" and "Sub PU Process Price Upd ori",
/// referenced copies of them (see docs/microsoft-dependencies.md).
/// </summary>
codeunit 10035050 "Sub PU Perform Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Price Update Template ''%1'' does not exist.', Comment = '%1 = price update template code||is-IS=Sniðmát fyrir verðuppfærslu ''%1'' er ekki til.';
        NothingToPerformErr: Label 'There are no Contract Price Update Lines to perform. Run Subscription.PriceUpdate.CreateProposal first.', Comment = 'is-IS=Engar línur verðuppfærslu áskriftarsamnings eru til að framkvæma. Keyrðu Subscription.PriceUpdate.CreateProposal fyrst.';
        NothingToPerformForTemplateErr: Label 'There are no Contract Price Update Lines for Price Update Template ''%1'' to perform. Run Subscription.PriceUpdate.CreateProposal first.', Comment = '%1 = price update template code||is-IS=Engar línur verðuppfærslu áskriftarsamnings eru til að framkvæma fyrir sniðmát fyrir verðuppfærslu ''%1''. Keyrðu Subscription.PriceUpdate.CreateProposal fyrst.';
        PartlyFailedErr: Label '%1 of %2 Contract Price Update Lines could not be performed and were left in the proposal; see ''results''. The other lines were performed and committed one by one, so they were not rolled back.', Comment = '%1 = number of failed lines, %2 = number of lines processed||is-IS=Ekki tókst að framkvæma %1 af %2 línum verðuppfærslu áskriftarsamnings og þær voru skildar eftir í tillögunni; sjá ''results''. Hinar línurnar voru framkvæmdar og staðfestar ein í einu og voru því ekki afturkallaðar.';
        DescriptionLbl: Label 'Applies the Contract Price Update Lines: updates Subscription Lines or writes Planned Subscription Lines, and deletes each performed line. Nothing is posted.', MaxLength = 250, Comment = 'is-IS=Beitir línum verðuppfærslu áskriftarsamnings: uppfærir áskriftarlínur eða skrifar áætlaðar áskriftarlínur og eyðir hverri framkvæmdri línu. Ekkert er bókað.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Price Update Template");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'perform price update, apply price update, apply new prices, execute price increase, update subscription prices, apply the proposed prices, run price update, write new prices to subscription lines', Comment = 'is-IS=framkvæma verðuppfærslu, beita verðuppfærslu, beita nýjum verðum, framkvæma verðhækkun, uppfæra áskriftarverð, beita tillögðum verðum, keyra verðuppfærslu, skrifa ný verð á áskriftarlínur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Apply a price update: writes the proposed prices to the Subscription Lines, or to Planned Subscription Lines when they cannot take effect yet, archives the old values and deletes each performed proposal line. Irreversible. Create the proposal first with Subscription.PriceUpdate.CreateProposal.', Comment = 'is-IS=Framkvæma verðuppfærslu: skrifar tillögð verð á áskriftarlínur, eða á áætlaðar áskriftarlínur þegar þau geta ekki tekið gildi strax, geymir gömlu gildin í safni og eyðir hverri framkvæmdri tillögulínu. Óafturkræf aðgerð. Fyrst þarf að stofna tillöguna með Subscription.PriceUpdate.CreateProposal.';
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
        Parameters := ContractParts.PriceUpdatePerformParameters();
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
        Examples.Add(ContractMgt.Example('Perform the proposal of one template',
            '{"type":"Subscription.PriceUpdate.Perform","subject":"ANNUAL"}',
            '{"status":"Success","priceUpdateTemplateCode":"ANNUAL","linesProcessed":2,"subscriptionLinesUpdated":1,"plannedSubscriptionLinesCreated":1,"linesSkipped":0,"linesFailed":0,"results":[{"entryNo":17,"subscriptionLineEntryNo":42,"outcome":"Updated"},{"entryNo":18,"subscriptionLineEntryNo":43,"outcome":"Planned"}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Applies the Contract Price Update Lines, as Perform Price Update on the Contract Price Update page does. A line whose change can take effect now updates ' +
            'its Subscription Line and archives the old prices; otherwise it writes a Planned Subscription Line that Microsoft applies when the line is next billed. ' +
            'Each performed line is deleted. Nothing is posted.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Microsoft''s price update logic is internal in Business Central 28, so this runs a referenced copy of it; the copy is checked ' +
            'against Microsoft''s own page by tests. Without priceUpdateTemplateCode or a subject every line of every template is performed, which is what Microsoft does; ' +
            'with one, only that template''s lines. A Planned Subscription Line is written instead of changing the line when Perform Update On is after the line''s Next ' +
            'Billing Date, when the line is on an unposted invoice or credit memo, or when its Next Billing Date is before its Next Price Update. A line that already has ' +
            'a Planned Subscription Line is left unchanged and its price update line is deleted (outcome SkippedPlannedExists), as Microsoft does. Each line is committed ' +
            'on its own, so a failed line stays in the proposal while the others are kept; the answer is then status Error with the results. Under Omit Commit nothing is ' +
            'committed: the first failure stops the call and the caller''s transaction rolls everything back.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.PriceUpdate.Perform');
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

        if not Codeunit.Run(Codeunit::"Sub PU Perform Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Performs the price update lines and reports each line's outcome. Called directly under Omit Commit, where
    /// nothing is committed, or in isolation through OnRun, where each line commits on its own.
    /// </summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        PriceUpdateTemplate: Record "Price Update Template";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateManagement: Codeunit "Sub PU Price Update Mgt ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ResultJson: JsonObject;
        Results: JsonArray;
        ResultToken: JsonToken;
        OutcomeToken: JsonToken;
        PriceUpdateTemplateCode: Code[20];
        UpdatedCount: Integer;
        PlannedCount: Integer;
        SkippedCount: Integer;
        FailedCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        PriceUpdateTemplateCode := Helper.GetSubjectOr(RequestJson, 'priceUpdateTemplateCode', Argument, false);
        if PriceUpdateTemplateCode <> '' then begin
            if not PriceUpdateTemplate.Get(PriceUpdateTemplateCode) then
                Error(TemplateNotFoundErr, PriceUpdateTemplateCode);
            ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplateCode);
        end;

        if ContractPriceUpdateLine.IsEmpty() then
            if PriceUpdateTemplateCode = '' then
                Error(NothingToPerformErr)
            else
                Error(NothingToPerformForTemplateErr, PriceUpdateTemplateCode);

        PriceUpdateManagement.PerformPriceUpdate(ContractPriceUpdateLine, not Argument."Omit Commit", Results);

        foreach ResultToken in Results do begin
            ResultJson := ResultToken.AsObject();
            ResultJson.Get('outcome', OutcomeToken);
            case OutcomeToken.AsValue().AsText() of
                'Updated':
                    UpdatedCount += 1;
                'Planned':
                    PlannedCount += 1;
                'SkippedPlannedExists':
                    SkippedCount += 1;
                else
                    FailedCount += 1;
            end;
        end;

        if FailedCount > 0 then begin
            ResponseJson.Add('status', 'Error');
            ResponseJson.Add('error', StrSubstNo(PartlyFailedErr, FailedCount, Results.Count()));
            ResponseJson.Add('rolledBack', false);
        end else
            ResponseJson.Add('status', 'Success');
        ResponseJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        ResponseJson.Add('linesProcessed', Results.Count());
        ResponseJson.Add('subscriptionLinesUpdated', UpdatedCount);
        ResponseJson.Add('plannedSubscriptionLinesCreated', PlannedCount);
        ResponseJson.Add('linesSkipped', SkippedCount);
        ResponseJson.Add('linesFailed', FailedCount);
        ResponseJson.Add('results', Results);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
