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

using Microsoft.Finance.Currency;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Copy of Microsoft codeunit 8012 "Price By Percent", the "Price by %" price update method:
/// the old calculation base and the old price both rise by the template's Update Value %, the calculation base % stays.
/// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceByPercent.Codeunit.al,
/// microsoft/BCApps releases/28.x, commit a674a13.
/// Change requested from Microsoft: make the methods of codeunit 8012 and interface "Contract Price Update"
/// public, or make Price Update Management.CreatePriceUpdateProposal public.
/// Differences from Microsoft: the internal event OnAfterCalculateNewPriceForSubscriptionLine cannot be raised
/// from this app, and the "line not created" notification is counted instead (GetNotInsertedLineCount).
/// </summary>
codeunit 10035078 "Sub PU Price By Percent ori" implements "Sub PU Contract Price Upd ori"
{
    Access = Internal;

    var
        PriceUpdateTemplate: Record "Price Update Template";
        ServiceCommitment: Record "Subscription Line";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        PriceUpdateManagement: Codeunit "Sub PU Price Update Mgt ori";
        LineMgt: Codeunit "Sub PU Line Mgt ori";
        IncludeServiceCommitmentUpToDate: Date;
        PerformUpdateOnDate: Date;
        NotInsertedLineCount: Integer;

    /// <summary>
    /// Copy of codeunit 8012 "Price By Percent".SetPriceUpdateParameters (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceByPercent.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make SetPriceUpdateParameters public on codeunit 8012.
    /// </summary>
    /// <param name="NewPriceUpdateTemplate">The template of the run.</param>
    /// <param name="NewIncludeServiceCommitmentUpToDate">Include Subscription Lines up to this date.</param>
    /// <param name="NewPerformUpdateOnDate">The requested perform date.</param>
    procedure SetPriceUpdateParameters(NewPriceUpdateTemplate: Record "Price Update Template"; NewIncludeServiceCommitmentUpToDate: Date; NewPerformUpdateOnDate: Date)
    begin
        PriceUpdateTemplate := NewPriceUpdateTemplate;
        IncludeServiceCommitmentUpToDate := NewIncludeServiceCommitmentUpToDate;
        PerformUpdateOnDate := NewPerformUpdateOnDate;
    end;

    /// <summary>
    /// Copy of codeunit 8012 "Price By Percent".ApplyFilterOnServiceCommitments (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceByPercent.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make ApplyFilterOnServiceCommitments public on codeunit 8012.
    /// </summary>
    procedure ApplyFilterOnServiceCommitments()
    begin
        PriceUpdateManagement.TestIncludeServiceCommitmentUpToDate(IncludeServiceCommitmentUpToDate);
        PriceUpdateManagement.GetAndApplyFiltersOnServiceCommitment(ServiceCommitment, PriceUpdateTemplate, IncludeServiceCommitmentUpToDate);
    end;

    /// <summary>
    /// Copy of codeunit 8012 "Price By Percent".CreatePriceUpdateProposal (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceByPercent.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreatePriceUpdateProposal public on codeunit 8012.
    /// </summary>
    procedure CreatePriceUpdateProposal()
    begin
        if ServiceCommitment.FindSet() then
            repeat
                if not LineMgt.PriceUpdateLineExists(ServiceCommitment) then begin
                    LineMgt.InitNewLine(ContractPriceUpdateLine);
                    ContractPriceUpdateLine."Price Update Template Code" := PriceUpdateTemplate.Code;
                    LineMgt.UpdatePerformUpdateOn(ContractPriceUpdateLine, ServiceCommitment, PerformUpdateOnDate);
                    LineMgt.UpdateFromServiceCommitment(ContractPriceUpdateLine, ServiceCommitment);
                    LineMgt.UpdateFromContract(ContractPriceUpdateLine, ServiceCommitment.Partner, ServiceCommitment."Subscription Contract No.");
                    CalculateNewPrice(PriceUpdateTemplate."Update Value %", ContractPriceUpdateLine);
                    ContractPriceUpdateLine."Next Price Update" := CalcDate(PriceUpdateTemplate."Price Binding Period", ContractPriceUpdateLine."Perform Update On");
                    if LineMgt.ShouldContractPriceUpdateLineBeInserted(ContractPriceUpdateLine) then
                        ContractPriceUpdateLine.Insert(false)
                    else
                        NotInsertedLineCount += 1;
                end;
            until ServiceCommitment.Next() = 0;
    end;

    /// <summary>
    /// Copy of codeunit 8012 "Price By Percent".CalculateNewPrice (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/PriceByPercent.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CalculateNewPrice public on codeunit 8012.
    /// </summary>
    /// <param name="UpdatePercentValue">The template's Update Value %, added to the old calculation base and the old price.</param>
    /// <param name="NewContractPriceUpdateLine">The line on which the new price is calculated.</param>
    procedure CalculateNewPrice(UpdatePercentValue: Decimal; var NewContractPriceUpdateLine: Record "Sub. Contr. Price Update Line")
    var
        Currency: Record Currency;
    begin
        Currency.InitRoundingPrecision();
        NewContractPriceUpdateLine."New Calculation Base" := Round(NewContractPriceUpdateLine."Old Calculation Base" + NewContractPriceUpdateLine."Old Calculation Base" * UpdatePercentValue / 100, Currency."Amount Rounding Precision");
        NewContractPriceUpdateLine."New Price" := Round(NewContractPriceUpdateLine."Old Price" + NewContractPriceUpdateLine."Old Price" * UpdatePercentValue / 100, Currency."Unit-Amount Rounding Precision");
        NewContractPriceUpdateLine."New Amount" := Round(NewContractPriceUpdateLine."New Price" * NewContractPriceUpdateLine.Quantity, Currency."Amount Rounding Precision");
        NewContractPriceUpdateLine."New Calculation Base %" := NewContractPriceUpdateLine."Old Calculation Base %";
        NewContractPriceUpdateLine."Discount Amount" := Round(NewContractPriceUpdateLine."Discount %" * NewContractPriceUpdateLine."New Amount" / 100, Currency."Amount Rounding Precision");
        NewContractPriceUpdateLine."New Amount" := NewContractPriceUpdateLine."New Amount" - NewContractPriceUpdateLine."Discount Amount";
        NewContractPriceUpdateLine."Additional Amount" := NewContractPriceUpdateLine."New Amount" - NewContractPriceUpdateLine."Old Amount";
    end;

    /// <summary>Origo addition: lines not inserted because the new calculation base was not above zero.</summary>
    /// <returns>The number of lines that were not inserted.</returns>
    procedure GetNotInsertedLineCount(): Integer
    begin
        exit(NotInsertedLineCount);
    end;
}
