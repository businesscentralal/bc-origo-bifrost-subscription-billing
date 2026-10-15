namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost full access permission set with the Subscription Billing objects,
/// so anyone already granted full Bifrost access can invoke these message types too.
/// Execute rights on the implementation codeunits and the shared codeunits they call are required
/// for that: without them the dispatcher resolves the interface and then fails when it runs the
/// implementation. The extension includes "BIFROST SubBil ori" instead of repeating its list, so
/// the two always grant the same objects; add a new object to "BIFROST SubBil ori" only.
/// The message types still run under the caller's own permissions on the Microsoft Subscription
/// Billing tables, so this does not widen access to subscription or contract data.
/// </summary>
permissionsetextension 10035063 "BIFROST SubBFull ori" extends "BIFROST Full ori"
{
    IncludedPermissionSets = "BIFROST SubBil ori";
}
