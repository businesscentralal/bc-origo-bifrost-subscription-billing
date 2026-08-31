namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Origo.APP.CloudEvents;

/// <summary>
/// Extends the Cloud Events read-only permission set with the Subscription Billing helper objects.
/// Read-only users can discover the message types and read their help documents; the write and
/// preview operations still require the write permissions the underlying tables demand.
/// </summary>
permissionsetextension 10035064 "CE Sub Bil Read ori" extends "CE Read All ori"
{
    Permissions =
        codeunit "CE Sub Helper ori" = X;
}
