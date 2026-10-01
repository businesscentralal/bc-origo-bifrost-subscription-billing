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
codeunit 10035040 "Sub Con UpdDates Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        NotSupportedErr: Label 'Subscription.Contract.UpdateLineDates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() and codeunit 8058 "Update Sub. Lines Term. Dates" are all internal to Microsoft''s Subscription Billing app and cannot be called from this extension. Run the "Update Subscription Line Dates" action on the contract in the Business Central client instead, or schedule Microsoft''s own job queue entry for the batch job that does this in bulk.', Comment = 'is-IS=Subscription.Contract.UpdateLineDates hefur ekkert stutt opinbert API í þessari útgáfu af Business Central. Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() og codeunit 8058 "Update Sub. Lines Term. Dates" eru öll innri í Subscription Billing-forriti Microsoft og því ekki hægt að kalla þau úr þessu appi. Keyrðu aðgerðina „Uppfæra dagsetningar áskriftarlína“ ("Update Subscription Line Dates") á samningnum í Business Central-biðlaranum í staðinn, eða settu upp vinnsluraðarfærslu Microsoft sjálfs fyrir hópkeyrsluna sem gerir þetta í lotum.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to roll a contract''s Subscription Line dates forward. Always returns a structured error naming the internal procedures involved.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert API aðgengilegt til að færa dagsetningar áskriftarlína samnings áfram. Skilar alltaf skipulagðri villu sem nefnir þau innri ferli sem við eiga.';

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

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Contract.UpdateLineDates, Subscription, Contract, UpdateLineDates, customer, dates', Comment = 'is-IS=Subscription.Contract.UpdateLineDates, áskrift, samningur, uppfæra línudagsetningar, viðskiptavinur, dagsetningar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Contract.UpdateLineDates: Recalculates customer contract line dates. Irreversible.', Comment = 'is-IS=Subscription.Contract.UpdateLineDates: Endurreiknar dagsetningar lína í viðskiptasamningi. Óafturkræf aðgerð.';
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
        Overview := 'Blocked. In the client, Update Subscription Line Dates on a Customer Subscription Contract rolls the term dates of its Subscription Lines forward. ' +
            'That action uses Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() and codeunit 8058 Update Sub. Lines ' +
            'Term. Dates, all internal to Microsoft''s app.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ContractParts.BlockedNote() +
            'Re-implementing the date rollover was rejected: term dates, billing rhythms and renewal interact in ways that are easy to get wrong, and a diverging ' +
            'copy could corrupt contracts unnoticed.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.UpdateLineDates');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Always responds with a structured error - see the class summary for why this message type cannot write.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotSupportedErr);
    end;
}
