namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Posting;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Posting;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements <c>Subscription.Billing.PostDocuments</c>.
/// Foundation's Sales.Document.Post refuses a subscription item, so an invoice that a billing run
/// created with postDocuments false cannot be posted through Bifröst. This type posts those
/// documents, and the purchase documents CreateDocuments never posts, through Microsoft's own
/// Sales-Post and Purch.-Post. It refuses a document Subscription Billing did not create.
/// </summary>
codeunit 10035085 "Sub Bil PostDocs Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        PostingGate: Codeunit "Sub Posting Gate ori";
        DescriptionLbl: Label 'Posts unposted sales and purchase documents that a Subscription Billing run created, through Business Central''s own posting path. Refuses a document that run did not create.', MaxLength = 250, Comment = 'is-IS=Bókar óbókúð sölu- og innkaupaskjöl sem reikningskeyrsla áskrifta bjó til, með eigin bókunarleið Business Central. Hafnar skjali sem sú keyrsla bjó ekki til.';
        MissingDocumentsErr: Label 'The request is missing the required parameter ''%1''.', Comment = '%1 = parameter name||is-IS=Beiðnina vantar nauðsynlega færibreytu ''%1''.';
        EmptyDocumentsErr: Label 'The parameter ''documents'' must contain at least one document.', Comment = 'is-IS=Færibreytan ''documents'' verður að innihalda að minnsta kosti eitt skjal.';
        DocumentShapeErr: Label 'Each entry of ''documents'' must be a JSON object with partner, documentType and documentNo.', Comment = 'is-IS=Hver færsla í ''documents'' verður að vera JSON-hlutur með partner, documentType og documentNo.';
        InvalidPartnerErr: Label 'The parameter ''partner'' must be either ''Customer'' or ''Vendor''.', Comment = 'is-IS=Færibreytan ''partner'' verður að vera annaðhvort ''Customer'' eða ''Vendor''.';
        InvalidDocumentTypeErr: Label 'The parameter ''documentType'' must be either ''Invoice'' or ''Credit Memo''.', Comment = 'is-IS=Færibreytan ''documentType'' verður að vera annaðhvort ''Invoice'' eða ''Credit Memo''.';
        ValueTooLongErr: Label 'The parameter ''%1'' is longer than the %2 characters allowed.', Comment = '%1 = parameter name, %2 = maximum length||is-IS=Færibreytan ''%1'' er lengri en leyfilegur hámarksfjöldi stafa, %2.';
        DuplicateDocumentErr: Label 'Document %1 is listed more than once. Nothing was posted.', Comment = '%1 = document number||is-IS=Skjal %1 er tilgreint oftar en einu sinni. Ekkert var bókað.';
        ForeignCustomerErr: Label 'Document %1 %2 was not created by Subscription Billing. Post it with Sales.Document.Post.', Comment = '%1 = document type, %2 = document number||is-IS=Skjal %1 %2 var ekki búið til af áskriftareikningagerð. Bókaðu það með Sales.Document.Post.';
        ForeignVendorErr: Label 'Document %1 %2 was not created by Subscription Billing. Post it with Purch.Document.Post.', Comment = '%1 = document type, %2 = document number||is-IS=Skjal %1 %2 var ekki búið til af áskriftareikningagerð. Bókaðu það með Purch.Document.Post.';
        AlreadyPostedErr: Label 'Document %1 %2 is already posted.', Comment = '%1 = document type, %2 = document number||is-IS=Skjal %1 %2 er þegar bókað.';
        NotOpenErr: Label 'Billing document %1 %2 is not an open sales or purchase document.', Comment = '%1 = document type, %2 = document number||is-IS=Reikningsskjalið %1 %2 er ekki opið sölu- eða innkaupaskjal.';
        PostFailedErr: Label 'Posting document %1 failed. Documents this call already posted stay posted. %2', Comment = '%1 = document number, %2 = the underlying error||is-IS=Bókun skjals %1 mistókst. Skjöl sem þetta kall hefur þegar bókað standa áfram bókuð. %2';
        PostedNoMissingErr: Label 'Posting document %1 reported success but no posted document was found.', Comment = '%1 = document number||is-IS=Bókun skjals %1 tilkynnti árangur en ekkert bókað skjal fannst.';
        CustomerTok: Label 'Customer', Locked = true;
        VendorTok: Label 'Vendor', Locked = true;
        InvoiceTok: Label 'Invoice', Locked = true;
        CreditMemoTok: Label 'Credit Memo', Locked = true;

    procedure IsEnabled(): Boolean
    begin
        exit(PostingGate.HasPostingPermission());
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
        KeywordsLbl: Label 'Subscription.Billing.PostDocuments, Subscription, Billing, PostDocuments, invoice, post', Comment = 'is-IS=Subscription.Billing.PostDocuments, áskrift, reikningagerð, bóka skjöl, reikningur, bóka';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Billing.PostDocuments: Posts billing documents. Irreversible and always commits.', Comment = 'is-IS=Subscription.Billing.PostDocuments: Bókar reikningsskjöl. Óafturkræf aðgerð sem staðfestir alltaf.';
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
        Parameters := ContractParts.PostDocumentsParameters();
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
        Examples.Add(ContractMgt.Example('Post one unposted billing invoice',
            '{"type":"Subscription.Billing.PostDocuments","data":{"documents":[{"partner":"Customer","documentType":"Invoice","documentNo":"INV-000123"}]}}',
            '{"status":"Success","postedCount":1,"documents":[{"partner":"Customer","documentType":"Invoice","documentNo":"INV-000123","postedDocumentNo":"INV-000123","posted":true}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Posts sales and purchase invoices or credit memos that a Subscription Billing run created and left unposted. ' +
            'A document the billing run did not create is refused.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This call always commits, including when Omit Commit is set, because a posted ledger document cannot be rolled back. ' +
            'Every document is checked before the first one is posted. A document Subscription Billing did not create is refused and the caller is sent to Sales.Document.Post or Purch.Document.Post. ' +
            'An already posted document is refused. A blank Vendor Invoice No. on a purchase document is set to the document number before posting. ' +
            'Sales.Document.Post cannot post these documents: it refuses a subscription item before posting.';
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Billing.PostDocuments');
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
        if not PostingGate.AssertCanPost(Argument) then
            exit;

        // The write commits on its own, including under Omit Commit. Isolate it so a refusal
        // becomes status Error on the API path instead of an unhandled exception.
        if not Codeunit.Run(Codeunit::"Sub Bil PostDocs Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Posts the requested billing documents. Called directly by the test library, or by OnRun
    /// when ExecuteBifrostTask runs this codeunit in its own transaction.
    /// </summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Documents: JsonArray;
        PostedDocuments: JsonArray;
        PendingJson: JsonObject;
        Pending: List of [JsonObject];
    begin
        if not PostingGate.AssertCanPost(Argument) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if not Helper.TryGetArray(RequestJson, 'documents', Documents) then
            Error(MissingDocumentsErr, 'documents');
        if Documents.Count() = 0 then
            Error(EmptyDocumentsErr);

        Pending := ValidateDocuments(Documents);
        foreach PendingJson in Pending do
            PostedDocuments.Add(PostOne(PendingJson));

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('postedCount', PostedDocuments.Count());
        ResponseJson.Add('documents', PostedDocuments);
        Helper.RespondWithSuccess(Argument, ResponseJson);
        // The posted documents are already committed. Commit the success response as well when the
        // caller set Omit Commit, which would otherwise leave this answer uncommitted.
        Commit();
    end;

    local procedure ValidateDocuments(Documents: JsonArray) Pending: List of [JsonObject]
    var
        Seen: Dictionary of [Text, Boolean];
        DocumentToken: JsonToken;
        DocumentJson: JsonObject;
        PartnerText: Text;
        DocumentTypeText: Text;
        DocumentNoText: Text;
        DocumentNo: Code[20];
        Partner: Enum "Service Partner";
        BillingDocumentType: Enum "Rec. Billing Document Type";
        SeenKey: Text;
    begin
        foreach DocumentToken in Documents do begin
            if not DocumentToken.IsObject() then
                Error(DocumentShapeErr);
            DocumentJson := DocumentToken.AsObject();
            PartnerText := NormalizePartner(Helper.GetText(DocumentJson, 'partner', true));
            DocumentTypeText := NormalizeDocumentType(Helper.GetText(DocumentJson, 'documentType', true));
            DocumentNoText := Helper.GetText(DocumentJson, 'documentNo', true);
            if DocumentNoText = '' then
                Error(MissingDocumentsErr, 'documentNo');
            if StrLen(DocumentNoText) > MaxStrLen(DocumentNo) then
                Error(ValueTooLongErr, 'documentNo', MaxStrLen(DocumentNo));
            DocumentNo := CopyStr(DocumentNoText, 1, MaxStrLen(DocumentNo));

            SeenKey := PartnerText + '|' + DocumentTypeText + '|' + DocumentNo;
            if Seen.ContainsKey(SeenKey) then
                Error(DuplicateDocumentErr, DocumentNo);
            Seen.Add(SeenKey, true);

            Partner := PartnerFromText(PartnerText);
            BillingDocumentType := BillingDocumentTypeFromText(DocumentTypeText);
            AssertCanPostDocument(Partner, BillingDocumentType, DocumentTypeText, DocumentNo);
            Pending.Add(PendingDocument(PartnerText, DocumentTypeText, DocumentNo));
        end;
    end;

    local procedure AssertCanPostDocument(Partner: Enum "Service Partner"; BillingDocumentType: Enum "Rec. Billing Document Type"; DocumentTypeText: Text; DocumentNo: Code[20])
    var
        OnBillingLine: Boolean;
        OnArchive: Boolean;
        OpenHeader: Boolean;
        PostedNo: Code[20];
    begin
        OnBillingLine := BillingLineExists(Partner, BillingDocumentType, DocumentNo);
        OnArchive := BillingArchiveExists(Partner, BillingDocumentType, DocumentNo);
        OpenHeader := OpenHeaderExists(Partner, BillingDocumentType, DocumentNo);
        PostedNo := PostedNoOf(Partner, BillingDocumentType, DocumentNo);
        // Posting can move the billing row onto the posted document number. A second call that
        // still names the original document number has to see that row.
        if (not OnBillingLine) and (not OnArchive) and (PostedNo <> '') and (PostedNo <> DocumentNo) then begin
            OnBillingLine := BillingLineExists(Partner, BillingDocumentType, PostedNo);
            OnArchive := BillingArchiveExists(Partner, BillingDocumentType, PostedNo);
        end;

        if (not OnBillingLine) and (not OnArchive) then
            if Partner = Enum::"Service Partner"::Customer then
                Error(ForeignCustomerErr, DocumentTypeText, DocumentNo)
            else
                Error(ForeignVendorErr, DocumentTypeText, DocumentNo);

        if OpenHeader then
            exit;
        if (PostedNo <> '') or OnArchive then
            Error(AlreadyPostedErr, DocumentTypeText, DocumentNo);
        Error(NotOpenErr, DocumentTypeText, DocumentNo);
    end;

    local procedure PostedNoOf(Partner: Enum "Service Partner"; BillingDocumentType: Enum "Rec. Billing Document Type"; DocumentNo: Code[20]): Code[20]
    begin
        if Partner = Enum::"Service Partner"::Customer then
            exit(PostedSalesNo(SalesDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo, ''));
        exit(PostedPurchaseNo(PurchaseDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo, ''));
    end;

    local procedure PostOne(PendingJson: JsonObject) PostedJson: JsonObject
    var
        PartnerText: Text;
        DocumentTypeText: Text;
        DocumentNo: Code[20];
        PostedNo: Code[20];
        VendorInvoiceNo: Code[35];
    begin
        PartnerText := Helper.GetText(PendingJson, 'partner', true);
        DocumentTypeText := Helper.GetText(PendingJson, 'documentType', true);
        DocumentNo := CopyStr(Helper.GetText(PendingJson, 'documentNo', true), 1, MaxStrLen(DocumentNo));
        if PartnerText = CustomerTok then
            PostedNo := PostSalesDocument(DocumentTypeText, DocumentNo)
        else
            PostedNo := PostPurchaseDocument(DocumentTypeText, DocumentNo, VendorInvoiceNo);

        PostedJson.Add('partner', PartnerText);
        PostedJson.Add('documentType', DocumentTypeText);
        PostedJson.Add('documentNo', DocumentNo);
        PostedJson.Add('postedDocumentNo', PostedNo);
        PostedJson.Add('posted', true);
        if PartnerText = VendorTok then
            PostedJson.Add('vendorInvoiceNo', VendorInvoiceNo);
    end;

    local procedure PostSalesDocument(DocumentTypeText: Text; DocumentNo: Code[20]) PostedNo: Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesDocumentType: Enum "Sales Document Type";
        Failure: Text;
    begin
        SalesDocumentType := SalesDocumentTypeFromText(DocumentTypeText);
        SalesHeader.Get(SalesDocumentType, DocumentNo);
        SalesHeader.Ship := false;
        SalesHeader.Invoice := true;
        SalesHeader."Print Posted Documents" := false;
        SalesHeader.Modify(false);
        SalesHeader.SetHideValidationDialog(true);
        Commit();
        ClearLastError();
        if not Codeunit.Run(Codeunit::"Sales-Post", SalesHeader) then begin
            Failure := GetLastErrorText();
            Error(PostFailedErr, DocumentNo, Failure);
        end;
        PostedNo := PostedSalesNo(SalesDocumentType, DocumentNo, SalesHeader."Last Posting No.");
        if PostedNo = '' then
            Error(PostedNoMissingErr, DocumentNo);
    end;

    local procedure PostPurchaseDocument(DocumentTypeText: Text; DocumentNo: Code[20]; var VendorInvoiceNo: Code[35]) PostedNo: Code[20]
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseDocumentType: Enum "Purchase Document Type";
        Failure: Text;
    begin
        PurchaseDocumentType := PurchaseDocumentTypeFromText(DocumentTypeText);
        PurchaseHeader.Get(PurchaseDocumentType, DocumentNo);
        if PurchaseHeader."Vendor Invoice No." = '' then
            PurchaseHeader.Validate("Vendor Invoice No.", DocumentNo);
        PurchaseHeader.Receive := false;
        PurchaseHeader.Invoice := true;
        PurchaseHeader."Print Posted Documents" := false;
        PurchaseHeader.Modify(true);
        VendorInvoiceNo := PurchaseHeader."Vendor Invoice No.";
        PurchaseHeader.SetHideValidationDialog(true);
        Commit();
        ClearLastError();
        if not Codeunit.Run(Codeunit::"Purch.-Post", PurchaseHeader) then begin
            Failure := GetLastErrorText();
            Error(PostFailedErr, DocumentNo, Failure);
        end;
        PostedNo := PostedPurchaseNo(PurchaseDocumentType, DocumentNo, PurchaseHeader."Last Posting No.");
        if PostedNo = '' then
            Error(PostedNoMissingErr, DocumentNo);
    end;

    local procedure BillingLineExists(Partner: Enum "Service Partner"; BillingDocumentType: Enum "Rec. Billing Document Type"; DocumentNo: Code[20]): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange(Partner, Partner);
        BillingLine.SetRange("Document Type", BillingDocumentType);
        BillingLine.SetRange("Document No.", DocumentNo);
        exit(not BillingLine.IsEmpty());
    end;

    local procedure BillingArchiveExists(Partner: Enum "Service Partner"; BillingDocumentType: Enum "Rec. Billing Document Type"; DocumentNo: Code[20]): Boolean
    var
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingLineArchive.SetRange(Partner, Partner);
        BillingLineArchive.SetRange("Document Type", BillingDocumentType);
        BillingLineArchive.SetRange("Document No.", DocumentNo);
        exit(not BillingLineArchive.IsEmpty());
    end;

    local procedure OpenHeaderExists(Partner: Enum "Service Partner"; BillingDocumentType: Enum "Rec. Billing Document Type"; DocumentNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
        PurchaseHeader: Record "Purchase Header";
    begin
        if Partner = Enum::"Service Partner"::Customer then
            exit(SalesHeader.Get(SalesDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo));
        exit(PurchaseHeader.Get(PurchaseDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo));
    end;

    local procedure PostedSalesNo(DocumentType: Enum "Sales Document Type"; DocumentNo: Code[20]; LastPostingNo: Code[20]): Code[20]
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if LastPostingNo <> '' then
            exit(LastPostingNo);
        if DocumentType = DocumentType::Invoice then begin
            if SalesInvoiceHeader.Get(DocumentNo) then
                exit(SalesInvoiceHeader."No.");
            SalesInvoiceHeader.SetRange("Pre-Assigned No.", DocumentNo);
            if SalesInvoiceHeader.FindLast() then
                exit(SalesInvoiceHeader."No.");
        end else begin
            if SalesCrMemoHeader.Get(DocumentNo) then
                exit(SalesCrMemoHeader."No.");
            SalesCrMemoHeader.SetRange("Pre-Assigned No.", DocumentNo);
            if SalesCrMemoHeader.FindLast() then
                exit(SalesCrMemoHeader."No.");
        end;
    end;

    local procedure PostedPurchaseNo(DocumentType: Enum "Purchase Document Type"; DocumentNo: Code[20]; LastPostingNo: Code[20]): Code[20]
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
    begin
        if LastPostingNo <> '' then
            exit(LastPostingNo);
        if DocumentType = DocumentType::Invoice then begin
            if PurchInvHeader.Get(DocumentNo) then
                exit(PurchInvHeader."No.");
            PurchInvHeader.SetRange("Pre-Assigned No.", DocumentNo);
            if PurchInvHeader.FindLast() then
                exit(PurchInvHeader."No.");
        end else begin
            if PurchCrMemoHeader.Get(DocumentNo) then
                exit(PurchCrMemoHeader."No.");
            PurchCrMemoHeader.SetRange("Pre-Assigned No.", DocumentNo);
            if PurchCrMemoHeader.FindLast() then
                exit(PurchCrMemoHeader."No.");
        end;
    end;

    local procedure PendingDocument(PartnerText: Text; DocumentTypeText: Text; DocumentNo: Code[20]) PendingJson: JsonObject
    begin
        PendingJson.Add('partner', PartnerText);
        PendingJson.Add('documentType', DocumentTypeText);
        PendingJson.Add('documentNo', DocumentNo);
    end;

    local procedure NormalizePartner(PartnerText: Text): Text
    begin
        case UpperCase(PartnerText) of
            'CUSTOMER':
                exit(CustomerTok);
            'VENDOR':
                exit(VendorTok);
            else
                Error(InvalidPartnerErr);
        end;
    end;

    local procedure NormalizeDocumentType(DocumentTypeText: Text): Text
    begin
        case UpperCase(DocumentTypeText) of
            'INVOICE':
                exit(InvoiceTok);
            'CREDIT MEMO':
                exit(CreditMemoTok);
            else
                Error(InvalidDocumentTypeErr);
        end;
    end;

    local procedure PartnerFromText(PartnerText: Text): Enum "Service Partner"
    begin
        if PartnerText = VendorTok then
            exit(Enum::"Service Partner"::Vendor);
        exit(Enum::"Service Partner"::Customer);
    end;

    local procedure BillingDocumentTypeFromText(DocumentTypeText: Text): Enum "Rec. Billing Document Type"
    begin
        if DocumentTypeText = CreditMemoTok then
            exit(Enum::"Rec. Billing Document Type"::"Credit Memo");
        exit(Enum::"Rec. Billing Document Type"::Invoice);
    end;

    local procedure SalesDocumentTypeFromText(DocumentTypeText: Text): Enum "Sales Document Type"
    begin
        if DocumentTypeText = CreditMemoTok then
            exit(Enum::"Sales Document Type"::"Credit Memo");
        exit(Enum::"Sales Document Type"::Invoice);
    end;

    local procedure PurchaseDocumentTypeFromText(DocumentTypeText: Text): Enum "Purchase Document Type"
    begin
        if DocumentTypeText = CreditMemoTok then
            exit(Enum::"Purchase Document Type"::"Credit Memo");
        exit(Enum::"Purchase Document Type"::Invoice);
    end;
}
