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
        DescriptionLbl: Label 'Posts unposted sales and purchase documents that a Subscription Billing run created, through Business Central''s own posting path. Refuses a document that run did not create.', MaxLength = 250, Comment = 'is-IS=Bókar óbókuð sölu- og innkaupaskjöl sem reikningskeyrsla áskrifta bjó til, með eigin bókunarleið Business Central. Hafnar skjali sem sú keyrsla bjó ekki til.';
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
        MissingVendorInvoiceNoErr: Label 'Purchase %1 %2 has no vendor document number. Nothing was posted.', Comment = '%1 = document type, %2 = document number||is-IS=Innkaupaskjalið %1 %2 hefur ekkert skjalanúmer lánardrottins. Ekkert var bókað.';
        MissingVendorInvoiceNoExpectedTxt: Label 'The vendor''s own invoice or credit memo number, at most 35 characters.', Comment = 'is-IS=Eigið reiknings- eða kreditnótunúmer lánardrottins, í mesta lagi 35 stafir.';
        MissingVendorInvoiceNoNextStepTxt: Label 'Send vendorInvoiceNo on the document entry with the number on the vendor''s invoice or credit memo, then call again.', Comment = 'is-IS=Sendu vendorInvoiceNo á færslu skjalsins með númerinu á reikningi eða kreditnótu lánardrottins og kallaðu svo aftur.';
        SharedVendorInvoiceNoErr: Label 'The top-level vendorInvoiceNo can be used for one purchase document only, and %1 purchase documents need it. Send vendorInvoiceNo on each document entry instead.', Comment = '%1 = number of purchase documents||is-IS=vendorInvoiceNo á efsta stigi má aðeins nota fyrir eitt innkaupaskjal en %1 innkaupaskjöl þurfa það. Sendu vendorInvoiceNo á hverja skjalafærslu í staðinn.';
        VendorInvoiceNoForCustomerErr: Label 'vendorInvoiceNo is read for purchase documents only, and document %1 is a sales document.', Comment = '%1 = document number||is-IS=vendorInvoiceNo er aðeins lesið fyrir innkaupaskjöl og skjal %1 er söluskjal.';
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
        KeywordsLbl: Label 'post billing documents, post subscription invoices, post unposted billing invoices, post purchase documents from billing, book the invoices, post the billing run, post vendor invoices from contracts, post sales invoices from contracts', Comment = 'is-IS=bóka reikningsskjöl, bóka áskriftarreikninga, bóka óbókaða reikninga úr reikningagerð, bóka innkaupaskjöl úr reikningagerð, bóka reikningana, bóka reikningakeyrsluna, bóka lánardrottnareikninga af samningum, bóka sölureikninga af samningum';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Post billing documents: posts unposted sales or purchase documents that a Subscription Billing run created. Irreversible, and it always commits. Create the documents first with Subscription.Billing.CreateDocuments, which can post sales documents itself but never purchase documents. A document that billing did not create is posted with Sales.Document.Post or Purch.Document.Post instead.', Comment = 'is-IS=Bóka reikningsskjöl: bókar óbókuð sölu- eða innkaupaskjöl sem reikningakeyrsla áskrifta bjó til. Óafturkræf aðgerð og hún staðfestir alltaf. Fyrst þarf að stofna skjölin með Subscription.Billing.CreateDocuments, sem getur sjálf bókað söluskjöl en aldrei innkaupaskjöl. Skjal sem reikningagerðin bjó ekki til er bókað með Sales.Document.Post eða Purch.Document.Post.';
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
        Examples.Add(ContractMgt.Example('Post a billing purchase invoice with the vendor''s invoice number',
            '{"type":"Subscription.Billing.PostDocuments","data":{"documents":[{"partner":"Vendor","documentType":"Invoice","documentNo":"PI-000045","vendorInvoiceNo":"V-2026-0912"}]}}',
            '{"status":"Success","postedCount":1,"documents":[{"partner":"Vendor","documentType":"Invoice","documentNo":"PI-000045","postedDocumentNo":"PPI-000045","posted":true,"vendorInvoiceNo":"V-2026-0912"}]}'));
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
            'An already posted document is refused. A purchase document needs the vendor''s own document number: send vendorInvoiceNo on its entry (or once at the top level when only one purchase document needs it); ' +
            'it is validated into Vendor Invoice No. on an invoice and Vendor Cr. Memo No. on a credit memo. A purchase document that has no such number and gets none is refused before anything is posted. ' +
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
        if not Helper.ValidateRequest(Argument) then
            exit;
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
        SharedVendorInvoiceNo: Text;
        MissingDocumentType: Text;
        MissingDocumentNo: Code[20];
    begin
        if not PostingGate.AssertCanPost(Argument) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if not Helper.TryGetArray(RequestJson, 'documents', Documents) then
            Error(MissingDocumentsErr, 'documents');
        if Documents.Count() = 0 then
            Error(EmptyDocumentsErr);
        SharedVendorInvoiceNo := ReadVendorInvoiceNo(RequestJson);

        Pending := ValidateDocuments(Documents, SharedVendorInvoiceNo);
        // A purchase document without a vendor document number is answered before anything is posted.
        // The number is the vendor's own; this call never invents one from the document number.
        if FindMissingVendorInvoiceNo(Pending, MissingDocumentType, MissingDocumentNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingVendorInvoiceNoErr, MissingDocumentType, MissingDocumentNo),
                'vendorInvoiceNo', '', MissingVendorInvoiceNoExpectedTxt, MissingVendorInvoiceNoNextStepTxt);
            exit;
        end;
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

    local procedure ValidateDocuments(Documents: JsonArray; SharedVendorInvoiceNo: Text) Pending: List of [JsonObject]
    var
        VendorInvoiceNo: Text;
        SharedUseCount: Integer;
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

            VendorInvoiceNo := ReadVendorInvoiceNo(DocumentJson);
            if (VendorInvoiceNo <> '') and (Partner = Enum::"Service Partner"::Customer) then
                Error(VendorInvoiceNoForCustomerErr, DocumentNo);
            if Partner = Enum::"Service Partner"::Vendor then
                if VendorInvoiceNo = '' then
                    if StoredVendorDocumentNo(DocumentTypeText, DocumentNo) = '' then
                        if SharedVendorInvoiceNo <> '' then begin
                            VendorInvoiceNo := SharedVendorInvoiceNo;
                            SharedUseCount += 1;
                        end;
            Pending.Add(PendingDocument(PartnerText, DocumentTypeText, DocumentNo, VendorInvoiceNo));
        end;
        if SharedUseCount > 1 then
            Error(SharedVendorInvoiceNoErr, SharedUseCount);
    end;

    local procedure ReadVendorInvoiceNo(Json: JsonObject) VendorInvoiceNo: Text
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        VendorInvoiceNo := Helper.GetText(Json, 'vendorInvoiceNo', false).Trim();
        if StrLen(VendorInvoiceNo) > MaxStrLen(PurchaseHeader."Vendor Invoice No.") then
            Error(ValueTooLongErr, 'vendorInvoiceNo', MaxStrLen(PurchaseHeader."Vendor Invoice No."));
    end;

    /// <summary>The vendor document number already on the open purchase document: Vendor Invoice No. on an invoice, Vendor Cr. Memo No. on a credit memo.</summary>
    local procedure StoredVendorDocumentNo(DocumentTypeText: Text; DocumentNo: Code[20]): Code[35]
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.SetLoadFields("Vendor Invoice No.", "Vendor Cr. Memo No.");
        if not PurchaseHeader.Get(PurchaseDocumentTypeFromText(DocumentTypeText), DocumentNo) then
            exit('');
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then
            exit(PurchaseHeader."Vendor Cr. Memo No.");
        exit(PurchaseHeader."Vendor Invoice No.");
    end;

    local procedure FindMissingVendorInvoiceNo(Pending: List of [JsonObject]; var MissingDocumentType: Text; var MissingDocumentNo: Code[20]): Boolean
    var
        PendingJson: JsonObject;
        DocumentTypeText: Text;
        DocumentNo: Code[20];
    begin
        foreach PendingJson in Pending do
            if Helper.GetText(PendingJson, 'partner', true) = VendorTok then
                if Helper.GetText(PendingJson, 'vendorInvoiceNo', false) = '' then begin
                    DocumentTypeText := Helper.GetText(PendingJson, 'documentType', true);
                    DocumentNo := CopyStr(Helper.GetText(PendingJson, 'documentNo', true), 1, MaxStrLen(DocumentNo));
                    if StoredVendorDocumentNo(DocumentTypeText, DocumentNo) = '' then begin
                        MissingDocumentType := DocumentTypeText;
                        MissingDocumentNo := DocumentNo;
                        exit(true);
                    end;
                end;
        exit(false);
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
        VendorInvoiceNo := CopyStr(Helper.GetText(PendingJson, 'vendorInvoiceNo', false), 1, MaxStrLen(VendorInvoiceNo));
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
        // Validate, not a direct assignment: OnValidate runs the vendor's duplicate document number check.
        if VendorInvoiceNo <> '' then
            if PurchaseDocumentType = PurchaseDocumentType::"Credit Memo" then
                PurchaseHeader.Validate("Vendor Cr. Memo No.", VendorInvoiceNo)
            else
                PurchaseHeader.Validate("Vendor Invoice No.", VendorInvoiceNo);
        PurchaseHeader.Receive := false;
        PurchaseHeader.Invoice := true;
        PurchaseHeader."Print Posted Documents" := false;
        PurchaseHeader.Modify(true);
        if PurchaseDocumentType = PurchaseDocumentType::"Credit Memo" then
            VendorInvoiceNo := PurchaseHeader."Vendor Cr. Memo No."
        else
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
        if Partner = Enum::"Service Partner"::Customer then begin
            SalesHeader.SetLoadFields("No.");
            exit(SalesHeader.Get(SalesDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo));
        end;
        PurchaseHeader.SetLoadFields("No.");
        exit(PurchaseHeader.Get(PurchaseDocumentTypeFromText(Helper.FormatDocumentType(BillingDocumentType)), DocumentNo));
    end;

    local procedure PostedSalesNo(DocumentType: Enum "Sales Document Type"; DocumentNo: Code[20]; LastPostingNo: Code[20]): Code[20]
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if LastPostingNo <> '' then
            exit(LastPostingNo);
        SalesInvoiceHeader.SetLoadFields("No.");
        SalesCrMemoHeader.SetLoadFields("No.");
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
        PurchInvHeader.SetLoadFields("No.");
        PurchCrMemoHeader.SetLoadFields("No.");
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

    local procedure PendingDocument(PartnerText: Text; DocumentTypeText: Text; DocumentNo: Code[20]; VendorInvoiceNo: Text) PendingJson: JsonObject
    begin
        PendingJson.Add('partner', PartnerText);
        PendingJson.Add('documentType', DocumentTypeText);
        PendingJson.Add('documentNo', DocumentNo);
        PendingJson.Add('vendorInvoiceNo', VendorInvoiceNo);
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
