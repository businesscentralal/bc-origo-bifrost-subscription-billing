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
using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Copies of the internal procedures of Microsoft's table 8004 "Sub. Contr. Price Update Line" and
/// of the internal temporary-document builders of codeunit 8055 "Sub. Contracts Item Management"
/// that the price update proposal needs. Microsoft declares the table procedures on the table
/// (operating on Rec); here each takes the price update line as a var parameter instead, and
/// otherwise keeps Microsoft's statements in Microsoft's order. Public Microsoft procedures
/// (CalculateUnitPrice, CalculateUnitCost, CalculateDirectUnitCost, Date Time Management.GetMaxDate)
/// are called, not copied. Each procedure names its source and the change that would let us delete it.
/// </summary>
codeunit 10035081 "Sub PU Line Mgt ori"
{
    Access = Internal;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".InitNewLine (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make InitNewLine public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line to initialise.</param>
    procedure InitNewLine(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line")
    begin
        ContractPriceUpdateLine.Init();
        ContractPriceUpdateLine."Entry No." := 0;
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".UpdateFromServiceCommitment (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UpdateFromServiceCommitment public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line to fill.</param>
    /// <param name="ServiceCommitment">The Subscription Line the line is proposed for.</param>
    procedure UpdateFromServiceCommitment(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"; ServiceCommitment: Record "Subscription Line")
    begin
        ServiceCommitment.CalcFields("Subscription Description", Quantity);
        ContractPriceUpdateLine."Subscription Header No." := ServiceCommitment."Subscription Header No.";
        ContractPriceUpdateLine."Subscription Line Entry No." := ServiceCommitment."Entry No.";
        ContractPriceUpdateLine."Subscription Description" := ServiceCommitment."Subscription Description";
        ContractPriceUpdateLine."Subscription Line Description" := ServiceCommitment.Description;
        ContractPriceUpdateLine.Partner := ServiceCommitment.Partner;
        ContractPriceUpdateLine."Subscription Contract No." := ServiceCommitment."Subscription Contract No.";
        ContractPriceUpdateLine."Old Price" := ServiceCommitment.Price;
        ContractPriceUpdateLine."Old Calculation Base" := ServiceCommitment."Calculation Base Amount";
        ContractPriceUpdateLine."Old Calculation Base %" := ServiceCommitment."Calculation Base %";
        ContractPriceUpdateLine."Old Amount" := ServiceCommitment.Amount;
        ContractPriceUpdateLine."Discount %" := ServiceCommitment."Discount %";
        ContractPriceUpdateLine."Discount Amount" := ServiceCommitment."Discount Amount";
        ContractPriceUpdateLine.Quantity := ServiceCommitment.Quantity;
        ContractPriceUpdateLine."Currency Code" := ServiceCommitment."Currency Code";
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".UpdateFromContract (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UpdateFromContract public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line to fill.</param>
    /// <param name="ServicePartner">Customer or Vendor.</param>
    /// <param name="ContractNo">The contract the Subscription Line belongs to; empty skips the lookup.</param>
    procedure UpdateFromContract(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"; ServicePartner: Enum "Service Partner"; ContractNo: Code[20])
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
    begin
        if ContractNo = '' then
            exit;
        case ServicePartner of
            "Service Partner"::Customer:
                begin
                    CustomerContract.Get(ContractNo);
                    ContractPriceUpdateLine."Sub. Contract Description" := CustomerContract."Description Preview";
                    ContractPriceUpdateLine."Partner No." := CustomerContract."Sell-to Customer No.";
                    ContractPriceUpdateLine."Partner Name" := CustomerContract."Sell-to Customer Name";
                end;
            "Service Partner"::Vendor:
                begin
                    VendorContract.Get(ContractNo);
                    ContractPriceUpdateLine."Sub. Contract Description" := VendorContract."Description Preview";
                    ContractPriceUpdateLine."Partner No." := VendorContract."Pay-to Vendor No.";
                    ContractPriceUpdateLine."Partner Name" := VendorContract."Pay-to Name";
                end;
        end;
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".PriceUpdateLineExists together with
    /// FilterOnServiceCommitment (both internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make PriceUpdateLineExists and FilterOnServiceCommitment public on table 8004.
    /// </summary>
    /// <param name="ServiceCommitment">The Subscription Line to look for.</param>
    /// <returns>True when a price update line already exists for the Subscription Line, under any template.</returns>
    procedure PriceUpdateLineExists(ServiceCommitment: Record "Subscription Line"): Boolean
    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
    begin
        ContractPriceUpdateLine.SetRange("Subscription Line Entry No.", ServiceCommitment."Entry No.");
        exit(not ContractPriceUpdateLine.IsEmpty());
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".CalculateNewPrice (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CalculateNewPrice public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line whose New Calculation Base and New Calculation Base % are already set.</param>
    procedure CalculateNewPrice(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line")
    var
        Currency: Record Currency;
    begin
        Currency.InitRoundingPrecision();
        ContractPriceUpdateLine."New Price" := Round(ContractPriceUpdateLine."New Calculation Base" * ContractPriceUpdateLine."New Calculation Base %" / 100, Currency."Unit-Amount Rounding Precision");
        ContractPriceUpdateLine."New Amount" := Round((ContractPriceUpdateLine."New Price" * ContractPriceUpdateLine.Quantity), Currency."Amount Rounding Precision");
        ContractPriceUpdateLine."Discount Amount" := Round(ContractPriceUpdateLine."Discount %" * ContractPriceUpdateLine."New Amount" / 100, Currency."Amount Rounding Precision");
        ContractPriceUpdateLine."New Amount" := ContractPriceUpdateLine."New Amount" - ContractPriceUpdateLine."Discount Amount";
        ContractPriceUpdateLine."Additional Amount" := ContractPriceUpdateLine."New Amount" - ContractPriceUpdateLine."Old Amount";
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".CalculateNewCalculationBaseAmount (internal),
    /// which reads the current item price (customer), unit cost (vendor, item) or direct unit cost (vendor, G/L
    /// account). The public calculators CalculateUnitPrice, CalculateUnitCost and CalculateDirectUnitCost of
    /// codeunit 8055 "Sub. Contracts Item Management" are called; Subscription Header.IsItem (internal) is inlined.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CalculateNewCalculationBaseAmount public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line whose New Calculation Base is set.</param>
    procedure CalculateNewCalculationBaseAmount(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line")
    var
        ServiceObject: Record "Subscription Header";
        TempPurchaseHeader: Record "Purchase Header" temporary;
        TempPurchaseLine: Record "Purchase Line" temporary;
        TempSalesHeader: Record "Sales Header" temporary;
        TempSalesLine: Record "Sales Line" temporary;
        ContractsItemManagement: Codeunit "Sub. Contracts Item Management";
    begin
        ServiceObject.Get(ContractPriceUpdateLine."Subscription Header No.");
        case ContractPriceUpdateLine.Partner of
            "Service Partner"::Customer:
                begin
                    CreateTempSalesHeader(TempSalesHeader, TempSalesHeader."Document Type"::Order, ServiceObject."End-User Customer No.", ServiceObject."Bill-to Customer No.", ContractPriceUpdateLine."Perform Update On", '');
                    CreateTempSalesLine(TempSalesLine, TempSalesHeader, ServiceObject, ContractPriceUpdateLine."Perform Update On");
                    ContractPriceUpdateLine."New Calculation Base" := ContractsItemManagement.CalculateUnitPrice(TempSalesHeader, TempSalesLine);
                end;
            "Service Partner"::Vendor:
                if ServiceObject.Type = ServiceObject.Type::Item then
                    ContractPriceUpdateLine."New Calculation Base" := ContractsItemManagement.CalculateUnitCost(ServiceObject."Source No.")
                else begin
                    CreateTempPurchaseHeader(TempPurchaseHeader, TempPurchaseHeader."Document Type"::Order, ContractPriceUpdateLine."Partner No.", ContractPriceUpdateLine."Perform Update On", ContractPriceUpdateLine."Currency Code");
                    CreateTempPurchaseLine(TempPurchaseLine, TempPurchaseHeader, ServiceObject, ContractPriceUpdateLine."Perform Update On");
                    ContractPriceUpdateLine."New Calculation Base" := ContractsItemManagement.CalculateDirectUnitCost(TempPurchaseHeader, TempPurchaseLine);
                end;
        end;
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".ShouldContractPriceUpdateLineBeInserted (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make ShouldContractPriceUpdateLineBeInserted public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The calculated price update line.</param>
    /// <returns>True when the New Calculation Base is above zero.</returns>
    procedure ShouldContractPriceUpdateLineBeInserted(ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"): Boolean
    begin
        exit(ContractPriceUpdateLine."New Calculation Base" > 0);
    end;

    /// <summary>
    /// Copy of Microsoft table 8004 "Sub. Contr. Price Update Line".UpdatePerformUpdateOn (internal): the latest of
    /// the Subscription Line's Next Billing Date, its Next Price Update and the requested perform date.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Tables/SubContrPriceUpdateLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UpdatePerformUpdateOn public on table 8004.
    /// </summary>
    /// <param name="ContractPriceUpdateLine">The price update line whose Perform Update On is set.</param>
    /// <param name="ServiceCommitment">The Subscription Line the line is proposed for.</param>
    /// <param name="PerformUpdateOnDate">The perform date requested for the proposal.</param>
    procedure UpdatePerformUpdateOn(var ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line"; ServiceCommitment: Record "Subscription Line"; PerformUpdateOnDate: Date)
    var
        DateTimeManagement: Codeunit "Date Time Management";
        DateList: List of [Date];
    begin
        DateList.Add(ServiceCommitment."Next Billing Date");
        DateList.Add(ServiceCommitment."Next Price Update");
        DateList.Add(PerformUpdateOnDate);
        ContractPriceUpdateLine."Perform Update On" := DateTimeManagement.GetMaxDate(DateList);
    end;

    /// <summary>
    /// Copy of Microsoft codeunit 8055 "Sub. Contracts Item Management".CreateTempSalesHeader (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Base/Codeunits/SubContractsItemManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreateTempSalesHeader public on codeunit 8055.
    /// </summary>
    local procedure CreateTempSalesHeader(var TempSalesHeader: Record "Sales Header" temporary; DocumentType: Enum "Sales Document Type"; SellToCustomerNo: Code[20]; BillToCustomerNo: Code[20]; OrderDate: Date; CurrencyCode: Code[10])
    begin
        TempSalesHeader.SetHideValidationDialog(true);
        TempSalesHeader.Init();
        TempSalesHeader.Validate("Document Type", DocumentType);
        TempSalesHeader.Validate(Status, TempSalesHeader.Status::Open);
        TempSalesHeader.InitRecord();
        if SellToCustomerNo <> '' then
            TempSalesHeader.Validate("Sell-to Customer No.", SellToCustomerNo);
        if BillToCustomerNo <> '' then
            TempSalesHeader.Validate("Bill-to Customer No.", BillToCustomerNo);
        TempSalesHeader.Validate("Currency Code", CurrencyCode);
        TempSalesHeader."Order Date" := OrderDate;
    end;

    /// <summary>
    /// Copy of Microsoft codeunit 8055 "Sub. Contracts Item Management".CreateTempSalesLine (both internal
    /// overloads merged: the Subscription Header overload only passes its own fields to the detailed one).
    /// Source: src/Apps/W1/Subscription Billing/App/Base/Codeunits/SubContractsItemManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreateTempSalesLine public on codeunit 8055.
    /// </summary>
    local procedure CreateTempSalesLine(var TempSalesLine: Record "Sales Line" temporary; var TempSalesHeader: Record "Sales Header" temporary; ServiceObject: Record "Subscription Header"; OrderDate: Date)
    begin
        TempSalesLine.Init();
        TempSalesLine.SetHideValidationDialog(true);
        TempSalesLine.SuspendStatusCheck(true);
        TempSalesLine.Validate("Document Type", TempSalesHeader."Document Type");
        TempSalesLine."Document No." := TempSalesHeader."No.";
        case ServiceObject.Type of
            ServiceObject.Type::Item:
                TempSalesLine.Type := TempSalesLine.Type::Item;
            ServiceObject.Type::"G/L Account":
                TempSalesLine.Type := TempSalesLine.Type::"G/L Account";
        end;
        TempSalesLine."Sell-to Customer No." := TempSalesHeader."Sell-to Customer No.";
        TempSalesLine."Bill-to Customer No." := TempSalesHeader."Bill-to Customer No.";
        TempSalesLine."Customer Price Group" := TempSalesHeader."Customer Price Group";
        TempSalesLine."VAT Bus. Posting Group" := TempSalesHeader."VAT Bus. Posting Group";
        TempSalesLine."No." := ServiceObject."Source No.";
        TempSalesLine.Quantity := ServiceObject.Quantity;
        TempSalesLine."Currency Code" := TempSalesHeader."Currency Code";
        TempSalesLine."Variant Code" := ServiceObject."Variant Code";
        TempSalesLine."Unit of Measure Code" := ServiceObject."Unit of Measure";
        TempSalesLine."Qty. per Unit of Measure" := GetQtyPerUnitOfMeasure(ServiceObject.Type, ServiceObject."Source No.", ServiceObject."Unit of Measure");

        // Microsoft: the field is empty on the temporary line and decides which sales price is picked; without it WorkDate is used.
        if OrderDate <> 0D then
            TempSalesLine."Posting Date" := OrderDate;
    end;

    /// <summary>
    /// Copy of Microsoft codeunit 8055 "Sub. Contracts Item Management".GetQtyPerUnitOfMeasure (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Base/Codeunits/SubContractsItemManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: none of its own; it goes away with CreateTempSalesLine and CreateTempPurchaseLine.
    /// </summary>
    local procedure GetQtyPerUnitOfMeasure(ServiceObjectType: Enum "Service Object Type"; SourceNo: Code[20]; UnitOfMeasureCode: Code[10]): Decimal
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if (ServiceObjectType <> ServiceObjectType::Item) or (UnitOfMeasureCode = '') then
            exit(1);
        if not ItemUnitOfMeasure.Get(SourceNo, UnitOfMeasureCode) then
            exit(1);
        if ItemUnitOfMeasure."Qty. per Unit of Measure" = 0 then
            exit(1);
        exit(ItemUnitOfMeasure."Qty. per Unit of Measure");
    end;

    /// <summary>
    /// Copy of Microsoft codeunit 8055 "Sub. Contracts Item Management".CreateTempPurchaseHeader (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Base/Codeunits/SubContractsItemManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreateTempPurchaseHeader public on codeunit 8055.
    /// </summary>
    local procedure CreateTempPurchaseHeader(var TempPurchaseHeader: Record "Purchase Header" temporary; DocumentType: Enum "Purchase Document Type"; PayToVendorNo: Code[20]; OrderDate: Date; CurrencyCode: Code[10])
    begin
        TempPurchaseHeader.SetHideValidationDialog(true);
        TempPurchaseHeader.Init();
        TempPurchaseHeader.Validate("Document Type", DocumentType);
        TempPurchaseHeader.Validate(Status, TempPurchaseHeader.Status::Open);
        TempPurchaseHeader.InitRecord();
        if PayToVendorNo <> '' then
            TempPurchaseHeader.Validate("Pay-to Vendor No.", PayToVendorNo);
        TempPurchaseHeader.Validate("Currency Code", CurrencyCode);
        TempPurchaseHeader."Order Date" := OrderDate;
    end;

    /// <summary>
    /// Copy of Microsoft codeunit 8055 "Sub. Contracts Item Management".CreateTempPurchaseLine (both internal
    /// overloads merged, as for CreateTempSalesLine).
    /// Source: src/Apps/W1/Subscription Billing/App/Base/Codeunits/SubContractsItemManagement.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreateTempPurchaseLine public on codeunit 8055.
    /// </summary>
    local procedure CreateTempPurchaseLine(var TempPurchaseLine: Record "Purchase Line" temporary; var TempPurchaseHeader: Record "Purchase Header" temporary; ServiceObject: Record "Subscription Header"; OrderDate: Date)
    begin
        TempPurchaseLine.Init();
        TempPurchaseLine.SuspendStatusCheck(true);
        TempPurchaseLine.Validate("Document Type", TempPurchaseHeader."Document Type");
        TempPurchaseLine."Document No." := TempPurchaseHeader."No.";
        case ServiceObject.Type of
            ServiceObject.Type::Item:
                TempPurchaseLine.Type := TempPurchaseLine.Type::Item;
            ServiceObject.Type::"G/L Account":
                TempPurchaseLine.Type := TempPurchaseLine.Type::"G/L Account";
        end;
        TempPurchaseLine."Pay-to Vendor No." := TempPurchaseHeader."Pay-to Vendor No.";
        TempPurchaseLine."Buy-from Vendor No." := TempPurchaseHeader."Buy-from Vendor No.";
        TempPurchaseLine."VAT Bus. Posting Group" := TempPurchaseHeader."VAT Bus. Posting Group";
        TempPurchaseLine."No." := ServiceObject."Source No.";
        TempPurchaseLine.Quantity := ServiceObject.Quantity;
        TempPurchaseLine."Currency Code" := TempPurchaseHeader."Currency Code";
        TempPurchaseLine."Variant Code" := ServiceObject."Variant Code";
        TempPurchaseLine."Unit of Measure Code" := ServiceObject."Unit of Measure";
        TempPurchaseLine."Qty. per Unit of Measure" := GetQtyPerUnitOfMeasure(ServiceObject.Type, ServiceObject."Source No.", ServiceObject."Unit of Measure");
        if OrderDate <> 0D then
            TempPurchaseLine."Expected Receipt Date" := OrderDate;
    end;
}
