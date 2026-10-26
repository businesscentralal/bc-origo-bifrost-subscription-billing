namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Grants Bifrost Subscription Billing posting.
/// Assign explicitly. Not included in BIFROST SubBil ori, BIFROST SubBFull ori or BIFROST SubBRead ori.
/// Sales.Document.Post and Purchase.Document.Post do not cover Subscription.Billing.PostDocuments.
/// </summary>
permissionset 10035086 "BIFROST SubPost ori"
{
    Assignable = true;
    Caption = 'Sub. Billing Posting', MaxLength = 30, Comment = 'is-IS=Bókun áskriftareikninga';
    Permissions =
        tabledata "Sub Posting ori" = RIMD;
}
