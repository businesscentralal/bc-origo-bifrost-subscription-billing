namespace Origo.APP.CloudEvents.SubscriptionBilling;

using System.TestTools.TestRunner;

/// <summary>
/// Builds the DEFAULT AL test suite when the test app is installed, so the test explorer and the
/// AL-Go pipeline both find the Subscription Billing tests without any manual setup.
/// </summary>
codeunit 95700 "CE Sub Test Install ori"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        ALTestSuite: Record "AL Test Suite";
        TestSuiteMgt: Codeunit "Test Suite Mgt.";
        SuiteName: Code[10];
    begin
        SuiteName := 'DEFAULT';
        if ALTestSuite.Get(SuiteName) then
            exit;
        TestSuiteMgt.CreateTestSuite(SuiteName);
        ALTestSuite.Get(SuiteName);
        TestSuiteMgt.SelectTestMethodsByRange(ALTestSuite, '95700..95799');
    end;
}
