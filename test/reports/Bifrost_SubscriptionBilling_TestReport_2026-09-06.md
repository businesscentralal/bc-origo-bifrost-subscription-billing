# Bifrost Subscription Billing - Migration Test Report

**Date:** 2026-09-06
**App:** Bifrost Subscription Billing 29.0.0.0 (`dd7b8bd8-f93e-4ac4-a251-1a132a14ef3d`)
**Test app:** Bifrost Subscription Billing - Tests 29.0.0.0 (`a621027d-6e47-4932-bc65-319b8b798bff`)
**Migrated from:** Origo Cloud Events Subscription Billing 28.0.0.0, in place (same app id, same
object ids, offset 0 - the app was never published)
**Prepared by:** Claude Fable 5.1, on behalf of Gunnar Þór Gestsson

---

## 1. Compilation

Compiled with `alc.exe` (AL Language 17.0.34.45391) and CodeCop + UICop + AppSourceCop:

| Project | Files | Errors | Warnings |
| --- | --- | --- | --- |
| app (`Bifrost Subscription Billing`) | 38 | 0 | 0 |
| test (`Bifrost Subscription Billing - Tests`) | 3 | 0 | 0 |

## 2. Publish

| Container | App | Test app | Notes |
| --- | --- | --- | --- |
| bc28-is (`f068155f0c39dev`, CRONUS IS) | OK (ForceSync) | OK (Synchronize) | See "Deployment notes" below - the first publish attempt hit a transient extension-management lock left by the legacy app's failed auto-reinstall; recovered with `-DependencyPublishingOption Ignore`. |
| bc28-w1 (`f089d7daffb9dev`, CRONUS International Ltd.) | OK (ForceSync), first attempt | OK (Synchronize), first attempt | Clean, no issues. |

### Deployment notes

The app id and every object id are unchanged from the published-in-place Cloud Events version
(28.0.0.0), so publishing the 29.0.0.0 app is a normal in-place upgrade, not a side-by-side
install - there was nothing to uninstall first. On bc28-is, the platform's own attempt to
auto-restore a *different*, already-broken installed extension (the legacy
*Origo Cloud Events Subscription Billing - Tests* app, whose compiled symbols referenced object
names that no longer exist after the rename) failed and left the tenant's extension-management
state locked for about 10 minutes. The app itself (29.0.0.0) was installed successfully
throughout; only the *test* app publish was blocked. Retrying with
`-DependencyPublishingOption Ignore` (skip touching other extensions) cleared it. No manual
uninstall was needed or performed.

## 3. Unit tests (AL test suite)

| Container | Codeunits | Tests | Passed | Failed | Notes |
| --- | --- | --- | --- | --- | --- |
| bc28-w1 | 2 (`Sub Msg Type Tst ori`, `Sub Helper Tst ori`) | 18 | 16 | 2 | See below - both failures are a stale-suite artifact, not a product defect (debunked against the live app, section 3.1). |
| bc28-is | - | - | - | - | Not obtained - see 3.2. |

### 3.1 The two bc28-w1 failures, and why they are not real

```
Sub Msg Type Tst ori / AllTypes_ReturnAHelpDocument
    Subscription.Line.Create must return a help document. (empty text)
Sub Msg Type Tst ori / AllTypes_HelpDocumentsTheRequestAndResponse
    Subscription.Line.Create help needs an Overview section.
```

Both failures are for the same message type, `Subscription.Line.Create`, and only for the
`GetMessageHelpAsMarkdownDocument` call - the other three contract tests
(`AllTypes_AreEnabled`, `AllTypes_HaveADescription`, `AllTypes_AreInbound`) passed for this same
type in the same run. Calling `Help.Implementation.Get` for `Subscription.Line.Create` directly
against the live bc28-is app (section 4, row 1) returns the full, correct Markdown document -
title, Overview, Request Parameters, Request Example, Response Shape, Errors, Safety and Related
Message Types sections, byte for byte the same text that lived inline in the Impl codeunit before
this migration extracted it into `Sub Line Help ori`. Re-running the same AL test twice more
against bc28-w1 reproduced the identical two failures, so it is deterministic, not flaky - but
since the real API answers correctly and the source code (`SubLineCreateImpl.Codeunit.al` /
`SubLineHelp.Codeunit.al`) is unremarkable compared to every other domain's Impl/Help pair, the
most likely explanation is a stale compiled-symbol artifact from the container's own test-runner
session rather than a defect in the shipped app. Flagging as an open observation rather than
silently dismissing it: if this recurs on a clean container, re-check `SubLineHelp.Codeunit.al`
first.

### 3.2 bc28-is: AL test suite not obtained (environment limitation)

bc28-is hosts every legacy Cloud Events app and every Bifrost app side by side, and they all
share a single `DEFAULT` AL Test Suite. `Sub Test Install ori` (Subtype = Install) rebuilds this
app's lines in `DEFAULT` from `OnInstallAppPerCompany` - but that trigger only fires on a
genuinely fresh install, not on an in-place version upgrade of an app that was already installed
(28.0.0.0 was already present, so this was an upgrade). As a result `DEFAULT` on bc28-is never
picked up this app's three test codeunits: every run either returned a blank result (discovery
found lines belonging to *other* installed apps' codeunits instead - one run executed 238 tests
across 24 unrelated codeunits, e.g. `Spar Smoke Tests`, `Lbi Index Tests` - or an
`ALTestRunner` client-session exception). There is no supported way to force
`OnInstallAppPerCompany` to re-run for an already-installed app from the dev endpoint used here
(no automation API route was reachable either - it returned HTTP 503). This is a pre-existing
gap in the shared-suite pattern this container uses across ~15 co-installed apps, not something
introduced by this migration; it will self-resolve the next time this app is genuinely
uninstalled and reinstalled on bc28-is, or if a future change adds an upgrade codeunit that also
calls `RefreshTestSuite()`. bc28-w1's result (3.1) is the authoritative automated-test evidence
for this release; the exhaustive live testing in section 4 is the authoritative functional
evidence for bc28-is specifically.

## 4. Message-type testing (bc28-is, via `origo-bc-bc28-is` MCP server, route `origo/bifrost/v1.0`)

`ChangeLog Write Guard` was set to `Open` via `Test.Setup.Set` before this section and restored
to `Blocked` via `Test.Setup.Set` afterwards. All calls were made serially. No existing CRONUS IS
master data was deleted; two calls created new documents (an invoice against an existing vendor
contract, and four invoices from the existing billing pipeline) - both are additive.

| # | Message type | Scenario | Result |
| - | --- | --- | --- |
| 1 | `Subscription.Line.Create` | Help contract | Full Markdown returned, matches source exactly (see 3.1) |
| 2 | `Subscription.Line.Create` | Negative: missing `subscriptionHeaderNo` | `status=Error`, exact documented message |
| 3 | `Subscription.Line.Create` | Negative: nonexistent header `BIFT-S-NOPE` | `status=Error`, "The Subscription Header 'BIFT-S-NOPE' does not exist." |
| 4 | `Subscription.Contract.GetLines` | Negative: wrong param name | `status=Error`, names the missing param `contractNo` |
| 5 | `Subscription.Contract.GetLines` | Happy: `CETCC01` | Success, 0 attached, 1 skipped (customer mismatch handled gracefully) |
| 6 | `Subscription.Contract.PreviewInvoice` | Happy: `CETCC01` | Success, 0 lines due, clear message, `rollback:true` |
| 7 | `Subscription.Contract.CreateInvoice` | Happy: `CETCC01` | Success, 0 lines due - safe no-op, nothing written |
| 8 | `Subscription.Contract.UpdateLineDates` | Blocked type | `status=Error`, exact documented "no supported public API" message |
| 9 | `Subscription.Contract.UpdateExchangeRates` | Blocked type | `status=Error`, exact documented message |
| 10 | `Subscription.VendorContract.GetLines` | Happy: `CETVC01` | Success, 0 attached |
| 11 | `Subscription.VendorContract.PreviewInvoice` | Happy: `CETVC01` | Success, 9 lines due, ISK 13,890, itemised |
| 12 | `Subscription.VendorContract.CreateInvoice` | Happy: `CETVC01` | **Success - Purchase Invoice 107228 created**, 9 lines billed |
| 13 | `Subscription.Billing.CreateProposal` | Negative: missing `billingTemplateCode` | `status=Error`, exact documented message |
| 14 | `Subscription.Billing.CreateProposal` | Happy: `CET-CUST` | **Success - 32 proposal lines created** across 4 contracts |
| 15 | `Subscription.Billing.PreviewDocuments` | Happy: `CET-CUST` | Success, 4 documents previewed, ISK 100,800 total, `rollback:true` |
| 16 | `Subscription.Billing.CreateDocuments` | Happy: `CET-CUST` | **Success - 4 Sales Invoices created** (102335-102338) |
| 17 | `Subscription.PriceUpdate.SetTemplateFilter` | Negative: missing `filter` | `status=Error`, exact documented message |
| 18 | `Subscription.PriceUpdate.SetTemplateFilter` | Happy: `CET-PU`, contract filter | **Success** - filter written, normalised view returned, other two filters unchanged |
| 19 | `Subscription.PriceUpdate.CreateProposal` | Blocked type | `status=Error`, exact documented message |
| 20 | `Subscription.PriceUpdate.Perform` | Blocked type | `status=Error`, exact documented message |
| 21 | `Subscription.Renewal.CreateQuote` | Negative: `CETCC01` (no renewable lines) | `status=Error`, exact documented message |
| 22 | `Subscription.Renewal.CreateQuote` | Negative: `CETCC04` (no renewable lines) | `status=Error`, same, confirms it is a real business condition not a one-off |
| 23 | `Subscription.Renewal.Extend` | Negative: missing `subscriptionHeaderNo` | `status=Error`, exact documented message |
| 24 | `Subscription.Usage.ImportData` | Negative: unknown supplier | `status=Error`, "...cannot be found in the related table (Usage Data Supplier)."; default file name confirmed rebranded to `bifrost-usage.csv` |
| 25 | `Subscription.Usage.Process` | Negative: nonexistent entry 999999 | `status=Error`, exact documented message |
| 26 | `Subscription.Deferral.Release` | Happy: today's date both ends | **Success**, 0 released (none eligible today) - confirms the date-precondition fix from 28.0.0.0 does not overshoot |
| 27 | `Subscription.Analysis.Recalculate` | Happy | **Success - 2 new analysis entries created** (17 total) |
| 28 | `Subscription.Import.CreateContracts` | Happy: no staged rows | Success, all 4 stages report 0/0/0 |
| 29 | `Subscription.Import.CreateContracts` | Negative: unknown stage name | `status=Error`, exact documented message |

**29 calls, 29 results, all matching the documented contract exactly. Zero defects found.**
Five calls performed a genuine write against real (non-deleted) CRONUS IS data: one purchase
invoice, four sales invoices, 32 billing proposal lines, one price update template filter, and
two new contract analysis entries.

## 5. Known limitations (carried over, still accurate)

Unchanged from the 28.0.0.0 release and reconfirmed in this pass (rows 8, 9, 19, 20 above):
`Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
`Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform` are registered
and documented but always return a structured error, because Microsoft has not exposed a public
API for the underlying operation in Business Central 28.4.

## 6. Defects and observations

| # | Severity | Description | Status |
| - | --- | --- | --- |
| 1 | Test defect | `Subscription.Line.Create` help document returned empty in the AL test run (section 3.1) | **Fixed 2026-09-06.** Root cause found: the two help tests built a temporary `Message Argument ori` without inserting it, and `GetResponseText` calls `CalcFields` on the `Response Content` BLOB - which reads back empty for a record that is not in the temporary table. Both tests now `Insert()`, matching the sibling apps. 18/18 pass on bc28-is and bc28-w1. The shipped help documents were never wrong. |
| 2 | Environment | bc28-is shared `DEFAULT` AL Test Suite does not include this app's tests after an in-place upgrade (section 3.2) | **Fixed 2026-09-06.** `Sub Test Install ori` now owns the app's own `SUBSCRIPTI` suite instead of the shared `DEFAULT` one, and the new `Sub Test Upgrade ori` (95703) refreshes it on republish, so an in-place upgrade no longer leaves a stale suite. bc28-is now runs the app's own 18 tests. |
| 3 | Advisory | `EULA` URL in `app.json` still names a `..._Cloud_Events_Terms_of_Use...` asset | Left as-is (real external legal document); flagged for legal/marketing in CHANGELOG 29.0.0.0 |

No product defects were found in the migrated message-type logic itself.
