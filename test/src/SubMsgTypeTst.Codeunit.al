namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Contract tests over every Subscription Billing message type. They assert the registration
/// itself: that each type resolves to an implementation, describes itself, and returns a usable
/// help document. These are the guarantees the Bifrost discovery surface depends on, and
/// they hold without any Subscription Billing master data in the company.
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
    procedure AllTypes_ReturnAHelpDocument()
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        HelpText: Text;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;

                TempArgument.Reset();
                TempArgument.DeleteAll();
                TempArgument.Init();
                TempArgument."Type" := MessageType;
                // GetResponseText calls CalcFields, which reads the BLOB back from the (temporary)
                // table - the record has to exist there or the response comes back empty.
                TempArgument.Insert();

                // [WHEN] The help document is requested, which is what Help.Implementation.Get calls
                MessageTypeInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
                HelpText := TempArgument.GetResponseText();

                // [THEN] A markdown document comes back, titled after the message type
                Assert.AreNotEqual('', HelpText, StrSubstNo('%1 must return a help document.', Format(MessageType)));
                Assert.AreEqual(
                    TempArgument.GetContentTypeMarkdown(),
                    TempArgument."Content Type",
                    StrSubstNo('%1 help must be served as markdown.', Format(MessageType)));
                Assert.IsTrue(
                    StrPos(HelpText, '# ' + Format(MessageType)) > 0,
                    StrSubstNo('The help document for %1 should be titled with the message type name.', Format(MessageType)));
            end;
    end;

    [Test]
    procedure AllTypes_HelpDocumentsTheRequestAndResponse()
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        HelpText: Text;
    begin
        // [GIVEN] The registered Subscription Billing message types
        Initialize();

        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if IsSubscriptionBillingType(Ordinal) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;

                TempArgument.Reset();
                TempArgument.DeleteAll();
                TempArgument.Init();
                TempArgument."Type" := MessageType;
                // GetResponseText calls CalcFields, which reads the BLOB back from the (temporary)
                // table - the record has to exist there or the response comes back empty.
                TempArgument.Insert();

                // [WHEN] The help document is read
                MessageTypeInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
                HelpText := TempArgument.GetResponseText();

                // [THEN] It carries the sections a caller needs to build a request and read the answer
                Assert.IsTrue(StrPos(HelpText, '## Overview') > 0, StrSubstNo('%1 help needs an Overview section.', Format(MessageType)));
                Assert.IsTrue(StrPos(HelpText, '## Request Parameters') > 0, StrSubstNo('%1 help needs a Request Parameters section.', Format(MessageType)));
                Assert.IsTrue(StrPos(HelpText, '## Response Shape') > 0, StrSubstNo('%1 help needs a Response Shape section.', Format(MessageType)));
                Assert.IsTrue(StrPos(HelpText, '## Errors') > 0, StrSubstNo('%1 help needs an Errors section.', Format(MessageType)));
                Assert.IsTrue(StrPos(HelpText, '## Safety') > 0, StrSubstNo('%1 help needs a Safety section.', Format(MessageType)));
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
}
