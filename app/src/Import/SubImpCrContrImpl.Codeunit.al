namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Import.CreateContracts</c> Bifrost message type.
/// Builds real Subscription Header, Customer Subscription Contract, Subscription Line and
/// Cust. Sub. Contract Line records from staged import rows, by running Microsoft's four
/// TableNo-bound creation codeunits one staging row at a time. A plain Data.Records.Set cannot
/// do this because each stage derives and cross-links keys (contract numbers, line entry
/// numbers) that only Microsoft's own codeunits know how to compute.
/// </summary>
codeunit 10035057 "Sub Imp CrContr Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        UnknownStageErr: Label '''%1'' is not a known import stage. Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines.', Comment = '%1 = stage name||is-IS=''%1'' er ekki þekkt innflutningsskref. Notaðu SubscriptionHeaders, CustomerContracts, SubscriptionLines eða ContractLines.';
        MaxErrorsCappedMsg: Label 'Only the first %1 errors are listed; more rows may have failed.', Comment = '%1 = maximum error count||is-IS=Aðeins fyrstu %1 villurnar eru sýndar; fleiri línur gætu hafa mistekist.';
        SubscriptionHeadersTok: Label 'SubscriptionHeaders', Locked = true;
        CustomerContractsTok: Label 'CustomerContracts', Locked = true;
        SubscriptionLinesTok: Label 'SubscriptionLines', Locked = true;
        ContractLinesTok: Label 'ContractLines', Locked = true;
        MaxErrorCount: Integer;
        DescriptionLbl: Label 'Creates Subscription Headers, Customer Subscription Contracts, Subscription Lines and Cust. Sub. Contract Lines from staged import rows, one stage at a time.', MaxLength = 250, Comment = 'is-IS=Býr til áskriftarhausa, áskriftarsamninga viðskiptavina, áskriftarlínur og samningslínur áskriftarsamnings viðskiptavinar út frá innfluttum bráðabirgðalínum, eitt skref í einu.';

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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        ImpHelp: Codeunit "Sub Imp Help ori";
    begin
        Argument.SetResponseMarkdown(ImpHelp.GetHelpMarkdown('Subscription.Import.CreateContracts'));
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

    /// <summary>Runs the requested import stages over the staged rows. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
