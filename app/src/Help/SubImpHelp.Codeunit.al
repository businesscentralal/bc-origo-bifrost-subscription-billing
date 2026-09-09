namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Import.CreateContracts</c> Bifrost message type.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035074 "Sub Imp Help ori"
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
            'Subscription.Import.CreateContracts':
                begin
                    HelpBuilder.AppendLine('# Subscription.Import.CreateContracts');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Turns staged import rows - Imported Subscription Header (table 8008), Imported Cust. Sub.');
                    HelpBuilder.AppendLine('Contract (table 8010) and Imported Subscription Line (table 8009) - into real Subscription');
                    HelpBuilder.AppendLine('Header, Customer Subscription Contract, Subscription Line and Cust. Sub. Contract Line');
                    HelpBuilder.AppendLine('records. The four stages run in a fixed order - headers, then contracts, then lines, then');
                    HelpBuilder.AppendLine('contract lines - because each later stage needs the keys the earlier stages wrote back onto');
                    HelpBuilder.AppendLine('the staging rows. Only unprocessed rows are picked up: each stage filters to its own');
                    HelpBuilder.AppendLine('''created'' flag being false, so calling this again only processes what is still outstanding.');
                    HelpBuilder.AppendLine('One bad row does not stop the batch - its error is recorded on the staging row and the next');
                    HelpBuilder.AppendLine('row is still attempted.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| stages | Array of Text | No | Which stages to run, in any subset of SubscriptionHeaders, CustomerContracts, SubscriptionLines, ContractLines. Defaults to all four, always executed in that fixed order regardless of the order given. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "stages": ["SubscriptionHeaders", "CustomerContracts", "SubscriptionLines", "ContractLines"]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "stages": [');
                    HelpBuilder.AppendLine('    { "stage": "SubscriptionHeaders", "processed": 5, "succeeded": 5, "failed": 0 },');
                    HelpBuilder.AppendLine('    { "stage": "CustomerContracts", "processed": 5, "succeeded": 4, "failed": 1 },');
                    HelpBuilder.AppendLine('    { "stage": "SubscriptionLines", "processed": 5, "succeeded": 5, "failed": 0 },');
                    HelpBuilder.AppendLine('    { "stage": "ContractLines", "processed": 5, "succeeded": 4, "failed": 1 }');
                    HelpBuilder.AppendLine('  ],');
                    HelpBuilder.AppendLine('  "errors": [');
                    HelpBuilder.AppendLine('    { "stage": "CustomerContracts", "key": "12", "error": "..." }');
                    HelpBuilder.AppendLine('  ]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`processed` is the number of unprocessed rows the stage found; `succeeded` and `failed` split');
                    HelpBuilder.AppendLine('that count. `key` in `errors` is the staging row''s Entry No.. The `errors` array is capped at');
                    HelpBuilder.AppendLine('the first 50 entries across all stages - a failed row past that cap is still counted in');
                    HelpBuilder.AppendLine('`failed` but its detail is not listed; check the staging table in the client for the rest.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| An unknown stage name is given | ''%1'' is not a known import stage. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('A row failing to create its Subscription record is not itself a call error - it is reported');
                    HelpBuilder.AppendLine('inside `stages` and `errors` instead, and the call still returns `"status": "Success"`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes. It creates new Subscription Header, Customer Subscription Contract,');
                    HelpBuilder.AppendLine('Subscription Line and Cust. Sub. Contract Line records from staging rows already present in');
                    HelpBuilder.AppendLine('the database; it does not post anything. Each staging row is committed independently as it');
                    HelpBuilder.AppendLine('is processed, so a failure partway through leaves earlier rows'' results in place - this call');
                    HelpBuilder.AppendLine('cannot be rolled back as a whole once it has started.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Line.Create`');
                    HelpBuilder.AppendLine('- `Subscription.Contract.GetLines`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
