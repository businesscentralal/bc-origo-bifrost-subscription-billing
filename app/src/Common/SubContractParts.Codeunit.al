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
            if MessageType in ['Subscription.Usage.Process', 'Subscription.Usage.DeleteData'] then
                Subject.Add('description', 'The Usage Data Import entry number, written as a whole number. When set it is used instead of data.usageDataImportEntryNo; a subject that is not a whole number is refused.')
            else
                Subject.Add('description', 'The ' + SubjectForm + '. When set it is used instead of data.' + DataKey + ', and it may be at most 20 characters long.');
        end else begin
            Subject.Add('use', 'notUsed');
            Subject.Add('description', 'The subject is not read by this message type.');
        end;
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', MessageType in ['Subscription.Line.Create', 'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.Renewal.Extend', 'Subscription.Usage.ImportData', 'Subscription.Billing.SetTemplateFilter', 'Subscription.Contract.RemoveLine', 'Subscription.Package.RemoveItemAssignment']);
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
    /// Builds parameters for the operations types that use shared dispatch.
    /// The existing types call the parameter procedure of their own domain below, which names keys literally
    /// so the ContractParameterKeys guard can compare them with the keys the type reads (#26).
    /// </summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        Entry: JsonObject;
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
            'Subscription.Billing.ClearProposal':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', false, 'The Billing Template whose proposal is cleared. May be supplied as the subject instead. Omit it to clear the billing lines without a Billing Template, which contractNo then has to narrow.'));
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Clears only the proposal lines of this Customer or Vendor Subscription Contract. Required when billingTemplateCode is omitted.'));
                end;
            'Subscription.Billing.DeleteDocuments':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', false, 'The Billing Template whose billing documents are deleted. May be supplied as the subject instead. Omit it for the documents made from billing lines without a Billing Template, which contractNo or documentNo then has to narrow.'));
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Deletes only the documents of this Customer or Vendor Subscription Contract.'));
                    Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Deletes only this unposted invoice or credit memo. A posted document number is refused by name.'));
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
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The Customer Subscription Contract to renew. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('contractLineNos', 'array', false, 'Renews only these contract lines, by their Line No., written as whole numbers. Every number must be a line of the contract. Omit it to renew every line with an end date.'));
                end;
            'Subscription.VendorContract.AddLinesToInvoice':
                begin
                    Parameters.Add(ContractMgt.Parameter('purchaseInvoiceNo', 'string', true, 'The unposted purchase invoice to add lines to. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineEntryNos', 'array', false, 'Adds only these Subscription Lines, written as whole numbers. Each must be an open vendor line of the invoice''s vendor, invoiced through a contract and without a pending billing line. Omit it to add every such line.'));
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', false, 'Without subscriptionLineEntryNos: adds only the lines of this Vendor Subscription Contract.'));
                    Parameters.Add(DateParameter('billingToDate', 'Bills each line up to this date. Omit it to bill each line up to the end of its next billing period, as the Get Vendor Contract Lines page proposes.'));
                end;
            'Subscription.Usage.DeleteData':
                begin
                    Parameters.Add(ContractMgt.Parameter('usageDataImportEntryNo', 'integer', true, 'The Usage Data Import entry to undo. May be supplied as the subject instead.'));
                    Entry := AllowedParameter('mode', 'string', false, 'resetLines deletes the imported lines and usage billing and keeps the file, so the import can be processed again; deleteImport deletes the import with its file. Any casing.', 'resetLines,deleteImport');
                    Entry.Add('default', 'resetLines');
                    Parameters.Add(Entry);
                end;
            'Subscription.Billing.SetTemplateFilter':
                begin
                    Parameters.Add(ContractMgt.Parameter('billingTemplateCode', 'string', true, 'The Billing Template to change. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('filter', 'string', true, 'A Business Central view, such as WHERE(Contract Type=FILTER(MONTHLY)), of Customer Subscription Contract (Partner Customer) or Vendor Subscription Contract (Partner Vendor). It is validated and normalised before it is stored; a view without filters clears the stored filter.'));
                end;
            'Subscription.Contract.RemoveLine':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The contract the line belongs to. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, 'Line No. of the contract line to remove.'));
                    Entry := AllowedParameter('partner', 'string', false, 'Customer for a Customer Subscription Contract, Vendor for a Vendor Subscription Contract. Any casing.', 'Customer,Vendor');
                    Entry.Add('default', 'Customer');
                    Parameters.Add(Entry);
                end;
            'Subscription.Package.RemoveItemAssignment':
                begin
                    Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, 'The item. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('subscriptionPackageCode', 'string', true, 'The Subscription Package to remove from the item.'));
                end;
            'Subscription.Contract.UpdateExchangeRates':
                begin
                    Parameters.Add(ContractMgt.Parameter('contractNo', 'string', true, 'The Subscription Contract to recalculate. May be supplied as the subject instead.'));
                    Entry := AllowedParameter('partner', 'string', false, 'Customer for a Customer Subscription Contract, Vendor for a Vendor Subscription Contract. Any casing.', 'Customer,Vendor');
                    Entry.Add('default', 'Customer');
                    Parameters.Add(Entry);
                    Parameters.Add(DateParameter('currencyFactorDate', 'The key date of the exchange rate, stored as Currency Factor Date on the lines. Defaults to the work date.'));
                    Parameters.Add(ContractMgt.Parameter('currencyFactor', 'number', false, 'The currency factor to store: foreign currency per unit of local currency. Omit it to use the exchange rate of currencyFactorDate, as the Exchange Rate Selection page proposes. Must be greater than zero.'));
                end;
            'Subscription.Contract.UpdateLineDates':
                begin
                    Entry := AllowedParameter('runMode', 'string', false, 'foreground runs the Job Queue Entry in this call and reports what it closed; background hands it to the job queue and returns at once. Any casing.', 'foreground,background');
                    Entry.Add('default', 'foreground');
                    Parameters.Add(Entry);
                end;
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
            'Subscription.Usage.ConnectSubscriptions':
                begin
                    Parameters.Add(ContractMgt.Parameter('supplierNo', 'string', true, 'The Usage Data Supplier whose subscriptions are connected. May be supplied as the subject instead.'));
                    Parameters.Add(ContractMgt.Parameter('entryNos', 'array', false, 'Connects only these Usage Data Supp. Subscription entries, written as whole numbers. Each must belong to the supplier, have a Connect to Subscription Method and not be connected yet. Omit it to connect every such entry of the supplier.'));
                end;
            'Subscription.Usage.DisconnectSubscription':
                begin
                    Parameters.Add(ContractMgt.Parameter('subscriptionLineEntryNo', 'integer', false, 'Entry No. of the connected Subscription Line. One of subscriptionLineEntryNo and usageDataSubscriptionEntryNo is required; when both are sent this one is used.'));
                    Parameters.Add(ContractMgt.Parameter('usageDataSubscriptionEntryNo', 'integer', false, 'Entry No. of the connected Usage Data Supp. Subscription, as an alternative to subscriptionLineEntryNo.'));
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
        Parameters.Add(WithBooleanDefault(ContractMgt.Parameter('postDocuments', 'boolean', false, 'When true, the created sales documents are posted. Purchase documents are never posted.'), false));
        Parameters.Add(AsGroupBy(ContractMgt.Parameter('groupBy', 'string', false, 'Contract creates one document per contract; Customer creates one document per Bill-to Customer No. and needs customer proposal lines. Any casing.')));
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
        Parameters.Add(ContractMgt.Parameter('contractLineNos', 'array', false, 'Renews only these contract lines, by their Line No., written as whole numbers. Every number must be a line of the contract. Omit it to renew every line with an end date.'));
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
            'Subscription.Billing.ClearProposal':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The cleared Billing Template; empty for the billing lines without a template.'));
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract the call was narrowed to; empty when it was not.'));
                    Fields.Add(ContractMgt.ResponseField('billingLinesDeleted', 'integer', 'Number of billing proposal lines deleted. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionLinesReset', 'integer', 'Number of distinct Subscription Lines whose Next Billing Date was reset.'));
                    Fields.Add(ContractMgt.ResponseField('contracts', 'array', 'Contract numbers of the deleted lines.'));
                end;
            'Subscription.Billing.DeleteDocuments':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The Billing Template; empty for the billing lines without a template.'));
                    Fields.Add(ContractMgt.ResponseField('documentsDeleted', 'integer', 'Number of unposted documents deleted. Zero is still a success.'));
                    Children.Add(ContractMgt.ResponseField('partner', 'string', 'Customer or Vendor.'));
                    Children.Add(ContractMgt.ResponseField('documentType', 'string', 'Invoice or Credit Memo.'));
                    Children.Add(ContractMgt.ResponseField('documentNo', 'string', 'No. of the deleted document.'));
                    Fields.Add(FieldWithChildren('documents', 'array', 'One entry per deleted document.', Children));
                    Fields.Add(ContractMgt.ResponseField('billingLinesReturnedToProposal', 'integer', 'Billing lines of the deleted documents that are back in the proposal, without a document.'));
                    Fields.Add(ContractMgt.ResponseField('billingLinesRemoved', 'integer', 'Billing lines of the deleted documents that Microsoft deleted, with their Subscription Line reset.'));
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
            'Subscription.VendorContract.AddLinesToInvoice':
                begin
                    Fields.Add(ContractMgt.ResponseField('purchaseInvoiceNo', 'string', 'The purchase invoice.'));
                    Fields.Add(ContractMgt.ResponseField('vendorNo', 'string', 'Its Buy-from Vendor No.'));
                    Fields.Add(ContractMgt.ResponseField('linesAdded', 'integer', 'Purchase lines the invoice gained. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionLineEntryNos', 'array', 'Entry No. of every Subscription Line that was proposed onto the invoice.'));
                end;
            'Subscription.Usage.DeleteData':
                begin
                    Fields.Add(ContractMgt.ResponseField('usageDataImportEntryNo', 'integer', 'The Usage Data Import entry.'));
                    Fields.Add(ContractMgt.ResponseField('mode', 'string', 'resetLines or deleteImport, as run.'));
                    Fields.Add(ContractMgt.ResponseField('usageDataBillingDeleted', 'integer', 'Usage Data Billing rows deleted.'));
                    Fields.Add(ContractMgt.ResponseField('importDeleted', 'boolean', 'True when the Usage Data Import itself was deleted.'));
                    Fields.Add(ContractMgt.ResponseField('processingStatus', 'string', 'resetLines only: the Processing Status after the reset, None.'));
                end;
            'Subscription.Billing.SetTemplateFilter':
                begin
                    Fields.Add(ContractMgt.ResponseField('billingTemplateCode', 'string', 'The changed Billing Template.'));
                    Fields.Add(ContractMgt.ResponseField('partner', 'string', 'Customer or Vendor: the contract table the filter applies to.'));
                    Fields.Add(ContractMgt.ResponseField('filter', 'string', 'The stored, normalised view; empty when the filter was cleared.'));
                end;
            'Subscription.Contract.RemoveLine':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The contract.'));
                    Fields.Add(ContractMgt.ResponseField('partner', 'string', 'Customer or Vendor.'));
                    Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line No. of the removed contract line.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'The Subscription Line that is now unassigned; 0 for a comment line.'));
                end;
            'Subscription.Package.RemoveItemAssignment':
                begin
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionPackageCode', 'string', 'The package removed from the item.'));
                    Fields.Add(ContractMgt.ResponseField('wasStandard', 'boolean', 'True when it was a standard package of the item.'));
                end;
            'Subscription.Contract.UpdateExchangeRates':
                begin
                    Fields.Add(ContractMgt.ResponseField('contractNo', 'string', 'The recalculated contract.'));
                    Fields.Add(ContractMgt.ResponseField('partner', 'string', 'Customer or Vendor.'));
                    Fields.Add(ContractMgt.ResponseField('currencyCode', 'string', 'The contract''s Currency Code, now on every recalculated line.'));
                    Fields.Add(ContractMgt.ResponseField('currencyFactor', 'string', 'The currency factor used, as a culture-invariant decimal string.'));
                    Fields.Add(ContractMgt.ResponseField('currencyFactorDate', 'string', 'The key date used, as YYYY-MM-DD.'));
                    Fields.Add(ContractMgt.ResponseField('linesRecalculated', 'integer', 'Subscription Lines recalculated. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('linesSkipped', 'integer', 'Subscription Lines left unchanged because their contract line is closed.'));
                end;
            'Subscription.Contract.UpdateLineDates':
                begin
                    Fields.Add(ContractMgt.ResponseField('runMode', 'string', 'foreground or background, as run.'));
                    Fields.Add(ContractMgt.ResponseField('alreadyQueued', 'boolean', 'True when a Job Queue Entry for codeunit 8058 was already Ready, Waiting or In Process; nothing new was created or run, and jobQueueEntryId and jobQueueStatus describe that entry.'));
                    Fields.Add(ContractMgt.ResponseField('jobQueueEntryId', 'string', 'ID of the Job Queue Entry, a GUID without braces.'));
                    Fields.Add(ContractMgt.ResponseField('jobQueueStatus', 'string', 'Status of the entry: Ready, Waiting, In Process, On Hold, Error or Finished. Finished means the entry was removed after its run.'));
                    Fields.Add(ContractMgt.ResponseField('result', 'string', 'Foreground only: Success or Error, from the Job Queue Log Entry of the run.'));
                    Fields.Add(ContractMgt.ResponseField('error', 'string', 'Foreground only: the error the run stopped on; empty when it succeeded.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionLinesClosed', 'integer', 'Foreground only: Subscription Lines closed during the call.'));
                    Fields.Add(ContractMgt.ResponseField('customerContractLinesClosed', 'integer', 'Foreground only: Cust. Sub. Contract Lines closed during the call.'));
                    Fields.Add(ContractMgt.ResponseField('vendorContractLinesClosed', 'integer', 'Foreground only: Vend. Sub. Contract Lines closed during the call.'));
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
            'Subscription.Usage.ConnectSubscriptions':
                begin
                    Fields.Add(ContractMgt.ResponseField('supplierNo', 'string', 'The Usage Data Supplier.'));
                    Fields.Add(ContractMgt.ResponseField('connected', 'integer', 'Entries now connected to a Subscription Line. Zero is still a success.'));
                    Fields.Add(ContractMgt.ResponseField('skipped', 'integer', 'Entries Microsoft could not connect; see reason.'));
                    Children.Add(ContractMgt.ResponseField('entryNo', 'integer', 'Entry No. of the Usage Data Supp. Subscription.'));
                    Children.Add(ContractMgt.ResponseField('connected', 'boolean', 'True when the entry is now connected.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'The Subscription it is connected to; empty when skipped.'));
                    Children.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'The Subscription Line it is connected to; 0 when skipped.'));
                    Children.Add(ContractMgt.ResponseField('reason', 'string', 'Why Microsoft skipped the entry; empty when it was connected.'));
                    Fields.Add(FieldWithChildren('entries', 'array', 'One entry per supplier subscription the call tried to connect.', Children));
                end;
            'Subscription.Usage.DisconnectSubscription':
                begin
                    Fields.Add(ContractMgt.ResponseField('subscriptionLineEntryNo', 'integer', 'The Subscription Line that was disconnected.'));
                    Fields.Add(ContractMgt.ResponseField('subscriptionHeaderNo', 'string', 'Its Subscription.'));
                    Fields.Add(ContractMgt.ResponseField('usageDataSubscriptionEntryNo', 'integer', 'The Usage Data Supp. Subscription that was disconnected.'));
                    Fields.Add(ContractMgt.ResponseField('supplierReferenceEntryNo', 'integer', 'The Supplier Reference Entry No. the link used.'));
                    Fields.Add(ContractMgt.ResponseField('linesDisconnected', 'integer', 'Lines of the Subscription whose Supplier Reference Entry No. was cleared.'));
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
                    Children.Add(ContractMgt.ResponseField('processed', 'integer', 'Staging rows the stage acted on. Skipped rows are left out of this count.'));
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
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the BIFROST Force ori permission set. Nothing is created or run.', 'Have BIFROST Force ori assigned, then call again.'));
        end;

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
            if MessageType in ['Subscription.Contract.CreateInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Renewal.Extend', 'Subscription.Renewal.CreateQuote', 'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts', 'Subscription.PriceUpdate.Perform', 'Subscription.Contract.UpdateLineDates', 'Subscription.Billing.ClearProposal', 'Subscription.Billing.DeleteDocuments', 'Subscription.Usage.ConnectSubscriptions', 'Subscription.Usage.DeleteData'] then
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
                begin
                    Preconditions.Add('The Usage Data Import entry exists and is not Closed.');
                    Preconditions.Add('The supplier subscriptions in the file are connected to Subscriptions (Subscription.Usage.ConnectSubscriptions); Process Imported Lines fails on an unconnected one.');
                end;
            'Subscription.Usage.ConnectSubscriptions':
                Preconditions.Add('Each entry to connect has Connect to Sub. Header No. set, which sets its Connect to Subscription Method; the Subscription has usage based lines (Existing Subscription Lines) or its item has a usage based package (New Subscription Lines).');
            'Subscription.Usage.DisconnectSubscription':
                Preconditions.Add('The Subscription Line is connected: it has a Supplier Reference Entry No. that a supplier subscription carries.');
            'Subscription.Billing.ClearProposal':
                begin
                    Preconditions.Add('The selected proposal lines are not on a document yet.');
                    Preconditions.Add('When any Billing Template bills automatically, the user has Auto Contract Billing in User Setup.');
                end;
            'Subscription.Billing.DeleteDocuments':
                begin
                    Preconditions.Add('The documents are not posted.');
                    Preconditions.Add('When any Billing Template bills automatically, the user has Auto Contract Billing in User Setup.');
                end;
            'Subscription.VendorContract.AddLinesToInvoice':
                begin
                    Preconditions.Add('The purchase invoice is unposted.');
                    Preconditions.Add('No contract has billing proposal lines without a Billing Template that are not on a document.');
                end;
            'Subscription.Usage.DeleteData':
                Preconditions.Add('No Usage Data Billing row of the import is on a billing line or a document.');
            'Subscription.Contract.RemoveLine':
                Preconditions.Add('The contract line is open, on no billing line, never billed, and without unreleased deferrals.');
            'Subscription.Contract.UpdateExchangeRates':
                Preconditions.Add('The contract has a Currency Code, and an exchange rate exists for that currency on currencyFactorDate unless currencyFactor is sent.');
            'Subscription.Contract.UpdateLineDates':
                begin
                    Preconditions.Add('The caller holds the BIFROST Force ori permission set, checked before anything is read: scheduling work through the job queue is reserved for it.');
                    Preconditions.Add('The caller may create and run Job Queue Entries: write permission on Job Queue Entry, Job Queue Log Entry, Error Message Register and Error Message.');
                end;
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
            'Subscription.Contract.CreateInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.DeleteDocuments', 'Undo: delete the unposted document (no billingTemplateCode, with contractNo or documentNo).'));
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
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Renewal.CreateQuote', 'Renew lines before their end date instead of letting them close.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Bill the last period first: a line closes only once it is fully invoiced.'));
                end;
            'Subscription.Contract.UpdateExchangeRates':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Create an invoice once exchange rates are current.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create a vendor invoice once exchange rates are current.'));
                end;
            'Subscription.VendorContract.GetLines':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create a vendor invoice after attaching lines.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.PreviewInvoice', 'See what would be billed after attaching lines.'));
                end;
            'Subscription.VendorContract.CreateInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.DeleteDocuments', 'Undo: delete the unposted document (no billingTemplateCode, with contractNo or documentNo).'));
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
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.ClearProposal', 'Undo: delete the proposal and reset the Next Billing Dates.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents from the generated proposal.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PreviewDocuments', 'See the documents the proposal would become.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.CreateInvoice', 'Bill one customer contract without a Billing Template.'));
                end;
            'Subscription.Billing.CreateDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.DeleteDocuments', 'Undo: delete the unposted documents and return their lines to the proposal.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.PreviewDocuments', 'Preview the bulk run before writing documents.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal lines this call consumes.'));
                end;
            'Subscription.Billing.PreviewDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create documents after reviewing the preview.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal lines this call reads.'));
                end;
            'Subscription.VendorContract.AddLinesToInvoice':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.CreateInvoice', 'Create a new purchase invoice for a vendor contract instead.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.DeleteDocuments', 'Undo: delete the purchase invoice and reset the lines.'));
                end;
            'Subscription.Usage.DeleteData':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.Process', 'Process the import again after resetLines.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.ClearProposal', 'Clear the billing proposal first when usage billing is on a billing line.'));
                end;
            'Subscription.Billing.SetTemplateFilter':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create a proposal for the filtered contracts.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.PriceUpdate.SetTemplateFilter', 'The same validated write for Price Update Templates.'));
                end;
            'Subscription.Contract.RemoveLine':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Contract.GetLines', 'Attach the detached Subscription Line to a customer contract again.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.VendorContract.GetLines', 'Attach the detached Subscription Line to a vendor contract again.'));
                end;
            'Subscription.Package.RemoveItemAssignment':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Line.Create', 'Apply a package to a Subscription directly.'));
            'Subscription.Billing.ClearProposal':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.DeleteDocuments', 'Delete the documents first when proposal lines are already on one.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateProposal', 'Create the proposal again.'));
                end;
            'Subscription.Billing.DeleteDocuments':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.ClearProposal', 'Clear the proposal the documents were made from.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Billing.CreateDocuments', 'Create the documents again.'));
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
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.Process', 'Process the imported usage entry.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ConnectSubscriptions', 'Connect new supplier subscriptions before processing.'));
                end;
            'Subscription.Usage.Process':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ConnectSubscriptions', 'Run first for new supplier subscriptions: processing fails on an unconnected one.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ImportData', 'Import usage data when no entry exists.'));
                end;
            'Subscription.Usage.ConnectSubscriptions':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.Process', 'Process the imported usage once the subscriptions are connected.'));
                    Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.DisconnectSubscription', 'Remove a link again.'));
                end;
            'Subscription.Usage.DisconnectSubscription':
                Related.Add(ContractMgt.RelatedEntry('Subscription.Usage.ConnectSubscriptions', 'Connect the supplier subscription again, for example to another Subscription.'));
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
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.PreviewDocuments', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.ClearProposal', 'Subscription.Billing.DeleteDocuments':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateProposal', 'Create the billing proposal lines for a Billing Template.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.PreviewDocuments', 'Review the documents the proposal would become, and any warnings.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Billing.CreateDocuments', 'Turn the proposal lines into documents.'));
                    Workflow.Add('text', 'Bill every contract a Billing Template covers in one run.');
                end;
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.SetTemplateFilter', 'Narrow the Price Update Template to the contracts, subscriptions or lines to update.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.CreateProposal', 'Create the Contract Price Update Lines and review the new prices.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.PriceUpdate.Perform', 'Apply the proposal to the Subscription Lines.'));
                    Workflow.Add('text', 'Raise or index contract prices through a Price Update Template. Nothing is posted.');
                end;
            'Subscription.Usage.ImportData', 'Subscription.Usage.Process', 'Subscription.Usage.ConnectSubscriptions', 'Subscription.Usage.DisconnectSubscription':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Usage.ImportData', 'Store the supplier''s usage file and parse it into imported lines.'));
                    Steps.Add(ContractMgt.WorkflowStep('Subscription.Usage.ConnectSubscriptions', 'Connect new supplier subscriptions to Subscriptions; needed once per new subscription.'));
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
    /// blocks by default. The subject and pronoun agree: one record is "it", several are "them".
    /// </summary>
    local procedure AddSetupPreconditions(MessageType: Text; var Preconditions: JsonArray)
    var
        Subject: Text;
        Pronoun: Text;
    begin
        case MessageType of
            'Subscription.Line.Create':
                begin
                    Subject := 'The Subscription Header and the Subscription Package';
                    Pronoun := 'them';
                end;
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Renewal.CreateQuote':
                begin
                    Subject := 'The Customer Subscription Contract';
                    Pronoun := 'it';
                end;
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                begin
                    Subject := 'The Vendor Subscription Contract';
                    Pronoun := 'it';
                end;
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments':
                begin
                    Subject := 'The Billing Template';
                    Pronoun := 'it';
                end;
            'Subscription.Renewal.Extend':
                begin
                    Subject := 'The Subscription and the customer or vendor contract';
                    Pronoun := 'them';
                end;
            'Subscription.Usage.ImportData':
                begin
                    Subject := 'The Usage Data Supplier and its Generic Import Settings';
                    Pronoun := 'them';
                end;
            'Subscription.Import.CreateContracts':
                begin
                    Subject := 'The staging rows in Imported Subscription Header, Imported Cust. Sub. Contract and Imported Subscription Line';
                    Pronoun := 'them';
                end;
            else
                exit;
        end;
        Preconditions.Add(Subject + ' must already exist; this call does not create ' + Pronoun + '. Writing ' + Pronoun + ' with Data.Records.Set needs the Bifrost Setup write guard set to Open, or Change Log coverage on those Subscription Billing tables, because the guard is Blocked by default.');
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
                exit('Creates billing proposal lines under the Billing Template for the due Subscription Lines that match the template''s filter. No document is created and nothing is posted. ' +
                    'Microsoft Subscription Billing commits the proposal lines every CommitBatchSize (50) contracts, so a failure after such a commit does not roll back the lines already committed.');
            'Subscription.Billing.CreateDocuments':
                exit('Turns the template''s unbilled proposal lines into sales or purchase documents, and posts the sales documents when postDocuments is true. Microsoft commits each document as it creates it, so a failure part way leaves the earlier documents in place.');
            'Subscription.Billing.PreviewDocuments':
                exit('Reads the template''s unbilled proposal lines. Nothing is written.');
            'Subscription.Billing.ClearProposal':
                exit('Deletes the selected billing proposal lines with their delete trigger, which resets the Next Billing Date of each Subscription Line, recalculates the harmonized billing fields of the customer contract and unlinks Usage Data Billing rows. No document is touched.');
            'Subscription.Billing.DeleteDocuments':
                exit('Deletes the selected unposted sales or purchase invoices and credit memos with their delete trigger. Microsoft then returns their billing lines to the proposal, or deletes billing lines without a Billing Template and resets their Subscription Lines. Posted documents are never touched.');
            'Subscription.PriceUpdate.SetTemplateFilter':
                exit('Writes one of the three view filters on the Price Update Template. Contracts, Subscriptions and Subscription Lines are not touched.');
            'Subscription.PriceUpdate.CreateProposal':
                exit('Inserts Contract Price Update Lines (Sub. Contr. Price Update Line) for the template''s matching Subscription Lines. Subscription Lines, contracts and prices are not changed, nothing is posted and nothing is committed.');
            'Subscription.PriceUpdate.Perform':
                exit('Writes Subscription Lines: changes their prices, Next Price Update and Price Binding Period and archives the old values in the Subscription Line Archive, or inserts Planned Subscription Lines. ' +
                    'Deletes each performed Contract Price Update Line and commits after each line. Nothing is posted.');
            'Subscription.Contract.UpdateExchangeRates':
                exit('Writes Currency Code, Currency Factor and Currency Factor Date on every Subscription Line of the contract whose contract line is open, converts its Calculation Base Amount again from the local currency amount, which recalculates price and amount, flags its billing lines Update Required and archives the previous amounts. The contract itself is not changed.');
            'Subscription.Contract.UpdateLineDates':
                exit('Creates a Job Queue Entry for Microsoft''s codeunit 8058. In foreground mode the entry runs at once: every Subscription in the company gets its ended, fully invoiced Subscription Lines and their customer and vendor contract lines closed and the term dates of its other lines rolled forward, with a commit after each Subscription; the entry is then deleted and its Job Queue Log Entry kept. In background mode the entry is handed to the job queue, which does the same later. Nothing is created when such an entry is already pending.');
            'Subscription.Renewal.Extend':
                exit('Runs Microsoft''s Extend Sub. Contract Mgt. without its dialog: inserts Subscription Lines on the Subscription and contract lines on the named customer and vendor contracts.');
            'Subscription.Renewal.CreateQuote':
                exit('Deletes the contract''s Sub. Contract Renewal Lines, builds new ones from its Subscription Lines that have an end date (only the contractLineNos lines when given), and creates a renewal sales quote from them. Nothing is posted.');
            'Subscription.Usage.ImportData':
                exit('Creates a Usage Data Import with a Usage Data Blob holding the file and commits them, then runs the Create Imported Lines step, and Process Imported Lines when runProcessing is true, each after a commit. Nothing is posted.');
            'Subscription.Usage.Process':
                exit('Runs the requested processing steps on the Usage Data Import, committing before each, so a later failure does not undo an earlier step. Creates and processes Usage Data Billing rows; nothing is posted by this call.');
            'Subscription.VendorContract.AddLinesToInvoice':
                exit('Creates a template-less billing line for each selected Subscription Line, moves its Next Billing Date past the billed period, and turns the billing lines into lines of the existing purchase invoice through Microsoft''s billing document creation. Nothing is posted.');
            'Subscription.Usage.DeleteData':
                exit('resetLines: deletes the imported lines and the Usage Data Billing rows of the import and resets its Processing Status, Processing Step and reason; the stored file stays. deleteImport: deletes the Usage Data Import with Delete(true), which also deletes its file. Deleting a Usage Data Billing row reverts a rebilling Next Billing Date.');
            'Subscription.Billing.SetTemplateFilter':
                exit('Writes the Filter Blob of the Billing Template. Contracts, Subscriptions and billing lines are not touched; the next billing proposal from the template uses the new filter.');
            'Subscription.Contract.RemoveLine':
                exit('Deletes the contract line with its delete trigger, which detaches its Subscription Line from the contract (Subscription Contract No. cleared) and recalculates the harmonized billing fields of a customer contract. The Subscription Line is not deleted.');
            'Subscription.Package.RemoveItemAssignment':
                exit('Deletes the Item Subscription Package row. The Subscription Package and existing Subscription Lines are not touched.');
            'Subscription.Usage.ConnectSubscriptions':
                exit('Runs Microsoft''s Connect to Subscription for each selected supplier subscription. Existing Subscription Lines: the Subscription''s usage based lines get the Supplier Reference Entry No. and the supplier subscription gets the Subscription and line. New Subscription Lines: the current lines end the day before the connect date and the contracts are extended with new usage based lines. Disconnect does not undo the new lines. Imported usage rows of the supplier get the Subscription No.');
            'Subscription.Usage.DisconnectSubscription':
                exit('Clears the Supplier Reference Entry No. of the Subscription''s lines that carry it, and the Subscription No. and Subscription Line Entry No. of the supplier subscription. No line, contract or usage data is deleted.');
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
            'Subscription.Contract.GetLines', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.Renewal.CreateQuote':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Customer Subscription Contract No.');
            'Subscription.VendorContract.GetLines', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Vendor Subscription Contract No.');
            'Subscription.Contract.UpdateExchangeRates':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Customer or Vendor Subscription Contract No., following partner');
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments', 'Subscription.Billing.ClearProposal', 'Subscription.Billing.DeleteDocuments':
                SetSubjectKey(DataKey, SubjectForm, 'billingTemplateCode', 'Billing Template Code');
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                SetSubjectKey(DataKey, SubjectForm, 'priceUpdateTemplateCode', 'Price Update Template Code');
            'Subscription.Usage.ImportData', 'Subscription.Usage.ConnectSubscriptions':
                SetSubjectKey(DataKey, SubjectForm, 'supplierNo', 'Usage Data Supplier No.');
            'Subscription.Usage.Process', 'Subscription.Usage.DeleteData':
                SetSubjectKey(DataKey, SubjectForm, 'usageDataImportEntryNo', 'Usage Data Import Entry No.');
            'Subscription.VendorContract.AddLinesToInvoice':
                SetSubjectKey(DataKey, SubjectForm, 'purchaseInvoiceNo', 'Purchase Invoice No.');
            'Subscription.Billing.SetTemplateFilter':
                SetSubjectKey(DataKey, SubjectForm, 'billingTemplateCode', 'Billing Template Code');
            'Subscription.Contract.RemoveLine':
                SetSubjectKey(DataKey, SubjectForm, 'contractNo', 'Customer or Vendor Subscription Contract No., following partner');
            'Subscription.Package.RemoveItemAssignment':
                SetSubjectKey(DataKey, SubjectForm, 'itemNo', 'Item No.');
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
        if not (MessageType in ['Subscription.Deferral.Release', 'Subscription.Analysis.Recalculate', 'Subscription.Import.CreateContracts', 'Subscription.Contract.UpdateLineDates', 'Subscription.Billing.ClearProposal', 'Subscription.Billing.DeleteDocuments', 'Subscription.Usage.DisconnectSubscription', 'Subscription.PriceUpdate.Perform']) then
            AddBusinessCentralError(Errors, 'The request is missing the required parameter ''%1''.', 'A required parameter is missing, and the subject does not carry it either.', 'Send the parameter named in the error.');
        if not (MessageType in ['Subscription.Usage.Process', 'Subscription.Deferral.Release', 'Subscription.Import.CreateContracts', 'Subscription.Contract.UpdateLineDates', 'Subscription.Usage.DisconnectSubscription', 'Subscription.Usage.DeleteData']) then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is longer than the %2 characters allowed.', 'A record number or code, or the subject, is longer than 20 characters.', 'Send the number as it is stored in Business Central.');
        if MessageType in ['Subscription.Line.Create', 'Subscription.Contract.CreateInvoice', 'Subscription.Contract.PreviewInvoice', 'Subscription.VendorContract.CreateInvoice', 'Subscription.VendorContract.PreviewInvoice', 'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Deferral.Release', 'Subscription.VendorContract.AddLinesToInvoice', 'Subscription.PriceUpdate.CreateProposal'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', 'A date parameter is not a date in the ISO format.', 'Send the date as YYYY-MM-DD.');
        if MessageType in ['Subscription.Renewal.Extend', 'Subscription.Usage.Process', 'Subscription.Usage.DisconnectSubscription', 'Subscription.Usage.DeleteData', 'Subscription.Contract.RemoveLine'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', 'An integer parameter is not a number.', 'Send a whole number.');
        if MessageType in ['Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines', 'Subscription.Renewal.Extend', 'Subscription.Usage.Process', 'Subscription.Import.CreateContracts', 'Subscription.Usage.ConnectSubscriptions', 'Subscription.Renewal.CreateQuote', 'Subscription.VendorContract.AddLinesToInvoice'] then
            AddBusinessCentralError(Errors, 'The parameter ''%1'' must be a JSON array.', 'An array parameter has a value that is not an array.', 'Send a JSON array, or leave the parameter out.');
        if MessageType in ['Subscription.Contract.GetLines', 'Subscription.VendorContract.GetLines', 'Subscription.Usage.ConnectSubscriptions', 'Subscription.Renewal.CreateQuote', 'Subscription.VendorContract.AddLinesToInvoice'] then
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
            'Subscription.Billing.CreateProposal', 'Subscription.Billing.CreateDocuments', 'Subscription.Billing.PreviewDocuments', 'Subscription.Billing.ClearProposal', 'Subscription.Billing.DeleteDocuments':
                AddNotFoundError(Errors, 'The Billing Template ''%1'' does not exist.', 'billingTemplateCode or the subject names no Billing Template.');
            'Subscription.PriceUpdate.SetTemplateFilter', 'Subscription.PriceUpdate.CreateProposal', 'Subscription.PriceUpdate.Perform':
                AddNotFoundError(Errors, 'The Price Update Template ''%1'' does not exist.', 'priceUpdateTemplateCode or the subject names no Price Update Template.');
            'Subscription.Billing.SetTemplateFilter':
                AddNotFoundError(Errors, 'The Billing Template ''%1'' does not exist.', 'billingTemplateCode or the subject names no Billing Template.');
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
            'Subscription.Billing.ClearProposal':
                begin
                    AddBusinessCentralError(Errors, 'The request must name a Billing Template in ''billingTemplateCode'' or the subject, or, for the billing lines without a Billing Template, a contract in ''contractNo''.', 'Neither a Billing Template nor a contract was given.', 'Send billingTemplateCode, or contractNo for the lines without a template.');
                    AddBusinessCentralError(Errors, '%1 billing line(s) of Billing Template ''%2'' are already on document %3. ...', 'A selected proposal line is already on an unposted document. Nothing is deleted.', 'Delete the documents first with Subscription.Billing.DeleteDocuments.');
                    AddAutomationError(Errors);
                    AddBusinessCentralError(Errors, 'Only last Billing Line for Subscription Line can be deleted or all Billing Lines. ...', 'A later billing line of the same Subscription Line sits under another Billing Template or contract. Nothing is deleted.', 'Clear that proposal first, or clear without contractNo.');
                end;
            'Subscription.Billing.DeleteDocuments':
                begin
                    AddBusinessCentralError(Errors, 'The request must name a Billing Template in ''billingTemplateCode'' or the subject, or, for the billing lines without a Billing Template, a contract in ''contractNo'' or a document in ''documentNo''.', 'No Billing Template, contract or document was given.', 'Send billingTemplateCode, or contractNo or documentNo for the documents without a template.');
                    AddBusinessCentralError(Errors, 'Document %1 is posted and cannot be deleted. ...', 'documentNo names a posted invoice or credit memo.', 'Cancel or correct the posted document, for example with Sales.SalesInvoice.Cancel or Sales.SalesInvoice.Correct.');
                    AddBusinessCentralError(Errors, 'No billing line of Billing Template ''%1'' is on document %2.', 'documentNo names no unposted document of the selected billing lines.', 'Use a document number the template''s billing lines carry.');
                    AddAutomationError(Errors);
                end;
            'Subscription.PriceUpdate.SetTemplateFilter':
                begin
                    AddBusinessCentralError(Errors, 'The parameter ''target'' must be one of ''contract'', ''subscription'' or ''line'', not ''%1''.', 'target is none of the three names.', 'Send contract, subscription or line.');
                    AddBusinessCentralError(Errors, 'The parameter ''filter'' is not a valid Business Central view for target ''%1''. ...', 'Business Central cannot parse filter as a view of the target''s table.', 'Send a view such as WHERE(Field=FILTER(Value)) with field names of that table.');
                end;
            'Subscription.VendorContract.AddLinesToInvoice':
                begin
                    AddNotFoundError(Errors, 'The purchase invoice ''%1'' does not exist.', 'purchaseInvoiceNo or the subject names no unposted purchase invoice.');
                    AddBusinessCentralError(Errors, 'The purchase invoice ''%1'' is posted. ...', 'The number belongs to a posted purchase invoice.', 'Use an unposted purchase invoice of the vendor.');
                    AddNotFoundError(Errors, 'Subscription Line %1 does not exist.', 'An entry of subscriptionLineEntryNos names no Subscription Line.');
                    AddBusinessCentralError(Errors, 'Subscription Line %1 belongs to a vendor contract of another vendor than ''%2'', ...', 'A listed line is on a contract of another vendor.', 'List only lines of the invoice''s vendor.');
                    AddBusinessCentralError(Errors, 'Subscription Line %1 cannot be added: ...', 'A listed line is not a vendor contract line, is closed, or is already on a billing line.', 'List only open vendor contract lines without a pending billing line.');
                    AddBusinessCentralError(Errors, 'There are %1 pending billing proposal line(s) without a Billing Template for contract ''%2''. ...', 'Template-less proposal lines are pending; Microsoft would add them to this invoice too.', 'Bill or clear that proposal first, for example with Subscription.Billing.ClearProposal and contractNo.');
                end;
            'Subscription.Usage.DeleteData':
                begin
                    AddBusinessCentralError(Errors, 'The subject ''%1'' is not a Usage Data Import entry number. ...', 'The subject is set but is not a whole number.', 'Send the entry number as the subject, or as usageDataImportEntryNo.');
                    AddNotFoundError(Errors, 'The Usage Data Import entry %1 does not exist.', 'No Usage Data Import has that entry number.');
                    AddBusinessCentralError(Errors, 'The parameter ''mode'' must be either ''resetLines'' or ''deleteImport'', not ''%1''.', 'mode is neither resetLines nor deleteImport.', 'Send resetLines or deleteImport, or leave mode out.');
                    AddBusinessCentralError(Errors, 'Usage Data Import entry %1 has usage billing on document %2. ...', 'Usage billing of the import is on a document, posted or not.', 'Delete or cancel that document first; posted usage cannot be imported again.');
                    AddBusinessCentralError(Errors, 'Usage Data Import entry %1 has usage billing on billing line %2. ...', 'Usage billing of the import is on a billing proposal line.', 'Clear the proposal first with Subscription.Billing.ClearProposal.');
                end;
            'Subscription.Billing.SetTemplateFilter':
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidFilterField, 'Foundation''s view validation refused filter: a field the contract table does not have, a field the caller may not read, or a view that does not parse. Nothing is written.', 'Send a view such as WHERE(Field=FILTER(Value)) with field names of the template''s contract table.'));
            'Subscription.Contract.RemoveLine':
                begin
                    AddNotFoundError(Errors, 'Line %1 of Customer Subscription Contract ''%2'' does not exist.', 'partner is Customer (the default) and the contract has no such line.');
                    AddNotFoundError(Errors, 'Line %1 of Vendor Subscription Contract ''%2'' does not exist.', 'partner is Vendor and the contract has no such line.');
                    AddBusinessCentralError(Errors, 'The parameter ''%1'' must be either ''Customer'' or ''Vendor''.', 'partner is neither Customer nor Vendor.', 'Send Customer or Vendor, or leave partner out.');
                    AddBusinessCentralError(Errors, 'Line %1 of contract ''%2'' is closed. ...', 'The contract line is closed.', 'Leave closed lines in place; they keep the history of ended Subscription Lines.');
                    AddBusinessCentralError(Errors, 'Line %1 of contract ''%2'' is on a billing line. ...', 'The line is on a billing proposal line or unposted document.', 'Clear the proposal or delete the document first (Subscription.Billing.ClearProposal, Subscription.Billing.DeleteDocuments).');
                    AddBusinessCentralError(Errors, 'Line %1 of contract ''%2'' has already been billed, ...', 'The line has archived billing lines.', 'Close the Subscription Line instead, for example by giving it an end date.');
                    AddBusinessCentralError(Errors, 'Line %1 of contract ''%2'' has unreleased deferrals. ...', 'The line has deferrals that are not released.', 'Release the deferrals first.');
                end;
            'Subscription.Package.RemoveItemAssignment':
                AddNotFoundError(Errors, 'Subscription Package ''%1'' is not assigned to item ''%2''.', 'The item has no Item Subscription Package row for that package.');
            'Subscription.Contract.UpdateExchangeRates':
                begin
                    AddNotFoundError(Errors, 'The Customer Subscription Contract ''%1'' does not exist.', 'partner is Customer (the default) and contractNo or the subject names no Customer Subscription Contract.');
                    AddNotFoundError(Errors, 'The Vendor Subscription Contract ''%1'' does not exist.', 'partner is Vendor and contractNo or the subject names no Vendor Subscription Contract.');
                    AddBusinessCentralError(Errors, 'The parameter ''%1'' must be either ''Customer'' or ''Vendor''.', 'partner is neither Customer nor Vendor.', 'Send Customer or Vendor, or leave partner out.');
                    AddBusinessCentralError(Errors, 'Subscription Contract ''%1'' has no Currency Code, so its Subscription Lines are in local currency ...', 'The contract is in local currency.', 'Set the Currency Code on the contract first; nothing needs recalculating in local currency.');
                    AddBusinessCentralError(Errors, 'The exchange rate for currency ''%1'' on %2 is %3. ...', 'currencyFactor is zero or negative, or no exchange rate exists for currencyFactorDate.', 'Send a currencyFactor greater than zero, or set up the exchange rate.');
                    AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid date. Use the ISO format YYYY-MM-DD.', 'currencyFactorDate is not a date in the ISO format.', 'Send the date as YYYY-MM-DD.');
                    AddBusinessCentralError(Errors, 'The parameter ''%1'' is not a valid number. Use a decimal point, for example 1234.56.', 'currencyFactor is not a number.', 'Send a number with a decimal point.');
                end;
            'Subscription.Contract.UpdateLineDates':
                AddBusinessCentralError(Errors, 'The parameter ''runMode'' must be either ''foreground'' or ''background'', not ''%1''.', 'runMode is neither foreground nor background.', 'Send foreground or background, or leave runMode out.');
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
                    AddBusinessCentralError(Errors, 'Line %1 of contractLineNos is not a line of Customer Subscription Contract ''%2''.', 'A listed contract line number does not exist on the contract.', 'Send Line No. values of the contract''s lines.');
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
            'Subscription.Usage.ConnectSubscriptions':
                begin
                    AddNotFoundError(Errors, 'The Usage Data Supplier ''%1'' does not exist.', 'supplierNo or the subject names no Usage Data Supplier.');
                    AddNotFoundError(Errors, 'Usage Data Supp. Subscription entry %1 does not exist for supplier ''%2''.', 'An entry of entryNos does not exist or belongs to another supplier.');
                    AddBusinessCentralError(Errors, 'Usage Data Supp. Subscription entry %1 has no Connect to Subscription Method. ...', 'A listed entry has no method, because Connect to Sub. Header No. is not set.', 'Set Connect to Sub. Header No. on the entry first, for example with Data.Records.Set.');
                    AddBusinessCentralError(Errors, 'Usage Data Supp. Subscription entry %1 is already connected to Subscription Line %2. ...', 'A listed entry is connected already.', 'Disconnect it first with Subscription.Usage.DisconnectSubscription, or leave it out.');
                    AddBusinessCentralError(Errors, 'Usage Data Supp. Subscription entries %1 and %2 both connect to Subscription ''%3''. ...', 'Two selected entries name the same Subscription; Microsoft would ask for confirmation, which an unattended call cannot give.', 'Connect them in separate calls, after checking that this is intended.');
                end;
            'Subscription.Usage.DisconnectSubscription':
                begin
                    AddBusinessCentralError(Errors, 'The request must supply ''subscriptionLineEntryNo'' or ''usageDataSubscriptionEntryNo''.', 'Neither parameter was sent.', 'Send one of the two entry numbers.');
                    AddNotFoundError(Errors, 'Subscription Line %1 does not exist.', 'subscriptionLineEntryNo names no Subscription Line.');
                    AddNotFoundError(Errors, 'Usage Data Supp. Subscription entry %1 does not exist.', 'usageDataSubscriptionEntryNo names no entry.');
                    AddBusinessCentralError(Errors, 'Usage Data Supp. Subscription entry %1 is not connected to a Subscription Line.', 'The supplier subscription has no Subscription Line.', 'Nothing to disconnect.');
                    AddBusinessCentralError(Errors, 'Subscription Line %1 is not connected to a usage data supplier''s subscription.', 'The line has no Supplier Reference Entry No., or no supplier subscription carries it.', 'Nothing to disconnect.');
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

    local procedure AddAutomationError(var Errors: JsonArray)
    begin
        AddBusinessCentralError(Errors, 'You are not authorized to clear billing proposals or delete billing documents while a Billing Template bills automatically. ...', 'A Billing Template has Automation set and the user lacks Auto Contract Billing in User Setup.', 'Set Auto Contract Billing on the user in User Setup, as the client requires.');
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
    /// <summary>Shared operations contract helper.</summary>

    /// <summary>Shared operations contract helper.</summary>

    /// <summary>Shared operations contract helper.</summary>

    /// <summary>Shared operations contract helper.</summary>

    /// <summary>Shared operations contract helper.</summary>

    /// <summary>Shared operations contract helper.</summary>

    local procedure PartnerContractName(MessageType: Text): Text
    begin
        if MessageType.StartsWith('Subscription.VendorContract.') then
            exit('Vendor Subscription Contract');
        exit('Customer Subscription Contract');
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

}
