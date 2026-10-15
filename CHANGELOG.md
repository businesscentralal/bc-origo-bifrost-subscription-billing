# Changelog

## Unreleased

### Changed (2026-10-11) - CI compiles on Business Central 28.5

- `.AL-Go/settings.json` sets `artifact` to `/sandbox/28.5.54151.55751/w1/latest`. AL-Go reads that as the default storage account, type sandbox, version 28.5.54151.55751, country w1, and select latest, so pull request builds and CI/CD compile on that Business Central 28.5 sandbox artifact.
- The same file is listed in `fullBuildPatterns`. An incremental pull request build otherwise leaves `.AL-Go/settings.json` out of the project folders it compares, skips compilation, and reports success against the previous BC 29 artifacts.
- `app/app.json` and `test/app.json` already set `runtime` to `17.0` and `application` and `platform` to `28.0.0.0`. The app version stays 29.0.0.0.
- `.github/Test Current.settings.json` sets the same artifact, `/sandbox/28.5.54151.55751/w1/latest`. That workflow file overrides the project setting, and it previously selected `////latest`.
- Test Next Minor and Test Next Major keep `////nextminor` and `////nextmajor`. `.github/AL-Go-Settings.json` does not set `artifact`.

### Fixed (2026-10-10) - UAT dependency installation

- UAT feature-app deployment uses the Foundation app already deployed by its own pipeline in Dev scope, avoiding an unauthorized AppSource Foundation installation. `.github/AL-Go-Settings.json`: `DeployToBifrost.DependencyInstallMode = "ignore"`. AppSource delivery is unchanged; no AL objects or IDs change.

### Fixed (2026-10-09) - test app object ID collision (PR #32, follow-up to #30)

- `Sub Bil PrvDocs SkipTst ori` is renumbered from 95705 to 95709 in the test app.
  It collided with `Sub Imp CrContr Tst ori` (95705, #30), so the test app failed to
  compile with AL0264 "already declared" on main and on PR #32. Both suites, names,
  assertions and behavior are unchanged; the 95709 allocation is verified free against
  the full main tree 4ba0248 and the `.claude/CLAUDE.md` free-ID ledger, which is updated.
- `tools/Test-ObjectIdsUnique.ps1` is the Source Guards `ObjectIdsUnique` job.
  It scans `app/src` and `test/src` and fails when the same object type and ID
  are declared twice in one app. A table and a page may share a number. App and
  test are separate apps. The Python harness is not part of the repo.
- `CommentLineTypeFailsSubscriptionLinesStage` stores its request on an inserted temporary
  `Message Argument ori` before `PerformWrite`. `GetRequestJson` otherwise reads an empty
  blob and fails with "The data does not represent a valid JSON token." The assertion is unchanged.

### Changed (2026-10-04) - CI/CD builds only main; every pull request gets a Pull Request Build

- Build policy only, no app change. `CI/CD` runs on pushes to `main` only, and `Pull Request Build` runs for pull requests into any branch. `.github/AL-Go-Settings.json` sets `CICDPushBranches` to `main` and `CICDPullRequestBranches` to `**`, so Update AL-Go System Files keeps the triggers.

## [Unreleased]

### Added (2026-10-15) - behaviour tests that drive Microsoft Subscription Billing (#43)

- Six test codeunits seed their own customers, vendors, items, packages, Subscriptions, contracts and templates through `Sub Test Library ori` (95770) and run the types' writes, asserting on the records Microsoft's logic writes, not only on the response:
  - `Sub Line GetLines Tst ori` (95773): Line.Create applies a package with the requested start, end and next billing dates; an unknown package is refused; usageBasedBillingPackageLinesOnly skips the other lines. Contract.GetLines and VendorContract.GetLines attach all candidate lines or only the selected entry numbers, and a line of another customer is skipped.
  - `Sub Invoice Tst ori` (95774): Contract.CreateInvoice and VendorContract.CreateInvoice create an unposted sales and purchase invoice with the billed amount, linked from the billing lines (vendorInvoiceNo lands on the purchase invoice); nothing due bills nothing; an unknown contract is refused. Both PreviewInvoice types leave the counts of billing lines and sales or purchase headers unchanged.
  - `Sub Billing Run Tst ori` (95775): Billing.CreateProposal adds a proposal line for the template's contract; Billing.CreateDocuments with postDocuments = true posts the sales invoice and leaves the purchase invoice unposted; a template without proposal lines answers nothing pending; an unknown template is refused.
  - `Sub Renewal Tst ori` (95776): Renewal.Extend adds the standard and the extra package's lines, starting on the Provision Start Date, onto the contract; without a contract it is refused. Renewal.CreateQuote builds a renewal sales quote with lines for a contract whose line has an end date, and refuses open-ended lines.
  - `Sub Usage Tst ori` (95777): a one-row generic CSV runs through Usage.ImportData (runProcessing) and Usage.Process to Usage Data Billing rows for the usage-based contract line, with the imported quantity; missing content and an unknown step are refused.
  - `Sub Deferral Analysis Tst ori` (95778): Deferral.Release releases the deferral of a posted contract invoice on the work date and posts a G/L entry with the release source code; another posting date or a postUntilDate after it is refused. Analysis.Recalculate adds one entry for the contract and nothing the second time in the same month.
- `Renewal.Extend` does not move contract terms or Subscription Line end dates: Microsoft's Extend Sub. Contract Mgt. adds new Subscription Lines from the item's packages and attaches them to the contracts. The test asserts that behaviour, which is what the type's help already says.

### Fixed (2026-10-15) - help links follow the documentation rules (#27)

- `app/app.json` links move to the public site, as DOCUMENTATION-RULES (bifrost-support, Addresses) requires: `help` is `https://docs.bifrost.origo.is/en-us/subscription-billing/` (the app page that bifrost#104 publishes), and `privacyStatement` and `EULA` are `https://docs.bifrost.origo.is/en-us/licensing/privacy/` and `.../licensing/eula/`, as for Foundation and Attachments. The version is unchanged.
- The app has no Business Central pages, so the site has no help instance for it. `contextSensitiveHelpUrl` cannot be removed, because AppSourceCop requires it (AS0051 is an error), so it now points at the app's own page, `https://docs.bifrost.origo.is/{0}/subscription-billing/`, instead of the help instance `.../{0}/help/subscription-billing/` that does not exist and never will.
- `tools/Test-HelpLinks.ps1` checks the app.json links too: `help`, `privacyStatement` and `EULA` must be on `https://docs.bifrost.origo.is/`, and `contextSensitiveHelpUrl` must be the help instance when the app has pages and the app page when it has none. For an app without pages it no longer needs `-DocsPath`, because there is no help page to look up; with pages it checks every slug in both locales as before. It passes for the repo.

### Fixed (2026-10-15) - ContractParameterKeys guard passes for the repo (#26)

- `tools/Test-ContractParameterKeys.ps1` reported 388 problems on main. Two code structures hid each type's own keys from it; the contracts and the code otherwise agreed. The guard itself is unchanged and now passes with no allow-list (`Every contract parameter is a key the code reads, and every key the code reads is declared (0 allow-listed).`); its self-tests pass.
- Reads: every Impl ran its write through `Sub Write Process ori` (10035059), whose dispatcher called the `PerformWrite` of all 18 types, so each type appeared to read every other type's keys. Each Impl now has `TableNo = "Message Argument ori"` and an `OnRun` that calls its own `PerformWrite`, and `ExecuteBifrostTask` runs `Codeunit.Run(Codeunit::"<the Impl>", Argument)`. The isolation is the same (a failed write rolls back on its own and is answered with `RespondWithLastError`; `Omit Commit` still runs inline). `Sub Write Process ori` is deleted and its id 10035059 is free.
- Declarations: `Sub Contract Parts ori` (10035075) built every type's parameters in one `GetParameters` case over type names, through helpers that took the key as a variable. Each domain now has its own procedure (`LineCreateParameters`, `GetLinesParameters`, `InvoiceParameters`, `BillingProposalParameters`, `BillingDocumentsParameters`, `BillingPreviewParameters`, `SetTemplateFilterParameters`, `RenewalExtendParameters`, `RenewalQuoteParameters`, `UsageImportParameters`, `UsageProcessParameters`, `DeferralReleaseParameters`, `AnalysisParameters`, `ImportParameters`) that names its keys literally in `ContractMgt.Parameter`, and each Impl's `GetParameters` calls its own. The parameter texts, types, defaults and allowed values are unchanged. `GetParameters(MessageType)` stays for the four blocked types and returns no parameters.
- `Sub Helper ori`.`GetSubjectOr` takes the request and the key first (`GetSubjectOr(RequestJson, 'contractNo', Argument, true)`), like every other reader, so a key read from the subject or the request counts as a read (Renewal.CreateQuote reads nothing else).
- `BIFROST SubBil ori` no longer lists the deleted codeunit.

### Changed (2026-10-15) - help states the setup preconditions per type (#44, part)

- `Sub Contract Parts ori` (10035075) adds a precondition to the effect chapter of the 14 types that read Subscription Billing records they do not create (Line.Create, the six customer and vendor contract types, the three Billing types, Renewal.Extend and Renewal.CreateQuote, Usage.ImportData and Import.CreateContracts): the record must exist, and writing it with `Data.Records.Set` needs the Bifrost Setup write guard Open or Change Log coverage, because the guard is Blocked by default. Usage.Process, Deferral.Release and Analysis.Recalculate need no prepared record and say nothing more.
- Checked: no running type's contract claims end-to-end operation, indexation or a Business Central version. None of these types suggests the job queue route, so none needs BIFROST Force ori.
- Left to the branches that rewrite them: the help, errors and effect of `Contract.UpdateLineDates`, `Contract.UpdateExchangeRates` and the three PriceUpdate types (the "Business Central 28.4" wording and the irreversible effect of the blocked types), and the README's Known issues section. The `app.json` description is release-manager territory.
- Tests: `Sub Help Accuracy Tst ori` (95772) asserts the precondition on the 14 types, its absence on the three others, and the absence of end-to-end, indexation and version claims.

### Changed (2026-10-15) - Icelandic glossary for customers, vendors, contracts and posting (Gunnar 14.10, core#702)

- 37 `is-IS=` comments in 12 implementation codeunits follow the Bifröst glossary: the BC Customer is `viðskiptamaður` (was `viðskiptavinur`), the BC Vendor is `lánardrottinn` (was `birgir`), and posting is `bóka` throughout (`bókar`, `óbókaður`, `bókað`; was `bókfæra`).
- The contract records have one name each: `áskriftarsamningur viðskiptamanns` (Customer Subscription Contract; was also `viðskiptavinasamningur`, `viðskiptasamningur` and `áskriftarsamningur viðskiptavinar`) and `áskriftarsamningur lánardrottins` (Vendor Subscription Contract, as in Microsoft's caption; was `birgjasamningur` and `birgjaáskriftarsamningur`). Microsoft's own Subscription Billing caption for the customer contract says `viðskiptavinar`; the Bifröst glossary's BC Customer word wins here so one word names the customer everywhere.
- The labels of `Contract.UpdateLineDates`, `Contract.UpdateExchangeRates` and the three PriceUpdate types are left to the branches that rewrite those types.
- The is-IS xlf is regenerated.

### Fixed (2026-10-15) - BIFROST SubBFull ori grants what the message types call (#42)

- `BIFROST SubBFull ori` (permissionsetextension 10035063 on `BIFROST Full ori`) listed 23 codeunits and missed `Sub Contract Parts ori` (10035075), which `Sub Ana Recalc Impl ori`, `Sub Bil CrDocs Impl ori`, `Sub Bil CrProposal Impl ori` and `Sub Bil PrvDocs Impl ori` call. It now has `IncludedPermissionSets = "BIFROST SubBil ori"` instead of its own list, so the full set grants exactly what `BIFROST SubBil ori` grants and the two cannot drift again. New objects go into `BIFROST SubBil ori` only.
- `BIFROST SubBil ori` (10035062) also grants `Sub Registration ori` (10035060), the subscriber that registers the app with Foundation's App Registry.
- Tests: `Sub Perm Full Tst ori` (95771, TestPermissions Restrictive) builds the contracts of the four types and the chapters of `Sub Bil CrProposal Impl ori` with only `BIFROST Full ori` in the session. The test app depends on Microsoft's Permissions Mock for `Library - Lower Permissions`.

### Fixed (2026-10-15) - Import.CreateContracts imports explicit comment lines again (#39, closes #6)

- `Subscription.Import.CreateContracts` (`Sub Imp CrContr Impl ori`, 10035057) reads a new optional request flag `allowCommentLines` (boolean, default false). With it, staged `Imported Subscription Line` rows whose `Sub_ContractLineType` is Comment are skipped by the SubscriptionLines stage and turned into contract comment lines by the ContractLines stage, through Microsoft's `Create Sub. Contract Line`. Comment is also the value of a row whose line type was never set, so the opt-in is how the caller says the Comment rows are meant.
- Without the flag the #6 guard is unchanged: a Comment row fails the SubscriptionLines stage with `LineTypeRequiredErr`, whose text now names the real line types (Item, G/L Account, or Comment with `allowCommentLines`). A call that runs ContractLines without SubscriptionLines refuses such a row in ContractLines too, so an omitted line type never becomes a comment line.
- When the call also runs SubscriptionLines, the ContractLines stage skips the rows that stage failed (a Comment row without the opt-in, or a row whose Subscription Line was not created). The default four-stage call therefore no longer leaves a comment contract line behind for a failed row (#6 decision d, AC-8).
- Every stage entry in the response carries a new `skipped` count. The contract chapters (parameters, response, effect, notes and a comment-line example) document the flag and the line type rules.
- `RunSubscriptionLines` no longer calls `SetLoadFields` twice on a record it then modifies and passes to Microsoft's codeunit.
- Tests: `Sub Imp CrContr Tst ori` (95705) covers an omitted type refused, the default call creating no contract line, ContractLines alone refusing a Comment row, an opted-in Comment row creating the comment line, an explicit Item row creating its Subscription Line, and the documented parameter. New shared seeding codeunit `Sub Test Library ori` (95770).
- The is-IS xlf is regenerated, which also adds the two units main was missing.

### Fixed (2026-10-06) - price update filter validation and Icelandic keywords (PR #25)

- `Sub PU SetFilter Impl ori` (10035048) validates the caller's `filter` with
  Foundation's `Message Argument ori.ApplyTableView` before applying or storing it.
  Invalid views return a structured error and preserve all template filters.
  `Sub PU Filter Tst ori` (95708) covers valid customer/vendor/subscription/line views,
  malformed and unknown fields, required values and explicit clearing.
- `Sub PU CrProposal Impl ori` (10035049) uses distinct Icelandic search terms;
  the regenerated translation matches the AL source and Developer note.

### Changed (2026-10-05) - align with Bifrost Foundation 28.0.1

- The Foundation dependency floor is **28.0.1.0** in `app/app.json` and `test/app.json`, the same floor as Bifrost Language Models and Bifrost Attachments.
- `tools/` carries Foundation's source guards. The Source Guards workflow runs the checks that already pass on Attachments: no call stack in answers, validated table views, no obsolete, permission coverage, and Icelandic keyword counts. Contract-parameter and mixed-language guards are copied but not wired in.
- Help Links is not wired in until `businesscentralal/bifrost` main has `help/subscription-billing/`.


### Fixed (2026-10-01) - Billing.CreateProposal is irreversible (issue #22)

- `Subscription.Billing.CreateProposal` now declares effect `irreversible`. Microsoft Subscription
  Billing's `CreateBillingProposal` commits the proposal lines every `CommitBatchSize` (50) contracts,
  so the run cannot roll back with the caller's transaction. The `changes` text and the notes say so.
- The contract test asserts the new effect and that the six types that only write inside the caller's
  transaction (Line.Create, Contract.GetLines, VendorContract.GetLines, PriceUpdate.SetTemplateFilter,
  PriceUpdate.CreateProposal, Analysis.Recalculate) stay `write`, and the three previews stay `read`.

### Removed (2026-10-01) - markdown help (issue #19)

- `GetMessageHelpAsMarkdownDocument` is gone from all 22 message type codeunits, following its
  removal from Foundation's `Msg Interface ori` (core#198). Every type describes itself only through
  its contract chapters, which `Help.Implementation.Get` returns.
- Deleted the ten markdown help codeunits `Sub <Domain> Help ori` (ids 10035065-10035074, now free)
  and their permission lines.
- Tests read the contract chapters through `Msg Contract Mgt ori.GetContract` instead of the markdown.
- Pinned Bifrost Foundation 28.0.0.186, the first build without the procedure, in the app and the test app.
- The contract and interface procedures of the message type codeunits are written one statement per
  line, which clears the CodeCop AA0018 warnings.

### Changed (2026-10-01) - help facts moved into the contract chapters (issue #18)

- Every fact the markdown help still carried, checked against the code, is now in a contract chapter:
  per-type subject use and target, parameters with defaults, date format and allowed values, the full
  response fields, the error texts the code answers with, per-type `changes` and `preconditions`,
  related types and domain workflows, and an overview, notes and examples for every type.
- Where the old help or the earlier contract disagreed with the code, the chapters now follow the code;
  for example the PreviewInvoice response fields, the CreateQuote `salesQuoteNo` field, the Usage.Process
  step order, and Analysis.Recalculate's `contractNo`, which narrows only the counts.

### Fixed (2026-09-30) - Foundation floor, is-IS xlf, Recalculate effect (post-#20) (#21)

- Pinned Bifrost Foundation to 28.0.0.166 in the app and the test app. 28.0.1.0 is not a
  published Foundation build, and 28.0.0.166 is the first build that contains the contract builders.
- Added is-IS translations for the 44 new keyword and selection labels across the 22 message
  implementations.
- Declared `Subscription.Analysis.Recalculate` as a write. Its effect, idempotency and description
  follow Create Contract Analysis: the report adds analysis entries and skips a line that already
  has an entry for the current month, so the operation stays idempotent. The selection text no
  longer says read-only, and the batch effect test expects `write`.
- The discovery test reads keywords and selection text through `Msg Discovery ori`. Foundation
  28.0.0.166 does not declare those procedures on `Msg Interface ori`.
- `Sub Contract Batch2 Tst ori` resolves message types with `Enum::"Message Type ori".FromInteger`,
  the same method call as the first batch.
- Related chapters now include the links the help already names for the blocked contract operations,
  price-update perform, renewal quote, deferral release, analysis recalculate and import.

### Added (2026-09-29) - message type contracts (issue #18)

- All 22 Subscription Billing message types now expose Foundation contract chapters for their
  envelope, target, parameters, response, errors, effect, metering and related message types.
- Discovery metadata is available for every type, including bilingual selection text and keywords.
- Added batch conformance tests for contract presence and operation effects, and raised the
  Bifrost Foundation dependency to 28.0.0.166, which contains the contract builders.
- Corrected contract parameters and response fields to match the customer invoice, usage and
  analysis implementations, and added regression coverage for dedicated discovery text.

### Security

- Default (release) builds no longer ship the test app's internalsVisibleTo grant; the strip moved to PipelineInitialize.ps1 because Alpaca never ran PreCompileApp.ps1 (core#129).
### Changed (2026-09-25) - latest Foundation CI build

- The app builds against the latest Foundation CI build, with a Foundation floor of 28.0.0.0.
- AL-Go core probe for `bc-origo-bifrost-core`: `1.0.0.110` → `latest` (`release_status` remains `latestBuild`).

### Added (2026-09-18) - PreviewDocuments Foundation skip/take (issue #8)

- `Subscription.Billing.PreviewDocuments` now calls Foundation `EvaluateSkipTake` (omit→0/100, negatives Error, take clamped to 1000).
- Response adds `skip`, `take`, `hasMore`; `documentCount` is the unpaginated group total while `documents` is the page.
- Help documents `## Pagination Limits` (max 1000). No product clamp below Foundation's 1000.
- Bifrost Foundation Exact pin `28.0.0.100` → `28.0.0.110`; AL-Go core probe `1.0.0.100` → `1.0.0.110` (latestBuild + Exact).
- New test codeunit 95705 `Sub Bil PrvDocs SkipTst ori`.

### Changed

- App logo: new Bifröst wordmark with "Powered by origo." tagline; app name renders in the blank space above the wordmark, tagline position unchanged.
- `privacyStatement` and `EULA` in `app.json` now point at the Bifrost Foundation privacy and EULA pages (<https://businesscentralal.github.io/bifrost/en-us/foundation/privacy/> and <https://businesscentralal.github.io/bifrost/en-us/foundation/eula/>), and the Application Insights connection string now uses the shared Bifrost telemetry resource.


## [29.0.0.0] - 2026-09-06

### Fixed (2026-09-17) - Icelandic translations and AL Comment authority (PR #7)

- Icelandic translations in Subscription Billing were reviewed and corrected (terminology,
  grammar, plurals, spelling, and consistency). The AL `Comment = 'is-IS=…'` authority on
  Label declarations was brought into line with the generated `.xlf` targets so a future
  xlf regeneration cannot silently revert the corrections.


### Reviewed (2026-09-07) - Setup Wizard action rollout

- Checked against the wave-wide Setup Wizard action rollout: this app has no setup page of its own
  (`Sub Registration ori` registers with `Setup Page Id = 0` by design, asserted by `Sub Registration
  Tst ori`), so there is no page to add the action to. No functional change.

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
