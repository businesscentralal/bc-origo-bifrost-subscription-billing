namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.Security.User;
using System.Text;
using System.Utilities;

/// <summary>
/// Shared request parsing and response building for the Subscription Billing message types.
/// Values are read from the request JSON with culture invariant formatting (format 9) so a
/// caller in any locale supplies the same ISO shapes for dates and decimals.
/// </summary>
codeunit 10035058 "Sub Helper ori"
{
    Access = Internal;

    var
        CorrectParameterTxt: Label 'Correct %1 and resend the request.', Comment = '%1 = parameter||is-IS=Leiðréttu %1 og sendu beiðnina aftur.';
        ExpectedValueTxt: Label 'A valid value for %1.', Comment = '%1 = parameter||is-IS=Gilt gildi fyrir %1.';
        InvalidValueErr: Label 'The parameter %1 has an invalid value. Expected %2.', Comment = '%1 = parameter, %2 = expected format||is-IS=Færibreytan %1 hefur ógilt gildi. Væntanlegt er %2.';
        ProblemsErr: Label '%1 problems in the request. Nothing was written.', Comment = '%1 = problem count||is-IS=%1 vandamál í beiðninni. Ekkert var skrifað.';
        Base64ExpectedTxt: Label 'A valid base64-encoded file.', Comment = 'is-IS=Gild base64-kóðuð skrá.';
        TemplateNotFoundErr: Label 'The Billing Template %1 does not exist.', Comment = '%1 = template code||is-IS=Reikningssniðmátið %1 er ekki til.';
        ExistingTemplateTxt: Label 'An existing billing template code.', Comment = 'is-IS=Kóði fyrirliggjandi reikningssniðmáts.';
        Base64Err: Label 'The parameter contentBase64 is not valid base64.', Comment = 'is-IS=Færibreytan contentBase64 er ekki gilt base64.';
        MissingParameterErr: Label 'The request is missing the required parameter ''%1''.', Comment = '%1 = parameter name||is-IS=Beiðnina vantar nauðsynlega færibreytu ''%1''.';
        InvalidDateErr: Label 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' er ekki gild dagsetning. Notaðu ISO sniðið YYYY-MM-DD.';
        InvalidDecimalErr: Label 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' er ekki gild tala. Notaðu tugapunkt, til dæmis 1234.56.';
        InvalidPartnerErr: Label 'The parameter ''%1'' must be either ''Customer'' or ''Vendor''.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' verður að vera annaðhvort ''Customer'' eða ''Vendor''.';
        ValueTooLongErr: Label 'The parameter ''%1'' is longer than the %2 characters allowed.', Comment = '%1 = parameter name, %2 = maximum length||is-IS=Færibreytan ''%1'' er lengri en leyfilegur hámarksfjöldi stafa, %2.';
        NotAnArrayErr: Label 'The parameter ''%1'' must be a JSON array.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' verður að vera JSON-fylki.';
        InvalidEntryNoArrayErr: Label 'The parameter ''%1'' must be a JSON array of entry numbers, written as whole numbers.', Comment = '%1 = parameter name||is-IS=Færibreytan ''%1'' verður að vera JSON fylki af færslunúmerum, rituðum sem heilar tölur.';

    /// <summary>Raises a shared structured error while preserving the normal transaction rollback path.</summary>
    procedure RaiseError(ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; ParameterName: Text; Received: Text; Expected: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        if Received = '' then
            Received := '<missing>';
        TempArgument.AddError(ErrorCode, MessageText, ParameterName, Received, Expected, StrSubstNo(CorrectParameterTxt, ParameterName));
        TempArgument.RaiseCollectedErrors("Bifrost Error Code ori"::MultipleErrors, MessageText);
    end;

    /// <summary>Raises an app-owned refusal with the stable shared code and translated recovery fields.</summary>
    procedure RaiseRefusal(ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; ParameterName: Text; Received: Text)
    var
        Expected: Text;
        ExistingRecordTxt: Label 'An existing record identified by %1.', Comment = '%1 = parameter||is-IS=Fyrirliggjandi færsla sem %1 auðkennir.';
        PreconditionsTxt: Label 'The conditions described in the error must hold for %1.', Comment = '%1 = parameter||is-IS=Skilyrðin sem lýst er í villunni verða að vera uppfyllt fyrir %1.';
        ConsistentIdentifiersTxt: Label 'Consistent identifiers for %1.', Comment = '%1 = parameter||is-IS=Samræmd auðkenni fyrir %1.';
        BusinessOperationTxt: Label 'Business Central must be able to complete the operation for %1.', Comment = '%1 = parameter||is-IS=Business Central verður að geta lokið aðgerðinni fyrir %1.';
    begin
        case ErrorCode of
            "Bifrost Error Code ori"::RecordNotFound:
                Expected := StrSubstNo(ExistingRecordTxt, ParameterName);
            "Bifrost Error Code ori"::PreconditionFailed:
                Expected := StrSubstNo(PreconditionsTxt, ParameterName);
            "Bifrost Error Code ori"::ConflictingIdentifiers:
                Expected := StrSubstNo(ConsistentIdentifiersTxt, ParameterName);
            "Bifrost Error Code ori"::BusinessCentralError:
                Expected := StrSubstNo(BusinessOperationTxt, ParameterName);
            else
                Expected := StrSubstNo(ExpectedValueTxt, ParameterName);
        end;
        RaiseError(ErrorCode, MessageText, ParameterName, Received, Expected);
    end;

    /// <summary>Decodes only into an in-memory blob. Decode exceptions never expose platform/.NET text.</summary>
    [TryFunction]
    procedure TryDecodeBase64(ContentBase64: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Base64Convert: Codeunit "Base64 Convert";
        DataOut: OutStream;
    begin
        TempBlob.CreateOutStream(DataOut);
        Base64Convert.FromBase64(ContentBase64, DataOut);
    end;

    /// <summary>Collects request-value problems before the implementation performs business lookups or writes.</summary>
    procedure ValidateRequest(var Argument: Record "Message Argument ori"): Boolean
    var
        BillingTemplate: Record "Billing Template";
        Parts: Codeunit "Sub Contract Parts ori";
        TempBlob: Codeunit "Temp Blob";
        Contract: Interface "Msg Contract ori";
        Request: JsonObject;
        Definition: JsonObject;
        Parameters: JsonArray;
        DefinitionToken: JsonToken;
        ValueToken: JsonToken;
        SubjectValue: JsonValue;
        TypeName: Text;
        SubjectKey: Text;
        SubjectForm: Text;
        ParameterName: Text;
        ParameterType: Text;
        Received: Text;
        Expected: Text;
        ProblemCount: Integer;
        Required: Boolean;
        Missing: Boolean;
    begin
        Request := Argument.GetRequestJson();
        TypeName := Argument."Type".Names().Get(Argument."Type".Ordinals().IndexOf(Argument."Type".AsInteger()));
        Parts.GetSubjectKey(TypeName, SubjectKey, SubjectForm);
        Contract := Argument."Type";
        Contract.GetParameters(Parameters);
        foreach DefinitionToken in Parameters do begin
            Definition := DefinitionToken.AsObject();
            ParameterName := GetText(Definition, 'name', false);
            ParameterType := GetText(Definition, 'type', false);
            Required := GetBoolean(Definition, 'required', false);
            Clear(ValueToken);
            Clear(Received);
            if (ParameterName = SubjectKey) and (Argument.Subject <> '') then begin
                SubjectValue.SetValue(Argument.Subject);
                ValueToken := SubjectValue.AsToken();
            end else
                if not Request.Get(ParameterName, ValueToken) then
                    Clear(ValueToken);
            if ValueToken.IsValue() then
                if not ValueToken.AsValue().IsNull() then
                    Received := ValueToken.AsValue().AsText();
            Missing := (not Request.Contains(ParameterName)) and not ((ParameterName = SubjectKey) and (Argument.Subject <> ''));
            if ValueToken.IsValue() then
                if ValueToken.AsValue().IsNull() then
                    Missing := true
                else
                    if (Received = '') and (ParameterType = 'string') and (ParameterName <> 'filter') then
                        Missing := true;
            if Missing then begin
                if Required then begin
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, ParameterName), ParameterName, '<missing>', StrSubstNo(ExpectedValueTxt, ParameterName), StrSubstNo(CorrectParameterTxt, ParameterName));
                    ProblemCount += 1;
                end;
            end else begin
                if not ValueToken.IsValue() then
                    ValueToken.WriteTo(Received);
                Expected := ParameterType;
                if GetText(Definition, 'format', false) = 'date' then
                    Expected := 'YYYY-MM-DD';
                if not ValidParameterValue(ValueToken, ParameterType, Expected) then begin
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidValueErr, ParameterName, Expected), ParameterName, Received, Expected, StrSubstNo(CorrectParameterTxt, ParameterName));
                    ProblemCount += 1;
                end else
                    if IsCodeParameter(ParameterName) and (StrLen(Received) > 20) then begin
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ValueTooLongErr, ParameterName, 20), ParameterName, Received, '20 characters at most', StrSubstNo(CorrectParameterTxt, ParameterName));
                        ProblemCount += 1;
                    end else
                        if not AllowedParameterValue(Definition, ValueToken) then begin
                            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidValueErr, ParameterName, GetAllowedText(Definition)), ParameterName, Received, GetAllowedText(Definition), StrSubstNo(CorrectParameterTxt, ParameterName));
                            ProblemCount += 1;
                        end;
            end;
        end;
        if HasValue(Request, 'contentBase64') then
            if not TryDecodeBase64(GetText(Request, 'contentBase64', false), TempBlob) then begin
                ClearLastError();
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, Base64Err, 'contentBase64', '[omitted]', Base64ExpectedTxt, StrSubstNo(CorrectParameterTxt, 'contentBase64'));
                ProblemCount += 1;
            end;
        // All request values have been collected before the first business lookup.
        // A well-formed template key can be checked even when another value (such as a date) is bad.
        if SubjectKey = 'billingTemplateCode' then begin
            Received := GetText(Request, SubjectKey, false);
            if Argument.Subject <> '' then
                Received := Argument.Subject;
            if (Received <> '') and (StrLen(Received) <= 20) then
                if not BillingTemplate.Get(CopyStr(Received, 1, MaxStrLen(BillingTemplate.Code))) then begin
                    Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateNotFoundErr, Received), SubjectKey, Received, ExistingTemplateTxt, StrSubstNo(CorrectParameterTxt, SubjectKey));
                    ProblemCount += 1;
                end;
        end;
        CollectNestedProblems(Argument, Request, TypeName, ProblemCount);
        if (TypeName = 'Subscription.Usage.ImportData') and not HasValue(Request, 'content') and not HasValue(Request, 'contentBase64') then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, 'content'), 'content', '<missing>', Base64ExpectedTxt, StrSubstNo(CorrectParameterTxt, 'content'));
            ProblemCount += 1;
        end;
        if ProblemCount = 0 then
            exit(true);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, StrSubstNo(ProblemsErr, ProblemCount));
        exit(false);
    end;

    local procedure CollectNestedProblems(var Argument: Record "Message Argument ori"; Request: JsonObject; TypeName: Text; var ProblemCount: Integer)
    var
        ArrayToken: JsonToken;
        Entry: JsonToken;
        Values: JsonArray;
        Item: JsonObject;
        Index: Integer;
        Path: Text;
        Received: Text;
        DocumentPathTxt: Label 'documents[%1]', Locked = true;
    begin
        Index := 0;
        if TypeName = 'Subscription.Billing.PostDocuments' then begin
            if not Request.Get('documents', ArrayToken) then
                exit;
            if not ArrayToken.IsArray() then
                exit;
            Values := ArrayToken.AsArray();
            if Values.Count() = 0 then begin
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, 'documents'), 'documents', '[]', 'array', StrSubstNo(CorrectParameterTxt, 'documents'));
                ProblemCount += 1;
            end;
            foreach Entry in Values do begin
                Path := StrSubstNo(DocumentPathTxt, Index);
                if not Entry.IsObject() then begin
                    Entry.WriteTo(Received);
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidValueErr, Path, 'object'), Path, Received, 'object', StrSubstNo(CorrectParameterTxt, Path));
                    ProblemCount += 1;
                end else begin
                    Item := Entry.AsObject();
                    CheckNestedProperty(Argument, Item, 'partner', Path + '.partner', true, 'Customer|Vendor', 0, ProblemCount);
                    CheckNestedProperty(Argument, Item, 'documentType', Path + '.documentType', true, 'Invoice|Credit Memo', 0, ProblemCount);
                    CheckNestedProperty(Argument, Item, 'documentNo', Path + '.documentNo', true, '', 20, ProblemCount);
                    CheckNestedProperty(Argument, Item, 'vendorInvoiceNo', Path + '.vendorInvoiceNo', false, '', 35, ProblemCount);
                end;
                Index += 1;
            end;
        end;
    end;

    local procedure CheckNestedProperty(var Argument: Record "Message Argument ori"; Item: JsonObject; PropertyName: Text; Path: Text; Required: Boolean; Allowed: Text; MaximumLength: Integer; var ProblemCount: Integer)
    var
        Token: JsonToken;
        Received: Text;
        Candidate: Text;
        Found: Boolean;
        AllowedValues: List of [Text];
    begin
        if not Item.Get(PropertyName, Token) then begin
            if Required then begin
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, Path), Path, '<missing>', StrSubstNo(ExpectedValueTxt, Path), StrSubstNo(CorrectParameterTxt, Path));
                ProblemCount += 1;
            end;
            exit;
        end;
        Token.WriteTo(Received);
        if Token.IsValue() then
            if not Token.AsValue().IsNull() then begin
                Received := Token.AsValue().AsText();
                Found := (not Required or (Received <> '')) and ((MaximumLength = 0) or (StrLen(Received) <= MaximumLength));
                if Found and (Allowed <> '') then begin
                    Found := false;
                    AllowedValues := Allowed.Split('|');
                    foreach Candidate in AllowedValues do
                        if LowerCase(Candidate) = LowerCase(Received) then
                            Found := true;
                end;
            end;
        if Found then
            exit;
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidValueErr, Path, Allowed), Path, Received, StrSubstNo(ExpectedValueTxt, Path), StrSubstNo(CorrectParameterTxt, Path));
        ProblemCount += 1;
    end;

    local procedure ValidParameterValue(ValueToken: JsonToken; ParameterType: Text; Expected: Text): Boolean
    var
        DateValue: Date;
        DecimalValue: Decimal;
        IntegerValue: Integer;
        TextValue: Text;
    begin
        if ParameterType = 'array' then
            exit(ValueToken.IsArray());
        if ParameterType = 'object' then
            exit(ValueToken.IsObject());
        if not ValueToken.IsValue() then
            exit(false);
        if ValueToken.AsValue().IsNull() then
            exit(false);
        TextValue := ValueToken.AsValue().AsText();
        if Expected = 'YYYY-MM-DD' then
            exit((StrLen(TextValue) = 10) and Evaluate(DateValue, TextValue, 9));
        case ParameterType of
            'integer':
                exit(Evaluate(IntegerValue, TextValue, 9));
            'number':
                exit(Evaluate(DecimalValue, TextValue, 9));
            'boolean':
                exit(LowerCase(TextValue) in ['true', 'false', '1', '0']);
            'string':
                exit(true);
        end;
        exit(true);
    end;

    local procedure AllowedParameterValue(Definition: JsonObject; ValueToken: JsonToken): Boolean
    var
        AllowedToken: JsonToken;
        Candidate: JsonToken;
        Entry: JsonToken;
        Matches: Boolean;
    begin
        if not Definition.Get('allowed', AllowedToken) then
            exit(true);
        if not AllowedToken.IsArray() then
            exit(true);
        if ValueToken.IsArray() then begin
            foreach Entry in ValueToken.AsArray() do begin
                Matches := false;
                if Entry.IsValue() then
                    if not Entry.AsValue().IsNull() then
                        foreach Candidate in AllowedToken.AsArray() do
                            if LowerCase(Candidate.AsValue().AsText()) = LowerCase(Entry.AsValue().AsText()) then
                                Matches := true;
                if not Matches then
                    exit(false);
            end;
            exit(true);
        end;
        if not ValueToken.IsValue() then
            exit(true);
        foreach Candidate in AllowedToken.AsArray() do
            if LowerCase(Candidate.AsValue().AsText()) = LowerCase(ValueToken.AsValue().AsText()) then
                exit(true);
        exit(false);
    end;

    local procedure GetAllowedText(Definition: JsonObject): Text
    var
        AllowedToken: JsonToken;
        Result: Text;
    begin
        if Definition.Get('allowed', AllowedToken) then
            AllowedToken.WriteTo(Result);
        exit(Result);
    end;

    local procedure IsCodeParameter(ParameterName: Text): Boolean
    begin
        exit(ParameterName in ['billingTemplateCode', 'contractNo', 'customerContractNo', 'documentNo', 'itemNo', 'priceUpdateTemplateCode', 'purchaseInvoiceNo', 'subscriptionHeaderNo', 'subscriptionPackageCode', 'supplierNo', 'vendorContractNo']);
    end;

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
            RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotAnArrayErr, PropertyName), PropertyName, '', 'array');
        Value := JToken.AsArray();
        exit(true);
    end;

    /// <summary>
    /// Reads an optional JSON array of record entry numbers and turns it into a filter the database
    /// can apply. Every element has to be a value that reads as a whole number - anything else is
    /// rejected rather than quietly skipped, so a caller who sends the wrong shape is told so.
    /// Fills SelectedEntryNos with the distinct numbers, and returns the ''Entry No.'' filter to
    /// apply before reading: the numbers themselves while the list is short enough for one filter
    /// expression, and an empty text once it is not - past that point the caller keeps every
    /// candidate row and tests it against SelectedEntryNos, which costs one dictionary lookup a row
    /// and cannot run into the length a filter expression is allowed to have. An empty text is also
    /// what an absent property returns, and then SelectedEntryNos is empty too, which means
    /// "no selection - take everything".
    /// </summary>
    procedure GetEntryNoSelection(RequestJson: JsonObject; PropertyName: Text; var SelectedEntryNos: Dictionary of [Integer, Boolean]) EntryNoFilter: Text
    var
        EntryNoJsonArray: JsonArray;
        EntryNoJToken: JsonToken;
        EntryNo: Integer;
        MaxInlineEntryNos: Integer;
    begin
        Clear(SelectedEntryNos);
        if not TryGetArray(RequestJson, PropertyName, EntryNoJsonArray) then
            exit('');

        foreach EntryNoJToken in EntryNoJsonArray do begin
            if not EntryNoJToken.IsValue() then
                RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidEntryNoArrayErr, PropertyName), PropertyName, '', 'array of integers');
            if not Evaluate(EntryNo, EntryNoJToken.AsValue().AsText(), 9) then
                RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidEntryNoArrayErr, PropertyName), PropertyName, '', 'array of integers');
            if not SelectedEntryNos.ContainsKey(EntryNo) then
                SelectedEntryNos.Add(EntryNo, true);
        end;

        // Ten digits and a separator per entry number keeps a full list of this many comfortably
        // inside what Business Central accepts as a single filter expression.
        MaxInlineEntryNos := 50;
        if (SelectedEntryNos.Count() = 0) or (SelectedEntryNos.Count() > MaxInlineEntryNos) then
            exit('');

        foreach EntryNo in SelectedEntryNos.Keys() do begin
            if EntryNoFilter <> '' then
                EntryNoFilter += '|';
            EntryNoFilter += Format(EntryNo, 0, 9);
        end;
        exit(EntryNoFilter);
    end;

    /// <summary>Reads a text value. Errors when Required and the value is absent.</summary>
    procedure GetText(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Text
    var
        JToken: JsonToken;
    begin
        if not HasValue(RequestJson, PropertyName) then begin
            if Required then
                RaiseError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, PropertyName), PropertyName, '', StrSubstNo(ExpectedValueTxt, PropertyName));
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
            RaiseError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ValueTooLongErr, PropertyName, MaxStrLen(Value)), PropertyName, TextValue, '20 characters at most');
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
            RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidDateErr, PropertyName), PropertyName, TextValue, 'YYYY-MM-DD');
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
                RaiseError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, PropertyName), PropertyName, '', StrSubstNo(ExpectedValueTxt, PropertyName));
            exit(0);
        end;
        RequestJson.Get(PropertyName, JToken);
        TextValue := JToken.AsValue().AsText();
        if not Evaluate(Value, TextValue, 9) then
            RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidDecimalErr, PropertyName), PropertyName, TextValue, 'number');
    end;

    /// <summary>Reads an integer value.</summary>
    procedure GetInteger(RequestJson: JsonObject; PropertyName: Text; Required: Boolean) Value: Integer
    var
        JToken: JsonToken;
        TextValue: Text;
    begin
        if not HasValue(RequestJson, PropertyName) then begin
            if Required then
                RaiseError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, PropertyName), PropertyName, '', StrSubstNo(ExpectedValueTxt, PropertyName));
            exit(0);
        end;
        RequestJson.Get(PropertyName, JToken);
        TextValue := JToken.AsValue().AsText();
        if not Evaluate(Value, TextValue, 9) then
            RaiseError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidDecimalErr, PropertyName), PropertyName, TextValue, 'number');
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
                RaiseError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidPartnerErr, PropertyName), PropertyName, TextValue, 'Customer or Vendor');
        end;
    end;

    /// <summary>Returns the subject when set, otherwise the named request property. The request and the key come first, as in every other reader, so the key reads as a request key.</summary>
    procedure GetSubjectOr(RequestJson: JsonObject; PropertyName: Text; var Argument: Record "Message Argument ori"; Required: Boolean) Value: Code[20]
    begin
        if Argument.Subject <> '' then begin
            if StrLen(Argument.Subject) > MaxStrLen(Value) then
                RaiseError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ValueTooLongErr, PropertyName, MaxStrLen(Value)), PropertyName, Argument.Subject, '20 characters at most');
            exit(CopyStr(Argument.Subject, 1, MaxStrLen(Value)));
        end;
        exit(GetCode20(RequestJson, PropertyName, Required));
    end;

    /// <summary>Writes a success response and stamps the JSON content type.</summary>
    procedure RespondWithSuccess(var Argument: Record "Message Argument ori"; var ResponseJson: JsonObject)
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

    /// <summary>
    /// Refuses to clear a billing proposal or delete billing documents when a Billing Template bills
    /// automatically and the user is not set up for automated contract billing. This is the rule of
    /// Microsoft's internal "Billing Proposal".DisplayErrorIfNotAuthorizedToClearProposalOrDeleteDocuments
    /// (BCApps src/Apps/W1/Subscription Billing/App/Billing/Codeunits/BillingProposal.Codeunit.al, releases/28.x
    /// a674a13), rewritten here because the procedure is internal; see docs/microsoft-dependencies.md.
    /// </summary>
    procedure AssertMayClearBillingProposal()
    var
        BillingTemplate: Record "Billing Template";
        UserSetup: Record "User Setup";
        NotAuthorizedErr: Label 'You are not authorized to clear billing proposals or delete billing documents while a Billing Template bills automatically. Set Auto Contract Billing on your user in User Setup.', Comment = 'is-IS=Þú hefur ekki heimild til að hreinsa reikningstillögur eða eyða reikningsskjölum á meðan reikningssniðmát gerir reikninga sjálfvirkt. Merktu við Reikningsregla samnings á notandanum þínum í Uppsetningu notanda.';
    begin
        BillingTemplate.ReadIsolation := IsolationLevel::ReadCommitted;
        BillingTemplate.SetFilter(Automation, '<>%1', BillingTemplate.Automation::None);
        if BillingTemplate.IsEmpty() then
            exit;
        UserSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        if UserSetup.Get(UserId()) then
            if UserSetup."Auto Contract Billing" then
                exit;
        RaiseRefusal("Bifrost Error Code ori"::PreconditionFailed, NotAuthorizedErr, 'permission', 'Auto Contract Billing');
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
