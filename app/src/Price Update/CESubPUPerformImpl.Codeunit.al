namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.Perform</c> Cloud Event message type.
/// There is no supported public path for this operation: <c>Codeunit "Price Update
/// Management".PerformPriceUpdate</c> is internal and its worker codeunit 8013 "Process Price
/// Update" is declared <c>Access = Internal</c>. A plain Data.Records call cannot reach either
/// of them, and this codeunit deliberately does not attempt to re-implement Microsoft's price
/// update application logic - silently diverging from it would corrupt customer contracts. It
/// always responds with a clear, structured error instead.
/// </summary>
codeunit 10035050 "CE Sub PU Perform Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        NotAccessibleErr: Label 'Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to perform the price update.', Comment = 'is-IS=Subscription.PriceUpdate.Perform er ekki hægt að keyra: Codeunit "Price Update Management".PerformPriceUpdate er innvortis (internal) í Business Central 28.4 og hefur ekki verið gert aðgengilegt utanaðkomandi köllum. Notaðu síðuna "Contract Price Update" í Business Central biðlaranum til að framkvæma verðuppfærsluna.';
        DescriptionLbl: Label 'Blocked: Microsoft has not exposed a public API to perform price updates. Use the "Contract Price Update" page instead.', MaxLength = 250, Comment = 'is-IS=Lokað: Microsoft hefur ekki gert opinbert forritsskil aðgengilegt til að framkvæma verðuppfærslur. Notaðu síðuna "Contract Price Update" í staðinn.';

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
        HelpBuilder.AppendLine('# Subscription.PriceUpdate.Perform');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type is blocked.** It always returns an error and writes nothing.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Applying a price update proposal in Business Central 28.4 requires');
        HelpBuilder.AppendLine('`Codeunit "Price Update Management".PerformPriceUpdate`, which Microsoft has marked');
        HelpBuilder.AppendLine('`internal`, and its worker codeunit 8013 "Process Price Update" is declared');
        HelpBuilder.AppendLine('`Access = Internal` at the object level. Neither is reachable from an external app, so');
        HelpBuilder.AppendLine('there is genuinely no supported public path to perform the update from code.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Even a hypothetical public version would need care: Microsoft''s PerformPriceUpdate');
        HelpBuilder.AppendLine('processes every row standing in the price update proposal table across *all* templates,');
        HelpBuilder.AppendLine('with no template or contract filter of its own - the filtering happens earlier, when the');
        HelpBuilder.AppendLine('proposal is created. A caller who expects "perform" to be scoped to one template would be');
        HelpBuilder.AppendLine('surprised by that behaviour, which is one more reason this codeunit does not attempt a');
        HelpBuilder.AppendLine('workaround: doing so would risk applying price changes to contracts the caller never');
        HelpBuilder.AppendLine('intended to touch.');
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
        HelpBuilder.AppendLine('  "error": "Subscription.PriceUpdate.Perform cannot run: ...",');
        HelpBuilder.AppendLine('  "callstack": "..."');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| Always | Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal in Business Central 28.4 and has not been exposed for external callers. Use the "Contract Price Update" page in the Business Central client to perform the price update. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type never writes. It is registered and enabled so that discovery and help');
        HelpBuilder.AppendLine('tooling can list it, but every call fails fast with a specific, actionable error rather');
        HelpBuilder.AppendLine('than attempting an unsupported workaround that could corrupt customer contracts.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.SetTemplateFilter`');
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.CreateProposal`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Argument.RespondWithError(NotAccessibleErr);
    end;
}
