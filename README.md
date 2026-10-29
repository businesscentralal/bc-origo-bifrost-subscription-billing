# Bifröst Subscription Billing

**App name:** Bifrost Subscription Billing  
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `dd7b8bd8-f93e-4ac4-a251-1a132a14ef3d` — **Test app ID:** `a621027d-6e47-4932-bc65-319b8b798bff`  
**Object ID range:** 10035035–10035090 (tests 95700–95799) — **Namespace:** `Origo.Bifrost.SubscriptionBilling`

Subscription Billing is the recurring-revenue module of the Bifröst platform. It makes Microsoft's
**Subscription Billing** app callable from outside Business Central. It publishes a Bifröst message
type for each operation that otherwise lives behind a page action — applying a subscription package,
attaching, merging and removing contract lines, running and undoing the billing pipeline, posting the
documents a billing run created, updating prices and exchange rates, importing and connecting usage
data, releasing deferrals, rebuilding contract analysis and creating records from staged migration
rows. It is the successor of *Origo Cloud Events Subscription Billing*.

Anything a plain read or a plain write already covers is deliberately not here; Foundation's
`Data.Records.Get` and `Data.Records.Set` handle it. A few types delete what a billing or usage run
created (`Subscription.Billing.ClearProposal`, `Subscription.Billing.DeleteDocuments`,
`Subscription.Usage.DeleteData`) or remove a line or an assignment; ending a subscription itself is
still an end date or a closed flag, not a hard delete. Currency Code on customer and vendor
subscription contracts is closed to `Data.Records.Set`, because Microsoft's validation recalculates
the lines with a currency factor of zero when its exchange rate page cannot open.

### Message types

The list is the `Sub Msg Type ori` enum extension (`app/src/SubMsgType.EnumExt.al`); `Help.Bifrost.Get`
and `Help.Implementation.Get` answer the same list and each type's contract at runtime.

| Message type | What it does |
| --- | --- |
| `Subscription.Line.Create` | Creates a Subscription Line by applying a Subscription Package to a Subscription. |
| `Subscription.Contract.GetLines` | Attaches unassigned Subscription Lines to a customer Subscription Contract. |
| `Subscription.Contract.CreateInvoice` | Bills a customer Subscription Contract into an unposted sales invoice. |
| `Subscription.Contract.PreviewInvoice` | Previews the customer contract billing result without writing anything. |
| `Subscription.Contract.UpdateLineDates` | Closes ended Subscription Lines and rolls term dates forward for every Subscription through a Job Queue Entry for codeunit 8058. |
| `Subscription.Contract.UpdateExchangeRates` | Recalculates the Subscription Lines of a foreign-currency customer or vendor Subscription Contract with a new exchange rate. |
| `Subscription.VendorContract.GetLines` | Attaches unassigned Subscription Lines to a vendor Subscription Contract. |
| `Subscription.VendorContract.CreateInvoice` | Bills a vendor Subscription Contract into an unposted purchase invoice. |
| `Subscription.VendorContract.PreviewInvoice` | Previews the vendor contract billing result without writing anything. |
| `Subscription.Billing.CreateProposal` | Generates billing proposal lines for a billing template and date range. |
| `Subscription.Billing.CreateDocuments` | Turns billing proposal lines into invoices in a bulk run. |
| `Subscription.Billing.PreviewDocuments` | Previews the bulk billing run without writing anything. |
| `Subscription.PriceUpdate.SetTemplateFilter` | Writes the BLOB view filters on a Price Update Template. |
| `Subscription.PriceUpdate.CreateProposal` | Builds a price update proposal from a Price Update Template. |
| `Subscription.PriceUpdate.Perform` | Applies a price update proposal to the Subscription Lines. |
| `Subscription.Renewal.Extend` | Extends a Subscription Contract term with additional package lines. |
| `Subscription.Renewal.CreateQuote` | Creates a contract renewal sales quote. |
| `Subscription.Usage.ImportData` | Imports usage data for metered Subscription Lines. |
| `Subscription.Usage.Process` | Processes imported usage data into billable quantities. |
| `Subscription.Deferral.Release` | Releases deferred revenue or cost for a period. |
| `Subscription.Analysis.Recalculate` | Rebuilds the Subscription Contract analysis entries. |
| `Subscription.Import.CreateContracts` | Builds real Subscription records from staged import rows. |
| `Subscription.Billing.ClearProposal` | Deletes a Billing Template's billing proposal lines and resets the Next Billing Date of their Subscription Lines. |
| `Subscription.Billing.DeleteDocuments` | Deletes the unposted documents created from billing lines and returns the lines to the billing proposal. |
| `Subscription.Usage.ConnectSubscriptions` | Connects a usage data supplier's subscriptions to Subscriptions through Microsoft's Connect to Subscription. |
| `Subscription.Usage.DisconnectSubscription` | Disconnects a Subscription Line from its usage data supplier's subscription. |
| `Subscription.VendorContract.AddLinesToInvoice` | Adds due vendor contract lines to an existing unposted purchase invoice. |
| `Subscription.Usage.DeleteData` | Deletes a usage import's processed data, or the whole import, so it can be re-run. |
| `Subscription.Billing.SetTemplateFilter` | Writes the validated contract filter of a Billing Template. |
| `Subscription.Contract.RemoveLine` | Removes an unbilled line from a customer or vendor Subscription Contract. |
| `Subscription.Package.RemoveItemAssignment` | Removes the assignment of a Subscription Package to an item. |
| `Subscription.Contract.MergeLines` | Merges customer contract lines without opening the selection page. |
| `Subscription.Billing.PostDocuments` | Posts unposted sales and purchase documents that a billing run created. |

---

## Microsoft source

The source code of the Microsoft Subscription Billing app is at
<https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Subscription%20Billing>.

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>. This repository has no `Help/`
folder; `docs/microsoft-dependencies.md` records the Microsoft code this app copies.

| What | Where |
| --- | --- |
| Product documentation (overview, message types, AppSource listing) | <https://docs.bifrost.origo.is/en-us/subscription-billing/> |
| Copied Microsoft procedures and the changes requested from Microsoft | [docs/microsoft-dependencies.md](docs/microsoft-dependencies.md) |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

Message-type contracts are also served by the app itself at runtime: `Help.Bifrost.Get` lists the
registered types, and every message type answers its contract chapters (parameters, response,
errors, effect, preconditions, workflow) through `Help.Implementation.Get` / `get_message_type_help`.

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
| `app/src/Common/` | Shared request parsing and the contract chapters of every type (`Sub Contract Parts ori`) |
| `app/src/Posting/` | The app's own posting gate for `Subscription.Billing.PostDocuments` |
| `app/src/Permission Set/` | Permission sets |
| `test/` | Test app (`Bifrost Subscription Billing - Tests`) |
| `test/reports/` | End-to-end message-type test reports (internal, not published) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.3.530 |
| Subscription Billing | `3099ffc7-4cf7-4df6-9b96-7e4bc2bb587c` | Microsoft | 28.3.0.0 |

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

## Setup

This app has **no setup of its own** and deliberately adds **nothing to the Bifröst Setup page** -
no `Apps` group action, no setup table, no setup page and no Secret Store entry. Every message type
calls Microsoft's Subscription Billing app in-process; there is no external service, no API key and
no outbound HTTP. Everything the operations need is configured in Microsoft's own Subscription
Billing setup (billing templates, contract types, price update templates, usage data suppliers).
Grant `BIFROST SubBil ori` alongside a Bifröst Foundation permission set and the Microsoft
Subscription Billing permission sets, and the app is ready. Posting through
`Subscription.Billing.PostDocuments` also needs `BIFROST SubPost ori`, which is assigned on its own
and is not part of any other set.

## Known issues

No message type is blocked. Where Microsoft keeps the logic internal, the app runs a referenced copy
under the MIT licence of microsoft/BCApps: the price update types (#45) and the customer contract line
merge of `Subscription.Contract.MergeLines` (#50). Every copied procedure, its source and the Microsoft
change that would let us delete it are listed in
[docs/microsoft-dependencies.md](docs/microsoft-dependencies.md). Oracle tests in the test app compare
the copies with Microsoft's own behaviour, so a change in the installed Subscription Billing app shows
up as a failing test.

The EULA and privacy links in `app/app.json` point at the Bifröst licensing pages on
<https://docs.bifrost.origo.is>.

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
