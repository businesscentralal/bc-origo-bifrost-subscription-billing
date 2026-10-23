namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost read-only permission set with the shared Subscription Billing helper.
/// Every Subscription Billing message type either writes or runs a preview inside a transaction,
/// so none of them are granted here on purpose: a read-only Bifrost user is not meant to
/// invoke any of them. Invoking one requires "BIFROST SubBil ori" or "BIFROST SubBFull ori".
/// </summary>
permissionsetextension 10035064 "BIFROST SubBRead ori" extends "BIFROST Read ori"
{
    Permissions =
        page "SubBil Setup Wizard ori" = X,
        codeunit "SubBil Wizard Mgt ori" = X,
        codeunit "SubBil Wizard Reg. ori" = X,
        codeunit "Sub Helper ori" = X;
}
