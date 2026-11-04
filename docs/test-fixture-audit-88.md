# Reused-container fixture audit (#88)

Audited all 41 AL files in `test/src` for inserts, literal primary keys, temporary records, shared fixture helpers and cleanup. This is a source audit; live results are recorded separately.

| Fixture family | Ownership / repeatability |
| --- | --- |
| 95723 refusal empty filter | Replaced `XS62-TEMPLATE` with an X-prefixed GUID code. Every invocation deletes its row and asserts absence. English and Icelandic tests each call the scenario twice. |
| 95723 domain-selection refusals | Replaced fixed contract, subscription, template and invoice keys with X-prefixed GUID codes. Each expected error rolls back the preceding scenario's SQL fixtures; no commit is used on this direct path. |
| 95708 price-update filters | Existing template is deleted before insert. Fixed customer/vendor contracts now also delete prior matching fixture rows before insert. Each test removes its exact reserved fixture contracts and template after all assertions. |
| 95709 billing-preview paging | Template insertion is guarded by Get; lines are cleared by exact template before each case. Entry numbers start after the current maximum. |
| 95711/95712/95713/95714/95715/95716 Branch A | Each Initialize removes its reserved fixture keys or invokes the X-prefix-scoped shared cleanup before insertion. Job Queue entries use fresh SystemIds. No additional unguarded fixed-code insertion found. |
| 95705 import-contract staging | Header uses the test library's generated number; imported lines are keyed by that header and line number. Comment scenario clears its header's imported rows first. |
| 95718 posting | Purchase invoice uses Library - Utility's generated code; posted invoice numbers derive from uniquely generated documents. |
| 95720 merge | Subscription/contract records use library-generated numbers; comments include that generated subscription key. Billing lines use AutoIncrement entry numbers. Fixed serial/reference text is not an inserted primary key. |
| 95740–95743 price updates | NewCode generates unique contract/header/template keys. Contract-type insertion handles an existing reserved code explicitly. Temporary proposal/line records are not persistent collisions. |
| 95770 shared behavior library | Customers/vendors/items and setup number series come from Microsoft libraries; package/template codes use generated codes. Fixed deferral source code is guarded by Get. |
| 95773–95778 behavior tests | Use the shared generated fixture graph. Usage import suppliers and exchange definitions have generated keys; the literal line code is scoped by its unique definition. Supplier reference inserts check their composite key. |
| Other test codeunits | No persistent fixed-key Insert: contract/help/registration/permission/wizard checks either read data, delegate to the audited libraries, or use temporary Message Argument records. |

The test app's installer and upgrade register its own SUBSCRIPTI suite. No consent, licence, HTTP, production behavior, assertion, warning exclusion or pipeline setting is changed.
