namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.PriceUpdate.SetTemplateFilter</c>, <c>Subscription.PriceUpdate.CreateProposal</c> and <c>Subscription.PriceUpdate.Perform</c> Bifrost message types.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035069 "Sub PU Help ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the Markdown help document for the given message key. Returns an empty
    /// text when the key is not one of the message types covered by this codeunit.
    /// </summary>
    procedure GetHelpMarkdown(MessageKey: Text): Text
    var
        HelpBuilder: TextBuilder;
    begin
        case MessageKey of
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    HelpBuilder.AppendLine('# Subscription.PriceUpdate.SetTemplateFilter');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Writes one of the three view filters stored on a Price Update Template (table 8003):');
                    HelpBuilder.AppendLine('the Subscription Contract filter, the Subscription filter, or the Subscription Line filter.');
                    HelpBuilder.AppendLine('Each is kept as a Blob holding a standard Business Central view string. The supplied');
                    HelpBuilder.AppendLine('filter is normalised through a RecordRef on the matching table before it is stored, so it');
                    HelpBuilder.AppendLine('is saved in the platform''s own canonical syntax - the same text the "Contract Price');
                    HelpBuilder.AppendLine('Update" page would store from the filter editor. For the contract filter, the target table');
                    HelpBuilder.AppendLine('depends on the template''s own Partner field: Customer Subscription Contract when the');
                    HelpBuilder.AppendLine('template''s Partner is Customer, otherwise Vendor Subscription Contract.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| priceUpdateTemplateCode | Code[20] | Yes | The Price Update Template to update. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| filter | Text | Yes | A view string, for example `WHERE(Subscription Contract No.=FILTER(CC000010))`, or a full `SORTING(...) WHERE(...)` view. |');
                    HelpBuilder.AppendLine('| target | Text | Yes | One of `contract`, `subscription` or `line`, case-insensitive. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "priceUpdateTemplateCode": "ANNUAL",');
                    HelpBuilder.AppendLine('  "target": "contract",');
                    HelpBuilder.AppendLine('  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "priceUpdateTemplateCode": "ANNUAL",');
                    HelpBuilder.AppendLine('  "target": "contract",');
                    HelpBuilder.AppendLine('  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))",');
                    HelpBuilder.AppendLine('  "filters": {');
                    HelpBuilder.AppendLine('    "contract": "WHERE(Subscription Contract No.=FILTER(CC000010))",');
                    HelpBuilder.AppendLine('    "subscription": "",');
                    HelpBuilder.AppendLine('    "line": ""');
                    HelpBuilder.AppendLine('  }');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`filter` echoes back the normalised view that was written for `target`. `filters` always');
                    HelpBuilder.AppendLine('reports the current value of all three filters after the write, so a caller can confirm');
                    HelpBuilder.AppendLine('the other two were left untouched. An empty string means no filter is set.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The template does not exist | The Price Update Template ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| target is not contract, subscription or line | The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''. |');
                    HelpBuilder.AppendLine('| filter is not a valid view for the target table | Raised by the platform''s own filter parser and reported as-is. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes only the named filter Blob on the template record itself - it');
                    HelpBuilder.AppendLine('never touches contracts, subscriptions or lines. The write runs in an isolated transaction');
                    HelpBuilder.AppendLine('that rolls back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.CreateProposal`');
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.Perform`');
                end;
            'Subscription.PriceUpdate.CreateProposal':
                begin
                    HelpBuilder.AppendLine('# Subscription.PriceUpdate.CreateProposal');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('**This message type is blocked.** It always returns an error and writes nothing.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Creating a price update proposal in Business Central 28.4 requires');
                    HelpBuilder.AppendLine('`Codeunit "Price Update Management".CreatePriceUpdateProposal`, which Microsoft has marked');
                    HelpBuilder.AppendLine('`internal`. The entire `Interface "Contract Price Update"` that carries out the actual');
                    HelpBuilder.AppendLine('rate calculation, and every implementation of it, is also internal, and the worker');
                    HelpBuilder.AppendLine('codeunit 8013 "Process Price Update" is declared `Access = Internal` at the object level.');
                    HelpBuilder.AppendLine('None of this is reachable from an external app, so there is genuinely no supported public');
                    HelpBuilder.AppendLine('path to create the proposal from code.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This codeunit does not attempt to re-implement Microsoft''s price update logic. Doing so');
                    HelpBuilder.AppendLine('would risk silently diverging from Microsoft''s own rounding, currency and binding-period');
                    HelpBuilder.AppendLine('rules and could mis-price live customer contracts - a clear error is safer than a guess.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| (none) | | | This message type takes no parameters. It always fails. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Error",');
                    HelpBuilder.AppendLine('  "error": "Subscription.PriceUpdate.CreateProposal cannot run: ...",');
                    HelpBuilder.AppendLine('  "callstack": "..."');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| Always | Subscription.PriceUpdate.CreateProposal cannot run: Codeunit "Price Update Management".CreatePriceUpdateProposal is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to create the proposal, or call Subscription.PriceUpdate.SetTemplateFilter first to prepare the template''s filters. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type never writes. It is registered and enabled so that discovery and help');
                    HelpBuilder.AppendLine('tooling can list it, but every call fails fast with a specific, actionable error rather');
                    HelpBuilder.AppendLine('than attempting an unsupported workaround.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.SetTemplateFilter`');
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.Perform`');
                end;
            'Subscription.PriceUpdate.Perform':
                begin
                    HelpBuilder.AppendLine('# Subscription.PriceUpdate.Perform');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('**This message type is blocked.** It always returns an error and writes nothing.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Applying a price update proposal in Business Central 28.4 requires');
                    HelpBuilder.AppendLine('`Codeunit "Price Update Management".PerformPriceUpdate`, which Microsoft has marked');
                    HelpBuilder.AppendLine('`internal`, and its worker codeunit 8013 "Process Price Update" is declared');
                    HelpBuilder.AppendLine('`Access = Internal` at the object level. Neither is reachable from an external app, so');
                    HelpBuilder.AppendLine('there is genuinely no supported public path to perform the update from code.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Even a hypothetical public version would need care: Microsoft''s PerformPriceUpdate');
                    HelpBuilder.AppendLine('processes every row standing in the price update proposal table across *all* templates,');
                    HelpBuilder.AppendLine('with no template or contract filter of its own - the filtering happens earlier, when the');
                    HelpBuilder.AppendLine('proposal is created. A caller who expects "perform" to be scoped to one template would be');
                    HelpBuilder.AppendLine('surprised by that behaviour, which is one more reason this codeunit does not attempt a');
                    HelpBuilder.AppendLine('workaround: doing so would risk applying price changes to contracts the caller never');
                    HelpBuilder.AppendLine('intended to touch.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| (none) | | | This message type takes no parameters. It always fails. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Error",');
                    HelpBuilder.AppendLine('  "error": "Subscription.PriceUpdate.Perform cannot run: ...",');
                    HelpBuilder.AppendLine('  "callstack": "..."');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| Always | Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to perform the price update. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type never writes. It is registered and enabled so that discovery and help');
                    HelpBuilder.AppendLine('tooling can list it, but every call fails fast with a specific, actionable error rather');
                    HelpBuilder.AppendLine('than attempting an unsupported workaround that could corrupt customer contracts.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.SetTemplateFilter`');
                    HelpBuilder.AppendLine('- `Subscription.PriceUpdate.CreateProposal`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
