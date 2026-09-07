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
codeunit 10035037 "Sub Con GetLines Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract no.||is-IS=Áskriftarsamningur viðskiptavinar ''%1'' er ekki til.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a customer Subscription Contract. Returns the lines attached and any skipped.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við áskriftarsamning viðskiptavinar. Skilar tengdum línum og línum sem var sleppt.';

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
        Argument.SetResponseMarkdown(ConHelp.GetHelpMarkdown('Subscription.Contract.GetLines'));
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

    /// <summary>Attaches the candidate Subscription Lines to the contract. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
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
