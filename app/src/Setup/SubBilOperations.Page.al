namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>Hosts Foundation's installed message type list in a page that can be opened from assisted setup.</summary>
page 10035036 "SubBil Operations ori"
{
    PageType = Card;
    Extensible = false;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Bifrost Message Types', Comment = 'is-IS=Skilaboðategundir Bifröst';
    ContextSensitiveHelpPage = 'subscription-billing-setup';
    Editable = false;

    layout
    {
        area(Content)
        {
            part(MessageTypes; "Message Type List ori")
            {
                ApplicationArea = All;
            }
        }
    }
}
