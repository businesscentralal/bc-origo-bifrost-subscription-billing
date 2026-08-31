namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Registers the <c>Subscription.Contract.UpdateExchangeRates</c> Cloud Event message type, and
/// always responds with a structured error. Recalculating a contract's foreign-currency service
/// commitment amounts - the action labelled "Update Exchange Rates" in the client - is performed
/// by <c>Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData()</c>,
/// which is <c>internal</c> in Microsoft's app. Even if it were public, the underlying flow opens
/// the interactive "Exchange Rate Selection" page and, when <c>GuiAllowed</c> is false, that page
/// returns false and the flow proceeds with a zero exchange rate - so calling it unattended would
/// be unsafe even with access, and this message type intentionally never writes.
/// </summary>
codeunit 10035041 "CE Sub Con UpdFCY Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        NotSupportedErr: Label 'Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() is internal to Microsoft''s Subscription Billing app. It also drives the interactive "Exchange Rate Selection" page, which returns false and lets a zero exchange rate through when GuiAllowed is false, so it would be unsafe to call unattended even if it were public. Use the "Update Exchange Rates" action on the contract in the Business Central client instead.', Comment = 'is-IS=Subscription.Contract.UpdateExchangeRates hefur ekkert stutt opinbert forritsskil (API) í þessari útgáfu af Business Central. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() er innri (internal) í Subscription Billing appi Microsoft. Hún keyrir einnig gagnvirku síðuna "Exchange Rate Selection", sem skilar false og hleypir í gegn núll gengi þegar GuiAllowed er false, svo það væri óöruggt að kalla hana án mannlegrar íhlutunar jafnvel þótt hún væri opinber. Notaðu aðgerðina "Update Exchange Rates" á samningnum í Business Central biðlaranum í staðinn.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to recalculate a contract''s exchange rates, and the underlying flow is unsafe unattended. Always returns a structured error.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að endurreikna gengi samnings, og undirliggjandi ferli er óöruggt án mannlegrar íhlutunar. Skilar alltaf skipulagðri villu.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Customer Subscription Contract");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Contract.UpdateExchangeRates');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type is blocked. It is registered so it can be discovered and documented,');
        HelpBuilder.AppendLine('but every call returns an error - nothing is ever written.**');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('In the Business Central client, the "Update Exchange Rates" action on a Customer');
        HelpBuilder.AppendLine('Subscription Contract recalculates the local-currency amounts on the contract''s foreign');
        HelpBuilder.AppendLine('currency Subscription Lines. That action calls');
        HelpBuilder.AppendLine('`Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData()`, which');
        HelpBuilder.AppendLine('is marked `internal` in Microsoft''s Subscription Billing app, so an external app such as');
        HelpBuilder.AppendLine('this one cannot call it.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('There is a second, independent reason this stays blocked even if that procedure were made');
        HelpBuilder.AppendLine('public: the flow it drives opens the interactive "Exchange Rate Selection" page so a user');
        HelpBuilder.AppendLine('can confirm which exchange rate to apply. When `GuiAllowed` is false - as it is for an');
        HelpBuilder.AppendLine('unattended Cloud Event call - that page returns false instead of failing, and the flow');
        HelpBuilder.AppendLine('proceeds by applying a zero exchange rate. Calling it from here would silently zero out');
        HelpBuilder.AppendLine('foreign-currency amounts on the contract, which is worse than not running it at all.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | Accepted for documentation purposes only. May be supplied as the message subject. The call still fails regardless of its value. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "CC000010"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Error",');
        HelpBuilder.AppendLine('  "error": "Subscription.Contract.UpdateExchangeRates has no supported public API...",');
        HelpBuilder.AppendLine('  "callstack": "..."');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| Always | Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version... Use the ''Update Exchange Rates'' action on the contract in the Business Central client instead. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type never writes. It always responds with an error and never reaches the');
        HelpBuilder.AppendLine('isolated write process, so there is nothing to roll back, and no risk of the zero exchange');
        HelpBuilder.AppendLine('rate problem described above ever reaching a real contract through this API.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Contract.UpdateLineDates` (also blocked, for a different reason)');
        HelpBuilder.AppendLine('- `Subscription.Contract.CreateInvoice`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    /// <summary>Always responds with a structured error - see the class summary for why this message type cannot write.</summary>
    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotSupportedErr);
    end;
}
