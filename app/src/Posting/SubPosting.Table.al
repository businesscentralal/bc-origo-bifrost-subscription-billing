namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Permission token for BIFROST SubPost ori.
/// No records are stored. WritePermission() on this table is the posting gate for
/// Subscription.Billing.PostDocuments. It is not included in BIFROST SubBil ori.
/// </summary>
table 10035083 "Sub Posting ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'BIFROST SubPost ori', Comment = 'is-IS=Bifröst bókun áskrifta';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
