namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Refuses a generic write to Currency Code on a customer or vendor subscription contract.
/// Microsoft's OnValidate opens an exchange-rate page and, with no UI, recalculates every line
/// with a currency factor of zero. The supported path is Subscription.Contract.UpdateExchangeRates.
/// Foundation's Data.Records.Set events are internal to Foundation, so this app subscribes to the
/// contract tables itself and leaves Foundation generic.
/// </summary>
codeunit 10035082 "Sub Con Ccy Guard ori"
{
    Access = Internal;

    var
        CurrencyWriteErr: Label 'Currency Code on subscription contract %1 cannot be changed by a generic write. Use Subscription.Contract.UpdateExchangeRates.', Comment = '%1 = contract number||is-IS=Ekki er hægt að breyta gjaldmiðilskóða á áskriftarsamningi %1 með almennri skrifun. Notaðu Subscription.Contract.UpdateExchangeRates.';

    [EventSubscriber(ObjectType::Table, Database::"Customer Subscription Contract", OnBeforeValidateEvent, 'Currency Code', false, false)]
    local procedure RefuseCustomerContractCurrencyCode(var Rec: Record "Customer Subscription Contract"; var xRec: Record "Customer Subscription Contract")
    begin
        RefuseCurrencyCodeChange(Rec."No.", Rec."Currency Code", xRec."Currency Code");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Vendor Subscription Contract", OnBeforeValidateEvent, 'Currency Code', false, false)]
    local procedure RefuseVendorContractCurrencyCode(var Rec: Record "Vendor Subscription Contract"; var xRec: Record "Vendor Subscription Contract")
    begin
        RefuseCurrencyCodeChange(Rec."No.", Rec."Currency Code", xRec."Currency Code");
    end;

    local procedure RefuseCurrencyCodeChange(ContractNo: Code[20]; NewCurrencyCode: Code[10]; OldCurrencyCode: Code[10])
    begin
        if NewCurrencyCode = OldCurrencyCode then
            exit;
        Error(CurrencyWriteErr, ContractNo);
    end;
}
