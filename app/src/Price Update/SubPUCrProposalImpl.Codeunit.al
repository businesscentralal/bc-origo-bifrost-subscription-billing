namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.CreateProposal</c> Bifrost message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".CreatePriceUpdateProposal</c> is internal, the whole <c>Interface"Contract
/// Price Update"</c> and its implementations are internal, and the worker codeunit 8013
/// "Process Price Update" is declared <c>Access = Internal</c>. A plain Data.Records call
/// cannot reach any of them, and this codeunit deliberately does not attempt to re-implement
/// Microsoft's price update proposal logic - silently diverging from it would mis-price
/// customer contracts. It always responds with a clear, structured error instead.
/// </summary>
codeunit 10035049 "Sub PU CrProposal Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        NotAccessibleErr: Label 'Subscription.PriceUpdate.CreateProposal cannot run: Codeunit "Price Update Management".CreatePriceUpdateProposal is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to create the proposal, or call Subscription.PriceUpdate.SetTemplateFilter first to prepare the template''s filters.', Comment = 'is-IS=Subscription.PriceUpdate.CreateProposal er ekki hægt að keyra: Codeunit "Price Update Management".CreatePriceUpdateProposal er innri í Business Central 28.4 og hefur ekki verið gert aðgengilegt utanaðkomandi köllum. Notaðu síðuna "Contract Price Update" í Business Central-biðlaranum til að útbúa tillöguna, eða kallaðu á Subscription.PriceUpdate.SetTemplateFilter fyrst til að undirbúa síur sniðmátsins.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to create price update proposals. Use the "Contract Price Update" page instead.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að búa til verðuppfærslutillögur. Notaðu síðuna "Contract Price Update" í staðinn.';

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
        KeywordsLbl: Label 'Subscription.PriceUpdate.CreateProposal, Subscription, PriceUpdate, CreateProposal, price update, proposal', Comment = 'is-IS=Subscription.PriceUpdate.CreateProposal, áskrift, verðuppfærsla, stofna tillögu, verðuppfærsla, tillaga';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.PriceUpdate.CreateProposal: Creates a price update proposal.', Comment = 'is-IS=Subscription.PriceUpdate.CreateProposal: Stofnar tillögu að verðuppfærslu.';
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
        Overview := 'Blocked. Creating a price update proposal needs Price Update Management.CreatePriceUpdateProposal, which is internal in Business Central 28.4, as are ' +
            'the Contract Price Update interface with all its implementations and codeunit 8013 Process Price Update.';
        exit(true);
    end;
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ContractParts.BlockedNote() +
            'Microsoft''s price update logic is not re-implemented here: a copy could diverge from Microsoft''s rounding, currency and binding-period rules and ' +
            'misprice live contracts.';
        exit(true);
    end;
    local procedure ContractType(): Text begin exit('Subscription.PriceUpdate.CreateProposal'); end;

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
