namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Contract tests over every Subscription Billing message type. They assert the registration
/// itself: that each type resolves to an implementation, describes itself, and answers
/// Help.Implementation.Get with contract chapters. These are the guarantees the Bifrost
/// discovery surface depends on, and they hold without any Subscription Billing master data
/// in the company.
/// </summary>
codeunit 95701 "Sub Msg Type Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FirstTypeOrdinal: Integer;
        LastTypeOrdinal: Integer;

    trigger OnRun()
    begin
        FirstTypeOrdinal := 10035036;
        LastTypeOrdinal := 10035057;
    end;

    [Test]
    procedure AllTypes_AreRegistered_WithAnImplementation()
    var
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        FoundCount: Integer;
    begin
        // [GIVEN] The Subscription Billing object range
        Initialize();

        // [WHEN] Every ordinal in the range is resolved to an enum value
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Assert.AreNotEqual('', Format(MessageType), 'Every registered type must have a name.');
                FoundCount += 1;
            end;

        // [THEN] All 22 message types are registered
        Assert.AreEqual(22, FoundCount, 'All Subscription Billing message types should be registered on the Bifrost enum.');
    end;

    [Test]
    procedure AllTypes_AreEnabled()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);

                // [WHEN] The implementation is asked whether it is enabled
                MessageTypeInterface := MessageType;

                // [THEN] It is
                Assert.IsTrue(MessageTypeInterface.IsEnabled(), StrSubstNo('%1 should be enabled.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_HaveADescription()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        DescriptionText: Text;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;

                // [WHEN] The description is read
                DescriptionText := MessageTypeInterface.GetDescription();

                // [THEN] It is a real sentence, which is what discovery ranks on
                Assert.AreNotEqual('', DescriptionText, StrSubstNo('%1 must describe itself.', Format(MessageType)));
                Assert.IsTrue(StrLen(DescriptionText) > 20, StrSubstNo('%1 needs a description a caller can act on.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_AreInbound()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;

                // [WHEN] The direction is read
                // [THEN] Every Subscription Billing type is driven from outside Business Central
                Assert.AreEqual(
                    MessageTypeInterface.GetMessageDirection(),
                    Enum::"Msg Direction ori"::Inbound,
                    StrSubstNo('%1 should be an inbound message type.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_HaveDistinctDiscoveryText()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        DiscoveryInterface: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        DescriptionText: Text;
        KeywordsText: Text;
        SelectionText: Text;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;
                DiscoveryInterface := MessageType;
                DescriptionText := MessageTypeInterface.GetDescription();
                KeywordsText := DiscoveryInterface.GetKeywords();
                SelectionText := DiscoveryInterface.GetSelectionDescription();

                // [THEN] Discovery provides dedicated text rather than reusing the description
                Assert.AreNotEqual(DescriptionText, KeywordsText, StrSubstNo('%1 must have dedicated keywords.', Format(MessageType)));
                Assert.AreNotEqual(DescriptionText, SelectionText, StrSubstNo('%1 must have a dedicated selection description.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_HaveAnOverviewAndNotes()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Ordinal: Integer;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);

                // [WHEN] The contract is read, which is what Help.Implementation.Get returns
                ContractMgt.GetContract(MessageType, Contract);

                // [THEN] It explains the type in text, which is where the old help's prose now lives
                Assert.AreNotEqual('', ReadChapterText(Contract, 'overview'), StrSubstNo('%1 must have an overview chapter.', Format(MessageType)));
                Assert.AreNotEqual('', ReadChapterText(Contract, 'notes'), StrSubstNo('%1 must have a notes chapter.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_ContractDocumentsTheRequestAndResponse()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Ordinal: Integer;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);

                // [WHEN] The contract is read
                ContractMgt.GetContract(MessageType, Contract);

                // [THEN] It carries the chapters a caller needs to build a request and read the answer
                Assert.IsTrue(Contract.Contains('envelope'), StrSubstNo('%1 needs an envelope chapter.', Format(MessageType)));
                Assert.IsTrue(Contract.Contains('parameters'), StrSubstNo('%1 needs a parameters chapter.', Format(MessageType)));
                Assert.IsTrue(Contract.Contains('response'), StrSubstNo('%1 needs a response chapter.', Format(MessageType)));
                Assert.IsTrue(Contract.Contains('errors'), StrSubstNo('%1 needs an errors chapter.', Format(MessageType)));
                Assert.IsTrue(Contract.Contains('effect'), StrSubstNo('%1 needs an effect chapter.', Format(MessageType)));
            end;
    end;

    local procedure Initialize()
    begin
        FirstTypeOrdinal := 10035036;
        LastTypeOrdinal := 10035057;
    end;

    local procedure IsSubscriptionBillingType(Ordinal: Integer): Boolean
    begin
        exit((Ordinal >= FirstTypeOrdinal) and (Ordinal <= LastTypeOrdinal));
    end;

    local procedure ReadChapterText(Contract: JsonObject; ChapterKey: Text): Text
    var
        Token: JsonToken;
    begin
        if not Contract.Get(ChapterKey, Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
