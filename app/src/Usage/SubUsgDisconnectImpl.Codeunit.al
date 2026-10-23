namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Usage.DisconnectSubscription</c> Bifrost message type (#38).
/// Removes the link between a Subscription Line and a usage data supplier's subscription, as the
/// Disconnect from Subscription action does. Microsoft's public
/// "Usage Based Billing Mgmt.".DisconnectServiceCommitmentFromSubscription asks for confirmation
/// through Confirm Management.GetResponse, which answers No in a session without a user interface, so
/// called from an API it silently changes nothing. Its two steps are therefore rebuilt here from
/// Microsoft's source (see docs/microsoft-dependencies.md): the Supplier Reference Entry No. of the
/// Subscription's lines is cleared, and the supplier subscription's Subscription No. and Subscription
/// Line Entry No. are validated empty.
/// 
/// Portions copyright (c) Microsoft Corporation, licensed under the MIT License (BCApps releases/28.x
/// a674a13, src/Apps/W1/Subscription Billing/App/Usage Based Billing/Codeunits/UsageBasedBillingMgmt.Codeunit.al
/// and Usage Based Billing/Tables/UsageDataSuppSubscription.Table.al).
/// </summary>
codeunit 10035067 "Sub Usg Disconnect Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        MissingSelectionErr: Label 'The request must supply ''subscriptionLineEntryNo'' or ''usageDataSubscriptionEntryNo''.', Comment = 'is-IS=Beiðnin verður að innihalda ''subscriptionLineEntryNo'' eða ''usageDataSubscriptionEntryNo''.';
        LineNotFoundErr: Label 'Subscription Line %1 does not exist.', Comment = '%1 = subscription line entry number||is-IS=Áskriftarlína %1 er ekki til.';
        EntryNotFoundErr: Label 'Usage Data Supp. Subscription entry %1 does not exist.', Comment = '%1 = entry number||is-IS=Færsla %1 í áskriftum birgis notkunargagna er ekki til.';
        EntryNotConnectedErr: Label 'Usage Data Supp. Subscription entry %1 is not connected to a Subscription Line.', Comment = '%1 = entry number||is-IS=Færsla %1 í áskriftum birgis notkunargagna er ekki tengd áskriftarlínu.';
        LineNotConnectedErr: Label 'Subscription Line %1 is not connected to a usage data supplier''s subscription.', Comment = '%1 = subscription line entry number||is-IS=Áskriftarlína %1 er ekki tengd áskrift birgis notkunargagna.';
        DescriptionLbl: Label 'Disconnects a Subscription Line from its usage data supplier''s subscription, like Disconnect from Subscription, and returns the link that was removed.', MaxLength = 250, Comment = 'is-IS=Aftengir áskriftarlínu frá áskrift birgis notkunargagna, eins og Aftengjast áskrift, og skilar tengingunni sem var fjarlægð.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Line");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'disconnect usage subscription, unlink supplier subscription, remove supplier link, disconnect from subscription, break link between subscription line and supplier, disconnect subscription line, remove usage connection, unlink usage based line', Comment = 'is-IS=aftengja notkunaráskrift, aftengja áskrift birgis, fjarlægja tengingu við birgi, aftengjast áskrift, rjúfa tengingu áskriftarlínu og birgis, aftengja áskriftarlínu, fjarlægja notkunartengingu, aftengja notkunartengda línu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Disconnect a supplier subscription: clears the link between a Subscription Line and a usage data supplier''s subscription. Writes data; no line, contract or usage data is deleted. To link again use Subscription.Usage.ConnectSubscriptions.', Comment = 'is-IS=Aftengja áskrift birgis: hreinsar tenginguna milli áskriftarlínu og áskriftar birgis notkunargagna. Skrifar gögn; engri línu, samningi eða notkunargögnum er eytt. Til að tengja aftur skal nota Subscription.Usage.ConnectSubscriptions.';
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
        Parameters := ContractParts.DisconnectSubscriptionParameters();
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
        Examples.Add(ContractMgt.Example('Disconnect a Subscription Line',
            '{"type":"Subscription.Usage.DisconnectSubscription","data":{"subscriptionLineEntryNo":311}}',
            '{"status":"Success","subscriptionLineEntryNo":311,"subscriptionHeaderNo":"SUB000042","usageDataSubscriptionEntryNo":17,"supplierReferenceEntryNo":5,"linesDisconnected":1}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Disconnects a Subscription Line from the usage data supplier''s subscription it is linked to, named by the Subscription Line or by the supplier ' +
            'subscription entry. The Subscription''s lines lose their Supplier Reference Entry No. and the supplier subscription loses its Subscription No. and ' +
            'Subscription Line Entry No., so it can be connected again with Subscription.Usage.ConnectSubscriptions.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Microsoft''s own disconnect asks for confirmation and answers No when no user interface is present, so this type performs its two steps ' +
            'itself, unchanged. Every line of the same Subscription with the same Supplier Reference Entry No. is disconnected, as in the client; linesDisconnected ' +
            'counts them. Lines created by a New Subscription Lines connect are not removed, and the lines it ended are not reopened. When both parameters are ' +
            'sent, subscriptionLineEntryNo is used. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Usage.DisconnectSubscription');
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

        if not Codeunit.Run(Codeunit::"Sub Usg Disconnect Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Removes the selected link. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        SubscriptionLine: Record "Subscription Line";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        LineEntryNo: Integer;
        SubscriptionEntryNo: Integer;
        SupplierReferenceEntryNo: Integer;
        LinesDisconnected: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        LineEntryNo := Helper.GetInteger(RequestJson, 'subscriptionLineEntryNo', false);
        SubscriptionEntryNo := Helper.GetInteger(RequestJson, 'usageDataSubscriptionEntryNo', false);
        if (LineEntryNo = 0) and (SubscriptionEntryNo = 0) then
            Error(MissingSelectionErr);

        if LineEntryNo = 0 then begin
            if not UsageDataSubscription.Get(SubscriptionEntryNo) then
                Error(EntryNotFoundErr, SubscriptionEntryNo);
            if UsageDataSubscription."Subscription Line Entry No." = 0 then
                Error(EntryNotConnectedErr, SubscriptionEntryNo);
            LineEntryNo := UsageDataSubscription."Subscription Line Entry No.";
        end;
        if not SubscriptionLine.Get(LineEntryNo) then
            Error(LineNotFoundErr, LineEntryNo);
        if SubscriptionLine."Supplier Reference Entry No." = 0 then
            Error(LineNotConnectedErr, LineEntryNo);
        SupplierReferenceEntryNo := SubscriptionLine."Supplier Reference Entry No.";

        // Microsoft: "Usage Based Billing Mgmt.".DisconnectServiceCommitmentFromSubscription finds the first supplier
        // subscription with the line's Supplier Reference Entry No. and does nothing when there is none.
        UsageDataSubscription.Reset();
        UsageDataSubscription.SetRange("Supplier Reference Entry No.", SupplierReferenceEntryNo);
        if not UsageDataSubscription.FindFirst() then
            Error(LineNotConnectedErr, LineEntryNo);
        SubscriptionEntryNo := UsageDataSubscription."Entry No.";

        LinesDisconnected := ResetSupplierReferenceEntryNo(SubscriptionLine."Subscription Header No.", SupplierReferenceEntryNo);
        ResetServiceObjectAndServiceCommitment(UsageDataSubscription);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('subscriptionLineEntryNo', LineEntryNo);
        ResponseJson.Add('subscriptionHeaderNo', SubscriptionLine."Subscription Header No.");
        ResponseJson.Add('usageDataSubscriptionEntryNo', SubscriptionEntryNo);
        ResponseJson.Add('supplierReferenceEntryNo', SupplierReferenceEntryNo);
        ResponseJson.Add('linesDisconnected', LinesDisconnected);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Copy of Microsoft's local "Usage Based Billing Mgmt".ResetSupplierReferenceEntryNoForServiceObject: clears the Supplier
    /// Reference Entry No. of every line of the Subscription that carries it. Returns how many lines it cleared.
    /// </summary>
    local procedure ResetSupplierReferenceEntryNo(SubscriptionHeaderNo: Code[20]; SupplierReferenceEntryNo: Integer) LinesCleared: Integer
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        SubscriptionLine.SetRange("Supplier Reference Entry No.", SupplierReferenceEntryNo);
        LinesCleared := SubscriptionLine.Count();
        SubscriptionLine.ModifyAll("Supplier Reference Entry No.", 0, false);
    end;

    /// <summary>Copy of Microsoft's internal "Usage Data Supp. Subscription".ResetServiceObjectAndServiceCommitment.</summary>
    local procedure ResetServiceObjectAndServiceCommitment(var UsageDataSubscription: Record "Usage Data Supp. Subscription")
    begin
        if UsageDataSubscription."Entry No." = 0 then
            exit;
        UsageDataSubscription.Validate("Subscription Header No.", '');
        UsageDataSubscription.Validate("Subscription Line Entry No.", 0);
        UsageDataSubscription.Modify(true);
    end;
}
