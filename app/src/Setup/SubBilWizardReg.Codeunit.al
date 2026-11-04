namespace Origo.Bifrost.SubscriptionBilling;

using System.Environment.Configuration;
using System.Media;

/// <summary>Registers the Subscription Billing assisted setup without configuring or completing it.</summary>
codeunit 10035035 "SubBil Wizard Reg. ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", OnRegisterAssistedSetup, '', false, false)]
    local procedure RegisterWizard()
    var
        GuidedExperience: Codeunit "Guided Experience";
        TitleTxt: Label 'Set up Bifrost Subscription Billing', Comment = 'is-IS=Setja upp Bifröst áskriftareikningagerð';
        ShortTitleTxt: Label 'Bifrost Subscription Billing', Comment = 'is-IS=Bifröst áskriftareikningagerð';
        DescriptionTxt: Label 'Learn about subscription operations, enable HTTP through Bifrost Setup, and review the access users need.', Comment = 'is-IS=Kynntu þér áskriftaraðgerðir, virkjaðu HTTP í uppsetningu Bifröst og farðu yfir aðgang sem notendur þurfa.';
    begin
        GuidedExperience.InsertAssistedSetup(TitleTxt, ShortTitleTxt, DescriptionTxt, 5,
            ObjectType::Page, Page::"SubBil Setup Wizard ori", Enum::"Assisted Setup Group"::Extensions,
            '', Enum::"Video Category"::Uncategorized, 'https://docs.bifrost.origo.is/en-us/subscription-billing/');
    end;
}
