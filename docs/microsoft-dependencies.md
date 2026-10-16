# Microsoft dependencies: copied code

Some Bifrost Subscription Billing message types need Microsoft Subscription Billing logic that is
`internal` in Business Central 28. Gunnar's decision (14.10.2026, issue #45) is to copy that logic from
Microsoft's source with a full reference, and to record the Microsoft change that would let us delete
the copy and call Microsoft instead. This file lists every copy.

- **Source:** [microsoft/BCApps](https://github.com/microsoft/BCApps), branch `releases/28.x`, commit
  `a674a13` (Subscription Billing app 28.7.0.0), folder `src/Apps/W1/Subscription Billing/App`.
- **Licence:** MIT, Copyright (c) Microsoft Corporation. The full notice is at the top of every AL file
  that holds a copy, and below.
- **Rule for a copy:** keep Microsoft's structure and statement order; change only names, namespace,
  object ids, `Rec` into a parameter where a table procedure becomes a codeunit procedure, and the few
  documented differences. Every copied procedure carries an XML doc block with the Microsoft object and
  procedure, the path, the commit and the requested Microsoft change.
- **How a change in Microsoft's app is caught:** the oracle tests in codeunit 95741
  `Sub PU Oracle Tst ori` run Microsoft's own logic through its public page 8025 "Contract Price
  Update" (actions Create Proposal and Perform Price Update) and the copy on the same data, and compare
  every field. They run against whatever Subscription Billing version is installed.

## Price update and indexation (#45)

Used by `Subscription.PriceUpdate.CreateProposal` (`Sub PU CrProposal Impl ori`, 10035049) and
`Subscription.PriceUpdate.Perform` (`Sub PU Perform Impl ori`, 10035050). The copies live in
`app/src/Price Update/Microsoft Copy/`.

The smallest Microsoft change that retires every copy in this section: **make
`Price Update Management.CreatePriceUpdateProposal` and `Price Update Management.PerformPriceUpdate`
(codeunit 8009) public**, with `PerformPriceUpdate` taking the `Sub. Contr. Price Update Line` records
to process as a `var` parameter. Then both Impl codeunits call codeunit 8009 and all of the objects
below are deleted.

| Our object (id) | Our procedure | Microsoft object | Microsoft procedure (access) | Path under `App/` | Change requested from Microsoft |
|---|---|---|---|---|---|
| `Sub PU Price Update Mgt ori` (10035076) | CreatePriceUpdateProposal | codeunit 8009 "Price Update Management" | CreatePriceUpdateProposal (internal) | Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al | Make it public |
| `Sub PU Price Update Mgt ori` | GetPriceUpdateMethod | enum 8003 "Price Update Method" | Implementation = "Contract Price Update" (interface internal) | Contract Price Update/Enums/PriceUpdateMethod.Enum.al | Make interface "Contract Price Update" public |
| `Sub PU Price Update Mgt ori` | TestIncludeServiceCommitmentUpToDate | codeunit 8009 | TestIncludeServiceCommitmentUpToDate (internal) | as above | Make it public |
| `Sub PU Price Update Mgt ori` | GetAndApplyFiltersOnServiceCommitment and the locals ApplyDefaultFiltering, InitTempServiceCommitmentTable, FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment, DeleteUnmarkedTempServiceCommitment, FilterAndMarkServiceCommitmentOnServiceObject, FilterAndMarkServiceCommitmentOnContract, ApplyContractFilterAndMarkServiceCommitment, MarkServiceCommitmentsFromTempTable | codeunit 8009 | GetAndApplyFiltersOnServiceCommitment (internal) and its locals | as above | Make GetAndApplyFiltersOnServiceCommitment public |
| `Sub PU Price Update Mgt ori` | ApplyContractFilterAndMarkServiceCommitment (inlined) | table 8059 "Subscription Line" | FilterOnContract (internal) | Service Commitments/Tables/SubscriptionLine.Table.al | Make it public |
| `Sub PU Price Update Mgt ori` | ReadFilter | table 8003 "Price Update Template" | ReadFilter (internal) | Contract Price Update/Tables/PriceUpdateTemplate.Table.al | Make it public |
| `Sub PU Price Update Mgt ori` | PerformPriceUpdate | codeunit 8009 | PerformPriceUpdate (internal) | Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al | Make it public, taking the lines as a `var` record |
| interface `Sub PU Contract Price Upd ori` (no id) | SetPriceUpdateParameters, ApplyFilterOnServiceCommitments, CreatePriceUpdateProposal, CalculateNewPrice | interface "Contract Price Update" | all (Access = Internal) | Contract Price Update/Interfaces/ContractPriceUpdate.Interface.al | Make the interface public |
| `Sub PU Calc Base By Perc ori` (10035077) | SetPriceUpdateParameters, ApplyFilterOnServiceCommitments, CreatePriceUpdateProposal, CalculateNewPrice | codeunit 8010 "Calculation Base By Perc" | same (internal) | Contract Price Update/Codeunits/CalculationBaseByPerc.Codeunit.al | Make the methods public (or the interface) |
| `Sub PU Recent Item Price ori` (10035079) | same four | codeunit 8011 "Recent Item Price" | same (internal) | Contract Price Update/Codeunits/RecentItemPrice.Codeunit.al | Make the methods public (or the interface) |
| `Sub PU Price By Percent ori` (10035078) | same four | codeunit 8012 "Price By Percent" | same (internal) | Contract Price Update/Codeunits/PriceByPercent.Codeunit.al | Make the methods public (or the interface) |
| `Sub PU Process Price Upd ori` (10035080) | OnRun, UpdateServiceCommitmentPrices, CreatePlannedServiceCommitment, ShouldPlannedServiceCommitmentBeCreated | codeunit 8013 "Process Price Update" | whole codeunit (Access = Internal) | Contract Price Update/Codeunits/ProcessPriceUpdate.Codeunit.al | Make the codeunit public |
| `Sub PU Process Price Upd ori` | UnpostedDocumentExists | table 8059 "Subscription Line" | UnpostedDocumentExists (internal) | Service Commitments/Tables/SubscriptionLine.Table.al | Make it public |
| `Sub PU Process Price Upd ori` | UpdateServiceCommitmentFromContractPriceUpdateLine | table 8059 | UpdateServiceCommitmentFromContractPriceUpdateLine (internal), SetSkipArchiving (internal) | as above | Make UpdateServiceCommitmentFromContractPriceUpdateLine public (or SetSkipArchiving and CreateServiceCommitmentArchive) |
| `Sub PU Process Price Upd ori` | CreateServiceCommitmentArchive | table 8059 | CreateServiceCommitmentArchive (internal), FindServiceCommitmentArchiveCreatedInLessThanMinute (local); table 8073 FilterOnServiceCommitment (internal) | as above | Make CreateServiceCommitmentArchive public |
| `Sub PU Process Price Upd ori` | CopyFromServiceCommitment | table 8073 "Subscription Line Archive" | CopyFromServiceCommitment (internal) | Service Commitments/Tables/SubscriptionLineArchive.Table.al | Make it public |
| `Sub PU Line Mgt ori` (10035081) | InitNewLine, UpdateFromServiceCommitment, UpdateFromContract, PriceUpdateLineExists (with FilterOnServiceCommitment), CalculateNewPrice, CalculateNewCalculationBaseAmount, ShouldContractPriceUpdateLineBeInserted, UpdatePerformUpdateOn | table 8004 "Sub. Contr. Price Update Line" | same (internal) | Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al | Make them public |
| `Sub PU Line Mgt ori` | CalculateNewCalculationBaseAmount (inlined) | table 8057 "Subscription Header" | IsItem (internal) | Service Objects/Tables/SubscriptionHeader.Table.al | Make it public |
| `Sub PU Line Mgt ori` | CreateTempSalesHeader, CreateTempSalesLine, CreateTempPurchaseHeader, CreateTempPurchaseLine, GetQtyPerUnitOfMeasure | codeunit 8055 "Sub. Contracts Item Management" | same (internal; GetQtyPerUnitOfMeasure local) | Base/Codeunits/SubContractsItemManagement.Codeunit.al | Make the four Create procedures public |

Public Microsoft code that the copies call instead of copying: codeunit 8017 "Date Time Management".GetMaxDate,
codeunit 8055 CalculateUnitPrice, CalculateUnitCost and CalculateDirectUnitCost, `Billing Line`.FilterBillingLineOnContractLine,
`Currency`.InitRoundingPrecision, and the tables, fields and enums of the Subscription Billing app.

### Known differences from Microsoft

| Difference | Why | Effect |
|---|---|---|
| Microsoft's internal integration events are not raised: `OnAfterCalculateNewPriceForSubscriptionLine` (8010/8011/8012), `OnAfterFilterSubscriptionLineOnAfterGetAndApplyFiltersOnSubscriptionLine` (8009), `OnAfterUpdateServiceCommitmentFromContractPriceUpdateLine` (8059), `OnAfterCopyFromSubscriptionLine` (8073) | An app can raise only its own events | An extension that subscribes to one of them sees the page's run but not a Bifrost run. Ask Microsoft for the procedures, not for the events. |
| `ShowContractPriceUpdateLineNotInsertedNotification` is replaced by a count (`linesNotCreated`) | A notification never reaches an unattended caller | Same lines are inserted; the caller is told how many were left out |
| SetSkipArchiving is not available: OnModify writes the archive entry first and the copy of CreateServiceCommitmentArchive overwrites it | SetSkipArchiving is internal | The same single archive entry, with the same values; checked by `Oracle_Perform_UpdatesAndPlansLikeMicrosoft` |
| Perform can be limited to one template (`priceUpdateTemplateCode`) | Safety for an agent; Microsoft performs every line of every template | Without the parameter the behaviour is Microsoft's |
| Perform under Omit Commit commits nothing and stops at the first failed line | Codeunit.Run with a return value needs a committed transaction | Without Omit Commit each line is committed and a failed line is kept, as Microsoft does |
| The copy follows commit a674a13 (app 28.7): the temporary sales and purchase lines carry the subscription's Unit of Measure (scenario 648553) | The copy was taken from the 28.7 source | On an installed Subscription Billing older than 28.7, Recent Item Prices for a subscription in a non-base unit of measure can differ from the page; the oracle tests use the base unit of measure, and `CreateProposal_RecentItemPrices_UsesPriceOfSubscriptionUnitOfMeasure` pins the 28.7 behaviour |

## Customer contract line merge (#50)

Used by `Subscription.Contract.MergeLines` (`Sub Con Merge Impl ori`, 10035073). The copy lives in
`app/src/Customer Contracts/Microsoft Copy/SubConMergeMgt.Codeunit.al` (`Sub Con Merge Mgt ori`, 10035074).

`Cust. Sub. Contract Line.MergeContractLines` (table 8062) is public, but it always opens page 8091
"Select Cust. Contract Lines". The eligibility checks and the merge are local on that table. The field
comparisons and `UpdateServicesDates` are internal. The smallest Microsoft change that retires the copy:
**make `MergeContractLines` take the reference line as a parameter, and make `TestMergingServiceObjects`,
`TestMergingServiceCommitments` and `UpdateServicesDates` public.** Then the message type calls table 8062
and codeunit 10035074 is deleted.

| Our object (id) | Our procedure | Microsoft object | Microsoft procedure (access) | Path under `App/` | Change requested from Microsoft |
|---|---|---|---|---|---|
| `Sub Con Merge Mgt ori` (10035074) | MergeLines and the local merge procedures | table 8062 "Cust. Sub. Contract Line" | MergeContractLines (public, opens a page) and its local procedures | Customer Contracts/Tables/CustSubContractLine.Table.al | Add a public overload that takes the reference line and does not open a page |
| `Sub Con Merge Mgt ori` | TestMergingServiceObjects, TestMergingServiceCommitments | codeunit 8059 "Sub. Contracts General Mgt." | same (internal) | Base/Codeunits/SubContractsGeneralMgt.Codeunit.al | Make them public |
| `Sub Con Merge Mgt ori` | BillingLineExists | codeunit 8059 | BillingLineExists (internal) | as above | Make it public. The copy calls public `Billing Line`.FilterBillingLineOnContractLine |
| `Sub Con Merge Mgt ori` | UpdateServicesDates and the date helpers it calls | table 8057 "Subscription Header" | UpdateServicesDates (internal) | Service Objects/Tables/SubscriptionHeader.Table.al | Make UpdateServicesDates public |
| `Sub Con Merge Mgt ori` | IsFullyInvoiced, GetReferenceDate, CalculateTermUntilUsingExtensionTerm, CalculateCancellationPossibleUntil | table 8059 "Subscription Line" | same (internal); IsExtensionTermEmpty is local | Service Commitments/Tables/SubscriptionLine.Table.al | Make UpdateServicesDates public so these do not need to be copied |
| `Sub Con Merge Impl ori` (10035073) | Assigns the merged line | table "Customer Subscription Contract" | CreateCustomerContractLineFromServiceCommitment (public, three parameters) | Customer Contracts/Tables/CustomerSubscriptionContract.Table.al | None. This one is called, not copied |

Public Microsoft code the copy calls: `Billing Line`.FilterBillingLineOnContractLine, codeunit "Date Time Management",
codeunit "Calendar Management", and `Customer Subscription Contract`.CreateCustomerContractLineFromServiceCommitment.

### Known differences from Microsoft

| Difference | Why | Effect |
|---|---|---|
| Page 8091 is not opened. `referenceLineNo` is the line the user would pick, and it must be one of the lines | An unattended caller cannot answer a modal page | The same reference Subscription is copied |
| `Message('Customer Subscription Contract lines have been merged.')` is not shown | A message never reaches an unattended caller | The response says `merged: true` |
| Lines whose contract is not the named contract are refused before Microsoft's checks | The page is opened from one contract, so Microsoft never receives a mixed set. AC02 requires the refusal | Nothing is merged |
| Microsoft's local events `OnAfterCheckSelectedContractLinesOnMergeContractLines` and `OnBeforeCreateCustomerContractLineFromTempSubscriptionLine` are not raised | An app can raise only its own events | A subscriber of those events sees the page's run but not a Bifrost run |
| `FilterOnServiceObjectContractLineType` is inlined as a range on Item through G/L Account | The procedure is internal | The same lines are closed by UpdateServicesDates |
| Vendor contract lines are not merged | Out of scope for #50 | Customer lines only |

## Licence notice for the copied code

```
MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
