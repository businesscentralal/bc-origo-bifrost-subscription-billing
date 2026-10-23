namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Finance.Currency;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Contract.UpdateExchangeRates</c> Bifrost message type (#40).
/// Recalculates the currency data of a customer or vendor Subscription Contract's Subscription Lines
/// with a new exchange rate, as the Update Exchange Rates action does.
/// 
/// Investigation (#40 AC01): validating Currency Code on the contract does not reach the same result.
/// The field's OnValidate calls UpdateAndRecalculateServiceCommitmentCurrencyData only when the code
/// changes, so refreshing the rate of an unchanged currency recalculates nothing. When it does run,
/// "Subscription Line".OpenExchangeSelectionPage returns false without a user interface and leaves the
/// contract's CurrencyFactor and CurrencyFactorDate at 0 and 0D, so every line is recalculated with
/// a zero currency factor. The procedure is internal, so its logic is rebuilt here from Microsoft's
/// source, with the rate the Exchange Rate Selection page would propose as the default:
/// 
/// - "Customer Subscription Contract" / "Vendor Subscription Contract".UpdateAndRecalculateServiceCommitmentCurrencyData;
/// - "Subscription Line".UpdateAndRecalculateServCommCurrencyFromContract, UpdateCurrencyDataOnServiceCommitments,
///   SetCurrencyData and RecalculateAmountsFromCurrencyData;
/// - page "Exchange Rate Selection".SetData for the default rate.
/// 
/// Portions copyright (c) Microsoft Corporation, licensed under the MIT License (BCApps releases/28.x
/// a674a13, src/Apps/W1/Subscription Billing/App/Service Commitments/Tables/SubscriptionLine.Table.al,
/// Customer Contracts/Tables/CustomerSubscriptionContract.Table.al, Vendor Contracts/Tables/VendorSubscriptionContract.Table.al,
/// Service Commitments/Pages/ExchangeRateSelection.Page.al). See docs/microsoft-dependencies.md.
/// </summary>
codeunit 10035041 "Sub Con UpdFCY Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        CustomerContractNotFoundErr: Label 'The Customer Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur viðskiptamanns ''%1'' er ekki til.';
        VendorContractNotFoundErr: Label 'The Vendor Subscription Contract ''%1'' does not exist.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur lánardrottins ''%1'' er ekki til.';
        LocalCurrencyErr: Label 'Subscription Contract ''%1'' uses local currency and has no foreign-currency exchange rate to update.', Comment = '%1 = contract number||is-IS=Áskriftarsamningur ''%1'' notar staðbundinn gjaldmiðil og hefur ekkert erlent gengi til að uppfæra.';
        ZeroExchangeRateErr: Label 'The exchange rate for currency ''%1'' on %2 is %3. Send a currencyFactor greater than zero, or set up an exchange rate for that date.', Comment = '%1 = currency code, %2 = date, %3 = the rate||is-IS=Gengi gjaldmiðilsins ''%1'' þann %2 er %3. Sendu currencyFactor sem er stærri en núll, eða settu upp gengi fyrir þá dagsetningu.';
        DescriptionLbl: Label 'Recalculates the currency data of a Subscription Contract''s Subscription Lines with a new exchange rate, like Update Exchange Rates, for customer or vendor contracts.', MaxLength = 250, Comment = 'is-IS=Endurreiknar gjaldmiðilsgögn áskriftarlína áskriftarsamnings með nýju gengi, eins og Uppfæra gengi, fyrir samninga viðskiptamanna eða lánardrottna.';

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
        KeywordsLbl: Label 'update exchange rates on contract, recalculate contract currency, change currency factor, new exchange rate for subscription lines, foreign currency contract prices, refresh contract exchange rate, update currency factor date, recalculate prices in foreign currency', Comment = 'is-IS=uppfæra gengi á samningi, endurreikna gjaldmiðil samnings, breyta gengisstuðli, nýtt gengi fyrir áskriftarlínur, verð samnings í erlendum gjaldmiðli, endurnýja gengi samnings, uppfæra gengisdagsetningu, endurreikna verð í erlendum gjaldmiðli';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Update contract exchange rates: stores a new currency factor on the Subscription Lines of one foreign-currency customer or vendor contract and recalculates their prices and amounts, archiving the old ones. Writes data; nothing is billed. Create the invoice afterwards with Subscription.Contract.CreateInvoice or Subscription.VendorContract.CreateInvoice.', Comment = 'is-IS=Uppfæra gengi á samningi: vistar nýjan gengisstuðul á áskriftarlínum eins samnings viðskiptamanns eða lánardrottins í erlendum gjaldmiðli og endurreiknar verð þeirra og upphæðir, og geymir gömlu gildin í safni. Skrifar gögn; ekkert er reikningsfært. Reikningurinn er stofnaður á eftir með Subscription.Contract.CreateInvoice eða Subscription.VendorContract.CreateInvoice.';
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
        Parameters := ContractParts.UpdateExchangeRatesParameters();
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
        Examples.Add(ContractMgt.Example('Refresh with the current rate',
            '{"type":"Subscription.Contract.UpdateExchangeRates","subject":"CC000010","data":{}}',
            '{"status":"Success","contractNo":"CC000010","partner":"Customer","currencyCode":"EUR","currencyFactor":"0.0068","currencyFactorDate":"2026-10-15","linesRecalculated":4,"linesSkipped":0}'));
        Examples.Add(ContractMgt.Example('A vendor contract with a fixed rate',
            '{"type":"Subscription.Contract.UpdateExchangeRates","subject":"VC000003","data":{"partner":"Vendor","currencyFactorDate":"2026-10-01","currencyFactor":0.0071}}',
            '{"status":"Success","contractNo":"VC000003","partner":"Vendor","currencyCode":"USD","currencyFactor":"0.0071","currencyFactorDate":"2026-10-01","linesRecalculated":2,"linesSkipped":0}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Recalculates the Subscription Lines of a customer or vendor Subscription Contract in a foreign currency, as the Update Exchange Rates action does: ' +
            'each line gets the contract''s Currency Code, the currency factor and its date, and its Calculation Base Amount is converted again from the Calculation ' +
            'Base Amount (LCY), which recalculates price and amount. The factor defaults to the exchange rate on currencyFactorDate, which is what the Exchange ' +
            'Rate Selection page proposes.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Microsoft''s own update cannot be called from outside Business Central. Data.Records.Set refuses Currency Code on a subscription contract, because Microsoft''s validation would ' +
            'recalculate the lines with a currency factor of zero when the exchange rate page cannot open. This type rebuilds Microsoft''s steps instead. ' +
            'Each line is saved with its modify trigger, which flags its billing lines Update Required and archives the old ' +
            'amounts, as Microsoft does. A line whose contract line is closed is skipped and counted under linesSkipped, because Business Central does not allow ' +
            'such a line to be changed. currencyFactor is the factor Business Central stores: foreign currency per unit of local currency. Running the type again ' +
            'with another rate recalculates from the same local currency amounts. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Contract.UpdateExchangeRates');
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

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Con UpdFCY Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Recalculates the contract's Subscription Lines. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Partner: Enum "Service Partner";
        ContractNo: Code[20];
        CurrencyCode: Code[10];
        CurrencyFactorDate: Date;
        CurrencyFactor: Decimal;
        LinesRecalculated: Integer;
        LinesSkipped: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetSubjectOr(RequestJson, 'contractNo', Argument, true);
        Partner := Helper.GetServicePartner(RequestJson, 'partner', Enum::"Service Partner"::Customer);
        CurrencyFactorDate := Helper.GetDateOrDefault(RequestJson, 'currencyFactorDate', WorkDate());

        CurrencyCode := GetContractCurrencyCode(Partner, ContractNo);
        if CurrencyCode = '' then
            Error(LocalCurrencyErr, ContractNo);

        // Exchange Rate Selection.SetData proposes the rate of the key date; the caller may override it.
        if Helper.HasValue(RequestJson, 'currencyFactor') then
            CurrencyFactor := Helper.GetDecimal(RequestJson, 'currencyFactor', true)
        else
            CurrencyFactor := CurrencyExchangeRate.ExchangeRate(CurrencyFactorDate, CurrencyCode);
        if CurrencyFactor <= 0 then
            Error(ZeroExchangeRateErr, CurrencyCode, Helper.FormatDate(CurrencyFactorDate), Helper.FormatDecimal(CurrencyFactor));

        RecalculateLines(Partner, ContractNo, CurrencyCode, CurrencyFactor, CurrencyFactorDate, LinesRecalculated, LinesSkipped);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('contractNo', ContractNo);
        if Partner = Partner::Vendor then
            ResponseJson.Add('partner', 'Vendor')
        else
            ResponseJson.Add('partner', 'Customer');
        ResponseJson.Add('currencyCode', CurrencyCode);
        ResponseJson.Add('currencyFactor', Helper.FormatDecimal(CurrencyFactor));
        ResponseJson.Add('currencyFactorDate', Helper.FormatDate(CurrencyFactorDate));
        ResponseJson.Add('linesRecalculated', LinesRecalculated);
        ResponseJson.Add('linesSkipped', LinesSkipped);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    local procedure GetContractCurrencyCode(Partner: Enum "Service Partner"; ContractNo: Code[20]): Code[10]
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
    begin
        if Partner = Partner::Vendor then begin
            if not VendorContract.Get(ContractNo) then
                Error(VendorContractNotFoundErr, ContractNo);
            exit(VendorContract."Currency Code");
        end;
        if not CustomerContract.Get(ContractNo) then
            Error(CustomerContractNotFoundErr, ContractNo);
        exit(CustomerContract."Currency Code");
    end;

    /// <summary>
    /// Microsoft: "Subscription Line".UpdateAndRecalculateServCommCurrencyFromContract and UpdateCurrencyDataOnServiceCommitments
    /// (UpdateCurrencyCodeOnServiceCommitment = true). Microsoft calls SetUpdateRequiredOnBillingLines and ArchiveServiceCommitment and
    /// then Modify(false); both are internal and are exactly what the line's OnModify trigger runs, so Modify(true) is used here. That
    /// trigger also refuses a line whose contract line is closed, so such a line is skipped up front.
    /// </summary>
    local procedure RecalculateLines(Partner: Enum "Service Partner"; ContractNo: Code[20]; CurrencyCode: Code[10]; CurrencyFactor: Decimal; CurrencyFactorDate: Date; var LinesRecalculated: Integer; var LinesSkipped: Integer)
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        SubscriptionLine.SetRange(Partner, Partner);
        SubscriptionLine.SetRange("Subscription Contract No.", ContractNo);
        if SubscriptionLine.FindSet(true) then
            repeat
                if IsContractLineClosed(SubscriptionLine) then
                    LinesSkipped += 1
                else begin
                    SubscriptionLine."Currency Factor" := CurrencyFactor;
                    SubscriptionLine."Currency Factor Date" := CurrencyFactorDate;
                    SubscriptionLine."Currency Code" := CurrencyCode;
                    RecalculateAmountsFromCurrencyData(SubscriptionLine);
                    SubscriptionLine.Modify(true);
                    LinesRecalculated += 1;
                end;
            until SubscriptionLine.Next() = 0;
    end;

    /// <summary>Microsoft: internal "Subscription Line".RecalculateAmountsFromCurrencyData, unchanged.</summary>
    local procedure RecalculateAmountsFromCurrencyData(var SubscriptionLine: Record "Subscription Line")
    var
        Currency: Record Currency;
        CurrencyExchangeRate: Record "Currency Exchange Rate";
    begin
        if (SubscriptionLine."Currency Factor" = 0) and (SubscriptionLine."Currency Code" = '') then
            exit;
        Currency.Initialize(SubscriptionLine."Currency Code");
        SubscriptionLine.Validate("Calculation Base Amount",
            Round(CurrencyExchangeRate.ExchangeAmtLCYToFCY(SubscriptionLine."Currency Factor Date", SubscriptionLine."Currency Code", SubscriptionLine."Calculation Base Amount (LCY)", SubscriptionLine."Currency Factor"),
                Currency."Unit-Amount Rounding Precision"));
    end;

    local procedure IsContractLineClosed(SubscriptionLine: Record "Subscription Line"): Boolean
    var
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
    begin
        if SubscriptionLine.Partner = SubscriptionLine.Partner::Vendor then begin
            VendSubContractLine.SetRange("Subscription Contract No.", SubscriptionLine."Subscription Contract No.");
            VendSubContractLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
            VendSubContractLine.SetRange(Closed, true);
            exit(not VendSubContractLine.IsEmpty());
        end;
        CustSubContractLine.SetRange("Subscription Contract No.", SubscriptionLine."Subscription Contract No.");
        CustSubContractLine.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        CustSubContractLine.SetRange(Closed, true);
        exit(not CustSubContractLine.IsEmpty());
    end;
}
