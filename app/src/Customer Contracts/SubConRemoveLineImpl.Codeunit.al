namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Contract.RemoveLine</c> Bifrost message type (#41 AC05).
/// Deletes one customer or vendor contract line with Delete(true), so Microsoft's delete trigger
/// detaches its Subscription Line from the contract (it can be attached again with GetLines) and
/// recalculates the contract's harmonized billing fields. A line that has been billed, is on a pending
/// billing line, has unreleased deferrals or is closed is refused up front with a named error: the
/// closed case would otherwise ask a question no unattended caller can answer.
/// </summary>
codeunit 10035071 "Sub Con RemoveLine Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        CustomerLineNotFoundErr: Label 'Line %1 of Customer Subscription Contract ''%2'' does not exist.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í áskriftarsamningi viðskiptamanns ''%2'' er ekki til.';
        VendorLineNotFoundErr: Label 'Line %1 of Vendor Subscription Contract ''%2'' does not exist.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í áskriftarsamningi lánardrottins ''%2'' er ekki til.';
        ClosedLineErr: Label 'Line %1 of contract ''%2'' is closed. A closed contract line keeps the history of an ended Subscription Line and is not removed by this message type.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í samningi ''%2'' er lokuð. Lokuð samningslína geymir sögu áskriftarlínu sem er lokið og þessi skeytagerð fjarlægir hana ekki.';
        PendingBillingErr: Label 'Line %1 of contract ''%2'' is on a billing line. Clear the billing proposal or delete the billing document first.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í samningi ''%2'' er á reikningslínu. Hreinsaðu reikningstillöguna eða eyddu reikningsskjalinu fyrst.';
        BilledErr: Label 'Line %1 of contract ''%2'' has already been billed, so it is part of the contract''s invoicing history and is not removed.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í samningi ''%2'' hefur þegar verið reikningsfærð, svo hún er hluti af reikningasögu samningsins og er ekki fjarlægð.';
        DeferralErr: Label 'Line %1 of contract ''%2'' has unreleased deferrals. Release them first, for example with Subscription.Deferral.Release.', Comment = '%1 = line number, %2 = contract number||is-IS=Lína %1 í samningi ''%2'' hefur óútleystar frestanir. Leystu þær fyrst út, til dæmis með Subscription.Deferral.Release.';
        DescriptionLbl: Label 'Removes a line from a customer or vendor Subscription Contract and detaches its Subscription Line. Refuses lines that are billed, in billing, deferred or closed.', MaxLength = 250, Comment = 'is-IS=Fjarlægir línu úr áskriftarsamningi viðskiptamanns eða lánardrottins og losar áskriftarlínu hennar. Hafnar línum sem eru reikningsfærðar, í reikningagerð, frestaðar eða lokaðar.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Cust. Sub. Contract Line");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'remove contract line, delete contract line, detach subscription line from contract, remove line from customer contract, remove line from vendor contract, delete line of contract, unattach subscription line, take line off contract', Comment = 'is-IS=fjarlægja samningslínu, eyða samningslínu, aftengja áskriftarlínu frá samningi, fjarlægja línu af samningi viðskiptamanns, fjarlægja línu af samningi lánardrottins, eyða línu samnings, losa áskriftarlínu, taka línu af samningi';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Remove a contract line: deletes an unbilled line of a customer or vendor contract and detaches its Subscription Line, which is not deleted. Writes data; billed, closed, deferred and in-billing lines are refused. Attach the Subscription Line again with Subscription.Contract.GetLines or Subscription.VendorContract.GetLines.', Comment = 'is-IS=Fjarlægja samningslínu: eyðir línu sem ekki hefur verið reikningsfærð á samningi viðskiptamanns eða lánardrottins og losar áskriftarlínu hennar, sem er ekki eytt. Skrifar gögn; línum sem eru reikningsfærðar, lokaðar, frestaðar eða í reikningagerð er hafnað. Áskriftarlínan er tengd aftur með Subscription.Contract.GetLines eða Subscription.VendorContract.GetLines.';
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
        Parameters := ContractParts.RemoveLineParameters();
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
        Examples.Add(ContractMgt.Example('Remove a customer contract line',
            '{"type":"Subscription.Contract.RemoveLine","subject":"CC000010","data":{"lineNo":20000}}',
            '{"status":"Success","contractNo":"CC000010","partner":"Customer","lineNo":20000,"subscriptionLineEntryNo":311}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes one contract line from a customer (partner Customer, the default) or vendor Subscription Contract. Microsoft''s delete trigger detaches the ' +
            'Subscription Line from the contract, so it is unassigned again and Subscription.Contract.GetLines or Subscription.VendorContract.GetLines can attach ' +
            'it to this or another contract. The Subscription Line itself is not deleted.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Refused, before anything changes: a line that is closed, a line on a billing proposal line or unposted document, a line that has been billed (it has ' +
            'archived billing lines) and a line with unreleased deferrals. A comment line can be removed. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.RemoveLine');
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

        if not Codeunit.Run(Codeunit::"Sub Con RemoveLine Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes the contract line. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Partner: Enum "Service Partner";
        ContractNo: Code[20];
        LineNo: Integer;
        SubscriptionLineEntryNo: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(RequestJson, 'contractNo', Argument, true);
        LineNo := Helper.GetInteger(RequestJson, 'lineNo', true);
        Partner := Helper.GetServicePartner(RequestJson, 'partner', Enum::"Service Partner"::Customer);

        if Partner = Partner::Vendor then begin
            if not VendSubContractLine.Get(ContractNo, LineNo) then
                Error(VendorLineNotFoundErr, LineNo, ContractNo);
            CheckRemovable(Partner, ContractNo, LineNo, VendSubContractLine.Closed);
            SubscriptionLineEntryNo := VendSubContractLine."Subscription Line Entry No.";
            VendSubContractLine.Delete(true);
        end else begin
            if not CustSubContractLine.Get(ContractNo, LineNo) then
                Error(CustomerLineNotFoundErr, LineNo, ContractNo);
            CheckRemovable(Partner, ContractNo, LineNo, CustSubContractLine.Closed);
            SubscriptionLineEntryNo := CustSubContractLine."Subscription Line Entry No.";
            CustSubContractLine.Delete(true);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        if Partner = Partner::Vendor then
            ResponseJson.Add('partner', 'Vendor')
        else
            ResponseJson.Add('partner', 'Customer');
        ResponseJson.Add('lineNo', LineNo);
        ResponseJson.Add('subscriptionLineEntryNo', SubscriptionLineEntryNo);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure CheckRemovable(Partner: Enum "Service Partner"; ContractNo: Code[20]; LineNo: Integer; IsClosed: Boolean)
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
        CustSubContractDeferral: Record "Cust. Sub. Contract Deferral";
        VendSubContractDeferral: Record "Vend. Sub. Contract Deferral";
    begin
        if IsClosed then
            Error(ClosedLineErr, LineNo, ContractNo);

        BillingLine.SetRange(Partner, Partner);
        BillingLine.SetRange("Subscription Contract No.", ContractNo);
        BillingLine.SetRange("Subscription Contract Line No.", LineNo);
        if not BillingLine.IsEmpty() then
            Error(PendingBillingErr, LineNo, ContractNo);

        BillingLineArchive.SetRange(Partner, Partner);
        BillingLineArchive.SetRange("Subscription Contract No.", ContractNo);
        BillingLineArchive.SetRange("Subscription Contract Line No.", LineNo);
        if not BillingLineArchive.IsEmpty() then
            Error(BilledErr, LineNo, ContractNo);

        if Partner = Partner::Vendor then begin
            VendSubContractDeferral.SetRange("Subscription Contract No.", ContractNo);
            VendSubContractDeferral.SetRange("Subscription Contract Line No.", LineNo);
            VendSubContractDeferral.SetRange(Released, false);
            if not VendSubContractDeferral.IsEmpty() then
                Error(DeferralErr, LineNo, ContractNo);
        end else begin
            CustSubContractDeferral.SetRange("Subscription Contract No.", ContractNo);
            CustSubContractDeferral.SetRange("Subscription Contract Line No.", LineNo);
            CustSubContractDeferral.SetRange(Released, false);
            if not CustSubContractDeferral.IsEmpty() then
                Error(DeferralErr, LineNo, ContractNo);
        end;
    end;
}
