namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Merges customer contract lines with Microsoft's eligibility rules and refuses a single line,
/// a comment line and lines from two contracts (#50). The oracle is table 8062 MergeContractLines
/// on microsoft/BCApps releases/28.x commit a674a13, without its selection page.
/// </summary>
codeunit 95720 "Sub Con Merge Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_AC01_MergeLines_ClosesTheSelectedLines_AndOpensOneMergedLine()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        NewHeader: Record "Subscription Header";
        ResponseJson: JsonObject;
        NewHeaderNo: Code[20];
    begin
        // Issue #50, AC01 | Time: lines start on WorkDate() | Risk: None
        // [GIVEN] Two equal customer contract lines on one contract
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);

        // [WHEN] Subscription.Contract.MergeLines merges them, copying the first line
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));

        // [THEN] Both selected lines are closed and one open line points at a Subscription whose quantity is the sum
        Assert.AreEqual('Success', TestLibrary.ReadText(ResponseJson, 'status'), TestLibrary.AsText(ResponseJson));
        Assert.AreEqual(2, TestLibrary.ReadInteger(ResponseJson, 'closedLineCount'), TestLibrary.AsText(ResponseJson));
        NewHeaderNo := CopyStr(TestLibrary.ReadText(ResponseJson, 'newSubscriptionHeaderNo'), 1, MaxStrLen(NewHeaderNo));
        NewHeader.Get(NewHeaderNo);
        NewHeader.TestField(Quantity, 2);
        AssertClosedCount(CustomerContract."No.", 2);
        AssertOpenCount(CustomerContract."No.", 1);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesASingleLine()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        ContractLine: Record "Cust. Sub. Contract Line";
    begin
        // Issue #50, AC02 | Time: none | Risk: None
        // [GIVEN] A contract with one line
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        ContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        ContractLine.FindFirst();

        // [WHEN] The call names only that line
        // [THEN] Microsoft's single-line refusal is raised and the line stays open
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", ContractLine."Line No.", ContractLine."Line No.", ContractLine."Line No."));
        Assert.ExpectedError('Please select the lines you want to combine.');
        ContractLine.Find();
        ContractLine.TestField(Closed, false);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesACommentLine()
    var
        CustomerContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        ContractLine: Record "Cust. Sub. Contract Line";
        CommentLine: Record "Cust. Sub. Contract Line";
    begin
        // Issue #50, AC02 | Time: none | Risk: None
        // [GIVEN] A contract line and a comment line
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        ContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        ContractLine.FindFirst();
        CommentLine.Init();
        CommentLine."Subscription Contract No." := CustomerContract."No.";
        CommentLine."Line No." := CommentLine.GetNextLineNo(CustomerContract."No.");
        CommentLine.Validate("Contract Line Type", Enum::"Contract Line Type"::Comment);
        CommentLine.Insert(true);

        // [WHEN] The call includes the comment
        // [THEN] Microsoft refuses text lines and the contract line stays open
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", ContractLine."Line No.", CommentLine."Line No.", ContractLine."Line No."));
        Assert.ExpectedError('Merging with text lines is not allowed.');
        ContractLine.Find();
        ContractLine.TestField(Closed, false);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesLinesFromDifferentContracts()
    var
        CustomerContract: Record "Customer Subscription Contract";
        OtherContract: Record "Customer Subscription Contract";
        SubscriptionHeader: Record "Subscription Header";
        OtherHeader: Record "Subscription Header";
        ContractLine: Record "Cust. Sub. Contract Line";
        OtherLine: Record "Cust. Sub. Contract Line";
        RequestJson: JsonObject;
        Lines: JsonArray;
    begin
        // Issue #50, AC02 | Time: none | Risk: None
        // [GIVEN] One line on each of two contracts
        TestLibrary.CreateBillableCustomerContract(CustomerContract, SubscriptionHeader, 0D);
        TestLibrary.CreateBillableCustomerContract(OtherContract, OtherHeader, 0D);
        ContractLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        ContractLine.FindFirst();
        OtherLine.SetRange("Subscription Contract No.", OtherContract."No.");
        OtherLine.FindFirst();
        RequestJson.Add('contractNo', CustomerContract."No.");
        Lines.Add(LineJson(CustomerContract."No.", ContractLine."Line No."));
        Lines.Add(LineJson(OtherContract."No.", OtherLine."Line No."));
        RequestJson.Add('lines', Lines);
        RequestJson.Add('referenceLineNo', ContractLine."Line No.");

        // [WHEN] The call names both contracts
        // [THEN] The lines are refused and both stay open
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", RequestJson);
        Assert.ExpectedError('more than one Customer Subscription Contract');
        ContractLine.Find();
        ContractLine.TestField(Closed, false);
        OtherLine.Find();
        OtherLine.TestField(Closed, false);
    end;

    local procedure CreateTwoLineContract(var CustomerContract: Record "Customer Subscription Contract"; var FirstLine: Record "Cust. Sub. Contract Line"; var SecondLine: Record "Cust. Sub. Contract Line")
    var
        Customer: Record Customer;
        Item: Record Item;
        SubscriptionPackage: Record "Subscription Package";
        FirstHeader: Record "Subscription Header";
        SecondHeader: Record "Subscription Header";
    begin
        TestLibrary.CreateCustomer(Customer);
        TestLibrary.CreateSubscriptionItem(Item);
        TestLibrary.CreatePackage(SubscriptionPackage, true, false, true);
        TestLibrary.AssignPackageToItem(Item."No.", SubscriptionPackage.Code, true);
        TestLibrary.SetContractAccounts(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        TestLibrary.CreateSubscription(FirstHeader, Item."No.", Customer."No.");
        TestLibrary.CreateSubscription(SecondHeader, Item."No.", Customer."No.");
        TestLibrary.RunLineCreate(FirstHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.RunLineCreate(SecondHeader."No.", SubscriptionPackage.Code, WorkDate(), 0D);
        TestLibrary.CreateCustomerContract(CustomerContract, Customer."No.");
        TestLibrary.RunGetLines(Enum::"Message Type ori"::"Subscription.Contract.GetLines", CustomerContract."No.");
        FirstLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        FirstLine.FindFirst();
        SecondLine.SetRange("Subscription Contract No.", CustomerContract."No.");
        SecondLine.SetFilter("Line No.", '<>%1', FirstLine."Line No.");
        SecondLine.FindFirst();
    end;

    local procedure MergeRequest(ContractNo: Code[20]; FirstLineNo: Integer; SecondLineNo: Integer; ReferenceLineNo: Integer) RequestJson: JsonObject
    var
        Lines: JsonArray;
    begin
        RequestJson.Add('contractNo', ContractNo);
        Lines.Add(LineJson(ContractNo, FirstLineNo));
        if SecondLineNo <> FirstLineNo then
            Lines.Add(LineJson(ContractNo, SecondLineNo));
        RequestJson.Add('lines', Lines);
        RequestJson.Add('referenceLineNo', ReferenceLineNo);
    end;

    local procedure LineJson(ContractNo: Code[20]; LineNo: Integer) LineObject: JsonObject
    begin
        LineObject.Add('contractNo', ContractNo);
        LineObject.Add('lineNo', LineNo);
    end;

    local procedure AssertClosedCount(ContractNo: Code[20]; Expected: Integer)
    var
        ContractLine: Record "Cust. Sub. Contract Line";
    begin
        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetRange(Closed, true);
        Assert.AreEqual(Expected, ContractLine.Count(), 'Closed contract lines.');
    end;

    local procedure AssertOpenCount(ContractNo: Code[20]; Expected: Integer)
    var
        ContractLine: Record "Cust. Sub. Contract Line";
    begin
        ContractLine.SetRange("Subscription Contract No.", ContractNo);
        ContractLine.SetRange(Closed, false);
        Assert.AreEqual(Expected, ContractLine.Count(), 'Open contract lines.');
    end;
}
