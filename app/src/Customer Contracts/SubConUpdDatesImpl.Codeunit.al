namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Registers the <c>Subscription.Contract.UpdateLineDates</c> Bifrost message type, and
/// always responds with a structured error. Rolling a contract's Subscription Line dates
/// forward - the action labelled "Update Subscription Line Dates" in the client - is performed
/// by <c>Customer Subscription Contract.UpdateServicesDates()</c> and
/// <c>Subscription Header.UpdateServicesDates()</c>, both <c>internal</c> in Microsoft's app, and
/// by codeunit 8058 "Update Sub. Lines Term. Dates", which is <c>Access = Internal</c>. None of
/// these can be called from this app, and re-implementing the date rollover and term-date
/// business logic here would risk silently diverging from Microsoft's own rules and corrupting
/// customer contracts, so this message type intentionally never writes.
/// </summary>
codeunit 10035040 "Sub Con UpdDates Impl ori" implements "Msg Interface ori"
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

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        ConHelp: Codeunit "Sub Con Help ori";
    begin
        Argument.SetResponseMarkdown(ConHelp.GetHelpMarkdown('Subscription.Contract.UpdateLineDates'));
    end;

    /// <summary>Always responds with a structured error - see the class summary for why this message type cannot write.</summary>
    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotSupportedErr);
    end;
}
