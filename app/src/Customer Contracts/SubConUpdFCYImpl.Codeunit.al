namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Registers the <c>Subscription.Contract.UpdateExchangeRates</c> Bifrost message type, and
/// always responds with a structured error. Recalculating a contract's foreign-currency service
/// commitment amounts - the action labelled "Update Exchange Rates" in the client - is performed
/// by <c>Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData()</c>,
/// which is <c>internal</c> in Microsoft's app. Even if it were public, the underlying flow opens
/// the interactive "Exchange Rate Selection" page and, when <c>GuiAllowed</c> is false, that page
/// returns false and the flow proceeds with a zero exchange rate - so calling it unattended would
/// be unsafe even with access, and this message type intentionally never writes.
/// </summary>
codeunit 10035041 "Sub Con UpdFCY Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        NotSupportedErr: Label 'Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() is internal to Microsoft''s Subscription Billing app. It also drives the interactive "Exchange Rate Selection" page, which returns false and lets a zero exchange rate through when GuiAllowed is false, so it would be unsafe to call unattended even if it were public. Use the "Update Exchange Rates" action on the contract in the Business Central client instead.', Comment = 'is-IS=Subscription.Contract.UpdateExchangeRates hefur ekkert stutt opinbert API í þessari útgáfu af Business Central. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() er innri í Subscription Billing-forriti Microsoft. Hún keyrir einnig gagnvirku síðuna "Exchange Rate Selection", sem skilar false og hleypir í gegn núllgengi þegar GuiAllowed er false, svo það væri óöruggt að kalla hana án eftirlits jafnvel þótt hún væri opinber. Notaðu aðgerðina „Uppfæra gengi“ ("Update Exchange Rates") á samningnum í Business Central-biðlaranum í staðinn.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to recalculate a contract''s exchange rates, and the underlying flow is unsafe unattended. Always returns a structured error.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert API aðgengilegt til að endurreikna gengi samnings og undirliggjandi ferli er óöruggt án eftirlits. Skilar alltaf skipulagðri villu.';

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

    procedure GetKeywords(): Text begin exit(GetDescription()); end;
    procedure GetSelectionDescription(): Text begin exit(GetDescription()); end;
    procedure GetEnvelope(var Envelope: JsonObject): Boolean begin Envelope := ContractParts.GetEnvelope(ContractType()); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin Target := ContractParts.GetTarget(ContractType()); exit(Target.Count() > 0); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin Parameters := ContractParts.GetParameters(ContractType()); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean begin Response := ContractParts.GetResponse(ContractType()); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean begin Errors := ContractParts.GetErrors(ContractType()); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean begin Effect := ContractParts.GetEffect(ContractType()); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean begin Related := ContractParts.GetRelated(ContractType()); exit(Related.Count() > 0); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin Clear(Overview); exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin Clear(Notes); exit(false); end;
    local procedure ContractType(): Text begin exit('Subscription.Contract.UpdateExchangeRates'); end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        ConHelp: Codeunit "Sub Con Help ori";
    begin
        Argument.SetResponseMarkdown(ConHelp.GetHelpMarkdown('Subscription.Contract.UpdateExchangeRates'));
    end;

    /// <summary>Always responds with a structured error - see the class summary for why this message type cannot write.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotSupportedErr);
    end;
}
