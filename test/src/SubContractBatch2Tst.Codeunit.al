namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;

/// <summary>Verifies the contract chapters and effects for the second Subscription Billing batch.</summary>
codeunit 95707 "Sub Contract Batch2 Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure Batch2_AllTypes_HaveRequiredChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
    begin
        foreach TypeName in Batch2Types() do begin
            MessageType := Enum::"Message Type ori"::FromInteger(OrdinalOf(TypeName));
            Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            Assert.IsTrue(Contract.Contains('envelope'), TypeName + ' must declare envelope.');
            Assert.IsTrue(Contract.Contains('response'), TypeName + ' must declare response.');
            Assert.IsTrue(Contract.Contains('errors'), TypeName + ' must declare errors.');
            Assert.IsTrue(Contract.Contains('effect'), TypeName + ' must declare effect.');
            Assert.IsTrue(Contract.Contains('metering'), TypeName + ' must declare metering.');
            Assert.IsTrue(Contract.Contains('related'), TypeName + ' must declare related.');
        end;
    end;

    [Test]
    procedure Batch2_Effects_MatchOperation()
    begin
        AssertEffect('Subscription.Renewal.Extend', 'irreversible');
        AssertEffect('Subscription.Renewal.CreateQuote', 'irreversible');
        AssertEffect('Subscription.Usage.ImportData', 'irreversible');
        AssertEffect('Subscription.Usage.Process', 'irreversible');
        AssertEffect('Subscription.Deferral.Release', 'irreversible');
        AssertEffect('Subscription.Analysis.Recalculate', 'read');
        AssertEffect('Subscription.Import.CreateContracts', 'irreversible');
    end;

    local procedure AssertEffect(TypeName: Text; Expected: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
    begin
        MessageType := Enum::"Message Type ori"::FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', Token);
        Effect := Token.AsObject();
        Effect.Get('effect', Token);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure Batch2Types() Types: List of [Text]
    begin
        Types.Add('Subscription.Renewal.Extend');
        Types.Add('Subscription.Renewal.CreateQuote');
        Types.Add('Subscription.Usage.ImportData');
        Types.Add('Subscription.Usage.Process');
        Types.Add('Subscription.Deferral.Release');
        Types.Add('Subscription.Analysis.Recalculate');
        Types.Add('Subscription.Import.CreateContracts');
    end;

    local procedure OrdinalOf(TypeName: Text): Integer
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        exit(Ordinals.Get(Names.IndexOf(TypeName)));
    end;
}
