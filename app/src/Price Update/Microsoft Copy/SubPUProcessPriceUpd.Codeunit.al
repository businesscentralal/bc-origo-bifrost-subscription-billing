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
/// Copy of Microsoft codeunit 8013 "Process Price Update" (Access = Internal), which applies one price
/// update line: it either writes a Planned Subscription Line (when the change cannot take effect yet) or
/// updates the Subscription Line and archives its previous state. The internal Subscription Line procedures
/// it calls (UpdateServiceCommitmentFromContractPriceUpdateLine, CreateServiceCommitmentArchive,
/// UnpostedDocumentExists) and Subscription Line Archive.CopyFromServiceCommitment are copied here too.
/// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/ProcessPriceUpdate.Codeunit.al,
/// microsoft/BCApps releases/28.x, commit a674a13.
/// Change requested from Microsoft: make codeunit 8013 public, or make
/// Subscription Line.UpdateServiceCommitmentFromContractPriceUpdateLine public.
/// The outcome of the run (GetOutcome) is an Origo addition so the response can say what happened.
/// </summary>
codeunit 10035080 "Sub PU Process Price Upd ori"
{
    Access = Internal;
    TableNo = "Sub. Contr. Price Update Line";

    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
        Outcome: Text;

    trigger OnRun()
    begin
        ContractPriceUpdateLine.Copy(Rec);
        UpdateServiceCommitmentPrices();
        Rec := ContractPriceUpdateLine;
    end;

    /// <summary>
    /// Origo addition: what the last run did to the Subscription Line: Updated (prices changed now),
    /// Planned (a Planned Subscription Line was written) or SkippedPlannedExists (Microsoft leaves the line
    /// alone because a Planned Subscription Line already exists).
    /// </summary>
    /// <returns>Updated, Planned or SkippedPlannedExists.</returns>
    procedure GetOutcome(): Text
    begin
        exit(Outcome);
    end;

    /// <summary>
    /// Copy of codeunit 8013 "Process Price Update".UpdateServiceCommitmentPrices (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/ProcessPriceUpdate.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make codeunit 8013 public.
    /// </summary>
    local procedure UpdateServiceCommitmentPrices()
    var
        ServiceCommitment: Record "Subscription Line";
    begin
        ServiceCommitment.Get(ContractPriceUpdateLine."Subscription Line Entry No.");
        ServiceCommitment.CalcFields("Planned Sub. Line exists");
        if ServiceCommitment."Planned Sub. Line exists" then begin
            Outcome := 'SkippedPlannedExists';
            exit;
        end;
        if ShouldPlannedServiceCommitmentBeCreated(ServiceCommitment) then begin
            CreatePlannedServiceCommitment(ServiceCommitment);
            Outcome := 'Planned';
        end else begin
            UpdateServiceCommitmentFromContractPriceUpdateLine(ServiceCommitment, ContractPriceUpdateLine);
            Outcome := 'Updated';
        end;
    end;

    /// <summary>
    /// Copy of codeunit 8013 "Process Price Update".CreatePlannedServiceCommitment (local).
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/ProcessPriceUpdate.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make codeunit 8013 public.
    /// </summary>
    local procedure CreatePlannedServiceCommitment(ServiceCommitment: Record "Subscription Line")
    var
        PlannedServiceCommitment: Record "Planned Subscription Line";
        PriceUpdateTemplate: Record "Price Update Template";
    begin
        PlannedServiceCommitment.TransferFields(ServiceCommitment);
        PlannedServiceCommitment.Validate("Calculation Base %", ContractPriceUpdateLine."New Calculation Base %");
        PlannedServiceCommitment.Validate("Calculation Base Amount", ContractPriceUpdateLine."New Calculation Base");
        PlannedServiceCommitment.Validate(Price, ContractPriceUpdateLine."New Price");
        PlannedServiceCommitment.Validate(Amount, ContractPriceUpdateLine."New Amount");
        PlannedServiceCommitment.Validate("Discount %", ContractPriceUpdateLine."Discount %");
        PlannedServiceCommitment.Validate("Discount Amount", ContractPriceUpdateLine."Discount Amount");
        PlannedServiceCommitment."Next Price Update" := ContractPriceUpdateLine."Next Price Update";
        PlannedServiceCommitment."Type Of Update" := Enum::"Type Of Price Update"::"Price Update";
        PlannedServiceCommitment."Perform Update On" := ContractPriceUpdateLine."Perform Update On";
        if PriceUpdateTemplate.Get(ContractPriceUpdateLine."Price Update Template Code") then
            PlannedServiceCommitment."Price Binding Period" := PriceUpdateTemplate."Price Binding Period";
        PlannedServiceCommitment.Insert(false);
    end;

    /// <summary>
    /// Copy of codeunit 8013 "Process Price Update".ShouldPlannedServiceCommitmentBeCreated (local), with
    /// Subscription Line.UnpostedDocumentExists (internal) copied as UnpostedDocumentExists below.
    /// Source: src/Apps/W1/Subscription Billing/App/Contract Price Update/Codeunits/ProcessPriceUpdate.Codeunit.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make codeunit 8013 public.
    /// </summary>
    local procedure ShouldPlannedServiceCommitmentBeCreated(ServiceCommitment: Record "Subscription Line"): Boolean
    begin
        if ContractPriceUpdateLine."Perform Update On" > ServiceCommitment."Next Billing Date" then
            exit(true);
        if UnpostedDocumentExists(ServiceCommitment) then
            exit(true);
        if (ServiceCommitment."Next Price Update" <> 0D) and (ServiceCommitment."Next Billing Date" < ServiceCommitment."Next Price Update") then
            exit(true);
        exit(false);
    end;

    /// <summary>
    /// Copy of table 8059 "Subscription Line".UnpostedDocumentExists (internal). The public
    /// Billing Line.FilterBillingLineOnContractLine is called.
    /// Source: src/Apps/W1/Subscription Billing/App/Service Commitments/Tables/SubscriptionLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UnpostedDocumentExists public on table 8059.
    /// </summary>
    local procedure UnpostedDocumentExists(ServiceCommitment: Record "Subscription Line"): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.FilterBillingLineOnContractLine(ServiceCommitment.Partner, ServiceCommitment."Subscription Contract No.", ServiceCommitment."Subscription Contract Line No.");
        BillingLine.SetRange("Document Type", "Rec. Billing Document Type"::Invoice, "Rec. Billing Document Type"::"Credit Memo");
        exit(not BillingLine.IsEmpty());
    end;

    /// <summary>
    /// Copy of table 8059 "Subscription Line".UpdateServiceCommitmentFromContractPriceUpdateLine (internal).
    /// Microsoft switches the archiving of the OnModify trigger off with the internal SetSkipArchiving, modifies,
    /// and then archives the previous state as a "Price Update" valid until the day before Perform Update On. This
    /// app cannot call SetSkipArchiving, so OnModify archives the previous state first (as an untyped change), and
    /// the copy of CreateServiceCommitmentArchive below then finds that archive entry (written less than a minute
    /// ago, the same rule Microsoft applies) and overwrites it with the same values Microsoft writes. The result is
    /// the single archive entry Microsoft leaves.
    /// Source: src/Apps/W1/Subscription Billing/App/Service Commitments/Tables/SubscriptionLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UpdateServiceCommitmentFromContractPriceUpdateLine public on table 8059
    /// (or SetSkipArchiving and CreateServiceCommitmentArchive). Difference: the internal event
    /// OnAfterUpdateServiceCommitmentFromContractPriceUpdateLine is not raised.
    /// </summary>
    local procedure UpdateServiceCommitmentFromContractPriceUpdateLine(var ServiceCommitment: Record "Subscription Line"; PriceUpdateLine: Record "Sub. Contr. Price Update Line")
    var
        ServiceCommitmentArchive: Record "Subscription Line Archive";
        xServiceCommitment: Record "Subscription Line";
        PriceUpdateTemplate: Record "Price Update Template";
    begin
        xServiceCommitment := ServiceCommitment;
        ServiceCommitment.Validate("Calculation Base %", PriceUpdateLine."New Calculation Base %");
        ServiceCommitment.Validate("Calculation Base Amount", PriceUpdateLine."New Calculation Base");
        ServiceCommitment.Validate(Price, PriceUpdateLine."New Price");
        ServiceCommitment.Validate(Amount, PriceUpdateLine."New Amount");
        ServiceCommitment.Validate("Discount %", PriceUpdateLine."Discount %");
        ServiceCommitment."Next Price Update" := PriceUpdateLine."Next Price Update";
        if PriceUpdateTemplate.Get(PriceUpdateLine."Price Update Template Code") then
            ServiceCommitment."Price Binding Period" := PriceUpdateTemplate."Price Binding Period";

        // Microsoft: SetSkipArchiving(true); Modify(true); SetSkipArchiving(false). See the summary.
        ServiceCommitment.Modify(true);
        CreateServiceCommitmentArchive(ServiceCommitmentArchive, xServiceCommitment, CalcDate('<-1D>', PriceUpdateLine."Perform Update On"), Enum::"Type Of Price Update"::"Price Update");
    end;

    /// <summary>
    /// Copy of table 8059 "Subscription Line".CreateServiceCommitmentArchive with FindServiceCommitmentArchiveCreatedInLessThanMinute
    /// (internal and local). Subscription Line Archive.FilterOnServiceCommitment (internal) is inlined.
    /// Source: src/Apps/W1/Subscription Billing/App/Service Commitments/Tables/SubscriptionLine.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CreateServiceCommitmentArchive public on table 8059.
    /// </summary>
    local procedure CreateServiceCommitmentArchive(var ServiceCommitmentArchive: Record "Subscription Line Archive"; xServiceCommitment: Record "Subscription Line"; PerformUpdateOn: Date; TypeOfPriceUpdate: Enum "Type Of Price Update")
    begin
        ServiceCommitmentArchive.SetRange("Original Entry No.", xServiceCommitment."Entry No.");
        ServiceCommitmentArchive.SetRange(SystemModifiedAt, CurrentDateTime() - 60000, CurrentDateTime());
        if ServiceCommitmentArchive.FindLast() then begin
            CopyFromServiceCommitment(ServiceCommitmentArchive, xServiceCommitment);
            ServiceCommitmentArchive."Perform Update On" := PerformUpdateOn;
            ServiceCommitmentArchive."Type Of Update" := TypeOfPriceUpdate;
            ServiceCommitmentArchive.Modify(false);
        end else begin
            ServiceCommitmentArchive.Init();
            CopyFromServiceCommitment(ServiceCommitmentArchive, xServiceCommitment);
            ServiceCommitmentArchive."Perform Update On" := PerformUpdateOn;
            ServiceCommitmentArchive."Type Of Update" := TypeOfPriceUpdate;
            ServiceCommitmentArchive."Entry No." := 0;
            ServiceCommitmentArchive.Insert(true);
        end;
    end;

    /// <summary>
    /// Copy of table 8073 "Subscription Line Archive".CopyFromServiceCommitment (internal).
    /// Source: src/Apps/W1/Subscription Billing/App/Service Commitments/Tables/SubscriptionLineArchive.Table.al,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make CopyFromServiceCommitment public on table 8073. Difference: the
    /// internal event OnAfterCopyFromSubscriptionLine is not raised.
    /// </summary>
    local procedure CopyFromServiceCommitment(var ServiceCommitmentArchive: Record "Subscription Line Archive"; ServiceCommitment: Record "Subscription Line")
    var
        ServiceObject: Record "Subscription Header";
    begin
        ServiceCommitmentArchive."Subscription Header No." := ServiceCommitment."Subscription Header No.";
        ServiceObject.Get(ServiceCommitment."Subscription Header No.");
        ServiceCommitmentArchive."Quantity (Sub. Header)" := ServiceObject.Quantity;
        ServiceCommitmentArchive."Serial No. (Sub. Header)" := ServiceObject."Serial No.";
        ServiceCommitmentArchive."Variant Code (Sub. Header)" := ServiceObject."Variant Code";
        ServiceCommitmentArchive."Original Entry No." := ServiceCommitment."Entry No.";
        ServiceCommitmentArchive."Subscription Package Code" := ServiceCommitment."Subscription Package Code";
        ServiceCommitmentArchive."Template" := ServiceCommitment."Template";
        ServiceCommitmentArchive."Description" := ServiceCommitment."Description";
        ServiceCommitmentArchive."Subscription Line Start Date" := ServiceCommitment."Subscription Line Start Date";
        ServiceCommitmentArchive."Subscription Line End Date" := ServiceCommitment."Subscription Line End Date";
        ServiceCommitmentArchive."Next Billing Date" := ServiceCommitment."Next Billing Date";
        ServiceCommitmentArchive."Calculation Base Amount" := ServiceCommitment."Calculation Base Amount";
        ServiceCommitmentArchive."Calculation Base %" := ServiceCommitment."Calculation Base %";
        ServiceCommitmentArchive."Price" := ServiceCommitment."Price";
        ServiceCommitmentArchive."Discount %" := ServiceCommitment."Discount %";
        ServiceCommitmentArchive."Discount Amount" := ServiceCommitment."Discount Amount";
        ServiceCommitmentArchive.Amount := ServiceCommitment.Amount;
        ServiceCommitmentArchive."Billing Base Period" := ServiceCommitment."Billing Base Period";
        ServiceCommitmentArchive."Invoicing via" := ServiceCommitment."Invoicing via";
        ServiceCommitmentArchive."Invoicing Item No." := ServiceCommitment."Invoicing Item No.";
        ServiceCommitmentArchive."Partner" := ServiceCommitment."Partner";
        ServiceCommitmentArchive."Subscription Contract No." := ServiceCommitment."Subscription Contract No.";
        ServiceCommitmentArchive."Notice Period" := ServiceCommitment."Notice Period";
        ServiceCommitmentArchive."Initial Term" := ServiceCommitment."Initial Term";
        ServiceCommitmentArchive."Extension Term" := ServiceCommitment."Extension Term";
        ServiceCommitmentArchive."Billing Rhythm" := ServiceCommitment."Billing Rhythm";
        ServiceCommitmentArchive."Cancellation Possible Until" := ServiceCommitment."Cancellation Possible Until";
        ServiceCommitmentArchive."Term Until" := ServiceCommitment."Term Until";
        ServiceCommitmentArchive."Subscription Contract Line No." := ServiceCommitment."Subscription Contract Line No.";
        ServiceCommitmentArchive."Customer Price Group" := ServiceCommitment."Customer Price Group";
        ServiceCommitmentArchive."Shortcut Dimension 1 Code" := ServiceCommitment."Shortcut Dimension 1 Code";
        ServiceCommitmentArchive."Shortcut Dimension 2 Code" := ServiceCommitment."Shortcut Dimension 2 Code";
        ServiceCommitmentArchive."Price (LCY)" := ServiceCommitment."Price (LCY)";
        ServiceCommitmentArchive."Discount Amount (LCY)" := ServiceCommitment."Discount Amount (LCY)";
        ServiceCommitmentArchive."Amount (LCY)" := ServiceCommitment."Amount (LCY)";
        ServiceCommitmentArchive."Currency Code" := ServiceCommitment."Currency Code";
        ServiceCommitmentArchive."Currency Factor" := ServiceCommitment."Currency Factor";
        ServiceCommitmentArchive."Currency Factor Date" := ServiceCommitment."Currency Factor Date";
        ServiceCommitmentArchive."Calculation Base Amount (LCY)" := ServiceCommitment."Calculation Base Amount (LCY)";
        ServiceCommitmentArchive."Dimension Set ID" := ServiceCommitment."Dimension Set ID";
        ServiceCommitmentArchive."Next Price Update" := ServiceCommitment."Next Price Update";
        ServiceCommitmentArchive."Unit Cost" := ServiceCommitment."Unit Cost";
        ServiceCommitmentArchive."Unit Cost (LCY)" := ServiceCommitment."Unit Cost (LCY)";
        ServiceCommitmentArchive.Closed := ServiceCommitment.Closed;
        ServiceCommitmentArchive."Usage Based Billing" := ServiceCommitment."Usage Based Billing";
        ServiceCommitmentArchive."Usage Based Pricing" := ServiceCommitment."Usage Based Pricing";
        ServiceCommitmentArchive."Pricing Unit Cost Surcharge %" := ServiceCommitment."Pricing Unit Cost Surcharge %";
    end;
}
