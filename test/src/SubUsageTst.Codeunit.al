namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// Behaviour tests of #43 AC08: a small generic usage file runs through Usage.ImportData and
/// Usage.Process to Usage Data Billing rows for a usage-based Subscription Line on a customer
/// contract. The supplier, its generic import settings and the data exchange definition are seeded
/// by the test.
/// </summary>
codeunit 95777 "Sub Usage Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        LibraryUtility: Codeunit "Library - Utility";

    [Test]
    procedure Scenario_AC08_ImportAndProcess_CreatesUsageDataBilling()
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        UsageDataBilling: Record "Usage Data Billing";
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustomerContract: Record "Customer Subscription Contract";
        RequestJson: JsonObject;
        ImportResponse: JsonObject;
        ProcessResponse: JsonObject;
        SupplierSubscriptionId: Text[80];
        ImportEntryNo: Integer;
    begin
        // Issue #43, AC08 | Time: usage period is the work date month | Risk: None
        // [GIVEN] A usage-based customer line on a contract and a generic usage data supplier
        CreateUsageBasedContract(CustomerContract, SubscriptionHeader, SubscriptionLine);
        CreateGenericSupplier(UsageDataSupplier);
        SupplierSubscriptionId := CopyStr('XSUBID-' + SubscriptionHeader."No.", 1, MaxStrLen(SupplierSubscriptionId));

        // [WHEN] Subscription.Usage.ImportData imports a one-row file and processes the imported lines
        RequestJson.Add('supplierNo', UsageDataSupplier."No.");
        RequestJson.Add('fileName', 'xusage.csv');
        RequestJson.Add('content', UsageFile(SubscriptionHeader."No.", CustomerContract."Sell-to Customer No.", SupplierSubscriptionId, 5));
        RequestJson.Add('runProcessing', true);
        ImportResponse := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.ImportData", RequestJson);

        // [THEN] One imported line exists with the file's values
        ImportEntryNo := TestLibrary.ReadInteger(ImportResponse, 'usageDataImportEntryNo');
        Assert.AreEqual(1, TestLibrary.ReadInteger(ImportResponse, 'importedLineCount'), 'The file row must become one imported line. ' + TestLibrary.AsText(ImportResponse));
        UsageDataGenericImport.SetRange("Usage Data Import Entry No.", ImportEntryNo);
        UsageDataGenericImport.FindFirst();
        Assert.AreEqual(5, UsageDataGenericImport.Quantity, 'The quantity must be read from the file.');
        Assert.AreEqual(SupplierSubscriptionId, UsageDataGenericImport."Supp. Subscription ID", 'The supplier subscription must be read from the file.');

        // [WHEN] The supplier subscription is linked to the Subscription Line, as a user does on the
        // Usage Data Subscriptions page, and Subscription.Usage.Process runs its default steps
        LinkSupplierSubscription(UsageDataSupplier."No.", SupplierSubscriptionId, SubscriptionLine);
        Clear(RequestJson);
        RequestJson.Add('usageDataImportEntryNo', ImportEntryNo);
        ProcessResponse := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.Process", RequestJson);

        // [THEN] Usage Data Billing rows exist for the customer line and none is in error
        Assert.AreNotEqual(0, TestLibrary.ReadInteger(ProcessResponse, 'usageDataBillingCount'), 'Usage Data Billing rows must be created. ' + TestLibrary.AsText(ProcessResponse));
        Assert.AreEqual(0, TestLibrary.ReadInteger(ProcessResponse, 'usageDataBillingErrorCount'), 'No Usage Data Billing row may be in error.');
        UsageDataBilling.SetRange("Usage Data Import Entry No.", ImportEntryNo);
        UsageDataBilling.SetRange(Partner, Enum::"Service Partner"::Customer);
        UsageDataBilling.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        Assert.RecordIsNotEmpty(UsageDataBilling);
        UsageDataBilling.FindFirst();
        Assert.AreEqual(5, UsageDataBilling.Quantity, 'The billed quantity must be the imported one.');
        Assert.AreEqual(CustomerContract."No.", UsageDataBilling."Subscription Contract No.", 'The usage must be billed to the contract.');
    end;

    [Test]
    procedure Scenario_AC08_ImportData_WithoutContent_IsRefused()
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataImport: Record "Usage Data Import";
        RequestJson: JsonObject;
    begin
        // Issue #43, AC08 refusal | Time: none | Risk: None
        // [GIVEN] A generic supplier
        CreateGenericSupplier(UsageDataSupplier);

        // [WHEN] ImportData sends neither content nor contentBase64
        RequestJson.Add('supplierNo', UsageDataSupplier."No.");
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.ImportData", RequestJson);

        // [THEN] The call is refused and no import is created
        Assert.ExpectedError('contentBase64');
        UsageDataImport.SetRange("Supplier No.", UsageDataSupplier."No.");
        Assert.RecordIsEmpty(UsageDataImport);
    end;

    [Test]
    procedure Scenario_AC08_Process_UnknownStep_IsRefused()
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        RequestJson: JsonObject;
        Steps: JsonArray;
        ImportResponse: JsonObject;
    begin
        // Issue #43, AC08 edge case | Time: none | Risk: None
        // [GIVEN] An imported usage file
        CreateGenericSupplier(UsageDataSupplier);
        RequestJson.Add('supplierNo', UsageDataSupplier."No.");
        RequestJson.Add('content', UsageFile('XNOSUB', 'XNOCUST', 'XNOSUBID', 1));
        ImportResponse := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.ImportData", RequestJson);

        // [WHEN] Usage.Process names a step that does not exist
        Clear(RequestJson);
        RequestJson.Add('usageDataImportEntryNo', TestLibrary.ReadInteger(ImportResponse, 'usageDataImportEntryNo'));
        Steps.Add('XNotAStep');
        RequestJson.Add('steps', Steps);
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Usage.Process", RequestJson);

        // [THEN] The call is refused naming the step
        Assert.ExpectedError('XNotAStep');
    end;

    local procedure CreateUsageBasedContract(var CustomerContract: Record "Customer Subscription Contract"; var SubscriptionHeader: Record "Subscription Header"; var SubscriptionLine: Record "Subscription Line")
    var
        Customer: Record Microsoft.Sales.Customer.Customer;
        Item: Record Microsoft.Inventory.Item.Item;
        SubscriptionPackage: Record "Subscription Package";
    begin
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, false, false, false);
        TestLibrary.AddUsageBasedCustomerLine(SubscriptionPackage.Code);
        TestLibrary.SetContractAccounts(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        TestLibrary.CreateSubscription(SubscriptionHeader, Item."No.", Customer."No.");
        TestLibrary.RunLineCreate(SubscriptionHeader."No.", SubscriptionPackage.Code, CalcDate('<-CM>', WorkDate()), 0D);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        TestLibrary.RunGetLines(Enum::"Message Type ori"::"Subscription.Contract.GetLines", CustomerContract."No.");
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeader."No.");
        SubscriptionLine.FindFirst();
    end;

    local procedure CreateGenericSupplier(var UsageDataSupplier: Record "Usage Data Supplier")
    var
        GenericImportSettings: Record "Generic Import Settings";
    begin
        TestLibrary.InitSubscriptionBilling();
        UsageDataSupplier.Init();
        UsageDataSupplier."No." := CopyStr(LibraryUtility.GenerateRandomCode20(UsageDataSupplier.FieldNo("No."), Database::"Usage Data Supplier"), 1, MaxStrLen(UsageDataSupplier."No."));
        UsageDataSupplier.Description := UsageDataSupplier."No.";
        UsageDataSupplier.Type := Enum::"Usage Data Supplier Type"::Generic;
        UsageDataSupplier."Unit Price from Import" := true;
        UsageDataSupplier."Vendor Invoice per" := Enum::"Vendor Invoice Per"::Import;
        UsageDataSupplier.Insert(false);

        GenericImportSettings.Init();
        GenericImportSettings."Usage Data Supplier No." := UsageDataSupplier."No.";
        GenericImportSettings."Create Customers" := true;
        GenericImportSettings."Create Supplier Subscriptions" := true;
        GenericImportSettings."Data Exchange Definition" := CreateDataExchangeDefinition();
        GenericImportSettings.Insert(false);
    end;

    /// <summary>A semicolon separated file with one header line and columns mapped one to one on Usage Data Generic Import.</summary>
    local procedure CreateDataExchangeDefinition(): Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchLineDef: Record "Data Exch. Line Def";
        DataExchMapping: Record "Data Exch. Mapping";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        LineDefCode: Code[20];
        ColumnFields: List of [Integer];
        GenericImportMappingsCodeunitId: Integer;
        FieldNo: Integer;
        ColumnNo: Integer;
    begin
        DataExchDef.Init();
        DataExchDef.Code := CopyStr(LibraryUtility.GenerateRandomCode20(DataExchDef.FieldNo(Code), Database::"Data Exch. Def"), 1, MaxStrLen(DataExchDef.Code));
        DataExchDef.Name := DataExchDef.Code;
        DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
        DataExchDef.Type := Enum::"Data Exchange Definition Type"::"Generic Import";
        DataExchDef."Reading/Writing XMLport" := Xmlport::"Data Exch. Import - CSV";
        DataExchDef."File Encoding" := DataExchDef."File Encoding"::"UTF-8";
        DataExchDef."Column Separator" := DataExchDef."Column Separator"::Semicolon;
        DataExchDef."Header Lines" := 1;
        DataExchDef.Insert(false);

        LineDefCode := 'XUSAGE';
        DataExchLineDef.InsertRec(DataExchDef.Code, LineDefCode, LineDefCode, 0);

        ColumnFields := FileColumns();
        GenericImportMappingsCodeunitId := 8030;
        DataExchMapping.InsertRec(DataExchDef.Code, LineDefCode, Database::"Usage Data Generic Import", LineDefCode, GenericImportMappingsCodeunitId, 0, 0);
        foreach FieldNo in ColumnFields do begin
            ColumnNo += 1;
            InsertColumn(DataExchDef.Code, LineDefCode, ColumnNo, FieldNo, UsageDataGenericImport);
        end;
        exit(DataExchDef.Code);
    end;

    local procedure InsertColumn(DataExchDefCode: Code[20]; LineDefCode: Code[20]; ColumnNo: Integer; FieldNo: Integer; UsageDataGenericImport: Record "Usage Data Generic Import")
    var
        DataExchColumnDef: Record "Data Exch. Column Def";
        DataExchFieldMapping: Record "Data Exch. Field Mapping";
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        DataType: Option Text,Date,Decimal,DateTime;
        DataFormat: Text[100];
    begin
        RecordRef.GetTable(UsageDataGenericImport);
        FieldRef := RecordRef.Field(FieldNo);
        DataType := DataType::Text;
        DataFormat := '';
        if FieldRef.Type = FieldType::Date then begin
            DataType := DataType::Date;
            DataFormat := 'yyyy-MM-dd';
        end;
        if FieldRef.Type = FieldType::Decimal then
            DataType := DataType::Decimal;
        DataExchColumnDef.InsertRecordForImport(DataExchDefCode, LineDefCode, ColumnNo, CopyStr(FieldRef.Name, 1, MaxStrLen(DataExchColumnDef.Name)), '', true, DataType, DataFormat, 'en-US');
        DataExchFieldMapping.InsertRec(DataExchDefCode, LineDefCode, Database::"Usage Data Generic Import", ColumnNo, FieldNo, true, 1);
    end;

    local procedure FileColumns() Columns: List of [Integer]
    var
        UsageDataGenericImport: Record "Usage Data Generic Import";
    begin
        Columns.Add(UsageDataGenericImport.FieldNo("Subscription Header No."));
        Columns.Add(UsageDataGenericImport.FieldNo("Customer ID"));
        Columns.Add(UsageDataGenericImport.FieldNo("Customer Name"));
        Columns.Add(UsageDataGenericImport.FieldNo("Supp. Subscription ID"));
        Columns.Add(UsageDataGenericImport.FieldNo("Supp. Subscription Name"));
        Columns.Add(UsageDataGenericImport.FieldNo("Supp. Subscription Start Date"));
        Columns.Add(UsageDataGenericImport.FieldNo("Supp. Subscription End Date"));
        Columns.Add(UsageDataGenericImport.FieldNo("Billing Period Start Date"));
        Columns.Add(UsageDataGenericImport.FieldNo("Billing Period End Date"));
        Columns.Add(UsageDataGenericImport.FieldNo("Product ID"));
        Columns.Add(UsageDataGenericImport.FieldNo("Product Name"));
        Columns.Add(UsageDataGenericImport.FieldNo(Cost));
        Columns.Add(UsageDataGenericImport.FieldNo(Price));
        Columns.Add(UsageDataGenericImport.FieldNo(Quantity));
        Columns.Add(UsageDataGenericImport.FieldNo("Cost Amount"));
        Columns.Add(UsageDataGenericImport.FieldNo(Amount));
    end;

    local procedure UsageFile(SubscriptionHeaderNo: Text; CustomerId: Text; SupplierSubscriptionId: Text; Quantity: Integer) Content: Text
    var
        StartDate: Text;
        EndDate: Text;
        CrLf: Text[2];
    begin
        CrLf[1] := 13;
        CrLf[2] := 10;
        StartDate := Format(CalcDate('<-CM>', WorkDate()), 0, 9);
        EndDate := Format(CalcDate('<CM>', WorkDate()), 0, 9);
        Content := 'SubscriptionHeaderNo;CustomerId;CustomerName;SubscriptionId;SubscriptionName;SubscriptionStart;SubscriptionEnd;PeriodStart;PeriodEnd;ProductId;ProductName;Cost;Price;Quantity;CostAmount;Amount' + CrLf;
        Content += SubscriptionHeaderNo + ';' + CustomerId + ';XUSAGE CUSTOMER;' + SupplierSubscriptionId + ';XUSAGE SUBSCRIPTION;' + StartDate + ';' + EndDate + ';' + StartDate + ';' + EndDate +
            ';XPRODUCT;XUSAGE PRODUCT;6;10;' + Format(Quantity, 0, 9) + ';' + Format(6 * Quantity, 0, 9) + ';' + Format(10 * Quantity, 0, 9) + CrLf;
    end;

    local procedure LinkSupplierSubscription(SupplierNo: Code[20]; SupplierSubscriptionId: Text[80]; var SubscriptionLine: Record "Subscription Line")
    var
        UsageDataSupplierReference: Record "Usage Data Supplier Reference";
    begin
        UsageDataSupplierReference.SetRange("Supplier No.", SupplierNo);
        UsageDataSupplierReference.SetRange(Type, Enum::"Usage Data Reference Type"::Subscription);
        UsageDataSupplierReference.SetRange("Supplier Reference", SupplierSubscriptionId);
        if not UsageDataSupplierReference.FindFirst() then begin
            UsageDataSupplierReference.Init();
            UsageDataSupplierReference."Entry No." := 0;
            UsageDataSupplierReference."Supplier No." := SupplierNo;
            UsageDataSupplierReference.Type := Enum::"Usage Data Reference Type"::Subscription;
            UsageDataSupplierReference."Supplier Reference" := SupplierSubscriptionId;
            UsageDataSupplierReference.Insert(false);
        end;
        SubscriptionLine.Get(SubscriptionLine."Entry No.");
        SubscriptionLine."Supplier Reference Entry No." := UsageDataSupplierReference."Entry No.";
        SubscriptionLine.Modify(false);
    end;
}
