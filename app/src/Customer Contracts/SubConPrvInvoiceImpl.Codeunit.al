namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Contract.PreviewInvoice</c> Bifrost message type.
/// Shows what <c>Subscription.Contract.CreateInvoice</c> would bill for one customer
/// Subscription Contract without ever creating a document. The contract's due Subscription
/// Lines are handed to Microsoft's ad-hoc billing proposal entry point - the same entry point
/// the write implementation uses - the resulting Billing Line proposal rows are read back and
/// reported, and then deleted again so the company is left exactly as it was found. A plain
/// Data.Records.Set cannot preview this because the proposal lines are produced by a codeunit,
/// not by a value the caller could compute itself.
/// </summary>
codeunit 10035039 "Sub Con PrvInvoice Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract no.||is-IS=Áskriftarsamningur viðskiptavinar ''%1'' er ekki til.';
        ForeignPendingErr: Label 'Contract ''%1'' has %2 pending billing line(s) with no billing template assigned. Clear or complete that proposal before previewing this contract, because the preview would also build proposal lines for those.', Comment = '%1 = foreign contract no., %2 = row count||is-IS=Samningur ''%1'' er með %2 ófrágengna(r) reikningslínu(r) án úthlutaðs reikningssniðmáts. Ljúktu við eða hreinsaðu þá tillögu áður en þessi samningur er forskoðaður, því annars myndi forskoðunin einnig búa til tillögulínur fyrir þær.';
        NothingNewMsg: Label 'Nothing new could be proposed for contract %1. Its due Subscription Lines are already covered by pending billing proposal lines - bill or clear those first.', Comment = '%1 = contract number||is-IS=Ekkert nýtt var hægt að leggja til fyrir samning %1. Áskriftarlínur hans eru þegar með reikningstillögulínur - ljúktu við þær eða hreinsaðu þær fyrst.';
        NothingDueMsg: Label 'No Subscription Lines were due for billing on or before %1 for contract %2.', Comment = '%1 = billing date, %2 = contract no.||is-IS=Engar áskriftarlínur voru gjaldfallnar til reikningsgerðar á eða fyrir %1 fyrir samning %2.';
        DescriptionLbl: Label 'Previews the billing proposal lines that Subscription.Contract.CreateInvoice would build for one customer Subscription Contract. Nothing is written and no invoice is ever created.', MaxLength = 250, Comment = 'is-IS=Forskoðar reikningstillögulínur sem Subscription.Contract.CreateInvoice myndi útbúa fyrir einn áskriftarsamning viðskiptavinar. Engu er skrifað og enginn reikningur er nokkurn tímann búinn til.';

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

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        ConHelp: Codeunit "Sub Con Help ori";
    begin
        Argument.SetResponseMarkdown(ConHelp.GetHelpMarkdown('Subscription.Contract.PreviewInvoice'));
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        BillingLine: Record "Billing Line";
        WriteProcess: Codeunit "Sub Write Process ori";
        ContractNo: Code[20];
        WatermarkEntryNo: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        ContractNo := Helper.GetSubjectOr(Argument, Argument.GetRequestJson(), 'contractNo', false);
        if BillingLine.FindLast() then
            WatermarkEntryNo := BillingLine."Entry No.";

        Clear(WriteProcess);
        if not WriteProcess.Run(Argument) then begin
            // The proposal commits internally, so a rolled-back failure can still leave rows
            // behind. Remove them here, outside the isolation, where the delete itself sticks.
            if ContractNo <> '' then
                DeleteProposalLinesAbove(WatermarkEntryNo, ContractNo);
            Argument.RespondWithLastError();
        end;
    end;

    /// <summary>Builds and reports the preview, then cleans up after itself. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        BillingDate: Date;
        BillingToDate: Date;
    begin
        ContractNo := Helper.GetSubjectOr(Argument, Argument.GetRequestJson(), 'contractNo', true);
        BillingDate := Helper.GetDateOrDefault(Argument.GetRequestJson(), 'billingDate', WorkDate());
        BillingToDate := Helper.GetDate(Argument.GetRequestJson(), 'billingToDate', false);

        PreviewContract(ContractNo, BillingDate, BillingToDate, ResponseJson);

        ResponseJson.Add('preview', true);
        ResponseJson.Add('rollback', true);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Builds the ad-hoc billing proposal for the contract's due Subscription Lines, reads back
    /// exactly the rows it produced, deletes them again, and fills ResponseJson with the outcome.
    /// The delete happens on every path once the proposal has been built, including when the
    /// proposal call itself fails partway through, because Microsoft's billing proposal codeunit
    /// commits internally and a transaction rollback alone would not remove what it already wrote.
    /// </summary>
    local procedure PreviewContract(ContractNo: Code[20]; BillingDate: Date; BillingToDate: Date; var ResponseJson: JsonObject)
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        TempSubscriptionLine: Record "Subscription Line" temporary;
        BillingLine: Record "Billing Line";
        BillingProposal: Codeunit "Billing Proposal";
        LinesArray: JsonArray;
        WatermarkEntryNo: Integer;
        WouldBillLineCount: Integer;
        TotalAmount: Decimal;
        ForeignCount: Integer;
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
            ResponseJson.Add('lines', LinesArray);
            ResponseJson.Add('wouldBillLineCount', 0);
            ResponseJson.Add('totalAmount', Helper.FormatDecimal(0));
            ResponseJson.Add('message', StrSubstNo(NothingDueMsg, Helper.FormatDate(BillingDate), ContractNo));
            exit;
        end;

        BillingLine.Reset();
        if BillingLine.FindLast() then
            WatermarkEntryNo := BillingLine."Entry No."
        else
            WatermarkEntryNo := 0;

        BillingProposal.CreateBillingProposalForPurchaseHeader(
            Enum::"Service Partner"::Customer, TempSubscriptionLine, BillingDate, BillingToDate);

        CollectAndDeleteProposalLines(WatermarkEntryNo, ContractNo, LinesArray, WouldBillLineCount, TotalAmount);

        if WouldBillLineCount = 0 then
            ResponseJson.Add('message', StrSubstNo(NothingNewMsg, ContractNo));

        ResponseJson.Add('lines', LinesArray);
        ResponseJson.Add('wouldBillLineCount', WouldBillLineCount);
        ResponseJson.Add('totalAmount', Helper.FormatDecimal(TotalAmount));
    end;

    /// <summary>Deletes any proposal lines the failed attempt above left behind, identified by the watermark taken before it ran.</summary>
    local procedure DeleteProposalLinesAbove(WatermarkEntryNo: Integer; ContractNo: Code[20])
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetFilter("Entry No.", '>%1', WatermarkEntryNo);
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        if not BillingLine.IsEmpty() then
            while BillingLine.FindLast() do
                BillingLine.Delete(true);
    end;

    /// <summary>Reads back the proposal lines created above the watermark, reports them, and deletes them again.</summary>
    local procedure CollectAndDeleteProposalLines(WatermarkEntryNo: Integer; ContractNo: Code[20]; var LinesArray: JsonArray; var WouldBillLineCount: Integer; var TotalAmount: Decimal)
    var
        BillingLine: Record "Billing Line";
        LineJson: JsonObject;
    begin
        BillingLine.SetFilter("Entry No.", '>%1', WatermarkEntryNo);
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        if BillingLine.FindSet() then
            repeat
                WouldBillLineCount += 1;
                TotalAmount += BillingLine.Amount;

                Clear(LineJson);
                LineJson.Add('subscriptionLineEntryNo', BillingLine."Subscription Line Entry No.");
                LineJson.Add('billingFrom', Helper.FormatDate(BillingLine."Billing from"));
                LineJson.Add('billingTo', Helper.FormatDate(BillingLine."Billing to"));
                LineJson.Add('unitPrice', Helper.FormatDecimal(BillingLine."Unit Price"));
                LineJson.Add('amount', Helper.FormatDecimal(BillingLine.Amount));
                LinesArray.Add(LineJson);
            until BillingLine.Next() = 0;

        // Business Central only allows a Subscription Line's LAST billing line to be removed,
        // so delete newest first rather than in one filtered sweep.
        while BillingLine.FindLast() do
            BillingLine.Delete(true);
    end;
}
