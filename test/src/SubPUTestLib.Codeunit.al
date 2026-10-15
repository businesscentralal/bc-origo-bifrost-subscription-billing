namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Shared fixtures for the price update tests (#45). Seeds Subscription Headers, Subscription Lines,
/// contracts and Price Update Templates directly, in the state Microsoft's own Contract Test Library
/// leaves them, and drives both paths under test: Microsoft's logic through its public
/// "Contract Price Update" page (the oracle), and this app's copy through the public dispatcher.
/// Every code starts with X so the fixtures cannot be mistaken for demo data; the test runner's
/// isolation rolls everything back.
/// </summary>
codeunit 95740 "Sub PU Test Lib ori"
{
    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryUtility: Codeunit "Library - Utility";

    /// <summary>
    /// Turns on HTTP for the Origo apps, then takes every existing Subscription Line out of price updates and removes every proposal line, so a
    /// template without filters sees only the lines a test seeds, whatever demo data the company holds.
    /// </summary>
    procedure Initialize()
    var
        SubscriptionLine: Record "Subscription Line";
        ExcludedLine: Record "Subscription Line";
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
    begin
        SubscriptionLine.SetRange("Exclude from Price Update", false);
        SubscriptionLine.SetLoadFields("Entry No.");
        if SubscriptionLine.FindSet() then
            repeat
                ExcludedLine.Get(SubscriptionLine."Entry No.");
                ExcludedLine."Exclude from Price Update" := true;
                ExcludedLine.Modify(false);
            until SubscriptionLine.Next() = 0;
        ContractPriceUpdateLine.DeleteAll(false);
    end;

    /// <summary>Creates a customer through Microsoft's sales test library.</summary>
    procedure CreateCustomer(var Customer: Record Customer)
    begin
        LibrarySales.CreateCustomer(Customer);
    end;

    /// <summary>Creates a vendor through Microsoft's purchase test library.</summary>
    procedure CreateVendor(var Vendor: Record Vendor)
    begin
        LibraryPurchase.CreateVendor(Vendor);
    end;

    /// <summary>Creates an item with the given unit price and unit cost.</summary>
    procedure CreateItem(var Item: Record Item; UnitPrice: Decimal; UnitCost: Decimal)
    begin
        LibraryInventory.CreateItem(Item);
        Item."Unit Price" := UnitPrice;
        Item."Unit Cost" := UnitCost;
        Item.Modify(false);
    end;

    /// <summary>Creates a Customer Subscription Contract for the customer.</summary>
    procedure CreateCustomerContract(var CustomerContract: Record "Customer Subscription Contract"; Customer: Record Customer)
    begin
        CustomerContract.Init();
        CustomerContract."No." := NewCode('XPUCC');
        CustomerContract."Sell-to Customer No." := Customer."No.";
        CustomerContract."Sell-to Customer Name" := Customer.Name;
        CustomerContract."Bill-to Customer No." := Customer."No.";
        CustomerContract."Description Preview" := 'X price update contract ' + CustomerContract."No.";
        CustomerContract.Insert(false);
    end;

    /// <summary>Creates a Vendor Subscription Contract for the vendor.</summary>
    procedure CreateVendorContract(var VendorContract: Record "Vendor Subscription Contract"; Vendor: Record Vendor)
    begin
        VendorContract.Init();
        VendorContract."No." := NewCode('XPUVC');
        VendorContract."Buy-from Vendor No." := Vendor."No.";
        VendorContract."Pay-to Vendor No." := Vendor."No.";
        VendorContract."Pay-to Name" := Vendor.Name;
        VendorContract."Description Preview" := 'X price update vendor contract ' + VendorContract."No.";
        VendorContract.Insert(false);
    end;

    /// <summary>Creates a Subscription Header for an item, owned by the customer (empty for a vendor-only subscription).</summary>
    procedure CreateSubscriptionHeader(var SubscriptionHeader: Record "Subscription Header"; Item: Record Item; CustomerNo: Code[20]; HeaderQuantity: Decimal)
    begin
        SubscriptionHeader.Init();
        SubscriptionHeader."No." := NewCode('XPUSH');
        SubscriptionHeader.Type := SubscriptionHeader.Type::Item;
        SubscriptionHeader."Source No." := Item."No.";
        SubscriptionHeader.Description := 'X price update ' + SubscriptionHeader."No.";
        SubscriptionHeader.Quantity := HeaderQuantity;
        SubscriptionHeader."End-User Customer No." := CustomerNo;
        SubscriptionHeader."Bill-to Customer No." := CustomerNo;
        SubscriptionHeader."Unit of Measure" := Item."Base Unit of Measure";
        SubscriptionHeader.Insert(false);
    end;

    /// <summary>
    /// Creates a contract-invoiced Subscription Line with Microsoft's own amount calculation (the
    /// field validations on Calculation Base Amount, Calculation Base % and Discount %).
    /// </summary>
    procedure CreateSubscriptionLine(var SubscriptionLine: Record "Subscription Line"; SubscriptionHeader: Record "Subscription Header"; Partner: Enum "Service Partner"; ContractNo: Code[20]; CalculationBase: Decimal; CalculationBasePct: Decimal; DiscountPct: Decimal; NextBillingDate: Date; NextPriceUpdate: Date)
    begin
        SubscriptionLine.Init();
        SubscriptionLine."Entry No." := 0;
        SubscriptionLine."Subscription Header No." := SubscriptionHeader."No.";
        SubscriptionLine."Subscription Package Code" := 'XPUPKG';
        SubscriptionLine.Template := 'XPUTPL';
        SubscriptionLine.Description := 'X price update line';
        SubscriptionLine.Partner := Partner;
        SubscriptionLine."Invoicing via" := Enum::"Invoicing Via"::Contract;
        SubscriptionLine."Subscription Contract No." := ContractNo;
        SubscriptionLine."Subscription Line Start Date" := CalcDate('<-1Y>', WorkDate());
        SubscriptionLine."Next Billing Date" := NextBillingDate;
        SubscriptionLine."Next Price Update" := NextPriceUpdate;
        Evaluate(SubscriptionLine."Billing Base Period", '<12M>');
        Evaluate(SubscriptionLine."Billing Rhythm", '<1M>');
        SubscriptionLine.Insert(false);
        SubscriptionLine.Validate("Calculation Base Amount", CalculationBase);
        SubscriptionLine.Validate("Calculation Base %", CalculationBasePct);
        SubscriptionLine.Validate("Discount %", DiscountPct);
        SubscriptionLine.Modify(false);
    end;

    /// <summary>Creates a Price Update Template the way Microsoft's Contract Test Library does.</summary>
    procedure CreatePriceUpdateTemplate(var PriceUpdateTemplate: Record "Price Update Template"; Partner: Enum "Service Partner"; PriceUpdateMethod: Enum "Price Update Method"; UpdateValuePct: Decimal; PerformUpdateOnFormula: Text; InclContrLinesUpToDateFormula: Text; PriceBindingPeriod: Text)
    begin
        PriceUpdateTemplate.Init();
        PriceUpdateTemplate.Code := NewCode('XPUT');
        PriceUpdateTemplate.Description := 'X price update template';
        PriceUpdateTemplate.Partner := Partner;
        PriceUpdateTemplate.Validate("Price Update Method", PriceUpdateMethod);
        PriceUpdateTemplate.Validate("Update Value %", UpdateValuePct);
        Evaluate(PriceUpdateTemplate."Perform Update on Formula", PerformUpdateOnFormula);
        Evaluate(PriceUpdateTemplate.InclContrLinesUpToDateFormula, InclContrLinesUpToDateFormula);
        Evaluate(PriceUpdateTemplate."Price Binding Period", PriceBindingPeriod);
        PriceUpdateTemplate.Insert(false);
    end;

    /// <summary>Writes one of the three filter Blobs of a template, as Microsoft's internal WriteFilter does.</summary>
    procedure WriteTemplateFilter(var PriceUpdateTemplate: Record "Price Update Template"; FieldNumber: Integer; FilterText: Text)
    var
        FilterStream: OutStream;
    begin
        case FieldNumber of
            PriceUpdateTemplate.FieldNo("Subscription Contract Filter"):
                begin
                    Clear(PriceUpdateTemplate."Subscription Contract Filter");
                    PriceUpdateTemplate."Subscription Contract Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
                end;
            PriceUpdateTemplate.FieldNo("Subscription Filter"):
                begin
                    Clear(PriceUpdateTemplate."Subscription Filter");
                    PriceUpdateTemplate."Subscription Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
                end;
            PriceUpdateTemplate.FieldNo("Subscription Line Filter"):
                begin
                    Clear(PriceUpdateTemplate."Subscription Line Filter");
                    PriceUpdateTemplate."Subscription Line Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
                end;
        end;
        if FilterText <> '' then
            FilterStream.WriteText(FilterText);
        PriceUpdateTemplate.Modify(false);
    end;

    /// <summary>Limits a customer template to one contract, so lines other tests left behind cannot match it.</summary>
    procedure RestrictTemplateToContract(var PriceUpdateTemplate: Record "Price Update Template"; ContractNo: Code[20])
    var
        CustomerContract: Record "Customer Subscription Contract";
    begin
        CustomerContract.SetRange("No.", ContractNo);
        WriteTemplateFilter(PriceUpdateTemplate, PriceUpdateTemplate.FieldNo("Subscription Contract Filter"), CustomerContract.GetView(false));
    end;

    /// <summary>
    /// Runs Subscription.PriceUpdate.CreateProposal on the committing path, where the dispatcher turns an error into
    /// a structured answer. Commits the test's pending writes first, as Microsoft's tests do before Codeunit.Run.
    /// </summary>
    procedure InvokeCreateProposalCommitted(PriceUpdateTemplateCode: Code[20]; IncludeLinesUpToDate: Date; PerformUpdateOnDate: Date) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        if IncludeLinesUpToDate <> 0D then
            RequestJson.Add('includeLinesUpToDate', Format(IncludeLinesUpToDate, 0, 9));
        if PerformUpdateOnDate <> 0D then
            RequestJson.Add('performUpdateOnDate', Format(PerformUpdateOnDate, 0, 9));
        Commit();
        ResponseJson := Invoke(Enum::"Message Type ori"::"Subscription.PriceUpdate.CreateProposal", '', RequestJson, false);
    end;

    /// <summary>Runs Microsoft's own Create Proposal action on its public Contract Price Update page: the oracle.</summary>
    procedure RunMicrosoftCreateProposal(PriceUpdateTemplateCode: Code[20]; IncludeLinesUpToDate: Date; PerformUpdateOnDate: Date)
    var
        ContractPriceUpdate: TestPage "Contract Price Update";
    begin
        ContractPriceUpdate.OpenEdit();
        ContractPriceUpdate.PriceUpdateTemplateCode.SetValue(PriceUpdateTemplateCode);
        ContractPriceUpdate.IncludeContractLinesUpToDate.SetValue(IncludeLinesUpToDate);
        ContractPriceUpdate.PerformUpdateOnDate.SetValue(PerformUpdateOnDate);
        ContractPriceUpdate.CreateProposalAction.Invoke();
        ContractPriceUpdate.Close();
    end;

    /// <summary>Runs Microsoft's own Perform Price Update action on its public Contract Price Update page: the oracle.</summary>
    procedure RunMicrosoftPerform()
    var
        ContractPriceUpdate: TestPage "Contract Price Update";
    begin
        ContractPriceUpdate.OpenEdit();
        ContractPriceUpdate.PerformPriceUpdateAction.Invoke();
        ContractPriceUpdate.Close();
    end;

    /// <summary>Runs Subscription.PriceUpdate.CreateProposal through the public dispatcher.</summary>
    procedure InvokeCreateProposal(PriceUpdateTemplateCode: Code[20]; IncludeLinesUpToDate: Date; PerformUpdateOnDate: Date) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        if IncludeLinesUpToDate <> 0D then
            RequestJson.Add('includeLinesUpToDate', Format(IncludeLinesUpToDate, 0, 9));
        if PerformUpdateOnDate <> 0D then
            RequestJson.Add('performUpdateOnDate', Format(PerformUpdateOnDate, 0, 9));
        ResponseJson := Invoke(Enum::"Message Type ori"::"Subscription.PriceUpdate.CreateProposal", '', RequestJson, true);
    end;

    /// <summary>
    /// Runs Subscription.PriceUpdate.Perform through the public dispatcher, for one template or (empty code) for all.
    /// OmitCommit true is the dispatcher's lightweight default: nothing is committed and the first failure stops the call.
    /// OmitCommit false is the committing path; the caller must commit its own pending writes first, as Microsoft's tests do.
    /// </summary>
    procedure InvokePerform(PriceUpdateTemplateCode: Code[20]; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        if PriceUpdateTemplateCode <> '' then
            RequestJson.Add('priceUpdateTemplateCode', PriceUpdateTemplateCode);
        ResponseJson := Invoke(Enum::"Message Type ori"::"Subscription.PriceUpdate.Perform", '', RequestJson, OmitCommit);
    end;

    /// <summary>Dispatches a message type with a subject and a JSON body and returns the parsed answer.</summary>
    procedure Invoke(MessageType: Enum "Message Type ori"; Subject: Text; RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, Enum::"Message Version ori"::"1.0", CopyStr(Subject, 1, 250), 'XPU', 'application/json',
            RequestContent, ResponseContent, ResponseContentType, OmitCommit);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The dispatcher must return structured JSON.');
    end;

    /// <summary>Copies the proposal lines of a template into a temporary table and deletes them from the database.</summary>
    procedure TakeProposal(PriceUpdateTemplateCode: Code[20]; var TempContractPriceUpdateLine: Record "Sub. Contr. Price Update Line" temporary)
    var
        ContractPriceUpdateLine: Record "Sub. Contr. Price Update Line";
    begin
        TempContractPriceUpdateLine.Reset();
        TempContractPriceUpdateLine.DeleteAll(false);
        ContractPriceUpdateLine.SetRange("Price Update Template Code", PriceUpdateTemplateCode);
        if ContractPriceUpdateLine.FindSet() then
            repeat
                TempContractPriceUpdateLine := ContractPriceUpdateLine;
                TempContractPriceUpdateLine.Insert(false);
            until ContractPriceUpdateLine.Next() = 0;
        ContractPriceUpdateLine.DeleteAll(false);
    end;

    /// <summary>
    /// Asserts that two proposals are equal line by line, matched on Subscription Line Entry No.: every
    /// field Microsoft writes, apart from the auto-increment Entry No.
    /// </summary>
    procedure AssertSameProposal(var TempExpected: Record "Sub. Contr. Price Update Line" temporary; var TempActual: Record "Sub. Contr. Price Update Line" temporary)
    begin
        Assert.AreEqual(TempExpected.Count(), TempActual.Count(), 'The copy must propose as many lines as Microsoft.');
        Assert.IsTrue(TempExpected.Count() > 0, 'The oracle scenario must propose at least one line.');
        if TempExpected.FindSet() then
            repeat
                TempActual.SetRange("Subscription Line Entry No.", TempExpected."Subscription Line Entry No.");
                Assert.IsTrue(TempActual.FindFirst(), StrSubstNo('The copy did not propose Subscription Line %1.', TempExpected."Subscription Line Entry No."));
                AssertSameLine(TempExpected, TempActual);
            until TempExpected.Next() = 0;
        TempActual.Reset();
    end;

    local procedure AssertSameLine(Expected: Record "Sub. Contr. Price Update Line"; Actual: Record "Sub. Contr. Price Update Line")
    var
        ExpectedRef: RecordRef;
        ActualRef: RecordRef;
        ExpectedField: FieldRef;
        ActualField: FieldRef;
        i: Integer;
    begin
        ExpectedRef.GetTable(Expected);
        ActualRef.GetTable(Actual);
        for i := 1 to ExpectedRef.FieldCount() do begin
            ExpectedField := ExpectedRef.FieldIndex(i);
            if ExpectedField.Number() <> Expected.FieldNo("Entry No.") then
                if ExpectedField.Number() < 2000000000 then begin
                    ActualField := ActualRef.Field(ExpectedField.Number());
                    Assert.AreEqual(Format(ExpectedField.Value(), 0, 9), Format(ActualField.Value(), 0, 9),
                        StrSubstNo('Field %1 of the proposal line for Subscription Line %2 differs from Microsoft.', ExpectedField.Name(), Expected."Subscription Line Entry No."));
                end;
        end;
    end;

    /// <summary>Fails the test, quoting the answer's error, unless the answer is a Success.</summary>
    procedure AssertSuccess(ResponseJson: JsonObject; Context: Text)
    var
        ErrorToken: JsonToken;
        ErrorText: Text;
    begin
        if ResponseJson.Get('error', ErrorToken) then
            if ErrorToken.IsValue() then
                ErrorText := ErrorToken.AsValue().AsText();
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), Context + ' ' + ErrorText);
    end;

    /// <summary>Reads a text property of a JSON answer, failing the test when it is missing.</summary>
    procedure ReadText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, PropertyToken), 'Missing response property: ' + PropertyName);
        exit(PropertyToken.AsValue().AsText());
    end;

    /// <summary>Reads an integer property of a JSON answer, failing the test when it is missing.</summary>
    procedure ReadInteger(ResponseJson: JsonObject; PropertyName: Text): Integer
    var
        PropertyToken: JsonToken;
        ResponseText: Text;
    begin
        if not ResponseJson.Get(PropertyName, PropertyToken) then begin
            ResponseJson.WriteTo(ResponseText);
            Assert.Fail('Missing response property: ' + PropertyName + '. Answer: ' + CopyStr(ResponseText, 1, 800));
        end;
        exit(PropertyToken.AsValue().AsInteger());
    end;

    local procedure NewCode(Prefix: Text): Code[20]
    begin
        exit(CopyStr(Prefix + LibraryUtility.GenerateGUID(), 1, 20));
    end;
}
