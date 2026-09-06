# Partner Center description (rich text)

## Run Subscription Billing without the clicks

Microsoft's Subscription Billing app models recurring revenue well, but every meaningful operation
in it lives behind a page action: get subscription lines onto a contract, create the contract
invoice, run the billing proposal, perform the price update, import a usage file. An integration or
an AI agent can read and write subscription records through a generic API, and then stops at the
first button.

Origo Bifrost Subscription Billing closes that gap. It publishes a curated set of Bifrost
message types - one per operation that genuinely needs a codeunit, record context at insert time, a
stored filter, or a preview-and-rollback run - so the whole application surface becomes callable.

## Who is this for?

**Finance teams running high-volume recurring billing.** Schedule the monthly billing proposal and
document creation, and let exceptions come to you instead of working every contract by hand.

**Partners building integrations.** A stable, documented, versioned message-type surface rather
than page automation that breaks on the next update.

**Teams adopting AI agents in Business Central.** Every message type ships a full help document -
purpose, parameters, a worked example, the response shape and the errors it raises - so an agent can
discover what it can do and call it correctly on the first attempt.

## Key capabilities

- **Commitments** - create subscription lines by applying a subscription package, which a plain
  record insert cannot do because the package context is required up front.
- **Customer and vendor contracts** - attach unassigned subscription lines to a contract and bill a
  contract to an unposted invoice.
- **Billing pipeline** - build a billing proposal for a template and date range, then turn the
  proposal into documents in a bulk run.
- **Preview without writing** - preview the customer, vendor and bulk billing runs. The work is
  performed for real so the numbers are true, then the whole transaction is rolled back and nothing
  is left behind.
- **Usage-based billing** - import a usage file as data rather than through a file dialog, and run
  Microsoft's processing stages over it.
- **Deferrals, analysis and migration** - release deferred revenue and cost for a period, rebuild
  contract analysis entries, and create real subscriptions and contracts from staged import rows.

## Designed to be safe

No message type deletes anything. Ending a subscription is an end date, not a hard delete. Every
write runs in an isolated transaction that rolls back cleanly and returns a structured error with
the failure and its call stack. Operations that post to the general ledger say so plainly in their
help, and nothing posts unless you ask for it.

## Built on Bifrost Core

This extension requires Origo Bifrost Core, which provides the message dispatcher, the request
log, the change-log write guard and the permission model. Subscription Billing message types appear
alongside the Core ones and are discovered the same way.
