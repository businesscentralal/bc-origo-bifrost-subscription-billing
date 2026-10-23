namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.DeleteDocuments</c> Bifrost message type (#37).
/// Deletes the unposted sales and purchase documents that a Billing Template's billing lines were
/// turned into, the way the Delete Documents action on the Recurring Billing page does for
/// "Documents from current billing template only". Microsoft's "Billing Proposal".DeleteBillingDocuments
/// is internal and asks its question in a dialog, so each Sales Header or Purchase Header is deleted
/// here with Delete(true): Microsoft's own subscribers to the header's OnBeforeDeleteEvent then put
/// the billing lines back into the proposal, or, for template-less lines, delete them and reset the
/// Next Billing Date. A posted document is refused by name.
/// </summary>
codeunit 10035065 "Sub Bil DelDocs Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        TemplateOrContractErr: Label 'The request must name a Billing Template in ''billingTemplateCode'' or the subject, or, for the billing lines without a Billing Template, a contract in ''contractNo'' or a document in ''documentNo''.', Comment = 'is-IS=Beiðnin verður að tilgreina reikningssniðmát í ''billingTemplateCode'' eða efninu, eða, fyrir reikningslínur án reikningssniðmáts, samning í ''contractNo'' eða skjal í ''documentNo''.';
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        PostedDocumentErr: Label 'Document %1 is posted and cannot be deleted. Cancel or correct the posted invoice or credit memo instead, for example with Sales.SalesInvoice.Cancel or Sales.SalesInvoice.Correct.', Comment = '%1 = document number||is-IS=Skjal %1 er bókað og ekki er hægt að eyða því. Hættu við eða leiðréttu bókaða reikninginn eða kreditreikninginn í staðinn, til dæmis með Sales.SalesInvoice.Cancel eða Sales.SalesInvoice.Correct.';
        DocumentNotFoundErr: Label 'No billing line of Billing Template ''%1'' is on document %2.', Comment = '%1 = billing template code, %2 = document number||is-IS=Engin reikningslína í reikningssniðmátinu ''%1'' er á skjali %2.';
        DescriptionLbl: Label 'Deletes the unposted invoices and credit memos created from a Billing Template''s billing lines and puts the lines back into the proposal. Refuses posted documents.', MaxLength = 250, Comment = 'is-IS=Eyðir óbókuðum reikningum og kreditreikningum sem urðu til úr reikningslínum reikningssniðmáts og setur línurnar aftur í tillöguna. Hafnar bókuðum skjölum.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Line");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete billing documents, delete unposted invoices, undo billing run, remove unposted billing invoice, delete unposted credit memo, return lines to proposal, undo invoice creation, delete invoice from contract', Comment = 'is-IS=eyða reikningsskjölum, eyða óbókuðum reikningum, afturkalla reikningagerð, fjarlægja óbókaðan reikning, eyða óbókuðum kreditreikningi, skila línum í tillöguna, afturkalla reikningsstofnun, eyða reikningi af samningi';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Delete billing documents: deletes unposted sales or purchase invoices and credit memos made by billing and returns their lines to the proposal; lines of documents made without a Billing Template are deleted instead. Irreversible, and posted documents are refused. To remove the proposal itself use Subscription.Billing.ClearProposal; to make the documents again use Subscription.Billing.CreateDocuments.', Comment = 'is-IS=Eyða reikningsskjölum: eyðir óbókuðum sölu- eða innkaupareikningum og kreditreikningum sem reikningagerð bjó til og skilar línum þeirra í tillöguna; línum skjala sem búin voru til án reikningssniðmáts er eytt. Óafturkræf aðgerð og bókuðum skjölum er hafnað. Til að fjarlægja sjálfa tillöguna skal nota Subscription.Billing.ClearProposal; til að búa skjölin til aftur skal nota Subscription.Billing.CreateDocuments.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope := ContractParts.GetEnvelope(ContractType());
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target := ContractParts.GetTarget(ContractType());
        exit(Target.Count() > 0);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := ContractParts.DeleteDocumentsParameters();
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response := ContractParts.GetResponse(ContractType());
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors := ContractParts.GetErrors(ContractType());
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect := ContractParts.GetEffect(ContractType());
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related := ContractParts.GetRelated(ContractType());
        exit(Related.Count() > 0);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow := ContractParts.GetWorkflow(ContractType());
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Delete the documents of a run',
            '{"type":"Subscription.Billing.DeleteDocuments","subject":"MONTHLY","data":{}}',
            '{"status":"Success","billingTemplateCode":"MONTHLY","documentsDeleted":2,"documents":[{"partner":"Customer","documentType":"Invoice","documentNo":"S-INV-1001"},{"partner":"Customer","documentType":"Invoice","documentNo":"S-INV-1002"}],"billingLinesReturnedToProposal":12,"billingLinesRemoved":0}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes the unposted sales or purchase invoices and credit memos that Subscription.Billing.CreateDocuments made from a Billing Template''s billing ' +
            'lines, optionally only those of one contract or one document. Microsoft''s delete handling puts the billing lines back into the proposal, so ' +
            'Subscription.Billing.CreateDocuments can run again, or Subscription.Billing.ClearProposal can clear them.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Without billingTemplateCode the call works on the billing lines without a Billing Template, which Subscription.Contract.CreateInvoice and ' +
            'Subscription.VendorContract.CreateInvoice create; contractNo or documentNo is then required. Each document is deleted once with its delete trigger, so ' +
            'Business Central and Subscription Billing run their usual delete checks. billingLinesReturnedToProposal counts the billing lines that still exist ' +
            'without a document afterwards; billingLinesRemoved counts those Microsoft deleted, which happens for billing lines without a Billing Template and for ' +
            'credit memo lines that reverse an invoice. A posted invoice or credit memo cannot be deleted: cancel or correct it, for example with ' +
            'Sales.SalesInvoice.Cancel or Sales.SalesInvoice.Correct. When any Billing Template bills automatically, only a user with Auto Contract Billing in User ' +
            'Setup may delete billing documents, as in the client. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Billing.DeleteDocuments');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformWrite(Rec);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not Helper.ValidateRequest(Argument) then
            exit;

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Bil DelDocs Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes the selected billing documents. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        BillingLine: Record "Billing Line";
        BillingTemplate: Record "Billing Template";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentsArray: JsonArray;
        AffectedLines: List of [Integer];
        DocumentKeys: List of [Text];
        BillingTemplateCode: Code[20];
        ContractNo: Code[20];
        DocumentNo: Code[20];
        PreviousKey: Text;
        DocumentKey: Text;
        LineEntryNo: Integer;
        DocumentsDeleted: Integer;
        LinesReturned: Integer;
        LinesRemoved: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(RequestJson, 'billingTemplateCode', Argument, false);
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);
        DocumentNo := Helper.GetCode20(RequestJson, 'documentNo', false);

        if BillingTemplateCode = '' then begin
            if (ContractNo = '') and (DocumentNo = '') then
                Error(TemplateOrContractErr);
        end else
            if not BillingTemplate.Get(BillingTemplateCode) then
                Error(TemplateNotFoundErr, BillingTemplateCode);
        Helper.AssertMayClearBillingProposal();

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        if ContractNo <> '' then
            BillingLine.SetRange("Subscription Contract No.", ContractNo);
        if DocumentNo <> '' then
            BillingLine.SetRange("Document No.", DocumentNo)
        else
            BillingLine.SetFilter("Document No.", '<>%1', '');
        BillingLine.SetCurrentKey("Document Type", "Document No.");
        if BillingLine.IsEmpty() and (DocumentNo <> '') then begin
            if IsPostedDocument(DocumentNo) then
                Error(PostedDocumentErr, DocumentNo);
            Error(DocumentNotFoundErr, BillingTemplateCode, DocumentNo);
        end;

        // Read the documents first: deleting one changes the billing lines the filter selects.
        if BillingLine.FindSet() then
            repeat
                AffectedLines.Add(BillingLine."Entry No.");
                DocumentKey := MakeDocumentKey(BillingLine);
                if DocumentKey <> PreviousKey then
                    if not DocumentKeys.Contains(DocumentKey) then
                        DocumentKeys.Add(DocumentKey);
                PreviousKey := DocumentKey;
            until BillingLine.Next() = 0;

        foreach DocumentKey in DocumentKeys do
            if DeleteDocument(DocumentKey, DocumentsArray) then
                DocumentsDeleted += 1;

        BillingLine.Reset();
        foreach LineEntryNo in AffectedLines do
            if BillingLine.Get(LineEntryNo) then
                LinesReturned += 1
            else
                LinesRemoved += 1;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);
        ResponseJson.Add('documentsDeleted', DocumentsDeleted);
        ResponseJson.Add('documents', DocumentsArray);
        ResponseJson.Add('billingLinesReturnedToProposal', LinesReturned);
        ResponseJson.Add('billingLinesRemoved', LinesRemoved);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure MakeDocumentKey(BillingLine: Record "Billing Line"): Text
    begin
        exit(Format(BillingLine.Partner.AsInteger(), 0, 9) + '|' + Format(BillingLine."Document Type".AsInteger(), 0, 9) + '|' + BillingLine."Document No.");
    end;

    /// <summary>Deletes the unposted document a key names and reports it; false when it no longer exists.</summary>
    local procedure DeleteDocument(DocumentKey: Text; var DocumentsArray: JsonArray): Boolean
    var
        SalesHeader: Record "Sales Header";
        PurchaseHeader: Record "Purchase Header";
        Parts: List of [Text];
        DocumentJson: JsonObject;
        PartnerOrdinal: Integer;
        DocumentTypeOrdinal: Integer;
        DocumentNo: Code[20];
        BillingDocumentType: Enum "Rec. Billing Document Type";
        Partner: Enum "Service Partner";
    begin
        Parts := DocumentKey.Split('|');
        Evaluate(PartnerOrdinal, Parts.Get(1), 9);
        Evaluate(DocumentTypeOrdinal, Parts.Get(2), 9);
        DocumentNo := CopyStr(Parts.Get(3), 1, MaxStrLen(DocumentNo));
        Partner := Enum::"Service Partner".FromInteger(PartnerOrdinal);
        BillingDocumentType := Enum::"Rec. Billing Document Type".FromInteger(DocumentTypeOrdinal);

        case Partner of
            Partner::Customer:
                begin
                    if not SalesHeader.Get(ToSalesDocumentType(BillingDocumentType), DocumentNo) then
                        exit(false);
                    SalesHeader.Delete(true);
                    DocumentJson.Add('partner', 'Customer');
                end;
            Partner::Vendor:
                begin
                    if not PurchaseHeader.Get(ToPurchaseDocumentType(BillingDocumentType), DocumentNo) then
                        exit(false);
                    PurchaseHeader.Delete(true);
                    DocumentJson.Add('partner', 'Vendor');
                end;
        end;
        DocumentJson.Add('documentType', Helper.FormatDocumentType(BillingDocumentType));
        DocumentJson.Add('documentNo', DocumentNo);
        DocumentsArray.Add(DocumentJson);
        exit(true);
    end;

    local procedure ToSalesDocumentType(BillingDocumentType: Enum "Rec. Billing Document Type"): Enum "Sales Document Type"
    begin
        if BillingDocumentType = BillingDocumentType::"Credit Memo" then
            exit(Enum::"Sales Document Type"::"Credit Memo");
        exit(Enum::"Sales Document Type"::Invoice);
    end;

    local procedure ToPurchaseDocumentType(BillingDocumentType: Enum "Rec. Billing Document Type"): Enum "Purchase Document Type"
    begin
        if BillingDocumentType = BillingDocumentType::"Credit Memo" then
            exit(Enum::"Purchase Document Type"::"Credit Memo");
        exit(Enum::"Purchase Document Type"::Invoice);
    end;

    local procedure IsPostedDocument(DocumentNo: Code[20]): Boolean
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
    begin
        SalesInvoiceHeader.SetRange("No.", DocumentNo);
        if not SalesInvoiceHeader.IsEmpty() then
            exit(true);
        SalesCrMemoHeader.SetRange("No.", DocumentNo);
        if not SalesCrMemoHeader.IsEmpty() then
            exit(true);
        PurchInvHeader.SetRange("No.", DocumentNo);
        if not PurchInvHeader.IsEmpty() then
            exit(true);
        PurchCrMemoHdr.SetRange("No.", DocumentNo);
        exit(not PurchCrMemoHdr.IsEmpty());
    end;
}
