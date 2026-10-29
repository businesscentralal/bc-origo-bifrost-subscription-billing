namespace Origo.Bifrost.SubscriptionBilling.Test;

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

        // [WHEN] The posting type is asked whether it is enabled, and the gate is asked to allow a post
        // [THEN] Both refuse, and the denial names BIFROST SubPost ori with code PermissionDenied
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
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
}
