namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements <c>Subscription.Contract.MergeLines</c>.
/// Microsoft's MergeContractLines opens a selection page. This type merges the named customer
/// contract lines with the same eligibility rules and the same resulting line, and takes the
/// reference line in the request instead of that page.
/// </summary>
codeunit 10035073 "Sub Con Merge Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        MergeMgt: Codeunit "Sub Con Merge Mgt ori";
        DescriptionLbl: Label 'Merges customer contract lines the way Microsoft merges them, without opening a page. The reference line names the Subscription that is copied.', MaxLength = 250, Comment = 'is-IS=Sameinar samningslínur viðskiptamanns eins og Microsoft sameinar þær, án þess að opna síðu. Tilvísunarlínan nefnir áskriftina sem er afrituð.';
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur viðskiptamanns ''%1'' er ekki til.';
        LineNotFoundErr: Label 'Customer contract line %1 does not exist on contract %2.', Comment = '%1 = line number, %2 = contract number||is-IS=Samningslína viðskiptamanns %1 er ekki til á samningi %2.';
        DifferentContractErr: Label 'The lines belong to more than one Customer Subscription Contract. Merge lines of one contract at a time.', Comment = 'is-IS=Línurnar tilheyra fleiri en einum áskriftarsamningi viðskiptamanns. Sameinaðu línur eins samnings í einu.';
        MissingLinesErr: Label 'The request is missing the required parameter ''%1''.', Comment = '%1 = parameter name||is-IS=Beiðnina vantar nauðsynlega færibreytu ''%1''.';
        LineShapeErr: Label 'Each entry of ''lines'' must be a JSON object with lineNo.', Comment = 'is-IS=Hver færsla í ''lines'' verður að vera JSON-hlutur með lineNo.';
        LineNoShapeErr: Label 'The parameter ''lineNo'' must be a whole number.', Comment = 'is-IS=Færibreytan ''lineNo'' verður að vera heil tala.';
        ReferenceNotInSetErr: Label 'referenceLineNo %1 is not one of the lines to merge.', Comment = '%1 = line number||is-IS=referenceLineNo %1 er ekki meðal línanna sem á að sameina.';
        ValueTooLongErr: Label 'The parameter ''%1'' is longer than the %2 characters allowed.', Comment = '%1 = parameter name, %2 = maximum length||is-IS=Færibreytan ''%1'' er lengri en leyfilegur hámarksfjöldi stafa, %2.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Customer Subscription Contract");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Contract.MergeLines, Subscription, Contract, MergeLines, customer, combine', Comment = 'is-IS=Subscription.Contract.MergeLines, áskrift, samningur, sameina línur, viðskiptamaður';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Contract.MergeLines: Merges customer contract lines. The closed lines stay closed.', Comment = 'is-IS=Subscription.Contract.MergeLines: Sameinar samningslínur viðskiptamanns. Lokaðu línurnar standa áfram lokaðar.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope := ContractParts.GetEnvelope(ContractType());
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target := ContractParts.GetTarget(ContractType());
        exit(Target.Count() > 0);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := ContractParts.MergeLinesParameters();
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response := ContractParts.GetResponse(ContractType());
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors := ContractParts.GetErrors(ContractType());
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect := ContractParts.GetEffect(ContractType());
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related := ContractParts.GetRelated(ContractType());
        exit(Related.Count() > 0);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow := ContractParts.GetWorkflow(ContractType());
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Merge two customer contract lines',
            '{"type":"Subscription.Contract.MergeLines","data":{"contractNo":"CSC-00001","lines":[{"lineNo":10000},{"contractNo":"CSC-00001","lineNo":20000}],"referenceLineNo":10000}}',
            '{"status":"Success","contractNo":"CSC-00001","referenceLineNo":10000,"closedLineCount":2,"newLineNo":30000,"merged":true}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Merges two or more customer contract lines into one Subscription. ' +
            'The reference line is the Subscription that is copied. The selected lines are closed.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The eligibility rules and the resulting line are Microsoft''s merge on Cust. Sub. Contract Line. ' +
            'referenceLineNo replaces the selection page, which an unattended caller cannot open. ' +
            'Lines from more than one contract are refused. A single line is refused. ' +
            'This call does not commit. Vendor contract lines are not merged.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.MergeLines');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformWrite(Rec);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Con Merge Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Merges the named customer contract lines. Called directly, or by OnRun.</summary>
    /// <param name="Argument">The message argument.</param>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CustomerContract: Record "Customer Subscription Contract";
        CustomerContractLine: Record "Cust. Sub. Contract Line";
        ReferenceLine: Record "Cust. Sub. Contract Line";
        NewContractLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        LineNos: JsonArray;
        ContractNo: Code[20];
        ReferenceLineNo: Integer;
        ClosedLineCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(RequestJson, 'contractNo', Argument, true);
        if not Helper.TryGetArray(RequestJson, 'lines', LineNos) then
            Error(MissingLinesErr, 'lines');
        ReferenceLineNo := Helper.GetInteger(RequestJson, 'referenceLineNo', true);

        if not CustomerContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        SelectLines(ContractNo, LineNos, ReferenceLineNo, CustomerContractLine, ReferenceLine);
        ClosedLineCount := CustomerContractLine.Count();
        MergeMgt.MergeLines(CustomerContractLine, ReferenceLine, NewContractLine);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('referenceLineNo', ReferenceLineNo);
        ResponseJson.Add('closedLineCount', ClosedLineCount);
        ResponseJson.Add('newLineNo', NewContractLine."Line No.");
        ResponseJson.Add('newSubscriptionHeaderNo', NewContractLine."Subscription Header No.");
        ResponseJson.Add('newSubscriptionLineEntryNo', NewContractLine."Subscription Line Entry No.");
        ResponseJson.Add('merged', true);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure SelectLines(ContractNo: Code[20]; Lines: JsonArray; ReferenceLineNo: Integer; var CustomerContractLine: Record "Cust. Sub. Contract Line"; var ReferenceLine: Record "Cust. Sub. Contract Line")
    var
        LineToken: JsonToken;
        LineContractNo: Code[20];
        LineNo: Integer;
        ReferenceFound: Boolean;
    begin
        CustomerContractLine.Reset();
        foreach LineToken in Lines do begin
            ReadLine(LineToken, ContractNo, LineContractNo, LineNo);
            if LineContractNo <> ContractNo then
                Error(DifferentContractErr);
            if not CustomerContractLine.Get(LineContractNo, LineNo) then
                Error(LineNotFoundErr, LineNo, LineContractNo);
            CustomerContractLine.Mark(true);
            if LineNo = ReferenceLineNo then begin
                ReferenceLine := CustomerContractLine;
                ReferenceFound := true;
            end;
        end;

        if not ReferenceFound then
            Error(ReferenceNotInSetErr, ReferenceLineNo);

        CustomerContractLine.MarkedOnly(true);
    end;

    local procedure ReadLine(LineToken: JsonToken; ContractNo: Code[20]; var LineContractNo: Code[20]; var LineNo: Integer)
    var
        LineObject: JsonObject;
        Token: JsonToken;
        ContractText: Text;
    begin
        if not LineToken.IsObject() then
            Error(LineShapeErr);
        LineObject := LineToken.AsObject();
        if not LineObject.Get('lineNo', Token) then
            Error(LineShapeErr);
        if not Token.IsValue() then
            Error(LineNoShapeErr);
        if not Evaluate(LineNo, Token.AsValue().AsText(), 9) then
            Error(LineNoShapeErr);
        if LineObject.Get('contractNo', Token) then begin
            if not Token.IsValue() then
                Error(LineShapeErr);
            ContractText := Token.AsValue().AsText();
            if StrLen(ContractText) > MaxStrLen(LineContractNo) then
                Error(ValueTooLongErr, 'contractNo', MaxStrLen(LineContractNo));
            LineContractNo := CopyStr(ContractText, 1, MaxStrLen(LineContractNo));
        end else
            LineContractNo := ContractNo;
    end;
}
