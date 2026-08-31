namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.CreateProposal</c> Cloud Event message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".CreatePriceUpdateProposal</c> is internal, the whole <c>Interface "Contract
/// Price Update"</c> and its implementations are internal, and the worker codeunit 8013
/// "Process Price Update" is declared <c>Access = Internal</c>. A plain Data.Records call
/// cannot reach any of them, and this codeunit deliberately does not attempt to re-implement
/// Microsoft's price update proposal logic - silently diverging from it would mis-price
/// customer contracts. It always responds with a clear, structured error instead.
/// </summary>
codeunit 10035049 "CE Sub PU CrProposal Impl ori" implements "Cloud Event Msg Interface ori"
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

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.PriceUpdate.CreateProposal');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type is blocked.** It always returns an error and writes nothing.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Creating a price update proposal in Business Central 28.4 requires');
        HelpBuilder.AppendLine('`Codeunit "Price Update Management".CreatePriceUpdateProposal`, which Microsoft has marked');
        HelpBuilder.AppendLine('`internal`. The entire `Interface "Contract Price Update"` that carries out the actual');
        HelpBuilder.AppendLine('rate calculation, and every implementation of it, is also internal, and the worker');
        HelpBuilder.AppendLine('codeunit 8013 "Process Price Update" is declared `Access = Internal` at the object level.');
        HelpBuilder.AppendLine('None of this is reachable from an external app, so there is genuinely no supported public');
        HelpBuilder.AppendLine('path to create the proposal from code.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This codeunit does not attempt to re-implement Microsoft''s price update logic. Doing so');
        HelpBuilder.AppendLine('would risk silently diverging from Microsoft''s own rounding, currency and binding-period');
        HelpBuilder.AppendLine('rules and could mis-price live customer contracts - a clear error is safer than a guess.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| (none) | | | This message type takes no parameters. It always fails. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Error",');
        HelpBuilder.AppendLine('  "error": "Subscription.PriceUpdate.CreateProposal cannot run: ...",');
        HelpBuilder.AppendLine('  "callstack": "..."');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| Always | Subscription.PriceUpdate.CreateProposal cannot run: Codeunit "Price Update Management".CreatePriceUpdateProposal is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to create the proposal, or call Subscription.PriceUpdate.SetTemplateFilter first to prepare the template''s filters. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type never writes. It is registered and enabled so that discovery and help');
        HelpBuilder.AppendLine('tooling can list it, but every call fails fast with a specific, actionable error rather');
        HelpBuilder.AppendLine('than attempting an unsupported workaround.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.SetTemplateFilter`');
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.Perform`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotAccessibleErr);
    end;
}
