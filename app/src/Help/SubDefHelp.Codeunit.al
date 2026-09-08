namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Deferral.Release</c> Bifrost message type.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035072 "Sub Def Help ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the Markdown help document for the given message key. Returns an empty
    /// text when the key is not one of the message types covered by this codeunit.
    /// </summary>
    internal procedure GetHelpMarkdown(MessageKey: Text): Text
    var
        HelpBuilder: TextBuilder;
    begin
        case MessageKey of
            'Subscription.Deferral.Release':
                begin
                    HelpBuilder.AppendLine('# Subscription.Deferral.Release');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Runs Microsoft''s "Contract Deferrals Release" report, which releases every eligible deferred');
                    HelpBuilder.AppendLine('revenue and cost entry - customer (table 8066) and vendor (table 8072) - and posts the');
                    HelpBuilder.AppendLine('release to the general ledger.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('**The report always uses the session work date.** Its two dates live on its request page,');
                    HelpBuilder.AppendLine('`SetRequestPageParameters` is internal to Microsoft''s app, and request page XML is not');
                    HelpBuilder.AppendLine('applied to this report, so an external app cannot tell it where to stop. It releases');
                    HelpBuilder.AppendLine('everything eligible up to the work date, posted under the work date.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`postingDate` and `postUntilDate` are therefore **not instructions - they are a guard**. This');
                    HelpBuilder.AppendLine('call checks what the report is about to do and refuses to run when that is more than the');
                    HelpBuilder.AppendLine('caller asked for, rather than posting to the general ledger and reporting a number that does');
                    HelpBuilder.AppendLine('not match what happened. To release up to an earlier date, set the session work date first.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| postingDate | Date | No | The date the caller expects the release to post under. Must equal the work date, because that is the only date Business Central will use. Defaults to the work date. |');
                    HelpBuilder.AppendLine('| postUntilDate | Date | No | The latest deferral posting date the caller is willing to release. The call is refused if the report would go past it. Defaults to postingDate. Must not be later than postingDate. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "postingDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "postUntilDate": "2026-08-31"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "postingDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "postUntilDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "customerDeferralsReleased": 8,');
                    HelpBuilder.AppendLine('  "vendorDeferralsReleased": 3,');
                    HelpBuilder.AppendLine('  "totalDeferralsReleased": 11');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('The counts are measured across **every** unreleased deferral, not only the ones inside the');
                    HelpBuilder.AppendLine('requested window, so they say what the run actually released. A run that finds nothing');
                    HelpBuilder.AppendLine('eligible is still a success, with every count at 0.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('If anything outside the window is released anyway, the response carries');
                    HelpBuilder.AppendLine('`releasedOutsideRequestedWindow` and a `warning`, so a run that got past the guard is');
                    HelpBuilder.AppendLine('still visible in the response rather than only in the ledger.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| postUntilDate is later than postingDate | The parameter ''postUntilDate'' (%1) must not be later than ''postingDate'' (%2). |');
                    HelpBuilder.AppendLine('| postingDate is not the work date | Business Central posts this release under the work date (%1) ... so ''postingDate'' (%2) cannot be honoured. |');
                    HelpBuilder.AppendLine('| The report would release deferrals past postUntilDate | Refusing to run: Business Central would release %1 deferral(s) posted between ''postUntilDate'' (%2) and the work date (%3). |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is posted.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('**This message type posts to the general ledger and cannot be undone**, except by posting a');
                    HelpBuilder.AppendLine('compensating credit memo through the normal deferral correction process. It is **not scoped**');
                    HelpBuilder.AppendLine('to a single contract - it releases every eligible customer and vendor deferral, across every');
                    HelpBuilder.AppendLine('Subscription Contract, up to the work date. The `postUntilDate` guard is what keeps that from');
                    HelpBuilder.AppendLine('reaching further than the caller intended; it cannot narrow the run, only refuse it. Confirm');
                    HelpBuilder.AppendLine('the work date carefully before calling this in a production environment.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Analysis.Recalculate`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
