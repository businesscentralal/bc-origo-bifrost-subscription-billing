namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.Renewal.Extend</c> and <c>Subscription.Renewal.CreateQuote</c> Bifrost message types.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035070 "Sub Ren Help ori"
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
            'Subscription.Renewal.Extend':
                begin
                    HelpBuilder.AppendLine('# Subscription.Renewal.Extend');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Extends an existing Subscription (table 8057) onto a customer and/or vendor contract by');
                    HelpBuilder.AppendLine('running Microsoft''s `Codeunit "Extend Sub. Contract Mgt."`. The Subscription must already');
                    HelpBuilder.AppendLine('exist - this message type does not create one. The item''s own standard service commitment');
                    HelpBuilder.AppendLine('packages are always applied by Microsoft''s codeunit; `subscriptionPackageCodes` only adds');
                    HelpBuilder.AppendLine('further packages beyond those standard ones.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | Yes | The Subscription to extend. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| customerContractNo | Code[20] | No | An existing Customer Subscription Contract to extend onto. |');
                    HelpBuilder.AppendLine('| vendorContractNo | Code[20] | No | An existing Vendor Subscription Contract to extend onto. |');
                    HelpBuilder.AppendLine('| subscriptionPackageCodes | Array of Code[20] | No | Extra Subscription Package codes to apply beyond the item''s standard packages. |');
                    HelpBuilder.AppendLine('| usageBasedBillingPackageLinesOnly | Boolean | No | Defaults to false. When true, only usage based billing package lines are added. |');
                    HelpBuilder.AppendLine('| supplierReferenceEntryNo | Integer | No | Defaults to 0. Links the extension to a specific supplier reference Subscription Line entry. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('At least one of `customerContractNo` or `vendorContractNo` is required.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000010",');
                    HelpBuilder.AppendLine('  "customerContractNo": "CC000010",');
                    HelpBuilder.AppendLine('  "subscriptionPackageCodes": ["SUPPORT"]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000010",');
                    HelpBuilder.AppendLine('  "customerContractNo": "CC000010",');
                    HelpBuilder.AppendLine('  "custContractLineCountBefore": 3,');
                    HelpBuilder.AppendLine('  "custContractLineCountAfter": 5,');
                    HelpBuilder.AppendLine('  "custContractLinesCreated": 2,');
                    HelpBuilder.AppendLine('  "newSubscriptionLineEntryNos": [1044, 1045],');
                    HelpBuilder.AppendLine('  "newSubscriptionLineCount": 2');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`custContractLine*`/`vendContractLine*` fields are only present for the side that was');
                    HelpBuilder.AppendLine('extended. `newSubscriptionLineEntryNos` lists the Subscription Line entries this call');
                    HelpBuilder.AppendLine('added to the Subscription, regardless of which contract side they were linked to.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The subscription does not exist | The Subscription ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| The customer contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| The vendor contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| A package code does not exist | The Subscription Package ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| Neither contract number was supplied | The request must supply at least one of ''customerContractNo'' or ''vendorContractNo''. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes: it inserts Subscription Lines and Cust./Vend. Sub. Contract');
                    HelpBuilder.AppendLine('Line records. The write runs in an isolated transaction that rolls back on error, and');
                    HelpBuilder.AppendLine('Microsoft''s completion dialog is suppressed so the call never blocks on user input.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Renewal.CreateQuote`');
                end;
            'Subscription.Renewal.CreateQuote':
                begin
                    HelpBuilder.AppendLine('# Subscription.Renewal.CreateQuote');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Creates a contract renewal sales quote for a Customer Subscription Contract. Any stale');
                    HelpBuilder.AppendLine('renewal lines left over from an earlier run against this contract are deleted first, then');
                    HelpBuilder.AppendLine('a fresh Sub. Contract Renewal Line row is built from every still-open Subscription Line');
                    HelpBuilder.AppendLine('on the contract, and Microsoft''s `Codeunit "Create Sub. Contract Renewal"` turns those');
                    HelpBuilder.AppendLine('rows into one sales quote. This bypasses Microsoft''s interactive renewal wrapper entirely,');
                    HelpBuilder.AppendLine('so it never shows a dialog or a request page.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Customer Subscription Contract to renew. May also be supplied as the message subject. |');
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
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "contractNo": "CC000010",');
                    HelpBuilder.AppendLine('  "renewalLinesCreated": 4,');
                    HelpBuilder.AppendLine('  "salesQuoteNo": "SQ000123"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| No Subscription Line qualifies for renewal | The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed. |');
                    HelpBuilder.AppendLine('| Create Sub. Contract Renewal produced no quote | Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes: it deletes and re-creates Sub. Contract Renewal Line rows for');
                    HelpBuilder.AppendLine('this contract, and it creates a sales quote header and lines. It never posts anything and');
                    HelpBuilder.AppendLine('never touches the contract itself. The write runs in an isolated transaction that rolls');
                    HelpBuilder.AppendLine('back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.Renewal.Extend`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
