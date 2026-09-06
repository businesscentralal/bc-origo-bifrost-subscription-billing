# Extension: Bifrost Subscription Billing

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.SubscriptionBilling` namespace)

## Namespace
Origo.Bifrost.SubscriptionBilling (tests: Origo.Bifrost.SubscriptionBilling.Test)

## Object ID Range
App:   10035035-10035084 (migrated in place from the legacy Cloud Events range, offset 0 - the app
  was never published, so ids kept their identity)
Tests: 95700-95799 (offset 0, same reason)

## Target BC Version
28.x (application/platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-subscription-billing
Default branch: main

## Dependencies
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.0.0)
- Subscription Billing (Microsoft, 28.0.0.0)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Subscription Billing"),
  the permission sets (`BIFROST SubBil ori`, `BIFROST SubBFull ori`, `BIFROST SubBRead ori`) and
  user-facing captions - never as an object-name prefix.
- The legacy `CE ` / `CE Sub ` prefix is gone; abbreviations kept: `Sub` (Subscription),
  `Bil` (Billing), `Con` (Contract), `Vend` (Vendor), `PU` (Price Update), `Ren` (Renewal),
  `Usg` (Usage), `Def` (Deferral), `Ana` (Analysis), `Imp` (Import).
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
- Implementation = code + tests + documentation (help text returned by `GetMessageHelpAsMarkdownDocument`)

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
- Enum extension `Sub Msg Type ori` (10035035) extends Foundation's `Message Type ori` with 22
  values, all named `Subscription.<Domain>.<Verb>` (`Help.Bifrost.Get` lists every type) - these
  keys are the published external API contract and must never be renamed or removed.
- Each type has a `Sub <Domain><Verb> Impl ori` codeunit implementing `Msg Interface ori`; help is
  returned inline by each Impl's `GetMessageHelpAsMarkdownDocument` (this app has not yet moved to
  the shared per-domain Help codeunit pattern used by Foundation/Nornir - see CHANGELOG 29.0.0.0).
- `Sub Write Process ori` runs writes in an isolated transaction so a failed write always rolls back
  cleanly, mirroring Foundation's own write-process pattern.
- Errors must be returned as `status = Error` with a helpful message; never let an unhandled
  exception reach the API.

## Migration Tooling
- Migrated in place from `origo-bc-cloudevents-subscriptionbilling` on 2026-09-06 using
  `bc-origo-bifrost-core/tools/migration/migrate.py` (same app id, same object ids, offset 0 - the
  app was never published). See CHANGELOG 29.0.0.0 for the full rename table.

## Testing Through the MCP Server
- `invoke_message_type` / `get_message_type_help` / `get_records` / `set_records` on the
  `origo-bc-bc28-is` server hit this app directly (route `origo/bifrost/v1.0`). Keep calls serial -
  parallel bursts crash the server. Test data uses the `BIFT-S` prefix in CRONUS IS.
- Full message-type test reports live in `app/docs/Bifrost_SubscriptionBilling_TestReport_<date>.md`.
