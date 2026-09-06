namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Registers the Subscription Billing message types on the Bifrost message type enum.
/// Every type is named Subscription.&lt;Domain&gt;.&lt;Action&gt; and covers an operation that the
/// generic Data.Records.Get / Data.Records.Set message types cannot perform on their own,
/// because it needs a Microsoft codeunit, record context at insert time, a BLOB filter,
/// or a preview-and-rollback run.
/// </summary>
enumextension 10035035 "Sub Msg Type ori" extends "Message Type ori"
{
    /// <summary>Creates a Subscription Line by applying a Subscription Package to a Subscription.</summary>
    value(10035036; "Subscription.Line.Create")
    {
        Caption = 'Subscription.Line.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Line Create Impl ori";
    }

    /// <summary>Attaches unassigned Subscription Lines to a customer Subscription Contract.</summary>
    value(10035037; "Subscription.Contract.GetLines")
    {
        Caption = 'Subscription.Contract.GetLines', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Con GetLines Impl ori";
    }

    /// <summary>Bills a customer Subscription Contract into an unposted sales invoice.</summary>
    value(10035038; "Subscription.Contract.CreateInvoice")
    {
        Caption = 'Subscription.Contract.CreateInvoice', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Con CrInvoice Impl ori";
    }

    /// <summary>Previews the customer contract billing result without writing anything.</summary>
    value(10035039; "Subscription.Contract.PreviewInvoice")
    {
        Caption = 'Subscription.Contract.PreviewInvoice', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Con PrvInvoice Impl ori";
    }

    /// <summary>Recalculates next billing and term dates across a Subscription Contract.</summary>
    value(10035040; "Subscription.Contract.UpdateLineDates")
    {
        Caption = 'Subscription.Contract.UpdateLineDates', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Con UpdDates Impl ori";
    }

    /// <summary>Refreshes foreign currency exchange rates on a Subscription Contract.</summary>
    value(10035041; "Subscription.Contract.UpdateExchangeRates")
    {
        Caption = 'Subscription.Contract.UpdateExchangeRates', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Con UpdFCY Impl ori";
    }

    /// <summary>Attaches unassigned Subscription Lines to a vendor Subscription Contract.</summary>
    value(10035042; "Subscription.VendorContract.GetLines")
    {
        Caption = 'Subscription.VendorContract.GetLines', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Vend GetLines Impl ori";
    }

    /// <summary>Bills a vendor Subscription Contract into an unposted purchase invoice.</summary>
    value(10035043; "Subscription.VendorContract.CreateInvoice")
    {
        Caption = 'Subscription.VendorContract.CreateInvoice', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Vend CrInvoice Impl ori";
    }

    /// <summary>Previews the vendor contract billing result without writing anything.</summary>
    value(10035044; "Subscription.VendorContract.PreviewInvoice")
    {
        Caption = 'Subscription.VendorContract.PreviewInvoice', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Vend PrvInv Impl ori";
    }

    /// <summary>Generates billing proposal lines for a billing template and date range.</summary>
    value(10035045; "Subscription.Billing.CreateProposal")
    {
        Caption = 'Subscription.Billing.CreateProposal', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Bil CrProposal Impl ori";
    }

    /// <summary>Turns billing proposal lines into invoices in a bulk run.</summary>
    value(10035046; "Subscription.Billing.CreateDocuments")
    {
        Caption = 'Subscription.Billing.CreateDocuments', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Bil CrDocs Impl ori";
    }

    /// <summary>Previews the bulk billing run without writing anything.</summary>
    value(10035047; "Subscription.Billing.PreviewDocuments")
    {
        Caption = 'Subscription.Billing.PreviewDocuments', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Bil PrvDocs Impl ori";
    }

    /// <summary>Writes the BLOB view filters on a Price Update Template.</summary>
    value(10035048; "Subscription.PriceUpdate.SetTemplateFilter")
    {
        Caption = 'Subscription.PriceUpdate.SetTemplateFilter', Locked = true;
        Implementation = "Msg Interface ori" = "Sub PU SetFilter Impl ori";
    }

    /// <summary>Builds a price update proposal from a Price Update Template.</summary>
    value(10035049; "Subscription.PriceUpdate.CreateProposal")
    {
        Caption = 'Subscription.PriceUpdate.CreateProposal', Locked = true;
        Implementation = "Msg Interface ori" = "Sub PU CrProposal Impl ori";
    }

    /// <summary>Applies a price update proposal to the Subscription Lines.</summary>
    value(10035050; "Subscription.PriceUpdate.Perform")
    {
        Caption = 'Subscription.PriceUpdate.Perform', Locked = true;
        Implementation = "Msg Interface ori" = "Sub PU Perform Impl ori";
    }

    /// <summary>Extends a Subscription Contract term with additional package lines.</summary>
    value(10035051; "Subscription.Renewal.Extend")
    {
        Caption = 'Subscription.Renewal.Extend', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Ren Extend Impl ori";
    }

    /// <summary>Creates a contract renewal sales quote.</summary>
    value(10035052; "Subscription.Renewal.CreateQuote")
    {
        Caption = 'Subscription.Renewal.CreateQuote', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Ren CrQuote Impl ori";
    }

    /// <summary>Imports usage data for metered Subscription Lines.</summary>
    value(10035053; "Subscription.Usage.ImportData")
    {
        Caption = 'Subscription.Usage.ImportData', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Usg Import Impl ori";
    }

    /// <summary>Processes imported usage data into billable quantities.</summary>
    value(10035054; "Subscription.Usage.Process")
    {
        Caption = 'Subscription.Usage.Process', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Usg Process Impl ori";
    }

    /// <summary>Releases deferred revenue or cost for a period.</summary>
    value(10035055; "Subscription.Deferral.Release")
    {
        Caption = 'Subscription.Deferral.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Def Release Impl ori";
    }

    /// <summary>Rebuilds the Subscription Contract analysis entries.</summary>
    value(10035056; "Subscription.Analysis.Recalculate")
    {
        Caption = 'Subscription.Analysis.Recalculate', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Ana Recalc Impl ori";
    }

    /// <summary>Builds real Subscription records from staged import rows.</summary>
    value(10035057; "Subscription.Import.CreateContracts")
    {
        Caption = 'Subscription.Import.CreateContracts', Locked = true;
        Implementation = "Msg Interface ori" = "Sub Imp CrContr Impl ori";
    }
}
