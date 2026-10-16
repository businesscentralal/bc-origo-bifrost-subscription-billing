// ------------------------------------------------------------------------------------------------
// Portions of this file are copied from Microsoft BCApps, src/Apps/W1/Subscription Billing/App,
// https://github.com/microsoft/BCApps, branch releases/28.x, commit a674a13 (app 28.7.0.0), and
// adapted (names, namespace, object ids, Rec into a parameter) for Bifrost Subscription Billing.
// See docs/microsoft-dependencies.md. The copied code is used under the MIT License:
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

using Microsoft.Foundation.Calendar;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Copy of the local merge on table 8062 "Cust. Sub. Contract Line" and of the internal checks it calls
/// on codeunit 8059 "Sub. Contracts General Mgt." and table 8057 "Subscription Header".
/// MergeContractLines itself is public, but it always opens page 8091 "Select Cust. Contract Lines".
/// The eligibility checks and the merge are local or internal, so an unattended caller cannot reach them.
/// Source: Customer Contracts/Tables/CustSubContractLine.Table.al, Base/Codeunits/SubContractsGeneralMgt.Codeunit.al
/// and Service Objects/Tables/SubscriptionHeader.Table.al, microsoft/BCApps releases/28.x, commit a674a13.
/// Change requested from Microsoft: make MergeContractLines accept the reference line as a parameter and
/// make TestMergingServiceObjects, TestMergingServiceCommitments and UpdateServicesDates public.
/// Then Subscription.Contract.MergeLines calls table 8062 and this codeunit is deleted.
/// </summary>
codeunit 10035074 "Sub Con Merge Mgt ori"
{
    Access = Internal;

    var
        OneContractLineSelectedErr: Label 'Please select the lines you want to combine.', Comment = 'is-IS=Veldu línurnar sem á að sameina.';
        BillingLinesForSelectedContractLinesExistsErr: Label 'Billing Lines for exists for at least one of the selected contract lines. Delete the Billing Lines before merging the Contract Lines.', Comment = 'is-IS=Reikningslínur eru til fyrir a.m.k. eina af völdu samningslínunum. Eyddu reikningslínunum áður en samningslínurnar eru sameinaðar.';
        ContractLinesWithDifferentDimensionSelectedErr: Label 'There are different dimension values for the Contract Lines. Complete the dimensions before merging the Contract Lines.', Comment = 'is-IS=Samningslínurnar hafa ólík víddargildi. Ljúktu við víddirnar áður en samningslínurnar eru sameinaðar.';
        ContractLinesWithDifferentNextBillingDateSelectedErr: Label 'There is a different Next Billing Date for the Contract Lines. The Contract Lines must be billed so that the Next Billing Date is the same before they can be combined.', Comment = 'is-IS=Samningslínurnar hafa ólíkan næsta reikningsdag. Reikningsfæra þarf línurnar þannig að næsti reikningsdagur sé sá sami áður en hægt er að sameina þær.';
        NotAllowedMergingTextLinesErr: Label 'Merging with text lines is not allowed.', Comment = 'is-IS=Ekki er leyfilegt að sameina við textalínur.';
        ContractLineWithDifferentCustRefCannotBeMergedErr: Label 'Subscription Lines from Subscriptions with different Customer References cannot be merged.', Comment = 'is-IS=Ekki er hægt að sameina áskriftarlínur af áskriftum með ólíkar tilvísanir viðskiptamanns.';
        LinesWithSerialNoCannotBeMergedErr: Label 'Contract lines cannot be merged if Serial No. is entered into Subscription.', Comment = 'is-IS=Ekki er hægt að sameina samningslínur ef raðnúmer er skráð á áskriftina.';
        MergeDidNotRunErr: Label 'The customer contract lines were not merged.', Comment = 'is-IS=Samningslínur viðskiptamanns voru ekki sameinaðar.';

    /// <summary>
    /// Copy of table 8062 MergeContractLines without page 8091. The reference line replaces the line
    /// the user would have picked on that page. The selected lines are the marked or filtered set.
    /// Source: Customer Contracts/Tables/CustSubContractLine.Table.al, procedure MergeContractLines,
    /// microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: a public MergeContractLines that takes the reference line.
    /// </summary>
    /// <param name="CustomerContractLine">The customer contract lines to merge. At least two, none of them comments.</param>
    /// <param name="ReferenceLine">The line whose Subscription is copied. It is the page selection.</param>
    /// <param name="NewContractLine">Returns the open contract line created for the merged Subscription.</param>
    procedure MergeLines(var CustomerContractLine: Record "Cust. Sub. Contract Line"; ReferenceLine: Record "Cust. Sub. Contract Line"; var NewContractLine: Record "Cust. Sub. Contract Line")
    begin
        CheckSelectedContractLines(CustomerContractLine);
        if not MergeCustomerContractLine(CustomerContractLine, ReferenceLine, NewContractLine) then
            Error(MergeDidNotRunErr);
    end;

    local procedure CheckSelectedContractLines(var CustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        ErrorIfTextLineIsSelected(CustomerContractLine);
        ErrorIfOneCustomerContractLineIsSelected(CustomerContractLine);
        TestAndCompareSelectedCustomerContractLines(CustomerContractLine);
    end;

    local procedure ErrorIfTextLineIsSelected(var CustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        CustomerContractLine.SetRange("Contract Line Type", Enum::"Contract Line Type"::Comment);
        if not CustomerContractLine.IsEmpty() then
            Error(NotAllowedMergingTextLinesErr);
        CustomerContractLine.SetRange("Contract Line Type");
    end;

    local procedure ErrorIfOneCustomerContractLineIsSelected(var CustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        if CustomerContractLine.Count() < 2 then
            Error(OneContractLineSelectedErr);
    end;

    local procedure TestAndCompareSelectedCustomerContractLines(var CustomerContractLine: Record "Cust. Sub. Contract Line")
    var
        ServiceCommitment: Record "Subscription Line";
        PrevServiceCommitment: Record "Subscription Line";
        ServiceObject: Record "Subscription Header";
        PrevServiceObject: Record "Subscription Header";
        PrevNextBillingDate: Date;
        FirstLine: Boolean;
        PrevDimensionSetID: Integer;
    begin
        FirstLine := true;
        PrevDimensionSetID := 0;
        PrevNextBillingDate := 0D;
        if CustomerContractLine.FindSet() then
            repeat
                CustomerContractLine.GetServiceCommitment(ServiceCommitment);
                ServiceObject.Get(CustomerContractLine."Subscription Header No.");

                if not FirstLine then
                    case true of
                        ServiceObject."Customer Reference" <> PrevServiceObject."Customer Reference":
                            Error(ContractLineWithDifferentCustRefCannotBeMergedErr);
                        ServiceObject."Serial No." <> PrevServiceObject."Serial No.":
                            Error(LinesWithSerialNoCannotBeMergedErr);
                        PrevDimensionSetID <> ServiceCommitment."Dimension Set ID":
                            Error(ContractLinesWithDifferentDimensionSelectedErr);
                        BillingLineExists(Enum::"Service Partner"::Customer, CustomerContractLine."Subscription Contract No.", CustomerContractLine."Line No."):
                            Error(BillingLinesForSelectedContractLinesExistsErr);
                        PrevNextBillingDate <> ServiceCommitment."Next Billing Date":
                            Error(ContractLinesWithDifferentNextBillingDateSelectedErr);
                        (ServiceCommitment."Subscription Header No." <> PrevServiceCommitment."Subscription Header No.") or
                        (ServiceCommitment."Entry No." <> PrevServiceCommitment."Entry No."):
                            begin
                                if ServiceObject."No." <> PrevServiceObject."No." then
                                    TestMergingServiceObjects(ServiceObject, PrevServiceObject);
                                TestMergingServiceCommitments(ServiceCommitment, PrevServiceCommitment);
                            end;
                    end;
                PrevDimensionSetID := ServiceCommitment."Dimension Set ID";
                PrevNextBillingDate := ServiceCommitment."Next Billing Date";
                PrevServiceCommitment := ServiceCommitment;
                PrevServiceObject := ServiceObject;
                FirstLine := false;
            until CustomerContractLine.Next() = 0;
    end;

    /// <summary>
    /// Copy of codeunit 8059 TestMergingServiceObjects (internal).
    /// Source: Base/Codeunits/SubContractsGeneralMgt.Codeunit.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make TestMergingServiceObjects public.
    /// </summary>
    local procedure TestMergingServiceObjects(ServiceObject: Record "Subscription Header"; PrevServiceObject: Record "Subscription Header")
    begin
        ServiceObject.TestField(Type, PrevServiceObject.Type);
        ServiceObject.TestField("Source No.", PrevServiceObject."Source No.");
        ServiceObject.TestField("Unit of Measure", PrevServiceObject."Unit of Measure");
        ServiceObject.TestField("End-User Contact No.", PrevServiceObject."End-User Contact No.");
        ServiceObject.TestField("End-User Customer No.", PrevServiceObject."End-User Customer No.");
        ServiceObject.TestField("Bill-to Customer No.", PrevServiceObject."Bill-to Customer No.");
        ServiceObject.TestField("Bill-to Contact No.", PrevServiceObject."Bill-to Contact No.");
        ServiceObject.TestField("Bill-to Contact", PrevServiceObject."Bill-to Contact");
        ServiceObject.TestField("Bill-to Name", PrevServiceObject."Bill-to Name");
        ServiceObject.TestField("Bill-to Name 2", PrevServiceObject."Bill-to Name 2");
        ServiceObject.TestField("Bill-to Address", PrevServiceObject."Bill-to Address");
        ServiceObject.TestField("Bill-to Address 2", PrevServiceObject."Bill-to Address 2");
        ServiceObject.TestField("Bill-to City", PrevServiceObject."Bill-to City");
        ServiceObject.TestField("Bill-to Post Code", PrevServiceObject."Bill-to Post Code");
        ServiceObject.TestField("Bill-to Country/Region Code", PrevServiceObject."Bill-to Country/Region Code");
        ServiceObject.TestField("Bill-to County", PrevServiceObject."Bill-to County");
        ServiceObject.TestField("Ship-to Name", PrevServiceObject."Ship-to Name");
        ServiceObject.TestField("Ship-to Name 2", PrevServiceObject."Ship-to Name 2");
        ServiceObject.TestField("Ship-to Code", PrevServiceObject."Ship-to Code");
        ServiceObject.TestField("Ship-to Address", PrevServiceObject."Ship-to Address");
        ServiceObject.TestField("Ship-to Address 2", PrevServiceObject."Ship-to Address 2");
        ServiceObject.TestField("Ship-to City", PrevServiceObject."Ship-to City");
        ServiceObject.TestField("Ship-to Post Code", PrevServiceObject."Ship-to Post Code");
        ServiceObject.TestField("Ship-to Country/Region Code", PrevServiceObject."Ship-to Country/Region Code");
        ServiceObject.TestField("Ship-to County", PrevServiceObject."Ship-to County");
        ServiceObject.TestField("Ship-to Contact", PrevServiceObject."Ship-to Contact");
        ServiceObject.TestField("Customer Price Group", PrevServiceObject."Customer Price Group");
    end;

    /// <summary>
    /// Copy of codeunit 8059 TestMergingServiceCommitments (internal).
    /// Source: Base/Codeunits/SubContractsGeneralMgt.Codeunit.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make TestMergingServiceCommitments public.
    /// </summary>
    local procedure TestMergingServiceCommitments(ServiceCommitment: Record "Subscription Line"; PrevServiceCommitment: Record "Subscription Line")
    begin
        ServiceCommitment.TestField("Subscription Line End Date", PrevServiceCommitment."Subscription Line End Date");
        ServiceCommitment.TestField("Calculation Base Amount", PrevServiceCommitment."Calculation Base Amount");
        ServiceCommitment.TestField("Calculation Base %", PrevServiceCommitment."Calculation Base %");
        ServiceCommitment.TestField(Price, PrevServiceCommitment.Price);
        ServiceCommitment.TestField("Billing Base Period", PrevServiceCommitment."Billing Base Period");
        ServiceCommitment.TestField("Invoicing via", PrevServiceCommitment."Invoicing via");
        ServiceCommitment.TestField("Invoicing Item No.", PrevServiceCommitment."Invoicing Item No.");
        ServiceCommitment.TestField(Partner, PrevServiceCommitment.Partner);
        ServiceCommitment.TestField("Subscription Contract No.", PrevServiceCommitment."Subscription Contract No.");
        ServiceCommitment.TestField("Notice Period", PrevServiceCommitment."Notice Period");
        ServiceCommitment.TestField("Initial Term", PrevServiceCommitment."Initial Term");
        ServiceCommitment.TestField("Extension Term", PrevServiceCommitment."Extension Term");
        ServiceCommitment.TestField("Billing Rhythm", PrevServiceCommitment."Billing Rhythm");
        ServiceCommitment.TestField("Sub. Header Customer No.", PrevServiceCommitment."Sub. Header Customer No.");
        ServiceCommitment.TestField("Customer Price Group", PrevServiceCommitment."Customer Price Group");
    end;

    /// <summary>
    /// Copy of codeunit 8059 BillingLineExists (internal). Uses the public Billing Line filter.
    /// Source: Base/Codeunits/SubContractsGeneralMgt.Codeunit.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// </summary>
    local procedure BillingLineExists(ServicePartner: Enum "Service Partner"; ContractNo: Code[20]; ContractLineNo: Integer): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.FilterBillingLineOnContractLine(ServicePartner, ContractNo, ContractLineNo);
        exit(not BillingLine.IsEmpty());
    end;

    local procedure MergeCustomerContractLine(var CustomerContractLine: Record "Cust. Sub. Contract Line"; RefCustomerContractLine: Record "Cust. Sub. Contract Line"; var NewContractLine: Record "Cust. Sub. Contract Line"): Boolean
    var
        ServiceObject: Record "Subscription Header";
        ServiceCommitment: Record "Subscription Line";
    begin
        CreateDuplicateServiceObject(ServiceObject, RefCustomerContractLine."Subscription Header No.", CustomerContractLine);
        CreateMergedServiceCommitment(ServiceCommitment, ServiceObject, RefCustomerContractLine);
        CloseCustomerContractLines(CustomerContractLine);
        exit(AssignNewServiceCommitmentToCustomerContract(CustomerContractLine."Subscription Contract No.", ServiceCommitment, NewContractLine));
    end;

    local procedure GetNewServiceObjectQuantity(var CustomerContractLine: Record "Cust. Sub. Contract Line") NewQuantity: Decimal
    var
        ServiceObject: Record "Subscription Header";
    begin
        if CustomerContractLine.FindSet() then
            repeat
                ServiceObject.Get(CustomerContractLine."Subscription Header No.");
                NewQuantity += ServiceObject.Quantity;
            until CustomerContractLine.Next() = 0;
    end;

    local procedure CreateDuplicateServiceObject(var NewServiceObject: Record "Subscription Header"; ServiceObjectNo: Code[20]; var CustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        NewServiceObject.Get(ServiceObjectNo);
        NewServiceObject."No." := '';
        NewServiceObject.Quantity := GetNewServiceObjectQuantity(CustomerContractLine);
        NewServiceObject.Insert(true);
    end;

    local procedure CreateMergedServiceCommitment(var ServiceCommitment: Record "Subscription Line"; ServiceObject: Record "Subscription Header"; RefCustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        RefCustomerContractLine.GetServiceCommitment(ServiceCommitment);
        ServiceCommitment."Entry No." := 0;
        ServiceCommitment."Subscription Header No." := ServiceObject."No.";
        ServiceCommitment.Validate(Amount, ServiceCommitment.Price * ServiceObject.Quantity);
        ServiceCommitment.Validate("Subscription Line Start Date", ServiceCommitment."Next Billing Date");
        ServiceCommitment.Insert(true);
    end;

    local procedure AssignNewServiceCommitmentToCustomerContract(ContractNo: Code[20]; var NewServiceCommitment: Record "Subscription Line"; var NewContractLine: Record "Cust. Sub. Contract Line"): Boolean
    var
        CustomerContract: Record "Customer Subscription Contract";
    begin
        if ContractNo = '' then
            exit(false);
        CustomerContract.Get(ContractNo);
        CustomerContract.CreateCustomerContractLineFromServiceCommitment(NewServiceCommitment, ContractNo, NewContractLine);
        exit(true);
    end;

    local procedure CloseCustomerContractLines(var CustomerContractLine: Record "Cust. Sub. Contract Line")
    var
        ServiceCommitment: Record "Subscription Line";
        ServiceObject: Record "Subscription Header";
    begin
        if CustomerContractLine.FindSet() then
            repeat
                CustomerContractLine.GetServiceCommitment(ServiceCommitment);
                UpdateServiceCommitmentAndCloseCustomerContractLine(ServiceCommitment, CustomerContractLine);
#pragma warning disable AA0214
                ServiceObject.Get(CustomerContractLine."Subscription Header No.");
                UpdateServicesDates(ServiceObject);
                ServiceObject.Modify(false);
#pragma warning restore AA0214
            until CustomerContractLine.Next() = 0;
    end;

    local procedure UpdateServiceCommitmentAndCloseCustomerContractLine(var ServiceCommitment: Record "Subscription Line"; var CustomerContractLine: Record "Cust. Sub. Contract Line")
    begin
        ServiceCommitment."Subscription Line End Date" := ServiceCommitment."Next Billing Date";
        ServiceCommitment."Next Billing Date" := 0D;
        ServiceCommitment.Validate("Subscription Line End Date");
        ServiceCommitment.Closed := true;
        ServiceCommitment.Modify(false);

        CustomerContractLine.Closed := true;
        CustomerContractLine.Modify(false);
    end;

    /// <summary>
    /// Copy of table 8057 UpdateServicesDates (internal). Called on each closed Subscription after the merge.
    /// Source: Service Objects/Tables/SubscriptionHeader.Table.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// Change requested from Microsoft: make UpdateServicesDates public.
    /// </summary>
    local procedure UpdateServicesDates(var SubscriptionHeader: Record "Subscription Header")
    var
        ServiceCommitment: Record "Subscription Line";
        ReferenceDateForComparison: Date;
        LastServiceEndDate: Date;
        ServiceCommitmentUpdated: Boolean;
        SkipProvisionEndDateUpdate: Boolean;
    begin
        LastServiceEndDate := 0D;
        ServiceCommitment.Reset();
        ServiceCommitment.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        if ServiceCommitment.FindSet() then
            repeat
                if (ServiceCommitment."Subscription Line End Date" <> 0D) and (Today() > ServiceCommitment."Subscription Line End Date") and IsFullyInvoiced(ServiceCommitment) then begin
                    ServiceCommitment."Cancellation Possible Until" := 0D;
                    ServiceCommitment."Term Until" := 0D;
                    ServiceCommitment.Closed := true;
                    ServiceCommitment.Modify(false);
                    case ServiceCommitment.Partner of
                        ServiceCommitment.Partner::Customer:
                            CloseOpenCustomerContractLines(ServiceCommitment);
                        ServiceCommitment.Partner::Vendor:
                            CloseOpenVendorContractLines(ServiceCommitment);
                    end;
                    if ServiceCommitment."Subscription Line End Date" > LastServiceEndDate then
                        LastServiceEndDate := ServiceCommitment."Subscription Line End Date";
                end else begin
                    SkipProvisionEndDateUpdate := true;
                    ReferenceDateForComparison := GetReferenceDate(ServiceCommitment);
                    if (Today() > ReferenceDateForComparison) and (ReferenceDateForComparison <> 0D) then
                        repeat
                            ServiceCommitmentUpdated := false;
                            if Format(ServiceCommitment."Notice Period") <> '' then
                                if CalculateTermUntilUsingExtensionTerm(ServiceCommitment) then begin
                                    CalculateCancellationPossibleUntil(ServiceCommitment);
                                    ServiceCommitment.Modify(false);
                                    ServiceCommitmentUpdated := true;
                                    ReferenceDateForComparison := GetReferenceDate(ServiceCommitment);
                                end;
                        until (Today() <= ReferenceDateForComparison) or not ServiceCommitmentUpdated;
                end;
            until ServiceCommitment.Next() = 0;
        if not SkipProvisionEndDateUpdate then
            SubscriptionHeader."Provision End Date" := LastServiceEndDate;
    end;

    local procedure CloseOpenCustomerContractLines(ServiceCommitment: Record "Subscription Line")
    var
        CustomerContractLine: Record "Cust. Sub. Contract Line";
    begin
        CustomerContractLine.SetRange("Contract Line Type", CustomerContractLine."Contract Line Type"::Item, CustomerContractLine."Contract Line Type"::"G/L Account");
        CustomerContractLine.SetRange("Subscription Line Entry No.", ServiceCommitment."Entry No.");
        CustomerContractLine.SetRange(Closed, false);
        CustomerContractLine.ModifyAll(Closed, true, true);
    end;

    local procedure CloseOpenVendorContractLines(ServiceCommitment: Record "Subscription Line")
    var
        VendorContractLine: Record "Vend. Sub. Contract Line";
    begin
        VendorContractLine.SetRange("Contract Line Type", VendorContractLine."Contract Line Type"::Item, VendorContractLine."Contract Line Type"::"G/L Account");
        VendorContractLine.SetRange("Subscription Line Entry No.", ServiceCommitment."Entry No.");
        VendorContractLine.SetRange(Closed, false);
        VendorContractLine.ModifyAll(Closed, true, false);
    end;

    /// <summary>
    /// Copy of table 8059 IsFullyInvoiced (internal). BillingLineExists on that table is also internal;
    /// the public Billing Line filter is the same read.
    /// Source: Service Commitments/Tables/SubscriptionLine.Table.al, microsoft/BCApps releases/28.x, commit a674a13.
    /// </summary>
    local procedure IsFullyInvoiced(ServiceCommitment: Record "Subscription Line"): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.FilterBillingLineOnContractLine(ServiceCommitment.Partner, ServiceCommitment."Subscription Contract No.", ServiceCommitment."Subscription Contract Line No.");
        if not BillingLine.IsEmpty() then
            exit(false);
        if ServiceCommitment."Next Billing Date" = 0D then
            exit(false);

        exit(ServiceCommitment."Subscription Line End Date" = CalcDate('<-1D>', ServiceCommitment."Next Billing Date"));
    end;

    local procedure GetReferenceDate(ServiceCommitment: Record "Subscription Line"): Date
    begin
        case true of
            ServiceCommitment."Cancellation Possible Until" <> 0D:
                exit(ServiceCommitment."Cancellation Possible Until");
            ServiceCommitment."Term Until" <> 0D:
                exit(ServiceCommitment."Term Until");
            ServiceCommitment."Subscription Line Start Date" <> 0D:
                exit(ServiceCommitment."Subscription Line Start Date");
        end;
    end;

    local procedure CalculateTermUntilUsingExtensionTerm(var ServiceCommitment: Record "Subscription Line"): Boolean
    var
        DateTimeManagement: Codeunit "Date Time Management";
        PreviousTermUntil: Date;
    begin
        if IsExtensionTermEmpty(ServiceCommitment) or
            ((ServiceCommitment."Term Until" = 0D) and (ServiceCommitment."Subscription Line Start Date" = 0D))
        then
            exit(false);
        if ServiceCommitment."Term Until" <> 0D then
            PreviousTermUntil := ServiceCommitment."Term Until"
        else begin
            PreviousTermUntil := ServiceCommitment."Subscription Line Start Date";
            PreviousTermUntil := CalcDate('<-1D>', PreviousTermUntil);
        end;
        ServiceCommitment."Term Until" := CalcDate(ServiceCommitment."Extension Term", PreviousTermUntil);
        if DateTimeManagement.IsLastDayOfMonth(PreviousTermUntil) then
            DateTimeManagement.MoveDateToLastDayOfMonth(ServiceCommitment."Term Until");
        exit(true);
    end;

    local procedure CalculateCancellationPossibleUntil(var ServiceCommitment: Record "Subscription Line"): Boolean
    var
        CalendarManagement: Codeunit "Calendar Management";
        DateTimeManagement: Codeunit "Date Time Management";
        NegativeDateFormula: DateFormula;
    begin
        if IsNoticePeriodEmpty(ServiceCommitment) or (ServiceCommitment."Term Until" = 0D) then
            exit(false);
        CalendarManagement.ReverseDateFormula(NegativeDateFormula, ServiceCommitment."Notice Period");
        ServiceCommitment."Cancellation Possible Until" := CalcDate(NegativeDateFormula, ServiceCommitment."Term Until");
        if DateTimeManagement.IsLastDayOfMonth(ServiceCommitment."Term Until") then
            DateTimeManagement.MoveDateToLastDayOfMonth(ServiceCommitment."Cancellation Possible Until");
        exit(true);
    end;

    local procedure IsExtensionTermEmpty(ServiceCommitment: Record "Subscription Line"): Boolean
    begin
        exit(Format(ServiceCommitment."Extension Term") = '');
    end;

    local procedure IsNoticePeriodEmpty(ServiceCommitment: Record "Subscription Line"): Boolean
    begin
        exit(Format(ServiceCommitment."Notice Period") = '');
    end;
}
