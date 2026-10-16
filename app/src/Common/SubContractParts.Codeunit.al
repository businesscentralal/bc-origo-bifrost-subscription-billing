namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Builds the contract chapters of the Subscription Billing message types: envelope, target,
/// parameters, response, errors, effect, related and workflow, per message type name, plus the
/// notes text several types share. What a single type alone says (overview, notes, examples)
/// lives on its own implementation codeunit.
/// </summary>
codeunit 10035075 "Sub Contract Parts ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";

    /// <summary>Builds the request envelope: how the subject is read and whether data is required.</summary>
    procedure GetEnvelope(MessageType: Text) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
        DataKey: Text;
        SubjectForm: Text;
    begin
        if GetSubjectKey(MessageType, DataKey, SubjectForm) then begin
            Subject.Add('use', 'optional');
            Forms.Add('string');
            Subject.Add('forms', Forms);
            if MessageType = 'Subscription.Usage.Process' then
                Subject.Add('description', 'The Usage Data Import entry number, written as a whole number. When set it is used instead of data.usageDataImportEntryNo; a subject that is not a whole number is refused.')
            else
                Subject.Add('description', 'The ' + SubjectForm + '. When set it is used instead of data.' + DataKey + ', and it may be at most 20 characters long.');
        end else begin
            Subject.Add('use', 'notUsed');
            Subject.Add('description', 'The subject is not read by this message type.');
        end;
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', MessageType in ['Subscription.Line.Create', 'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.Renewal.Extend', 'Subscription.Usage.ImportData', 'Subscription.Billing.PostDocuments', 'Subscription.Contract.MergeLines']);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the record target, in resolution order, when the operation addresses one record.</summary>
    procedure GetTarget(MessageType: Text) Target: JsonArray
    var
        DataKey: Text;
        SubjectForm: Text;
    begin
        if not GetSubjectKey(MessageType, DataKey, SubjectForm) then
            exit;
        Target.Add(ContractMgt.TargetEntry('subject', SubjectForm, 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.' + DataKey, SubjectForm, 'Read when the subject is empty.'));
    end;

    /// <summary>
    /// Builds no parameters. The blocked types call it: they answer every call with an error and read no request.
    /// Every other type calls the parameter procedure of its own domain below, which names its keys literally
    /// so the ContractParameterKeys guard can compare them with the keys the type reads (#26).
    /// </summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    begin
    end;

    /// <summary>The parameters of Subscription.Line.Create.</summary>
    procedure LineCreateParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The Subscription Header to add lines to. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('subscriptionPackageCode', 'string', true, 'The Subscription Package to apply.'));
        Parameters.Add(AsDate(ContractMgt.Parameter('subscriptionLineStartDate', 'string', false, 'Start date for the new lines. Omit to let the package''s own date formula decide.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('subscriptionLineEndDate', 'string', false, 'End date for the new lines. Omit to leave the lines open-ended.')));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('usageBasedBillingPackageLinesOnly', 'boolean', false, 'When true, only the usage-based lines of the package are created.'), false));
    end;

    /// <summary>The parameters of Subscription.Contract.GetLines and Subscription.VendorContract.GetLines.</summary>
    /// <param name="ContractName">The contract record name, Customer Subscription Contract or Vendor Subscription Contract.</param>
    procedure GetLinesParameters(ContractName: Text) Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The ' + ContractName + ' to attach lines to. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', false, 'Restricts the candidate lines to one Subscription Header.'));
        Parameters.Add(ContractMgt.Parameter('subscriptionLineEntryNos', 'array', false, 'Restricts the candidate lines to these Subscription Line entry numbers, written as whole numbers. A number that is not a candidate is ignored.'));
    end;

    /// <summary>The parameters of Subscription.Contract.MergeLines.</summary>
    procedure MergeLinesParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The Customer Subscription Contract whose lines are merged. May be supplied as the subject instead. Every line must belong to this contract.'));
        Parameters.Add(ContractMgt.Parameter('lines', 'array', true, 'The contract lines to merge, at least two. Each entry is an object with lineNo. contractNo on an entry is optional and must equal the contract being merged; a different contract is refused.'));
        Parameters.Add(ContractMgt.Parameter('referenceLineNo', 'integer', true, 'Line No. of the line whose Subscription is copied. It replaces the selection page and must be one of the lines.'));
    end;

    /// <summary>The parameters of the four contract invoice types.</summary>
    /// <param name="ContractName">The contract record name, Customer Subscription Contract or Vendor Subscription Contract.</param>
    /// <param name="WithDocumentDates">True for the CreateInvoice types, which read documentDate and postingDate.</param>
    /// <param name="WithVendorInvoiceNo">True for Subscription.VendorContract.CreateInvoice, which reads vendorInvoiceNo.</param>
    procedure InvoiceParameters(ContractName: Text; WithDocumentDates: Boolean; WithVendorInvoiceNo: Boolean) Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The ' + ContractName + ' to bill. May be supplied as the subject instead.'));
        Parameters.Add(AsDate(ContractMgt.Parameter('billingDate', 'string', false, 'Subscription Lines whose Next Billing Date is on or before this date are billed. Defaults to the work date.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('billingToDate', 'string', false, 'Bills complete periods up to this date. Omit to bill each line by its own billing rhythm.')));
        if WithDocumentDates then begin
            Parameters.Add(AsDate(ContractMgt.Parameter('documentDate', 'string', false, 'Document date of the created document. Defaults to the work date.')));
            Parameters.Add(AsDate(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date of the created document. Defaults to the work date.')));
        end;
        if WithVendorInvoiceNo then
            Parameters.Add(ContractMgt.Parameter('vendorInvoiceNo', 'string', false, 'Validated into Vendor Invoice No. on every document this call creates, so the vendor''s duplicate invoice number check applies. Text past 35 characters is cut off.'));
    end;

    /// <summary>The parameters of Subscription.Billing.CreateProposal.</summary>
    procedure BillingProposalParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template to run. May be supplied as the subject instead.'));
        Parameters.Add(AsDate(ContractMgt.Parameter('billingDate', 'string', false, 'Subscription Lines due on or before this date are proposed. Defaults to the work date.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('billingToDate', 'string', false, 'Bills complete periods up to this date. Omit to bill each line by its own billing rhythm.')));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('automatedBilling', 'boolean', false, 'Passed to Microsoft''s billing proposal as its automated billing flag. Leave it at the default for an unattended run.'), true));
    end;

    /// <summary>The parameters of Subscription.Billing.CreateDocuments.</summary>
    procedure BillingDocumentsParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template whose unbilled proposal lines are processed. May be supplied as the subject instead.'));
        Parameters.Add(AsDate(ContractMgt.Parameter('documentDate', 'string', false, 'Document date of the created documents. Defaults to the work date.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date of the created documents. Defaults to the work date.')));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('postDocuments', 'boolean', false, 'When true, the created sales documents are posted. Purchase documents are never posted; post them with Subscription.Billing.PostDocuments.'), false));
        Parameters.Add(AsGroupBy(ContractMgt.Parameter('groupBy', 'string', false, 'Contract creates one document per contract; Customer creates one document per Bill-to Customer No. and needs customer proposal lines. Any casing.')));
    end;

    /// <summary>The parameters of Subscription.Billing.PostDocuments.</summary>
    procedure PostDocumentsParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('documents', 'array', true, 'The documents to post. Each entry is an object with partner (Customer or Vendor), documentType (Invoice or Credit Memo) and documentNo. Every entry is checked before the first document is posted.'));
    end;

    /// <summary>The parameters of Subscription.Billing.PreviewDocuments.</summary>
    procedure BillingPreviewParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template to preview. May be supplied as the subject instead.'));
        Parameters.Add(AsGroupBy(ContractMgt.Parameter('groupBy', 'string', false, 'Contract groups per Subscription Contract No.; Customer groups per Partner No. and needs every pending line to belong to a customer contract. Any casing.')));
        Parameters.Add(WithIntegerDefault(ContractMgt.Parameter('skip', 'integer', false, 'Number of document groups to skip. Must be zero or greater.'), 0));
        Parameters.Add(WithIntegerDefault(ContractMgt.Parameter('take', 'integer', false, 'Maximum number of document groups to return. Zero means the default; a value above 1000 is clamped to 1000. Must be zero or greater.'), 100));
    end;

    /// <summary>The parameters of Subscription.PriceUpdate.SetTemplateFilter.</summary>
    procedure SetTemplateFilterParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('priceUpdateTemplateCode', 'string', true, 'The Price Update Template to change. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('filter', 'string', true, 'A Business Central view, such as WHERE(Subscription Contract No.=FILTER(CC000010)) or a full SORTING(...) WHERE(...) view, of the table the target names. It is normalised before it is stored; a view without filters clears the stored filter.'));
        Parameters.Add(WithAllowed(ContractMgt.Parameter('target', 'string', true, 'Which filter to write, in any casing: contract (Customer or Vendor Subscription Contract, following the template''s Partner), subscription (Subscription Header) or line (Subscription Line).'), 'contract,subscription,line'));
    end;

    /// <summary>The parameters of Subscription.PriceUpdate.CreateProposal.</summary>
    procedure PriceUpdateProposalParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('priceUpdateTemplateCode', 'string', true, 'The Price Update Template to run. May be supplied as the subject instead.'));
        Parameters.Add(AsDate(ContractMgt.Parameter('includeLinesUpToDate', 'string', false, 'Subscription Lines whose Next Price Update is empty or on or before this date are proposed. Defaults to the template''s Include Subscription Contract Lines up to Date Formula applied to the work date; required when the template has no such formula.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('performUpdateOnDate', 'string', false, 'The date the new prices are to take effect. A line''s own Next Billing Date or Next Price Update wins when it is later. Defaults to the template''s Perform Update on Formula applied to the work date.')));
    end;

    /// <summary>The parameters of Subscription.PriceUpdate.Perform.</summary>
    procedure PriceUpdatePerformParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('priceUpdateTemplateCode', 'string', false, 'Performs only the lines of this Price Update Template. May be supplied as the subject instead. Omit it to perform every line of every template, as the Contract Price Update page does.'));
    end;

    /// <summary>The parameters of Subscription.Renewal.Extend.</summary>
    procedure RenewalExtendParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The existing Subscription to extend. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('customerContractNo', 'string', false, 'An existing Customer Subscription Contract to extend onto. At least one of customerContractNo and vendorContractNo is required.'));
        Parameters.Add(ContractMgt.Parameter('vendorContractNo', 'string', false, 'An existing Vendor Subscription Contract to extend onto. At least one of customerContractNo and vendorContractNo is required.'));
        Parameters.Add(ContractMgt.Parameter('subscriptionPackageCodes', 'array', false, 'Subscription Package codes to apply in addition to the item''s standard packages, which Microsoft always applies.'));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('usageBasedBillingPackageLinesOnly', 'boolean', false, 'When true, only usage-based package lines are added.'), false));
        Parameters.Add(WithIntegerDefault(ContractMgt.Parameter('supplierReferenceEntryNo', 'integer', false, 'Links the extension to a supplier reference entry.'), 0));
    end;

    /// <summary>The parameters of Subscription.Renewal.CreateQuote.</summary>
    procedure RenewalQuoteParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The Customer Subscription Contract to renew. May be supplied as the subject instead.'));
    end;

    /// <summary>The parameters of Subscription.Usage.ImportData.</summary>
    procedure UsageImportParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('supplierNo', 'string', true, 'The Usage Data Supplier the file came from. May be supplied as the subject instead.'));
        Parameters.Add(WithTextDefault(ContractMgt.Parameter('fileName', 'string', false, 'File name recorded as Source on the Usage Data Blob.'), 'bifrost-usage.csv'));
        Parameters.Add(ContractMgt.Parameter('content', 'string', false, 'The file content as text, for example a CSV payload. Required unless contentBase64 is given.'));
        Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, 'The file content, base64 encoded, for payloads that are not plain text. Required unless content is given; when both are given, contentBase64 is used.'));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('runProcessing', 'boolean', false, 'When true, the Process Imported Lines step runs right after the import.'), false));
    end;

    /// <summary>The parameters of Subscription.Usage.Process.</summary>
    procedure UsageProcessParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('usageDataImportEntryNo', 'integer', true, 'The Usage Data Import entry to process. May be supplied as the subject instead.'));
        Parameters.Add(WithAllowed(ContractMgt.Parameter('steps', 'array', false, 'The processing steps to run, in the order given. Defaults to ProcessImportedLines, CreateUsageDataBilling, ProcessUsageDataBilling. CreateImportedLines parses the stored file again and is never run by default.'), 'CreateImportedLines,ProcessImportedLines,CreateUsageDataBilling,ProcessUsageDataBilling'));
    end;

    /// <summary>The parameters of Subscription.Deferral.Release.</summary>
    procedure DeferralReleaseParameters() Parameters: JsonArray
    begin
        Parameters.Add(AsDate(ContractMgt.Parameter('postingDate', 'string', false, 'The date the caller expects the release to post under. Must equal the work date, the only date Business Central uses. Defaults to the work date.')));
        Parameters.Add(AsDate(ContractMgt.Parameter('postUntilDate', 'string', false, 'The latest deferral posting date the caller accepts to release. The call is refused when the release would go past it. Must not be later than postingDate; defaults to postingDate.')));
    end;

    /// <summary>The parameters of Subscription.Analysis.Recalculate.</summary>
    procedure AnalysisParameters() Parameters: JsonArray
    begin
        Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Narrows the counts in the response to this Subscription Contract. It does not scope the run: the report always analyses every contract.'));
    end;

    /// <summary>The parameters of Subscription.Import.CreateContracts.</summary>
    procedure ImportParameters() Parameters: JsonArray
    begin
        Parameters.Add(WithAllowed(ContractMgt.Parameter('stages', 'array', false, 'The import stages to run. Defaults to all four. They always run in the fixed order SubscriptionHeaders, CustomerContracts, SubscriptionLines, ContractLines, whatever order is given.'), 'SubscriptionHeaders,CustomerContracts,SubscriptionLines,ContractLines'));
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('allowCommentLines', 'boolean', false, 'When true, staged lines whose Sub_ContractLineType is Comment become contract comment lines in the ContractLines stage. When false, such a row fails with the line type error, because Comment is also the value of a row whose line type was never set.'), false));
    end;

    /// <summary>Builds the fields of the Success answer.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        Fields: JsonArray;
        Children: JsonArray;
        MoreChildren: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        if IsBlocked(MessageType) then begin
            Fields.Add(ContractMgt.ResponseField('status', 'string', 'Never Success: this message type always answers with the error listed under errors.'));
            Response.Add('fields', Fields);
            exit;
        end;
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the operation completed.'));
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'The Subscription Header the lines were added to.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionPackageCode', 'string', 'The applied Subscription Package.'));
                    Fields.Add(ContractMgt.ResponseField('linesCreated', 'integer', 'Number of Subscription Lines the header gained. Zero is still a success, for example when usageBasedBillingPackageLinesOnly filtered out every package line.'));
                    Fields.Add(ContractMgt.ResponseField('createdLines', 'array', 'Entry No. of every Subscription Line this call added.'));
                end;
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract the lines were attached to.'));
                    Fields.Add(ContractMgt.ResponseField('linesAttached', 'integer', 'Number of lines attached. Zero is still a success.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'Entry No. of the attached Subscription Line.'));
                    Children.Add(ContractMgt.ResponseField('contractLineNo', 'integer', 'Line No. of the contract line created for it.'));
                    Fields.Add(FieldWithChildren('attachedLines', 'array', 'One entry per attached line.', Children));
                    if MessageType = 'Subscription.Contract.GetLines' then
                        Fields.Add(ContractMgt.ResponseField('linesSkipped', 'integer', 'Candidate lines left unattached because their Subscription Header''s End-User Customer No. is not the contract''s Sell-to Customer No.'));
                end;
            'Subscription.Contract.MergeLines':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract whose lines were merged.'));
                    Fields.Add(ContractMgt.ResponseField('referenceLineNo', 'integer', 'The line whose Subscription was copied.'));
                    Fields.Add(ContractMgt.ResponseField('closedLineCount', 'integer', 'Number of contract lines closed by the merge.'));
                    Fields.Add(ContractMgt.ResponseField('newLineNo', 'integer', 'Line No. of the open contract line created for the merged Subscription.'));
                    Fields.Add(ContractMgt.ResponseField('newSubscriptionHeaderNo', 'string', 'No. of the merged Subscription.'));
                    Fields.Add(ContractMgt.ResponseField('newSubscriptionLineEntryNo', 'integer', 'Entry No. of the merged Subscription Line.'));
                    Fields.Add(ContractMgt.ResponseField('merged', 'boolean', 'True.'));
                end;
            'Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The billed contract.'));
                    Fields.Add(ContractMgt.ResponseField('billingDate', 'string', 'The billing date used, as YYYY-MM-DD.'));
                    Children.Add(ContractMgt.ResponseField('documentType', 'string', 'Invoice or Credit Memo.'));
                    Children.Add(ContractMgt.ResponseField('documentNo', 'string', 'No. of the unposted document.'));
                    Fields.Add(FieldWithChildren('documents', 'array', 'The unposted documents this call created; empty when nothing was billed.', Children));
                    Fields.Add(ContractMgt.ResponseField('billingLineCount', 'integer', 'Number of billing lines this call created for the contract.'));
                    Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when nothing was billed: either no Subscription Line was due, or the due lines already sit on a billing proposal or an unposted document.'));
                end;
            'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The previewed contract.'));
                    Fields.Add(ContractMgt.ResponseField('billingDate', 'string', 'The billing date used, as YYYY-MM-DD.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'Entry No. of the Subscription Line that would be billed.'));
                    Children.Add(ContractMgt.ResponseField('billingFrom', 'string', 'Start of the billing period, as YYYY-MM-DD.'));
                    Children.Add(ContractMgt.ResponseField('billingTo', 'string', 'End of the billing period, as YYYY-MM-DD.'));
                    Children.Add(ContractMgt.ResponseField('unitPrice', 'string', 'Unit price as a culture-invariant decimal string.'));
                    Children.Add(ContractMgt.ResponseField('amount', 'string', 'Amount as a culture-invariant decimal string.'));
                    Fields.Add(FieldWithChildren('lines', 'array', 'The billing proposal lines the write call would bill.', Children));
                    Fields.Add(ContractMgt.ResponseField('wouldBillLineCount', 'integer', 'Number of entries in lines.'));
                    Fields.Add(ContractMgt.ResponseField('totalAmount', 'string', 'Sum of the line amounts as a culture-invariant decimal string.'));
                    Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when nothing would be billed: no line was due, or the due lines are already on pending proposal lines.'));
                    Fields.Add(ContractMgt.ResponseField('preview', 'boolean', 'Always true.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true: the proposal lines built for the preview were deleted again.'));
                end;
            'Subscription.Billing.CreateProposal':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The Billing Template that was run.'));
                    Fields.Add(ContractMgt.ResponseField('billingDate', 'string', 'The billing date used, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('billingToDate', 'string', 'The billing-to date, as YYYY-MM-DD; empty when it was not given.'));
                    Fields.Add(ContractMgt.ResponseField('proposalLinesCreated', 'integer', 'Number of proposal lines this call added to the template. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('proposalLineCount', 'integer', 'All proposal lines now standing for the template, including earlier ones.'));
                    Fields.Add(ContractMgt.ResponseField('contracts', 'array', 'Contract numbers of all proposal lines now standing for the template.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The processed Billing Template.'));
                    Fields.Add(ContractMgt.ResponseField('billingLinesProcessed', 'integer', 'Number of unbilled proposal lines the run started with.'));
                    Fields.Add(ContractMgt.ResponseField('documentCount', 'integer', 'Number of distinct documents created.'));
                    Children.Add(ContractMgt.ResponseField('documentType', 'string', 'Invoice or Credit Memo.'));
                    Children.Add(ContractMgt.ResponseField('documentNo', 'string', 'No. of the document.'));
                    Children.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract the document bills.'));
                    Children.Add(ContractMgt.ResponseField('posted', 'boolean', 'Present and true only for a document that was posted.'));
                    Fields.Add(FieldWithChildren('documents', 'array', 'One entry per document and contract created by this run.', Children));
                    Fields.Add(ContractMgt.ResponseField('posted', 'boolean', 'Present and true only when postDocuments was true.'));
                    Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when the template had no unbilled proposal lines; the counts are then zero and documents is empty.'));
                end;
            'Subscription.Billing.PostDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('postedCount', 'integer', 'Number of documents this call posted.'));
                    Children.Add(ContractMgt.ResponseField('partner', 'string', 'Customer or Vendor.'));
                    Children.Add(ContractMgt.ResponseField('documentType', 'string', 'Invoice or Credit Memo.'));
                    Children.Add(ContractMgt.ResponseField('documentNo', 'string', 'No. of the document that was posted.'));
                    Children.Add(ContractMgt.ResponseField('postedDocumentNo', 'string', 'No. of the posted sales or purchase document.'));
                    Children.Add(ContractMgt.ResponseField('posted', 'boolean', 'True.'));
                    Children.Add(ContractMgt.ResponseField('vendorInvoiceNo', 'string', 'Present for a vendor document: the Vendor Invoice No. used, filled from the document number when it was blank.'));
                    Fields.Add(FieldWithChildren('documents', 'array', 'One entry per document this call posted.', Children));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The previewed Billing Template.'));
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', 'The skip value used.'));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', 'The page size used, after defaulting and clamping.'));
                    Fields.Add(ContractMgt.ResponseField('billingLineCount', 'integer', 'Number of unbilled proposal lines under the template.'));
                    Fields.Add(ContractMgt.ResponseField('documentCount', 'integer', 'Number of document groups, not paged.'));
                    Children.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract of the group; empty when groupBy is Customer, because such a document can span several contracts.'));
                    Children.Add(ContractMgt.ResponseField('partnerNo', 'string', 'Partner No. of the group.'));
                    Children.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of proposal lines in the group.'));
                    Children.Add(ContractMgt.ResponseField('totalAmount', 'string', 'Sum of the line amounts as a culture-invariant decimal string.'));
                    Fields.Add(FieldWithChildren('documents', 'array', 'The current page of document groups, in the order the proposal lines first name them.', Children));
                    Fields.Add(ContractMgt.ResponseField('hasMore', 'boolean', 'True when more groups follow this page.'));
                    MoreChildren.Add(ContractMgt.ResponseField('code', 'string', 'MixedPartners or UpdateRequired.'));
                    MoreChildren.Add(ContractMgt.ResponseField('message', 'string', 'What the condition means for a real run.'));
                    MoreChildren.Add(ContractMgt.ResponseField('customerLineCount', 'integer', 'MixedPartners only: pending customer lines.'));
                    MoreChildren.Add(ContractMgt.ResponseField('vendorLineCount', 'integer', 'MixedPartners only: pending vendor lines.'));
                    MoreChildren.Add(ContractMgt.ResponseField('lineCount', 'integer', 'UpdateRequired only: lines flagged Update Required.'));
                    Fields.Add(FieldWithChildren('warnings', 'array', 'Conditions that would stop or complicate Subscription.Billing.CreateDocuments.', MoreChildren));
                    Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when the template has no unbilled proposal lines.'));
                    Fields.Add(ContractMgt.ResponseField('preview', 'boolean', 'Always true.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true; nothing was written.'));
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    Fields.Add(ContractMgt.ResponseField('priceUpdateTemplateCode', 'string', 'The changed Price Update Template.'));
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The written filter, in lower case: contract, subscription or line.'));
                    Fields.Add(ContractMgt.ResponseField('filter', 'string', 'The normalised view that was written.'));
                    Children.Add(ContractMgt.ResponseField('contract', 'string', 'The stored contract filter; empty when none is set.'));
                    Children.Add(ContractMgt.ResponseField('subscription', 'string', 'The stored subscription filter; empty when none is set.'));
                    Children.Add(ContractMgt.ResponseField('line', 'string', 'The stored line filter; empty when none is set.'));
                    Fields.Add(FieldWithChildren('filters', 'object', 'All three filters of the template after the write.', Children));
                end;
            'Subscription.PriceUpdate.CreateProposal':
                begin
                    Fields.Add(ContractMgt.ResponseField('priceUpdateTemplateCode', 'string', 'The Price Update Template that was run.'));
                    Fields.Add(ContractMgt.ResponseField('priceUpdateMethod', 'string', 'The template''s Price Update Method: Calculation Base by %, Price by % or Recent Item Prices.'));
                    Fields.Add(ContractMgt.ResponseField('includeLinesUpToDate', 'string', 'The include-up-to date used, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('performUpdateOnDate', 'string', 'The perform date used, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('linesCreated', 'integer', 'Contract Price Update Lines this call created. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('linesNotCreated', 'integer', 'Matching Subscription Lines left out because their new calculation base would be zero or less.'));
                    Fields.Add(ContractMgt.ResponseField('proposalLineCount', 'integer', 'All Contract Price Update Lines now standing for the template, including earlier ones.'));
                    Children.Add(ContractMgt.ResponseField('entryNo', 'integer', 'Entry No. of the Contract Price Update Line.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'Entry No. of the Subscription Line it updates.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'The Subscription the line belongs to.'));
                    Children.Add(ContractMgt.ResponseField('contractNo', 'string', 'The Subscription Contract of the line.'));
                    Children.Add(ContractMgt.ResponseField('partnerNo', 'string', 'Sell-to Customer No. or Pay-to Vendor No. of the contract.'));
                    Children.Add(ContractMgt.ResponseField('oldPrice', 'string', 'Price before the update, as a culture-invariant decimal string; so are all the amounts that follow.'));
                    Children.Add(ContractMgt.ResponseField('newPrice', 'string', 'Price after the update.'));
                    Children.Add(ContractMgt.ResponseField('oldAmount', 'string', 'Amount before the update.'));
                    Children.Add(ContractMgt.ResponseField('newAmount', 'string', 'Amount after the update, net of the line discount.'));
                    Children.Add(ContractMgt.ResponseField('additionalAmount', 'string', 'newAmount minus oldAmount.'));
                    Children.Add(ContractMgt.ResponseField('oldCalculationBase', 'string', 'Calculation Base Amount before the update.'));
                    Children.Add(ContractMgt.ResponseField('newCalculationBase', 'string', 'Calculation Base Amount after the update.'));
                    Children.Add(ContractMgt.ResponseField('newCalculationBasePct', 'string', 'Calculation Base % after the update.'));
                    Children.Add(ContractMgt.ResponseField('discountPct', 'string', 'The line discount %, unchanged.'));
                    Children.Add(ContractMgt.ResponseField('discountAmount', 'string', 'The line discount amount on the new amount.'));
                    Children.Add(ContractMgt.ResponseField('performUpdateOn', 'string', 'The date the update takes effect, as YYYY-MM-DD.'));
                    Children.Add(ContractMgt.ResponseField('nextPriceUpdate', 'string', 'The Next Price Update the line will carry, as YYYY-MM-DD.'));
                    Fields.Add(FieldWithChildren('lines', 'array', 'The lines this call created, at most 1000.', Children));
                    Fields.Add(ContractMgt.ResponseField('hasMore', 'boolean', 'True when more than 1000 lines were created; the rest are in Sub. Contr. Price Update Line.'));
                    Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when no line was created.'));
                end;
            'Subscription.PriceUpdate.Perform':
                begin
                    Fields.Add(ContractMgt.ResponseField('error', 'string', 'Present only when a line failed; status is then Error, although the other lines were performed and committed.'));
                    Fields.Add(ContractMgt.ResponseField('rolledBack', 'boolean', 'Present only when a line failed; always false.'));
                    Fields.Add(ContractMgt.ResponseField('priceUpdateTemplateCode', 'string', 'The template whose lines were performed; empty when every template''s lines were.'));
                    Fields.Add(ContractMgt.ResponseField('linesProcessed', 'integer', 'Contract Price Update Lines processed.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionLinesUpdated', 'integer', 'Lines whose Subscription Line got its new prices now.'));
                    Fields.Add(ContractMgt.ResponseField('plannedSubscriptionLinesCreated', 'integer', 'Lines that wrote a Planned Subscription Line instead.'));
                    Fields.Add(ContractMgt.ResponseField('linesSkipped', 'integer', 'Lines whose Subscription Line already had a Planned Subscription Line; nothing changed and the price update line was deleted.'));
                    Fields.Add(ContractMgt.ResponseField('linesFailed', 'integer', 'Lines that failed and are still in the proposal.'));
                    Children.Add(ContractMgt.ResponseField('entryNo', 'integer', 'Entry No. of the Contract Price Update Line.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'Entry No. of the Subscription Line.'));
                    Children.Add(ContractMgt.ResponseField('outcome', 'string', 'Updated, Planned, SkippedPlannedExists or Failed.'));
                    Children.Add(ContractMgt.ResponseField('error', 'string', 'Present only when outcome is Failed.'));
                    Fields.Add(FieldWithChildren('results', 'array', 'One entry per processed line, in entry number order.', Children));
                end;
            'Subscription.Renewal.Extend':
                begin
                    Fields.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'The extended Subscription.'));
                    Fields.Add(ContractMgt.ResponseField('customerContractNo', 'string', 'Present only when a customer contract was extended, as are the three custContractLine fields.'));
                    Fields.Add(ContractMgt.ResponseField('custContractLineCountBefore', 'integer', 'Cust. Sub. Contract Lines on the contract before the call.'));
                    Fields.Add(ContractMgt.ResponseField('custContractLineCountAfter', 'integer', 'Cust. Sub. Contract Lines on the contract after the call.'));
                    Fields.Add(ContractMgt.ResponseField('custContractLinesCreated', 'integer', 'The difference of the two counts.'));
                    Fields.Add(ContractMgt.ResponseField('vendorContractNo', 'string', 'Present only when a vendor contract was extended, as are the three vendContractLine fields.'));
                    Fields.Add(ContractMgt.ResponseField('vendContractLineCountBefore', 'integer', 'Vend. Sub. Contract Lines on the contract before the call.'));
                    Fields.Add(ContractMgt.ResponseField('vendContractLineCountAfter', 'integer', 'Vend. Sub. Contract Lines on the contract after the call.'));
                    Fields.Add(ContractMgt.ResponseField('vendContractLinesCreated', 'integer', 'The difference of the two counts.'));
                    Fields.Add(ContractMgt.ResponseField('newSubscriptionLineEntryNos', 'array', 'Entry No. of every Subscription Line the call added to the Subscription, whichever contract it went to.'));
                    Fields.Add(ContractMgt.ResponseField('newSubscriptionLineCount', 'integer', 'Number of entries in newSubscriptionLineEntryNos.'));
                end;
            'Subscription.Renewal.CreateQuote':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The renewed contract.'));
                    Fields.Add(ContractMgt.ResponseField('renewalLinesCreated', 'integer', 'Number of Sub. Contract Renewal Lines built for the quote.'));
                    Fields.Add(ContractMgt.ResponseField('salesQuoteNo', 'string', 'No. of the created renewal sales quote.'));
                end;
            'Subscription.Usage.ImportData':
                begin
                    Fields.Add(ContractMgt.ResponseField('usageDataImportEntryNo', 'integer', 'Entry No. of the created Usage Data Import.'));
                    Fields.Add(ContractMgt.ResponseField('processingStatus', 'string', 'Processing Status of the import after the last step: None, Ok, Error or Closed.'));
                    Fields.Add(ContractMgt.ResponseField('reason', 'string', 'The import''s reason text when processingStatus is Error; empty otherwise.'));
                    Fields.Add(ContractMgt.ResponseField('importedLineCount', 'integer', 'Usage Data Generic Import rows now standing for the import.'));
                end;
            'Subscription.Usage.Process':
                begin
                    Fields.Add(ContractMgt.ResponseField('usageDataImportEntryNo', 'integer', 'The processed Usage Data Import entry.'));
                    Children.Add(ContractMgt.ResponseField('step', 'string', 'The step name.'));
                    Children.Add(ContractMgt.ResponseField('status', 'string', 'Processing Status after the step: None, Ok, Error or Closed.'));
                    Children.Add(ContractMgt.ResponseField('reason', 'string', 'Why the step failed; empty when it did not.'));
                    Fields.Add(FieldWithChildren('steps', 'array', 'One entry per step, in the order they ran.', Children));
                    Fields.Add(ContractMgt.ResponseField('processingStatus', 'string', 'Processing Status of the entry after the last step.'));
                    Fields.Add(ContractMgt.ResponseField('usageDataBillingCount', 'integer', 'Usage Data Billing rows of the entry.'));
                    Fields.Add(ContractMgt.ResponseField('usageDataBillingErrorCount', 'integer', 'Usage Data Billing rows of the entry whose Processing Status is Error.'));
                end;
            'Subscription.Deferral.Release':
                begin
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'The posting date, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('postUntilDate', 'string', 'The post-until date, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('customerDeferralsReleased', 'integer', 'Customer deferrals released, counted over every unreleased deferral, not only those in the window.'));
                    Fields.Add(ContractMgt.ResponseField('vendorDeferralsReleased', 'integer', 'Vendor deferrals released, counted the same way.'));
                    Fields.Add(ContractMgt.ResponseField('totalDeferralsReleased', 'integer', 'The sum of the two. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('releasedOutsideRequestedWindow', 'integer', 'Present only when deferrals posted after postUntilDate were released anyway.'));
                    Fields.Add(ContractMgt.ResponseField('warning', 'string', 'Present only together with releasedOutsideRequestedWindow.'));
                end;
            'Subscription.Analysis.Recalculate':
                begin
                    Fields.Add(ContractMgt.ResponseField('analysisDate', 'string', 'The system date the report analysed as of, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('entriesCreated', 'integer', 'Analysis entries this call added, narrowed to contractNo when given. Zero when every line was already analysed this month.'));
                    Fields.Add(ContractMgt.ResponseField('totalEntries', 'integer', 'All analysis entries on file, narrowed to contractNo when given.'));
                end;
            'Subscription.Import.CreateContracts':
                begin
                    Children.Add(ContractMgt.ResponseField('stage', 'string', 'The stage name.'));
                    Children.Add(ContractMgt.ResponseField('processed', 'integer', 'Unprocessed staging rows the stage found.'));
                    Children.Add(ContractMgt.ResponseField('succeeded', 'integer', 'Rows that created their record.'));
                    Children.Add(ContractMgt.ResponseField('failed', 'integer', 'Rows that failed; their error text is stored on the staging row.'));
                    Children.Add(ContractMgt.ResponseField('skipped', 'integer', 'Rows the stage left alone: in SubscriptionLines the Comment rows of an allowCommentLines call, in ContractLines the rows the SubscriptionLines stage of the same call failed. Always 0 for the other stages.'));
                    Fields.Add(FieldWithChildren('stages', 'array', 'One entry per stage that ran.', Children));
                    MoreChildren.Add(ContractMgt.ResponseField('stage', 'string', 'The stage the row failed in.'));
                    MoreChildren.Add(ContractMgt.ResponseField('key', 'string', 'Entry No. of the staging row.'));
                    MoreChildren.Add(ContractMgt.ResponseField('error', 'string', 'The error text.'));
                    Fields.Add(FieldWithChildren('errors', 'array', 'Failed rows, at most the first 50 across all stages.', MoreChildren));
                    Fields.Add(ContractMgt.ResponseField('errorsNote', 'string', 'Present only when more than 50 rows failed.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the errors the implementation answers with.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    begin
        case MessageType of
            'Subscription.Contract.UpdateLineDates':
                Errors.Add(ContractMgt.TextErrorEntry('Subscription.Contract.UpdateLineDates has no supported public API in this Business Central version. ...', 'Always: the Microsoft procedures that roll Subscription Line dates forward are internal.', 'Run the Update Subscription Line Dates action on the contract in the Business Central client, or schedule Microsoft''s own job queue entry for the batch job.'));
            'Subscription.Contract.UpdateExchangeRates':
                Errors.Add(ContractMgt.TextErrorEntry('Subscription.Contract.UpdateExchangeRates has no supported public API in this Business Central version. ...', 'Always: the Microsoft procedure is internal, and its flow is unsafe unattended.', 'Use the Update Exchange Rates action on the contract in the Business Central client.'));
        end;
        if IsBlocked(MessageType) then
            exit;

        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'A Business Central or Subscription Billing validation error prevented completion.', 'Correct the data or setup named by the error and retry.'));
        AddParameterErrors(MessageType, Errors);
        AddLookupErrors(MessageType, Errors);
        AddTypeErrors(MessageType, Errors);
    end;

    /// <summary>Builds the operation effect.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    var
        Preconditions: JsonArray;
    begin
        if MessageType in ['Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.PreviewDocuments'] then
            Effect.Add('effect', 'read')
        else
            if MessageType in ['Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PostDocuments', 'Subscription.Renewal.Extend', 'Subscription.Renewal.CreateQuote', 'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts', 'Subscription.PriceUpdate.Perform', 'Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates'] then
                Effect.Add('effect', 'irreversible')
            else
                Effect.Add('effect', 'write');
        Effect.Add('changes', GetChanges(MessageType));
        Effect.Add('idempotent', MessageType in ['Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.PreviewDocuments', 'Subscription.Analysis.Recalculate']);
        if MessageType = 'Subscription.Billing.PostDocuments' then
            Effect.Add('permissionSet', 'BIFROST SubPost ori')
        else
            Effect.Add('permissionSet', 'BIFROST SubBil ori');
        Preconditions.Add('Microsoft Subscription Billing is installed and set up, and the caller has the permissions on its tables.');
        case MessageType of
            'Subscription.Line.Create':
                Preconditions.Add('The Subscription Header has a Source No.');
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                Preconditions.Add('No other contract has template-less billing proposal lines that are not on a document yet.');
            'Subscription.Billing.CreateDocuments':
                Preconditions.Add('The template has unbilled proposal lines (Subscription.Billing.CreateProposal), all for customers or all for vendors.');
            'Subscription.Billing.PostDocuments':
                begin
                    Preconditions.Add('Each document was created by a Subscription Billing run, so it stands on Billing Line or Billing Line Archive.');
                    Preconditions.Add('The caller holds permission set BIFROST SubPost ori.');
                end;
            'Subscription.Renewal.CreateQuote':
                Preconditions.Add('The contract has Subscription Lines with an end date.');
            'Subscription.Usage.Process':
                Preconditions.Add('The Usage Data Import entry exists and is not Closed.');
            'Subscription.Deferral.Release':
                Preconditions.Add('postingDate is the session work date, and no unreleased deferral posts after postUntilDate up to the work date.');
            'Subscription.PriceUpdate.CreateProposal':
                Preconditions.Add('The Price Update Template exists, and includeLinesUpToDate is given or the template has an Include Subscription Contract Lines up to Date Formula.');
            'Subscription.PriceUpdate.Perform':
                Preconditions.Add('Contract Price Update Lines exist (Subscription.PriceUpdate.CreateProposal), for the named template when one is given. The run cannot be undone: the old prices survive only in the Subscription Line Archive.');
        end;
        AddSetupPreconditions(MessageType, Preconditions);
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Builds links to adjacent message types.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    begin
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach the created lines to a customer contract.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Bill the contract once the lines are attached.'));
                end;
            'Subscription.Contract.GetLines':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Line.Create', 'Create Subscription Lines first when none exist.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create an invoice after attaching lines.'));
                end;
            'Subscription.Contract.MergeLines':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach lines to the customer contract before merging them.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Bill the contract after the lines are merged.'));
                end;
            'Subscription.Contract.CreateInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.PreviewInvoice', 'See what would be billed without creating a document.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach eligible lines before billing.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Bill many contracts at once through a Billing Template.'));
                end;
            'Subscription.Contract.PreviewInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create the invoice for real.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach eligible lines before billing.'));
                end;
            'Subscription.Contract.UpdateLineDates':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.UpdateExchangeRates', 'Also blocked in this version, for a different reason.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create an invoice once line dates are current.'));
                end;
            'Subscription.Contract.UpdateExchangeRates':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.UpdateLineDates', 'Also blocked in this version, for a different reason.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create an invoice once exchange rates are current.'));
                end;
            'Subscription.VendorContract.GetLines':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create a vendor invoice after attaching lines.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.PreviewInvoice', 'See what would be billed after attaching lines.'));
                end;
            'Subscription.VendorContract.CreateInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.PreviewInvoice', 'See what would be billed without creating a document.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.GetLines', 'Attach eligible lines before billing.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Bill many contracts at once from a Billing Template''s proposal.'));
                end;
            'Subscription.VendorContract.PreviewInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create the purchase document for real.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.GetLines', 'Attach eligible lines before billing.'));
                end;
            'Subscription.Billing.CreateProposal':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents from the generated proposal.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PreviewDocuments', 'See the documents the proposal would become.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Bill one customer contract without a Billing Template.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PreviewDocuments', 'Preview the bulk run before writing documents.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal lines this call consumes.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PostDocuments', 'Post documents this call left unposted, including every purchase document.'));
                end;
            'Subscription.Billing.PostDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create the unposted documents, including every purchase document and any sales document left unposted.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal a billing run turns into documents.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents after reviewing the preview.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal lines this call reads.'));
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.CreateProposal', 'Create a proposal after setting filters.'));
            'Subscription.PriceUpdate.CreateProposal':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.SetTemplateFilter', 'Set the template''s filters before creating the proposal.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.Perform', 'Apply a price update proposal.'));
                end;
            'Subscription.PriceUpdate.Perform':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.SetTemplateFilter', 'Set the template filter before creating a proposal.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.CreateProposal', 'Create a proposal before applying it.'));
                end;
            'Subscription.Renewal.Extend':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Renewal.CreateQuote', 'Create a renewal quote instead of extending directly.'));
            'Subscription.Renewal.CreateQuote':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Renewal.Extend', 'Extend the contract directly instead of creating a quote.'));
            'Subscription.Deferral.Release':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Analysis.Recalculate', 'Rebuild contract analysis entries.'));
            'Subscription.Analysis.Recalculate':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Deferral.Release', 'Release deferred revenue or cost.'));
            'Subscription.Import.CreateContracts':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Line.Create', 'Create subscription lines without a staged import.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach lines to a customer contract after import.'));
                end;
            'Subscription.Usage.ImportData':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.Process', 'Process the imported usage entry.'));
            'Subscription.Usage.Process':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ImportData', 'Import usage data when no entry exists.'));
        end;
    end;

    /// <summary>Builds the typical workflow of the type's domain; empty when the type has none.</summary>
    procedure GetWorkflow(MessageType: Text) Workflow: JsonObject
    var
        Steps: JsonArray;
    begin
        case MessageType of
            'Subscription.Line.Create', 'Subscription.Contract.GetLines', 'Subscription.Contract.PreviewInvoice', 'Subscription.Contract.CreateInvoice':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Line.Create', 'Create Subscription Lines on a Subscription Header from a package.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.GetLines', 'Attach the unassigned lines to the customer contract.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.PreviewInvoice', 'Check what the contract would bill.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.CreateInvoice', 'Create the unposted sales invoice.'));
                    Workflow.Add('text', 'Bill one customer contract. The invoice is left unposted.');
                end;
            'Subscription.Contract.MergeLines':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.GetLines', 'Attach the lines that should be merged.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.MergeLines', 'Merge them into one Subscription. The selected lines are closed.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Contract.CreateInvoice', 'Bill the open line that the merge created.'));
                    Workflow.Add('text', 'Merge duplicate customer contract lines, then bill the contract. The invoice is left unposted.');
                end;
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.GetLines', 'Attach the unassigned vendor lines to the vendor contract.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.PreviewInvoice', 'Check what the contract would bill.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.CreateInvoice', 'Create the unposted purchase document.'));
                    Workflow.Add('text', 'Bill one vendor contract. The purchase document is never posted here; post it separately after review.');
                end;
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.PreviewDocuments', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PostDocuments':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateProposal', 'Create the billing proposal lines for a Billing Template.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.PreviewDocuments', 'Review the documents the proposal would become, and any warnings.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateDocuments', 'Turn the proposal lines into documents.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.PostDocuments', 'Post the unposted documents the billing run created.'));
                    Workflow.Add('text', 'Bill every contract a Billing Template covers in one run, then post the documents that stay unposted.');
                end;
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.SetTemplateFilter', 'Narrow the Price Update Template to the contracts, subscriptions or lines to update.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.CreateProposal', 'Create the Contract Price Update Lines and review the new prices.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.Perform', 'Apply the proposal to the Subscription Lines.'));
                    Workflow.Add('text', 'Raise or index contract prices through a Price Update Template. Nothing is posted.');
                end;
            'Subscription.Usage.ImportData', 'Subscription.Usage.Process':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Usage.ImportData', 'Store the supplier''s usage file and parse it into imported lines.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Usage.Process', 'Process the imported lines into usage data billing and billing lines.'));
                    Workflow.Add('text', 'Bill usage-based Subscription Lines from a supplier''s usage file.');
                end;
            else
                exit;
        end;
        Workflow.Add('steps', Steps);
    end;

    /// <summary>The note on boolean parameters, shared by every type that reads one.</summary>
    procedure BooleanNote(): Text
    begin
        exit('Boolean parameters accept true and false, or the text true, false, 1 or 0 in any casing. Any other value is ignored and the default applies. ');
    end;

    /// <summary>The note on the isolated write, shared by the types that do not commit on their own.</summary>
    procedure IsolationNote(): Text
    begin
        exit('The write runs in its own transaction, so an error rolls back everything this call wrote and is answered with status Error. Under Omit Commit it runs inside the caller''s transaction instead. ');
    end;

    /// <summary>The note on the types that are registered for discovery but blocked.</summary>
    procedure BlockedNote(): Text
    begin
        exit('This message type is blocked. It is registered so that it can be discovered, but every call answers with an error and writes nothing; the request is not read. ');
    end;

    /// <summary>
    /// Adds the precondition on the Subscription Billing records a type reads but does not create.
    /// A caller prepares them with Foundation's generic writes, which the Bifrost Setup write guard
    /// blocks by default.
    /// </summary>
    local procedure AddSetupPreconditions(MessageType: Text; var Preconditions: JsonArray)
    var
        Records: Text;
    begin
        case MessageType of
            'Subscription.Line.Create':
                Records := 'The Subscription Header and the Subscription Package exist';
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Contract.MergeLines', 'Subscription.Renewal.CreateQuote':
                Records := 'The Customer Subscription Contract exists';
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                Records := 'The Vendor Subscription Contract exists';
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                Records := 'The Billing Template exists';
            'Subscription.Renewal.Extend':
                Records := 'The Subscription and the customer or vendor contract exist';
            'Subscription.Usage.ImportData':
                Records := 'The Usage Data Supplier and its Generic Import Settings exist';
            'Subscription.Import.CreateContracts':
                Records := 'The staging rows exist in Imported Subscription Header, Imported Cust. Sub. Contract and Imported Subscription Line';
            else
                exit;
        end;
        Preconditions.Add(Records + '. This call does not create them. Writing them with Data.Records.Set needs the Bifrost Setup write guard set to Open, or Change Log coverage on those Subscription Billing tables, because the guard is Blocked by default.');
    end;

    local procedure IsBlocked(MessageType: Text): Boolean
    begin
        exit(MessageType in ['Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates']);
    end;

    local procedure GetChanges(MessageType: Text): Text
    begin
        case MessageType of
            'Subscription.Line.Create':
                exit('Inserts Subscription Lines under the Subscription Header through Microsoft''s package application. No contract is touched and nothing is billed.');
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                exit('Attaches existing, unassigned Subscription Lines to the contract: a contract line is inserted for each and the Subscription Line is stamped with the contract. No Subscription Line is created and nothing is billed.');
            'Subscription.Contract.MergeLines':
                exit('Closes the named customer contract lines and their Subscription Lines, copies the reference line''s Subscription with the summed quantity, and inserts one open contract line for that Subscription. Nothing is posted and nothing is committed. Vendor contract lines are not merged.');
            'Subscription.Contract.CreateInvoice':
                exit('Creates template-less billing proposal lines for the contract''s due Subscription Lines and an unposted sales invoice or credit memo from them. Nothing is posted and no page opens. Microsoft commits each document it creates.');
            'Subscription.VendorContract.CreateInvoice':
                exit('Creates template-less billing proposal lines for the contract''s due Subscription Lines and an unposted purchase invoice or credit memo from them, with vendorInvoiceNo validated onto each. Nothing is posted. Microsoft commits each document it creates.');
            'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice':
                exit('Builds the real billing proposal lines for the contract, reads them back and deletes them again, also after a failed proposal. No document is created.');
            'Subscription.Billing.CreateProposal':
                exit('Creates billing proposal lines under the Billing Template for the due Subscription Lines that match the template''s filter. No document is created and nothing is posted. ' +
                    'Microsoft Subscription Billing commits the proposal lines every CommitBatchSize (50) contracts, so a failure after such a commit does not roll back the lines already committed.');
            'Subscription.Billing.CreateDocuments':
                exit('Turns the template''s unbilled proposal lines into sales or purchase documents, and posts the sales documents when postDocuments is true. Purchase documents are left unposted. Microsoft commits each document as it creates it, so a failure part way leaves the earlier documents in place. Post what stays unposted with Subscription.Billing.PostDocuments.');
            'Subscription.Billing.PostDocuments':
                exit('Posts the named unposted sales or purchase documents through Sales-Post or Purch.-Post and always commits, including when Omit Commit is set. A blank Vendor Invoice No. is set to the document number before a purchase document is posted. Nothing is posted when a document is foreign or already posted.');
            'Subscription.Billing.PreviewDocuments':
                exit('Reads the template''s unbilled proposal lines. Nothing is written.');
            'Subscription.PriceUpdate.SetTemplateFilter':
                exit('Writes one of the three view filters on the Price Update Template. Contracts, Subscriptions and Subscription Lines are not touched.');
            'Subscription.PriceUpdate.CreateProposal':
                exit('Inserts Contract Price Update Lines (Sub. Contr. Price Update Line) for the template''s matching Subscription Lines. Subscription Lines, contracts and prices are not changed, nothing is posted and nothing is committed.');
            'Subscription.PriceUpdate.Perform':
                exit('Writes Subscription Lines: changes their prices, Next Price Update and Price Binding Period and archives the old values in the Subscription Line Archive, or inserts Planned Subscription Lines. ' +
                    'Deletes each performed Contract Price Update Line and commits after each line. Nothing is posted.');
            'Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates':
                exit('Nothing: the call is answered with an error before anything is written.');
            'Subscription.Renewal.Extend':
                exit('Runs Microsoft''s Extend Sub. Contract Mgt. without its dialog: inserts Subscription Lines on the Subscription and contract lines on the named customer and vendor contracts.');
            'Subscription.Renewal.CreateQuote':
                exit('Deletes the contract''s Sub. Contract Renewal Lines, builds new ones from its Subscription Lines that have an end date, and creates a renewal sales quote from them. Nothing is posted.');
            'Subscription.Usage.ImportData':
                exit('Creates a Usage Data Import with a Usage Data Blob holding the file and commits them, then runs the Create Imported Lines step, and Process Imported Lines when runProcessing is true, each after a commit. Nothing is posted.');
            'Subscription.Usage.Process':
                exit('Runs the requested processing steps on the Usage Data Import, committing before each, so a later failure does not undo an earlier step. Creates and processes Usage Data Billing rows; nothing is posted by this call.');
            'Subscription.Deferral.Release':
                exit('Runs Microsoft''s Contract Deferrals Release report, which releases every eligible customer and vendor deferral of every contract up to the work date and posts the release to the general ledger.');
            'Subscription.Analysis.Recalculate':
                exit('Create Contract Analysis adds analysis entries for Subscription Lines with a contract and skips a line that already has an entry for the current month.');
            'Subscription.Import.CreateContracts':
                exit('Creates Subscription Headers, Customer Subscription Contracts, Subscription Lines and Cust. Sub. Contract Lines from the unprocessed staging rows, and contract comment lines when allowCommentLines is true. A failed row gets its error text on the staging row, committed at once.');
        end;
        exit('The operation invokes Microsoft Subscription Billing logic and changes the records described by the request.');
    end;

    local procedure GetSubjectKey(MessageType: Text; var DataKey: Text; var SubjectForm: Text): Boolean
    begin
        case MessageType of
            'Subscription.Line.Create', 'Subscription.Renewal.Extend':
                SetSubjectKey(DataKey, SubjectForm, 'subscriptionHeaderNo', 'Subscription Header No.');
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Contract.MergeLines', 'Subscription.Renewal.CreateQuote':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Customer Subscription Contract No.');
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Vendor Subscription Contract No.');
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                SetSubjectKey(DataKey, SubjectForm, 'billingTemplateCode', 'Billing Template Code');
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                SetSubjectKey(DataKey, SubjectForm, 'priceUpdateTemplateCode', 'Price Update Template Code');
            'Subscription.Usage.ImportData':
                SetSubjectKey(DataKey, SubjectForm, 'supplierNo', 'Usage Data Supplier No.');
            'Subscription.Usage.Process':
                SetSubjectKey(DataKey, SubjectForm, 'usageDataImportEntryNo', 'Usage Data Import Entry No.');
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure SetSubjectKey(var DataKey: Text; var SubjectForm: Text; NewDataKey: Text; NewSubjectForm: Text)
    begin
        DataKey := NewDataKey;
        SubjectForm := NewSubjectForm;
    end;


    local procedure AddParameterErrors(MessageType: Text; var Errors: JsonArray)
    begin
        if not (MessageType in ['Subscription.Deferral.Release', 'Subscription.Analysis.Recalculate', 'Subscription.Import.CreateContracts', 'Subscription.PriceUpdate.Perform']) then
            AddBusinessCentralError(Errors, 'The request is missing the required parameter ''%1''.', 'A required parameter is missing, and the subject does not carry it either.', 'Send the parameter named in the error.');
        if not (MessageType in ['Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts']) then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is longer than the %2 characters allowed.', 'A record number or code, or the subject, is longer than 20 characters.', 'Send the number as it is stored in Business Central.');
        if MessageType in ['Subscription.Line.Create', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Deferral.Release', 'Subscription.PriceUpdate.CreateProposal'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', 'A date parameter is not a date in the ISO format.', 'Send the date as YYYY-MM-DD.');
        if MessageType in ['Subscription.Renewal.Extend', 'Subscription.Usage.Process', 'Subscription.Contract.MergeLines'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', 'An integer parameter is not a number.', 'Send a whole number.');
        if MessageType in ['Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines', 'Subscription.Contract.MergeLines', 'Subscription.Renewal.Extend', 'Subscription.Usage.Process', 'Subscription.Import.CreateContracts', 'Subscription.Billing.PostDocuments'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' must be a JSON array.', 'An array parameter has a value that is not an array.', 'Send a JSON array, or leave the parameter out.');
        if MessageType in ['Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' must be a JSON array of entry numbers, written as whole numbers.', 'An entry of subscriptionLineEntryNos is not a whole number.', 'Send whole numbers only.');
    end;

    local procedure AddLookupErrors(MessageType: Text; var Errors: JsonArray)
    begin
        case MessageType of
            'Subscription.Line.Create':
                begin
                    AddNotFoundError(Errors, 'The Subscription Header ''%1'' does not exist.', 'subscriptionHeaderNo or the subject names no Subscription Header.');
                    AddNotFoundError(Errors, 'The Subscription Package ''%1'' does not exist.', 'subscriptionPackageCode names no Subscription Package.');
                end;
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Contract.MergeLines', 'Subscription.Renewal.CreateQuote':
                AddNotFoundError(Errors, 'The Customer Subscription Contract ''%1'' does not exist.', 'contractNo or the subject names no Customer Subscription Contract.');
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                AddNotFoundError(Errors, 'The Vendor Subscription Contract ''%1'' does not exist.', 'contractNo or the subject names no Vendor Subscription Contract.');
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                AddNotFoundError(Errors, 'The Billing Template ''%1'' does not exist.', 'billingTemplateCode or the subject names no Billing Template.');
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                AddNotFoundError(Errors, 'The Price Update Template ''%1'' does not exist.', 'priceUpdateTemplateCode or the subject names no Price Update Template.');
            'Subscription.Renewal.Extend':
                begin
                    AddNotFoundError(Errors, 'The Subscription ''%1'' does not exist.', 'subscriptionHeaderNo or the subject names no Subscription.');
                    AddNotFoundError(Errors, 'The Customer Subscription Contract ''%1'' does not exist.', 'customerContractNo names no Customer Subscription Contract.');
                    AddNotFoundError(Errors, 'The Vendor Subscription Contract ''%1'' does not exist.', 'vendorContractNo names no Vendor Subscription Contract.');
                    AddNotFoundError(Errors, 'The Subscription Package ''%1'' does not exist.', 'An entry of subscriptionPackageCodes names no Subscription Package.');
                end;
            'Subscription.Usage.Process':
                AddNotFoundError(Errors, 'The Usage Data Import entry %1 does not exist.', 'No Usage Data Import has that entry number.');
        end;
    end;

    local procedure AddTypeErrors(MessageType: Text; var Errors: JsonArray)
    begin
        case MessageType of
            'Subscription.Contract.MergeLines':
                begin
                    AddBusinessCentralError(Errors, 'Each entry of ''lines'' must be a JSON object with lineNo.', 'An entry of lines is not an object.', 'Send an object with lineNo.');
                    AddBusinessCentralError(Errors, 'The parameter ''lineNo'' must be a whole number.', 'lineNo is not a whole number.', 'Send a whole number.');
                    AddBusinessCentralError(Errors, 'The lines belong to more than one Customer Subscription Contract. Merge lines of one contract at a time.', 'An entry names a contract other than the one being merged.', 'Send lines of one contract.');
                    AddBusinessCentralError(Errors, 'Customer contract line %1 does not exist on contract %2.', 'lineNo is not a line of that contract.', 'Send a line number from the contract.');
                    AddBusinessCentralError(Errors, 'referenceLineNo %1 is not one of the lines to merge.', 'referenceLineNo is not among the lines.', 'Send the Line No. of one of the lines.');
                    AddBusinessCentralError(Errors, 'Please select the lines you want to combine.', 'Fewer than two contract lines remain after the request is read. This is Microsoft''s message.', 'Send at least two lines.');
                    AddBusinessCentralError(Errors, 'Merging with text lines is not allowed.', 'One of the lines is a comment. This is Microsoft''s message.', 'Leave comment lines out of the merge.');
                    AddBusinessCentralError(Errors, 'Subscription Lines from Subscriptions with different Customer References cannot be merged.', 'The Subscriptions do not share a Customer Reference. This is Microsoft''s message.', 'Align the Customer Reference, or merge a different set.');
                    AddBusinessCentralError(Errors, 'Contract lines cannot be merged if Serial No. is entered into Subscription.', 'The Subscriptions do not share a Serial No. This is Microsoft''s message.', 'Clear or align the serial numbers.');
                    AddBusinessCentralError(Errors, 'There are different dimension values for the Contract Lines. Complete the dimensions before merging the Contract Lines.', 'The Subscription Lines do not share a dimension set. This is Microsoft''s message.', 'Give the lines the same dimensions.');
                    AddBusinessCentralError(Errors, 'Billing Lines for exists for at least one of the selected contract lines. Delete the Billing Lines before merging the Contract Lines.', 'A selected line still has billing lines. This is Microsoft''s message.', 'Delete those billing lines first.');
                    AddBusinessCentralError(Errors, 'There is a different Next Billing Date for the Contract Lines. The Contract Lines must be billed so that the Next Billing Date is the same before they can be combined.', 'The Subscription Lines do not share a Next Billing Date. This is Microsoft''s message.', 'Bill the lines until the dates match.');
                end;
            'Subscription.Line.Create':
                AddBusinessCentralError(Errors, 'Source No. must have a value in Subscription Header ...', 'The Subscription Header has no Source No.', 'Set the Source No. of the Subscription Header, then retry.');
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice':
                AddBusinessCentralError(Errors, 'Contract ''%1'' has %2 pending billing line(s) with no billing template assigned. ...', 'Another contract has template-less billing proposal lines that are not on a document yet; this call would convert or touch them too.', 'Bill, preview or clear the proposal of the named contract first.');
            'Subscription.VendorContract.CreateInvoice':
                AddBusinessCentralError(Errors, 'There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before creating an invoice for ''%3''.', 'Another contract has template-less billing proposal lines that are not on a document yet.', 'Bill or clear the proposal of the named contract first.');
            'Subscription.VendorContract.PreviewInvoice':
                AddBusinessCentralError(Errors, 'There are %1 pending billing proposal line(s) left over for a different subscription contract (''%2''). Clear or process that proposal before previewing ''%3''.', 'Another contract has template-less billing proposal lines that are not on a document yet.', 'Bill or clear the proposal of the named contract first.');
            'Subscription.Billing.CreateDocuments':
                begin
                    AddBusinessCentralError(Errors, 'You can create documents only for one type of partner at a time. Billing Template ''%1'' currently has both customer and vendor proposal lines pending.', 'The template''s unbilled proposal lines mix customers and vendors.', 'Clear the lines of one partner type, or split them over two templates.');
                    AddGroupByErrors(Errors);
                    Errors.Add(ContractMgt.TextErrorEntry('The billing run failed after Business Central had already created the documents listed in ''documents''. ... Underlying error: %1', 'Business Central failed part way, after it had committed some documents. The answer has status Error and also carries billingTemplateCode, billingLinesProcessed, documentCount, documents and rolledBack (false).', 'Review the listed documents, which still exist, before running the template again.'));
                end;
            'Subscription.Billing.PostDocuments':
                begin
                    AddBusinessCentralError(Errors, 'The parameter ''documents'' must contain at least one document.', 'documents is an empty array. Nothing is posted.', 'Send at least one document.');
                    AddBusinessCentralError(Errors, 'Each entry of ''documents'' must be a JSON object with partner, documentType and documentNo.', 'An entry of documents is not an object.', 'Send an object with partner, documentType and documentNo.');
                    AddBusinessCentralError(Errors, 'The parameter ''partner'' must be either ''Customer'' or ''Vendor''.', 'partner is neither Customer nor Vendor.', 'Send Customer or Vendor.');
                    AddBusinessCentralError(Errors, 'The parameter ''documentType'' must be either ''Invoice'' or ''Credit Memo''.', 'documentType is neither Invoice nor Credit Memo.', 'Send Invoice or Credit Memo.');
                    AddBusinessCentralError(Errors, 'Document %1 is listed more than once. Nothing was posted.', 'The same document appears twice. Nothing is posted.', 'Send each document once.');
                    AddBusinessCentralError(Errors, 'Document %1 %2 was not created by Subscription Billing. Post it with Sales.Document.Post.', 'The customer document is on neither Billing Line nor Billing Line Archive.', 'Post an ordinary sales document with Sales.Document.Post.');
                    AddBusinessCentralError(Errors, 'Document %1 %2 was not created by Subscription Billing. Post it with Purch.Document.Post.', 'The vendor document is on neither Billing Line nor Billing Line Archive.', 'Post an ordinary purchase document with Purch.Document.Post.');
                    AddBusinessCentralError(Errors, 'Document %1 %2 is already posted.', 'The billing document has already been posted.', 'Do not post it again.');
                    AddBusinessCentralError(Errors, 'Billing document %1 %2 is not an open sales or purchase document.', 'The billing document is not open and is not a posted document.', 'Check the document number.');
                    AddBusinessCentralError(Errors, 'Posting document %1 failed. Documents this call already posted stay posted. %2', 'Business Central failed while posting one document. Earlier documents in this call stay posted.', 'Fix the cause named in the error and call again for the documents that are still open.');
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Posting denied: missing ''BIFROST SubPost ori'' permission set.', 'The caller cannot write the subscription billing posting token. Nothing is posted.', 'Assign BIFROST SubPost ori. Sales.Document.Post and Purch.Document.Post do not cover this type.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    AddGroupByErrors(Errors);
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'skip or take is negative or not a whole number.', 'Send zero or a positive whole number.'));
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    AddBusinessCentralError(Errors, 'The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''.', 'target is none of the three names.', 'Send contract, subscription or line.');
                    AddBusinessCentralError(Errors, 'The parameter ''filter'' is not a valid Business Central view for target ''%1''. ...', 'Business Central cannot parse filter as a view of the target''s table.', 'Send a view such as WHERE(Field=FILTER(Value)) with field names of that table.');
                end;
            'Subscription.PriceUpdate.CreateProposal':
                AddBusinessCentralError(Errors, 'Please enter the Include Contract Lines up to Date.', 'includeLinesUpToDate is not given and the template has no Include Subscription Contract Lines up to Date Formula. This is Microsoft''s own message.', 'Send includeLinesUpToDate, or set the formula on the template.');
            'Subscription.PriceUpdate.Perform':
                begin
                    AddBusinessCentralError(Errors, 'There are no Contract Price Update Lines to perform. Run Subscription.PriceUpdate.CreateProposal first.', 'No Contract Price Update Line exists. Nothing is written.', 'Create a proposal first.');
                    AddBusinessCentralError(Errors, 'There are no Contract Price Update Lines for Price Update Template ''%1'' to perform. Run Subscription.PriceUpdate.CreateProposal first.', 'The named template has no Contract Price Update Line. Nothing is written.', 'Create a proposal for the template first, or leave the template out.');
                    Errors.Add(ContractMgt.TextErrorEntry('%1 of %2 Contract Price Update Lines could not be performed and were left in the proposal; see ''results''. ...', 'At least one line failed; the other lines were performed and committed. The answer has status Error and also carries the counts, results (with each failed line''s error) and rolledBack (false).', 'Fix the cause named in the failed results and call again; only the remaining lines are performed.'));
                end;
            'Subscription.Renewal.Extend':
                AddBusinessCentralError(Errors, 'The request must supply at least one of ''customerContractNo'' or ''vendorContractNo''.', 'Neither contract number was given.', 'Name the customer contract, the vendor contract, or both.');
            'Subscription.Renewal.CreateQuote':
                begin
                    AddBusinessCentralError(Errors, 'The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed.', 'No Subscription Line of the contract has an end date that Microsoft accepts for renewal.', 'Check the end dates of the contract''s Subscription Lines.');
                    AddBusinessCentralError(Errors, 'Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''.', 'Microsoft''s renewal codeunit finished without creating a quote.', 'Check the renewal setup and the contract''s lines in the Business Central client.');
                end;
            'Subscription.Usage.ImportData':
                AddBusinessCentralError(Errors, 'The request must supply either ''content'' (raw text) or ''contentBase64'' (base64 encoded) for the usage data file.', 'Neither content nor contentBase64 was given.', 'Send the file as content or contentBase64.');
            'Subscription.Usage.Process':
                begin
                    AddBusinessCentralError(Errors, 'The subject ''%1'' is not a Usage Data Import entry number. ...', 'The subject is set but is not a whole number.', 'Send the entry number as the subject, or as usageDataImportEntryNo.');
                    AddBusinessCentralError(Errors, 'Usage Data Import entry %1 is already Closed and cannot be processed again.', 'The entry''s Processing Status is Closed.', 'Import the data again with Subscription.Usage.ImportData.');
                    AddBusinessCentralError(Errors, '''%1'' is not a known processing step. ...', 'An entry of steps is not one of the four step names. The steps before it have already run and committed.', 'Use CreateImportedLines, ProcessImportedLines, CreateUsageDataBilling or ProcessUsageDataBilling.');
                end;
            'Subscription.Deferral.Release':
                begin
                    AddBusinessCentralError(Errors, 'The parameter ''postUntilDate'' (%1) must not be later than ''postingDate'' (%2).', 'postUntilDate is after postingDate.', 'Send a postUntilDate on or before postingDate.');
                    AddBusinessCentralError(Errors, 'Business Central posts this release under the work date (%1) and offers no supported way to post it under a different one, so ''postingDate'' (%2) cannot be honoured. ...', 'postingDate is not the session work date.', 'Omit postingDate, or set the session work date to it before calling.');
                    AddBusinessCentralError(Errors, 'Refusing to run: Business Central would release %1 deferral(s) posted between ''postUntilDate'' (%2) and the work date (%3). ...', 'Unreleased deferrals post after postUntilDate and on or before the work date; the report would release them too.', 'Set the session work date to postUntilDate, or raise postUntilDate to the work date to accept releasing all of them.');
                end;
            'Subscription.Import.CreateContracts':
                AddBusinessCentralError(Errors, '''%1'' is not a known import stage. Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines.', 'An entry of stages is not a stage name. Nothing has run yet.', 'Use SubscriptionHeaders, CustomerContracts, SubscriptionLines or ContractLines.');
        end;
    end;

    local procedure AddGroupByErrors(var Errors: JsonArray)
    begin
        AddBusinessCentralError(Errors, 'The parameter ''groupBy'' must be either ''Contract'' or ''Customer''.', 'groupBy is neither Contract nor Customer.', 'Send Contract or Customer, or leave groupBy out.');
        AddBusinessCentralError(Errors, '''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts.', 'groupBy is Customer and the template has pending vendor proposal lines.', 'Use groupBy Contract for vendor proposal lines.');
    end;

    local procedure AddNotFoundError(var Errors: JsonArray; ErrorText: Text; When: Text)
    begin
        AddBusinessCentralError(Errors, ErrorText, When, 'Use an existing number or code.');
    end;

    local procedure AddBusinessCentralError(var Errors: JsonArray; ErrorText: Text; When: Text; Fix: Text)
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorText, When, Fix));
    end;

    local procedure AsDate(Entry: JsonObject): JsonObject
    begin
        Entry.Add('format', 'date');
        exit(Entry);
    end;

    local procedure WithBooleanDefault(Entry: JsonObject; DefaultValue: Boolean): JsonObject
    begin
        Entry.Add('default', DefaultValue);
        exit(Entry);
    end;

    local procedure WithIntegerDefault(Entry: JsonObject; DefaultValue: Integer): JsonObject
    begin
        Entry.Add('default', DefaultValue);
        exit(Entry);
    end;

    local procedure WithTextDefault(Entry: JsonObject; DefaultValue: Text): JsonObject
    begin
        Entry.Add('default', DefaultValue);
        exit(Entry);
    end;

    local procedure AsGroupBy(Entry: JsonObject): JsonObject
    begin
        Entry := WithAllowed(Entry, 'Contract,Customer');
        Entry.Add('default', 'Contract');
        exit(Entry);
    end;

    local procedure WithAllowed(Entry: JsonObject; AllowedValues: Text): JsonObject
    var
        Allowed: JsonArray;
        AllowedValue: Text;
    begin
        foreach AllowedValue in AllowedValues.Split(',') do
            Allowed.Add(AllowedValue);
        Entry.Add('allowed', Allowed);
        exit(Entry);
    end;

    local procedure FieldWithChildren(Name: Text; JsonType: Text; Description: Text; Children: JsonArray) Entry: JsonObject
    begin
        Entry := ContractMgt.ResponseField(Name, JsonType, Description);
        Entry.Add('children', Children);
    end;
}
