# AppSource offer: Bifrost Subscription Billing

Everything to enter in Partner Center for this offer, page by page, as Microsoft's offer pages ask
for it (Business Central offer, checked 06.10.2026). Built from the app's main branch and the
documentation. No message type names, as on the public site. Review before publishing.

## Files in this folder

| File | Use | Partner Center page |
|---|---|---|
| `logo-216.png` | Large logo, PNG, in the style of Bifrost Foundation's | Offer listing › Logos |
| `screenshots/*.png` | 0 screenshots, 1280 × 720 PNG (3 to 5 required) | Offer listing › Screenshots |
| `description.html` | Description with the allowed HTML tags | Offer listing › Description |
| `description.txt` | The same as plain text | (for review) |
| `product-sheet.pdf` | One-page marketing sheet (1 to 3 PDFs required) | Offer listing › Supporting documents |

## 1. Offer setup

| Field | Value |
|---|---|
| Offer alias | Bifrost Subscription Billing |
| Customer leads / listing option | Same as Bifrost Foundation |

## 2. Properties

| Field | Value | Subcategories |
|---|---|---|
| Primary category | Finance | Accounting |
| Secondary category | Sales | Contract Management |
| Industry | Professional Services | — |
| Industry | Telecommunications & Media | — |
| App version | The version of the `.app` you upload (the pipeline sets it) | |
| Terms and conditions (URL) | https://docs.bifrost.origo.is/en-us/licensing/eula/ | |

## 3. Offer listing

| Field | Value | Length / limit |
|---|---|---|
| Name | Bifrost Subscription Billing | 28 / 200 |
| Search results summary | Run Microsoft Subscription Billing from an assistant, a schedule or an integration. | 83 / 100 |
| Description | `description.html` | 1989 / 5,000 |
| Search keywords | Subscription billing, Recurring billing, Contract management | 3 / 3 |
| Products your app works with | Dynamics 365 Business Central | 1 / 3 |
| Help link | https://docs.bifrost.origo.is/en-us/apps/ | must differ from Support URL |
| Privacy policy link | https://docs.bifrost.origo.is/en-us/licensing/privacy/ | |
| Support contact (name, e-mail, phone, URL) | Same as Bifrost Foundation; Support URL https://www.origo.is/ | not shown to customers |
| Engineering contact | Same as Bifrost Foundation | not shown to customers |
| Supporting documents | `product-sheet.pdf` | 1 to 3 PDFs |
| Logo | `logo-216.png` | PNG |
| Screenshots | see below | 3 to 5, 1280 × 720 PNG |
| Videos | optional; none yet | up to 4 |

Links use the documentation's own domain, docs.bifrost.origo.is. The app has no page of its own on the
site yet, so the help link goes to the app list; change it to the app's page once that is published.
The app's `app.json` still points to the old github.io address, which GitHub forwards to the new domain.

Microsoft's logo guidance says no text on the logo; Bifrost Foundation's logo has text, so this one
follows Foundation for a consistent family.

### Screenshots and captions

| File | Caption |
|---|---|


Taken in the Bifrost sandbox (CRONUS demo company, demo data), 06.10.2026. The company name, user
names, e-mail addresses and IDs were replaced before capture.

## 4. Availability

Markets: the same as Bifrost Foundation.

## 5. Technical configuration

Upload the app's `.app` file from the release build. Dependency: Bifrost Foundation, and Microsoft's Subscription Billing.

## 6. Supplemental content

| Field | Value |
|---|---|
| Supported editions | Essentials and Premium |
| Key usage scenario, test accounts, test app | No longer used in validation (Microsoft); leave empty unless Partner Center requires it |

## Description (as in `description.txt`)

```
Run recurring billing without clicking through every contract.

Bifrost Subscription Billing lets an integration, a scheduled routine or an assistant do the work behind the action buttons in Microsoft's Subscription Billing app. It uses Microsoft's own Subscription Billing logic and reimplements none of it, so results appear in the standard pages. It is an add-on to Bifrost Foundation.

Who it is for
Business Central customers on Microsoft's Subscription Billing who want the monthly run, usage billing and period close to run by themselves.

What it does
- Puts subscriptions on contracts: apply a package and attach lines to customer or vendor contracts; Microsoft's rules work out prices and dates.
- Bills a contract or a whole run: one contract to an unposted invoice, or a billing proposal turned into documents.
- Shows the result before you bill: preview a contract or a run with real figures, without keeping anything.
- Bills for usage: deliver a usage file and move it through Microsoft's processing stages.
- Closes the period: release deferrals, rebuild contract analysis, extend a subscription or create a renewal quote.
- Moves subscriptions in: turn staged import rows into real subscriptions and contracts.

Requirements and pricing
- Microsoft Dynamics 365 Business Central 28.0 or later, Essentials or Premium.
- Bifrost Foundation, available separately on AppSource.
- Microsoft's Subscription Billing app installed and set up.
- For prices, contact Origo (https://www.origo.is/) or your Business Central partner.
- If you are a partner, contact The App Channel (https://www.theappchannel.com/).

Bifrost Subscription Billing does not replace Business Central or its extensions. It makes their data and business logic available to the people, routines and AI platforms your organisation already uses.
```

---
Drafted with the help of Claude (Anthropic); review before publishing. Origo's AI policy (STE-0002):
the person who publishes is responsible for the content.
