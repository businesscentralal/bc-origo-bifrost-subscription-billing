namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.CreateProposal</c> Bifrost message type.
/// Creates the Contract Price Update Lines of a Price Update Template the way Microsoft's
/// "Contract Price Update" page does: same default dates, same filters, same three price update
/// methods and the same rounding. Microsoft's own procedure, Price Update Management.CreatePriceUpdateProposal,
/// is internal in Business Central 28, so the call runs "Sub PU Price Update Mgt ori", a referenced copy of it
/// (see docs/microsoft-dependencies.md). No Subscription Line is changed; Subscription.PriceUpdate.Perform
/// applies the proposal.
/// </summary>
codeunit 10035049 "Sub PU CrProposal Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Price Update Template ''%1'' does not exist.', Comment = '%1 = price update template code||is-IS=Sniðmát fyrir verðuppfærslu ''%1'' er ekki til.';
        NoLinesCreatedMsg: Label 'No Contract Price Update Line was created for Price Update Template ''%1''. No Subscription Line matched the template''s partner, filters and dates, or every match already has a price update line.', Comment = '%1 = price update template code||is-IS=Engin lína verðuppfærslu áskriftarsamnings var stofnuð fyrir sniðmát fyrir verðuppfærslu ''%1''. Engin áskriftarlína passaði við viðskiptaaðila, síur og dagsetningar sniðmátsins, eða allar sem pössuðu eru þegar með línu verðuppfærslu.';
        DescriptionLbl: Label 'Creates the Contract Price Update Lines of a Price Update Template, as the Contract Price Update page does. Subscription Lines are not changed.', MaxLength = 250, Comment = 'is-IS=Stofnar línur verðuppfærslu áskriftarsamnings fyrir sniðmát fyrir verðuppfærslu, eins og síðan Verðuppfærsla áskriftarsamnings gerir. Áskriftarlínum er ekki breytt.';

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
        KeywordsLbl: Label 'create price update proposal, index contract prices, price increase proposal, propose new subscription prices, raise subscription prices, price update lines, contract price update, indexation proposal', Comment = 'is-IS=stofna tillögu að verðuppfærslu, vísitölutengja verð samninga, tillaga að verðhækkun, leggja til ný áskriftarverð, hækka áskriftarverð, línur verðuppfærslu, verðuppfærsla samninga, tillaga að vísitölutengingu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a price update proposal: creates Contract Price Update Lines with the new prices for the Subscription Lines a Price Update Template matches. Writes the proposal lines only; no price changes yet. Narrow the lines first with Subscription.PriceUpdate.SetTemplateFilter; apply the proposal with Subscription.PriceUpdate.Perform.', Comment = 'is-IS=Stofna tillögu að verðuppfærslu: býr til línur verðuppfærslu með nýjum verðum fyrir þær áskriftarlínur sem verðuppfærslusniðmát nær yfir. Skrifar eingöngu tillögulínurnar; engin verð breytast enn. Fyrst er línum afmarkað með Subscription.PriceUpdate.SetTemplateFilter; tillagan er framkvæmd með Subscription.PriceUpdate.Perform.';
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
        Parameters := ContractParts.PriceUpdateProposalParameters();
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
        Examples.Add(ContractMgt.Example('Propose a yearly price update with the template''s own dates',
            '{"type":"Subscription.PriceUpdate.CreateProposal","subject":"ANNUAL"}',
            '{"status":"Success","priceUpdateTemplateCode":"ANNUAL","priceUpdateMethod":"Price by %","includeLinesUpToDate":"2027-01-31","performUpdateOnDate":"2027-01-01","linesCreated":1,"linesNotCreated":0,"proposalLineCount":1,"lines":[{"entryNo":17,"subscriptionLineEntryNo":42,"subscriptionHeaderNo":"SUB000010","contractNo":"CC000010","partnerNo":"10000","oldPrice":"100","newPrice":"103","oldAmount":"1200","newAmount":"1236","additionalAmount":"36","oldCalculationBase":"100","newCalculationBase":"103","newCalculationBasePct":"100","discountPct":"0","discountAmount":"0","performUpdateOn":"2027-01-01","nextPriceUpdate":"2028-01-01"}],"hasMore":false}'));
        Examples.Add(ContractMgt.Example('Propose with explicit dates',
            '{"type":"Subscription.PriceUpdate.CreateProposal","subject":"ANNUAL","data":{"includeLinesUpToDate":"2027-03-31","performUpdateOnDate":"2027-04-01"}}',
            '{"status":"Success","priceUpdateTemplateCode":"ANNUAL","linesCreated":0,"message":"No Contract Price Update Line was created for Price Update Template ''ANNUAL''. ..."}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates the Contract Price Update Lines of a Price Update Template, the proposal a person creates with Create Proposal on the Contract Price Update page. ' +
            'The template''s Price Update Method decides the new price: Calculation Base by %, Price by % or Recent Item Prices. Run Subscription.PriceUpdate.Perform to apply it.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Microsoft''s proposal logic is internal in Business Central 28, so this runs a referenced copy of it; the copy is checked against ' +
            'Microsoft''s own page by tests. A Subscription Line is proposed only when it belongs to the template''s partner, is invoiced via a contract, is not excluded from ' +
            'price updates, not closed, not usage based, has no Planned Subscription Line and its Next Price Update is empty or on or before includeLinesUpToDate. A line that ' +
            'already has a price update line, under any template, is left out. A line whose new calculation base would be zero or less is not created and is counted in ' +
            'linesNotCreated. Perform Update On is the latest of the line''s Next Billing Date, its Next Price Update and performUpdateOnDate; Next Price Update becomes ' +
            'Perform Update On plus the template''s Price Binding Period. ' + ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.PriceUpdate.CreateProposal');
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

        if not Codeunit.Run(Codeunit::"Sub PU CrProposal Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Creates the proposal and reports the lines it created. Called directly under Omit Commit, or in isolation through OnRun.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        PriceUpdateTemplate: Record "Price Update Template";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateManagement: Codeunit "Sub PU Price Update Mgt ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        LinesJson: JsonArray;
        PriceUpdateTemplateCode: Code[20];
        IncludeLinesUpToDate: Date;
        PerformUpdateOnDate: Date;
        WatermarkEntryNo: Integer;
        LinesCreated: Integer;
        MaxLinesReturned: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        PriceUpdateTemplateCode := Helper.GetSubjectOr(RequestJson, 'priceUpdateTemplateCode', Argument, true);
        if not PriceUpdateTemplate.Get(PriceUpdateTemplateCode) then
            Error(TemplateNotFoundErr, PriceUpdateTemplateCode);

        // The Contract Price Update page's defaults (ApplyPriceUpdateTemplateFilter): both dates come from the template's formulas and the work date.
        IncludeLinesUpToDate := Helper.GetDate(RequestJson, 'includeLinesUpToDate', false);
        if (IncludeLinesUpToDate = 0D) and (Format(PriceUpdateTemplate.InclContrLinesUpToDateFormula) <> '') then
            IncludeLinesUpToDate := CalcDate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, WorkDate());
        PerformUpdateOnDate := Helper.GetDateOrDefault(RequestJson, 'performUpdateOnDate', CalcDate(PriceUpdateTemplate."Perform Update on Formula", WorkDate()));

        ContractPriceUpdateLine.ReadIsolation := IsolationLevel::ReadCommitted;
        ContractPriceUpdateLine.SetLoadFields("Entry No.");
        if ContractPriceUpdateLine.FindLast() then
            WatermarkEntryNo := ContractPriceUpdateLine."Entry No.";

        PriceUpdateManagement.CreatePriceUpdateProposal(PriceUpdateTemplateCode, IncludeLinesUpToDate, PerformUpdateOnDate);

        MaxLinesReturned := 1000;
        ContractPriceUpdateLine.Reset();
        ContractPriceUpdateLine.SetFilter("Entry No.", '>%1', WatermarkEntryNo);
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplateCode);
        if ContractPriceUpdateLine.FindSet() then
            repeat
                LinesCreated += 1;
                if LinesCreated <= MaxLinesReturned then
                    LinesJson.Add(LineToJson(ContractPriceUpdateLine));
            until ContractPriceUpdateLine.Next() = 0;

        ContractPriceUpdateLine.Reset();
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplateCode);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        ResponseJson.Add('priceUpdateMethod', PriceUpdateMethodName(PriceUpdateTemplate."Price Update Method"));
        ResponseJson.Add('includeLinesUpToDate', Helper.FormatDate(IncludeLinesUpToDate));
        ResponseJson.Add('performUpdateOnDate', Helper.FormatDate(PerformUpdateOnDate));
        ResponseJson.Add('linesCreated', LinesCreated);
        ResponseJson.Add('linesNotCreated', PriceUpdateManagement.GetNotInsertedLineCount());
        ResponseJson.Add('proposalLineCount', ContractPriceUpdateLine.Count());
        ResponseJson.Add('lines', LinesJson);
        ResponseJson.Add('hasMore', LinesCreated > MaxLinesReturned);
        if LinesCreated = 0 then
            ResponseJson.Add('message', StrSubstNo(NoLinesCreatedMsg, PriceUpdateTemplateCode));
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure LineToJson(ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line") LineJson: JsonObject
    begin
        LineJson.Add('entryNo', ContractPriceUpdateLine."Entry No.");
        LineJson.Add('subscriptionLineEntryNo', ContractPriceUpdateLine."Subscription Line Entry No.");
        LineJson.Add('subscriptionHeaderNo', ContractPriceUpdateLine."Subscription Header No.");
        LineJson.Add('contractNo', ContractPriceUpdateLine."Subscription Contract No.");
        LineJson.Add('partnerNo', ContractPriceUpdateLine."Partner No.");
        LineJson.Add('oldPrice', Helper.FormatDecimal(ContractPriceUpdateLine."Old Price"));
        LineJson.Add('newPrice', Helper.FormatDecimal(ContractPriceUpdateLine."New Price"));
        LineJson.Add('oldAmount', Helper.FormatDecimal(ContractPriceUpdateLine."Old Amount"));
        LineJson.Add('newAmount', Helper.FormatDecimal(ContractPriceUpdateLine."New Amount"));
        LineJson.Add('additionalAmount', Helper.FormatDecimal(ContractPriceUpdateLine."Additional Amount"));
        LineJson.Add('oldCalculationBase', Helper.FormatDecimal(ContractPriceUpdateLine."Old Calculation Base"));
        LineJson.Add('newCalculationBase', Helper.FormatDecimal(ContractPriceUpdateLine."New Calculation Base"));
        LineJson.Add('newCalculationBasePct', Helper.FormatDecimal(ContractPriceUpdateLine."New Calculation Base %"));
        LineJson.Add('discountPct', Helper.FormatDecimal(ContractPriceUpdateLine."Discount %"));
        LineJson.Add('discountAmount', Helper.FormatDecimal(ContractPriceUpdateLine."Discount Amount"));
        LineJson.Add('performUpdateOn', Helper.FormatDate(ContractPriceUpdateLine."Perform Update On"));
        LineJson.Add('nextPriceUpdate', Helper.FormatDate(ContractPriceUpdateLine."Next Price Update"));
    end;

    /// <summary>
    /// Names the price update method for a JSON response with Microsoft's enum value names, for the reason
    /// Sub Helper ori.FormatDocumentType gives: Format() would return a translated caption.
    /// </summary>
    local procedure PriceUpdateMethodName(PriceUpdateMethod: Enum "Price Update Method"): Text
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := Enum::"Price Update Method".Names();
        Ordinals := Enum::"Price Update Method".Ordinals();
        exit(Names.Get(Ordinals.IndexOf(PriceUpdateMethod.AsInteger())));
    end;
}
