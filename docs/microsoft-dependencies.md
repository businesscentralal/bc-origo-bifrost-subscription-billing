# Microsoft dependencies

This app drives Microsoft's Subscription Billing app (id `3099ffc7-4cf7-4df6-9b96-7e4bc2bb587c`).
Where Microsoft keeps the procedure we need `internal`, we rebuild its logic from Microsoft's
source (decision 14.10.2026, Gunnar). Each copy below names its source, where it lives here, and the
change we would like Microsoft to make so the copy can be deleted and the public procedure called.

Source for every entry: [microsoft/BCApps](https://github.com/microsoft/BCApps), branch `releases/28.x`,
commit `a674a13`, app version 28.7.0.0, folder `src/Apps/W1/Subscription Billing/App`.

## License notice

The copied logic comes from Microsoft BCApps, which is released under the MIT License:

> Copyright (c) Microsoft Corporation.
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
> associated documentation files (the "Software"), to deal in the Software without restriction,
> including without limitation the rights to use, copy, modify, merge, publish, distribute,
> sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or
> substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
> NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
> NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
> DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
> OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Copies

### Billing proposal authorization check (#37)

- **Microsoft source:** codeunit 8062 "Billing Proposal", `internal procedure DisplayErrorIfNotAuthorizedToClearProposalOrDeleteDocuments`, in `Billing/Codeunits/BillingProposal.Codeunit.al`, and table extension 8012 "User Setup", `internal procedure AutoContractBillingAllowed`, in `Billing/Table Extensions/UserSetup.TableExt.al`.
- **Our copy:** `Sub Helper ori.AssertMayClearBillingProposal` (`app/src/Common/SubHelper.Codeunit.al`), used by `Subscription.Billing.ClearProposal` and `Subscription.Billing.DeleteDocuments`.
- **What it does:** when any Billing Template has Automation set, only a user whose User Setup has Auto Contract Billing may clear a proposal or delete billing documents.
- **Change we want from Microsoft:** make `DeleteBillingProposal(BillingTemplateCode)` and `DeleteBillingDocuments(BillingTemplateCode)` public with an overload that takes the scope (all proposals of the partner, or the current template only) as a parameter instead of asking with `Dialog.StrMenu`. The check would then come with them and this copy could be deleted.

### Disconnect a Subscription Line from a supplier subscription (#38)

- **Microsoft source:** codeunit 8029 "Usage Based Billing Mgmt.", public `procedure DisconnectServiceCommitmentFromSubscription` and its `local procedure ResetSupplierReferenceEntryNoForServiceObject`, in `Usage Based Billing/Codeunits/UsageBasedBillingMgmt.Codeunit.al`; table 8016 "Usage Data Supp. Subscription", `internal procedure ResetServiceObjectAndServiceCommitment`, in `Usage Based Billing/Tables/UsageDataSuppSubscription.Table.al`.
- **Our copy:** `Sub Usg Disconnect Impl ori` (codeunit 10035067, `app/src/Usage/SubUsgDisconnectImpl.Codeunit.al`), local procedures `ResetSupplierReferenceEntryNo` and `ResetServiceObjectAndServiceCommitment`.
- **Why a copy although the procedure is public:** it asks `Confirm Management.GetResponse('Do you want to disconnect from the subscription?', true)`. GetResponse answers false whenever `GuiAllowed` is false, so from an API or job queue session the procedure returns without disconnecting anything and without an error.
- **Change we want from Microsoft:** an overload `DisconnectServiceCommitmentFromSubscription(var ServiceCommitment: Record "Subscription Line"; HideDialog: Boolean)`, or `GetResponseOrDefault` instead of `GetResponse`, so an unattended caller gets the default answer.

### Update exchange rates of a contract (#40)

- **Microsoft source:** table 8052 "Customer Subscription Contract" and table 8063 "Vendor Subscription Contract", `internal procedure UpdateAndRecalculateServiceCommitmentCurrencyData`, in `Customer Contracts/Tables/CustomerSubscriptionContract.Table.al` and `Vendor Contracts/Tables/VendorSubscriptionContract.Table.al`; table 8059 "Subscription Line", `internal procedure UpdateAndRecalculateServCommCurrencyFromContract`, `UpdateCurrencyDataOnServiceCommitments`, `SetCurrencyData` and `RecalculateAmountsFromCurrencyData`, in `Service Commitments/Tables/SubscriptionLine.Table.al`; page 8088 "Exchange Rate Selection", `SetData`, for the default rate.
- **Our copy:** `Sub Con UpdFCY Impl ori` (codeunit 10035041, `app/src/Customer Contracts/SubConUpdFCYImpl.Codeunit.al`), local procedures `RecalculateLines`, `RecalculateAmountsFromCurrencyData` and `IsContractLineClosed`.
- **Deviations:** Microsoft calls the internal `SetUpdateRequiredOnBillingLines` and `ArchiveServiceCommitment` and then `Modify(false)`; the copy uses `Modify(true)`, because the Subscription Line OnModify trigger runs exactly those two. That trigger refuses a line whose contract line is closed, so such lines are skipped and counted.
- **Investigation (#40 AC01):** validating Currency Code on the contract does not reach the same recalculation. The OnValidate calls the procedure only when the code changes, so an unchanged currency is never refreshed; and `OpenExchangeSelectionPage` returns false without a user interface, leaving the contract's CurrencyFactor and CurrencyFactorDate at 0 and 0D, so the lines would be recalculated with a zero factor.
- **Change we want from Microsoft:** a public `UpdateAndRecalculateServiceCommitmentCurrencyData(CurrencyFactorDate: Date; CurrencyFactor: Decimal)` overload on both contract tables that skips the exchange rate page, and an error instead of a zero factor in `OpenExchangeSelectionPage` when `GuiAllowed` is false.

### Reset a usage import (#41 AC03)

- **Microsoft source:** table 8013 "Usage Data Import", `internal procedure DeleteUsageDataBillingLines` and `local procedure CheckAndDeleteUsageDataBilling`, in `Usage Based Billing/Tables/UsageDataImport.Table.al` (the Delete Usage Data Lines & Billing action of page Usage Data Imports).
- **Our copy:** `Sub Usg DelData Impl ori` (codeunit 10035069, `app/src/Usage/SubUsgDelDataImpl.Codeunit.al`), local procedures `DeleteUsageDataBillingLines` and `CheckNotBilled`.
- **Deviations:** Microsoft's local `OnDeleteUsageDataBillingLines` integration event cannot be raised from outside and is not raised. Besides Microsoft's refusal of usage billing on a document, the copy also refuses usage billing on a billing line, so no proposal line points at deleted usage.
- **Change we want from Microsoft:** make `DeleteUsageDataBillingLines` public (it has no dialog).

### Billing Template filter (#41 AC04)

- **Microsoft source:** table 8060 "Billing Template", `internal procedure WriteFilter` (and `EditFilter`, which opens a FilterPageBuilder), in `Billing/Tables/BillingTemplate.Table.al`.
- **Our copy:** `Sub Bil SetFilter Impl ori` (codeunit 10035070, `app/src/Billing/SubBilSetFilterImpl.Codeunit.al`): the Filter Blob is cleared and the normalised view written unless it is the blank view of the template's contract table. The view is validated by Foundation's `Message Argument ori.ApplyTableView` first, as `Subscription.PriceUpdate.SetTemplateFilter` does for Price Update Templates.
- **Change we want from Microsoft:** make `WriteFilter(FieldNumber, FilterText)` public.
