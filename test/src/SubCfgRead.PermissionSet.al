namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Test-only read of Subscription Contract Setup (#98).
/// BIFROST Full ori does not grant this Microsoft table. The posting-gate test adds this set
/// so the availability check can see the number series and the remaining denial is the posting token.
/// </summary>
permissionset 95726 "Sub Cfg Read ori"
{
    Assignable = true;
    Caption = 'Sub. setup read test', Locked = true;

    Permissions =
        tabledata "Subscription Contract Setup" = R;
}
