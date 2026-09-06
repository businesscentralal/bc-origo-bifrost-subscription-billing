namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.Purchases.Document;
using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.VendorContract.CreateInvoice</c> Cloud Event message type.
/// Creates the vendor billing document (an unposted purchase invoice or credit memo) for the
/// due Subscription Lines of one vendor subscription contract.
/// A plain Data.Records.Set cannot do this because turning due lines into a purchase document
/// is a multi-step process owned by Microsoft's billing codeunits: an ad-hoc billing proposal
/// has to be built from the exact set of due lines, and only then can the document be created
/// from it - there is no single field to set that produces a purchase invoice.
/// </summary>
codeunit 10035043 "CE Sub Vend CrInvoice Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        ContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Birgjaáskriftarsamningurinn ''%1'' er ekki til.';
        ForeignPendingProposalErr: Label 'There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before creating an invoice for ''%3''.', Comment = '%1 = row count, %2 = the other contract number, %3 = this contract number||is-IS=Það eru %1 ólokin(ar) færsla(ur) í reikningstillögu fyrir annan áskriftarsamning (''%2''). Hreinsaðu eða vinndu úr þeirri tillögu áður en reikningur er búinn til fyrir ''%3''.';
        NothingDueMsg: Label 'No Subscription Lines were due for billing on or before %1 for contract %2.', Comment = '%1 = billing date, %2 = contract no.||is-IS=Engar áskriftarlínur voru gjaldfallnar til reikningsgerðar á eða fyrir %1 fyrir samning %2.';
        NothingNewMsg: Label 'Nothing new could be billed for contract %1. Its due Subscription Lines already sit on a billing proposal or on an unposted document - post or clear those first.', Comment = '%1 = contract number||is-IS=Ekkert nýtt var hægt að reikningsfæra fyrir samning %1. Áskriftarlínur hans eru þegar á reikningstillögu eða á óbókfærðu skjali - bókfaðu þær eða hreinsaðu þær fyrst.';
        DescriptionLbl: Label 'Creates an unposted purchase invoice or credit memo for the due Subscription Lines of a vendor subscription contract. Never posts the document.', MaxLength = 250, Comment = 'is-IS=Býr til óbókfærðan innkaupareikning eða kreditreikning fyrir gjaldfallnar áskriftarlínur birgjaáskriftarsamnings. Skjalið er aldrei bókfært.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Vendor Subscription Contract");
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
        HelpBuilder.AppendLine('# Subscription.VendorContract.CreateInvoice');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Bills the due Subscription Lines of one Vendor Subscription Contract. The lines whose next');
        HelpBuilder.AppendLine('billing date falls on or before the billing date are copied into an ad-hoc billing proposal');
        HelpBuilder.AppendLine('(Billing Line rows with a blank Billing Template Code), and that proposal is then turned into');
        HelpBuilder.AppendLine('an unposted purchase document. Nothing is posted by this call - post the resulting document');
        HelpBuilder.AppendLine('separately once it has been reviewed.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Vendor Subscription Contract to bill. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| billingDate | Date | No | Lines due on or before this date are billed. Defaults to the work date. |');
        HelpBuilder.AppendLine('| billingToDate | Date | No | Bills complete periods up to this date. Omit to use each line''s own billing rhythm. |');
        HelpBuilder.AppendLine('| documentDate | Date | No | Document date stamped on the created document. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postingDate | Date | No | Posting date stamped on the created document. Defaults to the work date. |');
        HelpBuilder.AppendLine('| vendorInvoiceNo | Text | No | When supplied, stamped onto the ''Vendor Invoice No.'' field of every document created by this call. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "VC000010",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "vendorInvoiceNo": "INV-2026-0912"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "contractNo": "VC000010",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "billingLineCount": 3,');
        HelpBuilder.AppendLine('  "documents": [');
        HelpBuilder.AppendLine('    { "documentType": "Invoice", "documentNo": "PINV-000123" }');
        HelpBuilder.AppendLine('  ]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`billingLineCount` is the number of Subscription Lines that were due and billed. A run that');
        HelpBuilder.AppendLine('finds nothing due is a success with `billingLineCount` of 0 and an empty `documents` array.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| contractNo is missing | The request is missing the required parameter ''contractNo''. |');
        HelpBuilder.AppendLine('| Another contract has an unfinished ad-hoc proposal | There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before creating an invoice for ''%3''. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes, but it never posts. The billing proposal it builds is an ad-hoc,');
        HelpBuilder.AppendLine('blank-template proposal shared by the whole company, so this call first checks that no such');
        HelpBuilder.AppendLine('proposal lines are left standing for a different contract, and fails rather than sweep up');
        HelpBuilder.AppendLine('someone else''s pending run. Only one partner type is ever billed by this call. Because');
        HelpBuilder.AppendLine('Microsoft''s purchase document creation ignores any post flag, the result is always an');
        HelpBuilder.AppendLine('unposted purchase document that must be posted separately. The write runs in an isolated');
        HelpBuilder.AppendLine('transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.VendorContract.PreviewInvoice`');
        HelpBuilder.AppendLine('- `Subscription.VendorContract.GetLines`');
        HelpBuilder.AppendLine('- `Subscription.Billing.CreateDocuments`');

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

    /// <summary>Builds the ad-hoc proposal and creates the purchase document. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentsArray: JsonArray;
        BillingLineCount: Integer;
        ContractNo: Code[20];
        BillingDate: Date;
        BillingToDate: Date;
        DocumentDate: Date;
        PostingDate: Date;
        VendorInvoiceNo: Text[35];
        Message: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);
        BillingDate := Helper.GetDateOrDefault(RequestJson, 'billingDate', WorkDate());
        BillingToDate := Helper.GetDate(RequestJson, 'billingToDate', false);
        DocumentDate := Helper.GetDateOrDefault(RequestJson, 'documentDate', WorkDate());
        PostingDate := Helper.GetDateOrDefault(RequestJson, 'postingDate', WorkDate());
        VendorInvoiceNo := CopyStr(Helper.GetText(RequestJson, 'vendorInvoiceNo', false), 1, MaxStrLen(VendorInvoiceNo));

        CreateVendorInvoice(ContractNo, BillingDate, BillingToDate, DocumentDate, PostingDate, VendorInvoiceNo, BillingLineCount, DocumentsArray, Message);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('billingDate', Helper.FormatDate(BillingDate));
        ResponseJson.Add('billingLineCount', BillingLineCount);
        ResponseJson.Add('documents', DocumentsArray);
        if Message <> '' then
            ResponseJson.Add('message', Message);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Shared implementation for the write and preview paths: builds an ad-hoc billing proposal for the
    /// contract's due vendor Subscription Lines, turns it into an unposted purchase document, and optionally
    /// stamps the caller's Vendor Invoice No. onto every document it created.
    /// </summary>
    internal procedure CreateVendorInvoice(ContractNo: Code[20]; BillingDate: Date; BillingToDate: Date; DocumentDate: Date; PostingDate: Date; VendorInvoiceNo: Text[35]; var BillingLineCount: Integer; var DocumentsArray: JsonArray; var Message: Text)
    var
        VendorSubscriptionContract: Record "Vendor Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        TempSubscriptionLine: Record "Subscription Line" temporary;
        BillingLine: Record "Billing Line";
        PurchaseHeader: Record "Purchase Header";
        BillingProposal: Codeunit "Billing Proposal";
        DocumentJson: JsonObject;
        DocumentNos: List of [Code[20]];
        DocumentTypes: List of [Text];
        DocumentNo: Code[20];
        Index: Integer;
        ForeignContractNo: Code[20];
        ForeignLineCount: Integer;
        DueLineCount: Integer;
        WatermarkEntryNo: Integer;
    begin
        if not VendorSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetFilter("Subscription Contract No.", '<>%1', ContractNo);
        // Lines already turned into a document are no longer pending and do not block this run.
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        if not BillingLine.IsEmpty() then begin
            ForeignLineCount := BillingLine.Count();
            BillingLine.FindFirst();
            ForeignContractNo := BillingLine."Subscription Contract No.";
            Error(ForeignPendingProposalErr, ForeignLineCount, ForeignContractNo, ContractNo);
        end;

        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.SetRange("Subscription Contract No.", ContractNo);
        SubscriptionLine.SetFilter("Next Billing Date", '<=%1&<>%2', BillingDate, 0D);
        if SubscriptionLine.FindSet() then
            repeat
                TempSubscriptionLine := SubscriptionLine;
                TempSubscriptionLine.Insert();
                DueLineCount += 1;
            until SubscriptionLine.Next() = 0;

        // Assigning a record copies its filters too, so the temporary set would otherwise
        // still be filtered by the source record's view. Clear it before passing it on.
        TempSubscriptionLine.Reset();

        if DueLineCount = 0 then begin
            Message := StrSubstNo(NothingDueMsg, Helper.FormatDate(BillingDate), ContractNo);
            exit;
        end;

        // Note where the Billing Line table ends before the proposal runs, so the response reports
        // exactly the rows this call produced. Reading every billed row for the contract instead
        // would re-report an earlier run's document - and re-stamp the caller's Vendor Invoice No.
        // onto it - which is what happens when the contract's due lines are still sitting on an
        // unposted document, because Business Central then bills nothing new.
        BillingLine.Reset();
        if BillingLine.FindLast() then
            WatermarkEntryNo := BillingLine."Entry No."
        else
            WatermarkEntryNo := 0;

        BillingProposal.CreateBillingProposalForPurchaseHeader(Enum::"Service Partner"::Vendor, TempSubscriptionLine, BillingDate, BillingToDate);
        BillingProposal.CreateBillingDocument(Enum::"Service Partner"::Vendor, ContractNo, DocumentDate, PostingDate, false, false);

        BillingLine.Reset();
        BillingLine.SetFilter("Entry No.", '>%1', WatermarkEntryNo);
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        BillingLine.SetFilter("Document Type", '<>%1', Enum::"Rec. Billing Document Type"::None);
        BillingLine.SetLoadFields("Document Type", "Document No.");
        if BillingLine.FindSet() then
            repeat
                BillingLineCount += 1;
                if not DocumentNos.Contains(BillingLine."Document No.") then begin
                    DocumentNos.Add(BillingLine."Document No.");
                    DocumentTypes.Add(Helper.FormatDocumentType(BillingLine."Document Type"));
                end;
            until BillingLine.Next() = 0;

        if BillingLineCount = 0 then
            Message := StrSubstNo(NothingNewMsg, ContractNo);

        for Index := 1 to DocumentNos.Count() do begin
            DocumentNo := DocumentNos.Get(Index);

            Clear(DocumentJson);
            DocumentJson.Add('documentType', DocumentTypes.Get(Index));
            DocumentJson.Add('documentNo', DocumentNo);
            DocumentsArray.Add(DocumentJson);

            if VendorInvoiceNo <> '' then
                if PurchaseHeader.Get(Enum::"Purchase Document Type"::Invoice, DocumentNo) then begin
                    PurchaseHeader."Vendor Invoice No." := VendorInvoiceNo;
                    PurchaseHeader.Modify(true);
                end else
                    if PurchaseHeader.Get(Enum::"Purchase Document Type"::"Credit Memo", DocumentNo) then begin
                        PurchaseHeader."Vendor Invoice No." := VendorInvoiceNo;
                        PurchaseHeader.Modify(true);
                    end;
        end;
    end;
}
