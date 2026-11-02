namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.SetTemplateFilter</c> Bifrost message type (#41 AC04).
/// Writes the contract filter of a Billing Template, the view that decides which contracts a billing
/// proposal from the template covers. "Billing Template".WriteFilter and EditFilter are internal and
/// EditFilter opens a filter page, so this mirrors Subscription.PriceUpdate.SetTemplateFilter: the view
/// is validated and normalised through Foundation's fail-closed Message Argument ori.ApplyTableView
/// on Customer or Vendor Subscription Contract, following the template's Partner, and written to the
/// Filter Blob the way WriteFilter does (nothing when it equals the table's blank view). A view that
/// does not parse is refused and nothing is written.
/// 
/// Portions copyright (c) Microsoft Corporation, licensed under the MIT License (BCApps releases/28.x
/// a674a13, src/Apps/W1/Subscription Billing/App/Billing/Tables/BillingTemplate.Table.al, WriteFilter).
/// </summary>
codeunit 10035070 "Sub Bil SetFilter Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        InvalidFilterErr: Label 'The parameter ''filter'' is not a valid Business Central view of %1. Supply a view in the form ''WHERE(Field=FILTER(Value))''. Nothing was written.', Comment = '%1 = the contract table caption||is-IS=Færibreytan ''filter'' er ekki gild Business Central sýn á %1. Sendu sýn á forminu ''WHERE(Reitur=FILTER(Gildi))''. Engu var breytt.';
        DescriptionLbl: Label 'Writes the contract filter of a Billing Template after validating it as a view of the template''s contract table, and returns the stored filter.', MaxLength = 250, Comment = 'is-IS=Skrifar samningssíu reikningssniðmáts eftir að hafa sannreynt hana sem sýn á samningatöflu sniðmátsins og skilar vistuðu síunni.';

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
        KeywordsLbl: Label 'set billing template filter, filter contracts of billing template, restrict billing run to contracts, billing template contract filter, change which contracts are billed, edit template filter, limit billing template, billing filter', Comment = 'is-IS=setja síu á reikningssniðmát, sía samninga reikningssniðmáts, takmarka reikningskeyrslu við samninga, samningssía reikningssniðmáts, breyta því hvaða samningar eru reikningsfærðir, breyta sniðmátssíu, afmarka reikningssniðmát, reikningssía';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Set a Billing Template filter: validates and stores the contract filter that decides which contracts Subscription.Billing.CreateProposal bills for the template. Writes only the template. For Price Update Templates use Subscription.PriceUpdate.SetTemplateFilter.', Comment = 'is-IS=Setja síu á reikningssniðmát: sannreynir og vistar samningssíuna sem ákveður hvaða samninga Subscription.Billing.CreateProposal reikningsfærir fyrir sniðmátið. Skrifar eingöngu sniðmátið. Fyrir verðuppfærslusniðmát skal nota Subscription.PriceUpdate.SetTemplateFilter.';
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
        Parameters := ContractParts.BillingTemplateFilterParameters();
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
        Examples.Add(ContractMgt.Example('Limit a template to monthly contracts',
            '{"type":"Subscription.Billing.SetTemplateFilter","subject":"MONTHLY","data":{"filter":"WHERE(Contract Type=FILTER(MONTHLY))"}}',
            '{"status":"Success","billingTemplateCode":"MONTHLY","partner":"Customer","filter":"<normalised view>"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Writes the Filter of a Billing Template: the view of Customer Subscription Contract (Partner Customer) or Vendor Subscription Contract (Partner ' +
            'Vendor) whose contracts a billing proposal from the template covers. The view is validated and normalised before it is stored, in the syntax the ' +
            'Billing Template page stores, so a mistyped field or a broken view is refused instead of silently widening the next billing run.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('A view without filters clears the stored filter, so the template covers every contract again. The filter is checked against the current Partner of the ' +
            'template; changing the Partner later does not convert it. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Billing.SetTemplateFilter');
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

        if not Codeunit.Run(Codeunit::"Sub Bil SetFilter Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Validates and writes the template's contract filter. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        BillingTemplate: Record "Billing Template";
        RRef: RecordRef;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OutStr: OutStream;
        BillingTemplateCode: Code[20];
        SuppliedFilter: Text;
        FilterText: Text;
        BlankView: Text;
        PublicFilter: Text;
        TargetCaption: Text;
        ViewApplied: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(RequestJson, 'billingTemplateCode', Argument, true);
        SuppliedFilter := Helper.GetText(RequestJson, 'filter', true);

        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        if BillingTemplate.Partner = BillingTemplate.Partner::Vendor then
            RRef.Open(Database::"Vendor Subscription Contract")
        else
            RRef.Open(Database::"Customer Subscription Contract");
        TargetCaption := RRef.Caption();
        BlankView := RRef.GetView(false);
        if not TryApplyTableView(Argument, RRef, SuppliedFilter, ViewApplied) then
            Error(InvalidFilterErr, TargetCaption);
        // Foundation has already answered with a structured refusal (code and nextStep) when it returns false.
        if not ViewApplied then begin
            Clear(RRef);
            NormalizeFilterError(Argument);
            exit;
        end;
        FilterText := RRef.GetView(false);
        PublicFilter := RRef.GetView(true);
        Clear(RRef);

        // Microsoft: "Billing Template".WriteFilter - the Blob is cleared and the view written unless it is the blank view.
        Clear(BillingTemplate.Filter);
        BillingTemplate.Filter.CreateOutStream(OutStr, TextEncoding::UTF8);
        if FilterText <> BlankView then
            OutStr.WriteText(FilterText);
        BillingTemplate.Modify(true);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        if BillingTemplate.Partner = BillingTemplate.Partner::Vendor then
            ResponseJson.Add('partner', 'Vendor')
        else
            ResponseJson.Add('partner', 'Customer');
        if FilterText = BlankView then
            PublicFilter := '';
        ResponseJson.Add('filter', PublicFilter);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure NormalizeFilterError(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        if Response.Contains('parameter') then
            Response.Replace('parameter', 'filter');
        if Response.Get('error', Token) then
            Response.Replace('error', Token.AsValue().AsText().Replace('tableView', 'filter'));
        if Response.Get('expected', Token) then
            Response.Replace('expected', Token.AsValue().AsText().Replace('tableView', 'filter'));
        if Response.Get('nextStep', Token) then
            Response.Replace('nextStep', Token.AsValue().AsText().Replace('tableView', 'filter'));
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Adapts filter to Foundation's tableView contract and validates it before applying it.</summary>
    [TryFunction]
    local procedure TryApplyTableView(var Argument: Record "Message Argument ori"; var RRef: RecordRef; View: Text; var ViewApplied: Boolean)
    var
        ViewRequest: JsonObject;
    begin
        ViewRequest.Add('tableView', View);
        ViewApplied := Argument.ApplyTableView(ViewRequest, RRef);
    end;
}
