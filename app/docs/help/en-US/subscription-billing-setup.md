---
title: Set up Bifrost Subscription Billing
---

Open **Assisted Setup**, then **Set up Bifrost Subscription Billing**. The wizard introduces subscription contracts and lines, billing, usage, price updates, renewals, deferrals, analysis and migration. It runs within the signed-in user's permissions.

1. Choose **Show operations** to open the installed Bifrost Message Types list. **Documentation** opens the Subscription Billing documentation.
2. Review **HTTP enabled**. **Enable HTTP in Bifrost Setup** opens Foundation's wizard, where an authorized administrator can enable outbound HTTP. Return and choose **Verify** to read the status again. Subscription Billing does not change extension settings or accept an agreement for you.
3. Review access. `BIFROST SubBil ori` permits operations within the user's existing business-data access. Assign `BIFROST SubPost ori` separately for posting. Users also need the appropriate Foundation permissions. **Open Users** and **Open Permission Sets** open the standard pages; the wizard assigns no permissions.
4. Review the summary and choose **Finish** to mark this assisted setup complete. Closing early preserves its prior completion state. You can run it again later.

The operations list shows the installed message types and their descriptions. Consult a type's help before calling it. Opening the list performs no business operation.
