namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Import.CreateContracts</c> Cloud Event message type.
/// Builds real Subscription Header, Customer Subscription Contract, Subscription Line and
/// Cust. Sub. Contract Line records from staged import rows, by running Microsoft's four
/// TableNo-bound creation codeunits one staging row at a time. A plain Data.Records.Set cannot
/// do this because each stage derives and cross-links keys (contract numbers, line entry
/// numbers) that only Microsoft's own codeunits know how to compute.
/// </summary>
codeunit 10035057 "CE Sub Imp CrContr Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        UnknownStageErr: Label '''%1'' is not a known import stage. Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines.', Comment = '%1 = stage name||is-IS=''%1'' er ekki þekkt innflutningsskref. Notaðu SubscriptionHeaders, CustomerContracts, SubscriptionLines eða ContractLines.';
        MaxErrorsCappedMsg: Label 'Only the first %1 errors are listed; more rows may have failed.', Comment = '%1 = maximum error count||is-IS=Aðeins fyrstu %1 villurnar eru sýndar; fleiri línur gætu hafa mistekist.';
        SubscriptionHeadersTok: Label 'SubscriptionHeaders', Locked = true;
        CustomerContractsTok: Label 'CustomerContracts', Locked = true;
        SubscriptionLinesTok: Label 'SubscriptionLines', Locked = true;
        ContractLinesTok: Label 'ContractLines', Locked = true;
        MaxErrorCount: Integer;
        DescriptionLbl: Label 'Creates Subscription Headers, Customer Subscription Contracts, Subscription Lines and Cust. Sub. Contract Lines from staged import rows, one stage at a time.', MaxLength = 250, Comment = 'is-IS=Býr til áskriftarhausa, áskriftarsamninga viðskiptavina, áskriftarlínur og samningslínur áskriftarsamnings viðskiptavinar út frá innfluttum bráðabirgðalínum, eitt skref í einu.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Imported Subscription Header");
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
        HelpBuilder.AppendLine('# Subscription.Import.CreateContracts');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Turns staged import rows - Imported Subscription Header (table 8008), Imported Cust. Sub.');
        HelpBuilder.AppendLine('Contract (table 8010) and Imported Subscription Line (table 8009) - into real Subscription');
        HelpBuilder.AppendLine('Header, Customer Subscription Contract, Subscription Line and Cust. Sub. Contract Line');
        HelpBuilder.AppendLine('records. The four stages run in a fixed order - headers, then contracts, then lines, then');
        HelpBuilder.AppendLine('contract lines - because each later stage needs the keys the earlier stages wrote back onto');
        HelpBuilder.AppendLine('the staging rows. Only unprocessed rows are picked up: each stage filters to its own');
        HelpBuilder.AppendLine('''created'' flag being false, so calling this again only processes what is still outstanding.');
        HelpBuilder.AppendLine('One bad row does not stop the batch - its error is recorded on the staging row and the next');
        HelpBuilder.AppendLine('row is still attempted.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| stages | Array of Text | No | Which stages to run, in any subset of SubscriptionHeaders, CustomerContracts, SubscriptionLines, ContractLines. Defaults to all four, always executed in that fixed order regardless of the order given. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "stages": ["SubscriptionHeaders", "CustomerContracts", "SubscriptionLines", "ContractLines"]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "stages": [');
        HelpBuilder.AppendLine('    { "stage": "SubscriptionHeaders", "processed": 5, "succeeded": 5, "failed": 0 },');
        HelpBuilder.AppendLine('    { "stage": "CustomerContracts", "processed": 5, "succeeded": 4, "failed": 1 },');
        HelpBuilder.AppendLine('    { "stage": "SubscriptionLines", "processed": 5, "succeeded": 5, "failed": 0 },');
        HelpBuilder.AppendLine('    { "stage": "ContractLines", "processed": 5, "succeeded": 4, "failed": 1 }');
        HelpBuilder.AppendLine('  ],');
        HelpBuilder.AppendLine('  "errors": [');
        HelpBuilder.AppendLine('    { "stage": "CustomerContracts", "key": "12", "error": "..." }');
        HelpBuilder.AppendLine('  ]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`processed` is the number of unprocessed rows the stage found; `succeeded` and `failed` split');
        HelpBuilder.AppendLine('that count. `key` in `errors` is the staging row''s Entry No.. The `errors` array is capped at');
        HelpBuilder.AppendLine('the first 50 entries across all stages - a failed row past that cap is still counted in');
        HelpBuilder.AppendLine('`failed` but its detail is not listed; check the staging table in the client for the rest.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| An unknown stage name is given | ''%1'' is not a known import stage. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('A row failing to create its Subscription record is not itself a call error - it is reported');
        HelpBuilder.AppendLine('inside `stages` and `errors` instead, and the call still returns `"status": "Success"`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. It creates new Subscription Header, Customer Subscription Contract,');
        HelpBuilder.AppendLine('Subscription Line and Cust. Sub. Contract Line records from staging rows already present in');
        HelpBuilder.AppendLine('the database; it does not post anything. Each staging row is committed independently as it');
        HelpBuilder.AppendLine('is processed, so a failure partway through leaves earlier rows'' results in place - this call');
        HelpBuilder.AppendLine('cannot be rolled back as a whole once it has started.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Line.Create`');
        HelpBuilder.AppendLine('- `Subscription.Contract.GetLines`');

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

    /// <summary>Runs the requested import stages over the staged rows. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StagesArray: JsonArray;
        ErrorsArray: JsonArray;
        RequestedStages: List of [Text];
        ErrorCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        GetRequestedStages(RequestJson, RequestedStages);
        MaxErrorCount := 50;
        ErrorCount := 0;

        if RequestedStages.Contains(SubscriptionHeadersTok) then
            RunSubscriptionHeaders(StagesArray, ErrorsArray, ErrorCount);
        if RequestedStages.Contains(CustomerContractsTok) then
            RunCustomerContracts(StagesArray, ErrorsArray, ErrorCount);
        if RequestedStages.Contains(SubscriptionLinesTok) then
            RunSubscriptionLines(StagesArray, ErrorsArray, ErrorCount);
        if RequestedStages.Contains(ContractLinesTok) then
            RunContractLines(StagesArray, ErrorsArray, ErrorCount);

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

    local procedure AddStageResult(var StagesArray: JsonArray; StageName: Text; Processed: Integer; Succeeded: Integer; Failed: Integer)
    var
        StageJson: JsonObject;
    begin
        StageJson.Add('stage', StageName);
        StageJson.Add('processed', Processed);
        StageJson.Add('succeeded', Succeeded);
        StageJson.Add('failed', Failed);
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
        AddStageResult(StagesArray, SubscriptionHeadersTok, Processed, Succeeded, Failed);
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
        AddStageResult(StagesArray, CustomerContractsTok, Processed, Succeeded, Failed);
    end;

    local procedure RunSubscriptionLines(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer)
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
    begin
        ImportedSubscriptionLine.SetRange("Subscription Line created", false);
        if ImportedSubscriptionLine.FindSet() then
            repeat
                Processed += 1;
                ClearLastError();
                if Codeunit.Run(Codeunit::"Create Subscription Line", ImportedSubscriptionLine) then
                    Succeeded += 1
                else begin
                    Failed += 1;
                    ImportedSubscriptionLine."Error Text" := CopyStr(GetLastErrorText(), 1, MaxStrLen(ImportedSubscriptionLine."Error Text"));
                    ImportedSubscriptionLine.Modify(false);
                    Commit();
                    AddError(ErrorsArray, ErrorCount, SubscriptionLinesTok, Format(ImportedSubscriptionLine."Entry No.", 0, 9), ImportedSubscriptionLine."Error Text");
                end;
            until ImportedSubscriptionLine.Next() = 0;
        AddStageResult(StagesArray, SubscriptionLinesTok, Processed, Succeeded, Failed);
    end;

    local procedure RunContractLines(var StagesArray: JsonArray; var ErrorsArray: JsonArray; var ErrorCount: Integer)
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
    begin
        ImportedSubscriptionLine.SetRange("Sub. Contract Line created", false);
        if ImportedSubscriptionLine.FindSet() then
            repeat
                Processed += 1;
                ClearLastError();
                if Codeunit.Run(Codeunit::"Create Sub. Contract Line", ImportedSubscriptionLine) then
                    Succeeded += 1
                else begin
                    Failed += 1;
                    ImportedSubscriptionLine."Error Text" := CopyStr(GetLastErrorText(), 1, MaxStrLen(ImportedSubscriptionLine."Error Text"));
                    ImportedSubscriptionLine.Modify(false);
                    Commit();
                    AddError(ErrorsArray, ErrorCount, ContractLinesTok, Format(ImportedSubscriptionLine."Entry No.", 0, 9), ImportedSubscriptionLine."Error Text");
                end;
            until ImportedSubscriptionLine.Next() = 0;
        AddStageResult(StagesArray, ContractLinesTok, Processed, Succeeded, Failed);
    end;
}
