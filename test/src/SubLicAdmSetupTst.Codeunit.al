namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Opens Foundation setup with this app installed under the licence-administrator role.
/// Registration must work without granting the role Subscription Billing or setup-write access.
/// </summary>
codeunit 95728 "Sub LicAdm Setup Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        PermissionsMock: Codeunit "Permissions Mock";

    /// <summary>Exercises licence-administrator setup access in English.</summary>
    [Test]
    procedure Scenario_AC03_LicenceAdmin_OpensReadOnlySetupEnglish()
    begin
        // Issue #80, AC03 | Time: none | Risk: Foundation must be at least 28.0.10.
        VerifySetupAccess(1033);
    end;

    /// <summary>Exercises licence-administrator setup access in Icelandic.</summary>
    [Test]
    procedure Scenario_AC03_LicenceAdmin_OpensReadOnlySetupIcelandic()
    begin
        // Issue #80, AC03 | Time: none | Risk: Foundation must be at least 28.0.10.
        VerifySetupAccess(1039);
    end;

    local procedure VerifySetupAccess(LanguageId: Integer)
    var
        BifrostSetup: Record "Setup ori";
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        SetupPage: TestPage "Setup ori";
        TestAppInfo: ModuleInfo;
        Dependency: ModuleDependencyInfo;
        AppId: Guid;
        PreviousLanguage: Integer;
        IsEditable: Boolean;
        CanWriteSetup: Boolean;
        IsRegistered: Boolean;
    begin
        // [GIVEN] An installed app and an initialized setup, with permission mocking active.
        Assert.IsTrue(PermissionsMock.IsStarted(), 'The test runner must enable permission mocking.');
        NavApp.GetCurrentModuleInfo(TestAppInfo);
        foreach Dependency in TestAppInfo.Dependencies() do
            if Dependency.Name() = 'Bifrost Subscription Billing' then
                AppId := Dependency.Id();
        Assert.IsFalse(IsNullGuid(AppId), 'The test app must depend on Subscription Billing.');
        BifrostSetup.InsertIfNotExists();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        LowerPermissions.AddPermissionSet('Sub Setup Test ori');

        // [WHEN] The real page invokes registration, before any direct registry warm-up.
        SetupPage.OpenView();
        IsEditable := SetupPage.Editable();
        CanWriteSetup := BifrostSetup.WritePermission();
        SetupPage.Close();
        AppRegistry.GetApps(TempApps);
        IsRegistered := TempApps.Get(AppId);
        LowerPermissions.SetOutsideO365Scope();
        GlobalLanguage(PreviousLanguage);

        // [THEN] Registration succeeds while the administrator boundary remains intact.
        Assert.IsTrue(IsRegistered, 'Subscription Billing must be registered for the licence administrator.');
        Assert.IsFalse(IsEditable, 'A licence administrator must not edit Bifrost Setup.');
        Assert.IsFalse(CanWriteSetup, 'Opening setup must not grant direct setup-write permission.');
    end;
}
