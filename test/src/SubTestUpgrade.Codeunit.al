namespace Origo.Bifrost.SubscriptionBilling.Test;

/// <summary>
/// Refreshes the SUBSCRIPTI test suite when the test app is republished. OnInstallAppPerCompany
/// only fires on a genuinely fresh install, so without this an in-place version upgrade left the
/// suite pointing at the previous release's test methods - the defect recorded as observation 2 in
/// test/reports/Bifrost_SubscriptionBilling_TestReport_2026-09-06.md.
/// </summary>
codeunit 95703 "Sub Test Upgrade ori"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        TestInstall: Codeunit "Sub Test Install ori";
    begin
        TestInstall.RefreshTestSuite();
    end;
}
