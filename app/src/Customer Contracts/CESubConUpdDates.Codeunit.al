namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Registers the <c>Subscription.Contract.UpdateLineDates</c> Cloud Event message type, and
/// always responds with a structured error. Rolling a contract's Subscription Line dates
/// forward - the action labelled "Update Subscription Line Dates" in the client - is performed
/// by <c>Customer Subscription Contract.UpdateServicesDates()</c> and
/// <c>Subscription Header.UpdateServicesDates()</c>, both <c>internal</c> in Microsoft's app, and
/// by codeunit 8058 "Update Sub. Lines Term. Dates", which is <c>Access = Internal</c>. None of
/// these can be called from this app, and re-implementing the date rollover and term-date
/// business logic here would risk silently diverging from Microsoft's own rules and corrupting
/// customer contracts, so this message type intentionally never writes.
/// </summary>
codeunit 10035040 "CE Sub Con UpdDates Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        NotSupportedErr: Label 'Subscription.Contract.UpdateLineDates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() and codeunit 8058 "Update Sub. Lines Term. Dates" are all internal to Microsoft''s Subscription Billing app and cannot be called from this extension. Run the "Update Subscription Line Dates" action on the contract in the Business Central client instead, or schedule Microsoft''s own job queue entry for the batch job that does this in bulk.', Comment = 'is-IS=Subscription.Contract.UpdateLineDates hefur ekkert stutt opinbert forritsskil (API) í þessari útgáfu af Business Central. Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() og kóðaeiningin 8058 "Update Sub. Lines Term. Dates" eru allar innri (internal) í Subscription Billing appi Microsoft og því ekki hægt að kalla þær úr þessu appi. Keyrðu aðgerðina "Update Subscription Line Dates" á samningnum í Business Central biðlaranum í staðinn, eða settu upp verkbeiðslufærslu (job queue entry) Microsoft sjálfs fyrir hópkeyrsluna sem gerir þetta í lotum.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to roll a contract''s Subscription Line dates forward. Always returns a structured error naming the internal procedures involved.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að færa áskriftarlínudagsetningar samnings áfram. Skilar alltaf skipulagðri villu sem nefnir þau innri ferli sem við eiga.';

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
        HelpBuilder.AppendLine('# Subscription.Contract.UpdateLineDates');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type is blocked. It is registered so it can be discovered and documented,');
        HelpBuilder.AppendLine('but every call returns an error - nothing is ever written.**');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('In the Business Central client, the "Update Subscription Line Dates" action on a Customer');
        HelpBuilder.AppendLine('Subscription Contract rolls forward the term start and end dates on the contract''s');
        HelpBuilder.AppendLine('Subscription Lines. That action calls');
        HelpBuilder.AppendLine('`Customer Subscription Contract.UpdateServicesDates()`, which in turn calls');
        HelpBuilder.AppendLine('`Subscription Header.UpdateServicesDates()` and codeunit 8058');
        HelpBuilder.AppendLine('"Update Sub. Lines Term. Dates". All three are marked `internal` (the codeunit is');
        HelpBuilder.AppendLine('`Access = Internal`) in Microsoft''s Subscription Billing app, so an external app such as');
        HelpBuilder.AppendLine('this one cannot call them, and there is no other supported route to the same result.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Re-implementing the date rollover logic independently was considered and rejected: the');
        HelpBuilder.AppendLine('rules for term dates, billing rhythms and renewal interact in ways that are easy to get');
        HelpBuilder.AppendLine('subtly wrong, and a divergent implementation could corrupt customer contracts in a way');
        HelpBuilder.AppendLine('that is hard to detect and hard to undo.');
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
        HelpBuilder.AppendLine('  "error": "Subscription.Contract.UpdateLineDates has no supported public API...",');
        HelpBuilder.AppendLine('  "callstack": "..."');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| Always | Subscription.Contract.UpdateLineDates has no supported public API in this Business Central version... Run the ''Update Subscription Line Dates'' action on the contract in the Business Central client instead, or schedule Microsoft''s own job queue entry for the batch job that does this in bulk. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type never writes. It always responds with an error and never reaches the');
        HelpBuilder.AppendLine('isolated write process, so there is nothing to roll back.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Contract.UpdateExchangeRates` (also blocked, for a different reason)');
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
