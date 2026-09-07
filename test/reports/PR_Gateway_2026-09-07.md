# Origo BC — PR Gateway Report

```
╔══════════════════════════════════════════════════════════════════╗
║           Origo BC — PR Gateway Report                           ║
║           Extension : Bifrost Subscription Billing v29.0.0.0     ║
║           Customer  : Origo (AppSource, Bifröst portfolio)       ║
║           Date      : 2026-09-07 08:40                           ║
║           Tier      : Standard (AppSourceCop.json, no stories/)  ║
║           Branch    : feature/bifrost-subscription-billing-      ║
║                       migration → main                           ║
║           PR        : #2                                         ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 1 — Automated Script (23 checks)                          ║
║  Files scanned: 38     Passed: 13/23     Failed: 10              ║
║  After agent triage: 10 real findings fixed, 4 reported open,    ║
║                      239 dismissed as false positives            ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 2 — Agent Deep Checks         Result                      ║
╠══════════════════════════════════════════════════════════════════╣
║  1.  AL Compiler                     ✅ Pass  (0 err / 0 warn)   ║
║  2.  Object Naming — Affix           ✅ Pass  (38 objects)       ║
║  3.  Object ID Ranges                ✅ Pass                     ║
║  4.  SetLoadFields — Exceptions      ✅ Pass  (10 added)         ║
║  5.  Breaking Change Guard           ⏭ Skip (initial phase)     ║
║  6.  app.json — Semantic             ⚠️ Pass w/ 2 deviations     ║
║  7.  CHANGELOG & README Quality      ✅ Pass                     ║
║  8.  HTML Help Pages                 ⏭ Skip (app has no pages)  ║
║  9.  Documentation Generation        📝 Done                     ║
║  10. Unit Tests                      ✅ Pass  (23/23 × 2)        ║
║  11. Story-Doc Consistency           ⏭ Skip (no stories/)       ║
║  12. Logic Review                    🔍 5 fixed, 3 reported      ║
║  13. What I Couldn't Check           🔍 4 gaps noted             ║
║  14. Role Coverage                   ✅ Pass  (34/34 granted)    ║
║  15. Platform Integration            ⏭ Skip (not standards repo)║
╠══════════════════════════════════════════════════════════════════╣
║  Overall : ✅ 9 passed  ❌ 0 failed  ⚠️ 1 warning  ⏭ 4 skipped  ║
╚══════════════════════════════════════════════════════════════════╝
```

Target branch `main` — from `.claude/CLAUDE.md` (`Default branch: main`) and confirmed against the
open PR #2. Working tree was clean at `3294f3b` when this run started.

Approved deviations, stated here once and never counted as failures: documentation lives in
`businesscentralal/bifrost` and this repository carries no `Help/` or `docs/` folder; help URLs use
`businesscentralal.github.io` until the `bifrost.origo.is` DNS record exists; the `EULA` still
points at the Cloud Events terms of use (warned, not failed); test-app objects carry no ` ori`
affix; there is no AppSourceCop version baseline, so the breaking-change guard is skipped; the app
adds no entry to the Bifröst Setup page and registers no secrets, by design; four message types are
documented Known Issues waiting on Microsoft.

---

## Layer 1 — Automated scan, with agent triage

The script reports 10 failed checks over 253 raw findings. Every finding was read against the
source. 10 were real and are fixed, 4 are real and are reported open with reasons, 239 are false
positives.

| Check | Raw | Real | Disposition |
| --- | ---: | ---: | --- |
| `xml_doc_comments` | 124 | 0 | Every object and every non-local procedure carries `///`. The hits are `local procedure`s and the `Msg Interface ori` implementations, where the contract is documented on the interface. This is the pattern the whole Bifröst portfolio uses. |
| `set_load_fields` | 62 → 52 | 10 | 10 added — see Check 4. Of the 52 left, roughly half are not record reads at all (`JsonObject.Get`, `JsonToken.Get`, `Dictionary.Get`), the rest are single-row `Get()` by primary key on a template or header that is then passed whole to a Microsoft procedure, where a partial load is a correctness trap rather than an optimisation. |
| `read_isolation` | 30 → 29 | 0 | Update paths (`FindLast` before a write), rows modified straight after the read, temporary records, and `IsEmpty()` existence probes. Adding `ReadIsolation` on a path that then writes would be wrong, not faster. |
| `one_statement_per_line` | 27 → 29 | 0 | Every hit is a procedure signature with several parameters; the scanner counts the parameter separator `;` as a statement separator. The count rose by 2 because this PR adds two such signatures. |
| `caption_translation` | 22 | 0 | All 22 are `Locked = true` captions on `Sub Msg Type ori`. They are the published wire contract and must not be translated. |
| `commit_in_loop` | 4 | 4 open | `Sub Imp CrContr Impl ori` lines 172/197/222/247 — reported, not changed. See Check 12, finding F7. |
| `modernization` | 7 → 8 | 0 | File-level hits with no line or text; substring matches inside longer identifiers. Nothing actionable. |
| `today_vs_workdate` | 2 | 0 open, advisory | `Sub Ana Recalc Impl ori` reports `analysisDate` as `Today()` (a run stamp, not a posting date) and `Sub Usg Import Impl ori` stamps `Import Date` with `Today()`, mirroring Microsoft's own connector. Neither drives a posting. Left as is. |
| `format_evaluate_enum` | 1 | 0 | The hit is inside a comment in `Sub Helper ori` explaining why `Format()` on the enum is *not* used. |
| `try_prefix_convention` | 1 | 0 | `TryGetArray` is a `Boolean`-returning "try to get" reader without `[TryFunction]` — the established portfolio convention; Bifröst Foundation ships `TryGetSecret` and `TryGetRemaining` in exactly this shape. The one genuine `[TryFunction]` added by this PR (`TrySetView`) is correctly attributed. |

---

## Check 1 — AL compiler

| Project | Analyzers | Result |
| --- | --- | --- |
| `app` (38 files) | CodeCop + UICop + AppSourceCop | **0 errors, 0 warnings** |
| `test` (4 files) | CodeCop + UICop | **0 errors, 0 warnings** |

`alc.exe` 17.0.34.45391, symbols from `app/.alpackages` and `test/.alpackages` with the current
`Origo_Bifrost Foundation_28.0.0.0.app`; the test project was rebuilt against the freshly compiled
app package, not a stale one. Command-line `alc` does not raise AS0011 (mandatory affix), so the
` ori` suffix was verified separately across all 38 objects — see Check 2.

---

## Check 2 — Object naming and affix

38 objects in `app/src`: 34 codeunits, 1 enum extension, 1 permission set, 2 permission set
extensions. The app has no tables, pages or reports — it is message types over Microsoft's own
Subscription Billing objects.

- **Affix:** 38 of 38 end in ` ori`. None missing.
- **Length:** none over 30 characters; the longest are 27 (`Sub Bil CrProposal Impl ori`,
  `Sub Con PrvInvoice Impl ori`, `Sub Vend CrInvoice Impl ori`), so there is headroom.
- **Permission sets:** `BIFROST SubBil ori`, `BIFROST SubBFull ori`, `BIFROST SubBRead ori` — all
  inside the `Code[20]` ceiling.
- **Test app:** 4 objects, 95700–95703, deliberately without the affix (approved deviation).

---

## Check 3 — Object ID ranges

Every id in `app/src` falls inside `10035035–10035084`, matching `app.json` `idRanges` and
`.claude/CLAUDE.md`. Lowest 10035035, highest **10035074**; 10035075–10035084 (10 ids) free. The
enum extension places its 22 value ordinals inside the same block (10035036–10035057). Test objects
95700–95703 are inside 95700–95799.

The MCP tool `check_app_range` was not reachable from this session, so the range was verified
against `app.json`, `.claude/CLAUDE.md` and a full scan of the source rather than against the
registry service. The workbook entry itself was not re-read — see Check 13.

---

## Check 4 — SetLoadFields

Ten reads that use one or two fields now declare them. Every one is a watermark read or a scan whose
loop body touches a single column:

| File | Line | Read | Fields |
| --- | ---: | --- | --- |
| `SubAnaRecalcImpl` | 80 | `FindLast` watermark | `Entry No.` |
| `SubLineCreateImpl` | 104 | `FindLast` watermark | `Entry No.` |
| `SubConCrInvoiceImpl` | 156 | `FindLast` watermark | `Entry No.` |
| `SubVendCrInvoiceImpl` | 170 | `FindLast` watermark | `Entry No.` |
| `SubConPrvInvoiceImpl` | 72 | `FindLast` watermark | `Entry No.` |
| `SubVendPrvInvImpl` | 71 | `FindLast` watermark | `Entry No.` |
| `SubRenCrQuoteImpl` | 96 | contract-line scan | `Subscription Line Entry No.` |
| `SubBilPrvDocsImpl` | 173 | grouping pass | `Partner No.`, `Subscription Contract No.`, `Amount` |
| `SubConGetLinesImpl` | new | header lookup | `End-User Customer No.` |
| `SubBilPrvDocsImpl` | 195 | second grouping pass | removed entirely — the pass is gone |

Not added, deliberately: `SubscriptionLine` in either `GetLines` type and in the two `CreateInvoice`
types, because the whole record is handed to Microsoft's
`CreateCustomerContractLineFromServiceCommitment` / `CreateVendorContractLineFromServiceCommitment`
or assigned into a temporary record. A partial load there would silently blank fields.

---

## Check 5 — Breaking change guard

⏭ **Skipped.** `app/AppSourceCop.json` sets `mandatoryAffixes`, `mandatorySuffix`, `publisher` and
`supportedCountries`, so the profile is **appsource** — but it carries no `version` property, so the
phase is **initial** and there is no baseline to break against. The app has never been published
under this identity as *Bifrost Subscription Billing*.

ℹ️ No ruleset file exists, so AppSourceCop runs with its default actions. Worth adding one before
the first AppSource submission, together with the `version` baseline, so subsequent releases get a
real breaking-change gate.

---

## Check 6 — app.json: two deviations

Everything mandatory is present and semantically correct: `id` `dd7b8bd8-…` matches
`.claude/CLAUDE.md`, publisher `Origo`, version `29.0.0.0`, `target: Cloud`, application/platform
`28.0.0.0`, runtime `17.0`, `idRanges` `10035035–10035084` matching every object in the app, logo,
brief, description, url, privacyStatement, and `applicationInsightsConnectionString` set (the modern
replacement for `applicationInsightsKey`). `supportedLocales` lists `en-US` and `is-IS`, and
`features` carries `TranslationFile`.

- ⚠️ **`EULA` still points at the Cloud Events terms of use** (the Prismic-hosted
  `Origo_BC_Cloud_Events_Terms_of_Use` PDF), carried over from the source app. **Needs a decision
  before AppSource submission** — publish a Bifröst EULA, or reuse this one deliberately. Already
  recorded as a release note in the CHANGELOG.
- ✅ **`help` and `contextSensitiveHelpUrl` use `businesscentralal.github.io`** instead of
  `bifrost.origo.is`. Approved: the DNS record does not exist yet, and the URLs move with it.

`suppressWarnings` carries `AS0081` only — pre-existing and unchanged by this PR.

---

## Check 7 — CHANGELOG and README

**CHANGELOG** — `## [29.0.0.0] - 2026-09-06` exists, is not empty, has no `[DRAFT]` marker, and uses
the `YYYY-MM-DD` date format. This run added two sections to it, `Security (2026-09-07)` and
`Performance (2026-09-07)`, describing every change below in user-facing terms.

**README** — present and current. It does not follow the ten-section documentation-writer template,
because the substantive documentation for this app lives on the Bifröst site and the README is
deliberately a repository guide (layout, dependencies, development, setup, known issues). That is
the same shape the sibling Bifröst repositories use. The `Known issues` section still matches the
four stub message types waiting on Microsoft. Nothing in this PR changes the object inventory or the
dependencies, so no section went stale.

---

## Check 8 — Help pages

⏭ **Skipped.** The app declares no pages and no page extensions, so there is no
`ContextSensitiveHelpPage` property anywhere and no slug to resolve. `app.json` still carries
`contextSensitiveHelpUrl` and `supportedLocales`, which is correct — the message-type help documents
are returned inline by each `Impl` codeunit's `GetMessageHelpAsMarkdownDocument`, and the 22 of them
are exercised by `AllTypes_ReturnAHelpDocument` and `AllTypes_HelpDocumentsTheRequestAndResponse`.

---

## Check 9 — Documentation

- CHANGELOG: two new sections, above.
- XML documentation added to every procedure introduced by this PR: `Sub Helper ori`
  `GetEntryNoSelection`, `Sub Con GetLines Impl ori` `BelongsToContractCustomer`,
  `Sub PU SetFilter Impl ori` `TrySetView`.
- The five new test procedures carry `[GIVEN] / [WHEN] / [THEN]` comments in the house style.
- No help document text changed: none of the fixes alters a documented request or response shape.
  The one behavioural change a caller can observe — a duplicate `vendorInvoiceNo` now being refused
  — is a Business Central control being enforced rather than a contract change, and is recorded in
  the CHANGELOG.

---

## Check 10 — Unit tests

| Container | Company | Codeunits | Tests | Passed | Failed |
| --- | --- | ---: | ---: | ---: | ---: |
| `bc28-is` (f068155f0c39dev) | CRONUS IS | 2 | **23** | **23** | 0 |
| `bc28-w1` (f089d7daffb9dev) | CRONUS International Ltd. | 2 | **23** | **23** | 0 |

18 before this run, 23 after. The five new ones cover `Sub Helper ori.GetEntryNoSelection`, which is
the shared entry-number parser both `GetLines` types now use — the code path behind security
findings L3 and F4:

| Test | Covers |
| --- | --- |
| `GetEntryNoSelection_BuildsAFilterOverTheDistinctEntryNos` | happy path, duplicates folded, filter built |
| `GetEntryNoSelection_SelectsEverything_WhenThePropertyIsMissing` | absent property means "take everything" |
| `GetEntryNoSelection_Errors_OnAnElementThatIsNotANumber` | a non-numeric element is rejected, not skipped |
| `GetEntryNoSelection_Errors_OnANestedElement` | a nested array is rejected before `AsValue` is called |
| `GetEntryNoSelection_DropsTheFilter_WhenTheListIsTooLongForOneExpression` | the filter-length bound |

The rest of the changes are not unit-testable without the Microsoft app's contract, billing and
deferral data — see Check 13.

---

## Check 11 — Story-doc consistency

⏭ **Skipped.** The repository has no `stories/` folder and the diff carries no `// Story #N`
comments. Acceptance criteria in Check 12 are inferred from the code and the two sub-audits.

---

## Check 12 — Logic review: the security and performance audits

```
╭──────────────────────────────────────────────────────────────╮
│  What this PR does:                                          │
│  Migrates Origo Cloud Events Subscription Billing to         │
│  Bifrost Subscription Billing 29.0.0.0 in place — same app   │
│  id, same object ids, new namespace, mandatory ` ori`        │
│  affix, 22 unchanged message-type keys. This gateway run     │
│  adds the security and performance fixes below.              │
╰──────────────────────────────────────────────────────────────╯
```

### Security

| Id | Site | Finding | Disposition |
| --- | --- | --- | --- |
| **M1** | `SubPUSetFilterImpl:92,114` | The caller's `filter` text went into `RRef.SetView` unguarded. A malformed view raised Business Central's own parser error, which names neither the parameter nor the shape it wanted, and can quote internals of the table being opened. | **Fixed.** `SetView` is wrapped in a `[TryFunction]` (`TrySetView`) and failure raises a curated bilingual `InvalidFilterErr` naming the target and the expected form. |
| **M2** | `SubVendCrInvoiceImpl:205,209` | `PurchaseHeader."Vendor Invoice No." := …; Modify(true)` assigned the field directly, bypassing its `OnValidate` — which is where the vendor's duplicate-invoice-number control lives. The same vendor invoice number could be booked twice under two different documents. | **Fixed.** Both sites (invoice and credit memo) now use `Validate("Vendor Invoice No.", …)`. This is a deliberate behaviour change: a duplicate is now refused, as it is in the user interface. |
| **L3** | `SubConGetLinesImpl:104-110` | Unguarded `AsValue().AsInteger()` over the caller's array, and an unbounded `'|'` filter string built from it. | **Fixed**, and unified with the vendor twin — see below. |
| **L4** | `SubUsgProcessImpl:89` | Unguarded `Evaluate(EntryNo, Argument.Subject, 9)` on free caller text. | **Fixed.** A non-numeric subject now raises `InvalidSubjectErr`, naming the subject and both ways to supply the entry number. Proven end to end through the queue API (below). |
| **L5** | 8 sites | `GetLastErrorText()` relayed verbatim to the caller (`SubUsgImportImpl:132,140`, `SubUsgProcessImpl:186`, `SubBilCrDocsImpl:218`, `SubImpCrContrImpl:170,195,220,245`). | **Reported, not changed** — design decision. These are Microsoft's own posting and import errors, which are the only useful diagnosis the caller can get, and every one is returned as `status = Error` through the isolation boundary rather than as an unhandled exception. Replacing them with curated text would make the app less debuggable, not more secure. |

**L3 and F4 together.** The two `GetLines` types read the same parameter in two different, and both
imperfect, ways: the customer twin trusted every element was an integer and built an arbitrarily
long filter string; the vendor twin validated properly but then read every unassigned Subscription
Line and sorted the selection out in memory. They now share one helper,
`Sub Helper ori.GetEntryNoSelection`, which validates each element (rejecting anything that is not a
value, and anything that does not read as a whole number under format 9), folds duplicates, and
returns the narrowest safe filter: the values themselves while the list is short enough for one
filter expression, and an empty filter past that point, where the caller falls back to a
dictionary lookup per row. Both paths select exactly the same rows; neither can run into the length
a filter expression is allowed to have.

**Clean, verified during the audit:** no secrets and no `IsolatedStorage` use; no `HttpClient` and
no outbound calls of any kind; no published integration events; all three permission sets are
least-privilege (execute-only on this app's own codeunits, no `tabledata` grants — the message types
run under the caller's own permissions on Microsoft's tables); all 22 message types call
`AssertVersion1` and `AssertIsLicensed` before doing anything.

### Performance

| Id | Site | Finding | Disposition |
| --- | --- | --- | --- |
| **F1** | `SubDefReleaseImpl:166-185` | Counted unreleased deferrals up to 12 times per call on `Released` and `Posting Date`, neither of which carries an index. Four of those counts were literal duplicates. | **Fixed.** The four pre-run counts are taken once, before the over-release precondition, and the precondition reuses the two window counts. Worst case drops from 12 table scans to 10. |
| **F2** | `SubBilCrDocsImpl:220-240` | `ProcessedEntryNos.Contains` — an O(m×n) walk of a growing list, once per Billing Line read back. Same shape for `DistinctComboKeys` and `DistinctDocumentNos`. | **Fixed**, but not the way the sub-audit proposed. All three lists are now dictionaries, so each test is one lookup. The suggested `Entry No.` watermark does **not** work here: `Create Billing Documents` updates the pending rows in place rather than inserting new ones, so a `> watermark` filter cannot separate this run's rows from an earlier run's — which is exactly why the code captured the entry numbers up front. The archive read at line 243 keeps its watermark, because those rows really are new. |
| **F3** | `SubRenCrQuoteImpl:96-107` | N+1 `SubscriptionLine.Get` inside the contract-line loop. | **Reported, not changed.** Iterating `Subscription Line` filtered by contract instead would change which rows are considered and in what order: the loop is driven by `Cust. Sub. Contract Line`, and the two sets are not guaranteed identical (comment lines carry entry number 0, and the renewal-line insertion order follows the contract lines). The lookup is a primary-key `Get`. `SetLoadFields` was added to the driving loop; the `Get` itself must stay a full read because the record is handed whole to `InitFromServiceCommitment`. |
| **F4** | `SubVendGetLinesImpl:99-112` | In-memory `List.Contains` inside `FindSet`. | **Fixed** — folded into the shared helper above; the selection is pushed into `SetFilter` before `FindSet`. |
| **F5** | `SubConGetLinesImpl:113-118` | `SubscriptionHeader.Get` per line to read one field. | **Fixed.** `BelongsToContractCustomer` reads the header once per distinct header, with `SetLoadFields("End-User Customer No.")`, and caches the answer for the rest of the run. |
| **F6** | `SubBilPrvDocsImpl:173-202` | Three passes plus two queries per group plus manual summation. | **Fixed.** One pass, accumulating count, total and partner per group in dictionaries. Group order is preserved by keeping the keys in a separate list, because a dictionary makes no promise about key order. Output is byte-identical: `contractNo` was always the group key when grouping by contract and always blank when grouping by customer; `partnerNo` was always the first row's value in the same sort order. |
| **F7** | `SubImpCrContrImpl:172,197,222,247` | `Commit()` inside the repeat loops on failure. | **Reported, not changed.** These commits are load-bearing, not sloppy. Each loop calls `Codeunit.Run` per row and catches the failure; the `Modify` + `Commit` persists the row's error text and, more importantly, leaves the transaction clean so the *next* `Codeunit.Run` in the loop can still be caught. Collecting failures and writing once after the loop would leave a dirty transaction across the catch boundary — the same trap `Sub Ren CrQuote Impl ori` already documents in a comment. Changing it risks turning a per-row error report into "an error occurred and the transaction is stopped". |
| **F8** | `SubBilCrDocsImpl:158,160` | `Count()` used only as an existence test. | **Fixed.** Both are `IsEmpty()` now and the two counters became booleans. The `Count()` at line 153 stays — that one is reported to the caller. |
| **F9** | 9 sites | Missing `SetLoadFields`. | **Fixed** — see Check 4. |
| **F10** | `SubAnaRecalcImpl:90-96` | Unindexed count over `Subscription Contract No.`. | **Reported.** The first count filters on `Entry No.` (the primary key) and is fine; the second counts every analysis entry for the contract with no supporting index. It runs once per call and the table is small in practice. Worth a key if contract analysis grows. |
| **F11** | — | Optional `SetCurrentKey("Subscription Header No.", Partner)`. | **Reported.** Speculative without a measured plan; the filter set already includes `Invoicing via`, `Subscription Contract No.` and `Partner`, and SQL picks its own index. Not worth adding blind. |

### Blindspot questions

- 👁 **`Validate` on `Vendor Invoice No.` can now fail mid-loop (M2).** The stamping loop walks every
  document the run created. If the second document's vendor invoice number collides, the first is
  already stamped and the error rolls back to `Sub Write Process ori`. That is the correct outcome —
  the whole call rolls back — but a caller who passes one `vendorInvoiceNo` for a run that produces
  several documents will now get an error where it previously got silent duplicates. Was that
  multi-document case ever intended?
- 👁 **The filter-length threshold is a judgement, not a measurement.** `GetEntryNoSelection` switches
  to the dictionary path above 50 entry numbers. That is comfortably inside what Business Central
  accepts, but it was chosen rather than measured. Both paths return the same rows, so the only
  consequence of it being wrong is a slower read.
- 👁 **`Sub Bil CrDocs Impl ori` still relays `GetLastErrorText()` (L5) in the one place it matters
  most** — line 218, after Microsoft has already committed some documents. The response says so
  explicitly and lists what survived, which is the right call, but it is worth knowing that this is
  the one message type that can return `status = Error` with real documents standing behind it.

---

## Check 14 — Role coverage

✅ **Pass.** All 34 codeunits are granted execute in `BIFROST SubBil ori` (10035062, `Assignable`,
`Access = Public`), and `BIFROST SubBFull ori` / `BIFROST SubBRead ori` extend the Foundation role
sets. No new objects were introduced by this PR, so no new grants were needed. There are no tables
or pages in this app, so there is no `tabledata` surface to keep least-privilege — the message types
run under the caller's own permissions on Microsoft's Subscription Billing tables, which is stated
in the permission set's own XML documentation.

---

## Check 15 — Platform integration

⏭ **Skipped.** This PR targets a customer/product app, not `bc-dev-standards`.

---

## Queue-API evidence

Twelve calls against `bc28-is` through the Bifröst queue route
(`.../f068155f0c39rest/api/origo/bifrost/v1.0/companies(b93c35e0-…)/tasks`), CloudEvents 1.0
envelopes, `data` as a JSON string, serial, credentials read from the user-level environment
variables and never echoed. Every call returned a curated `status` — no HTTP 5xx, no raw exception,
no `An error occurred and the transaction is stopped`.

| Case | Type | taskId | Result |
| --- | --- | --- | --- |
| **L4 guard, non-numeric subject** | `Subscription.Usage.Process` | `60ae3b6a-9d11-4b4a-ada7-01e67e2f567d` | `Error` — *"The subject 'BIFT-S-abc' is not a Usage Data Import entry number. Send the entry number as the subject, or as 'usageDataImportEntryNo' in the request."* ✅ the new guard, verbatim |
| Unknown import entry | `Subscription.Usage.Process` | `d1c3a9fd-dad1-4b4e-84e5-287d943ba319` | `Error` — "The Usage Data Import entry 999999 does not exist." |
| Malformed filter (M1) | `Subscription.PriceUpdate.SetTemplateFilter` | `6bddde1e-ac9e-4d7b-8f00-bab0ca401499` | `Error` — stops at the template precondition (see Check 13) |
| Bad target | `Subscription.PriceUpdate.SetTemplateFilter` | `f6a7c969-be9b-4a06-9d46-385617ff8682` | `Error` — same precondition |
| Bad entry-no array (L3) | `Subscription.Contract.GetLines` | `e5aacdfa-54d5-4867-aed2-9220039b7e35` | `Error` — stops at the contract precondition |
| Bad entry-no array (F4) | `Subscription.VendorContract.GetLines` | `caeb3fd2-9ea1-4a36-b8cd-fc289fdcd25b` | `Error` — stops at the contract precondition |
| Grouping pass (F6) | `Subscription.Billing.PreviewDocuments` | `b8420323-98f0-4282-a2d7-316c4efb1bdb` | `Error` — stops at the template precondition |
| Partner probe (F2/F8) | `Subscription.Billing.CreateDocuments` | `83971cac-3fae-45cc-b09b-a6bb9d1df434` | `Error` — stops at the template precondition |
| Over-release precondition (F1) | `Subscription.Deferral.Release` | `44a7f811-4e0f-4fbb-93ba-f54f3be5c6a0` | `Error` — the full curated work-date explanation, reached **after** the reordered counts ran ✅ |
| Watermark read (F9) | `Subscription.Analysis.Recalculate` | `822d1468-55a3-49be-8864-84fdded88419` | **`Success`** — `{"status":"Success","analysisDate":"2026-09-07","entriesCreated":0,"totalEntries":0}` ✅ the `SetLoadFields` watermark path end to end |
| Unknown contract (M2) | `Subscription.VendorContract.CreateInvoice` | `4af713b8-5e3d-4e3e-9d74-84075da272dd` | `Error` — stops at the contract precondition |
| Contract-line scan (F9) | `Subscription.Renewal.CreateQuote` | `8a0cd0b8-ae55-4b2e-bd88-58180043cdf3` | `Error` — stops at the contract precondition |

No test data was created and no master data was touched. Test subjects used the `BIFT-S` prefix.

**Environment note, not a defect in this app.** When the run started, *Bifrost Subscription Billing*
was published on `bc28-is` but **not installed** in CRONUS IS, so the queue route answered
*"Unknown message type"* for all 22 types. The unit tests still passed, because the AL test runner
executes inside the developer session where dev-published apps are loaded — the two do not prove the
same thing. A `ForceSync` republish completed the install (asynchronously; the extension list only
showed `installed=True` a minute later) and the calls above were then made against the installed
app. Worth knowing for the next gateway run on this container: verify installation, not just
publication, before reading anything into a queue result. `list_message_types` on the MCP server was
still not showing the `Subscription` namespace after the reinstall while the queue calls above were
succeeding, so the MCP catalogue and the live route were disagreeing — the queue results are the
authoritative ones here.

---

## Check 13 — What I couldn't check

- **The M1 filter guard was not reached through the API.** `TrySetView` is exercised only after the
  Price Update Template exists, and every queue attempt stopped at the template precondition.
  Creating a `Price Update Template` on `bc28-is` needs table 8003 field 1 added to the ChangeLog
  Write Guard whitelist, and Foundation's test-only `Test.Setup.*` types were not resolvable on the
  container during this run. The guard is three lines, compiles, and its failure path is a single
  `Error` call — but it has not been observed failing. **Worth one manual call once a template
  exists.**
- **The L3/F4 array guard was not reached through the API either**, for the same reason (both
  `GetLines` types check the contract first). It is covered instead by four of the five new unit
  tests, which exercise the helper directly on both containers.
- **No behavioural test of M2's duplicate refusal.** Proving it needs a vendor subscription contract
  with due lines and an existing posted purchase invoice carrying the same vendor invoice number —
  Microsoft Subscription Billing demo data that this container does not have set up. The change is a
  one-token substitution (`:=` → `Validate`) whose semantics are Microsoft's, but the refusal itself
  was not observed.
- **The object-id workbook was not re-read.** The range was verified against `app.json`,
  `.claude/CLAUDE.md` and a full source scan; `check_app_range` was not reachable from this session,
  and `origo_cloudevents_object_ranges.xlsx` was not opened.

Everything else in the gateway ran to completion: both projects compiled with the full analyzer set,
both containers were published and ran the full suite, and every Layer 1 finding was read against
the source rather than counted.

---

## Verdict

✅ **Ready to merge.** No failed checks. One warning (the Cloud Events `EULA` in `app.json`) that is
a business decision before AppSource submission, not a code defect, and is already recorded as a
release note.

Fixed in this run: 2 medium and 2 low security findings, 6 performance findings, 10 `SetLoadFields`
sites. Reported and deliberately not changed: 1 security finding (L5, verbatim error relay) and 4
performance findings (F3, F7, F10, F11), each with the reason above. Five new unit tests; 23/23
green on both containers; twelve queue calls, all answering with a curated status.
