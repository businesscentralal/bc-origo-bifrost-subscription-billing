namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Billing.PreviewDocuments</c> Cloud Event message type.
/// Shows what <c>Subscription.Billing.CreateDocuments</c> would produce for a Billing Template's
/// unbilled proposal lines by reading the existing Billing Line rows and reporting how they
/// would be grouped into documents. Unlike the invoice previews, this message type never writes
/// anything at all - it only reads the proposal lines the caller already created with
/// <c>Subscription.Billing.CreateProposal</c>, so there is nothing to build and nothing to
/// clean up afterwards.
/// </summary>
codeunit 10035047 "CE Sub Bil PrvDocs Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        InvalidGroupByErr: Label 'The parameter ''groupBy'' must be either ''Contract'' or ''Customer''.', Comment = 'is-IS=Færibreytan ''groupBy'' verður að vera annaðhvort ''Contract'' eða ''Customer''.';
        GroupByCustomerOnlyErr: Label '''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts.', Comment = 'is-IS=''groupBy'' = ''Customer'' á aðeins við þegar óloknar tillögufærslur tilheyra viðskiptavinasamningum.';
        NothingPendingMsg: Label 'There are no unbilled proposal lines for Billing Template ''%1''. Run Subscription.Billing.CreateProposal first.', Comment = '%1 = billing template code||is-IS=Það eru engar ófakturaðar tillögufærslur fyrir reikningssniðmátið ''%1''. Keyrðu Subscription.Billing.CreateProposal fyrst.';
        MixedPartnerMsg: Label 'Billing Template ''%1'' currently has both customer and vendor proposal lines pending. A real run refuses to create documents for a mix of partner types until this is resolved.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er núna með bæði viðskiptavina- og birgjafærslur í bið. Raunveruleg keyrsla neitar að búa til skjöl fyrir blöndu af tegundum viðskiptaaðila þar til úr því er leyst.';
        UpdateRequiredMsg: Label '%1 of the pending proposal line(s) are flagged ''Update Required'' and would need to be refreshed before a real run could process them.', Comment = '%1 = row count||is-IS=%1 af óloknum tillögufærslum eru merktar ''Uppfærslu krafist'' og þyrfti að endurnýja áður en raunveruleg keyrsla gæti unnið úr þeim.';
        DescriptionLbl: Label 'Previews the documents that Subscription.Billing.CreateDocuments would create for a Billing Template, by reading the existing proposal lines. Reads only; writes nothing.', MaxLength = 250, Comment = 'is-IS=Forskoðar þau skjöl sem Subscription.Billing.CreateDocuments myndi búa til fyrir reikningssniðmát, með því að lesa fyrirliggjandi tillögulínur. Les eingöngu; skrifar ekkert.';

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
        HelpBuilder.AppendLine('# Subscription.Billing.PreviewDocuments');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Shows what `Subscription.Billing.CreateDocuments` would produce for a Billing Template''s');
        HelpBuilder.AppendLine('unbilled proposal lines (Document Type = None), by reading those Billing Line rows and');
        HelpBuilder.AppendLine('grouping them the same way a real run would - one entry per document that would be');
        HelpBuilder.AppendLine('created, grouped per contract by default. Nothing is created, and nothing is written at');
        HelpBuilder.AppendLine('all. Run `Subscription.Billing.CreateProposal` first to populate the proposal lines this');
        HelpBuilder.AppendLine('call reads.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| billingTemplateCode | Code[20] | Yes | The Billing Template to preview. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| groupBy | Text | No | ''Contract'' (default) groups one document per contract. ''Customer'' groups one document per Partner No. and only applies when every pending line belongs to a customer contract. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('There are no `documentDate`, `postingDate` or `postDocuments` parameters - a preview never');
        HelpBuilder.AppendLine('creates or posts anything, so no document data applies.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY",');
        HelpBuilder.AppendLine('  "billingLineCount": 12,');
        HelpBuilder.AppendLine('  "documentCount": 5,');
        HelpBuilder.AppendLine('  "documents": [');
        HelpBuilder.AppendLine('    { "contractNo": "CC000010", "partnerNo": "10000", "lineCount": 3, "totalAmount": "297.00" }');
        HelpBuilder.AppendLine('  ],');
        HelpBuilder.AppendLine('  "warnings": [],');
        HelpBuilder.AppendLine('  "preview": true,');
        HelpBuilder.AppendLine('  "rollback": true');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`contractNo` is left blank on an entry when `groupBy` is `Customer`, because one document');
        HelpBuilder.AppendLine('created that way can span several contracts for the same Partner No. A run with no unbilled');
        HelpBuilder.AppendLine('proposal lines is a success with `documents: []`, `documentCount` of 0, and a `message`;');
        HelpBuilder.AppendLine('`preview` and `rollback` are still `true`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The template does not exist | The Billing Template ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| billingTemplateCode is missing | The request is missing the required parameter ''billingTemplateCode''. |');
        HelpBuilder.AppendLine('| groupBy is not Contract or Customer | The parameter ''groupBy'' must be either ''Contract'' or ''Customer''. |');
        HelpBuilder.AppendLine('| groupBy = Customer but a vendor line is pending | ''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }`. A mix of customer');
        HelpBuilder.AppendLine('and vendor proposal lines is not an error here - `Subscription.Billing.CreateDocuments`');
        HelpBuilder.AppendLine('would refuse to run, and this call reports that as a `warnings` entry instead, alongside');
        HelpBuilder.AppendLine('the grouping it can still show.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type only reads. It does not call `Subscription.Billing.CreateDocuments` or any');
        HelpBuilder.AppendLine('other codeunit that writes, so there is no billing proposal to build, no document to create');
        HelpBuilder.AppendLine('even temporarily, and nothing to clean up afterwards - unlike the invoice previews, which');
        HelpBuilder.AppendLine('have to build and then remove real proposal lines because that is the only way to preview');
        HelpBuilder.AppendLine('them. `preview` and `rollback` are always `true` in the response because, quite simply,');
        HelpBuilder.AppendLine('nothing was ever written for either of them to undo.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Billing.CreateDocuments`');
        HelpBuilder.AppendLine('- `Subscription.Billing.CreateProposal`');

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

    /// <summary>Reads the pending proposal lines and reports how they would be grouped into documents. Never writes.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        BillingTemplateCode: Code[20];
        GroupBy: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'billingTemplateCode', true);
        GroupBy := Helper.GetText(RequestJson, 'groupBy', false);

        PreviewDocuments(BillingTemplateCode, GroupBy, ResponseJson);

        ResponseJson.Add('preview', true);
        ResponseJson.Add('rollback', true);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>Reads the Billing Template's unbilled proposal lines and fills ResponseJson with the grouping and warnings a real run would produce.</summary>
    local procedure PreviewDocuments(BillingTemplateCode: Code[20]; GroupBy: Text; var ResponseJson: JsonObject)
    var
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        DocumentsArray: JsonArray;
        WarningsArray: JsonArray;
        BillingLineCount: Integer;
        CustomerLineCount: Integer;
        VendorLineCount: Integer;
        UpdateRequiredCount: Integer;
        GroupByCustomer: Boolean;
    begin
        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        BillingLineCount := BillingLine.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);

        if BillingLineCount = 0 then begin
            ResponseJson.Add('message', StrSubstNo(NothingPendingMsg, BillingTemplateCode));
            ResponseJson.Add('billingLineCount', 0);
            ResponseJson.Add('documentCount', 0);
            ResponseJson.Add('documents', DocumentsArray);
            ResponseJson.Add('warnings', WarningsArray);
            exit;
        end;

        BillingLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        CustomerLineCount := BillingLine.Count();
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        VendorLineCount := BillingLine.Count();
        BillingLine.SetRange(Partner);

        BillingLine.SetRange("Update Required", true);
        UpdateRequiredCount := BillingLine.Count();
        BillingLine.SetRange("Update Required");

        case UpperCase(GroupBy) of
            '', 'CONTRACT':
                GroupByCustomer := false;
            'CUSTOMER':
                begin
                    if VendorLineCount > 0 then
                        Error(GroupByCustomerOnlyErr);
                    GroupByCustomer := true;
                end;
            else
                Error(InvalidGroupByErr);
        end;

        BuildDocumentsPreview(BillingLine, GroupByCustomer, DocumentsArray);
        BuildWarnings(BillingTemplateCode, CustomerLineCount, VendorLineCount, UpdateRequiredCount, WarningsArray);

        ResponseJson.Add('billingLineCount', BillingLineCount);
        ResponseJson.Add('documentCount', DocumentsArray.Count());
        ResponseJson.Add('documents', DocumentsArray);
        ResponseJson.Add('warnings', WarningsArray);
    end;

    /// <summary>
    /// Groups the filtered Billing Line rows the way a real run would - per Subscription Contract
    /// No. by default, or per Partner No. when GroupByCustomer is set - and emits one document
    /// entry per group. contractNo is left blank on a per-customer entry because that grouping can
    /// span several contracts under the same Partner No.
    /// </summary>
    local procedure BuildDocumentsPreview(var BillingLine: Record "Billing Line"; GroupByCustomer: Boolean; var DocumentsArray: JsonArray)
    var
        GroupBillingLine: Record "Billing Line";
        DocumentJson: JsonObject;
        GroupKeys: List of [Code[20]];
        GroupKey: Code[20];
        PartnerNo: Code[20];
        ContractNo: Code[20];
        LineCount: Integer;
        TotalAmount: Decimal;
    begin
        if BillingLine.FindSet() then
            repeat
                if GroupByCustomer then
                    GroupKey := BillingLine."Partner No."
                else
                    GroupKey := BillingLine."Subscription Contract No.";
                if not GroupKeys.Contains(GroupKey) then
                    GroupKeys.Add(GroupKey);
            until BillingLine.Next() = 0;

        foreach GroupKey in GroupKeys do begin
            GroupBillingLine.CopyFilters(BillingLine);
            if GroupByCustomer then
                GroupBillingLine.SetRange("Partner No.", GroupKey)
            else
                GroupBillingLine.SetRange("Subscription Contract No.", GroupKey);

            LineCount := GroupBillingLine.Count();
            TotalAmount := 0;
            PartnerNo := '';
            ContractNo := '';

            if GroupBillingLine.FindSet() then
                repeat
                    TotalAmount += GroupBillingLine.Amount;
                    if PartnerNo = '' then
                        PartnerNo := GroupBillingLine."Partner No.";
                    if not GroupByCustomer then
                        ContractNo := GroupBillingLine."Subscription Contract No.";
                until GroupBillingLine.Next() = 0;

            Clear(DocumentJson);
            DocumentJson.Add('contractNo', ContractNo);
            DocumentJson.Add('partnerNo', PartnerNo);
            DocumentJson.Add('lineCount', LineCount);
            DocumentJson.Add('totalAmount', Helper.FormatDecimal(TotalAmount));
            DocumentsArray.Add(DocumentJson);
        end;
    end;

    /// <summary>Reports the conditions that would block or complicate a real Subscription.Billing.CreateDocuments run.</summary>
    local procedure BuildWarnings(BillingTemplateCode: Code[20]; CustomerLineCount: Integer; VendorLineCount: Integer; UpdateRequiredCount: Integer; var WarningsArray: JsonArray)
    var
        WarningJson: JsonObject;
    begin
        if (CustomerLineCount > 0) and (VendorLineCount > 0) then begin
            Clear(WarningJson);
            WarningJson.Add('code', 'MixedPartners');
            WarningJson.Add('message', StrSubstNo(MixedPartnerMsg, BillingTemplateCode));
            WarningJson.Add('customerLineCount', CustomerLineCount);
            WarningJson.Add('vendorLineCount', VendorLineCount);
            WarningsArray.Add(WarningJson);
        end;

        if UpdateRequiredCount > 0 then begin
            Clear(WarningJson);
            WarningJson.Add('code', 'UpdateRequired');
            WarningJson.Add('message', StrSubstNo(UpdateRequiredMsg, UpdateRequiredCount));
            WarningJson.Add('lineCount', UpdateRequiredCount);
            WarningsArray.Add(WarningJson);
        end;
    end;
}
