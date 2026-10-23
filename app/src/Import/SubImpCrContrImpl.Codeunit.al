namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Import.CreateContracts</c> Bifrost message type.
/// </summary>
codeunit 10035057 "Sub Imp CrContr Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        UnknownStageErr: Label '''%1'' is not a known import stage. Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines.', Comment = '%1 = stage name||is-IS=''%1'' er ekki þekkt innflutningsstig. Notaðu SubscriptionHeaders, CustomerContracts, SubscriptionLines eða ContractLines.';
        MaxErrorsCappedMsg: Label 'Only the first %1 errors are listed; more rows may have failed.', Comment = '%1 = maximum error count||is-IS=Aðeins fyrstu %1 villurnar eru sýndar; fleiri línur gætu hafa mistekist.';
        LineTypeRequiredErr: Label 'Sub_ContractLineType is required: set it to Item or G/L Account, or to Comment and send allowCommentLines = true.', Comment = 'is-IS=Sub_ContractLineType er nauðsynlegt: veldu Vara eða Fjárhagsreikningur, eða Athugasemd og sendu allowCommentLines = true.';
        LineNotCreatedErr: Label 'Create Subscription Line reported success but Subscription Line Entry No. is still 0.', Comment = 'is-IS=Stofnun áskriftarlínu tilkynnti árangur en númer áskriftarlínu er enn 0.';
        SubscriptionHeadersTok: Label 'SubscriptionHeaders', Locked = true;
        CustomerContractsTok: Label 'CustomerContracts', Locked = true;
        SubscriptionLinesTok: Label 'SubscriptionLines', Locked = true;
        ContractLinesTok: Label 'ContractLines', Locked = true;
        MaxErrorCount: Integer;
        DescriptionLbl: Label 'Creates Subscription Headers, Customer Subscription Contracts, Subscription Lines and Cust. Sub. Contract Lines from staged import rows, one stage at a time.', MaxLength = 250, Comment = 'is-IS=Býr til áskriftarhausa, áskriftarsamninga viðskiptamanna, áskriftarlínur og samningslínur áskriftarsamnings viðskiptamanns út frá innfluttum bráðabirgðalínum, eitt skref í einu.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Imported Subscription Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'import contracts, create contracts from staging, migrate subscriptions, contract migration, create subscription contracts from import, load contracts from staging rows, import subscription headers, import contract lines', Comment = 'is-IS=flytja inn samninga, stofna samninga úr bráðabirgðalínum, flytja áskriftir yfir, gagnaflutningur samninga, stofna áskriftarsamninga úr innflutningi, hlaða samningum úr bráðabirgðalínum, flytja inn áskriftarhausa, flytja inn samningslínur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create contracts from staged import rows: turns unprocessed staging rows into Subscription Headers, Customer Subscription Contracts, Subscription Lines and contract lines, one stage at a time, committing as it goes. Irreversible. To add the lines of one package to a single Subscription without staging use Subscription.Line.Create.', Comment = 'is-IS=Stofna samninga úr innfluttum bráðabirgðalínum: breytir óunnum bráðabirgðalínum í áskriftarhausa, áskriftarsamninga viðskiptamanna, áskriftarlínur og samningslínur, eitt skref í einu, og vistar jafnóðum. Óafturkræf aðgerð. Til að bæta línum eins pakka við eina áskrift án bráðabirgðalína skal nota Subscription.Line.Create.';
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
        Parameters := ContractParts.ImportParameters();
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
        Examples.Add(ContractMgt.Example('Run all stages',
            '{"type":"Subscription.Import.CreateContracts","data":{}}',
            '{"status":"Success","stages":[{"stage":"SubscriptionHeaders","processed":5,"succeeded":5,"failed":0,"skipped":0},{"stage":"CustomerContracts","processed":5,"succeeded":4,"failed":1,"skipped":0},{"stage":"SubscriptionLines","processed":5,"succeeded":5,"failed":0,"skipped":0},{"stage":"ContractLines","processed":5,"succeeded":4,"failed":1,"skipped":0}],"errors":[{"stage":"CustomerContracts","key":"12","error":"..."}]}'));
        Examples.Add(ContractMgt.Example('Import contract comment lines',
            '{"type":"Subscription.Import.CreateContracts","data":{"stages":["SubscriptionLines","ContractLines"],"allowCommentLines":true}}',
            '{"status":"Success","stages":[{"stage":"SubscriptionLines","processed":3,"succeeded":3,"failed":0,"skipped":1},{"stage":"ContractLines","processed":4,"succeeded":4,"failed":0,"skipped":0}],"errors":[]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Turns staged import rows into Subscription Headers, Customer Subscription Contracts, Subscription Lines and customer contract lines, in four stages that ' +
            'always run in the fixed order SubscriptionHeaders, CustomerContracts, SubscriptionLines, ContractLines. The rows are staged beforehand in Imported Subscription Header, ' +
            'Imported Cust. Sub. Contract and Imported Subscription Line. Use it to migrate existing subscriptions into Subscription Billing: a row that fails keeps its error text on ' +
            'the staging row and does not fail the call.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Stage the rows first, for example with Data.Records.Set on Imported Subscription Header, Imported Cust. Sub. Contract and Imported Subscription Line. ' +
            'Every Imported Subscription Line row needs Sub_ContractLineType: Item or G/L Account for a billable line, or Comment for a contract comment line. ' +
            'Comment is also the value of a row that never had the field set, so a Comment row is only imported when the call sends allowCommentLines = true; ' +
            'the SubscriptionLines stage then skips it, and the ContractLines stage creates the contract comment line, which needs Subscription Contract No., ' +
            'Partner and Invoicing via = Contract. Without allowCommentLines a Comment row fails with the line type error and no contract line is created for it. ' +
            'A row whose Subscription Line Entry No. is still 0 after Create Subscription Line is also failed. When the call runs the SubscriptionLines stage, ' +
            'the ContractLines stage skips the rows that stage failed, and counts them under skipped. A row failure does not fail the call. ' +
            ContractParts.BooleanNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Import.CreateContracts');
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
        if not Helper.ValidateRequest(Argument) then
            exit;
        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Sub Imp CrContr Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StagesArray: JsonArray;
        ErrorsArray: JsonArray;
        RequestedStages: List of [Text];
        ErrorCount: Integer;
        AllowCommentLines: Boolean;
        SubscriptionLinesRequested: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        GetRequestedStages(RequestJson, RequestedStages);
        AllowCommentLines := Helper.GetBoolean(RequestJson, 'allowCommentLines', false);
        SubscriptionLinesRequested := RequestedStages.Contains(SubscriptionLinesTok);
        MaxErrorCount := 50;
        ErrorCount := 0;
        if RequestedStages.Contains(SubscriptionHeadersTok) then
            RunSubscriptionHeaders(StagesArray, ErrorsArray, ErrorCount);
        if RequestedStages.Contains(CustomerContractsTok) then
            RunCustomerContracts(StagesArray, ErrorsArray, ErrorCount);
        if SubscriptionLinesRequested then
            RunSubscriptionLines(StagesArray, ErrorsArray, ErrorCount, AllowCommentLines);
        if RequestedStages.Contains(ContractLinesTok) then
            RunContractLines(StagesArray, ErrorsArray, ErrorCount, AllowCommentLines, SubscriptionLinesRequested);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('stages', StagesArray);
        ResponseJson.Add('errors', ErrorsArray);
        if ErrorCount > MaxErrorCount then
            ResponseJson.Add('errorsNote', StrSubstNo(MaxErrorsCappedMsg, MaxErrorCount));
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure GetRequestedStages(RequestJson: JsonObject; var RequestedStages: List of [Text])
    var
        StageToken: JsonToken;
        StagesArrayIn: JsonArray;
        StageName: Text;
    begin
        Clear(RequestedStages);
        if Helper.TryGetArray(RequestJson, 'stages', StagesArrayIn) then begin
            foreach StageToken in StagesArrayIn do begin
                StageName := StageToken.AsValue().AsText();
                case StageName of
                    SubscriptionHeadersTok, CustomerContractsTok, SubscriptionLinesTok, ContractLinesTok:
                        RequestedStages.Add(StageName);
                    else
                        Error(UnknownStageErr, StageName);
                end;
            end;
            exit;
        end;
        RequestedStages.Add(SubscriptionHeadersTok);
        RequestedStages.Add(CustomerContractsTok);
        RequestedStages.Add(SubscriptionLinesTok);
        RequestedStages.Add(ContractLinesTok);
    end;

    local procedure AddStageResult(var StagesArray: JsonArray; StageName: Text; Processed: Integer; Succeeded: Integer; Failed: Integer; Skipped: Integer)
    var
        StageJson: JsonObject;
    begin
        StageJson.Add('stage', StageName);
        StageJson.Add('processed', Processed);
        StageJson.Add('succeeded', Succeeded);
        StageJson.Add('failed', Failed);
        StageJson.Add('skipped', Skipped);
        StagesArray.Add(StageJson);
    end;

    local procedure AddError(var ErrorsArray: JsonArray; var ErrorCount: Integer; StageName: Text; RowKey: Text; ErrorMessage: Text)
    var
        ErrorJson: JsonObject;
    begin
        ErrorCount += 1;
        if ErrorCount > MaxErrorCount then
            exit;
        ErrorJson.Add('stage', StageName);
        ErrorJson.Add('key', RowKey);
        ErrorJson.Add('error', ErrorMessage);
        ErrorsArray.Add(ErrorJson);
    end;

    local procedure FailLine(var ImportedSubscriptionLine: Record "Imported Subscription Line"; var ErrorsArray: JsonArray; var ErrorCount: Integer; StageName: Text; ErrorMessage: Text)
    begin
        ImportedSubscriptionLine."Error Text" := CopyStr(ErrorMessage, 1, MaxStrLen(ImportedSubscriptionLine."Error Text"));
        if StageName = SubscriptionLinesTok then
            ImportedSubscriptionLine."Subscription Line created" := false;
        ImportedSubscriptionLine.Modify(false);
        Commit();
        AddError(ErrorsArray, ErrorCount, StageName, Format(ImportedSubscriptionLine."Entry No.", 0, 9), ImportedSubscriptionLine."Error Text");
    end;

    local procedure RunSubscriptionHeaders(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer)
    var
        ImportedSubscriptionHeader: Record "Imported Subscription Header";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
    begin
        ImportedSubscriptionHeader.SetRange("Subscription Header created", false);
        if ImportedSubscriptionHeader.FindSet() then
            repeat
                Processed += 1;
                ClearLastError();
                if Codeunit.Run(Codeunit::"Create Subscription Header", ImportedSubscriptionHeader) then
                    Succeeded += 1
                else begin
                    Failed += 1;
                    ImportedSubscriptionHeader."Error Text" := CopyStr(GetLastErrorText(), 1, MaxStrLen(ImportedSubscriptionHeader."Error Text"));
                    ImportedSubscriptionHeader.Modify(false);
                    Commit();
                    AddError(ErrorsArray, ErrorCount, SubscriptionHeadersTok, Format(ImportedSubscriptionHeader."Entry No.", 0, 9), ImportedSubscriptionHeader."Error Text");
                end;
            until ImportedSubscriptionHeader.Next() = 0;
        AddStageResult(StagesArray, SubscriptionHeadersTok, Processed, Succeeded, Failed, 0);
    end;

    local procedure RunCustomerContracts(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer)
    var
        ImportedCustSubContract: Record "Imported Cust. Sub. Contract";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
    begin
        ImportedCustSubContract.SetRange("Contract created", false);
        if ImportedCustSubContract.FindSet() then
            repeat
                Processed += 1;
                ClearLastError();
                if Codeunit.Run(Codeunit::"Create Cust. Sub. Contract", ImportedCustSubContract) then
                    Succeeded += 1
                else begin
                    Failed += 1;
                    ImportedCustSubContract."Error Text" := CopyStr(GetLastErrorText(), 1, MaxStrLen(ImportedCustSubContract."Error Text"));
                    ImportedCustSubContract.Modify(false);
                    Commit();
                    AddError(ErrorsArray, ErrorCount, CustomerContractsTok, Format(ImportedCustSubContract."Entry No.", 0, 9), ImportedCustSubContract."Error Text");
                end;
            until ImportedCustSubContract.Next() = 0;
        AddStageResult(StagesArray, CustomerContractsTok, Processed, Succeeded, Failed, 0);
    end;

    local procedure RunSubscriptionLines(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer; AllowCommentLines: Boolean)
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Skipped: Integer;
    begin
        ImportedSubscriptionLine.SetRange("Subscription Line created", false);
        if ImportedSubscriptionLine.FindSet() then
            repeat
                if ImportedSubscriptionLine.IsContractCommentLine() then begin
                    if AllowCommentLines then
                        Skipped += 1
                    else begin
                        Processed += 1;
                        Failed += 1;
                        FailLine(ImportedSubscriptionLine, ErrorsArray, ErrorCount, SubscriptionLinesTok, LineTypeRequiredErr);
                    end;
                end else begin
                    Processed += 1;
                    ClearLastError();
                    if not Codeunit.Run(Codeunit::"Create Subscription Line", ImportedSubscriptionLine) then begin
                        Failed += 1;
                        FailLine(ImportedSubscriptionLine, ErrorsArray, ErrorCount, SubscriptionLinesTok, GetLastErrorText());
                    end else
                        if ImportedSubscriptionLine."Subscription Line Entry No." = 0 then begin
                            Failed += 1;
                            FailLine(ImportedSubscriptionLine, ErrorsArray, ErrorCount, SubscriptionLinesTok, LineNotCreatedErr);
                        end else
                            Succeeded += 1;
                end;
            until ImportedSubscriptionLine.Next() = 0;
        AddStageResult(StagesArray, SubscriptionLinesTok, Processed, Succeeded, Failed, Skipped);
    end;

    local procedure RunContractLines(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer; AllowCommentLines: Boolean; SubscriptionLinesRequested: Boolean)
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Skipped: Integer;
    begin
        ImportedSubscriptionLine.SetRange("Sub. Contract Line created", false);
        if ImportedSubscriptionLine.FindSet() then
            repeat
                if IsReportedBySubscriptionLines(ImportedSubscriptionLine, AllowCommentLines, SubscriptionLinesRequested) then
                    Skipped += 1
                else begin
                    Processed += 1;
                    if ImportedSubscriptionLine.IsContractCommentLine() and not AllowCommentLines then begin
                        Failed += 1;
                        FailLine(ImportedSubscriptionLine, ErrorsArray, ErrorCount, ContractLinesTok, LineTypeRequiredErr);
                    end else begin
                        ClearLastError();
                        if Codeunit.Run(Codeunit::"Create Sub. Contract Line", ImportedSubscriptionLine) then
                            Succeeded += 1
                        else begin
                            Failed += 1;
                            FailLine(ImportedSubscriptionLine, ErrorsArray, ErrorCount, ContractLinesTok, GetLastErrorText());
                        end;
                    end;
                end;
            until ImportedSubscriptionLine.Next() = 0;
        AddStageResult(StagesArray, ContractLinesTok, Processed, Succeeded, Failed, Skipped);
    end;

    /// <summary>
    /// True for a row the SubscriptionLines stage of the same call has already failed and listed:
    /// a comment row sent without allowCommentLines, or another row whose Subscription Line was not
    /// created. The ContractLines stage skips such a row, so no contract line is created for it.
    /// </summary>
    local procedure IsReportedBySubscriptionLines(var ImportedSubscriptionLine: Record "Imported Subscription Line"; AllowCommentLines: Boolean; SubscriptionLinesRequested: Boolean): Boolean
    begin
        if not SubscriptionLinesRequested then
            exit(false);
        if ImportedSubscriptionLine.IsContractCommentLine() then
            exit(not AllowCommentLines);
        exit(not ImportedSubscriptionLine."Subscription Line created");
    end;
}
