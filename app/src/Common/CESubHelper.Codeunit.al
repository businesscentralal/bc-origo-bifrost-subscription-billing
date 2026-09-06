namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Shared request parsing and response building for the Subscription Billing message types.
/// Values are read from the request JSON with culture invariant formatting (format 9) so a
/// caller in any locale supplies the same ISO shapes for dates and decimals.
/// </summary>
codeunit 10035058 "CE Sub Helper ori"
{
    Access = Internal;

    var
        MissingParameterErr: Label 'The request is missing the required parameter ''%1''.', Comment = '%1 = parameter name||is-IS=Beiðnina vantar nauðsynlega færibreytu ''%1''.';
        InvalidDateErr: Label 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' er ekki gild dagsetning. Notaðu ISO sniðið YYYY-MM-DD.';
        InvalidDecimalErr: Label 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' er ekki gild tala. Notaðu punkt sem tugabrot, til dæmis 1234.56.';
        InvalidPartnerErr: Label 'The parameter ''%1'' must be either ''Customer'' or ''Vendor''.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' verður að vera annaðhvort ''Customer'' eða ''Vendor''.';
        ValueTooLongErr: Label 'The parameter ''%1'' is longer than the %2 characters allowed.', Comment = '%1 = parameter name, %2 = maximum length||is-IS=Færibreytan ''%1'' er lengri en %2 stafirnir sem leyfðir eru.';
        NotAnArrayErr: Label 'The parameter ''%1'' must be a JSON array.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' verður að vera JSON fylki.';

    /// <summary>Returns true when the request carries a non-null value for the property.</summary>
    procedure HasValue(RequestJson: JsonObject; PropertyName: Text): Boolean
    var
        JToken: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, JToken) then
            exit(false);
        if not JToken.IsValue() then
            exit(false);
        exit(not JToken.AsValue().IsNull());
    end;

    /// <summary>
    /// Reads a JSON array from the request. Returns false when the property is absent or null,
    /// which lets the caller fall back to its own default. Errors when the property is present
    /// with a value that is not an array, so a malformed request is reported rather than
    /// silently treated as "not supplied".
    /// </summary>
    procedure TryGetArray(RequestJson: JsonObject; PropertyName: Text; var Value: JsonArray): Boolean
    var
        JToken: JsonToken;
    begin
        Clear(Value);
        if not RequestJson.Get(PropertyName, JToken) then
            exit(false);
        if JToken.IsValue() then
            if JToken.AsValue().IsNull() then
                exit(false);
        if not JToken.IsArray() then
            Error(NotAnArrayErr, PropertyName);
        Value := JToken.AsArray();
        exit(true);
    end;

    /// <summary>Reads a text value. Errors when Required and the value is absent.</summary>
    procedure GetText(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Text
    var
        JToken: JsonToken;
    begin
        if not HasValue(RequestJson, PropertyName) then begin
            if Required then
                Error(MissingParameterErr, PropertyName);
            exit('');
        end;
        RequestJson.Get(PropertyName, JToken);
        Value := JToken.AsValue().AsText();
    end;

    /// <summary>Reads a Code[20] value and verifies it fits the field length.</summary>
    procedure GetCode20(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Code[20]
    var
        TextValue: Text;
    begin
        TextValue := GetText(RequestJson, PropertyName, Required);
        if StrLen(TextValue) > MaxStrLen(Value) then
            Error(ValueTooLongErr, PropertyName, MaxStrLen(Value));
        Value := CopyStr(TextValue, 1, MaxStrLen(Value));
    end;

    /// <summary>Reads a date value written in the ISO format YYYY-MM-DD.</summary>
    procedure GetDate(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Date
    var
        TextValue: Text;
    begin
        TextValue := GetText(RequestJson, PropertyName, Required);
        if TextValue = '' then
            exit(0D);
        if not Evaluate(Value, TextValue, 9) then
            Error(InvalidDateErr, PropertyName);
    end;

    /// <summary>Reads a date value, falling back to the given default when absent.</summary>
    procedure GetDateOrDefault(RequestJson: JsonObject; PropertyName: Text; DefaultValue: Date) Value: Date
    begin
        Value := GetDate(RequestJson, PropertyName, false);
        if Value = 0D then
            Value := DefaultValue;
    end;

    /// <summary>Reads a decimal value written with a decimal point.</summary>
    procedure GetDecimal(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Decimal
    var
        JToken: JsonToken;
        TextValue: Text;
    begin
        if not HasValue(RequestJson, PropertyName) then begin
            if Required then
                Error(MissingParameterErr, PropertyName);
            exit(0);
        end;
        RequestJson.Get(PropertyName, JToken);
        TextValue := JToken.AsValue().AsText();
        if not Evaluate(Value, TextValue, 9) then
            Error(InvalidDecimalErr, PropertyName);
    end;

    /// <summary>Reads an integer value.</summary>
    procedure GetInteger(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Integer
    var
        JToken: JsonToken;
        TextValue: Text;
    begin
        if not HasValue(RequestJson, PropertyName) then begin
            if Required then
                Error(MissingParameterErr, PropertyName);
            exit(0);
        end;
        RequestJson.Get(PropertyName, JToken);
        TextValue := JToken.AsValue().AsText();
        if not Evaluate(Value, TextValue, 9) then
            Error(InvalidDecimalErr, PropertyName);
    end;

    /// <summary>Reads a boolean value, falling back to the given default when absent.</summary>
    procedure GetBoolean(RequestJson: JsonObject; PropertyName: Text; DefaultValue: Boolean) Value: Boolean
    var
        JToken: JsonToken;
        TextValue: Text;
        TrueTok: Label 'TRUE', Locked = true;
        OneTok: Label '1', Locked = true;
        FalseTok: Label 'FALSE', Locked = true;
        ZeroTok: Label '0', Locked = true;
    begin
        if not HasValue(RequestJson, PropertyName) then
            exit(DefaultValue);
        RequestJson.Get(PropertyName, JToken);
        TextValue := UpperCase(JToken.AsValue().AsText());
        case TextValue of
            TrueTok, OneTok:
                exit(true);
            FalseTok, ZeroTok:
                exit(false);
            else
                exit(DefaultValue);
        end;
    end;

    /// <summary>
    /// Reads the service partner. Accepts 'Customer' or 'Vendor' in any casing and
    /// falls back to the given default when the property is absent.
    /// </summary>
    procedure GetServicePartner(RequestJson: JsonObject; PropertyName: Text; DefaultPartner: Enum "Service Partner") Partner: Enum "Service Partner"
    var
        TextValue: Text;
        CustomerTok: Label 'CUSTOMER', Locked = true;
        VendorTok: Label 'VENDOR', Locked = true;
    begin
        TextValue := GetText(RequestJson, PropertyName, false);
        if TextValue = '' then
            exit(DefaultPartner);
        case UpperCase(TextValue) of
            CustomerTok:
                exit(Enum::"Service Partner"::Customer);
            VendorTok:
                exit(Enum::"Service Partner"::Vendor);
            else
                Error(InvalidPartnerErr, PropertyName);
        end;
    end;

    /// <summary>Returns the subject when set, otherwise the named request property.</summary>
    procedure GetSubjectOr(var Argument: Record "CE Message Argument ori"; RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Code[20]
    begin
        if Argument.Subject <> '' then begin
            if StrLen(Argument.Subject) > MaxStrLen(Value) then
                Error(ValueTooLongErr, PropertyName, MaxStrLen(Value));
            exit(CopyStr(Argument.Subject, 1, MaxStrLen(Value)));
        end;
        exit(GetCode20(RequestJson, PropertyName, Required));
    end;

    /// <summary>Writes a success response and stamps the JSON content type.</summary>
    procedure RespondWithSuccess(var Argument: Record "CE Message Argument ori"; var ResponseJson: JsonObject)
    var
        SuccessTok: Label 'Success', Locked = true;
    begin
        if not ResponseJson.Contains('status') then
            ResponseJson.Add('status', SuccessTok);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>
    /// Names a recurring billing document type for a JSON response. Format() on the enum would
    /// return the caption in the caller's language, and Format(..., 0, 9) returns the bare
    /// ordinal, so neither gives a stable token an integration can switch on. These are the
    /// Microsoft enum value names, written out as locked labels.
    /// </summary>
    procedure FormatDocumentType(Value: Enum "Rec. Billing Document Type"): Text
    var
        NoneTok: Label 'None', Locked = true;
        InvoiceTok: Label 'Invoice', Locked = true;
        CreditMemoTok: Label 'Credit Memo', Locked = true;
    begin
        case Value of
            Value::None:
                exit(NoneTok);
            Value::Invoice:
                exit(InvoiceTok);
            Value::"Credit Memo":
                exit(CreditMemoTok);
        end;
        exit(Format(Value, 0, 9));
    end;

    /// <summary>
    /// Names a usage data processing status for a JSON response, for the same reason
    /// FormatDocumentType exists: neither Format() nor Format(..., 0, 9) yields a stable token.
    /// </summary>
    procedure FormatProcessingStatus(Value: Enum "Processing Status"): Text
    var
        NoneTok: Label 'None', Locked = true;
        OkTok: Label 'Ok', Locked = true;
        ErrorTok: Label 'Error', Locked = true;
        ClosedTok: Label 'Closed', Locked = true;
    begin
        case Value of
            Value::None:
                exit(NoneTok);
            Value::Ok:
                exit(OkTok);
            Value::Error:
                exit(ErrorTok);
            Value::Closed:
                exit(ClosedTok);
        end;
        exit(Format(Value, 0, 9));
    end;

    /// <summary>Formats a date for a JSON response using the ISO format.</summary>
    procedure FormatDate(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    /// <summary>Formats a decimal for a JSON response using culture invariant formatting.</summary>
    procedure FormatDecimal(Value: Decimal): Text
    begin
        exit(Format(Value, 0, 9));
    end;
}
