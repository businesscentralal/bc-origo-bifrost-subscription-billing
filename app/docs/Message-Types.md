# Subscription Billing message types

**App:** Origo Bifrost Subscription Billing
**Version:** 28.0.0.0
**Prepared:** 2026-08-30

## 1. Introduction

This app adds 22 Bifrost message types that let an external agent operate Microsoft
Dynamics 365 Business Central **Subscription Billing** end to end, without a person driving the
client by hand. It does not replace the generic **Origo Bifrost Core** message types -
`Data.Records.Get`, `Data.Records.Set` and the rest still cover plain reads and simple field
writes on any table. This app exists only for the operations a generic record call cannot
perform: applying a Subscription Package with Microsoft's own derivation logic, running a
billing proposal, previewing what a billing run would produce without leaving anything behind,
posting deferral releases, and similar multi-step or Microsoft-codeunit-driven work.

Every message type is named `Subscription.<Domain>.<Action>`, for example
`Subscription.Billing.CreateProposal`. The ten domains are Commitments, Customer Contracts,
Vendor Contracts, Billing Pipeline, Price Updates, Renewal, Usage, Deferrals, Analysis and
Import.

All 22 message types share the same request/response contract, inherited from Origo Cloud
Events Core:

- The request body is a JSON object. Every message type reads it with the same helper
  (`Sub Helper ori`), so parameter parsing is consistent: dates are read and written in the
  ISO format `YYYY-MM-DD` regardless of the caller's locale, decimals use a decimal point, and
  booleans accept `true`/`false`/`1`/`0` (case-insensitive).
- Most message types accept their primary key (a contract number, a subscription number, a
  template code) either as a named JSON property or as the Bifrost message **subject**. The
  named property always wins if both are supplied.
- A successful response is a JSON object with `"status": "Success"` plus the type's own keys.
  A failed call responds with `{"status": "Error", "error": "...", "callstack": "..."}` and
  writes nothing, except where a section below says otherwise.
- Every write-capable message type runs its actual work through a shared isolated-transaction
  wrapper (`Sub Write Process ori`), so a failure partway through a write rolls back cleanly
  rather than leaving half-written records.
- Assign the permission set **Bifrost Sub. Billing** (`BIFROST SubBil ori`) to let a user
  or service invoke these message types, in addition to their Bifrost Core permissions.
  This set only grants execute rights on this app's own objects; it does not widen the caller's
  access to Subscription Billing tables.
- Call `Help.MessageTypes.Get` (Core) to list all registered types, and
  `Help.Implementation.Get` with a type name as the subject to fetch that type's own Markdown
  help document - the same content this reference is built from.

## 2. Summary

Of the 22 message types, 15 write, 3 are read-only previews, and 4 are permanently blocked
because Microsoft has not exposed a public API for the underlying operation in Business
Central 28.4. Blocked types stay registered and discoverable - they exist so tooling can find
them and read why they fail - but every call to one returns a structured error and never
writes anything.

| Message type | Direction | Behaviour | Purpose |
| --- | --- | --- | --- |
| `Subscription.Line.Create` | Inbound | Writes | Applies a Subscription Package to a Subscription, creating Subscription Lines |
| `Subscription.Contract.GetLines` | Inbound | Writes | Attaches unassigned Subscription Lines to a customer contract |
| `Subscription.Contract.CreateInvoice` | Inbound | Writes | Bills a customer contract to an unposted sales invoice |
| `Subscription.Contract.PreviewInvoice` | Inbound | **Preview** | Shows what `Contract.CreateInvoice` would bill, without keeping anything |
| `Subscription.Contract.UpdateLineDates` | Inbound | **Blocked** | Would roll contract line dates forward; no public API exists |
| `Subscription.Contract.UpdateExchangeRates` | Inbound | **Blocked** | Would recalculate FCY amounts; no public API, and the flow is unsafe unattended |
| `Subscription.VendorContract.GetLines` | Inbound | Writes | Attaches unassigned Subscription Lines to a vendor contract |
| `Subscription.VendorContract.CreateInvoice` | Inbound | Writes | Bills a vendor contract to an unposted purchase invoice, never posted |
| `Subscription.VendorContract.PreviewInvoice` | Inbound | **Preview** | Shows what `VendorContract.CreateInvoice` would bill, without keeping anything |
| `Subscription.Billing.CreateProposal` | Inbound | Writes | Generates billing proposal lines for a Billing Template |
| `Subscription.Billing.CreateDocuments` | Inbound | Writes | Turns a template's unbilled proposal lines into documents in bulk |
| `Subscription.Billing.PreviewDocuments` | Inbound | **Preview** | Reads a template's existing proposal lines and reports how they would group into documents |
| `Subscription.PriceUpdate.SetTemplateFilter` | Inbound | Writes | Writes a contract/subscription/line view filter on a Price Update Template |
| `Subscription.PriceUpdate.CreateProposal` | Inbound | **Blocked** | Would build a price update proposal; no public API exists |
| `Subscription.PriceUpdate.Perform` | Inbound | **Blocked** | Would apply a price update proposal; no public API exists |
| `Subscription.Renewal.Extend` | Inbound | Writes | Extends a Subscription onto a customer and/or vendor contract |
| `Subscription.Renewal.CreateQuote` | Inbound | Writes | Builds renewal lines and a sales quote for a customer contract |
| `Subscription.Usage.ImportData` | Inbound | Writes | Imports a usage data file into Usage Data Import lines |
| `Subscription.Usage.Process` | Inbound | Writes | Advances a Usage Data Import entry through its processing stages |
| `Subscription.Deferral.Release` | Inbound | Writes, **posts to G/L** | Releases deferred revenue/cost up to a date, across every contract |
| `Subscription.Analysis.Recalculate` | Inbound | Writes | Rebuilds Subscription Contract analysis entries as of today |
| `Subscription.Import.CreateContracts` | Inbound | Writes | Builds real Subscription/contract records from staged import rows |

---

## 3. Commitments

### 3.1 Subscription.Line.Create

*Implementation: `Sub Line Create Impl ori` (10035036)*

Applies a Subscription Package to an existing Subscription Header, letting Microsoft's own
package application logic derive prices, billing rhythms and dates for each new Subscription
Line. A generic record write cannot do this: the lines to insert, and every value on them, are
computed by Microsoft's package application procedure
(`Subscription Header.InsertServiceCommitmentsFromServCommPackage`), not supplied by the caller.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `subscriptionHeaderNo` | Code[20] | Yes | The Subscription Header to add lines to. May also be supplied as the message subject. | - |
| `subscriptionPackageCode` | Code[20] | Yes | The Subscription Package to apply. | - |
| `subscriptionLineStartDate` | Date | No | Start date for the new lines. | Package's own formula |
| `subscriptionLineEndDate` | Date | No | End date for the new lines. | Left open-ended |
| `usageBasedBillingPackageLinesOnly` | Boolean | No | When true, only the package's usage-based lines are created. | `false` |

```json
{
  "subscriptionHeaderNo": "SUB000010",
  "subscriptionPackageCode": "STANDARD",
  "subscriptionLineStartDate": "2026-09-01"
}
```

```json
{
  "status": "Success",
  "subscriptionHeaderNo": "SUB000010",
  "subscriptionPackageCode": "STANDARD",
  "linesCreated": 3,
  "createdLines": [1001, 1002, 1003]
}
```

`createdLines` holds the `Entry No.` of every Subscription Line added. A package that adds
nothing (for example because every line is filtered out by
`usageBasedBillingPackageLinesOnly`) is still a success, with `linesCreated` of 0.

**Errors**

| Condition | Message |
| --- | --- |
| Subscription Header does not exist | The Subscription Header '%1' does not exist. |
| Header has no Source No. | Standard field-required error naming "Source No." |
| Subscription Package does not exist | The Subscription Package '%1' does not exist. |

**Safety.** Writes only Subscription Lines under the given header. No contract is touched and
nothing is billed. Runs in an isolated transaction that rolls back on error.

---

## 4. Customer Contracts

### 4.1 Subscription.Contract.GetLines

*Implementation: `Sub Con GetLines Impl ori` (10035037)*

Attaches Subscription Lines that are not yet on any contract to a customer Subscription
Contract, reproducing the selection Microsoft's own "Get Subscription Lines" action applies on
the contract page. A generic record write cannot do this: attaching a line also inserts and
numbers a Cust. Sub. Contract Line and stamps the Subscription Line with the contract it now
belongs to (`CustomerSubscriptionContract.CreateCustomerContractLineFromServiceCommitment`).

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Customer Subscription Contract to attach lines to. May also be supplied as the message subject. | - |
| `subscriptionHeaderNo` | Code[20] | No | Restricts candidates to lines on one Subscription. | All subscriptions |
| `subscriptionLineEntryNos` | Integer[] | No | Restricts candidates to these Subscription Line entry numbers. | All eligible lines |

A candidate line has `Invoicing via` = Contract, `Subscription Contract No.` blank,
`Partner` = Customer, and `Subscription Line End Date` either after the work date or blank.

```json
{
  "contractNo": "CC000010",
  "subscriptionHeaderNo": "SUB000010"
}
```

```json
{
  "status": "Success",
  "contractNo": "CC000010",
  "linesAttached": 2,
  "attachedLines": [
    { "subscriptionLineEntryNo": 1001, "contractLineNo": 10000 },
    { "subscriptionLineEntryNo": 1002, "contractLineNo": 20000 }
  ],
  "linesSkipped": 1
}
```

A candidate is skipped, not errored, when its Subscription's End-User Customer No. does not
match the contract's Sell-to Customer No.; `linesSkipped` counts these. A run matching no
candidates is still a success with `linesAttached` of 0.

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Customer Subscription Contract '%1' does not exist. |

**Safety.** Only attaches existing Subscription Lines; never creates or deletes one. Runs in an
isolated transaction that rolls back on error.

### 4.2 Subscription.Contract.CreateInvoice

*Implementation: `Sub Con CrInvoice Impl ori` (10035038)*

Bills one customer Subscription Contract to an unposted sales invoice (or credit memo, when a
line calls for one). The due Subscription Lines are handed to Microsoft's ad-hoc billing
proposal entry point - the same one the per-contract billing dialog in the client uses - which
creates Billing Line proposal rows with no billing template attached, and the document is
created from those rows. A generic record write cannot reach Microsoft's billing/pricing
calculation or document assembly.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Customer Subscription Contract to bill. May also be supplied as the message subject. | - |
| `billingDate` | Date | No | Lines due on or before this date are billed. | Work date |
| `billingToDate` | Date | No | Bills complete periods up to this date. | Each line's own rhythm |
| `documentDate` | Date | No | Document date on the created document. | Work date |
| `postingDate` | Date | No | Posting date on the created document. | Work date |

```json
{
  "contractNo": "CC000010",
  "billingDate": "2026-08-31"
}
```

```json
{
  "status": "Success",
  "contractNo": "CC000010",
  "billingDate": "2026-08-31",
  "documents": [
    { "documentType": "Invoice", "documentNo": "SINV-000123" }
  ],
  "billingLineCount": 3
}
```

Verified end to end: a preview of this same run reported 3 billing periods totalling 3,600
and left the database byte-identical; the real run then produced sales invoice 102311 from
exactly those 3 periods.

`documents` and `billingLineCount` describe **only what this call produced**. When nothing on
the contract is due, or when Business Central proposes nothing new, the call still succeeds
with `documents: []`, `billingLineCount` of 0 and a `message` saying which of the two it was.
The second case is the common one in practice: Business Central will not bill a Subscription
Line whose previous billing document is still unposted, so calling this twice in a row on the
same contract bills once and then reports *"Nothing new could be billed for contract %1..."*
until that document is posted. See
[Known limitations](#a-contract-cannot-be-billed-again-while-its-last-document-is-unposted).

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Customer Subscription Contract '%1' does not exist. |
| `contractNo` missing | The request is missing the required parameter 'contractNo'. |
| Another contract has pending template-less proposal lines | Contract '%1' has %2 pending billing line(s) with no billing template assigned. Clear or complete that proposal before billing this contract, because creating this invoice would also convert those lines. |

**Safety.** Writes an unposted document only; never posts and never opens a page. The proposal
rows this call builds carry a blank Billing Template Code, and Microsoft's document-creation
codeunit converts every blank-template Billing Line in the company when it runs - not only the
ones for this contract. See [Known limitations](#13-known-limitations) for why this call first
checks for, and refuses to run past, another contract's pending blank-template lines. Runs in
an isolated transaction that rolls back on error.

### 4.3 Subscription.Contract.PreviewInvoice

*Implementation: `Sub Con PrvInvoice Impl ori` (10035039)*

Shows what `Subscription.Contract.CreateInvoice` would bill, without keeping anything and
without ever creating a document. The due Subscription Lines are handed to the same ad-hoc
billing proposal entry point the write call uses, so the reported lines, periods and amounts
reflect what Business Central would actually produce - not an approximation. See
[Known limitations](#13-known-limitations) for why this needs a build-then-delete cycle rather
than a plain rollback.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Customer Subscription Contract to preview. May also be supplied as the message subject. | - |
| `billingDate` | Date | No | Lines due on or before this date are billed. | Work date |
| `billingToDate` | Date | No | Bills complete periods up to this date. | Each line's own rhythm |

There are no `documentDate` or `postingDate` parameters - a preview never creates a document.

```json
{
  "contractNo": "CC000010",
  "billingDate": "2026-08-31"
}
```

```json
{
  "status": "Success",
  "contractNo": "CC000010",
  "billingDate": "2026-08-31",
  "lines": [
    { "subscriptionLineEntryNo": 1001, "billingFrom": "2026-08-01", "billingTo": "2026-08-31", "unitPrice": "99.00", "amount": "99.00" }
  ],
  "wouldBillLineCount": 1,
  "totalAmount": "99.00",
  "preview": true,
  "rollback": true
}
```

Verified against a real container: a preview of a live contract reported 3 billing periods
totalling 3,600, and the database was byte-identical afterwards. When nothing is due the call
still succeeds with `lines: []`, `wouldBillLineCount` of 0 and a `message`; when the contract's
due lines are already covered by pending proposal lines, a different `message` explains that
instead. `preview` and `rollback` are always `true`.

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Customer Subscription Contract '%1' does not exist. |
| `contractNo` missing | The request is missing the required parameter 'contractNo'. |
| Another contract has pending template-less proposal lines | Contract '%1' has %2 pending billing line(s) with no billing template assigned. Clear or complete that proposal before previewing this contract, because the preview would also build proposal lines for those. |

**Safety.** Nothing is left behind, but this is not a rolled-back transaction - see
[Known limitations](#13-known-limitations). No document is ever created, even temporarily.

### 4.4 Subscription.Contract.UpdateLineDates — blocked

*Implementation: `Sub Con UpdDates Impl ori` (10035040)*

**Registered and discoverable, but every call returns an error. Nothing is ever written, and
the code does not read the request body at all** - it responds with a fixed error before
looking at any parameter.

In the client, the "Update Subscription Line Dates" action on a Customer Subscription Contract
rolls the term start and end dates on the contract's Subscription Lines forward. That action
calls `Customer Subscription Contract.UpdateServicesDates()`, which in turn calls
`Subscription Header.UpdateServicesDates()` and codeunit 8058 "Update Sub. Lines Term. Dates".
All three are `internal` in Microsoft's Subscription Billing app, so this extension cannot call
them, and there is no other supported route to the same result. Re-implementing the rollover
logic independently was considered and rejected: term dates, billing rhythms and renewal
interact in ways that are easy to get subtly wrong, and a divergent implementation could
corrupt customer contracts in a way that is hard to detect and hard to undo.

**Request parameters.** None are read by the implementation. The call fails unconditionally
regardless of any request body supplied.

```json
{}
```

```json
{
  "status": "Error",
  "error": "Subscription.Contract.UpdateLineDates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateServicesDates(), Subscription Header.UpdateServicesDates() and codeunit 8058 \"Update Sub. Lines Term. Dates\" are all internal to Microsoft's Subscription Billing app and cannot be called from this extension. Run the \"Update Subscription Line Dates\" action on the contract in the Business Central client instead, or schedule Microsoft's own job queue entry for the batch job that does this in bulk.",
  "callstack": "..."
}
```

**Errors.** Always the message above; there is no other outcome.

**Safety.** Never writes. Always responds with an error before reaching the isolated write
process, so there is nothing to roll back.

### 4.5 Subscription.Contract.UpdateExchangeRates — blocked

*Implementation: `Sub Con UpdFCY Impl ori` (10035041)*

**Registered and discoverable, but every call returns an error. Nothing is ever written, and
the code does not read the request body at all.**

In the client, the "Update Exchange Rates" action on a Customer Subscription Contract
recalculates the local-currency amounts on the contract's foreign-currency Subscription Lines,
via `Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData()`, which
is `internal` in Microsoft's app. There is a second, independent reason this stays blocked even
if that procedure were made public: the flow opens the interactive "Exchange Rate Selection"
page so a user can confirm the rate. When `GuiAllowed` is false - as it is for an unattended
Bifrost call - that page returns false instead of failing, and the flow proceeds with a
zero exchange rate. Calling it unattended would silently zero out foreign-currency amounts on
the contract, which is worse than not running it at all.

**Request parameters.** None are read by the implementation.

```json
{}
```

```json
{
  "status": "Error",
  "error": "Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version. Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData() is internal to Microsoft's Subscription Billing app. It also drives the interactive \"Exchange Rate Selection\" page, which returns false and lets a zero exchange rate through when GuiAllowed is false, so it would be unsafe to call unattended even if it were public. Use the \"Update Exchange Rates\" action on the contract in the Business Central client instead.",
  "callstack": "..."
}
```

**Errors.** Always the message above.

**Safety.** Never writes. Always responds with an error, so no risk of the zero-exchange-rate
problem ever reaching a real contract through this API.

---

## 5. Vendor Contracts

### 5.1 Subscription.VendorContract.GetLines

*Implementation: `Sub Vend GetLines Impl ori` (10035042)*

Finds Subscription Lines that are invoiced via a contract, belong to the vendor partner, are
not yet linked to any Vendor Subscription Contract, and have not already ended, then attaches
each one to the given Vendor Subscription Contract. Because Microsoft only exposes the
single-line attach procedure
(`VendorSubscriptionContract.CreateVendorContractLineFromServiceCommitment`) to external apps,
this call loops it once per candidate line - a generic record write has no equivalent
operation to call at all.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Vendor Subscription Contract to attach lines to. May also be supplied as the message subject. | - |
| `subscriptionHeaderNo` | Code[20] | No | Restrict candidates to this Subscription Header. | All subscriptions |
| `subscriptionLineEntryNos` | Integer[] | No | Restrict to these exact Subscription Line entry numbers. | All eligible lines |

```json
{
  "contractNo": "VC000010",
  "subscriptionHeaderNo": "SO000045",
  "subscriptionLineEntryNos": [101, 102]
}
```

```json
{
  "status": "Success",
  "contractNo": "VC000010",
  "linesAttached": 2,
  "attachedLines": [
    { "subscriptionLineEntryNo": 101, "contractLineNo": 10000 },
    { "subscriptionLineEntryNo": 102, "contractLineNo": 20000 }
  ]
}
```

A run matching no candidate line is a success with `linesAttached` of 0 and an empty array.

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Vendor Subscription Contract '%1' does not exist. |
| `contractNo` missing | The request is missing the required parameter 'contractNo'. |
| `subscriptionLineEntryNos` is present but is not an array | The parameter 'subscriptionLineEntryNos' must be a JSON array. |

**Safety.** Only attaches existing Subscription Lines; never creates or deletes one. Runs in an
isolated transaction that rolls back on error.

### 5.2 Subscription.VendorContract.CreateInvoice

*Implementation: `Sub Vend CrInvoice Impl ori` (10035043)*

Bills the due Subscription Lines of one Vendor Subscription Contract. The due lines are copied
into an ad-hoc billing proposal (Billing Line rows with a blank Billing Template Code), which is
then turned into an unposted purchase document via Microsoft's billing proposal codeunit.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Vendor Subscription Contract to bill. May also be supplied as the message subject. | - |
| `billingDate` | Date | No | Lines due on or before this date are billed. | Work date |
| `billingToDate` | Date | No | Bills complete periods up to this date. | Each line's own rhythm |
| `documentDate` | Date | No | Document date on the created document. | Work date |
| `postingDate` | Date | No | Posting date on the created document. | Work date |
| `vendorInvoiceNo` | Text | No | Stamped onto "Vendor Invoice No." on every document this call creates. | Blank |

```json
{
  "contractNo": "VC000010",
  "billingDate": "2026-08-31",
  "vendorInvoiceNo": "INV-2026-0912"
}
```

```json
{
  "status": "Success",
  "contractNo": "VC000010",
  "billingDate": "2026-08-31",
  "billingLineCount": 3,
  "documents": [
    { "documentType": "Invoice", "documentNo": "PINV-000123" }
  ]
}
```

`billingLineCount` counts the billing periods this call actually produced - the same number
the preview reports as `wouldBillLineCount` - and `documents` names only the documents this
call created. A run that finds nothing due, or that Business Central declines to bill again
because the contract's last document is still unposted, is a success with `billingLineCount`
of 0, an empty `documents` array and a `message` saying which of the two it was. See
[Known limitations](#a-contract-cannot-be-billed-again-while-its-last-document-is-unposted).

`vendorInvoiceNo` is stamped only onto the documents this call created; an earlier, still
unposted document for the same contract keeps the Vendor Invoice No. it was given at the
time.

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Vendor Subscription Contract '%1' does not exist. |
| `contractNo` missing | The request is missing the required parameter 'contractNo'. |
| Another contract has an unfinished ad-hoc proposal | There are %1 pending billing proposal line(s) left over for a different subscription contract ('%2'). Clear or process that proposal before creating an invoice for '%3'. |

**Safety.** Writes, but never posts - see [Known limitations](#13-known-limitations). The ad-hoc
blank-template proposal is shared by the whole company, so this call first checks that no such
lines are left standing for a different contract and refuses to run rather than sweep up
someone else's pending run. Runs in an isolated transaction that rolls back on error.

### 5.3 Subscription.VendorContract.PreviewInvoice

*Implementation: `Sub Vend PrvInv Impl ori` (10035044)*

Shows what `Subscription.VendorContract.CreateInvoice` would bill, without keeping anything and
without ever creating a document, using the same ad-hoc billing proposal entry point the write
call uses. See [Known limitations](#13-known-limitations) for the build-then-delete mechanism.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Vendor Subscription Contract to preview. May also be supplied as the message subject. | - |
| `billingDate` | Date | No | Lines due on or before this date are billed. | Work date |
| `billingToDate` | Date | No | Bills complete periods up to this date. | Each line's own rhythm |

There are no `documentDate`, `postingDate` or `vendorInvoiceNo` parameters.

```json
{
  "contractNo": "VC000010",
  "billingDate": "2026-08-31"
}
```

```json
{
  "status": "Success",
  "contractNo": "VC000010",
  "billingDate": "2026-08-31",
  "lines": [
    { "subscriptionLineEntryNo": 2001, "billingFrom": "2026-08-01", "billingTo": "2026-08-31", "unitPrice": "49.00", "amount": "49.00" }
  ],
  "wouldBillLineCount": 1,
  "totalAmount": "49.00",
  "preview": true,
  "rollback": true
}
```

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Vendor Subscription Contract '%1' does not exist. |
| `contractNo` missing | The request is missing the required parameter 'contractNo'. |
| Another contract has an unfinished ad-hoc proposal | There are %1 pending billing proposal line(s) left over for a different subscription contract ('%2'). Clear or process that proposal before previewing '%3'. |

**Safety.** No document is ever created, even temporarily - this call never reaches the step
that turns proposal lines into a purchase document. The same foreign-pending-lines check as
`CreateInvoice` applies here too.

---

## 6. Billing Pipeline

### 6.1 Subscription.Billing.CreateProposal

*Implementation: `Sub Bil CrProposal Impl ori` (10035045)*

Generates billing proposal lines (Billing Line, table 8061) for a Billing Template. Every
Subscription Line whose next billing date falls on or before the billing date, and that
matches the template's own filter, is proposed. Nothing is invoiced yet.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `billingTemplateCode` | Code[20] | Yes | The Billing Template to run. May also be supplied as the message subject. | - |
| `billingDate` | Date | No | Lines due on or before this date are proposed. | Work date |
| `billingToDate` | Date | No | Bills complete periods up to this date. | Each line's own rhythm |
| `automatedBilling` | Boolean | No | Keeps the run silent (no interactive prompts). Leave at the default. | `true` |

```json
{
  "billingTemplateCode": "MONTHLY",
  "billingDate": "2026-08-31",
  "billingToDate": "2026-09-30"
}
```

```json
{
  "status": "Success",
  "billingTemplateCode": "MONTHLY",
  "billingDate": "2026-08-31",
  "billingToDate": "2026-09-30",
  "proposalLinesCreated": 12,
  "proposalLineCount": 12,
  "contracts": ["CC000010", "CC000011"]
}
```

`proposalLinesCreated` counts the lines this call added. `proposalLineCount` is the total
Billing Line rows now recorded against the template - it is counted by template code alone, not
filtered to unbilled rows, so it can include lines a prior `CreateDocuments` run already
converted to a document if those rows still carry this template code. A run matching nothing is
a success with `proposalLinesCreated` of 0.

Verified end to end against a live container as part of `Subscription.Contract.CreateInvoice`
testing: a preview reported 3 billing periods, and the real proposal/invoice run billed exactly
those 3 periods for a total of 3,600.

**Errors**

| Condition | Message |
| --- | --- |
| Template does not exist | The Billing Template '%1' does not exist. |
| `billingTemplateCode` missing | The request is missing the required parameter 'billingTemplateCode'. |

**Safety.** Only creates proposal lines; no invoice is created and nothing is posted. Runs in an
isolated transaction that rolls back on error.

### 6.2 Subscription.Billing.CreateDocuments

*Implementation: `Sub Bil CrDocs Impl ori` (10035046)*

Processes every unbilled Billing Line (Document Type = None) standing under a Billing Template
and turns them into sales or purchase documents, grouped per contract by default. Run
`Subscription.Billing.CreateProposal` first to populate the rows this call consumes. A generic
record write cannot assemble a document from proposal rows; that assembly is Microsoft's own
billing-document codeunit.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `billingTemplateCode` | Code[20] | Yes | The Billing Template whose unbilled proposal lines are processed. May also be supplied as the message subject. | - |
| `documentDate` | Date | No | Document date on the created documents. | Work date |
| `postingDate` | Date | No | Posting date on the created documents. | Work date |
| `postDocuments` | Boolean | No | When true, **customer** documents are posted immediately. Vendor documents are never auto-posted regardless of this flag. | `false` |
| `groupBy` | Text | No | `Contract` groups one document per contract. `Customer` groups one document per Bill-to Customer and only applies when every pending line belongs to a customer contract. | `Contract` |

```json
{
  "billingTemplateCode": "MONTHLY",
  "postDocuments": false
}
```

```json
{
  "status": "Success",
  "billingTemplateCode": "MONTHLY",
  "billingLinesProcessed": 12,
  "documentCount": 5,
  "documents": [
    { "documentType": "Invoice", "documentNo": "INV-000123", "contractNo": "CC000010" }
  ]
}
```

When `postDocuments` was explicitly true, the response carries `"posted": true` at the top
level and each document carries `"posted": true` of its own - posting archives the proposal
rows, so those documents are read back from the Billing Line Archive rather than from Billing
Line. A run with no unbilled proposal lines is a success with `documents: []`, `documentCount`
of 0, and a `message` pointing at `Subscription.Billing.CreateProposal`.

`documents` and `documentCount` cover only the proposal rows **this** call consumed, so
running the same template twice does not re-report the first run's documents.

**This run is not atomic.** Business Central commits each billing document as it creates it,
so a failure part way through - a posting error on one document, say - leaves every document
created before it standing. The response then names them explicitly instead of failing blind:

```json
{
  "status": "Error",
  "error": "The billing run failed after Business Central had already created the documents listed in 'documents'. ...",
  "billingTemplateCode": "MONTHLY",
  "billingLinesProcessed": 12,
  "documentCount": 2,
  "documents": [
    { "documentType": "Invoice", "documentNo": "INV-000123", "contractNo": "CC000010" }
  ],
  "rolledBack": false
}
```

Errors raised before Business Central is called - an unknown template, a mixed-partner
proposal, an invalid `groupBy` - write nothing at all.

**Errors**

| Condition | Message |
| --- | --- |
| Template does not exist | The Billing Template '%1' does not exist. |
| `billingTemplateCode` missing | The request is missing the required parameter 'billingTemplateCode'. |
| Proposal lines mix customer and vendor rows | You can create documents only for one type of partner at a time. Billing Template '%1' currently has both customer and vendor proposal lines pending. |
| `groupBy` not Contract or Customer | The parameter 'groupBy' must be either 'Contract' or 'Customer'. |
| `groupBy` = Customer on vendor lines | 'groupBy' = 'Customer' only applies when the pending proposal lines belong to customer contracts. |

**Safety.** Can post when `postDocuments` is explicitly true, but only for customer documents -
vendor billing documents are never posted by Business Central on this path (see
[Known limitations](#13-known-limitations)). Always refuses to mix customer and vendor proposal
lines in one run. **Not atomic**: see the note above the errors table - documents created
before a failure are committed and are reported back with `"rolledBack": false`.

### 6.3 Subscription.Billing.PreviewDocuments

*Implementation: `Sub Bil PrvDocs Impl ori` (10035047)*

Shows what `Subscription.Billing.CreateDocuments` would produce for a Billing Template's
unbilled proposal lines, by reading those Billing Line rows and grouping them the same way a
real run would. **Unlike the two invoice previews, this type never writes anything at all** -
it only reads proposal lines the caller already created with `Subscription.Billing.
CreateProposal`, so there is nothing to build and nothing to clean up afterwards. See
[Known limitations](#13-known-limitations) for how this differs from the other two previews.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `billingTemplateCode` | Code[20] | Yes | The Billing Template to preview. May also be supplied as the message subject. | - |
| `groupBy` | Text | No | `Contract` groups one document per contract. `Customer` groups one document per Partner No. and only applies when every pending line belongs to a customer contract. | `Contract` |

There are no `documentDate`, `postingDate` or `postDocuments` parameters - a preview never
creates or posts anything.

```json
{
  "billingTemplateCode": "MONTHLY"
}
```

```json
{
  "status": "Success",
  "billingTemplateCode": "MONTHLY",
  "billingLineCount": 12,
  "documentCount": 5,
  "documents": [
    { "contractNo": "CC000010", "partnerNo": "10000", "lineCount": 3, "totalAmount": "297.00" }
  ],
  "warnings": [],
  "preview": true,
  "rollback": true
}
```

`contractNo` is left blank on an entry when `groupBy` is `Customer`, because one document
created that way can span several contracts for the same Partner No. A mix of customer and
vendor proposal lines is not an error here (unlike `CreateDocuments`, which would refuse to
run) - it is reported as a `warnings` entry with code `MixedPartners`, alongside the grouping
this call can still show. A `warnings` entry with code `UpdateRequired` reports lines flagged
"Update Required" that would need refreshing before a real run could process them. A run with
no unbilled proposal lines is a success with `documents: []`, `documentCount` of 0, and a
`message`; `preview` and `rollback` are still `true`.

**Errors**

| Condition | Message |
| --- | --- |
| Template does not exist | The Billing Template '%1' does not exist. |
| `billingTemplateCode` missing | The request is missing the required parameter 'billingTemplateCode'. |
| `groupBy` not Contract or Customer | The parameter 'groupBy' must be either 'Contract' or 'Customer'. |
| `groupBy` = Customer but a vendor line is pending | 'groupBy' = 'Customer' only applies when the pending proposal lines belong to customer contracts. |

**Safety.** Read-only. Does not call `CreateDocuments` or any other writing codeunit, so there
is no proposal to build, no document to create even temporarily, and nothing to clean up.
`preview` and `rollback` are always `true` because nothing was ever written for either to undo.

---

## 7. Price Updates

### 7.1 Subscription.PriceUpdate.SetTemplateFilter

*Implementation: `Sub PU SetFilter Impl ori` (10035048)*

Writes one of the three view filters stored on a Price Update Template (table 8003): the
Subscription Contract filter, the Subscription filter, or the Subscription Line filter. Each is
kept as a Blob holding a standard Business Central view string. Microsoft's own
`WriteFilter`/`ReadFilter`/`EditFilter` table methods on Price Update Template are `internal`,
so this call replicates their normalisation behaviour directly with a `RecordRef` against the
matching table - a generic record write cannot normalise or validate a view string this way.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `priceUpdateTemplateCode` | Code[20] | Yes | The Price Update Template to update. May also be supplied as the message subject. | - |
| `filter` | Text | Yes | A view string, for example `WHERE(Subscription Contract No.=FILTER(CC000010))`, or a full `SORTING(...)WHERE(...)` view. | - |
| `target` | Text | Yes | One of `contract`, `subscription` or `line`, case-insensitive. For `contract`, the target table depends on the template's own Partner field: Customer Subscription Contract when Partner = Customer, otherwise Vendor Subscription Contract. | - |

```json
{
  "priceUpdateTemplateCode": "ANNUAL",
  "target": "contract",
  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))"
}
```

```json
{
  "status": "Success",
  "priceUpdateTemplateCode": "ANNUAL",
  "target": "contract",
  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))",
  "filters": {
    "contract": "WHERE(Subscription Contract No.=FILTER(CC000010))",
    "subscription": "",
    "line": ""
  }
}
```

`filter` echoes back the normalised view written for `target`. `filters` always reports the
current value of all three filters after the write, so a caller can confirm the other two were
left untouched. An empty string means no filter is set.

**Errors**

| Condition | Message |
| --- | --- |
| Template does not exist | The Price Update Template '%1' does not exist. |
| `target` not contract/subscription/line | The parameter 'target' must be one of 'contract', 'subscription' or 'line', not '%1'. |
| `filter` is not a valid view for the target table | Raised by the platform's own filter parser and reported as-is; not a named error of this app. |

Verified end to end: this message type has been run successfully against a live container.

**Safety.** Writes only the named filter Blob on the template record itself - never touches
contracts, subscriptions or lines. Runs in an isolated transaction that rolls back on error.

### 7.2 Subscription.PriceUpdate.CreateProposal — blocked

*Implementation: `Sub PU CrProposal Impl ori` (10035049)*

**Registered and discoverable, but every call returns an error and writes nothing.** Creating a
price update proposal requires `Codeunit "Price Update Management".CreatePriceUpdateProposal`,
which is `internal`. The whole `Interface "Contract Price Update"` and every implementation of
it is also internal, and the worker codeunit 8013 "Process Price Update" is
`Access = Internal`. None of this is reachable from an external app. This codeunit does not
attempt to re-implement Microsoft's price update logic, since silently diverging from
Microsoft's own rounding, currency and binding-period rules could mis-price live customer
contracts.

**Request parameters.** None. The call always fails regardless of any request body.

```json
{}
```

```json
{
  "status": "Error",
  "error": "Subscription.PriceUpdate.CreateProposal cannot run: Codeunit \"Price Update Management\".CreatePriceUpdateProposal is internal in Business Central 28.4 and has not been exposed for external callers. Use the \"Contract Price Update\" page in the Business Central client to create the proposal, or call Subscription.PriceUpdate.SetTemplateFilter first to prepare the template's filters.",
  "callstack": "..."
}
```

**Errors.** Always the message above.

**Safety.** Never writes. Registered so discovery and help tooling can list it, but every call
fails fast with an actionable error instead of attempting an unsupported workaround.

### 7.3 Subscription.PriceUpdate.Perform — blocked

*Implementation: `Sub PU Perform Impl ori` (10035050)*

**Registered and discoverable, but every call returns an error and writes nothing.** Applying a
price update proposal requires `Codeunit "Price Update Management".PerformPriceUpdate`, which is
`internal`, and its worker codeunit 8013 "Process Price Update" is `Access = Internal`. Neither
is reachable from an external app. A further reason this stays blocked even hypothetically:
Microsoft's `PerformPriceUpdate` processes every row standing in the price update proposal table
across all templates, with no template or contract filter of its own - the filtering happens
earlier, when the proposal is created - so a caller expecting "perform" to be scoped to one
template would be surprised by that behaviour.

**Request parameters.** None. The call always fails regardless of any request body.

```json
{}
```

```json
{
  "status": "Error",
  "error": "Subscription.PriceUpdate.Perform cannot run: Codeunit \"Price Update Management\".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the \"Contract Price Update\" page in the Business Central client to perform the price update.",
  "callstack": "..."
}
```

**Errors.** Always the message above.

**Safety.** Never writes. Registered so discovery and help tooling can list it, but every call
fails fast rather than risking price changes on contracts the caller never intended to touch.

---

## 8. Renewal

### 8.1 Subscription.Renewal.Extend

*Implementation: `Sub Ren Extend Impl ori` (10035051)*

Extends an existing Subscription onto a customer and/or vendor contract by running Microsoft's
`Codeunit "Extend Sub. Contract Mgt."`. The Subscription must already exist - this type does not
create one. The item's own standard service commitment packages are always applied by
Microsoft's codeunit; `subscriptionPackageCodes` only adds further packages beyond those
standard ones. Microsoft's completion dialog is suppressed so the call never blocks on user
input - a generic record write has no way to invoke this multi-table extension logic at all.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `subscriptionHeaderNo` | Code[20] | Yes | The Subscription to extend. May also be supplied as the message subject. | - |
| `customerContractNo` | Code[20] | No | An existing Customer Subscription Contract to extend onto. | Not extended |
| `vendorContractNo` | Code[20] | No | An existing Vendor Subscription Contract to extend onto. | Not extended |
| `subscriptionPackageCodes` | Code[20][] | No | Extra Subscription Package codes to apply beyond the item's standard packages. | None |
| `usageBasedBillingPackageLinesOnly` | Boolean | No | When true, only usage-based billing package lines are added. | `false` |
| `supplierReferenceEntryNo` | Integer | No | Links the extension to a specific supplier reference Subscription Line entry. | `0` |

At least one of `customerContractNo` or `vendorContractNo` is required.

```json
{
  "subscriptionHeaderNo": "SO000010",
  "customerContractNo": "CC000010",
  "subscriptionPackageCodes": ["SUPPORT"]
}
```

```json
{
  "status": "Success",
  "subscriptionHeaderNo": "SO000010",
  "customerContractNo": "CC000010",
  "custContractLineCountBefore": 3,
  "custContractLineCountAfter": 5,
  "custContractLinesCreated": 2,
  "newSubscriptionLineEntryNos": [1044, 1045],
  "newSubscriptionLineCount": 2
}
```

`custContractLine*`/`vendContractLine*` fields are only present for the side that was extended.
`newSubscriptionLineEntryNos` lists the Subscription Line entries this call added, regardless of
which contract side they were linked to.

Verified end to end against a live container.

**Errors**

| Condition | Message |
| --- | --- |
| Subscription does not exist | The Subscription '%1' does not exist. |
| Customer contract does not exist | The Customer Subscription Contract '%1' does not exist. |
| Vendor contract does not exist | The Vendor Subscription Contract '%1' does not exist. |
| A package code does not exist | The Subscription Package '%1' does not exist. |
| Neither contract number supplied | The request must supply at least one of 'customerContractNo' or 'vendorContractNo'. |

**Safety.** Inserts Subscription Lines and Cust./Vend. Sub. Contract Line records. Runs in an
isolated transaction that rolls back on error.

### 8.2 Subscription.Renewal.CreateQuote

*Implementation: `Sub Ren CrQuote Impl ori` (10035052)*

Creates a contract renewal sales quote for a Customer Subscription Contract. Any stale renewal
lines left over from an earlier run against this contract are deleted first, then a fresh Sub.
Contract Renewal Line row is built from every still-open Subscription Line on the contract, and
Microsoft's `Codeunit "Create Sub. Contract Renewal"` turns those rows into one sales quote.
This bypasses Microsoft's interactive renewal wrapper entirely, so it never shows a dialog or a
request page - something a generic record write has no equivalent for.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | Yes | The Customer Subscription Contract to renew. May also be supplied as the message subject. | - |

```json
{
  "contractNo": "CC000010"
}
```

```json
{
  "status": "Success",
  "contractNo": "CC000010",
  "renewalLinesCreated": 4,
  "salesQuoteNo": "SQ000123"
}
```

**Errors**

| Condition | Message |
| --- | --- |
| Contract does not exist | The Customer Subscription Contract '%1' does not exist. |
| No Subscription Line qualifies for renewal | The Customer Subscription Contract '%1' has no Subscription Lines that can be renewed. |
| Create Sub. Contract Renewal produced no quote | Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract '%1'. |

**Safety.** Deletes and re-creates Sub. Contract Renewal Line rows for this contract, and
creates a sales quote header and lines. Never posts anything and never touches the contract
itself. Runs in an isolated transaction that rolls back on error.

---

## 9. Usage

### 9.1 Subscription.Usage.ImportData

*Implementation: `Sub Usg Import Impl ori` (10035053)*

Creates a Usage Data Import header (table 8013) and a Usage Data Blob (table 8011) holding the
supplied file, then runs Microsoft's "Import And Process Usage Data" codeunit with the "Create
Imported Lines" step, parsing the file into Usage Data Generic Import rows (table 8018). This
only creates the imported lines; it does not turn them into billable quantities.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `supplierNo` | Code[20] | Yes | The Usage Data Supplier the file was received from. May also be supplied as the message subject. | - |
| `fileName` | Text | No | The source file name recorded on the Usage Data Blob. | `bifrost-usage.csv` |
| `content` | Text | See note | The raw file content as text, for example a CSV payload. | - |
| `contentBase64` | Text | See note | The file content, base64 encoded. Use for non-text payloads. | - |
| `runProcessing` | Boolean | No | When true, also runs the "Process Imported Lines" step immediately after the import. | `false` |

At least one of `content` or `contentBase64` must be supplied. If both are supplied,
`contentBase64` takes priority and `content` is silently ignored - the code does not treat
supplying both as an error.

```json
{
  "supplierNo": "USUP0010",
  "fileName": "august-usage.csv",
  "content": "SubscriptionID,ProductID,Quantity\n1001,PROD1,10",
  "runProcessing": true
}
```

```json
{
  "status": "Success",
  "usageDataImportEntryNo": 137,
  "processingStatus": "Ok",
  "reason": "",
  "importedLineCount": 10
}
```

`reason` is only populated when `processingStatus` is `Error`. `importedLineCount` counts the
Usage Data Generic Import rows now standing for this entry. A file that parses with row-level
problems is still a success at the call level - check `processingStatus` and `reason`, and
inspect the Usage Data Import entry in the client for row-level detail.

**Errors**

| Condition | Message |
| --- | --- |
| Neither `content` nor `contentBase64` supplied | The request must supply either 'content' (raw text) or 'contentBase64' (base64 encoded) for the usage data file. |
| `supplierNo` missing | The request is missing the required parameter 'supplierNo'. |
| Microsoft's import codeunit fails | The underlying error text from `Codeunit "Import And Process Usage Data"`, passed through as-is. |

**Safety.** Creates a new Usage Data Import entry and its imported lines; does not post
anything and does not touch existing Subscription data. Runs in an isolated transaction that
rolls back on error.

### 9.2 Subscription.Usage.Process

*Implementation: `Sub Usg Process Impl ori` (10035054)*

Advances an existing Usage Data Import entry through its remaining processing stages: turning
imported lines into billable quantities, creating Usage Data Billing rows (table 8006), and
processing those rows into Billing Line entries. Each requested stage runs Microsoft's own
processing codeunit for that step, in its own committed transaction, so a failure in a later
stage does not undo an earlier one.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `usageDataImportEntryNo` | Integer | Yes | The Usage Data Import entry to process. May also be supplied as the message subject when the subject is numeric. | - |
| `steps` | Text[] | No | Any subset of `CreateImportedLines`, `ProcessImportedLines`, `CreateUsageDataBilling`, `ProcessUsageDataBilling`, always executed in that order regardless of the order given. | The last three, in order |

`CreateImportedLines` re-parses the Usage Data Blob that `Subscription.Usage.ImportData`
already stored, into Usage Data Generic Import rows. It is deliberately **not** in the default
set, because the import call runs it once already; ask for it when that first parse failed on
a setup problem - a Data Exchange Definition that does not match the file, say - and you want
to retry without re-sending the file.

```json
{
  "usageDataImportEntryNo": 137,
  "steps": ["ProcessImportedLines", "CreateUsageDataBilling"]
}
```

```json
{
  "status": "Success",
  "usageDataImportEntryNo": 137,
  "steps": [
    { "step": "ProcessImportedLines", "status": "Ok", "reason": "" },
    { "step": "CreateUsageDataBilling", "status": "Ok", "reason": "" }
  ],
  "processingStatus": "Ok",
  "usageDataBillingCount": 10,
  "usageDataBillingErrorCount": 0
}
```

Each stage's `status` and `reason` are its own: Business Central leaves the previous stage's
status standing on the Usage Data Import entry and only overwrites it when a stage has
something to say, so the entry is reset before each stage runs. Without that, a stage that
succeeded after an earlier one failed would be reported as an error carrying the earlier
stage's message.

`processingStatus` is the entry's status after the last requested stage. `usageDataBillingCount`
and `usageDataBillingErrorCount` count Usage Data Billing rows for this entry, the second
filtered to rows whose own Processing Status is Error. A stage that fails on its own data (for
example a row with a missing price) is still reported as a successful call - check each entry in
`steps` and `processingStatus`.

**Errors**

| Condition | Message |
| --- | --- |
| Entry does not exist | The Usage Data Import entry %1 does not exist. |
| Entry is already Closed | Usage Data Import entry %1 is already Closed and cannot be processed again. |
| Unknown step name given | '%1' is not a known processing step. Use ProcessImportedLines, CreateUsageDataBilling or ProcessUsageDataBilling. |
| `steps` is present but is not an array | The parameter 'steps' must be a JSON array. |

**Safety.** Advances an existing entry through its processing stages, creating Usage Data
Billing rows; does not post anything by itself. Each requested stage commits once it completes,
so a partially requested run cannot be rolled back as a whole - rerun the remaining steps
instead.

---

## 10. Deferrals

### 10.1 Subscription.Deferral.Release

*Implementation: `Sub Def Release Impl ori` (10035055)*

Runs Microsoft's "Contract Deferrals Release" report, which releases every eligible deferred
revenue and cost entry - customer (table 8066) and vendor (table 8072) - and posts the release
to the general ledger. A generic record write has no way to invoke a posting report.

**The report always uses the session work date, and its two dates cannot be set from an
external app.** They live on its request page, backed by global variables;
`SetRequestPageParameters` is `internal` in Microsoft's app, and the request page XML passed to
`Report.Execute` is not applied to this report. Verified against Business Central 28.4: a call
asking for `postUntilDate` of 2026-03-31 released every eligible deferral up to the work date of
2026-09-01 and posted them under the work date.

`postingDate` and `postUntilDate` are therefore **a guard, not an instruction**. The call
inspects what the report is about to do and refuses when that reaches further than the caller
asked, rather than posting irreversibly and reporting a number that does not match what
happened. To release up to an earlier date, set the session work date first.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `postingDate` | Date | No | The date the caller expects the release to post under. Must equal the work date - the call is refused otherwise, because that is the only date Business Central will use. | Work date |
| `postUntilDate` | Date | No | The latest deferral posting date the caller is willing to release. The call is refused if the report would go past it. Must not be later than `postingDate`. | `postingDate` |

```json
{
  "postingDate": "2026-08-31",
  "postUntilDate": "2026-08-31"
}
```

```json
{
  "status": "Success",
  "postingDate": "2026-08-31",
  "postUntilDate": "2026-08-31",
  "customerDeferralsReleased": 8,
  "vendorDeferralsReleased": 3,
  "totalDeferralsReleased": 11
}
```

Counts are measured across **every** unreleased deferral, not only those inside the requested
window, so they report what the run actually released. A run finding nothing eligible is still
a success, with every count at 0. Should anything outside the window be released even so, the
response carries `releasedOutsideRequestedWindow` and a `warning`, so it is visible in the
response and not only in the ledger.

Confirmed by live testing: this call requires `Source Code Setup."Sub. Contr. Deferrals
Release"` and the deferral release journal template/batch in Subscription Contract Setup to be
configured first. That check is not implemented in this app's own code - it is enforced inside
Microsoft's "Contract Deferrals Release" report, which this message type invokes directly. If
the setup is missing, the report itself raises a clear error, which this call passes through
unchanged.

**Errors**

| Condition | Message |
| --- | --- |
| `postUntilDate` later than `postingDate` | The parameter 'postUntilDate' (%1) must not be later than 'postingDate' (%2). |
| `postingDate` is not the work date | Business Central posts this release under the work date (%1) and offers no supported way to post it under a different one, so 'postingDate' (%2) cannot be honoured. Omit 'postingDate', or set the session work date to %2 before calling. |
| The report would reach past `postUntilDate` | Refusing to run: Business Central would release %1 deferral(s) posted between 'postUntilDate' (%2) and the work date (%3)... |
| Deferral release setup missing | Raised by Microsoft's "Contract Deferrals Release" report when Source Code Setup or the release journal template/batch is not configured; reported as-is. |

**Safety.** **This message type posts to the general ledger and cannot be undone**, except by
posting a compensating credit memo through the normal deferral correction process. It is **not
scoped to a single contract** - it releases every eligible customer and vendor deferral, across
every Subscription Contract, up to the work date. `postUntilDate` is what keeps that from
reaching further than intended; it can refuse the run, but it cannot narrow it. Confirm the work
date carefully before calling this in a production environment.

---

## 11. Analysis

### 11.1 Subscription.Analysis.Recalculate

*Implementation: `Sub Ana Recalc Impl ori` (10035056)*

Runs Microsoft's "Create Contract Analysis" report, which adds Sub. Contr. Analysis Entry rows
(table 8019) for every Subscription Line that belongs to a Subscription Contract. Three facts
about this report cannot be changed by this message type: it takes no parameters and always
analyses as of today's system date, not a date the caller chooses; it covers every Subscription
Line with a contract, never a single one; and it is additive only - a line that already has an
analysis entry for the current month is skipped, so calling this twice in the same month does
not duplicate or refresh entries already produced this month.

Confirmed by live testing: this message type has been run successfully end to end.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `contractNo` | Code[20] | No | Does **not** scope the run itself - the report always covers every contract. Only narrows the counts reported back, to this Subscription Contract. | Counts cover every contract |

```json
{
  "contractNo": "CC000010"
}
```

```json
{
  "status": "Success",
  "analysisDate": "2026-08-30",
  "entriesCreated": 4,
  "totalEntries": 96
}
```

`entriesCreated` counts the analysis entries this call added, and `totalEntries` is the total
number of analysis entries now on file (narrowed to `contractNo` when given). A run where every
line was already analysed this month is still a success, with `entriesCreated` at 0.

**Errors.** None specific to this message type. Failures return the standard
`{"status": "Error", "error": "...", "callstack": "..."}` shape.

**Safety.** Only adds analysis entries - a reporting side table. Does not post to the general
ledger and does not change any Subscription Contract or Subscription Line data. Runs in an
isolated transaction that rolls back on error.

---

## 12. Import

### 12.1 Subscription.Import.CreateContracts

*Implementation: `Sub Imp CrContr Impl ori` (10035057)*

Turns staged import rows - Imported Subscription Header (table 8008), Imported Cust. Sub.
Contract (table 8010) and Imported Subscription Line (table 8009) - into real Subscription
Header, Customer Subscription Contract, Subscription Line and Cust. Sub. Contract Line records.
The four stages run in a fixed order - headers, then contracts, then lines, then contract lines
- because each later stage needs the keys the earlier stages wrote back onto the staging rows.
Only unprocessed rows are picked up: each stage filters to its own "created" flag being false,
so calling this again only processes what is still outstanding. One bad row does not stop the
batch - its error is recorded on the staging row and the next row is still attempted.

Confirmed by live testing: this message type has been run successfully end to end.

**Request parameters**

| Parameter | Type | Required | Description | Default |
| --- | --- | --- | --- | --- |
| `stages` | Text[] | No | Which stages to run, any subset of `SubscriptionHeaders`, `CustomerContracts`, `SubscriptionLines`, `ContractLines`. Always executed in that fixed order regardless of the order given. | All four, in order |

```json
{
  "stages": ["SubscriptionHeaders", "CustomerContracts", "SubscriptionLines", "ContractLines"]
}
```

```json
{
  "status": "Success",
  "stages": [
    { "stage": "SubscriptionHeaders", "processed": 5, "succeeded": 5, "failed": 0 },
    { "stage": "CustomerContracts", "processed": 5, "succeeded": 4, "failed": 1 },
    { "stage": "SubscriptionLines", "processed": 5, "succeeded": 5, "failed": 0 },
    { "stage": "ContractLines", "processed": 5, "succeeded": 4, "failed": 1 }
  ],
  "errors": [
    { "stage": "CustomerContracts", "key": "12", "error": "..." }
  ]
}
```

`processed` is the number of unprocessed rows the stage found; `succeeded` and `failed` split
that count. `key` in `errors` is the staging row's Entry No. The `errors` array is capped at the
first 50 entries across all stages; a failed row past that cap is still counted in `failed` but
its detail is not listed, and the response adds an `errorsNote` key explaining the cap - check
the staging table in the client for the rest.

**Errors**

| Condition | Message |
| --- | --- |
| An unknown stage name is given | '%1' is not a known import stage. Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines. |

A row failing to create its Subscription record is not itself a call error - it is reported
inside `stages` and `errors` instead, and the call still returns `"status": "Success"`.

**Safety.** Creates new Subscription Header, Customer Subscription Contract, Subscription Line
and Cust. Sub. Contract Line records from staging rows already present in the database; does
not post anything. Each staging row is committed independently as it is processed, so a
failure partway through leaves earlier rows' results in place - this call cannot be rolled back
as a whole once it has started.

---

## 13. Known limitations

### Four message types are permanently blocked

Four message types are registered and discoverable, so tooling can list and describe them, but
every call to one returns a structured error and never writes anything. Each names the exact
Microsoft procedure that would need to be made public before the type could work:

| Message type | Microsoft procedure that would need to become public |
| --- | --- |
| `Subscription.Contract.UpdateLineDates` | `Customer Subscription Contract.UpdateServicesDates` (and `Subscription Header.UpdateServicesDates`, codeunit 8058 "Update Sub. Lines Term. Dates") |
| `Subscription.Contract.UpdateExchangeRates` | `Customer Subscription Contract.UpdateAndRecalculateServiceCommitmentCurrencyData` |
| `Subscription.PriceUpdate.CreateProposal` | `Price Update Management.CreatePriceUpdateProposal` |
| `Subscription.PriceUpdate.Perform` | `Price Update Management.PerformPriceUpdate` |

All four are `internal` (or, for the underlying worker codeunits, `Access = Internal`) in
Microsoft's Subscription Billing app in Business Central 28.4, so this extension cannot call
them, and none of the four attempt to re-implement the underlying business logic - doing so
risks silently diverging from Microsoft's own rules and corrupting or mis-pricing customer
contracts. Use the equivalent action in the Business Central client instead (see each type's
own section above for the specific action name).

### Deferral release cannot be scoped to a date from an external app

`Subscription.Deferral.Release` runs Microsoft's "Contract Deferrals Release" report, whose
posting date and cut-off date live on its request page. `SetRequestPageParameters` is `internal`
in Microsoft's app, and the request page XML handed to `Report.Execute` is not applied to this
report, so neither date can be supplied from outside. The report uses the session work date for
both: it releases everything eligible up to the work date and posts it under the work date.

Because the call posts irreversibly to the general ledger, `postingDate` and `postUntilDate` are
enforced as a precondition instead of being accepted and quietly ignored - the call is refused
when the report would post under a different date, or release deferrals past `postUntilDate`.
The way to release up to an earlier date is to set the session work date before calling.

### A contract cannot be billed again while its last document is unposted

Business Central will not propose a new billing period for a Subscription Line whose previous
billing document is still unposted. This is Microsoft's own rule, not something this app adds,
and it applies to every route into billing - `Subscription.Contract.CreateInvoice`,
`Subscription.VendorContract.CreateInvoice` and `Subscription.Billing.CreateProposal` alike.

The practical consequence for an integration is that billing the same contract twice in a row
bills once. The second call succeeds and reports `documents: []`, a count of 0, and a message
saying nothing new could be billed - it does **not** silently re-report the first call's
document. Post (or delete) the outstanding document and the next call bills the next period.

### Array parameters must be arrays

Every message type that takes a list - `subscriptionLineEntryNos`, `subscriptionPackageCodes`,
`steps`, `stages` - rejects a value that is present but is not a JSON array, with
*"The parameter '%1' must be a JSON array."* Omitting the parameter, or sending it as null,
still selects the documented default. The alternative - quietly ignoring a malformed list -
would turn a typo into a much larger run than the caller asked for: a mistyped `steps` would
run all the processing stages, and a mistyped `subscriptionLineEntryNos` would attach every
eligible Subscription Line rather than the two that were named.

### CreateInvoice refuses to run past another contract's pending lines

`Subscription.Contract.CreateInvoice` and `Subscription.VendorContract.CreateInvoice` both bill
a single contract by copying its due Subscription Lines into an ad-hoc billing proposal - Billing
Line rows with a **blank Billing Template Code**. That proposal is company-wide, not scoped to
one contract: Microsoft's document-creation codeunit converts every blank-template Billing Line
standing in the company when it runs, not only the ones this call just added. Both
implementations therefore check, before doing anything, whether any blank-template Billing Line
already exists for a **different** contract, and refuse to run if so - naming that other
contract in the error - rather than silently invoicing someone else's pending, unfinished
proposal alongside this one. The two preview types (`Subscription.Contract.PreviewInvoice` and
`Subscription.VendorContract.PreviewInvoice`) apply the identical check, because they build the
same kind of proposal rows temporarily.

### Vendor billing documents are never posted on this path

`Subscription.VendorContract.CreateInvoice` and the vendor path of
`Subscription.Billing.CreateDocuments` always produce an **unposted** purchase invoice or credit
memo. Business Central's billing-document creation ignores any post flag for vendor documents on
this route, so posting must always happen as a separate, deliberate step after review - there is
no parameter on either message type that can post a vendor document directly.

### Two of the three previews build and delete real proposal lines; one does not

`Subscription.Contract.PreviewInvoice` and `Subscription.VendorContract.PreviewInvoice` are not
rolled-back transactions. Microsoft's billing proposal codeunit commits internally partway
through its own run, so an ordinary error-based rollback would not undo it. Instead, each of
these two notes the last Billing Line entry number before doing anything, builds the real
proposal rows for the contract's due Subscription Lines through the same entry point the write
call uses, reads back exactly the rows it just created, and then deletes exactly those rows
again - newest first - on both the success path and if the proposal call itself fails partway
through. Deleting newest-first lets Business Central rewind the billing chain cleanly, including
fields such as Next Billing Date that a later proposal row can advance; deleting in the wrong
order, or leaving any row behind, could leave the chain pointing at a period that was never
actually billed.

`Subscription.Billing.PreviewDocuments` is different: it never builds or deletes anything. It
only reads Billing Line rows that already exist because the caller ran
`Subscription.Billing.CreateProposal` earlier, so there is nothing to roll back and no rewind
mechanism needed.

Verified by live testing: a preview reported 3 billing periods totalling 3,600 and left the
database byte-identical; the subsequent real run produced sales invoice 102311 from exactly
those 3 periods.
