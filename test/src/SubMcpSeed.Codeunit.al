namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>Explicit test-only seed operation for issue 63. Never runs at install and never changes licensing, consent or write guards.</summary>
codeunit 95728 "Sub MCP Seed ori"
{
    trigger OnRun()
    var
        Fixture: Record "Sub MCP Fixture ori";
    begin
        if not CompanyName().StartsWith('CRONUS') then
            Error(CompanyErr);
        Fixture.SetFilter("Fixture Key", 'ZZSB63W5*');
        if not Fixture.IsEmpty() then
            Error(AlreadySeededErr);
        SeedLanguage('ZZSB63W5-1033');
        SeedLanguage('ZZSB63W5-1039');
    end;

    var
        TestLibrary: Codeunit "Sub Test Library ori";
        CompanyErr: Label 'Run this explicit fixture seed only in the owned CRONUS development company.';
        AlreadySeededErr: Label 'The issue 63 fixture already exists. Inspect it; do not replay the seed.';

    local procedure SeedLanguage(FixtureKey: Code[20])
    var
        Contract: Record "Customer Subscription Contract";
        OtherContract: Record "Customer Subscription Contract";
        RenewalContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
        OtherVendorContract: Record "Vendor Subscription Contract";
        Subscription: Record "Subscription Header";
        Package: Record "Subscription Package";
        ContractLine: Record "Cust. Sub. Contract Line";
        Invoice: Record "Purchase Header";
        Supplier: Record "Usage Data Supplier";
        Import: Record "Usage Data Import";
        ImportedLine: Record "Usage Data Generic Import";
        SalesHeader: Record "Sales Header";
        FirstInvoice: Code[20];
        FailedInvoice: Code[20];
    begin
        TestLibrary.CreateBillableCustomerContract(Contract, Subscription, 0D);
        TestLibrary.CreateBillableCustomerContract(OtherContract, Subscription, 0D);
        Store(FixtureKey, 'analysisContract', Contract."No.");
        Store(FixtureKey, 'otherAnalysisContract', OtherContract."No.");
        TestLibrary.CreateBillableVendorContract(VendorContract, Subscription);
        TestLibrary.CreateBillableVendorContract(OtherVendorContract, Subscription);
        Invoice.Init();
        Invoice."Document Type" := Invoice."Document Type"::Invoice;
        Invoice.Insert(true);
        Invoice.Validate("Buy-from Vendor No.", VendorContract."Buy-from Vendor No.");
        Invoice.Modify(true);
        Store(FixtureKey, 'vendorContract', VendorContract."No.");
        Store(FixtureKey, 'foreignVendorContract', OtherVendorContract."No.");
        Store(FixtureKey, 'vendorInvoice', Invoice."No.");
        TestLibrary.CreateBillableCustomerContract(RenewalContract, Subscription, CalcDate('<CM+11M>', WorkDate()));
        TestLibrary.CreatePackage(Package, true, false, false);
        TestLibrary.RunLineCreate(Subscription."No.", Package.Code, WorkDate(), CalcDate('<CM+11M>', WorkDate()));
        TestLibrary.RunGetLines(Enum::"Message Type ori"::"Subscription.Contract.GetLines", RenewalContract."No.");
        ContractLine.SetRange("Subscription Contract No.", RenewalContract."No.");
        ContractLine.FindFirst();
        ContractLine.Closed := true;
        ContractLine.Modify(false);
        Store(FixtureKey, 'renewalContract', RenewalContract."No.");
        Store(FixtureKey, 'closedRenewalEntry', Format(ContractLine."Subscription Line Entry No.", 0, 9));
        Supplier.Init();
        Supplier."No." := FixtureKey;
        Supplier.Type := Enum::"Usage Data Supplier Type"::Generic;
        Supplier.Insert(false);
        Store(FixtureKey, 'supplier', Supplier."No.");
        Import.Init();
        Import.Insert(false);
        ImportedLine.Init();
        ImportedLine."Usage Data Import Entry No." := Import."Entry No.";
        ImportedLine."Processing Status" := ImportedLine."Processing Status"::Error;
        ImportedLine.Insert(false);
        Store(FixtureKey, 'errorImport', Format(Import."Entry No.", 0, 9));
        FirstInvoice := CreateBillingInvoice();
        FailedInvoice := CreateBillingInvoice();
        SalesHeader.Get(SalesHeader."Document Type"::Invoice, FailedInvoice);
        SalesHeader."Posting Date" := 0D;
        SalesHeader.Modify(false);
        Store(FixtureKey, 'firstBillingInvoice', FirstInvoice);
        Store(FixtureKey, 'failedBillingInvoice', FailedInvoice);
    end;

    local procedure Store(FixtureKey: Code[20]; Name: Code[30]; Value: Text)
    var
        Fixture: Record "Sub MCP Fixture ori";
    begin
        Fixture.Init();
        Fixture."Fixture Key" := FixtureKey;
        Fixture.Name := Name;
        Fixture.Value := CopyStr(Value, 1, MaxStrLen(Fixture.Value));
        Fixture.Insert(false);
    end;

    local procedure CreateBillingInvoice(): Code[20]
    var
        Contract: Record "Customer Subscription Contract";
        Subscription: Record "Subscription Header";
        BillingTemplate: Record "Billing Template";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        TestLibrary.CreateBillableCustomerContract(Contract, Subscription, 0D);
        TestLibrary.CreateBillingTemplate(BillingTemplate, Enum::"Service Partner"::Customer, Contract."No.");
        Request.Add('billingTemplateCode', BillingTemplate.Code);
        TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateProposal", Request);
        Response := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.CreateDocuments", Request);
        TestLibrary.ReadArray(Response, 'documents').Get(0, Token);
        exit(CopyStr(TestLibrary.ReadText(Token.AsObject(), 'documentNo'), 1, 20));
    end;
}
