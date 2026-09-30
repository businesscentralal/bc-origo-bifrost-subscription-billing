namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.PriceUpdate.SetTemplateFilter</c> Bifrost message type.
/// Writes one of the three view filters (contract, subscription, line) stored as Blobs on a
/// Price Update Template. Microsoft's own <c>WriteFilter</c>/<c>ReadFilter</c>/<c>EditFilter</c>
/// table methods on "Price Update Template" are internal, so a plain Data.Records.Set cannot
/// reach them - the Blob fields themselves are public, so this codeunit replicates exactly
/// what WriteFilter does: normalise the supplied view through a RecordRef on the matching
/// table, then write the normalised text (or nothing, when it equals the table's blank view)
/// into the field's Blob stream.
/// </summary>
codeunit 10035048 "Sub PU SetFilter Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Price Update Template ''%1'' does not exist.', Comment = '%1 = price update template code||is-IS=Verðuppfærslusniðmátið ''%1'' er ekki til.';
        InvalidTargetErr: Label 'The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''.', Comment = '%1 = the supplied target value||is-IS=Færibreytan ''target'' verður að vera ein af ''contract'', ''subscription'' eða ''line'', ekki ''%1''.';
        InvalidFilterErr: Label 'The parameter ''filter'' is not a valid Business Central view for target ''%1''. Supply a view in the form ''SORTING(Field) WHERE(Field=FILTER(Value))''.', Comment = '%1 = the supplied target value||is-IS=Færibreytan ''filter'' er ekki gild Business Central sýn fyrir ''%1''. Sendu sýn á forminu ''SORTING(Reitur) WHERE(Reitur=FILTER(Gildi))''.';
        ContractTok: Label 'contract', Locked = true;
        SubscriptionTok: Label 'subscription', Locked = true;
        LineTok: Label 'line', Locked = true;
        DescriptionLbl: Label 'Writes the contract, subscription or line view filter Blob on a Price Update Template and returns the current value of all three filters.', MaxLength = 250, Comment = 'is-IS=Skrifar síu (Blob) fyrir samnings-, áskriftar- eða línusýn á verðuppfærslusniðmát og skilar núgildandi gildi allra þriggja sía.';

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

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.PriceUpdate.SetTemplateFilter, Subscription, PriceUpdate, SetTemplateFilter, filter, template', Comment = 'is-IS=Subscription.PriceUpdate.SetTemplateFilter, áskrift, verðuppfærsla, setja sniðmátssíu, sía, sniðmát';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.PriceUpdate.SetTemplateFilter: Sets the filter on a price update template.', Comment = 'is-IS=Subscription.PriceUpdate.SetTemplateFilter: Setur síu á sniðmát verðuppfærslu.';
    begin
        exit(SelectionLbl);
    end;
    procedure GetEnvelope(var Envelope: JsonObject): Boolean begin Envelope := ContractParts.GetEnvelope(ContractType()); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin Target := ContractParts.GetTarget(ContractType()); exit(Target.Count() > 0); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin Parameters := ContractParts.GetParameters(ContractType()); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean begin Response := ContractParts.GetResponse(ContractType()); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean begin Errors := ContractParts.GetErrors(ContractType()); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean begin Effect := ContractParts.GetEffect(ContractType()); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean begin Related := ContractParts.GetRelated(ContractType()); exit(Related.Count() > 0); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin Clear(Overview); exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin Clear(Notes); exit(false); end;
    local procedure ContractType(): Text begin exit('Subscription.PriceUpdate.SetTemplateFilter'); end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        PUHelp: Codeunit "Sub PU Help ori";
    begin
        Argument.SetResponseMarkdown(PUHelp.GetHelpMarkdown('Subscription.PriceUpdate.SetTemplateFilter'));
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteProcess: Codeunit "Sub Write Process ori";
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
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        // The view comes straight from the caller. Business Central raises its own parser error on a
        // malformed one, which says nothing about which parameter was wrong and can name internals of
        // the table being opened. Catch it and answer with the contract this message type documents.
        if not TrySetView(RRef, SuppliedFilter) then
            Error(InvalidFilterErr, TargetName);
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

    /// <summary>Applies a caller-supplied view to the RecordRef, reporting failure instead of raising Business Central's own parser error.</summary>
    [TryFunction]
    local procedure TrySetView(var RRef: RecordRef; View: Text)
    begin
        RRef.SetView(View);
    end;

    /// <summary>Reads the remaining text of an InStream, or an empty string when it holds nothing.</summary>
    local procedure ReadStreamAsText(var InStr: InStream) Value: Text
    begin
        InStr.ReadText(Value);
    end;
}
