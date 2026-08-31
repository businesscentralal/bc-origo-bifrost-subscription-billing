# AppSource user scenarios

**App:** Origo Cloud Events Subscription Billing
**Publisher:** Origo
**Version:** 28.0.0.0
**Prepared:** 2026-08-30

These scenarios let a validation engineer exercise the app end to end. They assume a Business
Central sandbox with the **Subscription Billing** app and **Origo Cloud Events Core** installed,
and the Cloud Events demonstration data available.

## Test credentials

| Field | Value |
| --- | --- |
| Environment | Sandbox with Subscription Billing enabled |
| Company | CRONUS (or any company with Subscription Billing set up) |
| User | A user with SUPER, or with `CE Sub Bil Obj ori` plus a Cloud Events Core permission set |

## Prerequisites

1. Install **Origo Cloud Events Core** and activate it (see the Core app's own setup guide).
2. Install **Subscription Billing** (Microsoft) and run its assisted setup so that
   Subscription Contract Setup, number series and a Billing Template exist.
3. Install **Origo Cloud Events Subscription Billing**.
4. Assign the permission set **Cloud Events Sub. Billing** (`CE Sub Bil Obj ori`) to the test user,
   in addition to their Cloud Events Core permissions.

---

## Scenario 1: Installation and activation

1. Open **Extension Management**.
2. Confirm **Origo Cloud Events Subscription Billing** is listed and installed.
3. Confirm the dependency **Origo Cloud Events Core** is installed and appears above it.
4. Open **Users**, select the test user, and confirm the permission set
   **Cloud Events Sub. Billing** can be assigned.

**Expected:** the extension installs with no errors and its permission set is assignable.

---

## Scenario 2: Discovering the message types

1. Invoke the Cloud Events message type **`Help.MessageTypes.Get`** (Core).
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

1. Create a user **without** the `CE Sub Bil Obj ori` permission set (Cloud Events Core access only).
2. Attempt to invoke **`Subscription.Billing.CreateProposal`** as that user.
3. Assign `CE Sub Bil Obj ori` and retry.

**Expected:** without the permission set the call fails with a permission error; with it, the call
succeeds (subject to the user's own permissions on the Subscription Billing tables, which this
extension does not widen).

---

## Scenario 11: Uninstallation

1. Open **Extension Management**.
2. Uninstall **Origo Cloud Events Subscription Billing**.
3. Invoke `Help.MessageTypes.Get` again.

**Expected:** the extension uninstalls without error, the `Subscription.*` message types no longer
appear, and Cloud Events Core and Subscription Billing continue to work normally. No Subscription
Billing data is removed by the uninstall.
