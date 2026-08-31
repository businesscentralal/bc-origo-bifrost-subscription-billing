# Changelog

All notable changes to Origo Cloud Events Subscription Billing are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) aligned to the Business Central
major version.

## [28.0.0.0] - 2026-08-30

### Added

Initial release. Adds Cloud Event message types for the Microsoft Dynamics 365 Business Central
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
