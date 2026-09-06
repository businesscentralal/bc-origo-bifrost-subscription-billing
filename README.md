# Bifröst Subscription Billing

**App name:** Bifrost Subscription Billing  
**Publisher:** Origo — **Version:** 29.0.0.0 — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `dd7b8bd8-f93e-4ac4-a251-1a132a14ef3d` — **Test app ID:** `a621027d-6e47-4932-bc65-319b8b798bff`  
**Object ID range:** 10035035–10035084 (tests 95700–95799) — **Namespace:** `Origo.Bifrost.SubscriptionBilling`

Subscription Billing is the recurring-revenue module of the Bifröst platform. It makes Microsoft's
**Subscription Billing** app callable from outside Business Central, publishing 22 Bifröst message
types for the operations that otherwise live behind a page action — applying a subscription package,
attaching lines to customer and vendor contracts, running the billing pipeline, previewing a billing
run without writing, importing usage data, releasing deferrals, rebuilding contract analysis and
creating records from staged migration rows. It is the successor of *Origo Cloud Events Subscription
Billing*.

Anything a plain read or a plain insert already covers is deliberately not here; Foundation's
`Data.Records.Get` and `Data.Records.Set` handle it. There are no `*.Delete` message types: ending a
subscription is an end date or a closed flag, not a hard delete.

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://bifrost.origo.is>. There are no `docs/` or `Help/`
folders in this repository.

| What | Where |
| --- | --- |
| Product documentation (overview, message types, AppSource listing) | <https://bifrost.origo.is/en-us/subscription-billing/> |
| In-product help (en-US and is-IS) | <https://bifrost.origo.is/en-us/help/subscription-billing/> |
| Building on Bifröst (extensibility guide) | <https://bifrost.origo.is/en-us/extensibility/> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

Message-type contracts are also served by the app itself at runtime: `Help.MessageTypes.Get` (Core)
lists the registered types, and every message type answers its own Markdown help through
`get_message_type_help` / `Help.Implementation.Get`.

This app adds no pages of its own, so it registers no context-sensitive help slugs. The
`contextSensitiveHelpUrl` in `app/app.json` points at the help landing page, which explains that the
extension is operated entirely through message types.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Subscription Billing`) |
| `app/src/Commitments/` | `Subscription.Line.*` |
| `app/src/Customer Contracts/` | `Subscription.Contract.*` |
| `app/src/Vendor Contracts/` | `Subscription.VendorContract.*` |
| `app/src/Billing/` | `Subscription.Billing.*` |
| `app/src/Price Update/` | `Subscription.PriceUpdate.*` |
| `app/src/Renewal/` | `Subscription.Renewal.*` |
| `app/src/Usage/` | `Subscription.Usage.*` |
| `app/src/Deferrals/` | `Subscription.Deferral.*` |
| `app/src/Analysis/` | `Subscription.Analysis.*` |
| `app/src/Import/` | `Subscription.Import.*` |
| `app/src/Common/` | Shared request parsing, isolated write, preview rollback |
| `app/src/Help/` | Per-domain Markdown help text, one codeunit per domain |
| `app/src/Permission Set/` | Permission sets |
| `test/` | Test app (`Bifrost Subscription Billing - Tests`) |
| `test/reports/` | End-to-end message-type test reports (internal, not published) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.0.0 |
| Subscription Billing | `3099ffc7-4cf7-4df6-9b96-7e4bc2bb587c` | Microsoft | 28.0.0.0 |

The test app additionally depends on Bifrost Subscription Billing itself and on Microsoft's
Tests-TestLibraries, Application Test Library, Library Assert, Test Runner, Any and Library Variable
Storage.

Microsoft's Subscription Billing app must be installed **and set up** at runtime — Subscription
Contract Setup, number series, a Billing Template and the relevant posting setup. This app calls
Microsoft's own codeunits and reports; it reimplements none of their logic.

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International
  Ltd.), both defined in `app/.vscode/launch.json` — git-ignored and the authority for the instance
  ids. Publish and run the unit tests on **both**; select the target with
  `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. Symbols live in
  `app/.alpackages`; test symbols in `test/.alpackages`, including the Bifrost Foundation `.app`.

  ```
  alc.exe /project:app /packagecachepath:app/.alpackages /out:app/output/subscriptionbilling.app ^
          /analyzer:<CodeCop.dll> /analyzer:<UICop.dll> /analyzer:<AppSourceCop.dll>
  ```

  The build is expected to be **warning-free**. Only `AS0081` is suppressed, for the
  `internalsVisibleTo` entry the test app needs.

- Publish and run tests without VS Code (pwsh 7, credential from the user-level env vars
  `BC28IS_USER` / `BC28IS_PASSWORD`, never from files):
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and
  `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1`.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself before pushing.
- **Live message-type testing is what proves the Microsoft integration.** Most of what these message
  types do is call Microsoft's own codeunits, and those only misbehave against real data — an
  interactive request page that cannot open unattended, a proposal Business Central declines to build
  twice, a connector that skips a blob it thinks is already imported. Publish both apps to a
  development container and drive the types through the Bifröst API. The AppSource user scenarios on
  the documentation site list the company setup this needs.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`.
- Every object carries the mandatory ` ori` suffix; the brand name is carried by the namespace, the
  app name and the captions, never by an object-name prefix.

---

## Known limitations

Four message types are registered and discoverable but return a structured error rather than
performing the operation, because Microsoft has not exposed a public API for them in Business
Central 28.4: `Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
`Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform`. Each names the
procedure that would need to become public and points to the client action that does the job today.
See the [changelog](CHANGELOG.md) and the
[message type documentation](https://bifrost.origo.is/en-us/subscription-billing/message-types) for
detail.

---

© 2026 Origo ehf.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca). To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
