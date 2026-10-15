namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Shared fixture and dispatch helpers for the Branch A operation tests (#36, #37, #38, #40, #41).
/// Every type is called through the public Dispatcher ori, and every record a test seeds starts
/// with the X prefix so a later Initialize can remove it, also after a type committed it.
/// </summary>
codeunit 95710 "Sub Test Lib ori"
{
    Access = Internal;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Dispatches a message type with a JSON request and returns the parsed JSON answer.</summary>
    /// <param name="MessageType">The type to run.</param>
    /// <param name="Subject">The subject, or empty.</param>
    /// <param name="RequestJson">The data object of the request.</param>
    /// <param name="OmitCommit">True to run inside the caller's transaction; false for types that commit.</param>
    /// <returns>The response JSON.</returns>
    procedure Invoke(MessageType: Enum "Message Type ori"; Subject: Text[250]; RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
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
        Dispatcher.Execute(MessageType, Enum::"Message Version ori"::"1.0", Subject, 'XSBA', 'application/json',
            RequestContent, ResponseContent, ResponseContentType, OmitCommit);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The dispatcher must answer with JSON: ' + ResponseText);
    end;

    /// <summary>Reads a text property of a response; fails when it is missing.</summary>
    procedure GetText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads an integer property of a response; fails when it is missing.</summary>
    procedure GetInteger(ResponseJson: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Reads a boolean property of a response; fails when it is missing.</summary>
    procedure GetBoolean(ResponseJson: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Asserts a structured error answer whose error text contains the expected fragment.</summary>
    procedure AssertRefused(ResponseJson: JsonObject; ExpectedFragment: Text)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', GetText(ResponseJson, 'status'), 'Expected a refusal: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains(ExpectedFragment), 'The refusal must say ''' + ExpectedFragment + ''': ' + ResponseText);
    end;

    /// <summary>Asserts a Success answer, showing the whole answer when it is not.</summary>
    procedure AssertSuccess(ResponseJson: JsonObject)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', GetText(ResponseJson, 'status'), 'Expected Success: ' + ResponseText);
    end;

    /// <summary>Inserts a bare Subscription Header without running its triggers.</summary>
    procedure CreateSubscriptionHeader(HeaderNo: Code[20])
    var
        SubscriptionHeader: Record "Subscription Header";
    begin
        SubscriptionHeader.Init();
        SubscriptionHeader."No." := HeaderNo;
        SubscriptionHeader.Description := 'X Branch A fixture';
        SubscriptionHeader.Quantity := 1;
        SubscriptionHeader.Insert(false);
    end;

    /// <summary>Inserts a Subscription Line without running its triggers and returns its entry number.</summary>
    procedure CreateSubscriptionLine(HeaderNo: Code[20]; Partner: Enum "Service Partner"; ContractNo: Code[20]; StartDate: Date; EndDate: Date; NextBillingDate: Date) EntryNo: Integer
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        SubscriptionLine.Init();
        SubscriptionLine."Subscription Header No." := HeaderNo;
        SubscriptionLine.Partner := Partner;
        SubscriptionLine."Subscription Contract No." := ContractNo;
        SubscriptionLine."Subscription Package Code" := 'XSBAPKG';
        SubscriptionLine.Description := 'X Branch A line';
        SubscriptionLine."Subscription Line Start Date" := StartDate;
        SubscriptionLine."Subscription Line End Date" := EndDate;
        SubscriptionLine."Next Billing Date" := NextBillingDate;
        SubscriptionLine."Invoicing via" := SubscriptionLine."Invoicing via"::Contract;
        SubscriptionLine.Insert(false);
        exit(SubscriptionLine."Entry No.");
    end;

    /// <summary>Inserts a bare Customer Subscription Contract.</summary>
    procedure CreateCustomerContract(ContractNo: Code[20]; CustomerNo: Code[20])
    var
        CustomerContract: Record "Customer Subscription Contract";
    begin
        CustomerContract.Init();
        CustomerContract."No." := ContractNo;
        CustomerContract."Sell-to Customer No." := CustomerNo;
        CustomerContract."Bill-to Customer No." := CustomerNo;
        CustomerContract.Insert(false);
    end;

    /// <summary>Inserts a Cust. Sub. Contract Line pointing at a Subscription Line and returns its line number.</summary>
    procedure CreateCustomerContractLine(ContractNo: Code[20]; HeaderNo: Code[20]; SubscriptionLineEntryNo: Integer) LineNo: Integer
    var
        CustSubContractLine: Record "Cust. Sub. Contract Line";
    begin
        CustSubContractLine.SetRange("Subscription Contract No.", ContractNo);
        if CustSubContractLine.FindLast() then
            LineNo := CustSubContractLine."Line No.";
        LineNo += 10000;
        CustSubContractLine.Init();
        CustSubContractLine."Subscription Contract No." := ContractNo;
        CustSubContractLine."Line No." := LineNo;
        CustSubContractLine."Contract Line Type" := CustSubContractLine."Contract Line Type"::Item;
        CustSubContractLine."Subscription Header No." := HeaderNo;
        CustSubContractLine."Subscription Line Entry No." := SubscriptionLineEntryNo;
        CustSubContractLine.Insert(false);
        UpdateLineContractLineNo(SubscriptionLineEntryNo, LineNo);
    end;

    /// <summary>Inserts a bare Vendor Subscription Contract.</summary>
    procedure CreateVendorContract(ContractNo: Code[20]; VendorNo: Code[20])
    var
        VendorContract: Record "Vendor Subscription Contract";
    begin
        VendorContract.Init();
        VendorContract."No." := ContractNo;
        VendorContract."Buy-from Vendor No." := VendorNo;
        VendorContract."Pay-to Vendor No." := VendorNo;
        VendorContract.Insert(false);
    end;

    /// <summary>Inserts a Vend. Sub. Contract Line pointing at a Subscription Line and returns its line number.</summary>
    procedure CreateVendorContractLine(ContractNo: Code[20]; HeaderNo: Code[20]; SubscriptionLineEntryNo: Integer) LineNo: Integer
    var
        VendSubContractLine: Record "Vend. Sub. Contract Line";
    begin
        VendSubContractLine.SetRange("Subscription Contract No.", ContractNo);
        if VendSubContractLine.FindLast() then
            LineNo := VendSubContractLine."Line No.";
        LineNo += 10000;
        VendSubContractLine.Init();
        VendSubContractLine."Subscription Contract No." := ContractNo;
        VendSubContractLine."Line No." := LineNo;
        VendSubContractLine."Contract Line Type" := VendSubContractLine."Contract Line Type"::Item;
        VendSubContractLine."Subscription Header No." := HeaderNo;
        VendSubContractLine."Subscription Line Entry No." := SubscriptionLineEntryNo;
        VendSubContractLine.Insert(false);
        UpdateLineContractLineNo(SubscriptionLineEntryNo, LineNo);
    end;

    /// <summary>
    /// Removes every record of a fixture: Subscription Headers, Subscription Lines, contracts and contract lines
    /// whose number starts with the prefix, and the billing lines of those contracts. Runs without triggers.
    /// </summary>
    procedure DeleteFixture(Prefix: Text)
    var
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        CustomerContract: Record "Customer Subscription Contract";
        CustSubContractLine: Record "Cust. Sub. Contract Line";
        VendorContract: Record "Vendor Subscription Contract";
        VendSubContractLine: Record "Vend. Sub. Contract Line";
        BillingLine: Record "Billing Line";
        SubscriptionLineArchive: Record "Subscription Line Archive";
    begin
        SubscriptionLineArchive.SetFilter("Subscription Header No.", Prefix + '*');
        SubscriptionLineArchive.DeleteAll(false);
        BillingLine.SetFilter("Subscription Contract No.", Prefix + '*');
        BillingLine.DeleteAll(false);
        SubscriptionLine.SetFilter("Subscription Header No.", Prefix + '*');
        SubscriptionLine.DeleteAll(false);
        SubscriptionHeader.SetFilter("No.", Prefix + '*');
        SubscriptionHeader.DeleteAll(false);
        CustSubContractLine.SetFilter("Subscription Contract No.", Prefix + '*');
        CustSubContractLine.DeleteAll(false);
        CustomerContract.SetFilter("No.", Prefix + '*');
        CustomerContract.DeleteAll(false);
        VendSubContractLine.SetFilter("Subscription Contract No.", Prefix + '*');
        VendSubContractLine.DeleteAll(false);
        VendorContract.SetFilter("No.", Prefix + '*');
        VendorContract.DeleteAll(false);
    end;

    local procedure UpdateLineContractLineNo(SubscriptionLineEntryNo: Integer; LineNo: Integer)
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        if SubscriptionLineEntryNo = 0 then
            exit;
        if not SubscriptionLine.Get(SubscriptionLineEntryNo) then
            exit;
        SubscriptionLine."Subscription Contract Line No." := LineNo;
        SubscriptionLine.Modify(false);
    end;
}
