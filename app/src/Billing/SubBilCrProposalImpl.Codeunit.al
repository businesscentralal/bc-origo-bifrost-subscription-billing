namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.CreateProposal</c> Bifrost message type.
/// Runs Microsoft's "Create Billing Proposal" over a Billing Template for a billing date
/// and an optional billing-to date, filling the Billing Line table with proposal lines.
/// A plain Data.Records.Set cannot do this because the proposal is produced by a codeunit
/// that walks every due Subscription Line and derives the periods to bill.
/// </summary>
codeunit 10035045 "Sub Bil CrProposal Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        DescriptionLbl: Label 'Creates billing proposal lines for a Billing Template and a billing date. Returns the number of proposal lines created and the contracts they cover.', MaxLength = 250, Comment = 'is-IS=Býr til reikningstillögulínur fyrir reikningssniðmát og greiðsludagsetningu. Skilar fjölda tillögulína sem urðu til og þeim samningum sem þær ná yfir.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Template");
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
        BilHelp: Codeunit "Sub Bil Help ori";
    begin
        Argument.SetResponseMarkdown(BilHelp.GetHelpMarkdown('Subscription.Billing.CreateProposal'));
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

    /// <summary>Runs the billing proposal. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
