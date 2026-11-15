namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// The count that <c>expectedCount</c> confirms for <c>Subscription.PriceUpdate.Perform</c> (#91): the number of
/// Contract Price Update Lines the call would perform now. Foundation's default counter would count one named
/// template, and nothing at all when no template is named, although the call then performs every line.
/// </summary>
codeunit 10035087 "Sub PU Perform Confirm ori" implements "Msg Confirm ori"
{
    /// <summary>Counts the proposal lines the call would perform, without changing data.</summary>
    /// <param name="Argument">The caller's request.</param>
    /// <param name="Count">Receives the number of Contract Price Update Lines in scope.</param>
    /// <param name="Summary">Receives a localized description of the counted lines.</param>
    /// <returns>True; an invalid or unknown template counts as no lines and is refused by the type itself.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        DefaultConfirm: Codeunit "Default Confirm ori";
        RequestJson: JsonObject;
        Token: JsonToken;
        TemplateCode: Text;
        AllTemplatesTxt: Label 'Contract Price Update Lines of every Price Update Template', Comment = 'is-IS=línur verðuppfærslu áskriftarsamnings í öllum sniðmátum fyrir verðuppfærslu';
        OneTemplateTxt: Label 'Contract Price Update Lines of Price Update Template %1', Comment = '%1 = price update template code||is-IS=línur verðuppfærslu áskriftarsamnings í sniðmáti fyrir verðuppfærslu %1';
    begin
        TemplateCode := Argument.Subject;
        if TemplateCode = '' then
            if TryReadRequest(Argument, RequestJson) then
                if RequestJson.Get('priceUpdateTemplateCode', Token) then
                    if Token.IsValue() then
                        if not Token.AsValue().IsNull() then
                            TemplateCode := Token.AsValue().AsText();

        // No update lock: a lock opens a write transaction, and the committing path runs each line through Codeunit.Run,
        // which Business Central refuses inside one. Each line commits on its own, so a lock could not hold the selection anyway.
        if TemplateCode <> '' then begin
            if StrLen(TemplateCode) > MaxStrLen(ContractPriceUpdateLine."Price Update Template Code") then
                TemplateCode := '';
            ContractPriceUpdateLine.SetRange("Price Update Template Code", CopyStr(TemplateCode, 1, MaxStrLen(ContractPriceUpdateLine."Price Update Template Code")));
        end;
        Count := ContractPriceUpdateLine.Count();

        if (Count = 0) or (TemplateCode = '') then
            Summary := AllTemplatesTxt
        else
            Summary := StrSubstNo(OneTemplateTxt, TemplateCode);
        // With nothing to perform the gate hands over to the type's own refusal, which names the cause.
        if Count = 0 then
            Summary := DefaultConfirm.NoSubjectText();
        exit(true);
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
