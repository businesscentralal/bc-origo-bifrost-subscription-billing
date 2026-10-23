namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.VendorContract.GetLines</c> Bifrost message type.
/// Attaches unassigned Subscription Lines (Partner = Vendor, invoiced via Contract, not yet
/// linked to a Vendor Subscription Contract) to one vendor subscription contract.
/// A plain Data.Records.Set cannot do this because attaching a line also has to create its
/// matching Vend. Sub. Contract Line and keep both records consistent - that pairing is done
/// by Microsoft's own table procedure, not by writing fields directly.
/// </summary>
codeunit 10035042 "Sub Vend GetLines Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur lánardrottins ''%1'' er ekki til.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a vendor subscription contract, creating a Vend. Sub. Contract Line for each one. Returns how many lines were attached.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við áskriftarsamning lánardrottins og býr til samningslínu lánardrottins fyrir hverja línu. Skilar fjölda tengdra lína.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Vendor Subscription Contract");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'attach lines to vendor contract, add subscription lines to vendor contract, get vendor contract lines, assign subscription lines to vendor contract, link lines to vendor contract, unassigned vendor lines, attach eligible vendor lines, add lines to vendor contract', Comment = 'is-IS=tengja línur við samning lánardrottins, bæta áskriftarlínum við samning lánardrottins, sækja samningslínur lánardrottins, úthluta áskriftarlínum á samning lánardrottins, festa línur við samning lánardrottins, ótengdar línur lánardrottins, tengja hæfar línur lánardrottins, bæta línum við samning lánardrottins';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Attach lines to a vendor contract: creates a contract line for each unassigned Subscription Line and attaches it to the Vendor Subscription Contract. Writes data; nothing is billed. For customer contracts use Subscription.Contract.GetLines; bill afterwards with Subscription.VendorContract.CreateInvoice.', Comment = 'is-IS=Tengja línur við samning lánardrottins: stofnar samningslínu fyrir hverja ótengda áskriftarlínu og tengir hana við áskriftarsamning lánardrottins. Skrifar gögn; ekkert er reikningsfært. Fyrir samninga viðskiptamanna skal nota Subscription.Contract.GetLines; á eftir er reikningsfært með Subscription.VendorContract.CreateInvoice.';
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
        Parameters := ContractParts.GetLinesParameters('Vendor Subscription Contract');
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
        Examples.Add(ContractMgt.Example('Attach two named lines',
            '{"type":"Subscription.VendorContract.GetLines","subject":"VC000010","data":{"subscriptionLineEntryNos":[101,102]}}',
            '{"status":"Success","contractNo":"VC000010","linesAttached":2,"attachedLines":[{"subscriptionLineEntryNo":101,"contractLineNo":10000},{"subscriptionLineEntryNo":102,"contractLineNo":20000}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Attaches Subscription Lines that are on no contract yet to a Vendor Subscription Contract, creating a Vend. Sub. Contract Line for each. Microsoft ' +
            'attaches one line at a time, so the call attaches the candidate lines one by one.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('A candidate line is invoiced via contract, belongs to the vendor partner, is on no contract, and has no end date or one after the work date. Unlike ' +
            'Subscription.Contract.GetLines, no candidate is skipped, and the answer has no linesSkipped. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.VendorContract.GetLines');
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

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Vend GetLines Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Attaches the eligible Subscription Lines. Called directly, or by OnRun when ExecuteBifrostTask runs this codeunit in its own transaction.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        VendorSubscriptionContract: Record "Vendor Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AttachedLinesArray: JsonArray;
        AttachedLineJson: JsonObject;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        EntryNoFilter: Text;
        ContractNo: Code[20];
        SubscriptionHeaderNo: Code[20];
        LinesAttached: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(RequestJson, 'contractNo', Argument, true);
        SubscriptionHeaderNo := Helper.GetCode20(RequestJson, 'subscriptionHeaderNo', false);

        if not VendorSubscriptionContract.Get(ContractNo) then
            Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ContractNotFoundErr, ContractNo), 'contractNo', Format(ContractNo, 0, 9));

        EntryNoFilter := Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);

        SubscriptionLine.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        SubscriptionLine.SetRange("Subscription Contract No.", '');
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.SetFilter("Subscription Line End Date", '>%1|%2', WorkDate(), 0D);
        if SubscriptionHeaderNo <> '' then
            SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        // Let the database drop the rows the caller did not ask for, instead of reading every
        // unassigned line and sorting them out here one by one.
        if EntryNoFilter <> '' then
            SubscriptionLine.SetFilter("Entry No.", EntryNoFilter);

        if SubscriptionLine.FindSet() then
            repeat
                // The filter already holds the caller's selection whenever it fits in one
                // expression. The test repeats it for the case where it did not.
                if (SelectedEntryNos.Count() = 0) or SelectedEntryNos.ContainsKey(SubscriptionLine."Entry No.") then begin
                    Clear(VendSubContractLine);
                    VendorSubscriptionContract.CreateVendorContractLineFromServiceCommitment(SubscriptionLine, ContractNo, VendSubContractLine);
                    LinesAttached += 1;

                    Clear(AttachedLineJson);
                    AttachedLineJson.Add('subscriptionLineEntryNo', SubscriptionLine."Entry No.");
                    AttachedLineJson.Add('contractLineNo', VendSubContractLine."Line No.");
                    AttachedLinesArray.Add(AttachedLineJson);
                end;
            until SubscriptionLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('linesAttached', LinesAttached);
        ResponseJson.Add('attachedLines', AttachedLinesArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
