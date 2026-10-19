# Extension: Bifrost Subscription Billing

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.SubscriptionBilling` namespace)

## Namespace
Origo.Bifrost.SubscriptionBilling (tests: Origo.Bifrost.SubscriptionBilling.Test)

## Object ID Range
App:   10035035-10035090 (migrated in place from the legacy Cloud Events range, offset 0 - the app
  was never published, so ids kept their identity). Extended through 10035090 on 2026-10-16 for
  #51 and #52. Checked 2026-10-19 against every app.json under E:\Git: no other app uses
  10035085-10035090 (the next range below is Cloud Events Anthropic, 10034985-10035034).
Tests: 95700-95799 (offset 0, same reason)

### Allocated object ids
App:
- 10035035 enumextension `Sub Msg Type ori`
- 10035036-10035057 the `Sub <Domain><Verb> Impl ori` codeunits of the first message types (one per type; the id is also the enum value)
- 10035085 codeunit `Sub Bil PostDocs Impl ori` (`Subscription.Billing.PostDocuments`, #52)
- 10035058 codeunit `Sub Helper ori`
- Freed by #26: 10035059, codeunit `Sub Write Process ori` (each Impl now runs itself in isolation)
- 10035060 codeunit `Sub Registration ori` (registers the app with Foundation's `App Registry ori`)
- 10035062-10035064 the three permission sets `BIFROST SubBil ori`, `BIFROST SubBFull ori`, `BIFROST SubBRead ori`
- 10035086 permission set `BIFROST SubPost ori` (#52; not included in the three sets above)
- 10035075 codeunit `Sub Contract Parts ori` (shared contract chapters, #18)
- Freed by #19: 10035065-10035074, the ten markdown help codeunits `Sub <Domain> Help ori`
  (Line, Con, Vend, Bil, PU, Ren, Usg, Def, Ana, Imp), deleted with `GetMessageHelpAsMarkdownDocument`
- Branch A operations (#36-#41, 2026-10-15): 10035061 `Sub Bil ClrProposal Impl ori`, 10035065 `Sub Bil DelDocs Impl ori`,
  10035066 `Sub Usg Connect Impl ori`, 10035067 `Sub Usg Disconnect Impl ori`, 10035068 `Sub Vend AddToInv Impl ori`,
  10035069 `Sub Usg DelData Impl ori`, 10035070 `Sub Bil SetFilter Impl ori`, 10035071 `Sub Con RemoveLine Impl ori`,
  10035072 `Sub Pkg RemoveItem Impl ori` (each also the enum value of its type)
- 10035076-10035081 the price update copies of Microsoft's internal logic (#45, see docs/microsoft-dependencies.md):
  `Sub PU Price Update Mgt ori`, `Sub PU Calc Base By Perc ori`, `Sub PU Price By Percent ori`,
  `Sub PU Recent Item Price ori`, `Sub PU Process Price Upd ori`, `Sub PU Line Mgt ori` (plus the interface
  `Sub PU Contract Price Upd ori`, which has no id)
- 10035082 codeunit `Sub Con Ccy Restrict ori` (#51; Foundation field-restriction subscriber for contract Currency Code)
- 10035083 table `Sub Posting ori`, 10035084 codeunit `Sub Posting Gate ori` (#52)
- 10035073 codeunit `Sub Con Merge Impl ori` and enum value `Subscription.Contract.MergeLines` (#50)
- 10035074 codeunit `Sub Con Merge Mgt ori` (Microsoft merge copy, #50)
- Free: 10035087-10035090

Tests:
- 95700 `Sub Test Install ori`, 95701 `Sub Msg Type Tst ori`, 95702 `Sub Helper Tst ori`,
  95703 `Sub Test Upgrade ori`, 95704 `Sub Registration Tst ori`
- 95705 `Sub Imp CrContr Tst ori` (import contract stage tests, #30)
- 95706 `Sub Contract Batch1 Tst ori`, 95707 `Sub Contract Batch2 Tst ori` (#18)
- 95708 `Sub PU Filter Tst ori` (PR #25 filter validation regression)
- 95709 `Sub Bil PrvDocs SkipTst ori` (renumbered from 95705 to resolve the same-app
  ID collision, PR #32; fresh allocation verified against the full main tree 4ba0248)
- 95710 `Sub Test Lib ori` (shared Branch A fixtures), 95711 `Sub Con UpdDates Tst ori` (#36), 95712 `Sub Bil Undo Tst ori` (#37),
  95713 `Sub Usg Connect Tst ori` (#38), 95714 `Sub Con UpdFCY Tst ori` (#40), 95715 `Sub Should Have Tst ori` (#41),
  95716 `Sub Usg DelData Tst ori` (#41)
- 95740 `Sub PU Test Lib ori`, 95741 `Sub PU Oracle Tst ori`, 95742 `Sub PU Proposal Tst ori`,
  95743 `Sub PU Perform Tst ori` (#45)
- 95770 `Sub Test Library ori` (shared Subscription Billing seeding for the behaviour tests, #39/#43)
- 95771 `Sub Perm Full Tst ori` (Full-set-only permission test, #42)
- 95772 `Sub Help Accuracy Tst ori` (help preconditions and claims, #44)
- 95773 `Sub Line GetLines Tst ori`, 95774 `Sub Invoice Tst ori`, 95775 `Sub Billing Run Tst ori`,
  95776 `Sub Renewal Tst ori`, 95777 `Sub Usage Tst ori`, 95778 `Sub Deferral Analysis Tst ori`
  (behaviour tests that drive Microsoft Subscription Billing, #43)
- 95717 `Sub Con Ccy Tst ori` (#51), 95718 `Sub PostDocs Tst ori`, 95719 `Sub Post Gate Tst ori` (#52)
- 95720 `Sub Con Merge Tst ori` (#50)
- Free: 95721-95739, 95744-95769, 95779-95799

## Setup Notifications
Setup notifications (enable outbound HTTP, missing credentials, run the setup wizard) live **only**
on Bifröst Foundation's `Setup ori` page ("Bifrost Setup"), and their single action is "Start setup
wizard". This app never raises a `Notification` of its own. It makes itself known to Foundation
instead: codeunit `Sub Registration ori` subscribes to `App Registry ori.OnRegisterApps` and calls
`AddApp` with this app's module id, its display name and setup page id `0` (this app has no setup
page). If a setup page is ever added here, pass its `Page::` id in that same call.

## Target BC Version
28.x (application/platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-subscription-billing
Default branch: main

## Dependencies
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.5.590 minimum (the 28.0.5 release; raised 19.10.2026 for AppSource after compiling against that package); includes the public
  `Message Argument ori.ApplyTableView` validation used by price update template filters)
- Subscription Billing (Microsoft, 28.3.0.0; application floor 28.3.0.0)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Subscription Billing"),
  the permission sets (`BIFROST SubBil ori`, `BIFROST SubBFull ori`, `BIFROST SubBRead ori`,
  `BIFROST SubPost ori`) and
  user-facing captions - never as an object-name prefix.
- The legacy `CE ` / `CE Sub ` prefix is gone; abbreviations kept: `Sub` (Subscription),
  `Bil` (Billing), `Con` (Contract), `Vend` (Vendor), `PU` (Price Update), `Ren` (Renewal),
  `Usg` (Usage), `Def` (Deferral), `Ana` (Analysis), `Imp` (Import), `Pkg` (Package).
- Icelandic captions use "Bifröst".

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills:
- **`bc-al-coding-standards`** - namespaces, XML docs, naming, formatting, performance, enums, Format/Evaluate, events, error handling, JSON, security
- **`bc-test-writer`** - test structure, AAA pattern, coverage checklists, mock patterns
- **`bc-documentation-writer`** - XML doc comments, markdown reference docs, help codeunits, sync rules

Key rules always in effect:
- Namespace: `Origo.Bifrost.SubscriptionBilling` at the top of every app file (`Origo.Bifrost.SubscriptionBilling.Test` in tests)
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (the contract chapters of `Msg Contract ori`)

## Development Environment
- Two COSMO Alpaca containers, both defined in `app/.vscode/launch.json` (git-ignored, the authority
  for instance ids): `launch: bc28-is` (Icelandic CRONUS IS, legacy Cloud Events apps installed side
  by side, used for the MCP message-type tests) and `launch: bc28-w1` (W1 CRONUS International Ltd.).
  Publish and run the unit tests on **both**; select the target with `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop (symbols in `app/.alpackages`, test
  symbols in `test/.alpackages` including the freshly built Bifrost Foundation and app .app files).
- Publish and test without VS Code (pwsh 7, credential from the user-level env vars `BC28IS_USER` /
  `BC28IS_PASSWORD`, never from files), using the shared tooling in the Foundation repo:
  `..\..\OrigoSoftwareSolutions\bc-origo-bifrost-core\tools\Publish-BifrostApp.ps1 -AppFile <.app>`
  and `..\..\OrigoSoftwareSolutions\bc-origo-bifrost-core\tools\Run-BifrostTests.ps1`.
  Both read the instance from `app/.vscode/launch.json`; check it matches the MCP server's baseUrl
  before publishing.
- `AppSourceCop.json` sets `mandatoryAffixes`/`mandatorySuffix` to `ori` and the supported countries
  (IS, GB, DK, NO, SE, FI, DE, FR, NL, AT, CH, IE, PT, ES). Command-line alc does not raise AS0011
  here - AL-Go CI is the gate, so check affixes yourself.

## Message Type Conventions
- Enum extension `Sub Msg Type ori` (10035035) extends Foundation's `Message Type ori` with one
  value per type, all named `Subscription.<Domain>.<Verb>` (`Help.Bifrost.Get` lists every type) - these
  keys are the published external API contract and must never be renamed or removed.
- Each type has a `Sub <Domain><Verb> Impl ori` codeunit implementing `Msg Interface ori`,
  `Msg Discovery ori` and `Msg Contract ori`. A type describes itself only through its contract
  chapters, which `Help.Implementation.Get` returns: envelope, target, parameters, response,
  errors, effect, related and workflow are built per type name in `Sub Contract Parts ori`;
  overview, notes and examples live on the Impl codeunit. There is no markdown help procedure and
  no help codeunit (removed in #19, following core#198).
- Each Impl codeunit has `TableNo = "Message Argument ori"` and an `OnRun` that calls its own `PerformWrite`;
  `ExecuteBifrostTask` runs `Codeunit.Run(Codeunit::"<the Impl itself>", Argument)`, so a failed write rolls back
  on its own (Foundation's write-process pattern) and the ContractParameterKeys guard sees only that type's reads (#26).
  Each Impl's `GetParameters` calls its own `Sub Contract Parts ori` procedure, whose `ContractMgt.Parameter('<key>', ...)`
  calls name the keys literally; never route a type through a shared dispatcher or a case over all type names.
- Errors must be returned as `status = Error` with a helpful message; never let an unhandled
  exception reach the API.

## Migration Tooling
- Migrated in place from `origo-bc-cloudevents-subscriptionbilling` on 2026-09-06 using
  `bc-origo-bifrost-core/tools/migration/migrate.py` (same app id, same object ids, offset 0 - the
  app was never published). See the CHANGELOG first-release section (developed as 29.0.0.0) for the full rename table.

## Test App Rules
- **The test app uses Bifröst Foundation's public API only.** Bifrost Subscription Billing - Tests is not listed in
  Foundation's `app.json` `internalsVisibleTo` and must never be added back. A test that needs a
  message type executed runs it through the public `Dispatcher ori` (`Execute` for a lightweight
  dispatch, `EnqueueAndProcess` when the persisted queue row is needed); the dispatcher marks the
  call licensed itself, so the internal `SetLicensed` is never needed. An Impl may still be called
  directly on a temporary `Message Argument ori` when that Impl does not call `AssertIsLicensed`.

## Testing Through the MCP Server
- `invoke_message_type` / `get_message_type_help` / `get_records` / `set_records` on the
  `origo-bc-bc28-is` server hit this app directly (route `origo/bifrost/v1.0`). Keep calls serial -
  parallel bursts crash the server. Test data uses the `BIFT-S` prefix in CRONUS IS.
- Full message-type test reports live in `test/reports/Bifrost_SubscriptionBilling_TestReport_<date>.md`.
  They are internal and are never published to the documentation site.
