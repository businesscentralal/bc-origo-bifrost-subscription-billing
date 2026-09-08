namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Asserts that Bifrost Subscription Billing makes itself known to Bifrost Foundation's
/// application registry. Foundation shows the setup notifications for the whole family on its
/// own Bifrost Setup page, and it can only report on an application that answers
/// <c>OnRegisterApps</c> - so losing the subscriber would silently drop this app off that page.
/// </summary>
codeunit 95704 "Sub Registration Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        AppUnderTestId: Guid;
        AppNameTok: Label 'Bifrost Subscription Billing', Locked = true;
        AppIdNotFoundErr: Label 'The test app must depend on %1 for this test to resolve its app id.', Comment = '%1 = the app name', Locked = true;

    [Test]
    procedure GetApps_ListsSubscriptionBilling()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
    begin
        // [GIVEN] The module id of the app under test
        Initialize();

        // [WHEN] Foundation builds the registry of installed Bifrost applications
        AppRegistry.GetApps(TempApps);

        // [THEN] Bifrost Subscription Billing is in it, under its own module id and name
        Assert.IsTrue(TempApps.Get(AppUnderTestId), 'Bifrost Subscription Billing should register itself with the Bifrost application registry.');
        Assert.AreEqual(AppNameTok, TempApps."App Name", 'The registry should carry the app display name.');
        Assert.AreEqual(0, TempApps."Setup Page Id", 'This app has no setup page of its own.');
    end;

    /// <summary>
    /// Resolves the module id of Bifrost Subscription Billing from this test app's own dependency
    /// list, so the test never carries a hard-coded guid.
    /// </summary>
    local procedure Initialize()
    var
        TestAppInfo: ModuleInfo;
        Dependency: ModuleDependencyInfo;
    begin
        Clear(AppUnderTestId);
        NavApp.GetCurrentModuleInfo(TestAppInfo);
        foreach Dependency in TestAppInfo.Dependencies() do
            if Dependency.Name() = AppNameTok then
                AppUnderTestId := Dependency.Id();

        if IsNullGuid(AppUnderTestId) then
            Error(AppIdNotFoundErr, AppNameTok);
    end;
}
