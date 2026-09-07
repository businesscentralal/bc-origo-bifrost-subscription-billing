namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Billing.PreviewDocuments</c> Bifrost message type.
/// Shows what <c>Subscription.Billing.CreateDocuments</c> would produce for a Billing Template's
/// unbilled proposal lines by reading the existing Billing Line rows and reporting how they
/// would be grouped into documents. Unlike the invoice previews, this message type never writes
/// anything at all - it only reads the proposal lines the caller already created with
/// <c>Subscription.Billing.CreateProposal</c>, so there is nothing to build and nothing to
/// clean up afterwards.
/// </summary>
codeunit 10035047 "Sub Bil PrvDocs Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
        TemplateNotFoundErr: Label 'The Billing Template ''%1'' does not exist.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er ekki til.';
        InvalidGroupByErr: Label 'The parameter ''groupBy'' must be either ''Contract'' or ''Customer''.', Comment = 'is-IS=Færibreytan ''groupBy'' verður að vera annaðhvort ''Contract'' eða ''Customer''.';
        GroupByCustomerOnlyErr: Label '''groupBy'' = ''Customer'' only applies when the pending proposal lines belong to customer contracts.', Comment = 'is-IS=''groupBy'' = ''Customer'' á aðeins við þegar óloknar tillögufærslur tilheyra viðskiptavinasamningum.';
        NothingPendingMsg: Label 'There are no unbilled proposal lines for Billing Template ''%1''. Run Subscription.Billing.CreateProposal first.', Comment = '%1 = billing template code||is-IS=Það eru engar ófakturaðar tillögufærslur fyrir reikningssniðmátið ''%1''. Keyrðu Subscription.Billing.CreateProposal fyrst.';
        MixedPartnerMsg: Label 'Billing Template ''%1'' currently has both customer and vendor proposal lines pending. A real run refuses to create documents for a mix of partner types until this is resolved.', Comment = '%1 = billing template code||is-IS=Reikningssniðmátið ''%1'' er núna með bæði viðskiptavina- og birgjafærslur í bið. Raunveruleg keyrsla neitar að búa til skjöl fyrir blöndu af tegundum viðskiptaaðila þar til úr því er leyst.';
        UpdateRequiredMsg: Label '%1 of the pending proposal line(s) are flagged ''Update Required'' and would need to be refreshed before a real run could process them.', Comment = '%1 = row count||is-IS=%1 af óloknum tillögufærslum eru merktar ''Uppfærslu krafist'' og þyrfti að endurnýja áður en raunveruleg keyrsla gæti unnið úr þeim.';
        DescriptionLbl: Label 'Previews the documents that Subscription.Billing.CreateDocuments would create for a Billing Template, by reading the existing proposal lines. Reads only; writes nothing.', MaxLength = 250, Comment = 'is-IS=Forskoðar þau skjöl sem Subscription.Billing.CreateDocuments myndi búa til fyrir reikningssniðmát, með því að lesa fyrirliggjandi tillögulínur. Les eingöngu; skrifar ekkert.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Billing Template");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        BilHelp: Codeunit "Sub Bil Help ori";
    begin
        Argument.SetResponseMarkdown(BilHelp.GetHelpMarkdown('Subscription.Billing.PreviewDocuments'));
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteProcess: Codeunit "Sub Write Process ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        Clear(WriteProcess);
        if not WriteProcess.Run(Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Reads the pending proposal lines and reports how they would be grouped into documents. Never writes.</summary>
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        BillingTemplateCode: Code[20];
        GroupBy: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        BillingTemplateCode := Helper.GetSubjectOr(Argument, RequestJson, 'billingTemplateCode', true);
        GroupBy := Helper.GetText(RequestJson, 'groupBy', false);

        PreviewDocuments(BillingTemplateCode, GroupBy, ResponseJson);

        ResponseJson.Add('preview', true);
        ResponseJson.Add('rollback', true);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>Reads the Billing Template's unbilled proposal lines and fills ResponseJson with the grouping and warnings a real run would produce.</summary>
    local procedure PreviewDocuments(BillingTemplateCode: Code[20]; GroupBy: Text; var ResponseJson: JsonObject)
    var
        BillingTemplate: Record "Billing Template";
        BillingLine: Record "Billing Line";
        DocumentsArray: JsonArray;
        WarningsArray: JsonArray;
        BillingLineCount: Integer;
        CustomerLineCount: Integer;
        VendorLineCount: Integer;
        UpdateRequiredCount: Integer;
        GroupByCustomer: Boolean;
    begin
        if not BillingTemplate.Get(BillingTemplateCode) then
            Error(TemplateNotFoundErr, BillingTemplateCode);

        BillingLine.SetRange("Billing Template Code", BillingTemplateCode);
        BillingLine.SetRange("Document Type", Enum::"Rec. Billing Document Type"::None);
        BillingLineCount := BillingLine.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('billingTemplateCode', BillingTemplateCode);

        if BillingLineCount = 0 then begin
            ResponseJson.Add('message', StrSubstNo(NothingPendingMsg, BillingTemplateCode));
            ResponseJson.Add('billingLineCount', 0);
            ResponseJson.Add('documentCount', 0);
            ResponseJson.Add('documents', DocumentsArray);
            ResponseJson.Add('warnings', WarningsArray);
            exit;
        end;

        BillingLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        CustomerLineCount := BillingLine.Count();
        BillingLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        VendorLineCount := BillingLine.Count();
        BillingLine.SetRange(Partner);

        BillingLine.SetRange("Update Required", true);
        UpdateRequiredCount := BillingLine.Count();
        BillingLine.SetRange("Update Required");

        case UpperCase(GroupBy) of
            '', 'CONTRACT':
                GroupByCustomer := false;
            'CUSTOMER':
                begin
                    if VendorLineCount > 0 then
                        Error(GroupByCustomerOnlyErr);
                    GroupByCustomer := true;
                end;
            else
                Error(InvalidGroupByErr);
        end;

        BuildDocumentsPreview(BillingLine, GroupByCustomer, DocumentsArray);
        BuildWarnings(BillingTemplateCode, CustomerLineCount, VendorLineCount, UpdateRequiredCount, WarningsArray);

        ResponseJson.Add('billingLineCount', BillingLineCount);
        ResponseJson.Add('documentCount', DocumentsArray.Count());
        ResponseJson.Add('documents', DocumentsArray);
        ResponseJson.Add('warnings', WarningsArray);
    end;

    /// <summary>
    /// Groups the filtered Billing Line rows the way a real run would - per Subscription Contract
    /// No. by default, or per Partner No. when GroupByCustomer is set - and emits one document
    /// entry per group. contractNo is left blank on a per-customer entry because that grouping can
    /// span several contracts under the same Partner No.
    /// </summary>
    local procedure BuildDocumentsPreview(var BillingLine: Record "Billing Line"; GroupByCustomer: Boolean; var DocumentsArray: JsonArray)
    var
        DocumentJson: JsonObject;
        // The keys are kept in their own list as well, because the preview reports the groups in the
        // order the rows first named them and a dictionary makes no promise about the order it
        // hands its keys back in.
        GroupKeys: List of [Code[20]];
        GroupLineCounts: Dictionary of [Code[20], Integer];
        GroupTotals: Dictionary of [Code[20], Decimal];
        GroupPartnerNos: Dictionary of [Code[20], Code[20]];
        GroupKey: Code[20];
        ContractNo: Code[20];
    begin
        // One pass over the rows, accumulating per group as they arrive. Reading the table once per
        // group instead - a Count and a FindSet each - re-reads the same proposal N+1 times over.
        BillingLine.SetLoadFields("Partner No.", "Subscription Contract No.", Amount);
        if BillingLine.FindSet() then
            repeat
                if GroupByCustomer then
                    GroupKey := BillingLine."Partner No."
                else
                    GroupKey := BillingLine."Subscription Contract No.";

                if not GroupLineCounts.ContainsKey(GroupKey) then begin
                    GroupKeys.Add(GroupKey);
                    GroupLineCounts.Add(GroupKey, 0);
                    GroupTotals.Add(GroupKey, 0);
                    GroupPartnerNos.Add(GroupKey, '');
                end;

                GroupLineCounts.Set(GroupKey, GroupLineCounts.Get(GroupKey) + 1);
                GroupTotals.Set(GroupKey, GroupTotals.Get(GroupKey) + BillingLine.Amount);
                if GroupPartnerNos.Get(GroupKey) = '' then
                    GroupPartnerNos.Set(GroupKey, BillingLine."Partner No.");
            until BillingLine.Next() = 0;

        foreach GroupKey in GroupKeys do begin
            if GroupByCustomer then
                ContractNo := ''
            else
                ContractNo := GroupKey;

            Clear(DocumentJson);
            DocumentJson.Add('contractNo', ContractNo);
            DocumentJson.Add('partnerNo', GroupPartnerNos.Get(GroupKey));
            DocumentJson.Add('lineCount', GroupLineCounts.Get(GroupKey));
            DocumentJson.Add('totalAmount', Helper.FormatDecimal(GroupTotals.Get(GroupKey)));
            DocumentsArray.Add(DocumentJson);
        end;
    end;

    /// <summary>Reports the conditions that would block or complicate a real Subscription.Billing.CreateDocuments run.</summary>
    local procedure BuildWarnings(BillingTemplateCode: Code[20]; CustomerLineCount: Integer; VendorLineCount: Integer; UpdateRequiredCount: Integer; var WarningsArray: JsonArray)
    var
        WarningJson: JsonObject;
    begin
        if (CustomerLineCount > 0) and (VendorLineCount > 0) then begin
            Clear(WarningJson);
            WarningJson.Add('code', 'MixedPartners');
            WarningJson.Add('message', StrSubstNo(MixedPartnerMsg, BillingTemplateCode));
            WarningJson.Add('customerLineCount', CustomerLineCount);
            WarningJson.Add('vendorLineCount', VendorLineCount);
            WarningsArray.Add(WarningJson);
        end;

        if UpdateRequiredCount > 0 then begin
            Clear(WarningJson);
            WarningJson.Add('code', 'UpdateRequired');
            WarningJson.Add('message', StrSubstNo(UpdateRequiredMsg, UpdateRequiredCount));
            WarningJson.Add('lineCount', UpdateRequiredCount);
            WarningsArray.Add(WarningJson);
        end;
    end;
}
