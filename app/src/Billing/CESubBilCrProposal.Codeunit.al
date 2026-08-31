namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Billing.CreateProposal</c> Cloud Event message type.
/// Runs Microsoft's "Create Billing Proposal" over a Billing Template for a billing date
/// and an optional billing-to date, filling the Billing Line table with proposal lines.
/// A plain Data.Records.Set cannot do this because the proposal is produced by a codeunit
/// that walks every due Subscription Line and derives the periods to bill.
/// </summary>
codeunit 10035045 "CE Sub Bil CrProposal Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        DescriptionLbl: Label 'Creates billing proposal lines for a Billing Template and a billing date. Returns the number of proposal lines created and the contracts they cover.', MaxLength = 250, Comment = 'is-IS=Býr til reikningstillögulínur fyrir reikningssniðmát og greiðsludagsetningu. Skilar fjölda tillögulína sem urðu til og þeim samningum sem þær ná yfir.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Template");
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
        HelpBuilder.AppendLine('# Subscription.Billing.CreateProposal');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Generates billing proposal lines (Billing Line, table 8061) for a Billing Template.');
        HelpBuilder.AppendLine('Every Subscription Line whose next billing date falls on or before the billing date and');
        HelpBuilder.AppendLine('that matches the template''s own filter is proposed for billing. Nothing is invoiced yet -');
        HelpBuilder.AppendLine('call `Subscription.Billing.CreateDocuments` afterwards to turn the proposal into documents.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| billingTemplateCode | Code[20] | Yes | The Billing Template to run. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| billingDate | Date | No | Lines due on or before this date are proposed. Defaults to the work date. |');
        HelpBuilder.AppendLine('| billingToDate | Date | No | Bills complete periods up to this date. Omit to use each line''s own billing rhythm. |');
        HelpBuilder.AppendLine('| automatedBilling | Boolean | No | Defaults to true, which keeps the run silent. Leave it at the default. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "billingToDate": "2026-09-30"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "billingToDate": "2026-09-30",');
        HelpBuilder.AppendLine('  "proposalLinesCreated": 12,');
        HelpBuilder.AppendLine('  "proposalLineCount": 12,');
        HelpBuilder.AppendLine('  "contracts": ["CC000010", "CC000011"]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`proposalLinesCreated` counts the lines this call added. `proposalLineCount` is the total');
        HelpBuilder.AppendLine('number of proposal lines now standing for the template, including any created earlier.');
        HelpBuilder.AppendLine('A run that matches nothing is a success with `proposalLinesCreated` of 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The template does not exist | The Billing Template ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| billingTemplateCode is missing | The request is missing the required parameter ''billingTemplateCode''. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. It only creates proposal lines - no invoice is created and');
        HelpBuilder.AppendLine('nothing is posted. The write runs in an isolated transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Billing.CreateDocuments`');
        HelpBuilder.AppendLine('- `Subscription.Billing.PreviewDocuments`');
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

    /// <summary>Runs the billing proposal. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        BillingLine: Record "Billing Line";
        BillingTemplate: Record "Billing Template";
        BillingProposal: Codeunit "Billing Proposal";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractsArray: JsonArray;
        ContractNos: List of [Code[20]];
        ContractNo: Code[20];
        BillingTemplateCode: Code[20];
        BillingDate: Date;
        BillingToDate: Date;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'billingTemplateCode', true);
        BillingDate := Helper.GetDateOrDefault(RequestJson, 'billingDate', WorkDate());
        BillingToDate := Helper.GetDate(RequestJson, 'billingToDate', false);

        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        LinesBefore := BillingLine.Count();

        BillingProposal.CreateBillingProposal(BillingTemplateCode, BillingDate, BillingToDate, Helper.GetBoolean(RequestJson, 'automatedBilling', true));

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        LinesAfter := BillingLine.Count();

        BillingLine.SetLoadFields("Subscription Contract No.");
        if BillingLine.FindSet() then
            repeat
                if not ContractNos.Contains(BillingLine."Subscription Contract No.") then
                    if BillingLine."Subscription Contract No." <> '' then
                        ContractNos.Add(BillingLine."Subscription Contract No.");
            until BillingLine.Next() = 0;
        foreach ContractNo in ContractNos do
            ContractsArray.Add(ContractNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        ResponseJson.Add('billingDate', Helper.FormatDate(BillingDate));
        ResponseJson.Add('billingToDate', Helper.FormatDate(BillingToDate));
        ResponseJson.Add('proposalLinesCreated', LinesAfter - LinesBefore);
        ResponseJson.Add('proposalLineCount', LinesAfter);
        ResponseJson.Add('contracts', ContractsArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
