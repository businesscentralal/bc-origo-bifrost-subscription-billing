namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Line.Create</c> Bifrost message type.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035065 "Sub Line Help ori"
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
            'Subscription.Line.Create':
                begin
                    HelpBuilder.AppendLine('# Subscription.Line.Create');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Creates Subscription Lines (table 8059) on an existing Subscription Header by applying a');
                    HelpBuilder.AppendLine('Subscription Package. Every package line becomes a Subscription Line, with prices, billing');
                    HelpBuilder.AppendLine('rhythm and dates derived by Microsoft''s own package application logic - the same logic the');
                    HelpBuilder.AppendLine('Subscription Header page uses when a package is applied from the client.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | Yes | The Subscription Header to add lines to. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| subscriptionPackageCode | Code[20] | Yes | The Subscription Package to apply. |');
                    HelpBuilder.AppendLine('| subscriptionLineStartDate | Date | No | Start date for the new lines. Omit, or send 0001-01-01, to let the package''s own formula decide. |');
                    HelpBuilder.AppendLine('| subscriptionLineEndDate | Date | No | End date for the new lines. Omit to leave the lines open ended. |');
                    HelpBuilder.AppendLine('| usageBasedBillingPackageLinesOnly | Boolean | No | When true, only the package''s usage based lines are created. Defaults to false. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SUB000010",');
                    HelpBuilder.AppendLine('  "subscriptionPackageCode": "STANDARD",');
                    HelpBuilder.AppendLine('  "subscriptionLineStartDate": "2026-09-01"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SUB000010",');
                    HelpBuilder.AppendLine('  "subscriptionPackageCode": "STANDARD",');
                    HelpBuilder.AppendLine('  "linesCreated": 3,');
                    HelpBuilder.AppendLine('  "createdLines": [1001, 1002, 1003]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`createdLines` holds the `Entry No.` of every Subscription Line this call added. A package');
                    HelpBuilder.AppendLine('that adds nothing - for example because every line is filtered out by');
                    HelpBuilder.AppendLine('`usageBasedBillingPackageLinesOnly` - is still a success, with `linesCreated` of 0.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The Subscription Header does not exist | The Subscription Header ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| The header has no Source No. | Standard TestField error naming ''Source No.''. |');
                    HelpBuilder.AppendLine('| The Subscription Package does not exist | The Subscription Package ''%1'' does not exist. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes. Only Subscription Lines under the given header are created - no');
                    HelpBuilder.AppendLine('contract is touched and nothing is billed. The write runs in an isolated transaction that');
                    HelpBuilder.AppendLine('rolls back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Contract.GetLines`');
                    HelpBuilder.AppendLine('- `Subscription.Contract.CreateInvoice`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
