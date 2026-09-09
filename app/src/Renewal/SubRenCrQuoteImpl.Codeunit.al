namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Renewal.CreateQuote</c> Bifrost message type.
/// Builds the Sub. Contract Renewal Line rows for a Customer Subscription Contract and runs
/// Microsoft's fully public <c>Codeunit "Create Sub. Contract Renewal"</c> to turn them into a
/// sales quote. A plain Data.Records.Set cannot do this because the renewal lines have to be
/// derived, one per still-open Subscription Line, from the contract's own service commitments
/// before the quote-creating codeunit can run - and Microsoft's own interactive wrapper around
/// that codeunit (StartContractRenewalFromContract, BatchCreateContractRenewal, OpenSalesQuotes)
/// is internal and expects a user at a request page, so this codeunit bypasses it entirely.
/// </summary>
codeunit 10035052 "Sub Ren CrQuote Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = customer contract no.||is-IS=Viðskiptavinasamningurinn ''%1'' er ekki til.';
        NoRenewableLinesErr: Label 'The Customer Subscription Contract ''%1'' has no Subscription Lines that can be renewed.', Comment = '%1 = customer contract no.||is-IS=Viðskiptavinasamningurinn ''%1'' er ekki með neinar áskriftarlínur sem hægt er að endurnýja.';
        QuoteNotCreatedErr: Label 'Create Sub. Contract Renewal did not produce a sales quote for Customer Subscription Contract ''%1''.', Comment = '%1 = customer contract no.||is-IS=Create Sub. Contract Renewal bjó ekki til sölutilboð fyrir viðskiptavinasamninginn ''%1''.';
        DescriptionLbl: Label 'Builds contract renewal lines from a Customer Subscription Contract''s Subscription Lines and creates a renewal sales quote from them.', MaxLength = 250, Comment = 'is-IS=Býr til endurnýjunarlínur samnings út frá áskriftarlínum viðskiptavinasamnings og útbýr endurnýjunarsölutilboð út frá þeim.';

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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        RenHelp: Codeunit "Sub Ren Help ori";
    begin
        Argument.SetResponseMarkdown(RenHelp.GetHelpMarkdown('Subscription.Renewal.CreateQuote'));
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

    /// <summary>Builds the renewal lines for the contract and creates the renewal sales quote.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        SubContractRenewalLine: Record "Sub. Contract Renewal Line";
        CreateSubContractRenewal: Codeunit "Create Sub. Contract Renewal";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        SalesQuoteNo: Code[20];
        RenewalLinesCreated: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);

        if not CustomerSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        SubContractRenewalLine.SetRange("Linked to Sub. Contract No.", ContractNo);
        if not SubContractRenewalLine.IsEmpty() then
            SubContractRenewalLine.DeleteAll(true);

        CustSubContractLine.SetRange("Subscription Contract No.", ContractNo);
        CustSubContractLine.SetLoadFields("Subscription Line Entry No.");
        if CustSubContractLine.FindSet() then
            repeat
                if CustSubContractLine."Subscription Line Entry No." <> 0 then
                    if SubscriptionLine.Get(CustSubContractLine."Subscription Line Entry No.") then
                        if SubscriptionLine."Subscription Line End Date" <> 0D then begin
                            Clear(SubContractRenewalLine);
                            if SubContractRenewalLine.InitFromServiceCommitment(SubscriptionLine) then begin
                                SubContractRenewalLine.Insert(false);
                                RenewalLinesCreated += 1;
                            end;
                        end;
            until CustSubContractLine.Next() = 0;

        if RenewalLinesCreated = 0 then
            Error(NoRenewableLinesErr, ContractNo);

        SubContractRenewalLine.Reset();
        SubContractRenewalLine.SetRange("Subscription Contract No.", ContractNo);
        SubContractRenewalLine.SetRange(Partner, Enum::"Service Partner"::Customer);

        Clear(CreateSubContractRenewal);
        // Call this without consuming the Boolean, so a failure inside Microsoft's codeunit
        // propagates instead of being caught here. The renewal lines above are already written in
        // this transaction, and Business Central cannot roll a caught Codeunit.Run back to a
        // savepoint once that is true - it abandons the whole transaction and reports only
        // "An error occurred and the transaction is stopped", losing the real reason. Letting the
        // error travel up to the single isolation boundary in "Sub Write Process ori" rolls the
        // renewal lines back with it and keeps Microsoft's own message intact.
        CreateSubContractRenewal.Run(SubContractRenewalLine);

        SalesQuoteNo := CreateSubContractRenewal.GetSalesQuoteNo();
        if SalesQuoteNo = '' then
            Error(QuoteNotCreatedErr, ContractNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        ResponseJson.Add('renewalLinesCreated', RenewalLinesCreated);
        ResponseJson.Add('salesQuoteNo', SalesQuoteNo);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
