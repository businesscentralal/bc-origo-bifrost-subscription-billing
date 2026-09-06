# Changelog

All notable changes to Bifrost Subscription Billing are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) aligned to the Business Central
major version.

## [29.0.0.0] - 2026-09-06

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
performs the operation today. See `app/docs/Message-Types.md` for the detail.

### Notes

- No message type deletes data. Ending a subscription is modelled as an end date or a closed flag
  through the Core `Data.Records.Set` message type, not as a hard delete.
- Reads and simple header or line writes are intentionally absent; the Core `Data.Records.Get` and
  `Data.Records.Set` message types already cover them.
