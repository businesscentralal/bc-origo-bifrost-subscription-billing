namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Purchases.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.VendorContract.CreateInvoice</c> Bifrost message type.
/// Creates the vendor billing document (an unposted purchase invoice or credit memo) for the
/// due Subscription Lines of one vendor subscription contract.
/// A plain Data.Records.Set cannot do this because turning due lines into a purchase document
/// is a multi-step process owned by Microsoft's billing codeunits: an ad-hoc billing proposal
/// has to be built from the exact set of due lines, and only then can the document be created
/// from it - there is no single field to set that produces a purchase invoice.
/// </summary>
codeunit 10035043 "Sub Vend CrInvoice Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Birgjaáskriftarsamningurinn ''%1'' er ekki til.';
        ForeignPendingProposalErr: Label 'There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before creating an invoice for ''%3''.', Comment = '%1 = row count, %2 = the other contract number, %3 = this contract number||is-IS=Það eru %1 ólokin(ar) færsla(ur) í reikningstillögu fyrir annan áskriftarsamning (''%2''). Hreinsaðu eða vinndu úr þeirri tillögu áður en reikningur er búinn til fyrir ''%3''.';
        NothingDueMsg: Label 'No Subscription Lines were due for billing on or before %1 for contract %2.', Comment = '%1 = billing date, %2 = contract no.||is-IS=Engar áskriftarlínur voru gjaldfallnar til reikningsgerðar á eða fyrir %1 fyrir samning %2.';
        NothingNewMsg: Label 'Nothing new could be billed for contract %1. Its due Subscription Lines already sit on a billing proposal or on an unposted document - post or clear those first.', Comment = '%1 = contract number||is-IS=Ekkert nýtt var hægt að reikningsfæra fyrir samning %1. Áskriftarlínur hans eru þegar á reikningstillögu eða á óbókfærðu skjali - bókfaðu þær eða hreinsaðu þær fyrst.';
        DescriptionLbl: Label 'Creates an unposted purchase invoice or credit memo for the due Subscription Lines of a vendor subscription contract. Never posts the document.', MaxLength = 250, Comment = 'is-IS=Býr til óbókfærðan innkaupareikning eða kreditreikning fyrir gjaldfallnar áskriftarlínur birgjaáskriftarsamnings. Skjalið er aldrei bókfært.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Vendor Subscription Contract");
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
        VendHelp: Codeunit "Sub Vend Help ori";
    begin
        Argument.SetResponseMarkdown(VendHelp.GetHelpMarkdown('Subscription.VendorContract.CreateInvoice'));
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

    /// <summary>Builds the ad-hoc proposal and creates the purchase document. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
    procedure CreateVendorInvoice(ContractNo: Code[20]; BillingDate: Date; BillingToDate: Date; DocumentDate: Date; PostingDate: Date; VendorInvoiceNo: Text[35]; var BillingLineCount: Integer; var DocumentsArray: JsonArray; var Message: Text)
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
        BillingLine.SetLoadFields("Entry No.");
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

            // Validate, not a direct assignment: the field's OnValidate is what enforces the vendor's
            // duplicate-invoice-number control. Writing the field straight would let the same vendor
            // invoice number be booked twice under two different documents.
            if VendorInvoiceNo <> '' then
                if PurchaseHeader.Get(Enum::"Purchase Document Type"::Invoice, DocumentNo) then begin
                    PurchaseHeader.Validate("Vendor Invoice No.", VendorInvoiceNo);
                    PurchaseHeader.Modify(true);
                end else
                    if PurchaseHeader.Get(Enum::"Purchase Document Type"::"Credit Memo", DocumentNo) then begin
                        PurchaseHeader.Validate("Vendor Invoice No.", VendorInvoiceNo);
                        PurchaseHeader.Modify(true);
                    end;
        end;
    end;
}
