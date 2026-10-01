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
        Envelope.Add('dataRequired', MessageType in ['Subscription.Line.Create', 'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.Renewal.Extend', 'Subscription.Usage.ImportData']);
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

    /// <summary>Builds the request parameters the implementation reads under data.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    begin
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The Subscription Header to add lines to. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionPackageCode', 'string', true, 'The Subscription Package to apply.'));
                    Parameters.Add(DateParameter('subscriptionLineStartDate', 'Start date for the new lines. Omit to let the package''s own date formula decide.'));
                    Parameters.Add(DateParameter('subscriptionLineEndDate', 'End date for the new lines. Omit to leave the lines open-ended.'));
                    Parameters.Add(BooleanParameter('usageBasedBillingPackageLinesOnly', false, 'When true, only the usage-based lines of the package are created.'));
                end;
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The ' + PartnerContractName(MessageType) + ' to attach lines to. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', false, 'Restricts the candidate lines to one Subscription Header.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineEntryNos', 'array', false, 'Restricts the candidate lines to these Subscription Line entry numbers, written as whole numbers. A number that is not a candidate is ignored.'));
                end;
            'Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The ' + PartnerContractName(MessageType) + ' to bill. May be supplied as the subject instead.'));
                    Parameters.Add(DateParameter('billingDate', 'Subscription Lines whose Next Billing Date is on or before this date are billed. Defaults to the work date.'));
                    Parameters.Add(DateParameter('billingToDate', 'Bills complete periods up to this date. Omit to bill each line by its own billing rhythm.'));
                    if MessageType in ['Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice'] then begin
                        Parameters.Add(DateParameter('documentDate', 'Document date of the created document. Defaults to the work date.'));
                        Parameters.Add(DateParameter('postingDate', 'Posting date of the created document. Defaults to the work date.'));
                    end;
                    if MessageType = 'Subscription.VendorContract.CreateInvoice' then
                        Parameters.Add(ContractMgt.Parameter('vendorInvoiceNo', 'string', false, 'Validated into Vendor Invoice No. on every document this call creates, so the vendor''s duplicate invoice number check applies. Text past 35 characters is cut off.'));
                end;
            'Subscription.Billing.CreateProposal':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template to run. May be supplied as the subject instead.'));
                    Parameters.Add(DateParameter('billingDate', 'Subscription Lines due on or before this date are proposed. Defaults to the work date.'));
                    Parameters.Add(DateParameter('billingToDate', 'Bills complete periods up to this date. Omit to bill each line by its own billing rhythm.'));
                    Parameters.Add(BooleanParameter('automatedBilling', true, 'Passed to Microsoft''s billing proposal as its automated billing flag. Leave it at the default for an unattended run.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template whose unbilled proposal lines are processed. May be supplied as the subject instead.'));
                    Parameters.Add(DateParameter('documentDate', 'Document date of the created documents. Defaults to the work date.'));
                    Parameters.Add(DateParameter('postingDate', 'Posting date of the created documents. Defaults to the work date.'));
                    Parameters.Add(BooleanParameter('postDocuments', false, 'When true, the created sales documents are posted. Purchase documents are never posted.'));
                    Parameters.Add(GroupByParameter('Contract creates one document per contract; Customer creates one document per Bill-to Customer No. and needs customer proposal lines.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template to preview. May be supplied as the subject instead.'));
                    Parameters.Add(GroupByParameter('Contract groups per Subscription Contract No.; Customer groups per Partner No. and needs every pending line to belong to a customer contract.'));
                    Parameters.Add(IntegerParameter('skip', 0, 'Number of document groups to skip. Must be zero or greater.'));
                    Parameters.Add(IntegerParameter('take', 100, 'Maximum number of document groups to return. Zero means the default; a value above 1000 is clamped to 1000. Must be zero or greater.'));
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    Parameters.Add(ContractMgt.Parameter('priceUpdateTemplateCode', 'string', true, 'The Price Update Template to change. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('filter', 'string', true, 'A Business Central view, such as WHERE(Subscription Contract No.=FILTER(CC000010)) or a full SORTING(...) WHERE(...) view, of the table the target names. It is normalised before it is stored; a view without filters clears the stored filter.'));
                    Parameters.Add(AllowedParameter('target', 'string', true, 'Which filter to write, in any casing: contract (Customer or Vendor Subscription Contract, following the template''s Partner), subscription (Subscription Header) or line (Subscription Line).', 'contract,subscription,line'));
                end;
            'Subscription.Renewal.Extend':
                begin
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The existing Subscription to extend. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('customerContractNo', 'string', false, 'An existing Customer Subscription Contract to extend onto. At least one of customerContractNo and vendorContractNo is required.'));
                    Parameters.Add(ContractMgt.Parameter('vendorContractNo', 'string', false, 'An existing Vendor Subscription Contract to extend onto. At least one of customerContractNo and vendorContractNo is required.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionPackageCodes', 'array', false, 'Subscription Package codes to apply in addition to the item''s standard packages, which Microsoft always applies.'));
                    Parameters.Add(BooleanParameter('usageBasedBillingPackageLinesOnly', false, 'When true, only usage-based package lines are added.'));
                    Parameters.Add(IntegerParameter('supplierReferenceEntryNo', 0, 'Links the extension to a supplier reference entry.'));
                end;
            'Subscription.Renewal.CreateQuote':
                Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The Customer Subscription Contract to renew. May be supplied as the subject instead.'));
            'Subscription.Usage.ImportData':
                begin
                    Parameters.Add(ContractMgt.Parameter('supplierNo', 'string', true, 'The Usage Data Supplier the file came from. May be supplied as the subject instead.'));
                    Parameters.Add(TextParameter('fileName', 'bifrost-usage.csv', 'File name recorded as Source on the Usage Data Blob.'));
                    Parameters.Add(ContractMgt.Parameter('content', 'string', false, 'The file content as text, for example a CSV payload. Required unless contentBase64 is given.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, 'The file content, base64 encoded, for payloads that are not plain text. Required unless content is given; when both are given, contentBase64 is used.'));
                    Parameters.Add(BooleanParameter('runProcessing', false, 'When true, the Process Imported Lines step runs right after the import.'));
                end;
            'Subscription.Usage.Process':
                begin
                    Parameters.Add(ContractMgt.Parameter('usageDataImportEntryNo', 'integer', true, 'The Usage Data Import entry to process. May be supplied as the subject instead.'));
                    Parameters.Add(AllowedParameter('steps', 'array', false, 'The processing steps to run, in the order given. Defaults to ProcessImportedLines, CreateUsageDataBilling, ProcessUsageDataBilling. CreateImportedLines parses the stored file again and is never run by default.', 'CreateImportedLines,ProcessImportedLines,CreateUsageDataBilling,ProcessUsageDataBilling'));
                end;
            'Subscription.Deferral.Release':
                begin
                    Parameters.Add(DateParameter('postingDate', 'The date the caller expects the release to post under. Must equal the work date, the only date Business Central uses. Defaults to the work date.'));
                    Parameters.Add(DateParameter('postUntilDate', 'The latest deferral posting date the caller accepts to release. The call is refused when the release would go past it. Must not be later than postingDate; defaults to postingDate.'));
                end;
            'Subscription.Analysis.Recalculate':
                Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Narrows the counts in the response to this Subscription Contract. It does not scope the run: the report always analyses every contract.'));
            'Subscription.Import.CreateContracts':
                Parameters.Add(AllowedParameter('stages', 'array', false, 'The import stages to run. Defaults to all four. They always run in the fixed order SubscriptionHeaders, CustomerContracts, SubscriptionLines, ContractLines, whatever order is given.', 'SubscriptionHeaders,CustomerContracts,SubscriptionLines,ContractLines'));
        end;
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
            'Subscription.PriceUpdate.CreateProposal':
                Errors.Add(ContractMgt.TextErrorEntry('Subscription.PriceUpdate.CreateProposal cannot run: Codeunit "Price Update Management".CreatePriceUpdateProposal is internal ...', 'Always: Microsoft has not exposed the procedure.', 'Create the proposal on the Contract Price Update page in the Business Central client. Subscription.PriceUpdate.SetTemplateFilter can prepare the template''s filters first.'));
            'Subscription.PriceUpdate.Perform':
                Errors.Add(ContractMgt.TextErrorEntry('Subscription.PriceUpdate.Perform cannot run: Codeunit "Price Update Management".PerformPriceUpdate is internal ...', 'Always: Microsoft has not exposed the procedure.', 'Perform the price update on the Contract Price Update page in the Business Central client.'));
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
            if MessageType in ['Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.Billing.CreateDocuments', 'Subscription.Renewal.Extend', 'Subscription.Renewal.CreateQuote', 'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts', 'Subscription.PriceUpdate.Perform', 'Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates'] then
                Effect.Add('effect', 'irreversible')
            else
                Effect.Add('effect', 'write');
        Effect.Add('changes', GetChanges(MessageType));
        Effect.Add('idempotent', MessageType in ['Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.PreviewDocuments', 'Subscription.Analysis.Recalculate']);
        Effect.Add('permissionSet', 'BIFROST SubBil ori');
        Preconditions.Add('Microsoft Subscription Billing is installed and set up, and the caller has the permissions on its tables.');
        case MessageType of
            'Subscription.Line.Create':
                Preconditions.Add('The Subscription Header has a Source No.');
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                Preconditions.Add('No other contract has template-less billing proposal lines that are not on a document yet.');
            'Subscription.Billing.CreateDocuments':
                Preconditions.Add('The template has unbilled proposal lines (Subscription.Billing.CreateProposal), all for customers or all for vendors.');
            'Subscription.Renewal.CreateQuote':
                Preconditions.Add('The contract has Subscription Lines with an end date.');
            'Subscription.Usage.Process':
                Preconditions.Add('The Usage Data Import entry exists and is not Closed.');
            'Subscription.Deferral.Release':
                Preconditions.Add('postingDate is the session work date, and no unreleased deferral posts after postUntilDate up to the work date.');
        end;
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
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.SetTemplateFilter', 'Prepare the template''s filters, which works from here.'));
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
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.GetLines', 'Attach the unassigned vendor lines to the vendor contract.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.PreviewInvoice', 'Check what the contract would bill.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.VendorContract.CreateInvoice', 'Create the unposted purchase document.'));
                    Workflow.Add('text', 'Bill one vendor contract. The purchase document is never posted here; post it separately after review.');
                end;
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.PreviewDocuments', 'Subscription.Billing.CreateDocuments':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateProposal', 'Create the billing proposal lines for a Billing Template.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.PreviewDocuments', 'Review the documents the proposal would become, and any warnings.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateDocuments', 'Turn the proposal lines into documents.'));
                    Workflow.Add('text', 'Bill every contract a Billing Template covers in one run.');
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

    /// <summary>The note on the four types that are registered for discovery but blocked.</summary>
    procedure BlockedNote(): Text
    begin
        exit('This message type is blocked. It is registered so that it can be discovered, but every call answers with an error and writes nothing; the request is not read. ');
    end;

    local procedure IsBlocked(MessageType: Text): Boolean
    begin
        exit(MessageType in ['Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform']);
    end;

    local procedure GetChanges(MessageType: Text): Text
    begin
        case MessageType of
            'Subscription.Line.Create':
                exit('Inserts Subscription Lines under the Subscription Header through Microsoft''s package application. No contract is touched and nothing is billed.');
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                exit('Attaches existing, unassigned Subscription Lines to the contract: a contract line is inserted for each and the Subscription Line is stamped with the contract. No Subscription Line is created and nothing is billed.');
            'Subscription.Contract.CreateInvoice':
                exit('Creates template-less billing proposal lines for the contract''s due Subscription Lines and an unposted sales invoice or credit memo from them. Nothing is posted and no page opens. Microsoft commits each document it creates.');
            'Subscription.VendorContract.CreateInvoice':
                exit('Creates template-less billing proposal lines for the contract''s due Subscription Lines and an unposted purchase invoice or credit memo from them, with vendorInvoiceNo validated onto each. Nothing is posted. Microsoft commits each document it creates.');
            'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice':
                exit('Builds the real billing proposal lines for the contract, reads them back and deletes them again, also after a failed proposal. No document is created.');
            'Subscription.Billing.CreateProposal':
                exit('Creates billing proposal lines under the Billing Template for the due Subscription Lines that match the template''s filter. No document is created and nothing is posted.');
            'Subscription.Billing.CreateDocuments':
                exit('Turns the template''s unbilled proposal lines into sales or purchase documents, and posts the sales documents when postDocuments is true. Microsoft commits each document as it creates it, so a failure part way leaves the earlier documents in place.');
            'Subscription.Billing.PreviewDocuments':
                exit('Reads the template''s unbilled proposal lines. Nothing is written.');
            'Subscription.PriceUpdate.SetTemplateFilter':
                exit('Writes one of the three view filters on the Price Update Template. Contracts, Subscriptions and Subscription Lines are not touched.');
            'Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
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
                exit('Creates Subscription Headers, Customer Subscription Contracts, Subscription Lines and Cust. Sub. Contract Lines from the unprocessed staging rows. A failed row gets its error text on the staging row, committed at once.');
        end;
        exit('The operation invokes Microsoft Subscription Billing logic and changes the records described by the request.');
    end;

    local procedure GetSubjectKey(MessageType: Text; var DataKey: Text; var SubjectForm: Text): Boolean
    begin
        case MessageType of
            'Subscription.Line.Create', 'Subscription.Renewal.Extend':
                SetSubjectKey(DataKey, SubjectForm, 'subscriptionHeaderNo', 'Subscription Header No.');
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Renewal.CreateQuote':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Customer Subscription Contract No.');
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Vendor Subscription Contract No.');
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                SetSubjectKey(DataKey, SubjectForm, 'billingTemplateCode', 'Billing Template Code');
            'Subscription.PriceUpdate.SetTemplateFilter':
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

    local procedure PartnerContractName(MessageType: Text): Text
    begin
        if MessageType.StartsWith('Subscription.VendorContract.') then
            exit('Vendor Subscription Contract');
        exit('Customer Subscription Contract');
    end;

    local procedure AddParameterErrors(MessageType: Text; var Errors: JsonArray)
    begin
        if not (MessageType in ['Subscription.Deferral.Release', 'Subscription.Analysis.Recalculate', 'Subscription.Import.CreateContracts']) then
            AddBusinessCentralError(Errors, 'The request is missing the required parameter ''%1''.', 'A required parameter is missing, and the subject does not carry it either.', 'Send the parameter named in the error.');
        if not (MessageType in ['Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts']) then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is longer than the %2 characters allowed.', 'A record number or code, or the subject, is longer than 20 characters.', 'Send the number as it is stored in Business Central.');
        if MessageType in ['Subscription.Line.Create', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Deferral.Release'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', 'A date parameter is not a date in the ISO format.', 'Send the date as YYYY-MM-DD.');
        if MessageType in ['Subscription.Renewal.Extend', 'Subscription.Usage.Process'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', 'An integer parameter is not a number.', 'Send a whole number.');
        if MessageType in ['Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines', 'Subscription.Renewal.Extend', 'Subscription.Usage.Process', 'Subscription.Import.CreateContracts'] then
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
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Renewal.CreateQuote':
                AddNotFoundError(Errors, 'The Customer Subscription Contract ''%1'' does not exist.', 'contractNo or the subject names no Customer Subscription Contract.');
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                AddNotFoundError(Errors, 'The Vendor Subscription Contract ''%1'' does not exist.', 'contractNo or the subject names no Vendor Subscription Contract.');
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                AddNotFoundError(Errors, 'The Billing Template ''%1'' does not exist.', 'billingTemplateCode or the subject names no Billing Template.');
            'Subscription.PriceUpdate.SetTemplateFilter':
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

    local procedure DateParameter(Name: Text; Description: Text) Entry: JsonObject
    begin
        Entry := ContractMgt.Parameter(Name, 'string', false, Description);
        Entry.Add('format', 'date');
    end;

    local procedure BooleanParameter(Name: Text; DefaultValue: Boolean; Description: Text) Entry: JsonObject
    begin
        Entry := ContractMgt.Parameter(Name, 'boolean', false, Description);
        Entry.Add('default', DefaultValue);
    end;

    local procedure IntegerParameter(Name: Text; DefaultValue: Integer; Description: Text) Entry: JsonObject
    begin
        Entry := ContractMgt.Parameter(Name, 'integer', false, Description);
        Entry.Add('default', DefaultValue);
    end;

    local procedure TextParameter(Name: Text; DefaultValue: Text; Description: Text) Entry: JsonObject
    begin
        Entry := ContractMgt.Parameter(Name, 'string', false, Description);
        Entry.Add('default', DefaultValue);
    end;

    local procedure GroupByParameter(Description: Text) Entry: JsonObject
    begin
        Entry := AllowedParameter('groupBy', 'string', false, Description + ' Any casing.', 'Contract,Customer');
        Entry.Add('default', 'Contract');
    end;

    local procedure AllowedParameter(Name: Text; JsonType: Text; Required: Boolean; Description: Text; AllowedValues: Text) Entry: JsonObject
    var
        Allowed: JsonArray;
        AllowedValue: Text;
    begin
        foreach AllowedValue in AllowedValues.Split(',') do
            Allowed.Add(AllowedValue);
        Entry := ContractMgt.Parameter(Name, JsonType, Required, Description);
        Entry.Add('allowed', Allowed);
    end;

    local procedure FieldWithChildren(Name: Text; JsonType: Text; Description: Text; Children: JsonArray) Entry: JsonObject
    begin
        Entry := ContractMgt.ResponseField(Name, JsonType, Description);
        Entry.Add('children', Children);
    end;
}
