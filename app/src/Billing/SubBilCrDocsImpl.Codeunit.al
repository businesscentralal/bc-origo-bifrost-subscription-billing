namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.CreateDocuments</c> Bifrost message type.
/// Turns the unbilled proposal lines standing under a Billing Template into documents in one
/// bulk run. A plain Data.Records.Set cannot do this because creating documents from proposal
/// lines involves grouping lines onto the right header, copying amounts and dimensions, and
/// stamping each Billing Line with the document it produced - all of which is owned by
/// Microsoft's "Create Billing Documents" codeunit.
/// </summary>
codeunit 10035046 "Sub Bil CrDocs Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        MixedPartnerErr: Label 'You can create documents only for one type of partner at a time. Billing Template ''%1'' currently has both customer and vendor proposal lines pending.', Comment = '%1 = billing template code||is-IS=Aðeins er hægt að búa til skjöl fyrir eina tegund viðskiptaaðila í einu. Reikningssniðmátið ''%1'' er núna með bæði viðskiptavina- og birgjafærslur í bið.';
        InvalidGroupByErr: Label 'The parameter ''groupBy'' must be either ''Contract'' or ''Customer''.', Comment = 'is-IS=Færibreytan ''groupBy'' verður að vera annaðhvort ''Contract'' eða ''Customer''.';
        GroupByCustomerOnlyErr: Label '''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts.', Comment = 'is-IS=''groupBy'' = ''Customer'' á aðeins við þegar óloknar tillögufærslur tilheyra viðskiptavinasamningum.';
        NothingPendingMsg: Label 'There are no unbilled proposal lines for Billing Template ''%1''. Run Subscription.Billing.CreateProposal first.', Comment = '%1 = billing template code||is-IS=Það eru engar ófakturaðar tillögufærslur fyrir reikningssniðmátið ''%1''. Keyrðu Subscription.Billing.CreateProposal fyrst.';
        NotRolledBackErr: Label 'The billing run failed after Business Central had already created the documents listed in ''documents''. Business Central commits each document as it is created, so those documents still exist and were not rolled back. Review them before running this template again. Underlying error: %1', Comment = '%1 = the underlying Business Central error||is-IS=Reikningskeyrslan brast eftir að Business Central hafði þegar búið til skjölin sem talin eru upp í ''documents''. Business Central vistar hvert skjal um leið og það verður til, svo þau skjöl eru enn til og hafa ekki verið afturkölluð. Yfirfarðu þau áður en þetta sniðmát er keyrt aftur. Undirliggjandi villa: %1';
        DescriptionLbl: Label 'Turns the unbilled Billing Line rows under a Billing Template into sales or purchase documents. Reports the documents created and how many proposal lines were processed.', MaxLength = 250, Comment = 'is-IS=Umbreytir ófakturuðum reikningslínum undir reikningssniðmáti í sölu- eða innkaupaskjöl. Skilar þeim skjölum sem urðu til og fjölda tillögufærslna sem unnið var úr.';

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
        Argument.SetResponseMarkdown(BilHelp.GetHelpMarkdown('Subscription.Billing.CreateDocuments'));
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

    /// <summary>Processes the pending proposal lines into documents. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        FailureReason: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'billingTemplateCode', true);
        DocumentDate := Helper.GetDateOrDefault(RequestJson, 'documentDate', WorkDate());
        PostingDate := Helper.GetDateOrDefault(RequestJson, 'postingDate', WorkDate());
        PostDocuments := Helper.GetBoolean(RequestJson, 'postDocuments', false);
        GroupBy := Helper.GetText(RequestJson, 'groupBy', false);

        if CreateDocumentsFromProposal(BillingTemplateCode, DocumentDate, PostingDate, PostDocuments, GroupBy, BillingLinesProcessed, DocumentCount, DocumentsArray, FailureReason) then begin
            ResponseJson.Add('status', 'Success');
            ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
            ResponseJson.Add('message', StrSubstNo(NothingPendingMsg, BillingTemplateCode));
            ResponseJson.Add('billingLinesProcessed', 0);
            ResponseJson.Add('documentCount', 0);
            ResponseJson.Add('documents', DocumentsArray);
            Helper.RespondWithSuccess(Argument, ResponseJson);
            exit;
        end;

        if FailureReason <> '' then begin
            ResponseJson.Add('status', 'Error');
            ResponseJson.Add('error', StrSubstNo(NotRolledBackErr, FailureReason));
            ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
            ResponseJson.Add('billingLinesProcessed', BillingLinesProcessed);
            ResponseJson.Add('documentCount', DocumentCount);
            ResponseJson.Add('documents', DocumentsArray);
            ResponseJson.Add('rolledBack', false);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
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
    procedure CreateDocumentsFromProposal(BillingTemplateCode: Code[20]; DocumentDate: Date; PostingDate: Date; PostDocuments: Boolean; GroupBy: Text; var BillingLinesProcessed: Integer; var DocumentCount: Integer; var DocumentsArray: JsonArray; var FailureReason: Text) NothingPending: Boolean
    var
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
        CreateBillingDocuments: Codeunit "Create Billing Documents";
        DocumentJson: JsonObject;
        // Dictionaries, not lists: every one of these is asked "have I seen this already?" once per
        // Billing Line row, and a list answers that by walking everything it already holds.
        DistinctDocumentNos: Dictionary of [Code[20], Boolean];
        DistinctComboKeys: Dictionary of [Text, Boolean];
        ProcessedEntryNos: Dictionary of [Integer, Boolean];
        ArchiveWatermarkEntryNo: Integer;
        ActualPartner: Enum "Service Partner";
        HasCustomerLines: Boolean;
        HasVendorLines: Boolean;
        ComboKey: Text;
    begin
        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        BillingLinesProcessed := BillingLine.Count();
        if BillingLinesProcessed = 0 then
            exit(true);

        // Only whether there are any, never how many - so ask the question that stops at the first row.
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        HasCustomerLines := not BillingLine.IsEmpty();
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        HasVendorLines := not BillingLine.IsEmpty();
        if HasCustomerLines and HasVendorLines then
            Error(MixedPartnerErr, BillingTemplateCode);
        if HasVendorLines then
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
        // Remember which proposal rows this run is about to consume, so the response reports only
        // the documents they became. Reading every billed row under the template afterwards would
        // also name documents an earlier run produced.
        BillingLine.SetLoadFields("Entry No.");
        if BillingLine.FindSet() then
            repeat
                ProcessedEntryNos.Set(BillingLine."Entry No.", true);
            until BillingLine.Next() = 0;

        // Posting a document archives its Billing Line rows, so the rows this run consumed would
        // simply vanish from Billing Line and the response would name no documents at all. Note
        // where the archive ends too, and read the posted documents back from the rows added to it.
        BillingLineArchive.Reset();
        if BillingLineArchive.FindLast() then
            ArchiveWatermarkEntryNo := BillingLineArchive."Entry No."
        else
            ArchiveWatermarkEntryNo := 0;

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        // Run the instance configured above. Codeunit.Run(Codeunit::"Create Billing Documents", ...)
        // would start a fresh instance instead, losing SetSkipRequestPageSelection and opening the
        // interactive "Create Customer Billing Docs" request page - which fails outright in an
        // unattended session, where no client is there to answer it.
        // Microsoft's document creation commits each document as it goes, so a failure part way
        // through - a posting error on the third of five documents, say - leaves the earlier ones
        // standing. An ordinary Error() here would roll back nothing but this codeunit's own work
        // and tell the caller nothing about what survived. Catch it instead, read back what was
        // created, and report both together.
        if not CreateBillingDocuments.Run(BillingLine) then
            FailureReason := GetLastErrorText();

        BillingLine.Reset();
        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetFilter("Document Type", '<>%1', Enum::"Rec. Billing Document Type"::None);
        BillingLine.SetLoadFields("Document Type", "Document No.", "Subscription Contract No.");
        if BillingLine.FindSet() then
            repeat
                if ProcessedEntryNos.ContainsKey(BillingLine."Entry No.") then begin
                    ComboKey := Helper.FormatDocumentType(BillingLine."Document Type") + '|' + BillingLine."Document No." + '|' + BillingLine."Subscription Contract No.";
                    if not DistinctComboKeys.ContainsKey(ComboKey) then begin
                        DistinctComboKeys.Add(ComboKey, true);

                        Clear(DocumentJson);
                        DocumentJson.Add('documentType', Helper.FormatDocumentType(BillingLine."Document Type"));
                        DocumentJson.Add('documentNo', BillingLine."Document No.");
                        DocumentJson.Add('contractNo', BillingLine."Subscription Contract No.");
                        DocumentsArray.Add(DocumentJson);
                    end;
                    if not DistinctDocumentNos.ContainsKey(BillingLine."Document No.") then
                        DistinctDocumentNos.Add(BillingLine."Document No.", true);
                end;
            until BillingLine.Next() = 0;

        BillingLineArchive.Reset();
        BillingLineArchive.SetFilter("Entry No.", '>%1', ArchiveWatermarkEntryNo);
        BillingLineArchive.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLineArchive.SetLoadFields("Document Type", "Document No.", "Subscription Contract No.");
        if BillingLineArchive.FindSet() then
            repeat
                ComboKey := Helper.FormatDocumentType(BillingLineArchive."Document Type") + '|' + BillingLineArchive."Document No." + '|' + BillingLineArchive."Subscription Contract No.";
                if not DistinctComboKeys.ContainsKey(ComboKey) then begin
                    DistinctComboKeys.Add(ComboKey, true);

                    Clear(DocumentJson);
                    DocumentJson.Add('documentType', Helper.FormatDocumentType(BillingLineArchive."Document Type"));
                    DocumentJson.Add('documentNo', BillingLineArchive."Document No.");
                    DocumentJson.Add('contractNo', BillingLineArchive."Subscription Contract No.");
                    DocumentJson.Add('posted', true);
                    DocumentsArray.Add(DocumentJson);
                end;
                if not DistinctDocumentNos.ContainsKey(BillingLineArchive."Document No.") then
                    DistinctDocumentNos.Add(BillingLineArchive."Document No.", true);
            until BillingLineArchive.Next() = 0;

        DocumentCount := DistinctDocumentNos.Count();
        exit(false);
    end;
}
