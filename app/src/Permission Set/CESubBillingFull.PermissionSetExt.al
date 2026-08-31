namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Origo.APP.CloudEvents;

/// <summary>
/// Extends the Cloud Events full access permission set with the Subscription Billing objects,
/// so anyone already granted full Cloud Events access can invoke these message types too.
/// </summary>
permissionsetextension 10035063 "CE Sub Bil Full ori" extends "CE Full Access ori"
{
    Permissions =
        codeunit "CE Sub Helper ori" = X,
        codeunit "CE Sub Write Process ori" = X;
}
