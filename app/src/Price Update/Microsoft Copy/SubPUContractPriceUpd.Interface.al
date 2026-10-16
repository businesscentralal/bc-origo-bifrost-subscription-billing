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
/// Copy of Microsoft's interface "Contract Price Update" (Access = Internal), which enum 8003
/// "Price Update Method" implements with codeunits 8010, 8011 and 8012. Because the Microsoft
/// interface is internal its implementations cannot be reached through the enum from this app, so
/// the three implementations are copied as "Sub PU Calc Base By Perc ori", "Sub PU Recent Item Price ori"
/// and "Sub PU Price By Percent ori", and "Sub PU Price Update Mgt ori" maps the enum value to them.
/// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Interfaces/ContractPriceUpdate.Interface.al,
/// microsoft/BCApps releases/28.x, commit a674a13.
/// Change requested from Microsoft: make interface "Contract Price Update" public (Access = Public) and its
/// methods public on codeunits 8010, 8011 and 8012, or make Price Update Management.CreatePriceUpdateProposal
/// public, which would retire this interface and all three copies.
/// One method is an Origo addition: GetNotInsertedLineCount replaces Microsoft's
/// ShowContractPriceUpdateLineNotInsertedNotification, which sends a client notification an unattended
/// caller never sees.
/// </summary>
interface "Sub PU Contract Price Upd ori"
{
    /// <summary>
    /// Copy of "Contract Price Update".SetPriceUpdateParameters: sets the template and the two dates of the run.
    /// </summary>
    /// <param name="PriceUpdateTemplate">Price Update Template by which the update is executed.</param>
    /// <param name="IncludeContractLinesUpToDate">Subscription Lines whose Next Price Update is on or before this date are included.</param>
    /// <param name="PerformUpdateOnDate">The date the price update is to take effect.</param>
    procedure SetPriceUpdateParameters(PriceUpdateTemplate: Record "Price Update Template"; IncludeContractLinesUpToDate: Date; PerformUpdateOnDate: Date)

    /// <summary>
    /// Copy of "Contract Price Update".ApplyFilterOnServiceCommitments: filters the Subscription Lines to process.
    /// </summary>
    procedure ApplyFilterOnServiceCommitments()

    /// <summary>
    /// Copy of "Contract Price Update".CreatePriceUpdateProposal: inserts the price update lines.
    /// </summary>
    procedure CreatePriceUpdateProposal()

    /// <summary>
    /// Copy of "Contract Price Update".CalculateNewPrice: calculates the new price of one line.
    /// </summary>
    /// <param name="UpdatePercentValue">The template's Update Value %.</param>
    /// <param name="NewContractPriceUpdateLine">The line on which the new price is calculated.</param>
    procedure CalculateNewPrice(UpdatePercentValue: Decimal; var NewContractPriceUpdateLine: Record "Sub. Contr. Price Update Line")

    /// <summary>
    /// Origo addition: the number of proposal lines CreatePriceUpdateProposal did not insert because the new
    /// calculation base would be zero or negative. Microsoft reports this only as a notification.
    /// </summary>
    /// <returns>The number of lines that were not inserted.</returns>
    procedure GetNotInsertedLineCount(): Integer
}
