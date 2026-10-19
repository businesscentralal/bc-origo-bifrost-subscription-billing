namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Merges customer contract lines with Microsoft's eligibility rules and refuses a single line,
/// a comment line, lines from two contracts, and the cases Microsoft's merge refuses: a different
/// Next Billing Date, different dimensions, existing billing lines, a serial number and a different
/// Customer Reference (#50). The oracle is table 8062 MergeContractLines and codeunit 8059 on
/// microsoft/BCApps releases/28.x commit a674a13, without its selection page.
/// </summary>
codeunit 95720 "Sub Con Merge Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";
        LibraryDimension: Codeunit "Library - Dimension";

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
    procedure Scenario_AC01_MergeLines_ResultMatchesMicrosoftMerge()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        NewContractLine: Record "Cust. Sub. Contract Line";
        ReferenceSubscriptionLine: Record "Subscription Line";
        OldSubscriptionLine: Record "Subscription Line";
        NewSubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
        ReferenceNextBillingDate: Date;
    begin
        // Issue #50, AC01/AC03 oracle: Microsoft's merge copies the reference Subscription Line onto a new
        // Subscription with the summed quantity, starting on the reference Next Billing Date, and closes the
        // old Subscription Lines at their Next Billing Date | Time: lines start on WorkDate() | Risk: None
        // [GIVEN] Two equal customer contract lines on one contract
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        SecondLine.GetServiceCommitment(ReferenceSubscriptionLine);
        ReferenceNextBillingDate := ReferenceSubscriptionLine."Next Billing Date";

        // [WHEN] Subscription.Contract.MergeLines merges them, copying the second line
        ResponseJson := TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", SecondLine."Line No."));
        Assert.AreEqual('Success', TestLibrary.ReadText(ResponseJson, 'status'), TestLibrary.AsText(ResponseJson));
        Assert.AreEqual(SecondLine."Line No.", TestLibrary.ReadInteger(ResponseJson, 'referenceLineNo'), 'The answer must name the reference line.');

        // [THEN] The new open contract line points at the new Subscription and Subscription Line
        NewContractLine.Get(CustomerContract."No.", TestLibrary.ReadInteger(ResponseJson, 'newLineNo'));
        NewContractLine.TestField(Closed, false);
        NewContractLine.TestField("Subscription Header No.", CopyStr(TestLibrary.ReadText(ResponseJson, 'newSubscriptionHeaderNo'), 1, 20));
        NewSubscriptionLine.Get(TestLibrary.ReadInteger(ResponseJson, 'newSubscriptionLineEntryNo'));
        NewContractLine.TestField("Subscription Line Entry No.", NewSubscriptionLine."Entry No.");
        // [THEN] The new Subscription Line copies the reference price and starts on its Next Billing Date
        NewSubscriptionLine.TestField(Price, ReferenceSubscriptionLine.Price);
        NewSubscriptionLine.TestField("Calculation Base Amount", ReferenceSubscriptionLine."Calculation Base Amount");
        NewSubscriptionLine.TestField("Subscription Line Start Date", ReferenceNextBillingDate);
        NewSubscriptionLine.TestField("Subscription Contract No.", CustomerContract."No.");
        Assert.AreEqual(ReferenceSubscriptionLine.Price * 2, NewSubscriptionLine.Amount, 'Amount must be the price times the summed quantity.');
        // [THEN] The old Subscription Lines end on their former Next Billing Date and are closed
        FirstLine.Find();
        FirstLine.TestField(Closed, true);
        FirstLine.GetServiceCommitment(OldSubscriptionLine);
        OldSubscriptionLine.TestField(Closed, true);
        OldSubscriptionLine.TestField("Next Billing Date", 0D);
        OldSubscriptionLine.TestField("Subscription Line End Date", ReferenceNextBillingDate);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesDifferentNextBillingDate()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
    begin
        // Issue #50, AC02 oracle: Microsoft's ContractLinesWithDifferentNextBillingDateSelectedErr | Time: WorkDate() | Risk: None
        // [GIVEN] Two contract lines whose Subscription Lines bill on different dates
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        SecondLine.GetServiceCommitment(SubscriptionLine);
        SubscriptionLine."Next Billing Date" := CalcDate('<+1D>', SubscriptionLine."Next Billing Date");
        SubscriptionLine.Modify(false);

        // [WHEN] The lines are merged
        // [THEN] Microsoft's refusal is raised and nothing is closed
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));
        Assert.ExpectedError('There is a different Next Billing Date for the Contract Lines.');
        AssertClosedCount(CustomerContract."No.", 0);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesDifferentDimensions()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        SubscriptionLine: Record "Subscription Line";
        DimensionValue: Record "Dimension Value";
    begin
        // Issue #50, AC02 oracle: Microsoft's ContractLinesWithDifferentDimensionSelectedErr | Time: WorkDate() | Risk: None
        // [GIVEN] Two contract lines whose Subscription Lines carry different dimension sets
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        SecondLine.GetServiceCommitment(SubscriptionLine);
        SubscriptionLine."Dimension Set ID" := LibraryDimension.CreateDimSet(SubscriptionLine."Dimension Set ID", DimensionValue."Dimension Code", DimensionValue.Code);
        SubscriptionLine.Modify(false);

        // [WHEN] The lines are merged
        // [THEN] Microsoft's refusal is raised and nothing is closed
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));
        Assert.ExpectedError('There are different dimension values for the Contract Lines.');
        AssertClosedCount(CustomerContract."No.", 0);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesExistingBillingLines()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        BillingLine: Record "Billing Line";
    begin
        // Issue #50, AC02 oracle: Microsoft's BillingLinesForSelectedContractLinesExistsErr | Time: WorkDate() | Risk: None
        // [GIVEN] Two contract lines, and a billing line on the second
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        BillingLine.Init();
        BillingLine.Partner := BillingLine.Partner::Customer;
        BillingLine."Subscription Contract No." := CustomerContract."No.";
        BillingLine."Subscription Contract Line No." := SecondLine."Line No.";
        BillingLine.Insert(false);

        // [WHEN] The lines are merged
        // [THEN] Microsoft's refusal is raised and nothing is closed
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));
        Assert.ExpectedError('Delete the Billing Lines before merging the Contract Lines.');
        AssertClosedCount(CustomerContract."No.", 0);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesSerialNo()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        SubscriptionHeader: Record "Subscription Header";
    begin
        // Issue #50, AC02 oracle: Microsoft's LinesWithSerialNoCannotBeMergedErr | Time: WorkDate() | Risk: None
        // [GIVEN] Two contract lines, the second Subscription with a serial number
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        SubscriptionHeader.Get(SecondLine."Subscription Header No.");
        SubscriptionHeader."Serial No." := 'XSERIAL-1';
        SubscriptionHeader.Modify(false);

        // [WHEN] The lines are merged
        // [THEN] Microsoft's refusal is raised and nothing is closed
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));
        Assert.ExpectedError('Contract lines cannot be merged if Serial No. is entered into Subscription.');
        AssertClosedCount(CustomerContract."No.", 0);
    end;

    [Test]
    procedure Scenario_AC02_MergeLines_RefusesDifferentCustomerReference()
    var
        CustomerContract: Record "Customer Subscription Contract";
        FirstLine: Record "Cust. Sub. Contract Line";
        SecondLine: Record "Cust. Sub. Contract Line";
        SubscriptionHeader: Record "Subscription Header";
    begin
        // Issue #50, AC02 oracle: Microsoft's ContractLineWithDifferentCustRefCannotBeMergedErr | Time: WorkDate() | Risk: None
        // [GIVEN] Two contract lines whose Subscriptions have different Customer References
        CreateTwoLineContract(CustomerContract, FirstLine, SecondLine);
        SubscriptionHeader.Get(SecondLine."Subscription Header No.");
        SubscriptionHeader."Customer Reference" := 'XREF-OTHER';
        SubscriptionHeader.Modify(false);

        // [WHEN] The lines are merged
        // [THEN] Microsoft's refusal is raised and nothing is closed
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Contract.MergeLines", MergeRequest(CustomerContract."No.", FirstLine."Line No.", SecondLine."Line No.", FirstLine."Line No."));
        Assert.ExpectedError('Subscription Lines from Subscriptions with different Customer References cannot be merged.');
        AssertClosedCount(CustomerContract."No.", 0);
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
