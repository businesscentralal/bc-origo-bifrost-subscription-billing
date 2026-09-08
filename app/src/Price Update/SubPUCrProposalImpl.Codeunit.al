namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.CreateProposal</c> Bifrost message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".CreatePriceUpdateProposal</c> is internal, the whole <c>Interface"Contract
/// Price Update"</c> and its implementations are internal, and the worker codeunit 8013
/// "Process Price Update" is declared <c>Access = Internal</c>. A plain Data.Records call
/// cannot reach any of them, and this codeunit deliberately does not attempt to re-implement
/// Microsoft's price update proposal logic - silently diverging from it would mis-price
/// customer contracts. It always responds with a clear, structured error instead.
/// </summary>
codeunit 10035049 "Sub PU CrProposal Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        NotAccessibleErr: Label 'Subscription.PriceUpdate.CreateProposal cannot run: Codeunit "Price Update Management".CreatePriceUpdateProposal is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to create the proposal, or call Subscription.PriceUpdate.SetTemplateFilter first to prepare the template''s filters.', Comment = 'is-IS=Subscription.PriceUpdate.CreateProposal er ekki hægt að keyra: Codeunit "Price Update Management".CreatePriceUpdateProposal er innvortis (internal) í Business Central 28.4 og hefur ekki verið gert aðgengilegt utanaðkomandi köllum. Notaðu síðuna "Contract Price Update" í Business Central biðlaranum til að útbúa tillöguna, eða kallaðu á Subscription.PriceUpdate.SetTemplateFilter fyrst til að undirbúa síur sniðmátsins.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to create price update proposals. Use the "Contract Price Update" page instead.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að búa til verðuppfærslutillögur. Notaðu síðuna "Contract Price Update" í staðinn.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Price Update Template");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        PUHelp: Codeunit "Sub PU Help ori";
    begin
        Argument.SetResponseMarkdown(PUHelp.GetHelpMarkdown('Subscription.PriceUpdate.CreateProposal'));
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotAccessibleErr);
    end;
}
