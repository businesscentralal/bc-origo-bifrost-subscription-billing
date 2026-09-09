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
codeunit 10035041 "Sub Con UpdFCY Impl ori" implements "Msg Interface ori"
{
    var
        NotSupportedErr: Label 'Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() is internal to Microsoft''s Subscription Billing app. It also drives the interactive "Exchange Rate Selection" page, which returns false and lets a zero exchange rate through when GuiAllowed is false, so it would be unsafe to call unattended even if it were public. Use the "Update Exchange Rates" action on the contract in the Business Central client instead.', Comment = 'is-IS=Subscription.Contract.UpdateExchangeRates hefur ekkert stutt opinbert forritsskil (API) í þessari útgáfu af Business Central. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() er innri (internal) í Subscription Billing-forriti Microsoft. Hún keyrir einnig gagnvirku síðuna "Exchange Rate Selection", sem skilar false og hleypir í gegn núll gengi þegar GuiAllowed er false, svo það væri óöruggt að kalla hana án mannlegrar íhlutunar jafnvel þótt hún væri opinber. Notaðu aðgerðina „Uppfæra gengi“ ("Update Exchange Rates") á samningnum í Business Central biðlaranum í staðinn.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to recalculate a contract''s exchange rates, and the underlying flow is unsafe unattended. Always returns a structured error.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að endurreikna gengi samnings, og undirliggjandi ferli er óöruggt án mannlegrar íhlutunar. Skilar alltaf skipulagðri villu.';

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
