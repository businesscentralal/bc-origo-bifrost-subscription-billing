namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Makes Bifrost Subscription Billing known to Bifrost Foundation's application registry.
/// Setup notifications - enabling outbound HTTP, missing credentials, running the setup wizard -
/// are shown only on Foundation's Bifrost Setup page, which aggregates them over every registered
/// application. This app therefore raises no notification of its own; it only answers the
/// registration event so Foundation can report on it.
/// </summary>
codeunit 10035060 "Sub Registration ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
