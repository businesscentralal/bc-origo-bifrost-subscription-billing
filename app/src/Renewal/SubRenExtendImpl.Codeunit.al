namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Renewal.Extend</c> Bifrost message type.
/// Extends an existing Subscription with a customer and/or vendor contract by running
/// Microsoft's fully public <c>Codeunit "Extend Sub. Contract Mgt."</c>. A plain
/// Data.Records.Set cannot do this because extending a contract inserts new Subscription
/// Lines from the item's service commitment packages and then derives new Cust./Vend. Sub.
/// Contract Line records from them - work the codeunit performs as a unit.
/// </summary>
codeunit 10035051 "Sub Ren Extend Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
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

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        RenHelp: Codeunit "Sub Ren Help ori";
    begin
        Argument.SetResponseMarkdown(RenHelp.GetHelpMarkdown('Subscription.Renewal.Extend'));
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

    /// <summary>Extends the subscription onto the requested contract(s) and reports the lines created.</summary>
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        PackagesJsonArray: JsonArray;
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

        if Helper.TryGetArray(RequestJson, 'subscriptionPackageCodes', PackagesJsonArray) then
            foreach PackageJToken in PackagesJsonArray do begin
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
