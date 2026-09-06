# AppSource release checklist

**App:** Origo Cloud Events Subscription Billing (`dd7b8bd8-f93e-4ac4-a251-1a132a14ef3d`)
**Publisher:** Origo
**Target version:** 28.0.0.0 - first submission

Everything under *Done* is already in the repository. Everything under *Before you submit* needs
a person with Partner Center access, and cannot be finished from the code alone.

---

## Done

| Item | Where |
| --- | --- |
| Application Insights connection string | `app/app.json` - `applicationInsightsConnectionString` |
| Publisher, app id, version, brief, description | `app/app.json` |
| Logo (250x250 PNG) | `app/assets/Logo250x250.png` |
| Privacy statement URL | https://www.origo.is/um-origo/stefnur/personuverndarstefna |
| Licence terms (EULA) URL | The Cloud Events Terms of Use PDF, shared with Origo Cloud Events Core |
| Help URL and context-sensitive help URL | https://www.origo.is/ - see *Help content* below |
| `target: Cloud` | `app/app.json` |
| Registered object range 10035035..10035084 | `app/app.json` - `idRanges` |
| Affix and suffix `ori` on every object | `app/AppSourceCop.json`, enforced by AppSourceCop |
| Supported countries | `app/AppSourceCop.json` - 14 countries, matching the Partner Center listing |
| en-US and is-IS translations, complete | `app/Translations/*.xlf` - 84 of 84 units translated |
| Assignable permission set | `CE Sub Bil Obj ori`, plus extensions of the Core sets |
| Clean build with CodeCop, UICop and AppSourceCop | zero warnings; only `AS0081` is suppressed, for the test app's `internalsVisibleTo` |
| Test app excluded from the shipped artifact | `test/` is a separate app, listed under `testFolders` in `.AL-Go/settings.json` |
| Partner Center listing text | `app/docs/PartnerCenter-Listing.md`, `app/docs/PartnerCenter-Description.md` |
| Validation-engineer walkthrough | `app/docs/AppSource-UserScenarios.md` |

## Before you submit

### 1. Partner Center offer

Create (or reuse) the Business Central offer in Partner Center and note its **product ID** - the
GUID in the offer URL. Nothing in this repository has it yet.

### 2. Wire AL-Go up to that offer

Add a `deliverToAppSource` block to `.github/AL-Go-Settings.json`:

```json
{
  "deliverToAppSource": {
    "productId": "<the Partner Center product ID>",
    "mainAppFolder": "app",
    "continuousDelivery": false
  }
}
```

`continuousDelivery: false` keeps the ' Publish To AppSource' workflow manual, which is the right
default for a first submission. Turn it on once a release has passed technical validation.

### 3. Add the `appSourceContext` secret

The ' Publish To AppSource' workflow reads a repository (or organisation) secret named
`appSourceContext`:

```json
{
  "TenantId": "<Entra tenant id>",
  "ClientId": "<app registration client id>",
  "ClientSecret": "<client secret>"
}
```

The app registration must be the one linked to the Partner Center account under
**Account settings > Tenants**. Store it as a GitHub secret, never in the repository.

### 4. Help content

`help` and `contextSensitiveHelpUrl` currently point at https://www.origo.is/, which resolves.
Microsoft's validation checks that the Help link is reachable, and https://www.origo.is/ passes -
but it is the company home page, not product help.

The rest of the Cloud Events family publishes help to
`https://origopublic.blob.core.windows.net/help/<product>/<bcversion>/<locale>/index.html`
(Cloud Events Core uses `.../help/Cloud Events/bc27/en-US/index.html`). When help for this app is
published there, point both properties at it:

```json
"help": "https://origopublic.blob.core.windows.net/help/Cloud Events Subscription Billing/bc28/en-US/index.html",
"contextSensitiveHelpUrl": "https://origopublic.blob.core.windows.net/help/Cloud Events Subscription Billing/bc28/{0}/"
```

Do not set those URLs before the content is live: an unreachable Help link fails validation.

### 5. Screenshots

`screenshots` in `app/app.json` is an empty array, which is allowed - AppSource takes listing
images from Partner Center rather than from the app manifest. Upload at least one 1280x720 image
to the offer listing.

### 6. Dependency availability

The app depends on **Origo Cloud Events Core** `28.2.6.0` or later. That app must already be live
on AppSource, and at a version at least as high as the dependency, or validation cannot resolve
it. It also depends on Microsoft's **Subscription Billing**, which ships with Business Central,
so nothing is needed for that one.

### 7. Run the release

1. Run the ' CI/CD' workflow on `main` and confirm it is green.
2. Run ' Create Release' to produce the release artifact.
3. Run ' Publish To AppSource' with `GoLive` left off, and wait for Microsoft's technical
   validation result in Partner Center.
4. When validation passes, run it again with `GoLive` on - or press **Go live** in Partner Center.

## Known things a validation engineer will see

Four of the twenty-two message types are registered, discoverable and documented, but every call
returns a structured error explaining that Microsoft has not exposed a public API for the
operation in Business Central 28.4:
`Subscription.Contract.UpdateLineDates`, `Subscription.Contract.UpdateExchangeRates`,
`Subscription.PriceUpdate.CreateProposal` and `Subscription.PriceUpdate.Perform`.

This is deliberate and is documented in the app description, in each type's own help document and
in `app/docs/Message-Types.md`. Each error names the exact Microsoft procedure that would have to
become public, and points at the client action that performs the operation today. Re-implementing
that logic independently was considered and rejected: diverging from Microsoft's own date, pricing
and rounding rules could mis-price or corrupt live customer contracts.
