namespace Origo.Bifrost.SubscriptionBilling.Test;

using System.Environment.Configuration;
using System.TestTools.TestRunner;

/// <summary>
/// Registers the Bifrost Subscription Billing test codeunits in their own AL Test Suite so a test
/// run can select them without touching the shared DEFAULT suite of the container, where a dozen
/// Bifröst and Cloud Events test apps are installed side by side. The suite name is the one
/// tools/Run-BifrostTests.ps1 derives from the test app name.
/// </summary>
codeunit 95700 "Sub Test Install ori"
{
    Subtype = Install;

    var
        SuiteNameTok: Label 'SUBSCRIPTI', Locked = true;
        ObjectRangeTok: Label '95700..95799', Locked = true;
        FoundationAppIdTok: Label '7505e808-6e52-4b96-a328-82573391297a', Locked = true;
        SubscriptionBillingAppIdTok: Label 'dd7b8bd8-f93e-4ac4-a251-1a132a14ef3d', Locked = true;

    trigger OnInstallAppPerCompany()
    begin
        EnableHttpForDispatcherTests();
        RefreshTestSuite();
    end;

    /// <summary>
    /// Allows HttpClient requests for Bifrost Foundation and this app, as the Foundation test app does for itself
    /// (core PR #1000). Since that change Foundation no longer turns HTTP on while dispatching, and in an evaluation
    /// sandbox it refuses every licensed call while a registered Bifrost app has HTTP off, so the dispatcher tests
    /// would only ever see that refusal. Only the test app's install does this; production install is unchanged.
    /// </summary>
    local procedure EnableHttpForDispatcherTests()
    begin
        EnableHttp(FoundationAppIdTok);
        EnableHttp(SubscriptionBillingAppIdTok);
    end;

    local procedure EnableHttp(AppIdText: Text)
    var
        NavAppSetting: Record "NAV App Setting";
        AppId: Guid;
    begin
        Evaluate(AppId, AppIdText);
        if not NavAppSetting.Get(AppId) then begin
            NavAppSetting.Init();
            NavAppSetting."App ID" := AppId;
            NavAppSetting."Allow HttpClient Requests" := true;
            NavAppSetting.Insert();
        end else
            if not NavAppSetting."Allow HttpClient Requests" then begin
                NavAppSetting."Allow HttpClient Requests" := true;
                NavAppSetting.Modify();
            end;
    end;

    /// <summary>Rebuilds this app's own suite from its own object range. Safe to call repeatedly.</summary>
    internal procedure RefreshTestSuite()
    var
        ALTestSuite: Record "AL Test Suite";
        TestMethodLine: Record "Test Method Line";
        TestSuiteMgt: Codeunit "Test Suite Mgt.";
        SuiteName: Code[10];
    begin
        SuiteName := CopyStr(SuiteNameTok, 1, MaxStrLen(SuiteName));
        if not ALTestSuite.Get(SuiteName) then begin
            TestSuiteMgt.CreateTestSuite(SuiteName);
            Commit();
            ALTestSuite.Get(SuiteName);
        end;

        TestMethodLine.SetRange("Test Suite", ALTestSuite.Name);
        TestMethodLine.SetFilter("Test Codeunit", ObjectRangeTok);
        if not TestMethodLine.IsEmpty() then
            TestMethodLine.DeleteAll(true);

        TestSuiteMgt.SelectTestMethodsByRange(ALTestSuite, ObjectRangeTok);
    end;
}
