namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Renewal.CreateQuote</c> Cloud Event message type.
/// Builds the Sub. Contract Renewal Line rows for a Customer Subscription Contract and runs
/// Microsoft's fully public <c>Codeunit "Create Sub. Contract Renewal"</c> to turn them into a
/// sales quote. A plain Data.Records.Set cannot do this because the renewal lines have to be
/// derived, one per still-open Subscription Line, from the contract's own service commitments
/// before the quote-creating codeunit can run - and Microsoft's own interactive wrapper around
/// that codeunit (StartContractRenewalFromContract, BatchCreateContractRenewal, OpenSalesQuotes)
/// is internal and expects a user at a request page, so this codeunit bypasses it entirely.
/// </summary>
codeunit 10035052 "CE Sub Ren CrQuote Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = customer contract no.||is-IS=Viðskiptavinasamningurinn ''%1'' er ekki til.';
        NoRenewableLinesErr: Label 'The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed.', Comment = '%1 = customer contract no.||is-IS=Viðskiptavinasamningurinn ''%1'' er ekki með neinar áskriftarlínur sem hægt er að endurnýja.';
        QuoteNotCreatedErr: Label 'Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''.', Comment = '%1 = customer contract no.||is-IS=Create Sub. Contract Renewal bjó ekki til sölutilboð fyrir viðskiptavinasamninginn ''%1''.';
        DescriptionLbl: Label 'Builds contract renewal lines from a Customer Subscription Contract''s Subscription Lines and creates a renewal sales quote from them.', MaxLength = 250, Comment = 'is-IS=Býr til endurnýjunarlínur samnings út frá áskriftarlínum viðskiptavinasamnings og útbýr endurnýjunarsölutilboð út frá þeim.';

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

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Renewal.CreateQuote');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Creates a contract renewal sales quote for a Customer Subscription Contract. Any stale');
        HelpBuilder.AppendLine('renewal lines left over from an earlier run against this contract are deleted first, then');
        HelpBuilder.AppendLine('a fresh Sub. Contract Renewal Line row is built from every still-open Subscription Line');
        HelpBuilder.AppendLine('on the contract, and Microsoft''s `Codeunit "Create Sub. Contract Renewal"` turns those');
        HelpBuilder.AppendLine('rows into one sales quote. This bypasses Microsoft''s interactive renewal wrapper entirely,');
        HelpBuilder.AppendLine('so it never shows a dialog or a request page.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Customer Subscription Contract to renew. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "CC000010"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "contractNo": "CC000010",');
        HelpBuilder.AppendLine('  "renewalLinesCreated": 4,');
        HelpBuilder.AppendLine('  "salesQuoteNo": "SQ000123"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| No Subscription Line qualifies for renewal | The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed. |');
        HelpBuilder.AppendLine('| Create Sub. Contract Renewal produced no quote | Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes: it deletes and re-creates Sub. Contract Renewal Line rows for');
        HelpBuilder.AppendLine('this contract, and it creates a sales quote header and lines. It never posts anything and');
        HelpBuilder.AppendLine('never touches the contract itself. The write runs in an isolated transaction that rolls');
        HelpBuilder.AppendLine('back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Renewal.Extend`');

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

    /// <summary>Builds the renewal lines for the contract and creates the renewal sales quote.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        SubContractRenewalLine: Record "Sub. Contract Renewal Line";
        CreateSubContractRenewal: Codeunit "Create Sub. Contract Renewal";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        SalesQuoteNo: Code[20];
        RenewalLinesCreated: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);

        if not CustomerSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        SubContractRenewalLine.SetRange("Linked to Sub. Contract No.", ContractNo);
        if not SubContractRenewalLine.IsEmpty() then
            SubContractRenewalLine.DeleteAll(true);

        CustSubContractLine.SetRange("Subscription Contract No.", ContractNo);
        if CustSubContractLine.FindSet() then
            repeat
                if CustSubContractLine."Subscription Line Entry No." <> 0 then
                    if SubscriptionLine.Get(CustSubContractLine."Subscription Line Entry No.") then
                        if SubscriptionLine."Subscription Line End Date" <> 0D then begin
                            Clear(SubContractRenewalLine);
                            if SubContractRenewalLine.InitFromServiceCommitment(SubscriptionLine) then begin
                                SubContractRenewalLine.Insert(false);
                                RenewalLinesCreated += 1;
                            end;
                        end;
            until CustSubContractLine.Next() = 0;

        if RenewalLinesCreated = 0 then
            Error(NoRenewableLinesErr, ContractNo);

        SubContractRenewalLine.Reset();
        SubContractRenewalLine.SetRange("Subscription Contract No.", ContractNo);
        SubContractRenewalLine.SetRange(Partner, Enum::"Service Partner"::Customer);

        Clear(CreateSubContractRenewal);
        if not CreateSubContractRenewal.Run(SubContractRenewalLine) then
            Argument.RespondWithLastError()
        else begin
            SalesQuoteNo := CreateSubContractRenewal.GetSalesQuoteNo();
            if SalesQuoteNo = '' then
                Error(QuoteNotCreatedErr, ContractNo);

            ResponseJson.Add('status', 'Success');
            ResponseJson.Add('contractNo', ContractNo);
            ResponseJson.Add('renewalLinesCreated', RenewalLinesCreated);
            ResponseJson.Add('salesQuoteNo', SalesQuoteNo);
            Helper.RespondWithSuccess(Argument, ResponseJson);
        end;
    end;
}
