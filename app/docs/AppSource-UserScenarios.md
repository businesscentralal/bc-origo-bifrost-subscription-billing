# AppSource user scenarios

**App:** Bifrost Subscription Billing
**Publisher:** Origo
**Version:** 28.0.0.0
**Prepared:** 2026-09-01

These scenarios let a validation engineer exercise the app end to end. They assume a Business
Central sandbox with the **Subscription Billing** app and **Bifrost Foundation** installed,
and the Bifrost demonstration data available.

## Test credentials

| Field | Value |
| --- | --- |
| Environment | Sandbox with Subscription Billing enabled |
| Company | CRONUS (or any company with Subscription Billing set up) |
| User | A user with SUPER, or with `BIFROST SubBil ori` plus a Bifrost Core permission set |

## Prerequisites

1. Install **Bifrost Foundation** and activate it (see the Foundation app's own setup guide).
2. Install **Subscription Billing** (Microsoft) and run its assisted setup so that
   Subscription Contract Setup, number series and a Billing Template exist.
3. Install **Bifrost Subscription Billing**.
4. Assign the permission set **Bifrost Sub. Billing** (`BIFROST SubBil ori`) to the test user,
   in addition to their Bifrost Core permissions.

### Company setup the later scenarios depend on

Scenarios 1 to 5 need nothing beyond the four steps above. The billing, deferral and usage
scenarios post to the general ledger, so the company must also be set up for that. These are
Microsoft's own Subscription Billing prerequisites, not this app's, but they are easy to miss on
a fresh sandbox - every one of them was hit while testing this release against a Business
Central 28.4 container:

| Setup | Why it is needed | Symptom if missing |
| --- | --- | --- |
| **General Posting Setup** for the subscription item's posting group combination: *Cust. Sub. Contract Account*, *Cust. Sub. Contr. Def Account*, *Vend. Sub. Contract Account*, *Vend. Sub. Contr. Def. Account* | Contract deferrals post through these accounts | Posting a billing document fails with *"Cust. Sub. Contract Deferral Account must have a value in General Posting Setup..."* |
| **General Posting Setup**: sales/purchase line and invoice discount accounts, credit memo accounts | The deferral release journal needs them | `Subscription.Deferral.Release` fails with *"Sales Line Disc. Account must have a value..."* |
| **VAT Posting Setup** completed for the subscription item's VAT product posting group | Any posting | Posting fails with *"...VAT Posting Setup is blocked"* |
| **Source Code Setup > Sub. Contr. Deferrals Release** | Stamps the deferral release entries | `Subscription.Deferral.Release` fails with *"Subscription Contract Deferral must have a value in Source Code Setup"* |
| **Subscription Contract Setup > Def. Rel. Jnl. Template Name / Def. Rel. Jnl. Batch Name** | The journal the release posts through | `Subscription.Deferral.Release` cannot post |
| **Subscription Contract Setup > Vend. Sub. Contract Nos.** | Numbering vendor contracts | Creating a Vendor Subscription Contract fails |
| An **Item Unit of Measure** row for the subscription item, and the same code on the Subscription header | The invoicing item must share the subscription's unit | `Subscription.Contract.CreateInvoice` fails with *"The subscription's unit of measure contains a value that is not found in the item unit of measure..."* |
| **Currency Exchange Rates** covering the posting dates you use - including for the **Additional Reporting Currency**, if the company has one | Posting converts amounts to the additional reporting currency at the posting date | Posting fails with *"There is no Currency Exchange Rate within the filter"*. Note the reported currency code may be the **local** currency even when every document is in local currency and the rate that is actually missing belongs to the reporting currency, so check both |

### Usage-based billing scenarios

`Subscription.Usage.ImportData` parses the file through Microsoft's generic usage-data connector,
which needs, in addition to the above:

- a **Usage Data Supplier** of type Generic;
- **Generic Import Settings** for that supplier, pointing at a **Data Exchange Definition** that
  maps the file's columns onto table 8018 *Usage Data Generic Import*;
- **Usage Data Supplier Reference**, **Usage Data Supp. Customer** and **Usage Data Supp.
  Subscription** rows linking the file's customer and subscription identifiers to the Business
  Central customer and the usage-based Subscription Line.

Without the Data Exchange Definition the import call still succeeds as a call, and reports
`processingStatus: "Error"` with Business Central's own reason - it does not throw.

---

## Scenario 1: Installation and activation

1. Open **Extension Management**.
2. Confirm **Bifrost Subscription Billing** is listed and installed.
3. Confirm the dependency **Bifrost Foundation** is installed and appears above it.
4. Open **Users**, select the test user, and confirm the permission set
   **Bifrost Sub. Billing** can be assigned.

**Expected:** the extension installs with no errors and its permission set is assignable.

---

## Scenario 2: Discovering the message types

1. Invoke the Bifrost message type **`Help.MessageTypes.Get`** (Core).
2. Inspect the returned list.

**Expected:** the response includes 22 message types whose names begin with `Subscription.`, each
with a non-empty `description`, `messageDirection` of `Inbound`, and `isEnabled` of `true`.

---

## Scenario 3: Reading a message type's help document

1. Invoke **`Help.Implementation.Get`** with the subject `Subscription.Billing.CreateProposal`.
2. Read the returned markdown.

**Expected:** a markdown document titled `# Subscription.Billing.CreateProposal` containing the
sections Overview, Request Parameters, Request Example, Response Shape, Errors, Safety and Related
Message Types. Repeat for any other `Subscription.*` type and confirm the same structure.

---

## Scenario 4: Core functionality — create a billing proposal

1. In the client, open **Billing Templates** and note the code of an existing template, or create
   one for the Customer partner.
2. Invoke **`Subscription.Billing.CreateProposal`** with a body such as:

   ```json
   { "billingTemplateCode": "<template code>", "billingDate": "<a date with due lines>" }
   ```

3. Open **Recurring Billing** in the client and filter on the same template.

**Expected:** the response has `"status": "Success"` and reports `proposalLinesCreated`. The same
number of billing proposal lines is visible in Recurring Billing. If nothing was due, the call
still succeeds with `proposalLinesCreated` of 0 — this is not an error.

---

## Scenario 5: Core functionality — bill a contract to an unposted invoice

1. Choose a Customer Subscription Contract with subscription lines due for billing.
2. Invoke **`Subscription.Contract.CreateInvoice`** with the contract number as the subject, or:

   ```json
   { "contractNo": "<contract no.>", "billingDate": "<date>" }
   ```

3. Open **Sales Invoices** in the client.

**Expected:** the response lists the created document under `documents`, and an **unposted** sales
invoice with that number exists for the contract's customer. Nothing is posted. If the contract had
nothing due, the response succeeds with an empty `documents` array and an explanatory `message`.

---

## Scenario 6: Preview writes nothing

1. Note the number of unposted sales invoices for a customer.
2. Invoke **`Subscription.Contract.PreviewInvoice`** for one of that customer's contracts.
3. Re-check the sales invoice list and the contract's billing lines.

**Expected:** the response has `"status": "Success"`, `"preview": true` and `"rollback": true`, and
describes what would be created. **No new invoice and no new billing line exists** — the count is
unchanged. This demonstrates the preview-and-rollback behaviour.

---

## Scenario 7: Error handling — invalid input

1. Invoke **`Subscription.Billing.CreateProposal`** with a template code that does not exist:

   ```json
   { "billingTemplateCode": "DOES-NOT-EXIST" }
   ```

2. Invoke **`Subscription.Contract.CreateInvoice`** with no `contractNo` and no subject.

**Expected:** both return `{"status": "Error", ...}` with a readable `error` message — the first
naming the missing Billing Template, the second naming the missing required parameter. Nothing is
written in either case, and the response includes a `hint` pointing at `Help.Implementation.Get`.

---

## Scenario 8: Documented limitations return a clear error

1. Invoke **`Subscription.PriceUpdate.CreateProposal`**.

**Expected:** the response is `{"status": "Error", ...}` and the message states that Microsoft has
not exposed a public API for this operation in this version, names the Microsoft procedure
concerned, and directs the user to the **Contract Price Update** page in the client. This is the
documented, intended behaviour — see the app's changelog and message type reference.

---

## Scenario 9: Data integrity — no deletions

1. Review the list from Scenario 2.

**Expected:** no message type name ends in `.Delete`. The app never deletes subscription, contract
or billing records.

---

## Scenario 10: Permission verification

1. Create a user **without** the `BIFROST SubBil ori` permission set (Bifrost Core access only).
2. Attempt to invoke **`Subscription.Billing.CreateProposal`** as that user.
3. Assign `BIFROST SubBil ori` and retry.

**Expected:** without the permission set the call fails with a permission error; with it, the call
succeeds (subject to the user's own permissions on the Subscription Billing tables, which this
extension does not widen).

---

## Scenario 11: Uninstallation

1. Open **Extension Management**.
2. Uninstall **Bifrost Subscription Billing**.
3. Invoke `Help.MessageTypes.Get` again.

**Expected:** the extension uninstalls without error, the `Subscription.*` message types no longer
appear, and Bifrost Core and Subscription Billing continue to work normally. No Subscription
Billing data is removed by the uninstall.
