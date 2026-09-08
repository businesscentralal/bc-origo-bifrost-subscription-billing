namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Runs the write half of a Subscription Billing message type in its own transaction.
/// The implementation codeunits invoke this through Codeunit.Run so that a failed write rolls
/// back on its own and is reported as a structured error, instead of leaving the request in a
/// half-written state. The three preview types are dispatched here too: their own cleanup does
/// not depend on this transaction being rolled back, but running them under the same isolation
/// as a write keeps a mid-way failure from leaking a half-built response. Message types Microsoft
/// has not exposed a public API for never reach this dispatcher.
/// </summary>
codeunit 10035059 "Sub Write Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        Dispatch(Rec);
    end;

    local procedure Dispatch(var Argument: Record "Message Argument ori")
    var
        LineCreateImpl: Codeunit "Sub Line Create Impl ori";
        ConGetLinesImpl: Codeunit "Sub Con GetLines Impl ori";
        ConCrInvoiceImpl: Codeunit "Sub Con CrInvoice Impl ori";
        ConPrvInvoiceImpl: Codeunit "Sub Con PrvInvoice Impl ori";
        VendGetLinesImpl: Codeunit "Sub Vend GetLines Impl ori";
        VendCrInvoiceImpl: Codeunit "Sub Vend CrInvoice Impl ori";
        VendPrvInvImpl: Codeunit "Sub Vend PrvInv Impl ori";
        BilCrProposalImpl: Codeunit "Sub Bil CrProposal Impl ori";
        BilCrDocsImpl: Codeunit "Sub Bil CrDocs Impl ori";
        BilPrvDocsImpl: Codeunit "Sub Bil PrvDocs Impl ori";
        PUSetFilterImpl: Codeunit "Sub PU SetFilter Impl ori";
        RenExtendImpl: Codeunit "Sub Ren Extend Impl ori";
        RenCrQuoteImpl: Codeunit "Sub Ren CrQuote Impl ori";
        UsgImportImpl: Codeunit "Sub Usg Import Impl ori";
        UsgProcessImpl: Codeunit "Sub Usg Process Impl ori";
        DefReleaseImpl: Codeunit "Sub Def Release Impl ori";
        AnaRecalcImpl: Codeunit "Sub Ana Recalc Impl ori";
        ImpCrContrImpl: Codeunit "Sub Imp CrContr Impl ori";
    begin
        case Argument."Type" of
            Argument."Type"::"Subscription.Line.Create":
                LineCreateImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Contract.GetLines":
                ConGetLinesImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Contract.CreateInvoice":
                ConCrInvoiceImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Contract.PreviewInvoice":
                ConPrvInvoiceImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.VendorContract.GetLines":
                VendGetLinesImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.VendorContract.CreateInvoice":
                VendCrInvoiceImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.VendorContract.PreviewInvoice":
                VendPrvInvImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Billing.CreateProposal":
                BilCrProposalImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Billing.CreateDocuments":
                BilCrDocsImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Billing.PreviewDocuments":
                BilPrvDocsImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.PriceUpdate.SetTemplateFilter":
                PUSetFilterImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Renewal.Extend":
                RenExtendImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Renewal.CreateQuote":
                RenCrQuoteImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Usage.ImportData":
                UsgImportImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Usage.Process":
                UsgProcessImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Deferral.Release":
                DefReleaseImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Analysis.Recalculate":
                AnaRecalcImpl.PerformWrite(Argument);
            Argument."Type"::"Subscription.Import.CreateContracts":
                ImpCrContrImpl.PerformWrite(Argument);
        end;
    end;
}
