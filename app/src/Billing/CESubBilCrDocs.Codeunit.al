namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Billing.CreateDocuments</c> Cloud Event message type.
/// Turns the unbilled proposal lines standing under a Billing Template into documents in one
/// bulk run. A plain Data.Records.Set cannot do this because creating documents from proposal
/// lines involves grouping lines onto the right header, copying amounts and dimensions, and
/// stamping each Billing Line with the document it produced - all of which is owned by
/// Microsoft's "Create Billing Documents" codeunit.
/// </summary>
codeunit 10035046 "CE Sub Bil CrDocs Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        MixedPartnerErr: Label 'You can create documents only for one type of partner at a time. Billing Template ''%1'' currently has both customer and vendor proposal lines pending.', Comment = '%1 = billing template code||is-IS=Aðeins er hægt að búa til skjöl fyrir eina tegund viðskiptaaðila í einu. Reikningssniðmátið ''%1'' er núna með bæði viðskiptavina- og birgjafærslur í bið.';
        InvalidGroupByErr: Label 'The parameter ''groupBy'' must be either ''Contract'' or ''Customer''.', Comment = 'is-IS=Færibreytan ''groupBy'' verður að vera annaðhvort ''Contract'' eða ''Customer''.';
        GroupByCustomerOnlyErr: Label '''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts.', Comment = 'is-IS=''groupBy'' = ''Customer'' á aðeins við þegar óloknar tillögufærslur tilheyra viðskiptavinasamningum.';
        NothingPendingMsg: Label 'There are no unbilled proposal lines for Billing Template ''%1''. Run Subscription.Billing.CreateProposal first.', Comment = '%1 = billing template code||is-IS=Það eru engar ófakturaðar tillögufærslur fyrir reikningssniðmátið ''%1''. Keyrðu Subscription.Billing.CreateProposal fyrst.';
        DescriptionLbl: Label 'Turns the unbilled Billing Line rows under a Billing Template into sales or purchase documents. Reports the documents created and how many proposal lines were processed.', MaxLength = 250, Comment = 'is-IS=Umbreytir ófakturuðum reikningslínum undir reikningssniðmáti í sölu- eða innkaupaskjöl. Skilar þeim skjölum sem urðu til og fjölda tillögufærslna sem unnið var úr.';

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
        HelpBuilder.AppendLine('# Subscription.Billing.CreateDocuments');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Processes every unbilled Billing Line (Document Type = None) standing under a Billing Template');
        HelpBuilder.AppendLine('and turns them into sales or purchase documents, grouped per contract by default. Run');
        HelpBuilder.AppendLine('`Subscription.Billing.CreateProposal` first to populate the proposal lines this call consumes.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| billingTemplateCode | Code[20] | Yes | The Billing Template whose unbilled proposal lines are processed. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| documentDate | Date | No | Document date stamped on the created documents. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postingDate | Date | No | Posting date stamped on the created documents. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postDocuments | Boolean | No | Defaults to false. When true, customer documents are posted immediately - vendor documents are never auto-posted regardless of this flag. |');
        HelpBuilder.AppendLine('| groupBy | Text | No | ''Contract'' (default) groups one document per contract. ''Customer'' groups one document per Bill-to Customer and only applies to customer proposal lines. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY",');
        HelpBuilder.AppendLine('  "postDocuments": false');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "billingTemplateCode": "MONTHLY",');
        HelpBuilder.AppendLine('  "billingLinesProcessed": 12,');
        HelpBuilder.AppendLine('  "documentCount": 5,');
        HelpBuilder.AppendLine('  "documents": [');
        HelpBuilder.AppendLine('    { "documentType": "Invoice", "documentNo": "INV-000123", "contractNo": "CC000010" }');
        HelpBuilder.AppendLine('  ]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('When `postDocuments` was explicitly true, the response also carries `"posted": true`. A run with');
        HelpBuilder.AppendLine('no unbilled proposal lines is a success with `documents: []`, `documentCount` of 0, and a `message`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The template does not exist | The Billing Template ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| billingTemplateCode is missing | The request is missing the required parameter ''billingTemplateCode''. |');
        HelpBuilder.AppendLine('| Proposal lines mix customer and vendor rows | You can create documents only for one type of partner at a time. |');
        HelpBuilder.AppendLine('| groupBy is not Contract or Customer | The parameter ''groupBy'' must be either ''Contract'' or ''Customer''. |');
        HelpBuilder.AppendLine('| groupBy = Customer on vendor lines | ''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes, and can post when `postDocuments` is explicitly set to true for customer');
        HelpBuilder.AppendLine('documents. It always refuses to mix customer and vendor proposal lines in one run. The write runs');
        HelpBuilder.AppendLine('in an isolated transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Billing.CreateProposal`');
        HelpBuilder.AppendLine('- `Subscription.Billing.PreviewDocuments`');

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

    /// <summary>Processes the pending proposal lines into documents. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentsArray: JsonArray;
        BillingLinesProcessed: Integer;
        DocumentCount: Integer;
        BillingTemplateCode: Code[20];
        DocumentDate: Date;
        PostingDate: Date;
        PostDocuments: Boolean;
        GroupBy: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'billingTemplateCode', true);
        DocumentDate := Helper.GetDateOrDefault(RequestJson, 'documentDate', WorkDate());
        PostingDate := Helper.GetDateOrDefault(RequestJson, 'postingDate', WorkDate());
        PostDocuments := Helper.GetBoolean(RequestJson, 'postDocuments', false);
        GroupBy := Helper.GetText(RequestJson, 'groupBy', false);

        if CreateDocumentsFromProposal(BillingTemplateCode, DocumentDate, PostingDate, PostDocuments, GroupBy, BillingLinesProcessed, DocumentCount, DocumentsArray) then begin
            ResponseJson.Add('status', 'Success');
            ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
            ResponseJson.Add('message', StrSubstNo(NothingPendingMsg, BillingTemplateCode));
            ResponseJson.Add('billingLinesProcessed', 0);
            ResponseJson.Add('documentCount', 0);
            ResponseJson.Add('documents', DocumentsArray);
            Helper.RespondWithSuccess(Argument, ResponseJson);
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        ResponseJson.Add('billingLinesProcessed', BillingLinesProcessed);
        ResponseJson.Add('documentCount', DocumentCount);
        ResponseJson.Add('documents', DocumentsArray);
        if PostDocuments then
            ResponseJson.Add('posted', true);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Shared implementation for the write and preview paths. Returns true when there was nothing
    /// pending to process (BillingLinesProcessed and DocumentCount are then left at 0).
    /// </summary>
    internal procedure CreateDocumentsFromProposal(BillingTemplateCode: Code[20]; DocumentDate: Date; PostingDate: Date; PostDocuments: Boolean; GroupBy: Text; var BillingLinesProcessed: Integer; var DocumentCount: Integer; var DocumentsArray: JsonArray) NothingPending: Boolean
    var
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        CreateBillingDocuments: Codeunit "Create Billing Documents";
        DocumentJson: JsonObject;
        DistinctDocumentNos: List of [Code[20]];
        DistinctComboKeys: List of [Text];
        ActualPartner: Enum "Service Partner";
        CustomerLineCount: Integer;
        VendorLineCount: Integer;
        ComboKey: Text;
    begin
        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        BillingLinesProcessed := BillingLine.Count();
        if BillingLinesProcessed = 0 then
            exit(true);

        BillingLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        CustomerLineCount := BillingLine.Count();
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        VendorLineCount := BillingLine.Count();
        if (CustomerLineCount > 0) and (VendorLineCount > 0) then
            Error(MixedPartnerErr, BillingTemplateCode);
        if VendorLineCount > 0 then
            ActualPartner := Enum::"Service Partner"::Vendor
        else
            ActualPartner := Enum::"Service Partner"::Customer;

        case UpperCase(GroupBy) of
            '', 'CONTRACT':
                CreateBillingDocuments.SetBillingGroupingPerContract(ActualPartner);
            'CUSTOMER':
                begin
                    if ActualPartner <> Enum::"Service Partner"::Customer then
                        Error(GroupByCustomerOnlyErr);
                    CreateBillingDocuments.SetCustomerRecurringBillingGrouping(Enum::"Customer Rec. Billing Grouping"::"Bill-to Customer No.");
                end;
            else
                Error(InvalidGroupByErr);
        end;

        CreateBillingDocuments.SetDocumentDataFromRequestPage(DocumentDate, PostingDate, PostDocuments, false);
        CreateBillingDocuments.SetSkipRequestPageSelection(true);

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        Codeunit.Run(Codeunit::"Create Billing Documents", BillingLine);

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetFilter("Document Type", '<>%1', Enum::"Rec. Billing Document Type"::None);
        BillingLine.SetLoadFields("Document Type", "Document No.", "Subscription Contract No.");
        if BillingLine.FindSet() then
            repeat
                ComboKey := Format(BillingLine."Document Type") + '|' + BillingLine."Document No." + '|' + BillingLine."Subscription Contract No.";
                if not DistinctComboKeys.Contains(ComboKey) then begin
                    DistinctComboKeys.Add(ComboKey);

                    Clear(DocumentJson);
                    DocumentJson.Add('documentType', Format(BillingLine."Document Type"));
                    DocumentJson.Add('documentNo', BillingLine."Document No.");
                    DocumentJson.Add('contractNo', BillingLine."Subscription Contract No.");
                    DocumentsArray.Add(DocumentJson);
                end;
                if not DistinctDocumentNos.Contains(BillingLine."Document No.") then
                    DistinctDocumentNos.Add(BillingLine."Document No.");
            until BillingLine.Next() = 0;

        DocumentCount := DistinctDocumentNos.Count();
        exit(false);
    end;
}
