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
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');

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
        Impl: Codeunit "Sub Bil CrProposal Impl ori";
        Effect: JsonObject;
        Parameters: JsonArray;
    begin
        // Issue #42, AC03 edge case | Time: none | Risk: None
        // [GIVEN] The session holds only BIFROST Full ori
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');

        // [WHEN] The implementation codeunit builds its chapters through Sub Contract Parts ori
        Assert.IsTrue(Impl.GetEffect(Effect), 'GetEffect must answer.');
        Assert.IsTrue(Impl.GetParameters(Parameters), 'GetParameters must answer.');

        // [THEN] The chapters carry content
        Assert.IsTrue(Effect.Contains('effect'), 'The effect chapter must be built.');
        Assert.IsTrue(Parameters.Count() > 0, 'The parameters chapter must be built.');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'The contract must be built.');
        Assert.IsTrue(Contract.Contains('effect'), 'The contract must carry the effect chapter.');
    end;
}
