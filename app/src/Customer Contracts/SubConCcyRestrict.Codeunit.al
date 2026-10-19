namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Closes Currency Code on customer and vendor subscription contracts to Foundation's generic
/// Data.Records writes (#51). Microsoft's OnValidate asks for the exchange rate on a page; without a
/// client it recalculates every contract line with a currency factor of zero. Only the generic
/// write path is closed: the contract card, Microsoft's own contract creation and this app's
/// message types still validate Currency Code as before.
/// </summary>
codeunit 10035082 "Sub Con Ccy Restrict ori"
{
    Access = Internal;

    var
        CurrencyCodeHintTxt: Label 'Change Currency Code on the subscription contract card, which asks for the exchange rate. Subscription.Contract.UpdateExchangeRates recalculates the lines of a contract in the currency it already has.', Comment = 'is-IS=Breyttu gjaldmiðilskóðanum á spjaldi áskriftarsamningsins, sem biður um gengið. Subscription.Contract.UpdateExchangeRates endurreiknar línur samnings í þeim gjaldmiðli sem hann hefur þegar.';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictContractCurrencyCode(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        // Force does not reopen the field: a forced write still recalculates with a zero factor.
        if IsContractCurrencyCode(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure HintContractCurrencyCode(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if IsContractCurrencyCode(TableNo, FieldNo) then
            Hint := CurrencyCodeHintTxt;
    end;

    local procedure IsContractCurrencyCode(TableNo: Integer; FieldNo: Integer): Boolean
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
    begin
        case TableNo of
            Database::"Customer Subscription Contract":
                exit(FieldNo = CustomerContract.FieldNo("Currency Code"));
            Database::"Vendor Subscription Contract":
                exit(FieldNo = VendorContract.FieldNo("Currency Code"));
        end;
        exit(false);
    end;
}
