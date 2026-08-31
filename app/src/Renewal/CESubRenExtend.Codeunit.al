namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Renewal.Extend</c> Cloud Event message type.
/// Extends an existing Subscription with a customer and/or vendor contract by running
/// Microsoft's fully public <c>Codeunit "Extend Sub. Contract Mgt."</c>. A plain
/// Data.Records.Set cannot do this because extending a contract inserts new Subscription
/// Lines from the item's service commitment packages and then derives new Cust./Vend. Sub.
/// Contract Line records from them - work the codeunit performs as a unit.
/// </summary>
codeunit 10035051 "CE Sub Ren Extend Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        SubscriptionHeaderNotFoundErr: Label 'The Subscription ''%1'' does not exist.', Comment = '%1 = subscription header no.||is-IS=Áskriftin ''%1'' er ekki til.';
        CustomerContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = customer contract no.||is-IS=Viðskiptavinasamningurinn ''%1'' er ekki til.';
        VendorContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = vendor contract no.||is-IS=Birgjasamningurinn ''%1'' er ekki til.';
        PackageNotFoundErr: Label 'The Subscription Package ''%1'' does not exist.', Comment = '%1 = subscription package code||is-IS=Áskriftarpakkinn ''%1'' er ekki til.';
        NeitherContractErr: Label 'The request must supply at least one of ''customerContractNo'' or ''vendorContractNo''.', Comment = 'is-IS=Beiðnin verður að innihalda a.m.k. annað af ''customerContractNo'' eða ''vendorContractNo''.';
        DescriptionLbl: Label 'Extends a Subscription with a new customer and/or vendor contract, applying the item''s standard packages plus any extra packages supplied. Returns the contract line counts created.', MaxLength = 250, Comment = 'is-IS=Framlengir áskrift með nýjum viðskiptavina- og/eða birgjasamningi og beitir stöðluðum pökkum vörunnar auk aukapakka sem tilgreindir eru. Skilar fjölda samningslína sem urðu til.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Header");
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
        HelpBuilder.AppendLine('# Subscription.Renewal.Extend');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Extends an existing Subscription (table 8057) onto a customer and/or vendor contract by');
        HelpBuilder.AppendLine('running Microsoft''s `Codeunit "Extend Sub. Contract Mgt."`. The Subscription must already');
        HelpBuilder.AppendLine('exist - this message type does not create one. The item''s own standard service commitment');
        HelpBuilder.AppendLine('packages are always applied by Microsoft''s codeunit; `subscriptionPackageCodes` only adds');
        HelpBuilder.AppendLine('further packages beyond those standard ones.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | Yes | The Subscription to extend. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| customerContractNo | Code[20] | No | An existing Customer Subscription Contract to extend onto. |');
        HelpBuilder.AppendLine('| vendorContractNo | Code[20] | No | An existing Vendor Subscription Contract to extend onto. |');
        HelpBuilder.AppendLine('| subscriptionPackageCodes | Array of Code[20] | No | Extra Subscription Package codes to apply beyond the item''s standard packages. |');
        HelpBuilder.AppendLine('| usageBasedBillingPackageLinesOnly | Boolean | No | Defaults to false. When true, only usage based billing package lines are added. |');
        HelpBuilder.AppendLine('| supplierReferenceEntryNo | Integer | No | Defaults to 0. Links the extension to a specific supplier reference Subscription Line entry. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('At least one of `customerContractNo` or `vendorContractNo` is required.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000010",');
        HelpBuilder.AppendLine('  "customerContractNo": "CC000010",');
        HelpBuilder.AppendLine('  "subscriptionPackageCodes": ["SUPPORT"]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SO000010",');
        HelpBuilder.AppendLine('  "customerContractNo": "CC000010",');
        HelpBuilder.AppendLine('  "custContractLineCountBefore": 3,');
        HelpBuilder.AppendLine('  "custContractLineCountAfter": 5,');
        HelpBuilder.AppendLine('  "custContractLinesCreated": 2,');
        HelpBuilder.AppendLine('  "newSubscriptionLineEntryNos": [1044, 1045],');
        HelpBuilder.AppendLine('  "newSubscriptionLineCount": 2');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`custContractLine*`/`vendContractLine*` fields are only present for the side that was');
        HelpBuilder.AppendLine('extended. `newSubscriptionLineEntryNos` lists the Subscription Line entries this call');
        HelpBuilder.AppendLine('added to the Subscription, regardless of which contract side they were linked to.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The subscription does not exist | The Subscription ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| The customer contract does not exist | The Customer Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| The vendor contract does not exist | The Vendor Subscription Contract ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| A package code does not exist | The Subscription Package ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| Neither contract number was supplied | The request must supply at least one of ''customerContractNo'' or ''vendorContractNo''. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes: it inserts Subscription Lines and Cust./Vend. Sub. Contract');
        HelpBuilder.AppendLine('Line records. The write runs in an isolated transaction that rolls back on error, and');
        HelpBuilder.AppendLine('Microsoft''s completion dialog is suppressed so the call never blocks on user input.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Renewal.CreateQuote`');

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

    /// <summary>Extends the subscription onto the requested contract(s) and reports the lines created.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        SubscriptionHeader: Record "Subscription Header";
        CustomerSubscriptionContract: Record "Customer Subscription Contract";
        VendorSubscriptionContract: Record "Vendor Subscription Contract";
        SubscriptionPackage: Record "Subscription Package";
        TempSubscriptionPackage: Record "Subscription Package" temporary;
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        ExtendSubContractMgt: Codeunit "Extend Sub. Contract Mgt.";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        NewEntryNosArray: JsonArray;
        PackagesJToken: JsonToken;
        PackageJToken: JsonToken;
        ExistingEntryNos: List of [Integer];
        SubscriptionHeaderNo: Code[20];
        CustomerContractNo: Code[20];
        VendorContractNo: Code[20];
        PackageCode: Code[20];
        ExtendCustomerContract: Boolean;
        ExtendVendorContract: Boolean;
        UsageBasedBillingPackageLinesOnly: Boolean;
        SupplierReferenceEntryNo: Integer;
        CustLineCountBefore: Integer;
        CustLineCountAfter: Integer;
        VendLineCountBefore: Integer;
        VendLineCountAfter: Integer;
        NewLineCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        SubscriptionHeaderNo := Helper.GetSubjectOr(Argument, RequestJson, 'subscriptionHeaderNo', true);
        CustomerContractNo := Helper.GetCode20(RequestJson, 'customerContractNo', false);
        VendorContractNo := Helper.GetCode20(RequestJson, 'vendorContractNo', false);
        UsageBasedBillingPackageLinesOnly := Helper.GetBoolean(RequestJson, 'usageBasedBillingPackageLinesOnly', false);
        SupplierReferenceEntryNo := Helper.GetInteger(RequestJson, 'supplierReferenceEntryNo', false);

        if not SubscriptionHeader.Get(SubscriptionHeaderNo) then
            Error(SubscriptionHeaderNotFoundErr, SubscriptionHeaderNo);

        ExtendCustomerContract := CustomerContractNo <> '';
        ExtendVendorContract := VendorContractNo <> '';
        if not ExtendCustomerContract and not ExtendVendorContract then
            Error(NeitherContractErr);

        if ExtendCustomerContract then
            if not CustomerSubscriptionContract.Get(CustomerContractNo) then
                Error(CustomerContractNotFoundErr, CustomerContractNo);
        if ExtendVendorContract then
            if not VendorSubscriptionContract.Get(VendorContractNo) then
                Error(VendorContractNotFoundErr, VendorContractNo);

        if RequestJson.Get('subscriptionPackageCodes', PackagesJToken) then
            if PackagesJToken.IsArray() then
                foreach PackageJToken in PackagesJToken.AsArray() do begin
                    PackageCode := CopyStr(PackageJToken.AsValue().AsText(), 1, MaxStrLen(PackageCode));
                    if not SubscriptionPackage.Get(PackageCode) then
                        Error(PackageNotFoundErr, PackageCode);
                    TempSubscriptionPackage := SubscriptionPackage;
                    TempSubscriptionPackage.Selected := true;
                    TempSubscriptionPackage.Insert(false);
                end;

        if ExtendCustomerContract then begin
            CustSubContractLine.SetRange("Subscription Contract No.", CustomerContractNo);
            CustLineCountBefore := CustSubContractLine.Count();
        end;
        if ExtendVendorContract then begin
            VendSubContractLine.SetRange("Subscription Contract No.", VendorContractNo);
            VendLineCountBefore := VendSubContractLine.Count();
        end;

        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        SubscriptionLine.SetLoadFields("Entry No.");
        if SubscriptionLine.FindSet() then
            repeat
                ExistingEntryNos.Add(SubscriptionLine."Entry No.");
            until SubscriptionLine.Next() = 0;

        ExtendSubContractMgt.SetHideDialog(true);
        ExtendSubContractMgt.ExtendContract(
            SubscriptionHeader, TempSubscriptionPackage,
            ExtendCustomerContract, CustomerSubscriptionContract,
            ExtendVendorContract, VendorSubscriptionContract,
            UsageBasedBillingPackageLinesOnly, SupplierReferenceEntryNo);

        SubscriptionLine.Reset();
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        SubscriptionLine.SetLoadFields("Entry No.");
        if SubscriptionLine.FindSet() then
            repeat
                if not ExistingEntryNos.Contains(SubscriptionLine."Entry No.") then begin
                    NewEntryNosArray.Add(SubscriptionLine."Entry No.");
                    NewLineCount += 1;
                end;
            until SubscriptionLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('subscriptionHeaderNo', SubscriptionHeaderNo);
        if ExtendCustomerContract then begin
            CustSubContractLine.Reset();
            CustSubContractLine.SetRange("Subscription Contract No.", CustomerContractNo);
            CustLineCountAfter := CustSubContractLine.Count();
            ResponseJson.Add('customerContractNo', CustomerContractNo);
            ResponseJson.Add('custContractLineCountBefore', CustLineCountBefore);
            ResponseJson.Add('custContractLineCountAfter', CustLineCountAfter);
            ResponseJson.Add('custContractLinesCreated', CustLineCountAfter - CustLineCountBefore);
        end;
        if ExtendVendorContract then begin
            VendSubContractLine.Reset();
            VendSubContractLine.SetRange("Subscription Contract No.", VendorContractNo);
            VendLineCountAfter := VendSubContractLine.Count();
            ResponseJson.Add('vendorContractNo', VendorContractNo);
            ResponseJson.Add('vendContractLineCountBefore', VendLineCountBefore);
            ResponseJson.Add('vendContractLineCountAfter', VendLineCountAfter);
            ResponseJson.Add('vendContractLinesCreated', VendLineCountAfter - VendLineCountBefore);
        end;
        ResponseJson.Add('newSubscriptionLineEntryNos', NewEntryNosArray);
        ResponseJson.Add('newSubscriptionLineCount', NewLineCount);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
