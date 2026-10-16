// ------------------------------------------------------------------------------------------------
// Portions of this file are copied from Microsoft BCApps, src/Apps/W1/Subscription Billing/App,
// https://github.com/microsoft/BCApps, branch releases/28.x, commit a674a13 (app 28.7.0.0), and
// adapted (names, namespace, object ids) for Bifrost Subscription Billing. See
// docs/microsoft-dependencies.md for every copied procedure and the Microsoft change that would
// let us delete the copy. The copied code is used under the MIT License:
//
// MIT License
//
// Copyright (c) Microsoft Corporation.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ------------------------------------------------------------------------------------------------
namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Copy of the internal procedures of Microsoft codeunit 8009 "Price Update Management" that create and
/// perform a contract price update proposal: CreatePriceUpdateProposal, TestIncludeServiceCommitmentUpToDate,
/// GetAndApplyFiltersOnServiceCommitment with its local helpers, and PerformPriceUpdate. The codeunit itself
/// is public in Microsoft's app, but every one of these procedures is internal. The page-only procedures
/// (InitTempTable, DeleteProposal with its StrMenu) are not copied.
/// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
/// microsoft/BCApps releases/28.x, commit a674a13.
/// Change requested from Microsoft: make CreatePriceUpdateProposal and PerformPriceUpdate public on codeunit 8009,
/// with PerformPriceUpdate taking the price update lines to process as a var record so a caller can filter it.
/// Then Sub PU CrProposal Impl ori and Sub PU Perform Impl ori call them and this codeunit, the interface copy and
/// the five other copied codeunits are deleted.
/// </summary>
codeunit 10035076 "Sub PU Price Update Mgt ori"
{
    Access = Internal;

    var
        NotInsertedLineCount: Integer;
        PriceUpdateProposalCannotBeCreateWithoutTemplateErr: Label 'Price Update Proposals cannot be created without a Price Update Template. Please select a template before.', Comment = 'is-IS=Ekki er hægt að stofna tillögur að verðuppfærslu án sniðmáts fyrir verðuppfærslu. Veldu sniðmát fyrst.';
        NoIncludeContractLinesUpToDateErr: Label 'Please enter the Include Contract Lines up to Date.', Comment = 'is-IS=Færðu inn dagsetninguna sem samningslínur eru teknar með til.';
        UnknownPriceUpdateMethodErr: Label 'The Price Update Method of Price Update Template ''%1'' is not one this app knows. Update Bifrost Subscription Billing.', Comment = '%1 = price update template code||is-IS=Aðferð verðuppfærslu á sniðmáti fyrir verðuppfærslu ''%1'' er ekki þekkt í þessu forriti. Uppfærðu Bifröst Subscription Billing.';

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".CreatePriceUpdateProposal (internal). Microsoft resolves the
    /// method through the interface its enum 8003 "Price Update Method" implements; that interface is internal, so
    /// the enum value is mapped to the copied implementations here.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreatePriceUpdateProposal public on codeunit 8009.
    /// </summary>
    /// <param name="PriceUpdateTemplateCode">The Price Update Template to run.</param>
    /// <param name="IncludeServiceCommitmentUpToDate">Subscription Lines whose Next Price Update is on or before this date, or empty, are included.</param>
    /// <param name="PerformUpdateOnDate">The date the price update is to take effect.</param>
    procedure CreatePriceUpdateProposal(PriceUpdateTemplateCode: Code[20]; IncludeServiceCommitmentUpToDate: Date; PerformUpdateOnDate: Date)
    var
        PriceUpdateTemplate: Record "Price Update Template";
        ContractPriceUpdate: Interface "Sub PU Contract Price Upd ori";
    begin
        if PriceUpdateTemplateCode = '' then
            Error(PriceUpdateProposalCannotBeCreateWithoutTemplateErr);

        PriceUpdateTemplate.Get(PriceUpdateTemplateCode);
        ContractPriceUpdate := GetPriceUpdateMethod(PriceUpdateTemplate);
        ContractPriceUpdate.SetPriceUpdateParameters(PriceUpdateTemplate, IncludeServiceCommitmentUpToDate, PerformUpdateOnDate);
        ContractPriceUpdate.ApplyFilterOnServiceCommitments();
        ContractPriceUpdate.CreatePriceUpdateProposal();
        NotInsertedLineCount := ContractPriceUpdate.GetNotInsertedLineCount();
    end;

    /// <summary>
    /// Origo addition: the number of lines the last CreatePriceUpdateProposal did not insert because their new
    /// calculation base was not above zero. Microsoft shows a notification for this instead.
    /// </summary>
    /// <returns>The number of lines that were not inserted.</returns>
    procedure GetNotInsertedLineCount(): Integer
    begin
        exit(NotInsertedLineCount);
    end;

    /// <summary>
    /// Replaces the enum-to-interface resolution of enum 8003 "Price Update Method" (Implementation =
    /// "Contract Price Update" = codeunit 8010, 8011 or 8012), which this app cannot use because the interface
    /// is internal. The enum is not extensible, so the three values are all there is.
    /// Change requested from Microsoft: make interface "Contract Price Update" public.
    /// </summary>
    local procedure GetPriceUpdateMethod(PriceUpdateTemplate: Record "Price Update Template") ContractPriceUpdate: Interface "Sub PU Contract Price Upd ori"
    var
        CalcBaseByPerc: Codeunit "Sub PU Calc Base By Perc ori";
        PriceByPercent: Codeunit "Sub PU Price By Percent ori";
        RecentItemPrice: Codeunit "Sub PU Recent Item Price ori";
    begin
        case PriceUpdateTemplate."Price Update Method" of
            PriceUpdateTemplate."Price Update Method"::"Calculation Base by %":
                ContractPriceUpdate := CalcBaseByPerc;
            PriceUpdateTemplate."Price Update Method"::"Price by %":
                ContractPriceUpdate := PriceByPercent;
            PriceUpdateTemplate."Price Update Method"::"Recent Item Prices":
                ContractPriceUpdate := RecentItemPrice;
            else
                Error(UnknownPriceUpdateMethodErr, PriceUpdateTemplate.Code);
        end;
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".TestIncludeServiceCommitmentUpToDate (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make TestIncludeServiceCommitmentUpToDate public on codeunit 8009.
    /// </summary>
    /// <param name="IncludeServiceCommitmentUpToDate">The include-up-to date, which must not be empty.</param>
    procedure TestIncludeServiceCommitmentUpToDate(IncludeServiceCommitmentUpToDate: Date)
    begin
        if IncludeServiceCommitmentUpToDate = 0D then
            Error(NoIncludeContractLinesUpToDateErr);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".GetAndApplyFiltersOnServiceCommitment (internal): the default
    /// filters plus the template's line, subscription and contract filters, intersected through marks. Microsoft's
    /// internal Price Update Template.ReadFilter is copied as ReadFilter below.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make GetAndApplyFiltersOnServiceCommitment public on codeunit 8009, and
    /// ReadFilter public on table 8003. Difference: the internal event
    /// OnAfterFilterSubscriptionLineOnAfterGetAndApplyFiltersOnSubscriptionLine is not raised.
    /// </summary>
    /// <param name="ServiceCommitment">Receives the filtered and marked Subscription Lines.</param>
    /// <param name="PriceUpdateTemplate">The template whose filters apply.</param>
    /// <param name="IncludeServiceCommitmentUpToDate">The include-up-to date.</param>
    procedure GetAndApplyFiltersOnServiceCommitment(var ServiceCommitment: Record "Subscription Line"; PriceUpdateTemplate: Record "Price Update Template"; IncludeServiceCommitmentUpToDate: Date)
    var
        TempServiceCommitment: Record "Subscription Line" temporary;
        ServiceObjectFilterText: Text;
        ServiceCommitmentFilterText: Text;
        ContractFilterText: Text;
    begin
        ApplyDefaultFiltering(ServiceCommitment, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
        InitTempServiceCommitmentTable(ServiceCommitment, TempServiceCommitment);

        if PriceUpdateTemplate."Subscription Contract Filter".HasValue() then
            ContractFilterText := ReadFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"));
        if PriceUpdateTemplate."Subscription Filter".HasValue() then
            ServiceObjectFilterText := ReadFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Filter"));
        if PriceUpdateTemplate."Subscription Line Filter".HasValue() then
            ServiceCommitmentFilterText := ReadFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Line Filter"));

        if ServiceCommitmentFilterText <> '' then begin
            // The view is stored on the Price Update Template by Subscription.PriceUpdate.SetTemplateFilter (Foundation ApplyTableView) or Microsoft's FilterPageBuilder; Microsoft applies it the same way.
            // tableView validated by the caller
            ServiceCommitment.SetView(ServiceCommitmentFilterText);
            ApplyDefaultFiltering(ServiceCommitment, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
            FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment(ServiceCommitment, TempServiceCommitment);
        end;
        if ServiceObjectFilterText <> '' then begin
            FilterAndMarkServiceCommitmentOnServiceObject(ServiceCommitment, ServiceObjectFilterText, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
            FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment(ServiceCommitment, TempServiceCommitment);
        end;
        if ContractFilterText <> '' then begin
            FilterAndMarkServiceCommitmentOnContract(ServiceCommitment, ContractFilterText, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
            FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment(ServiceCommitment, TempServiceCommitment);
        end;

        MarkServiceCommitmentsFromTempTable(ServiceCommitment, TempServiceCommitment);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".ApplyDefaultFiltering (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure ApplyDefaultFiltering(var ServiceCommitment: Record "Subscription Line"; PriceUpdateTemplate: Record "Price Update Template"; IncludeServiceCommitmentUpToDate: Date)
    begin
        ServiceCommitment.SetRange(Partner, PriceUpdateTemplate.Partner);
        ServiceCommitment.SetRange("Exclude from Price Update", false);
        ServiceCommitment.SetRange("Invoicing via", Enum::"Invoicing Via"::Contract);
        ServiceCommitment.SetFilter("Next Price Update", '<=%1|%2', IncludeServiceCommitmentUpToDate, 0D);
        ServiceCommitment.SetRange("Planned Sub. Line exists", false);
        ServiceCommitment.SetRange("Usage Based Billing", false);
        ServiceCommitment.SetRange(Closed, false);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".InitTempServiceCommitmentTable (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure InitTempServiceCommitmentTable(ServiceCommitment: Record "Subscription Line"; var TempServiceCommitment: Record "Subscription Line" temporary)
    begin
        TempServiceCommitment.Reset();
        TempServiceCommitment.DeleteAll(false);
        if ServiceCommitment.FindSet() then
            repeat
                if not ServiceCommitment.Closed then begin
                    TempServiceCommitment := ServiceCommitment;
                    TempServiceCommitment.Insert(false);
                end;
            until ServiceCommitment.Next() = 0;
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure FindAndMarkMatchedAndDeleteUnmarkedServiceCommitment(var ServiceCommitment: Record "Subscription Line"; var TempServiceCommitment: Record "Subscription Line" temporary)
    begin
        if ServiceCommitment.FindSet() then
            repeat
                if TempServiceCommitment.Get(ServiceCommitment."Entry No.") then
                    TempServiceCommitment.Mark(true);
            until ServiceCommitment.Next() = 0;
        DeleteUnmarkedTempServiceCommitment(TempServiceCommitment);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".DeleteUnmarkedTempServiceCommitment (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure DeleteUnmarkedTempServiceCommitment(var TempServiceCommitment: Record "Subscription Line" temporary)
    begin
        if TempServiceCommitment.FindSet() then
            repeat
                if not TempServiceCommitment.Mark() then
                    TempServiceCommitment.Delete(false);
            until TempServiceCommitment.Next() = 0;
        TempServiceCommitment.Reset();
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".FilterAndMarkServiceCommitmentOnServiceObject (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure FilterAndMarkServiceCommitmentOnServiceObject(var ServiceCommitment: Record "Subscription Line"; ServiceObjectFilterText: Text; PriceUpdateTemplate: Record "Price Update Template"; IncludeServiceCommitmentUpToDate: Date)
    var
        ServiceObject: Record "Subscription Header";
    begin
        ServiceCommitment.Reset();
        // The view is stored on the Price Update Template by Subscription.PriceUpdate.SetTemplateFilter (Foundation ApplyTableView) or Microsoft's FilterPageBuilder; Microsoft applies it the same way.
        // tableView validated by the caller
        ServiceObject.SetView(ServiceObjectFilterText);
        ServiceObject.SetLoadFields("No.");
        if ServiceObject.FindSet() then
            repeat
                ServiceCommitment.SetRange("Subscription Header No.", ServiceObject."No.");
                ApplyDefaultFiltering(ServiceCommitment, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
                if ServiceCommitment.FindSet() then
                    repeat
                        ServiceCommitment.Mark(true);
                    until ServiceCommitment.Next() = 0;
            until ServiceObject.Next() = 0;
        ServiceCommitment.SetRange("Subscription Header No.");
        ServiceCommitment.MarkedOnly(true);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".FilterAndMarkServiceCommitmentOnContract (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure FilterAndMarkServiceCommitmentOnContract(var ServiceCommitment: Record "Subscription Line"; ContractFilterText: Text; PriceUpdateTemplate: Record "Price Update Template"; IncludeServiceCommitmentUpToDate: Date)
    var
        VendorContract: Record "Vendor Subscription Contract";
        CustomerContract: Record "Customer Subscription Contract";
    begin
        ServiceCommitment.Reset();
        case PriceUpdateTemplate.Partner of
            "Service Partner"::Customer:
                begin
                    // The view is stored on the Price Update Template by Subscription.PriceUpdate.SetTemplateFilter (Foundation ApplyTableView) or Microsoft's FilterPageBuilder; Microsoft applies it the same way.
                    // tableView validated by the caller
                    CustomerContract.SetView(ContractFilterText);
                    if CustomerContract.FindSet() then
                        repeat
                            ApplyContractFilterAndMarkServiceCommitment(ServiceCommitment, CustomerContract."No.", PriceUpdateTemplate, IncludeServiceCommitmentUpToDate)
                        until CustomerContract.Next() = 0;
                end;
            "Service Partner"::Vendor:
                begin
                    // The view is stored on the Price Update Template by Subscription.PriceUpdate.SetTemplateFilter (Foundation ApplyTableView) or Microsoft's FilterPageBuilder; Microsoft applies it the same way.
                    // tableView validated by the caller
                    VendorContract.SetView(ContractFilterText);
                    if VendorContract.FindSet() then
                        repeat
                            ApplyContractFilterAndMarkServiceCommitment(ServiceCommitment, VendorContract."No.", PriceUpdateTemplate, IncludeServiceCommitmentUpToDate)
                        until VendorContract.Next() = 0;
                end;
        end;
        ServiceCommitment.SetRange(Partner);
        ServiceCommitment.SetRange("Subscription Contract No.");
        ServiceCommitment.MarkedOnly(true);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".ApplyContractFilterAndMarkServiceCommitment (local), with
    /// Microsoft's internal Subscription Line.FilterOnContract inlined (SetRange on Partner and contract).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al
    /// and Service Commitments/Tables/SubscriptionLine.Table.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure ApplyContractFilterAndMarkServiceCommitment(var ServiceCommitment: Record "Subscription Line"; ContractNo: Code[20]; PriceUpdateTemplate: Record "Price Update Template"; IncludeServiceCommitmentUpToDate: Date)
    begin
        ServiceCommitment.SetRange(Partner, PriceUpdateTemplate.Partner);
        ServiceCommitment.SetRange("Subscription Contract No.", ContractNo);
        ApplyDefaultFiltering(ServiceCommitment, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
        if ServiceCommitment.FindSet() then
            repeat
                ServiceCommitment.Mark(true);
            until ServiceCommitment.Next() = 0;
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".MarkServiceCommitmentsFromTempTable (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes with GetAndApplyFiltersOnServiceCommitment.
    /// </summary>
    local procedure MarkServiceCommitmentsFromTempTable(var ServiceCommitment: Record "Subscription Line"; var TempServiceCommitment: Record "Subscription Line" temporary)
    begin
        ServiceCommitment.Reset();
        if TempServiceCommitment.FindSet() then
            repeat
                ServiceCommitment.Get(TempServiceCommitment."Entry No.");
                ServiceCommitment.Mark(true);
            until TempServiceCommitment.Next() = 0;
        ServiceCommitment.MarkedOnly(true);
    end;

    /// <summary>
    /// Copy of table 8003 "Price Update Template".ReadFilter (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/PriceUpdateTemplate.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make ReadFilter public on table 8003.
    /// </summary>
    local procedure ReadFilter(var PriceUpdateTemplate: Record "Price Update Template"; FieldNumber: Integer) FilterText: Text
    var
        IStream: InStream;
    begin
        case FieldNumber of
            PriceUpdateTemplate.FieldNo("Subscription Contract Filter"):
                begin
                    PriceUpdateTemplate.CalcFields("Subscription Contract Filter");
                    PriceUpdateTemplate."Subscription Contract Filter".CreateInStream(IStream, TextEncoding::UTF8);
                end;
            PriceUpdateTemplate.FieldNo("Subscription Filter"):
                begin
                    PriceUpdateTemplate.CalcFields("Subscription Filter");
                    PriceUpdateTemplate."Subscription Filter".CreateInStream(IStream, TextEncoding::UTF8);
                end;
            PriceUpdateTemplate.FieldNo("Subscription Line Filter"):
                begin
                    PriceUpdateTemplate.CalcFields("Subscription Line Filter");
                    PriceUpdateTemplate."Subscription Line Filter".CreateInStream(IStream, TextEncoding::UTF8);
                end;
        end;
        IStream.ReadText(FilterText);
    end;

    /// <summary>
    /// Copy of codeunit 8009 "Price Update Management".PerformPriceUpdate (internal): every price update line in
    /// the set is processed in its own transaction through Sub PU Process Price Upd ori (the copy of codeunit 8013
    /// "Process Price Update") and deleted when that succeeds; a line that fails is left in place. Microsoft runs
    /// over every line of the table; the caller passes the set here (unfiltered for Microsoft's behaviour), and
    /// each line's outcome is collected for the response.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceUpdateManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make PerformPriceUpdate public on codeunit 8009, taking the lines as a var
    /// record parameter, and make codeunit 8013 public (or report its outcome through an integration event).
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update lines to perform, filtered by the caller.</param>
    /// <param name="WithCommit">True for Microsoft's behaviour: commit before each line and keep a failed line. False runs every line inside the caller's transaction, so the first failure stops the run and rolls everything back.</param>
    /// <param name="Results">Receives one entry per processed line: entryNo, subscriptionLineEntryNo, outcome and error.</param>
    procedure PerformPriceUpdate(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"; WithCommit: Boolean; var Results: JsonArray)
    var
        ProcessPriceUpdate: Codeunit "Sub PU Process Price Upd ori";
        ResultJson: JsonObject;
    begin
        if ContractPriceUpdateLine.FindSet() then
            repeat
                Clear(ProcessPriceUpdate);
                Clear(ResultJson);
                ResultJson.Add('entryNo', ContractPriceUpdateLine."Entry No.");
                ResultJson.Add('subscriptionLineEntryNo', ContractPriceUpdateLine."Subscription Line Entry No.");
                if WithCommit then begin
                    Commit(); // Microsoft: Commit before if Codeunit.Run
                    if ProcessPriceUpdate.Run(ContractPriceUpdateLine) then begin
                        ContractPriceUpdateLine.Delete(false);
                        ResultJson.Add('outcome', ProcessPriceUpdate.GetOutcome());
                    end else begin
                        ResultJson.Add('outcome', 'Failed');
                        ResultJson.Add('error', GetLastErrorText());
                    end;
                end else begin
                    ProcessPriceUpdate.Run(ContractPriceUpdateLine);
                    ContractPriceUpdateLine.Delete(false);
                    ResultJson.Add('outcome', ProcessPriceUpdate.GetOutcome());
                end;
                Results.Add(ResultJson);
            until ContractPriceUpdateLine.Next() = 0;
    end;
}
