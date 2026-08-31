namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.SetTemplateFilter</c> Cloud Event message type.
/// Writes one of the three view filters (contract, subscription, line) stored as Blobs on a
/// Price Update Template. Microsoft's own <c>WriteFilter</c>/<c>ReadFilter</c>/<c>EditFilter</c>
/// table methods on "Price Update Template" are internal, so a plain Data.Records.Set cannot
/// reach them - the Blob fields themselves are public, so this codeunit replicates exactly
/// what WriteFilter does: normalise the supplied view through a RecordRef on the matching
/// table, then write the normalised text (or nothing, when it equals the table's blank view)
/// into the field's Blob stream.
/// </summary>
codeunit 10035048 "CE Sub PU SetFilter Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        TemplateNotFoundErr: Label 'The Price Update Template ''%1'' does not exist.', Comment = '%1 = price update template code||is-IS=Verðuppfærslusniðmátið ''%1'' er ekki til.';
        InvalidTargetErr: Label 'The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''.', Comment = '%1 = the supplied target value||is-IS=Færibreytan ''target'' verður að vera ein af ''contract'', ''subscription'' eða ''line'', ekki ''%1''.';
        ContractTok: Label 'contract', Locked = true;
        SubscriptionTok: Label 'subscription', Locked = true;
        LineTok: Label 'line', Locked = true;
        DescriptionLbl: Label 'Writes the contract, subscription or line view filter Blob on a Price Update Template and returns the current value of all three filters.', MaxLength = 250, Comment = 'is-IS=Skrifar síu (Blob) fyrir samnings-, áskriftar- eða línusýn á verðuppfærslusniðmát og skilar núgildandi gildi allra þriggja sía.';

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
        HelpBuilder.AppendLine('# Subscription.PriceUpdate.SetTemplateFilter');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Writes one of the three view filters stored on a Price Update Template (table 8003):');
        HelpBuilder.AppendLine('the Subscription Contract filter, the Subscription filter, or the Subscription Line filter.');
        HelpBuilder.AppendLine('Each is kept as a Blob holding a standard Business Central view string. The supplied');
        HelpBuilder.AppendLine('filter is normalised through a RecordRef on the matching table before it is stored, so it');
        HelpBuilder.AppendLine('is saved in the platform''s own canonical syntax - the same text the "Contract Price');
        HelpBuilder.AppendLine('Update" page would store from the filter editor. For the contract filter, the target table');
        HelpBuilder.AppendLine('depends on the template''s own Partner field: Customer Subscription Contract when the');
        HelpBuilder.AppendLine('template''s Partner is Customer, otherwise Vendor Subscription Contract.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| priceUpdateTemplateCode | Code[20] | Yes | The Price Update Template to update. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| filter | Text | Yes | A view string, for example `WHERE(Subscription Contract No.=FILTER(CC000010))`, or a full `SORTING(...) WHERE(...)` view. |');
        HelpBuilder.AppendLine('| target | Text | Yes | One of `contract`, `subscription` or `line`, case-insensitive. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "priceUpdateTemplateCode": "ANNUAL",');
        HelpBuilder.AppendLine('  "target": "contract",');
        HelpBuilder.AppendLine('  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "priceUpdateTemplateCode": "ANNUAL",');
        HelpBuilder.AppendLine('  "target": "contract",');
        HelpBuilder.AppendLine('  "filter": "WHERE(Subscription Contract No.=FILTER(CC000010))",');
        HelpBuilder.AppendLine('  "filters": {');
        HelpBuilder.AppendLine('    "contract": "WHERE(Subscription Contract No.=FILTER(CC000010))",');
        HelpBuilder.AppendLine('    "subscription": "",');
        HelpBuilder.AppendLine('    "line": ""');
        HelpBuilder.AppendLine('  }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`filter` echoes back the normalised view that was written for `target`. `filters` always');
        HelpBuilder.AppendLine('reports the current value of all three filters after the write, so a caller can confirm');
        HelpBuilder.AppendLine('the other two were left untouched. An empty string means no filter is set.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The template does not exist | The Price Update Template ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| target is not contract, subscription or line | The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''. |');
        HelpBuilder.AppendLine('| filter is not a valid view for the target table | Raised by the platform''s own filter parser and reported as-is. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes only the named filter Blob on the template record itself - it');
        HelpBuilder.AppendLine('never touches contracts, subscriptions or lines. The write runs in an isolated transaction');
        HelpBuilder.AppendLine('that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.CreateProposal`');
        HelpBuilder.AppendLine('- `Subscription.PriceUpdate.Perform`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    var
        WriteProcess: Codeunit "CE Sub Write Process ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        Clear(WriteProcess);
        if not WriteProcess.Run(Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Writes the requested filter Blob and reports back all three current filter values.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        PriceUpdateTemplate: Record "Price Update Template";
        RRef: RecordRef;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FiltersJson: JsonObject;
        OutStr: OutStream;
        InStr: InStream;
        PriceUpdateTemplateCode: Code[20];
        SuppliedFilter: Text;
        TargetName: Text;
        FilterText: Text;
        BlankView: Text;
        TargetTableNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        PriceUpdateTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'priceUpdateTemplateCode', true);
        SuppliedFilter := Helper.GetText(RequestJson, 'filter', true);
        TargetName := LowerCase(Helper.GetText(RequestJson, 'target', true));

        if not PriceUpdateTemplate.Get(PriceUpdateTemplateCode) then
            Error(TemplateNotFoundErr, PriceUpdateTemplateCode);

        case TargetName of
            ContractTok:
                if PriceUpdateTemplate.Partner = PriceUpdateTemplate.Partner::Customer then
                    TargetTableNo := Database::"Customer Subscription Contract"
                else
                    TargetTableNo := Database::"Vendor Subscription Contract";
            SubscriptionTok:
                TargetTableNo := Database::"Subscription Header";
            LineTok:
                TargetTableNo := Database::"Subscription Line";
            else
                Error(InvalidTargetErr, TargetName);
        end;

        RRef.Open(TargetTableNo);
        BlankView := RRef.GetView(false);
        RRef.SetView(SuppliedFilter);
        FilterText := RRef.GetView(false);
        Clear(RRef);

        case TargetName of
            ContractTok:
                begin
                    Clear(PriceUpdateTemplate."Subscription Contract Filter");
                    PriceUpdateTemplate."Subscription Contract Filter".CreateOutStream(OutStr, TextEncoding::UTF8);
                    if FilterText <> BlankView then
                        OutStr.WriteText(FilterText);
                end;
            SubscriptionTok:
                begin
                    Clear(PriceUpdateTemplate."Subscription Filter");
                    PriceUpdateTemplate."Subscription Filter".CreateOutStream(OutStr, TextEncoding::UTF8);
                    if FilterText <> BlankView then
                        OutStr.WriteText(FilterText);
                end;
            LineTok:
                begin
                    Clear(PriceUpdateTemplate."Subscription Line Filter");
                    PriceUpdateTemplate."Subscription Line Filter".CreateOutStream(OutStr, TextEncoding::UTF8);
                    if FilterText <> BlankView then
                        OutStr.WriteText(FilterText);
                end;
        end;
        PriceUpdateTemplate.Modify(true);

        PriceUpdateTemplate.CalcFields("Subscription Contract Filter", "Subscription Filter", "Subscription Line Filter");
        PriceUpdateTemplate."Subscription Contract Filter".CreateInStream(InStr, TextEncoding::UTF8);
        FiltersJson.Add('contract', ReadStreamAsText(InStr));
        PriceUpdateTemplate."Subscription Filter".CreateInStream(InStr, TextEncoding::UTF8);
        FiltersJson.Add('subscription', ReadStreamAsText(InStr));
        PriceUpdateTemplate."Subscription Line Filter".CreateInStream(InStr, TextEncoding::UTF8);
        FiltersJson.Add('line', ReadStreamAsText(InStr));

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        ResponseJson.Add('target', TargetName);
        ResponseJson.Add('filter', FilterText);
        ResponseJson.Add('filters', FiltersJson);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>Reads the remaining text of an InStream, or an empty string when it holds nothing.</summary>
    local procedure ReadStreamAsText(var InStr: InStream) Value: Text
    begin
        InStr.ReadText(Value);
    end;
}
