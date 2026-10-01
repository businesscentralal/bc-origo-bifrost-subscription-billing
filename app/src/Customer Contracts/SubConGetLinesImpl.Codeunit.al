namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Contract.GetLines</c> Bifrost message type.
/// Attaches unassigned Subscription Lines to a customer Subscription Contract, reproducing the
/// selection Microsoft's own "Get Subscription Lines" action applies on the contract page.
/// A plain Data.Records.Set cannot do this because attaching a line also inserts and numbers a
/// Cust. Sub. Contract Line and stamps the Subscription Line back with the contract it now belongs to.
/// </summary>
codeunit 10035037 "Sub Con GetLines Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract no.||is-IS=Áskriftarsamningur viðskiptavinar ''%1'' er ekki til.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a customer Subscription Contract. Returns the lines attached and any skipped.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við áskriftarsamning viðskiptavinar. Skilar tengdum línum og línum sem var sleppt.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Customer Subscription Contract");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Contract.GetLines, Subscription, Contract, GetLines, customer, attach lines', Comment = 'is-IS=Subscription.Contract.GetLines, áskrift, samningur, sækja línur, viðskiptavinur, tengja línur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Contract.GetLines: Attaches eligible lines to a customer contract.', Comment = 'is-IS=Subscription.Contract.GetLines: Tengir hæfar línur við viðskiptasamning.';
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
        Parameters := ContractParts.GetParameters(ContractType());
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
        Examples.Add(ContractMgt.Example('Attach the lines of one Subscription',
            '{"type":"Subscription.Contract.GetLines","subject":"CC000010","data":{"subscriptionHeaderNo":"SUB000010"}}',
            '{"status":"Success","contractNo":"CC000010","linesAttached":2,"attachedLines":[{"subscriptionLineEntryNo":1001,"contractLineNo":10000},{"subscriptionLineEntryNo":1002,"contractLineNo":20000}],"linesSkipped":1}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Attaches Subscription Lines that are on no contract yet to a customer Subscription Contract. The candidates are the lines Microsoft''s Get ' +
            'Subscription Lines action on the contract offers.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('A candidate line is invoiced via contract, is on no contract, belongs to a customer, and has no end date or one after the work date. A candidate ' +
            'whose Subscription Header names another End-User Customer No. than the contract''s Sell-to Customer No. is skipped and counted in linesSkipped, not ' +
            'refused. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.GetLines');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
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

    /// <summary>Attaches the candidate Subscription Lines to the contract. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AttachedLinesArray: JsonArray;
        AttachedLineJson: JsonObject;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        HeaderMatches: Dictionary of [Code[20], Boolean];
        EntryNoFilter: Text;
        ContractNo: Code[20];
        SubscriptionHeaderNo: Code[20];
        LinesAttached: Integer;
        LinesSkipped: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);
        SubscriptionHeaderNo := Helper.GetCode20(RequestJson, 'subscriptionHeaderNo', false);

        if not CustomerSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        SubscriptionLine.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        SubscriptionLine.SetRange("Subscription Contract No.", '');
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Customer);
        SubscriptionLine.SetFilter("Subscription Line End Date", '>%1|%2', WorkDate(), 0D);

        if SubscriptionHeaderNo <> '' then
            SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);

        EntryNoFilter := Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);
        if EntryNoFilter <> '' then
            SubscriptionLine.SetFilter("Entry No.", EntryNoFilter);

        if SubscriptionLine.FindSet() then
            repeat
                // The filter already holds the caller's selection whenever it fits in one
                // expression. The test repeats it for the case where it did not.
                if (SelectedEntryNos.Count() = 0) or SelectedEntryNos.ContainsKey(SubscriptionLine."Entry No.") then
                    if not BelongsToContractCustomer(SubscriptionLine."Subscription Header No.", CustomerSubscriptionContract."Sell-to Customer No.", HeaderMatches) then
                        LinesSkipped += 1
                    else begin
                        Clear(CustSubContractLine);
                        CustomerSubscriptionContract.CreateCustomerContractLineFromServiceCommitment(SubscriptionLine, ContractNo, CustSubContractLine);
                        LinesAttached += 1;
                        Clear(AttachedLineJson);
                        AttachedLineJson.Add('subscriptionLineEntryNo', SubscriptionLine."Entry No.");
                        AttachedLineJson.Add('contractLineNo', CustSubContractLine."Line No.");
                        AttachedLinesArray.Add(AttachedLineJson);
                    end;
            until SubscriptionLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('linesAttached', LinesAttached);
        ResponseJson.Add('attachedLines', AttachedLinesArray);
        ResponseJson.Add('linesSkipped', LinesSkipped);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Tells whether a Subscription Line's Subscription Header names the contract's customer, and
    /// so whether the line may be attached to it. A missing header answers no. The answer turns
    /// only on the header, and the lines a single call walks share a handful of headers between
    /// them, so it is read once per header and remembered for the rest of the run.
    /// </summary>
    local procedure BelongsToContractCustomer(SubscriptionHeaderNo: Code[20]; SellToCustomerNo: Code[20]; var HeaderMatches: Dictionary of [Code[20], Boolean]) Matches: Boolean
    var
        SubscriptionHeader: Record "Subscription Header";
    begin
        if HeaderMatches.Get(SubscriptionHeaderNo, Matches) then
            exit(Matches);

        SubscriptionHeader.SetLoadFields("End-User Customer No.");
        if SubscriptionHeader.Get(SubscriptionHeaderNo) then
            Matches := SubscriptionHeader."End-User Customer No." = SellToCustomerNo;

        HeaderMatches.Add(SubscriptionHeaderNo, Matches);
        exit(Matches);
    end;
}
