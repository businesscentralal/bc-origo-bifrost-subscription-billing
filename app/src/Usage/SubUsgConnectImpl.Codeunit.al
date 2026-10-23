namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Usage.ConnectSubscriptions</c> Bifrost message type (#38).
/// Connects a usage data supplier's subscriptions (Usage Data Supp. Subscription) to Subscriptions
/// through Microsoft's public "Usage Based Billing Mgmt.".ConnectSubscriptionsToServiceObjects, the
/// action behind Connect to Subscription on the Usage Data Supp. Subscriptions page. The caller first
/// sets Connect to Sub. Header No. (and, for new Subscription Lines, the date) on each entry, for
/// example with Data.Records.Set. Each entry is connected in its own call, so Microsoft's question
/// about several entries for one Subscription, which cannot be answered unattended, never comes up:
/// two selected entries for one Subscription are refused before anything runs instead.
/// </summary>
codeunit 10035066 "Sub Usg Connect Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        SupplierNotFoundErr: Label 'The Usage Data Supplier ''%1'' does not exist.', Comment = '%1 = supplier number||is-IS=Birgir notkunargagna ''%1'' er ekki til.';
        EntryNotFoundErr: Label 'Usage Data Supp. Subscription entry %1 does not exist for supplier ''%2''.', Comment = '%1 = entry number, %2 = supplier number||is-IS=Færsla %1 í áskriftum birgis notkunargagna er ekki til fyrir birgi ''%2''.';
        NoConnectMethodErr: Label 'Usage Data Supp. Subscription entry %1 has no Connect to Subscription Method. Set Connect to Sub. Header No. on the entry first, for example with Data.Records.Set.', Comment = '%1 = entry number||is-IS=Færsla %1 í áskriftum birgis notkunargagna hefur engan tengimáta við áskrift. Settu fyrst Tengjast áskriftarnr. á færsluna, til dæmis með Data.Records.Set.';
        AlreadyConnectedErr: Label 'Usage Data Supp. Subscription entry %1 is already connected to Subscription Line %2. Disconnect it first with Subscription.Usage.DisconnectSubscription.', Comment = '%1 = entry number, %2 = subscription line entry number||is-IS=Færsla %1 í áskriftum birgis notkunargagna er þegar tengd áskriftarlínu %2. Aftengdu hana fyrst með Subscription.Usage.DisconnectSubscription.';
        SameSubscriptionErr: Label 'Usage Data Supp. Subscription entries %1 and %2 both connect to Subscription ''%3''. Connect them in separate calls after checking that this is intended.', Comment = '%1 = first entry number, %2 = second entry number, %3 = subscription number||is-IS=Færslur %1 og %2 í áskriftum birgis notkunargagna tengjast báðar áskriftinni ''%3''. Tengdu þær í aðskildum köllum eftir að hafa gengið úr skugga um að það sé ætlunin.';
        DescriptionLbl: Label 'Connects a usage data supplier''s subscriptions to Subscriptions through Microsoft''s Connect to Subscription, and returns which entries were connected and which were skipped, with the reason.', MaxLength = 250, Comment = 'is-IS=Tengir áskriftir birgis notkunargagna við áskriftir með aðgerð Microsoft, Tengjast áskrift, og skilar hvaða færslur tengdust og hverjum var sleppt, ásamt ástæðu.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Usage Data Supp. Subscription");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'connect usage subscriptions, connect supplier subscription to subscription, link supplier subscriptions, connect usage data supplier subscription, connect to subscription, link supplier subscription to subscription line, connect new supplier subscriptions, match supplier subscriptions', Comment = 'is-IS=tengja notkunaráskriftir, tengja áskrift birgis við áskrift, tengja áskriftir birgis, tengja áskrift birgis notkunargagna, tengjast áskrift, tengja áskrift birgis við áskriftarlínu, tengja nýjar áskriftir birgis, para saman áskriftir birgis';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Connect supplier subscriptions: links a usage data supplier''s subscriptions to Subscriptions, and with New Subscription Lines it also ends the old lines. Irreversible, because Subscription.Usage.DisconnectSubscription removes the link but not the new lines. Run it before Subscription.Usage.Process for new supplier subscriptions.', Comment = 'is-IS=Tengja áskriftir birgis: tengir áskriftir birgis notkunargagna við áskriftir og með nýjum áskriftarlínum lýkur það einnig gömlu línunum. Óafturkræf aðgerð, því Subscription.Usage.DisconnectSubscription fjarlægir tenginguna en ekki nýju línurnar. Keyrðu hana á undan Subscription.Usage.Process fyrir nýjar áskriftir birgis.';
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
        Parameters := ContractParts.ConnectSubscriptionsParameters();
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
        Examples.Add(ContractMgt.Example('Connect one supplier subscription',
            '{"type":"Subscription.Usage.ConnectSubscriptions","subject":"GENERIC","data":{"entryNos":[17]}}',
            '{"status":"Success","supplierNo":"GENERIC","connected":1,"skipped":0,"entries":[{"entryNo":17,"connected":true,"subscriptionHeaderNo":"SUB000042","subscriptionLineEntryNo":311,"reason":""}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Connects the supplier subscriptions of a Usage Data Supplier to Subscriptions, the step Subscription.Usage.Process needs before it can bill a new ' +
            'usage subscription. Every entry of the supplier that has a Connect to Subscription Method and is not connected yet is connected, or only the entries ' +
            'listed in entryNos. With the method Existing Subscription Lines the usage based lines of the Subscription are linked; with New Subscription Lines the ' +
            'current lines end the day before the connect date and new usage based lines are added to the contracts.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Set Connect to Sub. Header No. on each entry first, for example with Data.Records.Set; that sets the method and, for new lines, the date. An entry ' +
            'Microsoft cannot connect, for example because the Subscription has no usage based line or its item is blocked, is not an error: it is counted under ' +
            'skipped with Microsoft''s reason, and its Processing Status is Error. A listed entry that does not exist, has no method or is already connected is ' +
            'refused, and so are two selected entries for the same Subscription. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Usage.ConnectSubscriptions');
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

        if not Codeunit.Run(Codeunit::"Sub Usg Connect Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Connects the selected supplier subscriptions. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        UsageBasedBillingMgmt: Codeunit "Usage Based Billing Mgmt.";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EntriesArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        CandidateEntryNos: List of [Integer];
        SupplierNo: Code[20];
        EntryNo: Integer;
        ConnectedCount: Integer;
        SkippedCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        SupplierNo := Helper.GetSubjectOr(RequestJson, 'supplierNo', Argument, true);
        Helper.GetEntryNoSelection(RequestJson, 'entryNos', SelectedEntryNos);

        if not UsageDataSupplier.Get(SupplierNo) then
            Error(SupplierNotFoundErr, SupplierNo);

        if SelectedEntryNos.Count() > 0 then
            foreach EntryNo in SelectedEntryNos.Keys() do begin
                CheckSelectedEntry(SupplierNo, EntryNo);
                CandidateEntryNos.Add(EntryNo);
            end
        else begin
            UsageDataSubscription.SetRange("Supplier No.", SupplierNo);
            UsageDataSubscription.SetRange("Subscription Line Entry No.", 0);
            UsageDataSubscription.SetFilter("Connect to Sub. Header Method", '<>%1', Enum::"Connect To SO Method"::None);
            UsageDataSubscription.SetLoadFields("Entry No.");
            if UsageDataSubscription.FindSet() then
                repeat
                    CandidateEntryNos.Add(UsageDataSubscription."Entry No.");
                until UsageDataSubscription.Next() = 0;
        end;
        CheckOneEntryPerSubscription(CandidateEntryNos);

        foreach EntryNo in CandidateEntryNos do begin
            Clear(UsageDataSubscription);
            UsageDataSubscription.SetRange("Entry No.", EntryNo);
            UsageBasedBillingMgmt.ConnectSubscriptionsToServiceObjects(UsageDataSubscription);
            if AddEntryResult(EntryNo, EntriesArray) then
                ConnectedCount += 1
            else
                SkippedCount += 1;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('supplierNo', SupplierNo);
        ResponseJson.Add('connected', ConnectedCount);
        ResponseJson.Add('skipped', SkippedCount);
        ResponseJson.Add('entries', EntriesArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure CheckSelectedEntry(SupplierNo: Code[20]; EntryNo: Integer)
    var
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
    begin
        if not UsageDataSubscription.Get(EntryNo) then
            Error(EntryNotFoundErr, EntryNo, SupplierNo);
        if UsageDataSubscription."Supplier No." <> SupplierNo then
            Error(EntryNotFoundErr, EntryNo, SupplierNo);
        if UsageDataSubscription."Subscription Line Entry No." <> 0 then
            Error(AlreadyConnectedErr, EntryNo, UsageDataSubscription."Subscription Line Entry No.");
        if UsageDataSubscription."Connect to Sub. Header Method" = Enum::"Connect To SO Method"::None then
            Error(NoConnectMethodErr, EntryNo);
    end;

    /// <summary>
    /// Microsoft asks before connecting several entries to one Subscription and stops when nobody can answer;
    /// refusing such a selection up front names the entries instead.
    /// </summary>
    local procedure CheckOneEntryPerSubscription(CandidateEntryNos: List of [Integer])
    var
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        FirstEntryBySubscription: Dictionary of [Code[20], Integer];
        EntryNo: Integer;
    begin
        foreach EntryNo in CandidateEntryNos do begin
            UsageDataSubscription.Get(EntryNo);
            if UsageDataSubscription."Connect to Sub. Header No." <> '' then begin
                if FirstEntryBySubscription.ContainsKey(UsageDataSubscription."Connect to Sub. Header No.") then
                    Error(SameSubscriptionErr, FirstEntryBySubscription.Get(UsageDataSubscription."Connect to Sub. Header No."), EntryNo, UsageDataSubscription."Connect to Sub. Header No.");
                FirstEntryBySubscription.Add(UsageDataSubscription."Connect to Sub. Header No.", EntryNo);
            end;
        end;
    end;

    /// <summary>Reports one entry after the connect run; true when it is now connected.</summary>
    local procedure AddEntryResult(EntryNo: Integer; var EntriesArray: JsonArray) IsConnected: Boolean
    var
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        EntryJson: JsonObject;
        ReasonStream: InStream;
        ReasonText: Text;
    begin
        UsageDataSubscription.Get(EntryNo);
        IsConnected := UsageDataSubscription."Subscription Line Entry No." <> 0;
        if not IsConnected then begin
            UsageDataSubscription.CalcFields(Reason);
            UsageDataSubscription.Reason.CreateInStream(ReasonStream, TextEncoding::UTF8);
            ReasonStream.ReadText(ReasonText);
            if ReasonText = '' then
                ReasonText := UsageDataSubscription."Reason (Preview)";
        end;
        EntryJson.Add('entryNo', EntryNo);
        EntryJson.Add('connected', IsConnected);
        EntryJson.Add('subscriptionHeaderNo', UsageDataSubscription."Subscription Header No.");
        EntryJson.Add('subscriptionLineEntryNo', UsageDataSubscription."Subscription Line Entry No.");
        EntryJson.Add('reason', ReasonText);
        EntriesArray.Add(EntryJson);
    end;
}
