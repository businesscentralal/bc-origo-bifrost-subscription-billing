namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Runs the contract paths of the four message types that call <c>Sub Contract Parts ori</c> under
/// the Bifrost full access set alone (#42), so a user who holds only "BIFROST Full ori" (extended by
/// "BIFROST SubBFull ori") can read their help without a permission error.
/// </summary>
codeunit 95771 "Sub Perm Full Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC03_FullSetOnly_ReadsContractOfContractPartsTypes()
    begin
        // Issue #42, AC03 | Time: none | Risk: None
        // [GIVEN] The session holds only BIFROST Full ori
        // [WHEN] The contracts of the four types that call Sub Contract Parts ori are built
        // [THEN] Each contract is built without a permission error
        AssertContract(Enum::"Message Type ori"::"Subscription.Analysis.Recalculate");
        AssertContract(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments");
        AssertContract(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal");
        AssertContract(Enum::"Message Type ori"::"Subscription.Billing.PreviewDocuments");
    end;

    [Test]
    procedure Scenario_AC03_FullSetOnly_RunsImplementationChapters()
    var
        Effect: JsonObject;
        Parameters: JsonArray;
        StartedPermissionsMock: Boolean;
        HasEffect: Boolean;
        HasParameters: Boolean;
        CallSucceeded: Boolean;
        FailureText: Text;
    begin
        // Issue #42, AC03 edge case | Time: none | Risk: None
        // [GIVEN] The session holds only BIFROST Full ori
        StartedPermissionsMock := RestrictToFullSet();

        // [WHEN] The implementation codeunit builds its chapters through Sub Contract Parts ori
        CallSucceeded := TryReadImplementationChapters(Effect, Parameters, HasEffect, HasParameters);
        FailureText := GetLastErrorText();
        RestoreTestPermissions(StartedPermissionsMock);

        // [THEN] The chapters carry content
        Assert.IsTrue(CallSucceeded, FailureText);
        Assert.IsTrue(HasEffect, 'GetEffect must answer.');
        Assert.IsTrue(HasParameters, 'GetParameters must answer.');
        Assert.IsTrue(Effect.Contains('effect'), 'The effect chapter must be built.');
        Assert.IsTrue(Parameters.Count() > 0, 'The parameters chapter must be built.');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori")
    var
        Contract: JsonObject;
        StartedPermissionsMock: Boolean;
        HasContract: Boolean;
        CallSucceeded: Boolean;
        FailureText: Text;
    begin
        StartedPermissionsMock := RestrictToFullSet();
        CallSucceeded := TryReadContract(MessageType, Contract, HasContract);
        FailureText := GetLastErrorText();
        RestoreTestPermissions(StartedPermissionsMock);
        Assert.IsTrue(CallSucceeded, FailureText);
        Assert.IsTrue(HasContract, 'The contract must be built.');
        Assert.IsTrue(Contract.Contains('effect'), 'The contract must carry the effect chapter.');
    end;

    [TryFunction]
    local procedure TryReadContract(MessageType: Enum "Message Type ori"; var Contract: JsonObject; var HasContract: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        HasContract := ContractMgt.GetContract(MessageType, Contract);
    end;

    [TryFunction]
    local procedure TryReadImplementationChapters(var Effect: JsonObject; var Parameters: JsonArray; var HasEffect: Boolean; var HasParameters: Boolean)
    var
        Impl: Codeunit "Sub Bil CrProposal Impl ori";
    begin
        HasEffect := Impl.GetEffect(Effect);
        HasParameters := Impl.GetParameters(Parameters);
    end;

    local procedure RestrictToFullSet() StartedPermissionsMock: Boolean
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        // SetExactPermissionSet is a no-op unless the mock is running.
        StartedPermissionsMock := not PermissionsMock.IsStarted();
        if StartedPermissionsMock then
            PermissionsMock.Start();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
    end;

    local procedure RestoreTestPermissions(StartedPermissionsMock: Boolean)
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        // Assertions must not add test-library permissions to the product role.
        if StartedPermissionsMock then
            PermissionsMock.Stop()
        else
            LowerPermissions.SetOutsideO365Scope();
    end;
}
