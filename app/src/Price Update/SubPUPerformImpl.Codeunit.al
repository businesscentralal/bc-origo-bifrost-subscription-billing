namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.Perform</c> Bifrost message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".PerformPriceUpdate</c> is internal and its worker codeunit 8013"Process Price
/// Update" is declared <c>Access = Internal</c>. A plain Data.Records call cannot reach either
/// of them, and this codeunit deliberately does not attempt to re-implement Microsoft's price
/// update application logic - silently diverging from it would corrupt customer contracts. It
/// always responds with a clear, structured error instead.
/// </summary>
codeunit 10035050 "Sub PU Perform Impl ori" implements "Msg Interface ori"
{
    var
        NotAccessibleErr: Label 'Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to perform the price update.', Comment = 'is-IS=Subscription.PriceUpdate.Perform er ekki hægt að keyra: Codeunit "Price Update Management".PerformPriceUpdate er innvortis (internal) í Business Central 28.4 og hefur ekki verið gert aðgengilegt utanaðkomandi köllum. Notaðu síðuna "Contract Price Update" í Business Central biðlaranum til að framkvæma verðuppfærsluna.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to perform price updates. Use the "Contract Price Update" page instead.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að framkvæma verðuppfærslur. Notaðu síðuna "Contract Price Update" í staðinn.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Price Update Template");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        PUHelp: Codeunit "Sub PU Help ori";
    begin
        Argument.SetResponseMarkdown(PUHelp.GetHelpMarkdown('Subscription.PriceUpdate.Perform'));
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotAccessibleErr);
    end;
}
