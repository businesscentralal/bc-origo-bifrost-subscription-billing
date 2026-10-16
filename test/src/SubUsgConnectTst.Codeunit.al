namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// #38: Subscription.Usage.ConnectSubscriptions connects supplier subscriptions through Microsoft's
/// public procedure, and Subscription.Usage.DisconnectSubscription removes the link again.
/// </summary>
codeunit 95713 "Sub Usg Connect Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLib: Codeunit "Sub Test Lib ori";
        PrefixTok: Label 'XSBA38', Locked = true;
        SupplierNoTok: Label 'XSBA38SUP', Locked = true;
        HeaderNoTok: Label 'XSBA38SUB', Locked = true;
        ContractNoTok: Label 'XSBA38CC', Locked = true;

    /// <summary>AC01, AC04: an entry set to Existing Subscription Lines is connected to the usage based line.</summary>
    [Test]
    procedure Connect_ExistingLines_ConnectsEntry()
    var
        SubscriptionLine: Record "Subscription Line";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        LineEntryNo: Integer;
        EntryNo: Integer;
        ReferenceEntryNo: Integer;
    begin
        // [GIVEN] A Subscription with a usage based line and a supplier subscription pointed at it
        Initialize();
        LineEntryNo := CreateUsageSubscription(true);
        EntryNo := CreateSupplierSubscription(Enum::"Connect To SO Method"::"Existing Service Commitments", ReferenceEntryNo);

        // [WHEN] The entry is connected
        EntryNos.Add(EntryNo);
        RequestJson.Add('entryNos', EntryNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", SupplierNoTok, RequestJson, false);

        // [THEN] One entry is connected and both sides carry the link
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'connected'), 'The entry must be connected.');
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'skipped'), 'Nothing may be skipped.');
        UsageDataSubscription.Get(EntryNo);
        Assert.AreEqual(LineEntryNo, UsageDataSubscription."Subscription Line Entry No.", 'The supplier subscription must point at the usage based line.');
        Assert.AreEqual(HeaderNoTok, UsageDataSubscription."Subscription Header No.", 'The supplier subscription must name the Subscription.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(ReferenceEntryNo, SubscriptionLine."Supplier Reference Entry No.", 'The line must carry the supplier reference.');
    end;

    /// <summary>AC04: connecting a supplier subscription lets its imported usage reach customer usage billing.</summary>
    [Test]
    procedure Connect_ThenProcess_CreatesUsageBilling()
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        UsageDataBilling: Record "Usage Data Billing";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        StepToken: JsonToken;
        StepsToken: JsonToken;
        StepText: Text;
        LineEntryNo: Integer;
        EntryNo: Integer;
        ReferenceEntryNo: Integer;
        ImportEntryNo: Integer;
    begin
        // [GIVEN] A supplier subscription and a self-created imported usage row, not connected yet
        Initialize();
        LineEntryNo := CreateUsageSubscription(true);
        EntryNo := CreateSupplierSubscription(Enum::"Connect To SO Method"::"Existing Service Commitments", ReferenceEntryNo);
        ImportEntryNo := CreateImportedUsage();

        // [WHEN] The imported row is processed before the supplier subscription is connected
        RequestJson.Add('usageDataImportEntryNo', ImportEntryNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.Process", '', RequestJson, false);

        // [THEN] No usage billing can be created, and the imported row records the missing connection
        TestLib.AssertSuccess(ResponseJson);
        UsageDataGenericImport.SetRange("Usage Data Import Entry No.", ImportEntryNo);
        Assert.IsTrue(UsageDataGenericImport.FindFirst(), 'The owned imported row must remain.');
        Assert.AreEqual(Enum::"Processing Status"::Error, UsageDataGenericImport."Processing Status", 'Processing an unconnected subscription must fail.');
        UsageDataBilling.SetRange("Usage Data Import Entry No.", ImportEntryNo);
        Assert.RecordIsEmpty(UsageDataBilling);

        // [WHEN] The message type connects the subscription, then Usage.Process retries all default stages
        Clear(RequestJson);
        EntryNos.Add(EntryNo);
        RequestJson.Add('entryNos', EntryNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", SupplierNoTok, RequestJson, false);
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'connected'), 'The supplier subscription must be connected.');
        Clear(RequestJson);
        RequestJson.Add('usageDataImportEntryNo', ImportEntryNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.Process", '', RequestJson, false);

        // [THEN] Every stage succeeds and only the connected customer's subscription receives the usage
        TestLib.AssertSuccess(ResponseJson);
        Assert.IsTrue(ResponseJson.Get('steps', StepsToken), 'Every executed stage must be reported.');
        Assert.AreEqual(3, StepsToken.AsArray().Count(), 'All three default processing stages must run.');
        foreach StepToken in StepsToken.AsArray() do begin
            StepToken.WriteTo(StepText);
            Assert.AreNotEqual('Error', TestLib.GetText(StepToken.AsObject(), 'status'), 'No processing stage may fail: ' + StepText);
        end;
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'usageDataBillingCount'), 'Exactly the self-created usage row must be billed.');
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'usageDataBillingErrorCount'), 'No usage billing may be in error.');
        UsageDataImport.Get(ImportEntryNo);
        Assert.AreNotEqual(Enum::"Processing Status"::Error, UsageDataImport."Processing Status", 'The import must no longer carry the pre-connection error.');
        UsageDataGenericImport.FindFirst();
        Assert.AreEqual(Enum::"Processing Status"::Ok, UsageDataGenericImport."Processing Status", 'The imported row must be processed.');
        Assert.AreEqual(HeaderNoTok, UsageDataGenericImport."Subscription Header No.", 'The imported row must resolve the connected subscription.');
        Assert.AreEqual(1, UsageDataBilling.Count(), 'No other subscription may receive this usage.');
        UsageDataBilling.FindFirst();
        Assert.AreEqual(Enum::"Service Partner"::Customer, UsageDataBilling.Partner, 'The usage must be assigned to the customer.');
        Assert.AreEqual(ContractNoTok, UsageDataBilling."Subscription Contract No.", 'The usage must be assigned to the owned contract.');
        Assert.AreEqual(LineEntryNo, UsageDataBilling."Subscription Line Entry No.", 'The usage must name the connected line.');
        Assert.AreEqual(1, UsageDataBilling.Quantity, 'The imported quantity must reach usage billing.');
    end;

    /// <summary>AC01, edge: a Subscription without usage based lines is skipped with Microsoft's reason, not refused.</summary>
    [Test]
    procedure Connect_NoUsageBasedLine_IsSkippedWithReason()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        ReferenceEntryNo: Integer;
        ResponseText: Text;
    begin
        // [GIVEN] A supplier subscription pointed at a Subscription whose line is not usage based
        Initialize();
        CreateUsageSubscription(false);
        CreateSupplierSubscription(Enum::"Connect To SO Method"::"Existing Service Commitments", ReferenceEntryNo);

        // [WHEN] Every eligible entry of the supplier is connected
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", SupplierNoTok, RequestJson, false);

        // [THEN] The call succeeds, the entry is skipped, and a reason is given
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(0, TestLib.GetInteger(ResponseJson, 'connected'), 'Nothing can be connected.');
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'skipped'), 'The entry must be skipped.');
        ResponseJson.WriteTo(ResponseText);
        Assert.IsFalse(ResponseText.Contains('"reason":""'), 'A skipped entry must carry a reason: ' + ResponseText);
    end;

    /// <summary>AC03, AC06: a listed entry without a connect method is refused by name.</summary>
    [Test]
    procedure Connect_EntryWithoutMethod_IsRefused()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        ReferenceEntryNo: Integer;
    begin
        // [GIVEN] A supplier subscription without Connect to Sub. Header No.
        Initialize();
        CreateUsageSubscription(true);
        EntryNos.Add(CreateSupplierSubscription(Enum::"Connect To SO Method"::None, ReferenceEntryNo));

        // [WHEN] It is listed for connecting
        RequestJson.Add('entryNos', EntryNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", SupplierNoTok, RequestJson, false);

        // [THEN] The call is refused and says what to set first
        TestLib.AssertRefused(ResponseJson, 'Connect to Sub. Header No.');
    end;

    /// <summary>AC03, AC06: an entry that is already connected, and an unknown supplier, are refused.</summary>
    [Test]
    procedure Connect_AlreadyConnectedOrUnknownSupplier_IsRefused()
    var
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EntryNos: JsonArray;
        EntryNo: Integer;
        ReferenceEntryNo: Integer;
    begin
        // [GIVEN] A supplier subscription that is connected already
        Initialize();
        EntryNo := CreateSupplierSubscription(Enum::"Connect To SO Method"::"Existing Service Commitments", ReferenceEntryNo);
        UsageDataSubscription.Get(EntryNo);
        UsageDataSubscription."Subscription Line Entry No." := CreateUsageSubscription(true);
        UsageDataSubscription.Modify(false);
        Commit();

        // [WHEN] It is listed for connecting
        EntryNos.Add(EntryNo);
        RequestJson.Add('entryNos', EntryNos);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", SupplierNoTok, RequestJson, false);

        // [THEN] The call is refused and points to the disconnect type
        TestLib.AssertRefused(ResponseJson, 'Subscription.Usage.DisconnectSubscription');

        // [WHEN] An unknown supplier is named
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.ConnectSubscriptions", 'XSBA38NONE', RequestJson, false);

        // [THEN] The supplier is named in the refusal
        TestLib.AssertRefused(ResponseJson, 'XSBA38NONE');
    end;

    /// <summary>AC02, AC04: disconnecting removes the link on the line and on the supplier subscription.</summary>
    [Test]
    procedure Disconnect_ConnectedLine_RemovesLink()
    var
        SubscriptionLine: Record "Subscription Line";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        LineEntryNo: Integer;
        EntryNo: Integer;
        ReferenceEntryNo: Integer;
    begin
        // [GIVEN] A connected usage based line
        Initialize();
        LineEntryNo := CreateUsageSubscription(true);
        EntryNo := CreateSupplierSubscription(Enum::"Connect To SO Method"::"Existing Service Commitments", ReferenceEntryNo);
        ConnectRaw(EntryNo, LineEntryNo, ReferenceEntryNo);

        // [WHEN] The line is disconnected
        RequestJson.Add('subscriptionLineEntryNo', LineEntryNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DisconnectSubscription", '', RequestJson, false);

        // [THEN] Both sides lost the link
        TestLib.AssertSuccess(ResponseJson);
        Assert.AreEqual(EntryNo, TestLib.GetInteger(ResponseJson, 'usageDataSubscriptionEntryNo'), 'The supplier subscription must be reported.');
        Assert.AreEqual(1, TestLib.GetInteger(ResponseJson, 'linesDisconnected'), 'One line must be disconnected.');
        SubscriptionLine.Get(LineEntryNo);
        Assert.AreEqual(0, SubscriptionLine."Supplier Reference Entry No.", 'The line must no longer carry the supplier reference.');
        UsageDataSubscription.Get(EntryNo);
        Assert.AreEqual(0, UsageDataSubscription."Subscription Line Entry No.", 'The supplier subscription must no longer point at the line.');
        Assert.AreEqual('', UsageDataSubscription."Subscription Header No.", 'The supplier subscription must no longer name the Subscription.');
    end;

    /// <summary>AC03, AC06, edge: a line that is not connected, and a call without either entry number, are refused.</summary>
    [Test]
    procedure Disconnect_NotConnectedOrNoParameter_IsRefused()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
        EmptyJson: JsonObject;
        LineEntryNo: Integer;
    begin
        // [GIVEN] A usage based line that is not connected
        Initialize();
        LineEntryNo := CreateUsageSubscription(true);

        // [WHEN] It is disconnected
        RequestJson.Add('subscriptionLineEntryNo', LineEntryNo);
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DisconnectSubscription", '', RequestJson, false);

        // [THEN] The call is refused because nothing is connected
        TestLib.AssertRefused(ResponseJson, 'is not connected');

        // [WHEN] Neither entry number is sent
        ResponseJson := TestLib.Invoke(Enum::"Message Type ori"::"Subscription.Usage.DisconnectSubscription", '', EmptyJson, false);

        // [THEN] The call names both parameters
        TestLib.AssertRefused(ResponseJson, 'usageDataSubscriptionEntryNo');
    end;

    local procedure Initialize()
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataSupplierReference: Record "Usage Data Supplier Reference";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
        UsageDataImport: Record "Usage Data Import";
        UsageDataGenericImport: Record "Usage Data Generic Import";
        UsageDataBilling: Record "Usage Data Billing";
        GenericImportSettings: Record "Generic Import Settings";
    begin
        UsageDataImport.SetRange("Supplier No.", SupplierNoTok);
        if UsageDataImport.FindSet() then
            repeat
                UsageDataBilling.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");
                UsageDataBilling.DeleteAll(true);
                UsageDataGenericImport.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");
                UsageDataGenericImport.DeleteAll(false);
            until UsageDataImport.Next() = 0;
        UsageDataImport.DeleteAll(false);
        GenericImportSettings.SetRange("Usage Data Supplier No.", SupplierNoTok);
        GenericImportSettings.DeleteAll(false);
        UsageDataSubscription.SetRange("Supplier No.", SupplierNoTok);
        UsageDataSubscription.DeleteAll(false);
        UsageDataSupplierReference.SetRange("Supplier No.", SupplierNoTok);
        UsageDataSupplierReference.DeleteAll(false);
        UsageDataSupplier.SetRange("No.", SupplierNoTok);
        UsageDataSupplier.DeleteAll(false);
        TestLib.DeleteFixture(PrefixTok);
        UsageDataSupplier.Init();
        UsageDataSupplier."No." := SupplierNoTok;
        UsageDataSupplier.Description := 'X Branch A usage supplier';
        UsageDataSupplier.Type := UsageDataSupplier.Type::Generic;
        UsageDataSupplier.Insert(false);
        Commit();
    end;

    /// <summary>Seeds an already imported generic usage row; file parsing belongs to Usage.ImportData tests.</summary>
    local procedure CreateImportedUsage(): Integer
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        GenericImportSettings: Record "Generic Import Settings";
        UsageDataImport: Record "Usage Data Import";
        UsageDataGenericImport: Record "Usage Data Generic Import";
    begin
        UsageDataSupplier.Get(SupplierNoTok);
        UsageDataSupplier."Unit Price from Import" := true;
        UsageDataSupplier.Modify(false);
        GenericImportSettings.Init();
        GenericImportSettings."Usage Data Supplier No." := SupplierNoTok;
        GenericImportSettings.Insert(false);
        UsageDataImport.Init();
        UsageDataImport."Supplier No." := SupplierNoTok;
        UsageDataImport.Insert(false);
        UsageDataGenericImport.Init();
        UsageDataGenericImport."Usage Data Import Entry No." := UsageDataImport."Entry No.";
        UsageDataGenericImport."Supp. Subscription ID" := 'XSBA38REF';
        UsageDataGenericImport."Supp. Subscription Start Date" := WorkDate();
        UsageDataGenericImport."Billing Period Start Date" := WorkDate();
        UsageDataGenericImport."Billing Period End Date" := CalcDate('<CM>', WorkDate());
        UsageDataGenericImport.Quantity := 1;
        UsageDataGenericImport.Insert(false);
        Commit();
        exit(UsageDataImport."Entry No.");
    end;

    /// <summary>Seeds a Subscription of type Item under a customer contract with one line, usage based or not.</summary>
    local procedure CreateUsageSubscription(UsageBased: Boolean) LineEntryNo: Integer
    var
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
    begin
        if not SubscriptionHeader.Get(HeaderNoTok) then begin
            TestLib.CreateSubscriptionHeader(HeaderNoTok);
            SubscriptionHeader.Get(HeaderNoTok);
            SubscriptionHeader.Type := SubscriptionHeader.Type::Item;
            SubscriptionHeader."Source No." := 'XSBA38ITEM';
            SubscriptionHeader.Modify(false);
            TestLib.CreateCustomerContract(ContractNoTok, '');
        end;
        LineEntryNo := TestLib.CreateSubscriptionLine(HeaderNoTok, Enum::"Service Partner"::Customer, ContractNoTok, WorkDate(), 0D, WorkDate());
        SubscriptionLine.Get(LineEntryNo);
        SubscriptionLine."Usage Based Billing" := UsageBased;
        if UsageBased then
            SubscriptionLine."Usage Based Pricing" := Enum::"Usage Based Pricing"::"Usage Quantity";
        SubscriptionLine.Modify(false);
        TestLib.CreateCustomerContractLine(ContractNoTok, HeaderNoTok, LineEntryNo);
        Commit();
    end;

    /// <summary>Seeds a supplier reference and a supplier subscription pointed at the fixture Subscription.</summary>
    local procedure CreateSupplierSubscription(Method: Enum "Connect To SO Method"; var ReferenceEntryNo: Integer) EntryNo: Integer
    var
        UsageDataSupplierReference: Record "Usage Data Supplier Reference";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
    begin
        UsageDataSupplierReference.Init();
        UsageDataSupplierReference."Supplier No." := SupplierNoTok;
        UsageDataSupplierReference.Type := UsageDataSupplierReference.Type::Subscription;
        UsageDataSupplierReference."Supplier Reference" := 'XSBA38REF';
        UsageDataSupplierReference.Insert(false);
        ReferenceEntryNo := UsageDataSupplierReference."Entry No.";

        UsageDataSubscription.Init();
        UsageDataSubscription."Supplier No." := SupplierNoTok;
        UsageDataSubscription."Supplier Reference" := 'XSBA38REF';
        UsageDataSubscription."Supplier Reference Entry No." := ReferenceEntryNo;
        if Method <> Method::None then
            UsageDataSubscription."Connect to Sub. Header No." := HeaderNoTok;
        UsageDataSubscription."Connect to Sub. Header Method" := Method;
        UsageDataSubscription.Insert(false);
        EntryNo := UsageDataSubscription."Entry No.";
        Commit();
    end;

    local procedure ConnectRaw(EntryNo: Integer; LineEntryNo: Integer; ReferenceEntryNo: Integer)
    var
        SubscriptionLine: Record "Subscription Line";
        UsageDataSubscription: Record "Usage Data Supp. Subscription";
    begin
        SubscriptionLine.Get(LineEntryNo);
        SubscriptionLine."Supplier Reference Entry No." := ReferenceEntryNo;
        SubscriptionLine.Modify(false);
        UsageDataSubscription.Get(EntryNo);
        UsageDataSubscription."Subscription Header No." := HeaderNoTok;
        UsageDataSubscription."Subscription Line Entry No." := LineEntryNo;
        UsageDataSubscription."Connect to Sub. Header No." := '';
        UsageDataSubscription."Connect to Sub. Header Method" := UsageDataSubscription."Connect to Sub. Header Method"::None;
        UsageDataSubscription.Modify(false);
        Commit();
    end;
}
