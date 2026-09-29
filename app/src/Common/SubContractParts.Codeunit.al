namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>Builds the shared contract chapters for Subscription Billing message types.</summary>
codeunit 10035075 "Sub Contract Parts ori"
{
    Access = Internal;

    /// <summary>Builds the request envelope.</summary>
    procedure GetEnvelope(MessageType: Text) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
        DataRequired: Boolean;
    begin
        DataRequired := not (MessageType in ['Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform']);
        Subject.Add('use', 'optional');
        Forms.Add('string');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The subject may carry the primary record number when the corresponding data key is omitted.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', DataRequired);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the request parameters read by the implementation.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The Subscription Header number; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionPackageCode', 'string', true, 'The Subscription Package code.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineStartDate', 'string', false, 'Optional ISO start date.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineEndDate', 'string', false, 'Optional ISO end date.'));
                    Parameters.Add(ContractMgt.Parameter('usageBasedBillingPackageLinesOnly', 'boolean', false, 'Whether to create only usage-based package lines.'));
                end;
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The customer or vendor contract number; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', false, 'Optional Subscription Header number.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineEntryNos', 'array', false, 'Optional whole-number Subscription Line entry numbers.'));
                end;
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The contract number; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('billingDate', 'string', false, 'Billing date in ISO format; defaults to WorkDate.'));
                    Parameters.Add(ContractMgt.Parameter('billingToDate', 'string', false, 'Optional inclusive billing end date.'));
                end;
            'Subscription.VendorContract.CreateInvoice':
                begin
                    Parameters.Add(ContractMgt.Parameter('documentDate', 'string', false, 'Document date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('vendorInvoiceNo', 'string', false, 'Vendor invoice number.'));
                end;
            'Subscription.Billing.CreateProposal':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template code; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('billingDate', 'string', false, 'Billing date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('billingToDate', 'string', false, 'Optional inclusive billing end date.'));
                    Parameters.Add(ContractMgt.Parameter('automatedBilling', 'boolean', false, 'Whether automated billing rules are applied.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template code; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('documentDate', 'string', false, 'Document date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('postDocuments', 'boolean', false, 'Whether created documents are posted.'));
                    Parameters.Add(ContractMgt.Parameter('groupBy', 'string', false, 'Optional grouping mode.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template code; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('groupBy', 'string', false, 'Optional grouping mode.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Rows to skip; defaults to zero.'));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size; capped by the Foundation limit.'));
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    Parameters.Add(ContractMgt.Parameter('priceUpdateTemplateCode', 'string', true, 'The Price Update Template code; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('filter', 'string', true, 'The Business Central table view filter.'));
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The filter target.'));
                end;
            'Subscription.Renewal.Extend':
                begin
                    Parameters.Add(ContractMgt.Parameter('subscriptionHeaderNo', 'string', true, 'The Subscription Header number; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('customerContractNo', 'string', false, 'Optional customer contract number.'));
                    Parameters.Add(ContractMgt.Parameter('vendorContractNo', 'string', false, 'Optional vendor contract number.'));
                    Parameters.Add(ContractMgt.Parameter('usageBasedBillingPackageLinesOnly', 'boolean', false, 'Whether to create only usage-based package lines.'));
                    Parameters.Add(ContractMgt.Parameter('supplierReferenceEntryNo', 'integer', false, 'Optional supplier reference entry number.'));
                end;
            'Subscription.Renewal.CreateQuote':
                Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The contract number; it may be supplied as subject.'));
            'Subscription.Usage.ImportData':
                begin
                    Parameters.Add(ContractMgt.Parameter('supplierNo', 'string', true, 'The usage data supplier number; it may be supplied as subject.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'The imported file name.'));
                    Parameters.Add(ContractMgt.Parameter('content', 'string', false, 'Usage content as text.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, 'Usage content encoded as base64.'));
                    Parameters.Add(ContractMgt.Parameter('runProcessing', 'boolean', false, 'Whether to process the imported data immediately.'));
                end;
            'Subscription.Usage.Process':
                Parameters.Add(ContractMgt.Parameter('usageDataImportEntryNo', 'integer', true, 'The usage data import entry number.'));
            'Subscription.Deferral.Release':
                begin
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in ISO format.'));
                    Parameters.Add(ContractMgt.Parameter('postUntilDate', 'string', false, 'Inclusive release date in ISO format.'));
                end;
            'Subscription.Analysis.Recalculate':
                Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Optional contract number; omit to recalculate all eligible contracts.'));
        end;
    end;

    /// <summary>Builds the record target when the operation addresses a record.</summary>
    procedure GetTarget(MessageType: Text) Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments', 'Subscription.Deferral.Release', 'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Import.CreateContracts'] then
            exit;
        Target.Add(ContractMgt.TargetEntry('subject or data', 'Business Central record number', 'The subject or corresponding data field identifies the record operated on.'));
    end;

    /// <summary>Builds the success response fields.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the operation completed.'));
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'The affected Subscription Header.'));
                    Fields.Add(ContractMgt.ResponseField('linesCreated', 'integer', 'Number of lines created.'));
                    Fields.Add(ContractMgt.ResponseField('createdLines', 'array', 'Created Subscription Line entry numbers.'));
                end;
            'Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The affected contract.'));
                    Fields.Add(ContractMgt.ResponseField('linesAttached', 'integer', 'Number of lines attached.'));
                    Fields.Add(ContractMgt.ResponseField('attachedLines', 'array', 'Attached line details.'));
                    Fields.Add(ContractMgt.ResponseField('linesSkipped', 'integer', 'Number of eligible lines skipped.'));
                end;
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The affected contract.'));
                    Fields.Add(ContractMgt.ResponseField('documents', 'array', 'Created or previewed document details.'));
                    Fields.Add(ContractMgt.ResponseField('billingLineCount', 'integer', 'Billing lines processed.'));
                end;
            'Subscription.Billing.CreateProposal':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The affected Billing Template.'));
                    Fields.Add(ContractMgt.ResponseField('proposalLinesCreated', 'integer', 'Number of proposal lines created.'));
                    Fields.Add(ContractMgt.ResponseField('proposalLineCount', 'integer', 'Total proposal line count.'));
                    Fields.Add(ContractMgt.ResponseField('contracts', 'array', 'Contract proposal summaries.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The affected Billing Template.'));
                    Fields.Add(ContractMgt.ResponseField('billingLinesProcessed', 'integer', 'Billing lines processed.'));
                    Fields.Add(ContractMgt.ResponseField('documentCount', 'integer', 'Number of documents created.'));
                    Fields.Add(ContractMgt.ResponseField('documents', 'array', 'Created document details.'));
                    Fields.Add(ContractMgt.ResponseField('posted', 'boolean', 'Whether documents were posted.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('preview', 'boolean', 'Always true for this operation.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Whether the preview was rolled back.'));
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', 'Rows skipped.'));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', 'Page size used.'));
                    Fields.Add(ContractMgt.ResponseField('documentCount', 'integer', 'Unpaginated document group count.'));
                    Fields.Add(ContractMgt.ResponseField('documents', 'array', 'Preview document groups.'));
                    Fields.Add(ContractMgt.ResponseField('hasMore', 'boolean', 'Whether more groups exist.'));
                    Fields.Add(ContractMgt.ResponseField('warnings', 'array', 'Preview warnings.'));
                end;
            'Subscription.Renewal.CreateQuote':
                Fields.Add(ContractMgt.ResponseField('quoteNo', 'string', 'The created renewal quote number.'));
            'Subscription.Usage.ImportData':
                Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The created usage import entry number.'));
            'Subscription.Import.CreateContracts':
                begin
                    Fields.Add(ContractMgt.ResponseField('stages', 'array', 'Import stage results.'));
                    Fields.Add(ContractMgt.ResponseField('errors', 'array', 'Row-level import errors.'));
                    Fields.Add(ContractMgt.ResponseField('errorsNote', 'string', 'Optional error truncation note.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the stable errors returned by the implementations.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform'] then begin
            Errors.Add(ContractMgt.TextErrorEntry('The requested operation is not exposed by the Microsoft Subscription Billing app.', 'The required Microsoft procedure is internal in this Business Central version.', 'Use the corresponding Microsoft client action, or upgrade when the procedure becomes public.'));
            exit;
        end;
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'A Business Central or Subscription Billing validation error prevented completion.', 'Correct the data or setup named by the error and retry.'));
        if MessageType in ['Subscription.Line.Create', 'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments', 'Subscription.Renewal.Extend', 'Subscription.Renewal.CreateQuote', 'Subscription.Analysis.Recalculate'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The requested Subscription Billing record does not exist.', 'Use the relevant list or record query to resolve an existing number.'));
    end;

    /// <summary>Builds the operation effect.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        if MessageType in ['Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.PreviewDocuments', 'Subscription.Analysis.Recalculate'] then
            Effect.Add('effect', 'read')
        else
            if MessageType in ['Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.Billing.CreateDocuments', 'Subscription.Renewal.Extend', 'Subscription.Renewal.CreateQuote', 'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts', 'Subscription.PriceUpdate.Perform', 'Subscription.Contract.UpdateLineDates', 'Subscription.Contract.UpdateExchangeRates'] then
                Effect.Add('effect', 'irreversible')
            else
                Effect.Add('effect', 'write');
        Effect.Add('changes', 'The operation invokes Microsoft Subscription Billing logic and changes the records described by the request.');
        Effect.Add('idempotent', MessageType in ['Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.PreviewDocuments', 'Subscription.Analysis.Recalculate']);
        Effect.Add('permissionSet', 'BIFROST SubBil ori');
        Effect.Add('preconditions', 'Microsoft Subscription Billing is installed and configured, and the caller has the required permissions.');
    end;

    /// <summary>Builds links to adjacent message types.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Subscription.Line.Create':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach created lines to a customer contract.'));
            'Subscription.Contract.GetLines':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Line.Create', 'Create Subscription Lines first when none exist.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create an invoice after attaching lines.'));
                end;
            'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach eligible lines before billing.'));
            'Subscription.VendorContract.GetLines':
                Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create a vendor invoice after attaching lines.'));
            'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.GetLines', 'Attach eligible lines before billing.'));
            'Subscription.Billing.CreateProposal':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents from the generated proposal.'));
            'Subscription.Billing.CreateDocuments':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PreviewDocuments', 'Preview the bulk run before writing documents.'));
            'Subscription.Billing.PreviewDocuments':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents after reviewing the preview.'));
            'Subscription.PriceUpdate.SetTemplateFilter':
                Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.CreateProposal', 'Create a proposal after setting filters.'));
            'Subscription.PriceUpdate.CreateProposal':
                Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.Perform', 'Apply a price update proposal.'));
            'Subscription.Renewal.Extend':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Renewal.CreateQuote', 'Create a renewal quote instead of extending directly.'));
            'Subscription.Usage.ImportData':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.Process', 'Process the imported usage entry.'));
            'Subscription.Usage.Process':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ImportData', 'Import usage data when no entry exists.'));
        end;
    end;
}
