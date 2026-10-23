namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.VendorContract.AddLinesToInvoice</c> Bifrost message type (#41 AC01).
/// Adds a vendor's due vendor contract lines to an existing unposted purchase invoice, as the Get
/// Vendor Contract Lines action on the purchase invoice does. The page itself cannot run unattended,
/// so this codeunit selects the same Subscription Lines the page lists (vendor partner, invoiced through
/// a contract, open, no pending billing line, contract of the invoice's Buy-from Vendor No.) and calls
/// Microsoft's public "Billing Proposal".CreateBillingProposalForPurchaseHeader per line, with the
/// billing-to date the page proposes, followed by CreatePurchaseLines on the invoice.
/// </summary>
codeunit 10035068 "Sub Vend AddToInv Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        InvoiceNotFoundErr: Label 'The purchase invoice ''%1'' does not exist.', Comment = '%1 = purchase invoice number||is-IS=Innkaupareikningurinn ''%1'' er ekki til.';
        InvoicePostedErr: Label 'The purchase invoice ''%1'' is posted. Lines can only be added to an unposted purchase invoice.', Comment = '%1 = purchase invoice number||is-IS=Innkaupareikningurinn ''%1'' er bókaður. Aðeins er hægt að bæta línum við óbókaðan innkaupareikning.';
        LineNotFoundErr: Label 'Subscription Line %1 does not exist.', Comment = '%1 = subscription line entry number||is-IS=Áskriftarlína %1 er ekki til.';
        OtherVendorErr: Label 'Subscription Line %1 belongs to a vendor contract of another vendor than ''%2'', the Buy-from Vendor No. of the purchase invoice.', Comment = '%1 = subscription line entry number, %2 = vendor number||is-IS=Áskriftarlína %1 tilheyrir samningi annars lánardrottins en ''%2'', sem er lánardrottinn innkaupareikningsins.';
        NotBillableErr: Label 'Subscription Line %1 cannot be added: it must be a vendor line invoiced through a contract, open, and without a pending billing line.', Comment = '%1 = subscription line entry number||is-IS=Ekki er hægt að bæta áskriftarlínu %1 við: hún verður að vera lína lánardrottins sem er reikningsfærð í gegnum samning, opin og án óafgreiddrar reikningslínu.';
        ForeignPendingProposalErr: Label 'There are %1 pending billing proposal line(s) without a Billing Template for contract ''%2''. Microsoft would add them to this invoice too. Bill or clear that proposal first.', Comment = '%1 = row count, %2 = contract number||is-IS=Það eru %1 óafgreiddar línur í reikningstillögu án reikningssniðmáts fyrir samning ''%2''. Microsoft myndi bæta þeim við þennan reikning líka. Reikningsfærðu eða hreinsaðu þá tillögu fyrst.';
        DescriptionLbl: Label 'Adds the due vendor contract lines of the invoice''s vendor to an existing unposted purchase invoice, like Get Vendor Contract Lines, and returns the lines added.', MaxLength = 250, Comment = 'is-IS=Bætir gjaldföllnum samningslínum lánardrottins reikningsins við óbókaðan innkaupareikning, eins og Sækja samningslínur lánardrottins, og skilar línunum sem bættust við.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Purchase Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'add lines to purchase invoice, add vendor contract lines to invoice, add contract lines to existing invoice, add due lines to purchase invoice, extend purchase invoice with contract lines, add subscription lines to vendor invoice, append vendor lines, complete the purchase invoice', Comment = 'is-IS=bæta línum við innkaupareikning, bæta samningslínum lánardrottins við reikning, bæta samningslínum við fyrirliggjandi reikning, bæta gjaldföllnum línum við innkaupareikning, bæta samningslínum við innkaupareikning, bæta áskriftarlínum við reikning lánardrottins, bæta við línum lánardrottins, fullgera innkaupareikninginn';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Add vendor lines to a purchase invoice: adds the due lines of the invoice''s vendor to an existing unposted purchase invoice. Writes data; nothing is posted. To create a new purchase invoice for a contract use Subscription.VendorContract.CreateInvoice.', Comment = 'is-IS=Bæta línum lánardrottins við innkaupareikning: bætir gjaldföllnum línum lánardrottins reikningsins við fyrirliggjandi óbókaðan innkaupareikning. Skrifar gögn; ekkert er bókað. Til að stofna nýjan innkaupareikning fyrir samning skal nota Subscription.VendorContract.CreateInvoice.';
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
        Parameters := ContractParts.AddLinesToInvoiceParameters();
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
        Examples.Add(ContractMgt.Example('Add every due line of the vendor',
            '{"type":"Subscription.VendorContract.AddLinesToInvoice","subject":"108017","data":{}}',
            '{"status":"Success","purchaseInvoiceNo":"108017","vendorNo":"10000","linesAdded":2,"subscriptionLineEntryNos":[311,312]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Adds the vendor contract lines that are due to an existing unposted purchase invoice, as Get Vendor Contract Lines does on the invoice. Without ' +
            'subscriptionLineEntryNos every open Subscription Line of the invoice''s vendor that is invoiced through a vendor contract and has no pending billing ' +
            'line is added; contractNo narrows that to one vendor contract. Each line is billed up to the billing-to date the page proposes for its next billing ' +
            'period, or up to billingToDate.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Microsoft creates a billing line without a Billing Template for each Subscription Line and then turns every such line in the company into lines of ' +
            'this invoice, so the call is refused while another contract has template-less proposal lines that are not on a document. A listed line of another ' +
            'vendor, a line that is closed, not invoiced through a contract or already on a billing line, and a posted invoice are refused. Zero candidate lines is ' +
            'still a success. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.VendorContract.AddLinesToInvoice');
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

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Vend AddToInv Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Adds the selected vendor contract lines to the invoice. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SubscriptionLine: Record "Subscription Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AddedArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        CandidateEntryNos: List of [Integer];
        InvoiceNo: Code[20];
        ContractNo: Code[20];
        BillingToDate: Date;
        EntryNo: Integer;
        LinesBefore: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        InvoiceNo := Helper.GetSubjectOr(RequestJson, 'purchaseInvoiceNo', Argument, true);
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);
        BillingToDate := Helper.GetDate(RequestJson, 'billingToDate', false);
        Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);

        GetUnpostedInvoice(InvoiceNo, PurchaseHeader);

        if SelectedEntryNos.Count() > 0 then
            foreach EntryNo in SelectedEntryNos.Keys() do begin
                CheckListedLine(EntryNo, PurchaseHeader."Buy-from Vendor No.");
                CandidateEntryNos.Add(EntryNo);
            end
        else
            CollectCandidates(PurchaseHeader."Buy-from Vendor No.", ContractNo, CandidateEntryNos);

        CheckNoForeignPendingProposal();

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        LinesBefore := PurchaseLine.Count();

        if CandidateEntryNos.Count() > 0 then begin
            foreach EntryNo in CandidateEntryNos do begin
                SubscriptionLine.Get(EntryNo);
                ProposeLine(SubscriptionLine, BillingToDate);
                AddedArray.Add(EntryNo);
            end;
            CreatePurchaseLines(PurchaseHeader);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('purchaseInvoiceNo', PurchaseHeader."No.");
        ResponseJson.Add('vendorNo', PurchaseHeader."Buy-from Vendor No.");
        ResponseJson.Add('linesAdded', PurchaseLine.Count() - LinesBefore);
        ResponseJson.Add('subscriptionLineEntryNos', AddedArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure GetUnpostedInvoice(InvoiceNo: Code[20]; var PurchaseHeader: Record "Purchase Header")
    var
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, InvoiceNo) then
            exit;
        PurchInvHeader.SetRange("No.", InvoiceNo);
        if not PurchInvHeader.IsEmpty() then
            Error(InvoicePostedErr, InvoiceNo);
        PurchInvHeader.SetRange("No.");
        PurchInvHeader.SetRange("Pre-Assigned No.", InvoiceNo);
        if not PurchInvHeader.IsEmpty() then
            Error(InvoicePostedErr, InvoiceNo);
        Error(InvoiceNotFoundErr, InvoiceNo);
    end;

    /// <summary>The candidates of the Get Vendor Contract Lines page: LoadVendorServiceCommitments and LoadVendorServiceCommitmentIfRelevant.</summary>
    local procedure CollectCandidates(VendorNo: Code[20]; ContractNo: Code[20]; var CandidateEntryNos: List of [Integer])
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        if ContractNo <> '' then
            SubscriptionLine.SetRange("Subscription Contract No.", ContractNo)
        else
            SubscriptionLine.SetFilter("Subscription Contract No.", '<>%1', '');
        SubscriptionLine.SetRange(Closed, false);
        SubscriptionLine.SetLoadFields("Entry No.", Partner, "Invoicing via", "Subscription Contract No.", Closed);
        if SubscriptionLine.FindSet() then
            repeat
                if IsBillableLine(SubscriptionLine) and (GetContractVendorNo(SubscriptionLine."Subscription Contract No.") = VendorNo) then
                    CandidateEntryNos.Add(SubscriptionLine."Entry No.");
            until SubscriptionLine.Next() = 0;
    end;

    local procedure CheckListedLine(EntryNo: Integer; VendorNo: Code[20])
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        if not SubscriptionLine.Get(EntryNo) then
            Error(LineNotFoundErr, EntryNo);
        if (SubscriptionLine.Partner <> SubscriptionLine.Partner::Vendor) or (SubscriptionLine."Invoicing via" <> SubscriptionLine."Invoicing via"::Contract) or
           (SubscriptionLine."Subscription Contract No." = '') or SubscriptionLine.Closed or (not IsBillableLine(SubscriptionLine))
        then
            Error(NotBillableErr, EntryNo);
        if GetContractVendorNo(SubscriptionLine."Subscription Contract No.") <> VendorNo then
            Error(OtherVendorErr, EntryNo, VendorNo);
    end;

    local procedure IsBillableLine(SubscriptionLine: Record "Subscription Line"): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        exit(BillingLine.IsEmpty());
    end;

    local procedure GetContractVendorNo(ContractNo: Code[20]): Code[20]
    var
        VendorContract: Record "Vendor Subscription Contract";
    begin
        VendorContract.SetLoadFields("Buy-from Vendor No.");
        if VendorContract.Get(ContractNo) then
            exit(VendorContract."Buy-from Vendor No.");
        exit('');
    end;

    local procedure CheckNoForeignPendingProposal()
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Billing Template Code", '');
        BillingLine.SetRange("Document No.", '');
        BillingLine.SetLoadFields("Subscription Contract No.");
        if BillingLine.FindFirst() then
            Error(ForeignPendingProposalErr, BillingLine.Count(), BillingLine."Subscription Contract No.");
    end;

    /// <summary>
    /// Proposes one Subscription Line the way the page does: CreateBillingProposalForPurchaseHeader with the page's
    /// BillingToDate (CalculateNextBillingToDateForServiceCommitment of its Next Billing Date) as billing date and billing-to date.
    /// </summary>
    local procedure ProposeLine(SubscriptionLine: Record "Subscription Line"; BillingToDate: Date)
    var
        TempSubscriptionLine: Record "Subscription Line" temporary;
        BillingProposal: Codeunit "Billing Proposal";
    begin
        if BillingToDate = 0D then
            BillingToDate := BillingProposal.CalculateNextBillingToDateForServiceCommitment(SubscriptionLine, SubscriptionLine."Next Billing Date");
        TempSubscriptionLine := SubscriptionLine;
        TempSubscriptionLine.Insert(false);
        BillingProposal.CreateBillingProposalForPurchaseHeader(Enum::"Service Partner"::Vendor, TempSubscriptionLine, BillingToDate, BillingToDate);
    end;

    local procedure CreatePurchaseLines(PurchaseHeader: Record "Purchase Header")
    var
        BillingProposal: Codeunit "Billing Proposal";
    begin
        BillingProposal.CreatePurchaseLines(PurchaseHeader);
    end;
}
