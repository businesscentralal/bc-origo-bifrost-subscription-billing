namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>PR #25 B2: exercises the public dispatcher and persisted price update template filters.</summary>
codeunit 95708 "Sub PU Filter Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TemplateCodeTok: Label 'XPR25FILTER', Locked = true;

    /// <summary>A valid customer contract filter persists and selects only the intended fixture.</summary>
    [Test]
    procedure Filter_ValidCustomerContract_PersistsOnlyMatchingView()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ResponseJson: JsonObject;
        StoredView: Text;
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        // [GIVEN] Two contracts and a customer price update template.
        Initialize(false);
        CreateCustomerContract('XPR25MATCH');
        CreateCustomerContract('XPR25OTHER');
        // [WHEN] The public message entry point receives a valid view.
        ResponseJson := InvokeFilter('contract', 'WHERE("No."=FILTER(XPR25MATCH))', true);
        // [THEN] The persisted view matches only the intended row and other Blobs survive.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Expected a successful filter write.');
        StoredView := ReadStoredFilter('contract');
        Assert.AreEqual(ReadText(ResponseJson, 'filter'), StoredView, 'Response must match persisted view.');
        CustomerContract.SetView(StoredView);
        Assert.AreEqual(1, CustomerContract.Count(), 'Stored filter must not broaden the intended rows.');
        CustomerContract.ReadIsolation := IsolationLevel::ReadCommitted;
        CustomerContract.FindFirst();
        Assert.AreEqual('XPR25MATCH', CustomerContract."No.", 'Wrong contract selected.');
        AssertOtherFiltersUnchanged('contract');
    end;

    /// <summary>Vendor templates validate against the vendor contract table.</summary>
    [Test]
    procedure Filter_ValidVendorContract_PersistsVendorView()
    var
        VendorContract: Record "Vendor Subscription Contract";
        ResponseJson: JsonObject;
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        // [GIVEN] A vendor template and two vendor contracts.
        Initialize(true);
        VendorContract.Init();
        VendorContract."No." := 'XPR25VENDOR';
        VendorContract.Insert(false);
        VendorContract.Init();
        VendorContract."No." := 'XPR25VOTHER';
        VendorContract.Insert(false);
        // [WHEN] A valid vendor contract filter is dispatched.
        ResponseJson := InvokeFilter('contract', 'WHERE("No."=FILTER(XPR25VENDOR))', true);
        // [THEN] The vendor view selects only the intended vendor contract.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Vendor filter must succeed.');
        VendorContract.Reset();
        VendorContract.SetView(ReadStoredFilter('contract'));
        Assert.AreEqual(1, VendorContract.Count(), 'Vendor view must select one contract.');
        VendorContract.ReadIsolation := IsolationLevel::ReadCommitted;
        VendorContract.FindFirst();
        Assert.AreEqual('XPR25VENDOR', VendorContract."No.", 'Wrong vendor contract selected.');
        AssertOtherFiltersUnchanged('contract');
    end;

    /// <summary>Subscription and line targets persist independently.</summary>
    [Test]
    procedure Filter_ValidSubscriptionAndLine_ChangesOnlySelectedBlob()
    var
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionLine: Record "Subscription Line";
        ResponseJson: JsonObject;
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        // [GIVEN] A template with independent Blob values.
        Initialize(false);
        SubscriptionHeader.SetRange("No.", 'XPR25SUB');
        // [WHEN] A subscription filter is dispatched.
        ResponseJson := InvokeFilter('subscription', SubscriptionHeader.GetView(true), true);
        // [THEN] Only that Blob is replaced.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Subscription filter must succeed.');
        Assert.AreEqual(SubscriptionHeader.GetView(false), ReadStoredFilter('subscription'), 'Wrong subscription view.');
        AssertOtherFiltersUnchanged('subscription');
        Initialize(false);
        SubscriptionLine.SetRange("Entry No.", 987654321);
        ResponseJson := InvokeFilter('line', SubscriptionLine.GetView(true), true);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Line filter must succeed.');
        Assert.AreEqual(SubscriptionLine.GetView(false), ReadStoredFilter('line'), 'Wrong line view.');
        AssertOtherFiltersUnchanged('line');
    end;

    /// <summary>Unknown WHERE fields fail closed, including when a valid filter precedes them.</summary>
    [Test]
    procedure Filter_UnknownWhereField_ReturnsErrorAndPreservesState()
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        AssertRejectedFilter('WHERE("No."=FILTER(XPR25MATCH),MistypedField=FILTER(1))');
    end;

    /// <summary>Unknown SORTING fields cannot broaden the stored view.</summary>
    [Test]
    procedure Filter_UnknownSortingField_ReturnsErrorAndPreservesState()
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        AssertRejectedFilter('SORTING(MistypedField) WHERE("No."=FILTER(XPR25MATCH))');
    end;

    /// <summary>Malformed parentheses produce a structured failure without a write.</summary>
    [Test]
    procedure Filter_UnbalancedView_ReturnsErrorAndPreservesState()
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        AssertRejectedFilter('WHERE("No."=FILTER(XPR25MATCH)');
    end;

    /// <summary>A non-view string cannot replace an existing filter.</summary>
    [Test]
    procedure Filter_NotAView_ReturnsErrorAndPreservesState()
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        AssertRejectedFilter('123');
    end;

    /// <summary>An empty filter clears only the selected Blob; an absent required property fails without writing.</summary>
    [Test]
    procedure Filter_EmptyClearsAndMissingRequiredValue_DoesNotWrite()
    var
        ResponseJson: JsonObject;
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        // [GIVEN] Existing template filters.
        Initialize(false);
        // [WHEN] The required filter property contains an empty string.
        ResponseJson := InvokeFilter('contract', '', true);
        // [THEN] The selected Blob is cleared; the other filters are preserved.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'An empty string is a valid clear operation.');
        Assert.AreEqual('', ReadStoredFilter('contract'), 'Empty input must clear only the selected Blob.');
        AssertOtherFiltersUnchanged('contract');
        Initialize(false);
        // [WHEN] The required property is absent, the request fails before any write.
        ResponseJson := InvokeFilter('contract', '', false);
        Assert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'Missing filter remains required.');
        AssertAllFiltersUnchanged();
    end;

    /// <summary>A valid view without filters explicitly clears only the selected Blob.</summary>
    [Test]
    procedure Filter_ViewWithoutFilters_ClearsSelectedBlob()
    var
        CustomerContract: Record "Customer Subscription Contract";
        ResponseJson: JsonObject;
    begin
        // PR #25 B2 | Time: no date dependence | Risk: None
        // [GIVEN] A stored contract filter.
        Initialize(false);
        // [WHEN] The default, unfiltered view is supplied (the documented clear operation).
        ResponseJson := InvokeFilter('CONTRACT', CustomerContract.GetView(true), true);
        // [THEN] Only the contract Blob is cleared and the normalized target is returned.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Unfiltered view must be valid.');
        Assert.AreEqual('contract', ReadText(ResponseJson, 'target'), 'Target casing must be normalized.');
        Assert.AreEqual('', ReadStoredFilter('contract'), 'Default view must clear the Blob.');
        AssertOtherFiltersUnchanged('contract');
    end;

    local procedure Initialize(VendorPartner: Boolean)
    var
        PriceUpdateTemplate: Record "Price Update Template";
        FilterStream: OutStream;
    begin
        if PriceUpdateTemplate.Get(TemplateCodeTok) then
            PriceUpdateTemplate.Delete(false);
        PriceUpdateTemplate.Init();
        PriceUpdateTemplate.Code := TemplateCodeTok;
        PriceUpdateTemplate.Description := 'X PR25 filter fixture';
        if VendorPartner then
            PriceUpdateTemplate.Partner := PriceUpdateTemplate.Partner::Vendor
        else
            PriceUpdateTemplate.Partner := PriceUpdateTemplate.Partner::Customer;
        PriceUpdateTemplate."Subscription Contract Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
        FilterStream.WriteText('X existing contract filter');
        PriceUpdateTemplate."Subscription Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
        FilterStream.WriteText('X existing subscription filter');
        PriceUpdateTemplate."Subscription Line Filter".CreateOutStream(FilterStream, TextEncoding::UTF8);
        FilterStream.WriteText('X existing line filter');
        PriceUpdateTemplate.Insert(false);
    end;

    local procedure CreateCustomerContract(ContractNo: Code[20])
    var
        CustomerContract: Record "Customer Subscription Contract";
    begin
        CustomerContract.Init();
        CustomerContract."No." := ContractNo;
        CustomerContract.Insert(false);
    end;

    local procedure InvokeFilter(TargetName: Text; FilterText: Text; IncludeFilter: Boolean) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestJson: JsonObject;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestJson.Add('priceUpdateTemplateCode', TemplateCodeTok);
        RequestJson.Add('target', TargetName);
        if IncludeFilter then
            RequestJson.Add('filter', FilterText);
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(Enum::"Message Type ori"::"Subscription.PriceUpdate.SetTemplateFilter",
            Enum::"Message Version ori"::"1.0", '', 'XPR25', 'application/json',
            RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'Dispatcher must return structured JSON.');
    end;

    local procedure AssertRejectedFilter(FilterText: Text)
    var
        ResponseJson: JsonObject;
    begin
        // [GIVEN] Three stored filters and a caller-supplied invalid view.
        Initialize(false);
        // [WHEN] The public dispatcher processes it.
        ResponseJson := InvokeFilter('contract', FilterText, true);
        // [THEN] Failure is structured and all template state survives.
        Assert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'Invalid filter must fail closed.');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'error'), 'Failure must explain the invalid filter.');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'code'), 'Invalid views must have a structured error code.');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'Invalid views must provide a corrective next step.');
        Assert.IsFalse(ResponseJson.Contains('callstack'), 'Errors must not expose a callstack.');
        AssertAllFiltersUnchanged();
    end;

    local procedure AssertAllFiltersUnchanged()
    begin
        Assert.AreEqual('X existing contract filter', ReadStoredFilter('contract'), 'Contract Blob was altered.');
        Assert.AreEqual('X existing subscription filter', ReadStoredFilter('subscription'), 'Subscription Blob was altered.');
        Assert.AreEqual('X existing line filter', ReadStoredFilter('line'), 'Line Blob was altered.');
    end;

    local procedure AssertOtherFiltersUnchanged(ChangedTarget: Text)
    begin
        if ChangedTarget <> 'contract' then
            Assert.AreEqual('X existing contract filter', ReadStoredFilter('contract'), 'Contract Blob was altered.');
        if ChangedTarget <> 'subscription' then
            Assert.AreEqual('X existing subscription filter', ReadStoredFilter('subscription'), 'Subscription Blob was altered.');
        if ChangedTarget <> 'line' then
            Assert.AreEqual('X existing line filter', ReadStoredFilter('line'), 'Line Blob was altered.');
    end;

    local procedure ReadStoredFilter(TargetName: Text) FilterText: Text
    var
        PriceUpdateTemplate: Record "Price Update Template";
        FilterStream: InStream;
    begin
        PriceUpdateTemplate.Get(TemplateCodeTok);
        PriceUpdateTemplate.CalcFields("Subscription Contract Filter", "Subscription Filter", "Subscription Line Filter");
        case TargetName of
            'contract':
                PriceUpdateTemplate."Subscription Contract Filter".CreateInStream(FilterStream, TextEncoding::UTF8);
            'subscription':
                PriceUpdateTemplate."Subscription Filter".CreateInStream(FilterStream, TextEncoding::UTF8);
            'line':
                PriceUpdateTemplate."Subscription Line Filter".CreateInStream(FilterStream, TextEncoding::UTF8);
        end;
        FilterStream.ReadText(FilterText);
    end;

    local procedure ReadText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, PropertyToken), 'Missing response property: ' + PropertyName);
        exit(PropertyToken.AsValue().AsText());
    end;
}
