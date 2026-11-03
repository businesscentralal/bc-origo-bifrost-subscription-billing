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
codeunit 10035051 "Sub Ren Extend Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        SubscriptionHeaderNotFoundErr: Label 'The Subscription ''%1'' does not exist.', Comment = '%1 = subscription header no.||is-IS=Áskriftin ''%1'' er ekki til.';
        CustomerContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = customer contract no.||is-IS=Áskriftarsamningur viðskiptamanns ''%1'' er ekki til.';
        VendorContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = vendor contract no.||is-IS=Áskriftarsamningur lánardrottins ''%1'' er ekki til.';
        PackageNotFoundErr: Label 'The Subscription Package ''%1'' does not exist.', Comment = '%1 = subscription package code||is-IS=Áskriftarpakkinn ''%1'' er ekki til.';
        NeitherContractErr: Label 'The request must supply at least one of ''customerContractNo'' or ''vendorContractNo''.', Comment = 'is-IS=Beiðnin verður að innihalda a.m.k. annað af ''customerContractNo'' eða ''vendorContractNo''.';
        DescriptionLbl: Label 'Extends an existing Subscription onto a customer contract, a vendor contract or both, applying the item''s standard packages plus any extra packages supplied. Returns the contract line counts created.', MaxLength = 250, Comment = 'is-IS=Framlengir fyrirliggjandi áskrift á áskriftarsamning viðskiptamanns, samning lánardrottins eða báða og beitir stöðluðum pökkum vörunnar auk aukapakka sem tilgreindir eru. Skilar fjölda samningslína sem urðu til.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'extend subscription, extend contract term, extend subscription onto contract, extend without quote, add package lines to a contract, renew without quotation, extend customer and vendor contract, prolong subscription', Comment = 'is-IS=framlengja áskrift, framlengja samningstíma, framlengja áskrift á samning, framlengja án tilboðs, bæta pakkalínum við samning, endurnýja án tilboðs, framlengja samning viðskiptamanns og lánardrottins, lengja áskrift';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Extend a Subscription: applies the item''s standard packages and any extra packages to an existing Subscription and adds the lines to the named customer and/or vendor contracts, with no dialog. Irreversible. To renew through a sales quote use Subscription.Renewal.CreateQuote.', Comment = 'is-IS=Framlengja áskrift: beitir stöðluðum pökkum vörunnar og aukapökkum á fyrirliggjandi áskrift og bætir línunum við tilgreinda samninga viðskiptamanns og/eða lánardrottins, án gluggasamskipta. Óafturkræf aðgerð. Til að endurnýja með sölutilboði skal nota Subscription.Renewal.CreateQuote.';
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
        Parameters := ContractParts.RenewalExtendParameters();
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
        Examples.Add(ContractMgt.Example('Extend onto a customer contract with an extra package',
            '{"type":"Subscription.Renewal.Extend","subject":"SUB000010","data":{"customerContractNo":"CC000010","subscriptionPackageCodes":["SUPPORT"]}}',
            '{"status":"Success","subscriptionHeaderNo":"SUB000010","customerContractNo":"CC000010","custContractLineCountBefore":3,"custContractLineCountAfter":5,"custContractLinesCreated":2,"newSubscriptionLineEntryNos":[1044,1045],"newSubscriptionLineCount":2}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Extends an existing Subscription onto a customer contract, a vendor contract or both, through Microsoft''s extend-contract logic. The Subscription ' +
            'must exist; this type does not create one.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Microsoft always applies the item''s standard packages; subscriptionPackageCodes adds packages beyond those. Microsoft''s completion dialog is ' +
            'suppressed, so the call never waits for input. ' +
            ContractParts.BooleanNote() +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Renewal.Extend');
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

        if not Codeunit.Run(Codeunit::"Sub Ren Extend Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Extends the subscription onto the requested contract(s) and reports the lines created.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
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
        SubscriptionHeaderNo := Helper.GetSubjectOr(RequestJson, 'subscriptionHeaderNo', Argument, true);
        CustomerContractNo := Helper.GetCode20(RequestJson, 'customerContractNo', false);
        VendorContractNo := Helper.GetCode20(RequestJson, 'vendorContractNo', false);
        UsageBasedBillingPackageLinesOnly := Helper.GetBoolean(RequestJson, 'usageBasedBillingPackageLinesOnly', false);
        SupplierReferenceEntryNo := Helper.GetInteger(RequestJson, 'supplierReferenceEntryNo', false);

        ExtendCustomerContract := CustomerContractNo <> '';
        ExtendVendorContract := VendorContractNo <> '';
        if not ExtendCustomerContract and not ExtendVendorContract then
            Helper.RaiseError("Bifrost Error Code ori"::MissingParameter, NeitherContractErr, 'customerContractNo', '', NeitherContractErr);

        if not SubscriptionHeader.Get(SubscriptionHeaderNo) then
            Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SubscriptionHeaderNotFoundErr, SubscriptionHeaderNo), 'subscriptionHeaderNo', Format(SubscriptionHeaderNo, 0, 9));


        if ExtendCustomerContract then
            if not CustomerSubscriptionContract.Get(CustomerContractNo) then
                Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(CustomerContractNotFoundErr, CustomerContractNo), 'customerContractNo', Format(CustomerContractNo, 0, 9));
        if ExtendVendorContract then
            if not VendorSubscriptionContract.Get(VendorContractNo) then
                Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(VendorContractNotFoundErr, VendorContractNo), 'vendorContractNo', Format(VendorContractNo, 0, 9));

        if Helper.TryGetArray(RequestJson, 'subscriptionPackageCodes', PackagesJsonArray) then
            foreach PackageJToken in PackagesJsonArray do begin
                PackageCode := CopyStr(PackageJToken.AsValue().AsText(), 1, MaxStrLen(PackageCode));
                if not SubscriptionPackage.Get(PackageCode) then
                    Helper.RaiseRefusal("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(PackageNotFoundErr, PackageCode), 'subscriptionPackageCode', Format(PackageCode, 0, 9));
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
