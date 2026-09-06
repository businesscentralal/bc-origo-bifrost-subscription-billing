namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Contract.CreateInvoice</c> Cloud Event message type.
/// Bills one customer Subscription Contract to an unposted sales invoice by handing the
/// contract's due Subscription Lines to Microsoft's ad-hoc billing proposal entry point and
/// then creating the document from the resulting proposal lines. A plain Data.Records.Set
/// cannot do this because both the proposal lines and the invoice are produced by codeunits
/// that derive periods, prices and grouping from each Subscription Line.
/// </summary>
codeunit 10035038 "CE Sub Con CrInvoice Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract no.||is-IS=Áskriftarsamningur viðskiptavinar ''%1'' er ekki til.';
        ForeignPendingErr: Label 'Contract ''%1'' has %2 pending billing line(s) with no billing template assigned. Clear or complete that proposal before billing this contract, because creating this invoice would also convert those lines.', Comment = '%1 = foreign contract no., %2 = row count||is-IS=Samningur ''%1'' er með %2 ófrágengna(r) reikningslínu(r) án úthlutaðs reikningssniðmáts. Ljúktu við eða hreinsaðu þá tillögu áður en þessi samningur er reikningsfærður, því annars myndi þessi aðgerð einnig umbreyta þeim línum.';
        NothingDueMsg: Label 'No Subscription Lines were due for billing on or before %1 for contract %2.', Comment = '%1 = billing date, %2 = contract no.||is-IS=Engar áskriftarlínur voru gjaldfallnar til reikningsgerðar á eða fyrir %1 fyrir samning %2.';
        NothingNewMsg: Label 'Nothing new could be billed for contract %1. Its due Subscription Lines already sit on a billing proposal or on an unposted document - post or clear those first.', Comment = '%1 = contract number||is-IS=Ekkert nýtt var hægt að reikningsfæra fyrir samning %1. Áskriftarlínur hans eru þegar á reikningstillögu eða á óbókfærðu skjali - bókfaðu þær eða hreinsaðu þær fyrst.';
        DescriptionLbl: Label 'Bills one customer Subscription Contract to an unposted sales invoice. Returns the documents created.', MaxLength = 250, Comment = 'is-IS=Reikningsfærir einn áskriftarsamning viðskiptavinar á óbókfærðan sölureikning. Skilar þeim skjölum sem urðu til.';

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
        HelpBuilder.AppendLine('# Subscription.Contract.CreateInvoice');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Bills one customer Subscription Contract to an unposted sales invoice (or credit memo,');
        HelpBuilder.AppendLine('when a line calls for one). The due Subscription Lines on the contract are copied into a');
        HelpBuilder.AppendLine('temporary set and handed to Microsoft''s ad-hoc billing proposal entry point - the same');
        HelpBuilder.AppendLine('entry point the per-contract billing dialog in the client uses - which creates Billing');
        HelpBuilder.AppendLine('Line proposal rows with no billing template attached. The document is then created from');
        HelpBuilder.AppendLine('those rows. Nothing is posted, and the document is never opened.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Customer Subscription Contract to bill. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| billingDate | Date | No | Lines due on or before this date are billed. Defaults to the work date. |');
        HelpBuilder.AppendLine('| billingToDate | Date | No | Bills complete periods up to this date. Omit to use each line''s own billing rhythm. |');
        HelpBuilder.AppendLine('| documentDate | Date | No | Document date on the created document. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postingDate | Date | No | Posting date on the created document. Defaults to the work date. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "CC000010",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "contractNo": "CC000010",');
        HelpBuilder.AppendLine('  "billingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "documents": [');
        HelpBuilder.AppendLine('    { "documentType": "Invoice", "documentNo": "SINV-000123" }');
        HelpBuilder.AppendLine('  ],');
        HelpBuilder.AppendLine('  "billingLineCount": 3');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('When nothing on the contract is due, the call still succeeds with `documents: []` and a');
        HelpBuilder.AppendLine('`message` explaining that nothing was due.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| Another contract has pending template-less proposal lines | Contract ''%1'' has %2 pending billing line(s) with no billing template assigned... |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes an unposted document; it never posts and never opens a page.');
        HelpBuilder.AppendLine('The proposal rows this call creates carry a blank Billing Template Code, because that is');
        HelpBuilder.AppendLine('what the ad-hoc, per-contract billing entry point produces. Microsoft''s own document');
        HelpBuilder.AppendLine('creation codeunit converts every blank-template Billing Line in the company when it runs -');
        HelpBuilder.AppendLine('not only the ones for this contract - so before doing anything this call checks for');
        HelpBuilder.AppendLine('blank-template Billing Lines that belong to a different contract and refuses to run,');
        HelpBuilder.AppendLine('naming that contract, rather than silently invoicing someone else''s pending proposal.');
        HelpBuilder.AppendLine('The write runs in an isolated transaction that rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Contract.PreviewInvoice`');
        HelpBuilder.AppendLine('- `Subscription.Contract.GetLines`');
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

    /// <summary>Bills the contract and reports the documents created. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        BillingDate: Date;
        BillingToDate: Date;
        DocumentDate: Date;
        PostingDate: Date;
    begin
        ContractNo := Helper.GetSubjectOr(Argument, Argument.GetRequestJson(), 'contractNo', true);
        BillingDate := Helper.GetDateOrDefault(Argument.GetRequestJson(), 'billingDate', WorkDate());
        BillingToDate := Helper.GetDate(Argument.GetRequestJson(), 'billingToDate', false);
        DocumentDate := Helper.GetDateOrDefault(Argument.GetRequestJson(), 'documentDate', WorkDate());
        PostingDate := Helper.GetDateOrDefault(Argument.GetRequestJson(), 'postingDate', WorkDate());

        BillContract(ContractNo, BillingDate, BillingToDate, DocumentDate, PostingDate, ResponseJson);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Shared billing logic used by both the write and the preview implementation. Builds the
    /// ad-hoc billing proposal for the contract's due Subscription Lines, creates the unposted
    /// document, and fills ResponseJson with the outcome. Does not respond on Argument itself,
    /// so the caller controls whether this is a real write or a rolled-back preview.
    /// </summary>
    local procedure BillContract(ContractNo: Code[20]; BillingDate: Date; BillingToDate: Date; DocumentDate: Date; PostingDate: Date; var ResponseJson: JsonObject)
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        TempSubscriptionLine: Record "Subscription Line" temporary;
        BillingLine: Record "Billing Line";
        BillingProposal: Codeunit "Billing Proposal";
        DocumentsArray: JsonArray;
        DocumentJson: JsonObject;
        SeenDocuments: List of [Text];
        DocumentKey: Text;
        ForeignCount: Integer;
        BillingLineCount: Integer;
        WatermarkEntryNo: Integer;
    begin
        if not CustomerSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetFilter("Subscription Contract No.", '<>%1', ContractNo);
        // Lines already turned into a document are no longer pending and do not block this run.
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        ForeignCount := BillingLine.Count();
        if ForeignCount > 0 then begin
            BillingLine.FindFirst();
            Error(ForeignPendingErr, BillingLine."Subscription Contract No.", ForeignCount);
        end;

        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        SubscriptionLine.SetRange("Subscription Contract No.", ContractNo);
        SubscriptionLine.SetFilter("Next Billing Date", '<=%1&<>%2', BillingDate, 0D);
        if SubscriptionLine.FindSet() then
            repeat
                TempSubscriptionLine := SubscriptionLine;
                TempSubscriptionLine.Insert();
            until SubscriptionLine.Next() = 0;

        // Assigning a record copies its filters too, so the temporary set would otherwise
        // still be filtered by the source record's view. Clear it before reading back.
        TempSubscriptionLine.Reset();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('billingDate', Helper.FormatDate(BillingDate));

        if TempSubscriptionLine.IsEmpty() then begin
            ResponseJson.Add('documents', DocumentsArray);
            ResponseJson.Add('billingLineCount', 0);
            ResponseJson.Add('message', StrSubstNo(NothingDueMsg, Helper.FormatDate(BillingDate), ContractNo));
            exit;
        end;

        // Note where the Billing Line table ends before the proposal runs, so the response reports
        // exactly the rows this call produced. Counting every blank-template row for the contract
        // instead would re-report rows from an earlier run and name a document that already
        // existed - which is what happens when the contract's due lines are still sitting on an
        // unposted document, because Business Central then bills nothing new.
        BillingLine.Reset();
        if BillingLine.FindLast() then
            WatermarkEntryNo := BillingLine."Entry No."
        else
            WatermarkEntryNo := 0;

        BillingProposal.CreateBillingProposalForPurchaseHeader(Enum::"Service Partner"::Customer, TempSubscriptionLine, BillingDate, BillingToDate);
        BillingProposal.CreateBillingDocument(Enum::"Service Partner"::Customer, ContractNo, DocumentDate, PostingDate, false, false);

        BillingLine.Reset();
        BillingLine.SetFilter("Entry No.", '>%1', WatermarkEntryNo);
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        BillingLineCount := BillingLine.Count();

        BillingLine.SetLoadFields("Document Type", "Document No.");
        if BillingLine.FindSet() then
            repeat
                if BillingLine."Document No." <> '' then begin
                    DocumentKey := Helper.FormatDocumentType(BillingLine."Document Type") + '|' + BillingLine."Document No.";
                    if not SeenDocuments.Contains(DocumentKey) then begin
                        SeenDocuments.Add(DocumentKey);
                        Clear(DocumentJson);
                        DocumentJson.Add('documentType', Helper.FormatDocumentType(BillingLine."Document Type"));
                        DocumentJson.Add('documentNo', BillingLine."Document No.");
                        DocumentsArray.Add(DocumentJson);
                    end;
                end;
            until BillingLine.Next() = 0;

        if BillingLineCount = 0 then
            ResponseJson.Add('message', StrSubstNo(NothingNewMsg, ContractNo));

        ResponseJson.Add('documents', DocumentsArray);
        ResponseJson.Add('billingLineCount', BillingLineCount);
    end;
}
