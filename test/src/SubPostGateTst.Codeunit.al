namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Deny path for the subscription billing posting gate (#52).
/// BIFROST Full ori includes BIFROST SubBil ori and does not include BIFROST SubPost ori.
/// </summary>
codeunit 95719 "Sub Post Gate Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC02_WithoutSubPost_PostingIsDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PostImpl: Codeunit "Sub Bil PostDocs Impl ori";
        PostingGate: Codeunit "Sub Posting Gate ori";
        PermissionsMock: Codeunit "Permissions Mock";
        Configured: Codeunit "Sub Configured ori";
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        ErrorToken: JsonToken;
        IsEnabled: Boolean;
        HasPostingPermission: Boolean;
        CanPost: Boolean;
    begin
        // Issue #52, AC02 | Time: none | Risk: None
        // [GIVEN] The session holds only BIFROST Full ori, which does not grant the posting token
        Assert.IsTrue(PermissionsMock.IsStarted(), 'The test runner must enable permission mocking.');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);

        // [WHEN] The company is configured, the posting type is asked whether it is enabled, and the gate is asked to allow a post
        // [THEN] Both refuse, and the denial names BIFROST SubPost ori with code PermissionDenied
        LowerPermissions.SetOutsideO365Scope();
        EnsureConfiguredCompany();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        // Full does not grant the Microsoft setup table. This test-only read lets the availability
        // check see the series, so a disabled PostDocuments is the posting token and not a hidden company.
        LowerPermissions.AddPermissionSet('Sub Cfg Read ori');
        Assert.IsTrue(Configured.IsConfigured(), 'The company is configured, so the remaining gate is the posting permission.');
        IsEnabled := PostImpl.IsEnabled();
        HasPostingPermission := PostingGate.HasPostingPermission();
        CanPost := PostingGate.AssertCanPost(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        LowerPermissions.SetOutsideO365Scope();

        // Assertion-library Execute permission is test infrastructure, not a product grant.
        Assert.IsFalse(IsEnabled, 'PostDocuments must be disabled without BIFROST SubPost ori.');
        Assert.IsFalse(HasPostingPermission, 'HasPostingPermission must be false without the token.');
        Assert.IsFalse(CanPost, 'AssertCanPost must deny without the token.');
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'The denial must carry a code.');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('error', ErrorToken), 'The denial must carry an error.');
        Assert.AreNotEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST SubPost ori'), ErrorToken.AsValue().AsText());
    end;

    local procedure EnsureConfiguredCompany()
    var
        Setup: Record "Subscription Contract Setup";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        if (Setup."Subscription Header No." = '') and (Setup."Cust. Sub. Contract Nos." = '') and (Setup."Vend. Sub. Contract Nos." = '') then begin
            Setup."Subscription Header No." := 'SB98';
            Setup.Modify(false);
        end;
    end;
}
