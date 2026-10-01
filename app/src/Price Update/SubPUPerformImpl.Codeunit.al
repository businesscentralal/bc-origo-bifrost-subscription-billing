namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.Perform</c> Bifrost message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".PerformPriceUpdate</c> is internal and its worker codeunit 8013"Process Price
/// Update" is declared <c>Access = Internal</c>. A plain Data.Records call cannot reach either
/// of them, and this codeunit deliberately does not attempt to re-implement Microsoft's price
/// update application logic - silently diverging from it would corrupt customer contracts. It
/// always responds with a clear, structured error instead.
/// </summary>
codeunit 10035050 "Sub PU Perform Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        NotAccessibleErr: Label 'Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to perform the price update.', Comment = 'is-IS=Subscription.PriceUpdate.Perform er ekki hægt að keyra: Codeunit "Price Update Management".PerformPriceUpdate er innri í Business Central 28.4 og hefur ekki verið gert aðgengilegt utanaðkomandi köllum. Notaðu síðuna "Contract Price Update" í Business Central-biðlaranum til að framkvæma verðuppfærsluna.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to perform price updates. Use the "Contract Price Update" page instead.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að framkvæma verðuppfærslur. Notaðu síðuna "Contract Price Update" í staðinn.';

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
        KeywordsLbl: Label 'Subscription.PriceUpdate.Perform, Subscription, PriceUpdate, Perform, apply prices, subscription lines', Comment = 'is-IS=Subscription.PriceUpdate.Perform, áskrift, verðuppfærsla, framkvæma, beita verðum, áskriftarlínur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.PriceUpdate.Perform: Applies a price update proposal. Irreversible.', Comment = 'is-IS=Subscription.PriceUpdate.Perform: Beitir tillögu að verðuppfærslu. Óafturkræf aðgerð.';
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
        Parameters := ContractParts.GetParameters(ContractType());
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
    begin
        // A blocked type has no successful call to show.
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Blocked. Performing a price update needs Price Update Management.PerformPriceUpdate, which is internal in Business Central 28.4, and its worker ' +
            'codeunit 8013 Process Price Update is internal too.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ContractParts.BlockedNote() +
            'Microsoft''s PerformPriceUpdate applies every row of the price update proposal across all templates, with no template or contract filter of its own; ' +
            'the filtering happens when the proposal is created.';
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

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotAccessibleErr);
    end;
}
