namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost.SubscriptionBilling;
using System.TestTools.TestRunner;

/// <summary>
/// Builds the DEFAULT AL test suite when the test app is installed, so the test explorer and the
/// AL-Go pipeline both find the Subscription Billing tests without any manual setup. The suite is
/// rebuilt rather than only created once: a DEFAULT suite that already exists keeps the method
/// list it was given the first time, so a test codeunit added in a later version would never
/// appear in it.
/// </summary>
codeunit 95700 "Sub Test Install ori"
{
    Subtype = Install;

    var
        SuiteNameTok: Label 'DEFAULT', Locked = true;
        ObjectRangeTok: Label '95700..95799', Locked = true;

    trigger OnInstallAppPerCompany()
    begin
        RefreshTestSuite();
    end;

    /// <summary>Creates the DEFAULT suite when it is missing, then re-selects this app's test methods into it.</summary>
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
            ALTestSuite.Get(SuiteName);
        end;

        // Drop only this app's own lines, so a suite someone has added other codeunits to keeps them.
        TestMethodLine.SetRange("Test Suite", ALTestSuite.Name);
        TestMethodLine.SetFilter("Test Codeunit", ObjectRangeTok);
        if not TestMethodLine.IsEmpty() then
            TestMethodLine.DeleteAll(true);

        TestSuiteMgt.SelectTestMethodsByRange(ALTestSuite, ObjectRangeTok);
    end;
}
