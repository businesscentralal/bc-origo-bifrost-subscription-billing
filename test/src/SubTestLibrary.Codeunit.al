namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Seeds the Microsoft Subscription Billing data the behaviour tests of this app need: setup with
/// number series, customers and vendors in local currency, subscription items, packages,
/// Subscriptions, contracts with lines and billing templates. Every record is created by the test
/// that needs it, so no test relies on demo data. Contract lines are created through this app's
/// own Subscription.Line.Create and GetLines types, the way a caller builds them.
/// </summary>
codeunit 95770 "Sub Test Library ori"
{
    var
        LibraryERM: Codeunit "Library - ERM";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryUtility: Codeunit "Library - Utility";
        DeferralSourceCodeTok: Label 'XSUBDEFREL', Locked = true;

    /// <summary>Makes sure Subscription Contract Setup has number series, default periods and the deferral release setup.</summary>
    procedure InitSubscriptionBilling()
    var
        SubscriptionContractSetup: Record "Subscription Contract Setup";
        GeneralLedgerSetup: Record "General Ledger Setup";
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        if not SubscriptionContractSetup.Get() then begin
            SubscriptionContractSetup.Init();
            SubscriptionContractSetup.Insert(false);
        end;
        if SubscriptionContractSetup."Cust. Sub. Contract Nos." = '' then
            SubscriptionContractSetup."Cust. Sub. Contract Nos." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Vend. Sub. Contract Nos." = '' then
            SubscriptionContractSetup."Vend. Sub. Contract Nos." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Subscription Header No." = '' then
            SubscriptionContractSetup."Subscription Header No." := LibraryERM.CreateNoSeriesCode();
        if SubscriptionContractSetup."Contract Invoice Description" = SubscriptionContractSetup."Contract Invoice Description"::" " then
            SubscriptionContractSetup.ContractTextsCreateDefaults();
        Evaluate(SubscriptionContractSetup."Default Billing Base Period", '<1M>');
        Evaluate(SubscriptionContractSetup."Default Billing Rhythm", '<1M>');
        GeneralLedgerSetup.Get();
        if GeneralLedgerSetup."Journal Templ. Name Mandatory" and (SubscriptionContractSetup."Def. Rel. Jnl. Batch Name" = '') then begin
            LibraryERM.CreateGenJournalTemplate(GenJournalTemplate);
            LibraryERM.CreateGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
            SubscriptionContractSetup."Def. Rel. Jnl. Template Name" := GenJournalBatch."Journal Template Name";
            SubscriptionContractSetup."Def. Rel. Jnl. Batch Name" := GenJournalBatch.Name;
        end;
        SubscriptionContractSetup.Modify(false);
        EnsureDeferralSourceCode();
    end;

    /// <summary>Creates a customer in local currency.</summary>
    /// <param name="Customer">Returns the created customer.</param>
    procedure CreateCustomer(var Customer: Record Customer)
    begin
        InitSubscriptionBilling();
        LibrarySales.CreateCustomer(Customer);
        Customer.Validate("Currency Code", '');
        Customer.Modify(false);
    end;

    /// <summary>Creates a vendor in local currency.</summary>
    /// <param name="Vendor">Returns the created vendor.</param>
    procedure CreateVendor(var Vendor: Record Vendor)
    begin
        InitSubscriptionBilling();
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Validate("Currency Code", '');
        Vendor.Modify(false);
    end;

    /// <summary>Creates a Customer Subscription Contract for the customer that creates contract deferrals.</summary>
    /// <param name="CustomerContract">Returns the created contract.</param>
    /// <param name="CustomerNo">The Sell-to Customer No. of the contract.</param>
    procedure CreateCustomerContract(var CustomerContract: Record "Customer Subscription Contract"; CustomerNo: Code[20])
    begin
        InitSubscriptionBilling();
        CustomerContract.Init();
        CustomerContract.Insert(true);
        CustomerContract.Validate("Sell-to Customer No.", CustomerNo);
        CustomerContract."Create Contract Deferrals" := true;
        CustomerContract.Modify(true);
    end;

    /// <summary>Creates a Vendor Subscription Contract for the vendor that creates contract deferrals.</summary>
    /// <param name="VendorContract">Returns the created contract.</param>
    /// <param name="VendorNo">The Buy-from Vendor No. of the contract.</param>
    procedure CreateVendorContract(var VendorContract: Record "Vendor Subscription Contract"; VendorNo: Code[20])
    begin
        InitSubscriptionBilling();
        VendorContract.Init();
        VendorContract.Insert(true);
        VendorContract.Validate("Buy-from Vendor No.", VendorNo);
        VendorContract."Create Contract Deferrals" := true;
        VendorContract.Modify(true);
    end;

    /// <summary>
    /// Creates a non-inventory item with Subscription Option Service Commitment Item, so it is both the
    /// Subscription's source and its own invoicing item.
    /// </summary>
    /// <param name="Item">Returns the created item.</param>
    procedure CreateSubscriptionItem(var Item: Record Item)
    begin
        InitSubscriptionBilling();
        LibraryInventory.CreateNonInventoryTypeItem(Item);
        Item.Validate("Unit Price", 100);
        Item.Validate("Unit Cost", 60);
        Item.Validate("Subscription Option", Enum::"Item Service Commitment Type"::"Service Commitment Item");
        Item.Modify(true);
    end;

    /// <summary>
    /// Creates a Subscription Package with one line per partner given, billed monthly through a
    /// contract at the item price (customer) or cost (vendor), with a 12 month initial term.
    /// </summary>
    /// <param name="SubscriptionPackage">Returns the created package.</param>
    /// <param name="CustomerLine">Adds a customer line.</param>
    /// <param name="VendorLine">Adds a vendor line.</param>
    /// <param name="CreateDeferrals">Whether the lines create contract deferrals.</param>
    procedure CreatePackage(var SubscriptionPackage: Record "Subscription Package"; CustomerLine: Boolean; VendorLine: Boolean; CreateDeferrals: Boolean)
    begin
        SubscriptionPackage.Init();
        SubscriptionPackage.Code := CopyStr(LibraryUtility.GenerateRandomCode20(SubscriptionPackage.FieldNo(Code), Database::"Subscription Package"), 1, MaxStrLen(SubscriptionPackage.Code));
        SubscriptionPackage.Description := SubscriptionPackage.Code;
        SubscriptionPackage.Insert(true);
        if CustomerLine then
            AddPackageLine(SubscriptionPackage.Code, Enum::"Service Partner"::Customer, CreateDeferrals, false);
        if VendorLine then
            AddPackageLine(SubscriptionPackage.Code, Enum::"Service Partner"::Vendor, CreateDeferrals, false);
    end;

    /// <summary>Adds a usage-based customer line (Usage Quantity pricing) to the package.</summary>
    /// <param name="PackageCode">The Subscription Package.</param>
    procedure AddUsageBasedCustomerLine(PackageCode: Code[20])
    begin
        AddPackageLine(PackageCode, Enum::"Service Partner"::Customer, false, true);
    end;

    /// <summary>Assigns the package to the item.</summary>
    /// <param name="ItemNo">The item.</param>
    /// <param name="PackageCode">The Subscription Package.</param>
    /// <param name="Standard">Whether the package is one of the item's standard packages.</param>
    procedure AssignPackageToItem(ItemNo: Code[20]; PackageCode: Code[20]; Standard: Boolean)
    var
        ItemSubscriptionPackage: Record "Item Subscription Package";
    begin
        ItemSubscriptionPackage.Init();
        ItemSubscriptionPackage."Item No." := ItemNo;
        ItemSubscriptionPackage.Validate(Code, PackageCode);
        ItemSubscriptionPackage.Standard := Standard;
        ItemSubscriptionPackage.Insert(false);
    end;

    /// <summary>Creates a Subscription Header for one unit of the item, used by the customer.</summary>
    /// <param name="SubscriptionHeader">Returns the created Subscription.</param>
    /// <param name="ItemNo">The source item.</param>
    /// <param name="CustomerNo">The End-User Customer No.; empty for a vendor-only Subscription.</param>
    procedure CreateSubscription(var SubscriptionHeader: Record "Subscription Header"; ItemNo: Code[20]; CustomerNo: Code[20])
    begin
        InitSubscriptionBilling();
        SubscriptionHeader.Init();
        SubscriptionHeader.Insert(true);
        SubscriptionHeader.SetHideValidationDialog(true);
        SubscriptionHeader.Type := Enum::"Service Object Type"::Item;
        SubscriptionHeader.Validate("Source No.", ItemNo);
        SubscriptionHeader.Validate(Quantity, 1);
        SubscriptionHeader."Provision Start Date" := WorkDate();
        if CustomerNo <> '' then
            SubscriptionHeader.Validate("End-User Customer No.", CustomerNo);
        SubscriptionHeader.Modify(true);
    end;

    /// <summary>
    /// Builds a billable customer contract: a customer, a subscription item with a customer package,
    /// a Subscription whose lines start on the work date (Subscription.Line.Create), and a contract
    /// the lines are attached to (Subscription.Contract.GetLines). The posting setup gets the
    /// Subscription contract accounts.
    /// </summary>
    /// <param name="CustomerContract">Returns the contract.</param>
    /// <param name="SubscriptionHeader">Returns the Subscription.</param>
    /// <param name="EndDate">End date of the lines; 0D leaves them open-ended.</param>
    procedure CreateBillableCustomerContract(var CustomerContract: Record "Customer Subscription Contract"; var SubscriptionHeader: Record "Subscription Header"; EndDate: Date)
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
    begin
        CreateCustomer(Customer);
        CreateSubscriptionItem(Item);
        CreatePackage(SubscriptionPackage, true, false, true);
        AssignPackageToItem(Item."No.", SubscriptionPackage.Code, true);
        SetContractAccounts(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), EndDate);
        CreateCustomerContract(CustomerContract, Customer."No.");
        RunGetLines(Enum::"Message Type ori"::"Subscription.Contract.GetLines", CustomerContract."No.");
        CustomerContract.Get(CustomerContract."No.");
    end;

    /// <summary>
    /// Builds a billable vendor contract: a vendor, a subscription item with a vendor package, a
    /// Subscription whose lines start on the work date, and a vendor contract the lines are attached to.
    /// </summary>
    /// <param name="VendorContract">Returns the contract.</param>
    /// <param name="SubscriptionHeader">Returns the Subscription.</param>
    procedure CreateBillableVendorContract(var VendorContract: Record "Vendor Subscription Contract"; var SubscriptionHeader: Record "Subscription Header")
    var
        Vendor: Record Vendor;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
    begin
        CreateVendor(Vendor);
        CreateSubscriptionItem(Item);
        CreatePackage(SubscriptionPackage, false, true, true);
        AssignPackageToItem(Item."No.", SubscriptionPackage.Code, true);
        SetContractAccounts(Vendor."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        CreateSubscription(SubscriptionHeader, Item."No.", '');
        RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        CreateVendorContract(VendorContract, Vendor."No.");
        RunGetLines(Enum::"Message Type ori"::"Subscription.VendorContract.GetLines", VendorContract."No.");
        VendorContract.Get(VendorContract."No.");
    end;

    /// <summary>Creates a Billing Template for the partner whose filter names only the given contract.</summary>
    /// <param name="BillingTemplate">Returns the template.</param>
    /// <param name="Partner">Customer or Vendor.</param>
    /// <param name="ContractNo">The only contract the template bills.</param>
    procedure CreateBillingTemplate(var BillingTemplate: Record "Billing Template"; Partner: Enum "Service Partner"; ContractNo: Code[20])
    var
        CustomerContract: Record "Customer Subscription Contract";
        VendorContract: Record "Vendor Subscription Contract";
        FilterStream: OutStream;
        ViewText: Text;
    begin
        BillingTemplate.Init();
        BillingTemplate.Code := CopyStr(LibraryUtility.GenerateRandomCode20(BillingTemplate.FieldNo(Code), Database::"Billing Template"), 1, MaxStrLen(BillingTemplate.Code));
        BillingTemplate.Description := BillingTemplate.Code;
        BillingTemplate.Partner := Partner;
        BillingTemplate.Insert(false);
        if Partner = Enum::"Service Partner"::Customer then begin
            CustomerContract.SetRange("No.", ContractNo);
            ViewText := CustomerContract.GetView(false);
        end else begin
            VendorContract.SetRange("No.", ContractNo);
            ViewText := VendorContract.GetView(false);
        end;
        BillingTemplate.Filter.CreateOutStream(FilterStream, TextEncoding::UTF8);
        FilterStream.WriteText(ViewText);
        BillingTemplate.Modify(false);
    end;

    /// <summary>
    /// Fills the Subscription contract accounts of the General Posting Setup for the posting groups,
    /// so billing documents can be created, posted and their deferrals released.
    /// </summary>
    /// <param name="GenBusPostingGroup">The partner's Gen. Bus. Posting Group.</param>
    /// <param name="GenProdPostingGroup">The item's Gen. Prod. Posting Group.</param>
    procedure SetContractAccounts(GenBusPostingGroup: Code[20]; GenProdPostingGroup: Code[20])
    var
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        if not GeneralPostingSetup.Get(GenBusPostingGroup, GenProdPostingGroup) then
            LibraryERM.CreateGeneralPostingSetup(GeneralPostingSetup, GenBusPostingGroup, GenProdPostingGroup);
        if GeneralPostingSetup."Sales Account" = '' then
            GeneralPostingSetup."Sales Account" := LibraryERM.CreateGLAccountNo();
        if GeneralPostingSetup."Purch. Account" = '' then
            GeneralPostingSetup."Purch. Account" := LibraryERM.CreateGLAccountNo();
        GeneralPostingSetup."Cust. Sub. Contract Account" := GeneralPostingSetup."Sales Account";
        GeneralPostingSetup."Vend. Sub. Contract Account" := GeneralPostingSetup."Purch. Account";
        if GeneralPostingSetup."Cust. Sub. Contr. Def Account" = '' then
            GeneralPostingSetup."Cust. Sub. Contr. Def Account" := LibraryERM.CreateGLAccountNo();
        if GeneralPostingSetup."Vend. Sub. Contr. Def. Account" = '' then
            GeneralPostingSetup."Vend. Sub. Contr. Def. Account" := LibraryERM.CreateGLAccountNo();
        GeneralPostingSetup.Modify(false);
    end;

    /// <summary>Runs Subscription.Line.Create for the Subscription with the package, starting on StartDate.</summary>
    /// <param name="SubscriptionHeaderNo">The Subscription.</param>
    /// <param name="PackageCode">The Subscription Package.</param>
    /// <param name="StartDate">The line start date.</param>
    /// <param name="EndDate">The line end date; 0D leaves it out of the request.</param>
    /// <returns>The response.</returns>
    procedure RunLineCreate(SubscriptionHeaderNo: Code[20]; PackageCode: Code[20]; StartDate: Date; EndDate: Date): JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('subscriptionHeaderNo', SubscriptionHeaderNo);
        RequestJson.Add('subscriptionPackageCode', PackageCode);
        RequestJson.Add('subscriptionLineStartDate', Format(StartDate, 0, 9));
        if EndDate <> 0D then
            RequestJson.Add('subscriptionLineEndDate', Format(EndDate, 0, 9));
        exit(Run(Enum::"Message Type ori"::"Subscription.Line.Create", RequestJson));
    end;

    /// <summary>Runs Contract.GetLines or VendorContract.GetLines for every candidate line of the contract.</summary>
    /// <param name="MessageType">The GetLines type to run.</param>
    /// <param name="ContractNo">The contract.</param>
    /// <returns>The response.</returns>
    procedure RunGetLines(MessageType: Enum "Message Type ori"; ContractNo: Code[20]): JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('contractNo', ContractNo);
        exit(Run(MessageType, RequestJson));
    end;

    /// <summary>
    /// Runs the write of a Subscription Billing message type directly, as its isolated write does, after
    /// a commit (the types run Microsoft's codeunits with Codeunit.Run). Returns the response.
    /// </summary>
    /// <param name="MessageType">The type to run.</param>
    /// <param name="RequestJson">The request data.</param>
    /// <returns>The response.</returns>
    procedure Run(MessageType: Enum "Message Type ori"; RequestJson: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(RequestJson);
        Commit();
        PerformWrite(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    /// <summary>Reads an integer property of a response.</summary>
    /// <param name="Json">The response.</param>
    /// <param name="Name">The property.</param>
    /// <returns>The value.</returns>
    procedure ReadInteger(Json: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Json.Get(Name, Token) then
            Error('The response has no %1: %2', Name, AsText(Json));
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Reads a text property of a response.</summary>
    /// <param name="Json">The response.</param>
    /// <param name="Name">The property.</param>
    /// <returns>The value.</returns>
    procedure ReadText(Json: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Json.Get(Name, Token) then
            Error('The response has no %1: %2', Name, AsText(Json));
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads an array property of a response.</summary>
    /// <param name="Json">The response.</param>
    /// <param name="Name">The property.</param>
    /// <returns>The value.</returns>
    procedure ReadArray(Json: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
    begin
        if not Json.Get(Name, Token) then
            Error('The response has no %1: %2', Name, AsText(Json));
        exit(Token.AsArray());
    end;

    local procedure AsText(Json: JsonObject) Result: Text
    begin
        Json.WriteTo(Result);
    end;

    local procedure PerformWrite(var TempArgument: Record "Message Argument ori" temporary)
    var
        LineCreateImpl: Codeunit "Sub Line Create Impl ori";
        ConGetLinesImpl: Codeunit "Sub Con GetLines Impl ori";
        ConCrInvoiceImpl: Codeunit "Sub Con CrInvoice Impl ori";
        ConPrvInvoiceImpl: Codeunit "Sub Con PrvInvoice Impl ori";
        VendGetLinesImpl: Codeunit "Sub Vend GetLines Impl ori";
        VendCrInvoiceImpl: Codeunit "Sub Vend CrInvoice Impl ori";
        VendPrvInvImpl: Codeunit "Sub Vend PrvInv Impl ori";
        BilCrProposalImpl: Codeunit "Sub Bil CrProposal Impl ori";
        BilCrDocsImpl: Codeunit "Sub Bil CrDocs Impl ori";
        RenExtendImpl: Codeunit "Sub Ren Extend Impl ori";
        RenCrQuoteImpl: Codeunit "Sub Ren CrQuote Impl ori";
        UsgImportImpl: Codeunit "Sub Usg Import Impl ori";
        UsgProcessImpl: Codeunit "Sub Usg Process Impl ori";
        DefReleaseImpl: Codeunit "Sub Def Release Impl ori";
        AnaRecalcImpl: Codeunit "Sub Ana Recalc Impl ori";
    begin
        case TempArgument."Type" of
            TempArgument."Type"::"Subscription.Line.Create":
                LineCreateImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Contract.GetLines":
                ConGetLinesImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Contract.CreateInvoice":
                ConCrInvoiceImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Contract.PreviewInvoice":
                ConPrvInvoiceImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.VendorContract.GetLines":
                VendGetLinesImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.VendorContract.CreateInvoice":
                VendCrInvoiceImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.VendorContract.PreviewInvoice":
                VendPrvInvImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Billing.CreateProposal":
                BilCrProposalImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Billing.CreateDocuments":
                BilCrDocsImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Renewal.Extend":
                RenExtendImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Renewal.CreateQuote":
                RenCrQuoteImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Usage.ImportData":
                UsgImportImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Usage.Process":
                UsgProcessImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Deferral.Release":
                DefReleaseImpl.PerformWrite(TempArgument);
            TempArgument."Type"::"Subscription.Analysis.Recalculate":
                AnaRecalcImpl.PerformWrite(TempArgument);
            else
                Error('The test library cannot run message type %1.', TempArgument."Type".AsInteger());
        end;
    end;

    local procedure AddPackageLine(PackageCode: Code[20]; Partner: Enum "Service Partner"; CreateDeferrals: Boolean; UsageBased: Boolean)
    var
        SubscriptionPackageLine: Record "Subscription Package Line";
        NextLineNo: Integer;
    begin
        SubscriptionPackageLine.SetRange("Subscription Package Code", PackageCode);
        if SubscriptionPackageLine.FindLast() then
            NextLineNo := SubscriptionPackageLine."Line No.";
        NextLineNo += 10000;
        SubscriptionPackageLine.Init();
        SubscriptionPackageLine."Subscription Package Code" := PackageCode;
        SubscriptionPackageLine."Line No." := NextLineNo;
        SubscriptionPackageLine.Validate(Partner, Partner);
        SubscriptionPackageLine."Invoicing via" := Enum::"Invoicing Via"::Contract;
        SubscriptionPackageLine."Calculation Base Type" := Enum::"Calculation Base Type"::"Item Price";
        SubscriptionPackageLine."Calculation Base %" := 100;
        Evaluate(SubscriptionPackageLine."Billing Base Period", '<1M>');
        Evaluate(SubscriptionPackageLine."Billing Rhythm", '<1M>');
        Evaluate(SubscriptionPackageLine."Initial Term", '<12M>');
        Evaluate(SubscriptionPackageLine."Extension Term", '<12M>');
        Evaluate(SubscriptionPackageLine."Notice Period", '<1M>');
        if UsageBased then begin
            SubscriptionPackageLine."Usage Based Billing" := true;
            SubscriptionPackageLine."Usage Based Pricing" := Enum::"Usage Based Pricing"::"Usage Quantity";
        end;
        if CreateDeferrals then
            SubscriptionPackageLine."Create Contract Deferrals" := Enum::"Create Contract Deferrals"::Yes
        else
            SubscriptionPackageLine."Create Contract Deferrals" := Enum::"Create Contract Deferrals"::No;
        SubscriptionPackageLine.Insert(false);
    end;

    local procedure EnsureDeferralSourceCode()
    var
        SourceCode: Record "Source Code";
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();
        if SourceCodeSetup."Sub. Contr. Deferrals Release" <> '' then
            exit;
        if not SourceCode.Get(DeferralSourceCodeTok) then begin
            SourceCode.Init();
            SourceCode.Code := DeferralSourceCodeTok;
            SourceCode.Insert(false);
        end;
        SourceCodeSetup."Sub. Contr. Deferrals Release" := SourceCode.Code;
        SourceCodeSetup.Modify(false);
    end;
}
