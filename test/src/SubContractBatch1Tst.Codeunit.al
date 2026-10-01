namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;

/// <summary>Verifies the contract chapters and effects for the first Subscription Billing batch.</summary>
codeunit 95706 "Sub Contract Batch1 Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure Batch1_AllTypes_HaveRequiredChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
    begin
        foreach TypeName in Batch1Types() do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            Assert.IsTrue(Contract.Contains('envelope'), TypeName + ' must declare envelope.');
            Assert.IsTrue(Contract.Contains('parameters'), TypeName + ' must declare parameters.');
            Assert.IsTrue(Contract.Contains('response'), TypeName + ' must declare response.');
            Assert.IsTrue(Contract.Contains('errors'), TypeName + ' must declare errors.');
            Assert.IsTrue(Contract.Contains('effect'), TypeName + ' must declare effect.');
            Assert.IsTrue(Contract.Contains('metering'), TypeName + ' must declare metering.');
            Assert.IsTrue(Contract.Contains('related'), TypeName + ' must declare related.');
        end;
    end;

    [Test]
    procedure Batch1_Effects_MatchOperation()
    begin
        AssertEffect('Subscription.Line.Create', 'write');
        AssertEffect('Subscription.Contract.GetLines', 'write');
        AssertEffect('Subscription.Contract.CreateInvoice', 'irreversible');
        AssertEffect('Subscription.Contract.PreviewInvoice', 'read');
        AssertEffect('Subscription.Contract.UpdateLineDates', 'irreversible');
        AssertEffect('Subscription.Contract.UpdateExchangeRates', 'irreversible');
        AssertEffect('Subscription.VendorContract.GetLines', 'write');
        AssertEffect('Subscription.VendorContract.CreateInvoice', 'irreversible');
        AssertEffect('Subscription.VendorContract.PreviewInvoice', 'read');
        AssertEffect('Subscription.Billing.CreateProposal', 'irreversible');
        AssertEffect('Subscription.Billing.CreateDocuments', 'irreversible');
        AssertEffect('Subscription.Billing.PreviewDocuments', 'read');
        AssertEffect('Subscription.PriceUpdate.SetTemplateFilter', 'write');
        AssertEffect('Subscription.PriceUpdate.CreateProposal', 'write');
        AssertEffect('Subscription.PriceUpdate.Perform', 'irreversible');
    end;

    [Test]
    procedure CommittingTypes_AreIrreversible_WriteTypesStayWrite()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO #22] Microsoft's billing proposal commits every CommitBatchSize contracts, so the type is irreversible
        AssertEffect('Subscription.Billing.CreateProposal', 'irreversible');
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", Contract);
        Contract.Get('effect', Token);
        Effect := Token.AsObject();
        Effect.Get('changes', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('CommitBatchSize'), 'The changes text must name the CommitBatchSize commit.');

        // [THEN] The six types that only write inside the caller's transaction stay write, and the previews stay read
        AssertEffect('Subscription.Line.Create', 'write');
        AssertEffect('Subscription.Contract.GetLines', 'write');
        AssertEffect('Subscription.VendorContract.GetLines', 'write');
        AssertEffect('Subscription.PriceUpdate.SetTemplateFilter', 'write');
        AssertEffect('Subscription.PriceUpdate.CreateProposal', 'write');
        AssertEffect('Subscription.Analysis.Recalculate', 'write');
        AssertEffect('Subscription.Contract.PreviewInvoice', 'read');
        AssertEffect('Subscription.VendorContract.PreviewInvoice', 'read');
        AssertEffect('Subscription.Billing.PreviewDocuments', 'read');
    end;

    local procedure AssertEffect(TypeName: Text; Expected: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
    begin
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', Token);
        Effect := Token.AsObject();
        Effect.Get('effect', Token);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure Batch1Types() Types: List of [Text]
    begin
        Types.Add('Subscription.Line.Create');
        Types.Add('Subscription.Contract.GetLines');
        Types.Add('Subscription.Contract.CreateInvoice');
        Types.Add('Subscription.Contract.PreviewInvoice');
        Types.Add('Subscription.Contract.UpdateLineDates');
        Types.Add('Subscription.Contract.UpdateExchangeRates');
        Types.Add('Subscription.VendorContract.GetLines');
        Types.Add('Subscription.VendorContract.CreateInvoice');
        Types.Add('Subscription.VendorContract.PreviewInvoice');
        Types.Add('Subscription.Billing.CreateProposal');
        Types.Add('Subscription.Billing.CreateDocuments');
        Types.Add('Subscription.Billing.PreviewDocuments');
        Types.Add('Subscription.PriceUpdate.SetTemplateFilter');
        Types.Add('Subscription.PriceUpdate.CreateProposal');
        Types.Add('Subscription.PriceUpdate.Perform');
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
