<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca). To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->

---

# Origo Cloud Events Subscription Billing

Cloud Event message types for the Microsoft Dynamics 365 Business Central **Subscription Billing**
app, so an agent or an integration can operate Subscription Billing end to end without manual UI
steps.

## What this app is for

Subscription Billing models recurring revenue well, but its meaningful operations sit behind page
actions. A generic API can read and write subscription records and then stops at the first button.
This extension publishes one Cloud Event message type per operation that genuinely needs more than
a record write — a Microsoft codeunit, record context at insert time, a stored BLOB filter, or a
preview-and-rollback run.

Anything a plain read or a plain insert/update can already do is deliberately **not** here; the
Core `Data.Records.Get` and `Data.Records.Set` message types cover it. There are no `*.Delete`
message types: ending a subscription is an end date or a closed flag, not a hard delete.

## Naming

Every type is `Subscription.<Domain>.<Action>` across ten domains: `Line`, `Contract`,
`VendorContract`, `Billing`, `PriceUpdate`, `Renewal`, `Usage`, `Deferral`, `Analysis`, `Import`.

See [app/docs/Message-Types.md](app/docs/Message-Types.md) for the full reference, and call
`Help.Implementation.Get` with a type name as the subject to get its help document at runtime.

## Dependencies

| App | Publisher | Minimum version |
| --- | --- | --- |
| Origo Cloud Events Core | Origo | 28.2.6.0 |
| Subscription Billing | Microsoft | 28.0.0.0 |

Object range 10035035–10035084. Namespace `Origo.APP.CloudEvents.SubscriptionBilling`.

## Repository layout

```
app/                 the extension
  src/Commitments/           Subscription.Line.*
  src/Customer Contracts/    Subscription.Contract.*
  src/Vendor Contracts/      Subscription.VendorContract.*
  src/Billing/               Subscription.Billing.*
  src/Price Update/          Subscription.PriceUpdate.*
  src/Renewal/               Subscription.Renewal.*
  src/Usage/                 Subscription.Usage.*
  src/Deferrals/             Subscription.Deferral.*
  src/Analysis/              Subscription.Analysis.*
  src/Import/                Subscription.Import.*
  src/Common/                shared request parsing, isolated write, preview rollback
  src/Permission Set/        permission sets
  docs/                      AppSource and Partner Center documentation
test/                the test app (object range 95700–95799)
scripts/             local build, deploy and MCP helpers
```

## Building locally

`scripts/build.sh` compiles with the AL compiler shipped in the VS Code AL extension, against
symbols in `app/.alpackages`. The symbols are not committed — download them from your development
container or from the public Microsoft symbol feed.

```bash
scripts/build.sh app     # or: test, both
```

## Deploying to a development container

```bash
BC_USER=<user> BC_PASSWORD=<password> scripts/deploy.sh app
```

Override `BC_SERVER`, `BC_INSTANCE` and `BC_TENANT` to target a different container. The default
points at the shared COSMO Alpaca development container.

## Known limitations

Four message types are registered and discoverable but return a structured error rather than
performing the operation, because Microsoft has not exposed a public API for them in Business
Central 28.4: `Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
`Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform`. Each names the
procedure that would need to become public and points to the client action that does the job today.
See the [changelog](CHANGELOG.md) and the message type reference for detail.
