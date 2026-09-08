namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Shared Markdown help text for the <c>Subscription.VendorContract.GetLines</c>, <c>Subscription.VendorContract.CreateInvoice</c> and <c>Subscription.VendorContract.PreviewInvoice</c> Bifrost message types.
/// Consolidating the help text per domain means a future domain-wide formatting change
/// only has to touch this file, instead of every Impl codeunit in the domain.
/// </summary>
codeunit 10035067 "Sub Vend Help ori"
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
            'Subscription.VendorContract.GetLines':
                begin
                    HelpBuilder.AppendLine('# Subscription.VendorContract.GetLines');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Finds Subscription Lines (table 8059) that are invoiced via a contract, belong to the vendor');
                    HelpBuilder.AppendLine('partner, are not yet linked to any Vendor Subscription Contract, and have not already ended,');
                    HelpBuilder.AppendLine('then attaches each one to the given Vendor Subscription Contract. Attaching a line creates a');
                    HelpBuilder.AppendLine('matching Vend. Sub. Contract Line (table 8065) for it. Because Microsoft only exposes the');
                    HelpBuilder.AppendLine('single-line attach procedure to external apps, this call loops it once per candidate line.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Vendor Subscription Contract to attach lines to. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | No | Restrict candidate lines to this Subscription Header. |');
                    HelpBuilder.AppendLine('| subscriptionLineEntryNos | Array of Integer | No | Restrict to these exact Subscription Line entry numbers. Omit to attach every eligible line. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('A candidate line has ''Invoicing via'' = Contract, Partner = Vendor, no Subscription Contract No.');
                    HelpBuilder.AppendLine('yet, and a Subscription Line End Date that is either blank or after the work date.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000045",');
                    HelpBuilder.AppendLine('  "subscriptionLineEntryNos": [101, 102]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "linesAttached": 2,');
                    HelpBuilder.AppendLine('  "attachedLines": [');
                    HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 101, "contractLineNo": 10000 },');
                    HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 102, "contractLineNo": 20000 }');
                    HelpBuilder.AppendLine('  ]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('A run that matches no candidate line is a success with `linesAttached` of 0 and an empty array.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| contractNo is missing | The request is missing the required parameter ''contractNo''. |');
                    HelpBuilder.AppendLine('| subscriptionLineEntryNos is present but is not an array | The parameter ''subscriptionLineEntryNos'' must be a JSON array. |');
                    HelpBuilder.AppendLine('| subscriptionLineEntryNos holds something other than integers | The parameter ''subscriptionLineEntryNos'' must be a JSON array of integers. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes. It only attaches already-existing Subscription Lines to a contract -');
                    HelpBuilder.AppendLine('it never creates or deletes a Subscription Line. The write runs in an isolated transaction that');
                    HelpBuilder.AppendLine('rolls back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.CreateInvoice`');
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.PreviewInvoice`');
                end;
            'Subscription.VendorContract.CreateInvoice':
                begin
                    HelpBuilder.AppendLine('# Subscription.VendorContract.CreateInvoice');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Bills the due Subscription Lines of one Vendor Subscription Contract. The lines whose next');
                    HelpBuilder.AppendLine('billing date falls on or before the billing date are copied into an ad-hoc billing proposal');
                    HelpBuilder.AppendLine('(Billing Line rows with a blank Billing Template Code), and that proposal is then turned into');
                    HelpBuilder.AppendLine('an unposted purchase document. Nothing is posted by this call - post the resulting document');
                    HelpBuilder.AppendLine('separately once it has been reviewed.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Vendor Subscription Contract to bill. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| billingDate | Date | No | Lines due on or before this date are billed. Defaults to the work date. |');
                    HelpBuilder.AppendLine('| billingToDate | Date | No | Bills complete periods up to this date. Omit to use each line''s own billing rhythm. |');
                    HelpBuilder.AppendLine('| documentDate | Date | No | Document date stamped on the created document. Defaults to the work date. |');
                    HelpBuilder.AppendLine('| postingDate | Date | No | Posting date stamped on the created document. Defaults to the work date. |');
                    HelpBuilder.AppendLine('| vendorInvoiceNo | Text | No | When supplied, stamped onto the ''Vendor Invoice No.'' field of every document created by this call. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "vendorInvoiceNo": "INV-2026-0912"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "billingLineCount": 3,');
                    HelpBuilder.AppendLine('  "documents": [');
                    HelpBuilder.AppendLine('    { "documentType": "Invoice", "documentNo": "PINV-000123" }');
                    HelpBuilder.AppendLine('  ]');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('`billingLineCount` is the number of Subscription Lines that were due and billed. A run that');
                    HelpBuilder.AppendLine('finds nothing due is a success with `billingLineCount` of 0 and an empty `documents` array.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| contractNo is missing | The request is missing the required parameter ''contractNo''. |');
                    HelpBuilder.AppendLine('| Another contract has an unfinished ad-hoc proposal | There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before creating an invoice for ''%3''. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('This message type writes, but it never posts. The billing proposal it builds is an ad-hoc,');
                    HelpBuilder.AppendLine('blank-template proposal shared by the whole company, so this call first checks that no such');
                    HelpBuilder.AppendLine('proposal lines are left standing for a different contract, and fails rather than sweep up');
                    HelpBuilder.AppendLine('someone else''s pending run. Only one partner type is ever billed by this call. Because');
                    HelpBuilder.AppendLine('Microsoft''s purchase document creation ignores any post flag, the result is always an');
                    HelpBuilder.AppendLine('unposted purchase document that must be posted separately. The write runs in an isolated');
                    HelpBuilder.AppendLine('transaction that rolls back on error.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.PreviewInvoice`');
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.GetLines`');
                    HelpBuilder.AppendLine('- `Subscription.Billing.CreateDocuments`');
                end;
            'Subscription.VendorContract.PreviewInvoice':
                begin
                    HelpBuilder.AppendLine('# Subscription.VendorContract.PreviewInvoice');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Overview');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Shows what `Subscription.VendorContract.CreateInvoice` would bill for a vendor subscription');
                    HelpBuilder.AppendLine('contract, without keeping anything and without ever creating a document. The due');
                    HelpBuilder.AppendLine('Subscription Lines are handed to the same ad-hoc billing proposal entry point the write');
                    HelpBuilder.AppendLine('call uses, so the reported lines, periods and amounts reflect what Business Central would');
                    HelpBuilder.AppendLine('actually produce. The proposal rows built for the preview are read and then deleted again.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Parameters');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
                    HelpBuilder.AppendLine('| --- | --- | --- | --- |');
                    HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Vendor Subscription Contract to preview. May also be supplied as the message subject. |');
                    HelpBuilder.AppendLine('| billingDate | Date | No | Lines due on or before this date are billed. Defaults to the work date. |');
                    HelpBuilder.AppendLine('| billingToDate | Date | No | Bills complete periods up to this date. Omit to use each line''s own billing rhythm. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`. There are no `documentDate`, `postingDate` or');
                    HelpBuilder.AppendLine('`vendorInvoiceNo` parameters - a preview never creates a document, so nothing about the');
                    HelpBuilder.AppendLine('document applies.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Request Example');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "billingDate": "2026-08-31"');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Response Shape');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('```json');
                    HelpBuilder.AppendLine('{');
                    HelpBuilder.AppendLine('  "status": "Success",');
                    HelpBuilder.AppendLine('  "contractNo": "VC000010",');
                    HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
                    HelpBuilder.AppendLine('  "lines": [');
                    HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 2001, "billingFrom": "2026-08-01", "billingTo": "2026-08-31", "unitPrice": "49.00", "amount": "49.00" }');
                    HelpBuilder.AppendLine('  ],');
                    HelpBuilder.AppendLine('  "wouldBillLineCount": 1,');
                    HelpBuilder.AppendLine('  "totalAmount": "49.00",');
                    HelpBuilder.AppendLine('  "preview": true,');
                    HelpBuilder.AppendLine('  "rollback": true');
                    HelpBuilder.AppendLine('}');
                    HelpBuilder.AppendLine('```');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('A run that finds nothing due is a success with `wouldBillLineCount` of 0 and an empty `lines`');
                    HelpBuilder.AppendLine('array; `preview` and `rollback` are still `true`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Errors');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('| Condition | Message |');
                    HelpBuilder.AppendLine('| --- | --- |');
                    HelpBuilder.AppendLine('| The contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
                    HelpBuilder.AppendLine('| contractNo is missing | The request is missing the required parameter ''contractNo''. |');
                    HelpBuilder.AppendLine('| Another contract has an unfinished ad-hoc proposal | There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before previewing ''%3''. |');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }`.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Safety');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('Nothing is left behind, but this is not a rolled-back transaction: Microsoft''s billing');
                    HelpBuilder.AppendLine('proposal codeunit commits internally partway through its own run, so an ordinary error-based');
                    HelpBuilder.AppendLine('rollback would not undo it. Instead, this call notes the last Billing Line entry number');
                    HelpBuilder.AppendLine('before it does anything, builds the real proposal lines for the contract''s due Subscription');
                    HelpBuilder.AppendLine('Lines with that same entry point, reads back exactly the rows it just created, and then');
                    HelpBuilder.AppendLine('deletes exactly those rows again - on both the success path and if the proposal call itself');
                    HelpBuilder.AppendLine('fails partway through. No document is ever created, even temporarily: this call never');
                    HelpBuilder.AppendLine('reaches the step that turns proposal lines into a purchase document.');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('## Related Message Types');
                    HelpBuilder.AppendLine();
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.CreateInvoice`');
                    HelpBuilder.AppendLine('- `Subscription.VendorContract.GetLines`');
                end;
            else
                exit('');
        end;
        exit(HelpBuilder.ToText());
    end;
}
