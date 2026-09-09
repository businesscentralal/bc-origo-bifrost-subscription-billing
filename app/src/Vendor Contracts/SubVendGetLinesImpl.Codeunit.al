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
codeunit 10035042 "Sub Vend GetLines Impl ori" implements "Msg Interface ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        ContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Birgjaáskriftarsamningurinn ''%1'' er ekki til.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a vendor subscription contract, creating a Vend. Sub. Contract Line for each one. Returns how many lines were attached.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við birgjaáskriftarsamning og býr til samningslínu fyrir áskrift birgis fyrir hverja þeirra. Skilar fjölda tengdra lína.';

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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        VendHelp: Codeunit "Sub Vend Help ori";
    begin
        Argument.SetResponseMarkdown(VendHelp.GetHelpMarkdown('Subscription.VendorContract.GetLines'));
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

    /// <summary>Attaches the eligible Subscription Lines. Called directly, or through the isolated write process.</summary>
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
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);
        SubscriptionHeaderNo := Helper.GetCode20(RequestJson, 'subscriptionHeaderNo', false);

        if not VendorSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

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
