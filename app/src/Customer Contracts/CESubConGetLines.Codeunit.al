namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Contract.GetLines</c> Cloud Event message type.
/// Attaches unassigned Subscription Lines to a customer Subscription Contract, reproducing the
/// selection Microsoft's own "Get Subscription Lines" action applies on the contract page.
/// A plain Data.Records.Set cannot do this because attaching a line also inserts and numbers a
/// Cust. Sub. Contract Line and stamps the Subscription Line back with the contract it now belongs to.
/// </summary>
codeunit 10035037 "CE Sub Con GetLines Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract no.||is-IS=Áskriftarsamningur viðskiptavinar ''%1'' er ekki til.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a customer Subscription Contract. Returns the lines attached and any skipped.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við áskriftarsamning viðskiptavinar. Skilar tengdum línum og línum sem var sleppt.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Customer Subscription Contract");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Contract.GetLines');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Attaches Subscription Lines that are not yet on any contract to a customer Subscription');
        HelpBuilder.AppendLine('Contract. The candidate lines are exactly the ones Microsoft''s own "Get Subscription Lines"');
        HelpBuilder.AppendLine('action on the contract page would offer: invoiced via contract, not yet on a contract,');
        HelpBuilder.AppendLine('owned by a customer, and not already fully expired.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Customer Subscription Contract to attach lines to. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | No | Restricts the candidates to lines on one Subscription. |');
        HelpBuilder.AppendLine('| subscriptionLineEntryNos | Integer[] | No | Restricts the candidates to these Subscription Line entry numbers. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "CC000010",');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SUB000010"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "contractNo": "CC000010",');
        HelpBuilder.AppendLine('  "linesAttached": 2,');
        HelpBuilder.AppendLine('  "attachedLines": [');
        HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 1001, "contractLineNo": 10000 },');
        HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 1002, "contractLineNo": 20000 }');
        HelpBuilder.AppendLine('  ],');
        HelpBuilder.AppendLine('  "linesSkipped": 1');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('A candidate line is skipped, rather than causing an error, when its Subscription''s');
        HelpBuilder.AppendLine('End-User Customer No. does not match the contract''s Sell-to Customer No. `linesSkipped`');
        HelpBuilder.AppendLine('counts these. A run that matches no candidates at all is still a success, with');
        HelpBuilder.AppendLine('`linesAttached` of 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. It only attaches existing Subscription Lines to the contract -');
        HelpBuilder.AppendLine('no Subscription Line is created and nothing is billed. The write runs in an isolated');
        HelpBuilder.AppendLine('transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Line.Create`');
        HelpBuilder.AppendLine('- `Subscription.Contract.CreateInvoice`');

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

    /// <summary>Attaches the candidate Subscription Lines to the contract. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        SubscriptionHeader: Record "Subscription Header";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AttachedLinesArray: JsonArray;
        AttachedLineJson: JsonObject;
        EntryNoJToken: JsonToken;
        EntryNoArrayJToken: JsonToken;
        EntryNoJsonArray: JsonArray;
        EntryNoFilter: Text;
        ContractNo: Code[20];
        SubscriptionHeaderNo: Code[20];
        LinesAttached: Integer;
        LinesSkipped: Integer;
        Index: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);
        SubscriptionHeaderNo := Helper.GetCode20(RequestJson, 'subscriptionHeaderNo', false);

        if not CustomerSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        SubscriptionLine.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        SubscriptionLine.SetRange("Subscription Contract No.", '');
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        SubscriptionLine.SetFilter("Subscription Line End Date", '>%1|%2', WorkDate(), 0D);

        if SubscriptionHeaderNo <> '' then
            SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);

        if RequestJson.Get('subscriptionLineEntryNos', EntryNoArrayJToken) then
            if EntryNoArrayJToken.IsArray() then begin
                EntryNoJsonArray := EntryNoArrayJToken.AsArray();
                for Index := 0 to EntryNoJsonArray.Count() - 1 do begin
                    EntryNoJsonArray.Get(Index, EntryNoJToken);
                    if EntryNoFilter <> '' then
                        EntryNoFilter += '|';
                    EntryNoFilter += Format(EntryNoJToken.AsValue().AsInteger(), 0, 9);
                end;
                if EntryNoFilter <> '' then
                    SubscriptionLine.SetFilter("Entry No.", EntryNoFilter);
            end;

        if SubscriptionLine.FindSet() then
            repeat
                if not SubscriptionHeader.Get(SubscriptionLine."Subscription Header No.") then
                    LinesSkipped += 1
                else
                    if SubscriptionHeader."End-User Customer No." <> CustomerSubscriptionContract."Sell-to Customer No." then
                        LinesSkipped += 1
                    else begin
                        Clear(CustSubContractLine);
                        CustomerSubscriptionContract.CreateCustomerContractLineFromServiceCommitment(SubscriptionLine, ContractNo, CustSubContractLine);
                        LinesAttached += 1;
                        Clear(AttachedLineJson);
                        AttachedLineJson.Add('subscriptionLineEntryNo', SubscriptionLine."Entry No.");
                        AttachedLineJson.Add('contractLineNo', CustSubContractLine."Line No.");
                        AttachedLinesArray.Add(AttachedLineJson);
                    end;
            until SubscriptionLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('linesAttached', LinesAttached);
        ResponseJson.Add('attachedLines', AttachedLinesArray);
        ResponseJson.Add('linesSkipped', LinesSkipped);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
