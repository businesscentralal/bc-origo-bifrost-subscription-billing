# Changelog

All notable changes to Bifrost Subscription Billing are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) aligned to the Business Central
major version.

## [29.0.0.0] - 2026-09-06

### Changed (2026-09-07) - tests run on Foundation's public API

- The test app no longer depends on Bifröst Foundation's internals: Bifrost Subscription Billing - Tests has been removed
  from Foundation's `internalsVisibleTo`, and the test suite compiles and runs against a Foundation
  package that does not grant it. No test code had to change - the suite never touched a Foundation
  internal.

### Setup notifications and wizard (2026-09-07)

- Across the Bifröst family, setup notifications now live only on Bifröst Foundation's **Bifrost
  Setup** page, and their only action is "Start setup wizard". A dependent app never raises a
  notification of its own; it makes itself known to Foundation instead.
- New codeunit 10035060 `Sub Registration ori` (internal) subscribes once to
  `App Registry ori.OnRegisterApps` and calls `AddApp` with this app's own module id, its display
  name and setup page id `0` - this app has no setup page. Foundation's registry then reports its
  HTTP status and credential counts alongside every other Bifröst app.
- Nothing was removed: this app never raised a setup notification and has no notification-action
  codeunit.
- New test codeunit 95704 `Sub Registration Tst ori` asserts that Bifrost Subscription Billing
  appears in `App Registry ori.GetApps` under the module id resolved from the test app's own
  dependency list, so the registration cannot be dropped unnoticed.

### Release notes

- **Version 29.0.0.0, not 28.x.** The predecessor *Origo Cloud Events Subscription Billing* had
  already reached 28.x, and this is an in-place successor with the same app id, so the version had
  to move forward. The sibling Bifröst apps sit at 28.x because they are new app identities. The
  app still targets `application`/`platform` 28.0.0.0 and runtime 17.0 - the major number is a
  release counter here, not a Business Central version.
- **This app adds no setup surface of its own, on purpose.** It has no setup table, no setup page,
  no secrets and no outbound HTTP: every message type calls Microsoft's Subscription Billing app
  in-process, and everything it needs is configured in Microsoft's own Subscription Billing setup.
  There is therefore no `Apps` group action and no Secret Store registration, unlike the sibling
  connectors that talk to an external service. It does register itself with Foundation's
  `App Registry ori` (setup page id `0`) so the Bifröst Setup page can list it.
- **`EULA` in `app.json` still points at the Cloud Events terms of use**
  (`..._Origo_BC_Cloud_Events_Terms_of_Use_-1-.pdf`). That is a real external legal document; it is
  left untouched until legal/marketing publish a Bifröst version.

### Known issues

- Four message types are registered and discoverable but always return a structured error instead
  of performing the operation, because Microsoft exposes no public API for them in Business Central
  28.4: `Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
  `Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform`. The procedures
  that would have to become public (`Customer Subscription Contract.UpdateServicesDates()`,
  `Subscription Header.UpdateServicesDates()`, codeunit 8058 `Update Sub. Lines Term. Dates`, and
  the price-update equivalents) are `internal` in Microsoft's app. Each error names them and points
  at the client action that does the job today. They stay registered so the contract is discoverable
  and so they start working the moment Microsoft opens the API; re-verified in the 2026-09-06
  end-to-end run (rows 8, 9, 19, 20 of the test report).

### Security (2026-09-07)

- `Subscription.VendorContract.CreateInvoice` stamped the caller's `vendorInvoiceNo` onto the
  purchase document by assigning the field directly. That skipped the field's own validation, which
  is where Business Central enforces the vendor's duplicate-invoice-number control - the same
  vendor invoice number could be booked twice under two different documents. The value now goes
  through `Validate`, so a duplicate is refused the way it is refused in the user interface.
- `Subscription.PriceUpdate.SetTemplateFilter` passed the caller's `filter` straight into
  `RecordRef.SetView`. A malformed view raised Business Central's own parser error, which names
  neither the parameter that was wrong nor the shape it should have had, and can quote internals of
  the table being opened. The call is now guarded and answers with the documented contract instead.
- `Subscription.Usage.Process` read the entry number out of the message subject with an unguarded
  `Evaluate`. A subject that is not a number now produces a message that names the subject and the
  two ways to supply the entry number, instead of a raw conversion error.
- `Subscription.Contract.GetLines` read `subscriptionLineEntryNos` without checking that each
  element was a value, and built an unbounded filter expression from it. Both `GetLines` types now
  share one helper that rejects anything that does not read as a whole number and keeps the filter
  inside the length Business Central allows - covered by five new unit tests.

### Performance (2026-09-07)

- `Subscription.Billing.CreateDocuments` compared every Billing Line it read back against a list of
  the entry numbers it had consumed, once per row against everything already accumulated. The three
  running sets are dictionaries now, so each test is a single lookup rather than a walk. Its two
  partner probes ask `IsEmpty` instead of `Count`, since only the answer "any at all" was used.
- `Subscription.Billing.PreviewDocuments` grouped the proposal by reading the table once to collect
  the group keys and then twice more per group - a `Count` and a `FindSet` each. It is one pass now,
  accumulating per group as the rows arrive, with the reporting order unchanged.
- `Subscription.Deferral.Release` counted unreleased deferrals up to twelve times per call on two
  columns that carry no index. The four pre-run counts are taken once and the over-release
  precondition reuses two of them.
- `Subscription.Contract.GetLines` read the Subscription Header once per candidate line to compare a
  single field. The answer is now read once per header and remembered, with `SetLoadFields` on it.
- `Subscription.VendorContract.GetLines` read every unassigned Subscription Line and sorted out the
  caller's selection in memory. The selection is pushed into the database filter instead.
- `SetLoadFields` added to nine watermark and scan reads that use one or two fields
  (`Sub Ana Recalc`, `Sub Line Create`, `Sub Con CrInvoice`, `Sub Con PrvInvoice`,
  `Sub Vend CrInvoice`, `Sub Vend PrvInv`, `Sub Ren CrQuote`, `Sub Bil PrvDocs`).

### Fixed (2026-09-07)

- Icelandic translations for the `Subscription.Contract.UpdateLineDates` and
  `Subscription.Contract.UpdateExchangeRates` known-issue errors quoted the Business Central client
  action names in plain English quotes. They now use Icelandic quotation marks with the English
  name kept in parentheses for clarity: `„Uppfæra dagsetningar áskriftarlína“ ("Update Subscription
  Line Dates")` and `„Uppfæra gengi“ ("Update Exchange Rates")`.
- The same two Icelandic strings read "Subscription Billing appi Microsoft" - "appi" used as a
  stray separate word instead of the correct Icelandic dative compound. Fixed to "Subscription
  Billing-forriti Microsoft".

### Fixed (2026-09-06)

- `AllTypes_ReturnAHelpDocument` and `AllTypes_HelpDocumentsTheRequestAndResponse` never actually
  exercised the help documents: they built a temporary `Message Argument ori` without inserting it,
  and `GetResponseText` calls `CalcFields` on the `Response Content` BLOB, which reads back empty
  for a record that is not in the (temporary) table. Both tests now `Insert()` the record, matching
  the sibling apps. This was observation 1 in the 2026-09-06 test report - a test defect, not an app
  defect; the shipped help documents were always correct, which is why the live API returned them.
- The test app no longer builds its lines into the shared `DEFAULT` AL Test Suite. `Sub Test
  Install ori` now owns the `SUBSCRIPTI` suite - the name `tools/Run-BifrostTests.ps1` derives from
  the test app name - and a new `Sub Test Upgrade ori` (95703) refreshes it on republish. Without
  the upgrade codeunit an in-place version upgrade never re-ran `OnInstallAppPerCompany`, so on
  bc28-is the suite kept other apps' test codeunits and this app's tests were never discovered
  (observation 2 in the 2026-09-06 test report).

### Changed (2026-09-06)

Documentation consolidated onto the Bifröst documentation site.

- All public documentation moved to <https://businesscentralal.github.io/bifrost>. Product documentation is at
  `/en-us/subscription-billing/` and in-product help at `/en-us/help/subscription-billing/`, both
  available in English and Icelandic. The `app/docs/` folder is gone; this repository now keeps only
  `README.md`, `CHANGELOG.md` and code.
- `help` and `contextSensitiveHelpUrl` in `app/app.json` repointed from the retiring
  `origopublic.blob.core.windows.net` storage account to
  <https://businesscentralal.github.io/bifrost>, where the site is actually published. They move to
  `bifrost.origo.is` once that DNS record exists. `supportedLocales` is unchanged
  (`en-US`, `is-IS`).
- The end-to-end message-type test report moved from `app/docs/` to `test/reports/`. It is internal
  and is not published to the documentation site.
- The one-off developer scripts (`scripts/build.sh`, `deploy.sh`, `getsymbols.sh`, `mcp.sh`) removed.
  Build locally with `alc.exe` and publish with the Bifröst tooling described in the README.

### Changed

Migrated from *Origo Cloud Events Subscription Billing* to **Bifrost Subscription Billing**,
following the same procedure used for the other Cloud Events -> Bifrost apps
(`bc-origo-bifrost-core/tools/migration/MIGRATION_GUIDE.md`). The app was never published, so
the app id and every object id keep their identity (offset 0) - this is an in-place rename, not
a side-by-side install.

- Namespace `Origo.APP.CloudEvents.SubscriptionBilling` -> `Origo.Bifrost.SubscriptionBilling`
  (tests: `Origo.Bifrost.SubscriptionBilling.Test`).
- Dependency on *Origo Cloud Events Core* replaced by **Bifrost Foundation** 28.0.0.0.
- Every object loses its `CE ` prefix; the `Sub`/`Bil`/`Con`/`Vend`/`PU`/`Ren`/`Usg`/`Def`/`Ana`/
  `Imp` abbreviations are unchanged. Renames (old -> new):

  | Old | New |
  | --- | --- |
  | `CE Sub Line Create Impl ori` | `Sub Line Create Impl ori` |
  | `CE Sub Con GetLines Impl ori` | `Sub Con GetLines Impl ori` |
  | `CE Sub Con CrInvoice Impl ori` | `Sub Con CrInvoice Impl ori` |
  | `CE Sub Con PrvInvoice Impl ori` | `Sub Con PrvInvoice Impl ori` |
  | `CE Sub Con UpdDates Impl ori` | `Sub Con UpdDates Impl ori` |
  | `CE Sub Con UpdFCY Impl ori` | `Sub Con UpdFCY Impl ori` |
  | `CE Sub Vend GetLines Impl ori` | `Sub Vend GetLines Impl ori` |
  | `CE Sub Vend CrInvoice Impl ori` | `Sub Vend CrInvoice Impl ori` |
  | `CE Sub Vend PrvInv Impl ori` | `Sub Vend PrvInv Impl ori` |
  | `CE Sub Bil CrProposal Impl ori` | `Sub Bil CrProposal Impl ori` |
  | `CE Sub Bil CrDocs Impl ori` | `Sub Bil CrDocs Impl ori` |
  | `CE Sub Bil PrvDocs Impl ori` | `Sub Bil PrvDocs Impl ori` |
  | `CE Sub PU SetFilter Impl ori` | `Sub PU SetFilter Impl ori` |
  | `CE Sub PU CrProposal Impl ori` | `Sub PU CrProposal Impl ori` |
  | `CE Sub PU Perform Impl ori` | `Sub PU Perform Impl ori` |
  | `CE Sub Ren Extend Impl ori` | `Sub Ren Extend Impl ori` |
  | `CE Sub Ren CrQuote Impl ori` | `Sub Ren CrQuote Impl ori` |
  | `CE Sub Usg Import Impl ori` | `Sub Usg Import Impl ori` |
  | `CE Sub Usg Process Impl ori` | `Sub Usg Process Impl ori` |
  | `CE Sub Def Release Impl ori` | `Sub Def Release Impl ori` |
  | `CE Sub Ana Recalc Impl ori` | `Sub Ana Recalc Impl ori` |
  | `CE Sub Imp CrContr Impl ori` | `Sub Imp CrContr Impl ori` |
  | `CE Sub Helper ori` | `Sub Helper ori` |
  | `CE Sub Write Process ori` | `Sub Write Process ori` |
  | `CE Sub Msg Type ori` (enum extension) | `Sub Msg Type ori` |
  | `CE Sub Bil Obj ori` (permission set) | `BIFROST SubBil ori` |
  | `CE Sub Bil Full ori` (permission set ext.) | `BIFROST SubBFull ori` |
  | `CE Sub Bil Read ori` (permission set ext.) | `BIFROST SubBRead ori` |

  Message type keys (`Subscription.<Domain>.<Action>`) are unchanged - they are the external API
  contract.

- Help text for all 22 message types moved out of their Impl codeunits into 10 new per-domain
  Help codeunits (`Sub <Domain> Help ori`, ids 10035065-10035074: Line, Con, Vend, Bil, PU, Ren,
  Usg, Def, Ana, Imp), matching the domain-help pattern used by Bifrost Foundation and Bifrost
  Nornir. Each Impl codeunit's `GetMessageHelpAsMarkdownDocument` now delegates to its domain's
  Help codeunit; the Markdown text itself is unchanged.
- No setup table or setup page extension existed in the Cloud Events version of this app, so
  there was nothing to move out of Foundation's `Setup ori` page for this migration.
- App renamed to **Bifrost Subscription Billing**, custom logo, help/contextSensitiveHelpUrl
  updated to the `BifrostSubscriptionBilling` blob path. One Icelandic caption paraphrase
  ("Atburðir í skýinu - áskriftir") was found and replaced with "Bifröst - áskriftir"
  (`BIFROST SubBil ori`); no other Icelandic paraphrases of the old brand were found.
- Repository renamed from `origo-bc-cloudevents-subscriptionbilling` to
  `bc-origo-bifrost-subscription-billing`.

### Notes

- The `EULA` URL still points at a document named `..._Cloud_Events_Terms_of_Use...` on the
  Origo CDN - left as-is because it is a real external legal document, not a code artifact;
  flag for legal/marketing to reissue under the Bifrost name on their own schedule.
- A Foundation-wide "Apps" action group (for setup pages like this one to hang an action off of)
  and a Foundation-wide secret store are both being built in parallel; this app has no setup page
  today, so neither applies yet.

## [28.0.0.0] - 2026-09-01

### Added

Initial release. Adds Bifrost message types for the Microsoft Dynamics 365 Business Central
Subscription Billing app, so an agent can drive Subscription Billing without manual UI steps.

Message types, all named `Subscription.<Domain>.<Action>`:

- **Commitments** - `Subscription.Line.Create`
- **Customer contracts** - `Subscription.Contract.GetLines`, `Subscription.Contract.CreateInvoice`,
  `Subscription.Contract.PreviewInvoice`, `Subscription.Contract.UpdateLineDates`,
  `Subscription.Contract.UpdateExchangeRates`
- **Vendor contracts** - `Subscription.VendorContract.GetLines`,
  `Subscription.VendorContract.CreateInvoice`, `Subscription.VendorContract.PreviewInvoice`
- **Billing pipeline** - `Subscription.Billing.CreateProposal`,
  `Subscription.Billing.CreateDocuments`, `Subscription.Billing.PreviewDocuments`
- **Price updates and indexation** - `Subscription.PriceUpdate.SetTemplateFilter`,
  `Subscription.PriceUpdate.CreateProposal`, `Subscription.PriceUpdate.Perform`
- **Renewal and lifecycle** - `Subscription.Renewal.Extend`, `Subscription.Renewal.CreateQuote`
- **Usage-based billing** - `Subscription.Usage.ImportData`, `Subscription.Usage.Process`
- **Deferrals, analysis and migration** - `Subscription.Deferral.Release`,
  `Subscription.Analysis.Recalculate`, `Subscription.Import.CreateContracts`

### Fixed before first release

Found by running every message type against a Business Central 28.4 container and corrected
before submission:

- `Subscription.VendorContract.GetLines` ignored `subscriptionLineEntryNos` and attached every
  eligible Subscription Line instead of the ones named. Array parameters are now read through
  one shared helper that also rejects a value that is present but is not an array, rather than
  silently falling back to the default - the same helper now backs `subscriptionPackageCodes`,
  `steps` and `stages`.
- `Subscription.Billing.CreateDocuments` started a fresh copy of Microsoft's document-creation
  codeunit instead of the configured one, so the interactive "Create Customer Billing Docs"
  request page opened and the call failed outright in an unattended session.
- `Subscription.Contract.CreateInvoice` and `Subscription.VendorContract.CreateInvoice`
  reported the documents and line counts of *earlier* runs when Business Central billed
  nothing new. They now report only what the call produced and say so when nothing was billed;
  the vendor type additionally no longer re-stamps `vendorInvoiceNo` onto an earlier document.
- `Subscription.Billing.CreateDocuments` reported no documents at all when `postDocuments` was
  true, because posting archives the proposal rows it read them back from. It now reads the
  posted documents from the Billing Line Archive and marks each with `"posted": true`. When the
  run fails part way through it now names the documents Business Central had already committed
  and returns `"rolledBack": false`, instead of failing without saying what survived.
- `Subscription.Renewal.CreateQuote` aborted with Business Central's generic *"An error
  occurred and the transaction is stopped"* whenever Microsoft's renewal codeunit failed,
  because it caught that codeunit's error after having already written the renewal lines.
- `Subscription.Usage.ImportData` stamped the Usage Data Blob as already imported, so Microsoft's
  connector skipped it and asked the client to upload a file - a callback that cannot be
  answered in an unattended session.
- `Subscription.Usage.Process` reported each stage using the status Business Central had left
  standing from the previous stage, so a stage that succeeded after an earlier failure was
  reported as an error carrying the earlier stage's message. It also gained a
  `CreateImportedLines` step, so a file whose first parse failed on a setup problem can be
  re-parsed without re-sending it.
- `documentType` and `processingStatus` came back as the caller's language caption, or as a
  bare enum ordinal. Both are now stable English tokens an integration can switch on.
- The `BIFROST SubBFull ori` permission set extension granted execute rights on only two
  codeunits, so a user with full Bifrost access could not actually invoke any Subscription
  Billing message type.
- `Subscription.Deferral.Release` accepted `postingDate` and `postUntilDate` and silently ignored
  both. Microsoft's report takes them from its request page, which an external app cannot set, so
  the report released everything eligible up to the work date and posted it under the work date -
  while the response reported only the count inside the window the caller asked for. Asking to
  release up to 2026-03-31 released 29 customer deferrals up to 2026-09-01 and reported 9. The
  two dates are now enforced as a precondition: the call is refused when the report would post
  under a different date or reach past `postUntilDate`, the counts cover every deferral actually
  released, and a run that overshoots anyway is flagged in the response.

### Known limitations

Four message types are registered and discoverable but return a structured error explaining that
Microsoft has not exposed a public API for the operation in Business Central 28.4. They are
`Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
`Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform`. Each error names
the exact Microsoft procedure that would need to become public and points to the client action that
performs the operation today. See
<https://businesscentralal.github.io/bifrost/en-us/subscription-billing/message-types> for the detail.

### Notes

- No message type deletes data. Ending a subscription is modelled as an end date or a closed flag
  through the Core `Data.Records.Set` message type, not as a hard delete.
- Reads and simple header or line writes are intentionally absent; the Core `Data.Records.Get` and
  `Data.Records.Set` message types already cover them.
