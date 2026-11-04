namespace Origo.Bifrost.SubscriptionBilling.Test;

/// <summary>Identifiers of data explicitly seeded in an individually owned development container for live MCP checks.</summary>
table 95728 "Sub MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Subscription MCP Fixture';
    fields
    {
        field(1; "Fixture Key"; Code[20]) { Caption = 'Fixture Key'; }
        field(2; Name; Code[30]) { Caption = 'Name'; }
        field(3; Value; Text[250]) { Caption = 'Value'; }
    }
    keys { key(PK; "Fixture Key", Name) { Clustered = true; } }
}
