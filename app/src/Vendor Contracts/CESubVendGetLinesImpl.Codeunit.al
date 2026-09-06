namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.VendorContract.GetLines</c> Cloud Event message type.
/// Attaches unassigned Subscription Lines (Partner = Vendor, invoiced via Contract, not yet
/// linked to a Vendor Subscription Contract) to one vendor subscription contract.
/// A plain Data.Records.Set cannot do this because attaching a line also has to create its
/// matching Vend. Sub. Contract Line and keep both records consistent - that pairing is done
/// by Microsoft's own table procedure, not by writing fields directly.
/// </summary>
codeunit 10035042 "CE Sub Vend GetLines Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        ContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Birgjaáskriftarsamningurinn ''%1'' er ekki til.';
        InvalidEntryNoArrayErr: Label 'The parameter ''subscriptionLineEntryNos'' must be a JSON array of integers.', Comment = 'is-IS=Færibreytan ''subscriptionLineEntryNos'' verður að vera JSON fylki af heiltölum.';
        DescriptionLbl: Label 'Attaches unassigned Subscription Lines to a vendor subscription contract, creating a Vend. Sub. Contract Line for each one. Returns how many lines were attached.', MaxLength = 250, Comment = 'is-IS=Tengir ótengdar áskriftarlínur við birgjaáskriftarsamning og býr til samningslínu fyrir áskrift birgis fyrir hverja þeirra. Skilar fjölda tengdra lína.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Vendor Subscription Contract");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.VendorContract.GetLines');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Finds Subscription Lines (table 8059) that are invoiced via a contract, belong to the vendor');
        HelpBuilder.AppendLine('partner, are not yet linked to any Vendor Subscription Contract, and have not already ended,');
        HelpBuilder.AppendLine('then attaches each one to the given Vendor Subscription Contract. Attaching a line creates a');
        HelpBuilder.AppendLine('matching Vend. Sub. Contract Line (table 8065) for it. Because Microsoft only exposes the');
        HelpBuilder.AppendLine('single-line attach procedure to external apps, this call loops it once per candidate line.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| contractNo | Code[20] | Yes | The Vendor Subscription Contract to attach lines to. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | No | Restrict candidate lines to this Subscription Header. |');
        HelpBuilder.AppendLine('| subscriptionLineEntryNos | Array of Integer | No | Restrict to these exact Subscription Line entry numbers. Omit to attach every eligible line. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('A candidate line has ''Invoicing via'' = Contract, Partner = Vendor, no Subscription Contract No.');
        HelpBuilder.AppendLine('yet, and a Subscription Line End Date that is either blank or after the work date.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "contractNo": "VC000010",');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000045",');
        HelpBuilder.AppendLine('  "subscriptionLineEntryNos": [101, 102]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "contractNo": "VC000010",');
        HelpBuilder.AppendLine('  "linesAttached": 2,');
        HelpBuilder.AppendLine('  "attachedLines": [');
        HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 101, "contractLineNo": 10000 },');
        HelpBuilder.AppendLine('    { "subscriptionLineEntryNo": 102, "contractLineNo": 20000 }');
        HelpBuilder.AppendLine('  ]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('A run that matches no candidate line is a success with `linesAttached` of 0 and an empty array.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| contractNo is missing | The request is missing the required parameter ''contractNo''. |');
        HelpBuilder.AppendLine('| subscriptionLineEntryNos is present but is not an array | The parameter ''subscriptionLineEntryNos'' must be a JSON array. |');
        HelpBuilder.AppendLine('| subscriptionLineEntryNos holds something other than integers | The parameter ''subscriptionLineEntryNos'' must be a JSON array of integers. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. It only attaches already-existing Subscription Lines to a contract -');
        HelpBuilder.AppendLine('it never creates or deletes a Subscription Line. The write runs in an isolated transaction that');
        HelpBuilder.AppendLine('rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.VendorContract.CreateInvoice`');
        HelpBuilder.AppendLine('- `Subscription.VendorContract.PreviewInvoice`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    var
        WriteProcess: Codeunit "CE Sub Write Process ori";
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
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        VendorSubscriptionContract: Record "Vendor Subscription Contract";
        SubscriptionLine: Record "Subscription Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AttachedLinesArray: JsonArray;
        AttachedLineJson: JsonObject;
        EntryNoJToken: JsonToken;
        EntryNoJsonArray: JsonArray;
        EntryNoFilter: List of [Integer];
        EntryNo: Integer;
        ContractNo: Code[20];
        SubscriptionHeaderNo: Code[20];
        LinesAttached: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(Argument, RequestJson, 'contractNo', true);
        SubscriptionHeaderNo := Helper.GetCode20(RequestJson, 'subscriptionHeaderNo', false);

        if not VendorSubscriptionContract.Get(ContractNo) then
            Error(ContractNotFoundErr, ContractNo);

        if Helper.TryGetArray(RequestJson, 'subscriptionLineEntryNos', EntryNoJsonArray) then
            foreach EntryNoJToken in EntryNoJsonArray do begin
                if not EntryNoJToken.IsValue() then
                    Error(InvalidEntryNoArrayErr);
                if not Evaluate(EntryNo, EntryNoJToken.AsValue().AsText(), 9) then
                    Error(InvalidEntryNoArrayErr);
                if not EntryNoFilter.Contains(EntryNo) then
                    EntryNoFilter.Add(EntryNo);
            end;

        SubscriptionLine.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        SubscriptionLine.SetRange("Subscription Contract No.", '');
        SubscriptionLine.SetRange(Partner, Enum::"Service Partner"::Vendor);
        SubscriptionLine.SetFilter("Subscription Line End Date", '>%1|%2', WorkDate(), 0D);
        if SubscriptionHeaderNo <> '' then
            SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);

        if SubscriptionLine.FindSet() then
            repeat
                if (EntryNoFilter.Count() = 0) or EntryNoFilter.Contains(SubscriptionLine."Entry No.") then begin
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
