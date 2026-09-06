namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Origo.APP.CloudEvents;

/// <summary>
/// Extends the Cloud Events read-only permission set with the shared Subscription Billing helper.
/// Every Subscription Billing message type either writes or runs a preview inside a transaction,
/// so none of them are granted here on purpose: a read-only Cloud Events user is not meant to
/// invoke any of them. Invoking one requires "CE Sub Bil Obj ori" or "CE Sub Bil Full ori".
/// </summary>
permissionsetextension 10035064 "CE Sub Bil Read ori" extends "CE Read All ori"
{
    Permissions =
        codeunit "CE Sub Helper ori" = X;
}
