namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests over the shared request parsing and response formatting the Subscription Billing
/// message types are built on. These lock in behaviour that live testing against Business
/// Central 28.4 showed had gone wrong once already: a list parameter that was silently ignored,
/// and enum values that reached the caller as a localised caption or a bare ordinal instead of
/// a stable token.
/// </summary>
codeunit 95702 "Sub Helper Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Sub Helper ori";

    [Test]
    procedure TryGetArray_ReturnsTheArray_WhenOneIsSupplied()
    var
        RequestJson: JsonObject;
        SuppliedArray: JsonArray;
        ReadArray: JsonArray;
    begin
        // [GIVEN] A request carrying a two element array
        SuppliedArray.Add(101);
        SuppliedArray.Add(102);
        RequestJson.Add('subscriptionLineEntryNos', SuppliedArray);

        // [WHEN] The array is read
        // [THEN] It comes back whole
        Assert.IsTrue(Helper.TryGetArray(RequestJson, 'subscriptionLineEntryNos', ReadArray), 'A supplied array should be found.');
        Assert.AreEqual(2, ReadArray.Count(), 'Both entries should come back.');
    end;

    [Test]
    procedure TryGetArray_ReportsAbsent_WhenThePropertyIsMissing()
    var
        RequestJson: JsonObject;
        ReadArray: JsonArray;
    begin
        // [GIVEN] A request with no such property
        RequestJson.Add('contractNo', 'CC000010');

        // [WHEN] The array is read
        // [THEN] The caller is told to fall back to its own default, rather than erroring
        Assert.IsFalse(Helper.TryGetArray(RequestJson, 'subscriptionLineEntryNos', ReadArray), 'An absent property is not an error.');
        Assert.AreEqual(0, ReadArray.Count(), 'Nothing should have been read.');
    end;

    [Test]
    procedure TryGetArray_ReportsAbsent_WhenThePropertyIsNull()
    var
        RequestJson: JsonObject;
        NullValue: JsonValue;
        ReadArray: JsonArray;
    begin
        // [GIVEN] A request that sends the property explicitly as null
        NullValue.SetValueToNull();
        RequestJson.Add('steps', NullValue);

        // [WHEN] The array is read
        // [THEN] Null means "not supplied", the same as leaving it out
        Assert.IsFalse(Helper.TryGetArray(RequestJson, 'steps', ReadArray), 'An explicit null is not an error.');
    end;

    [Test]
    procedure TryGetArray_Errors_WhenThePropertyIsNotAnArray()
    var
        RequestJson: JsonObject;
        ReadArray: JsonArray;
    begin
        // [GIVEN] A request that sends a single value where a list belongs
        RequestJson.Add('subscriptionLineEntryNos', '101');

        // [WHEN] The array is read
        asserterror Helper.TryGetArray(RequestJson, 'subscriptionLineEntryNos', ReadArray);

        // [THEN] The caller is told, rather than the value being dropped and every eligible
        // line being picked up instead of the one that was named
        Assert.ExpectedError('subscriptionLineEntryNos');
    end;

    [Test]
    procedure GetEntryNoSelection_BuildsAFilterOverTheDistinctEntryNos()
    var
        RequestJson: JsonObject;
        SuppliedArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        EntryNoFilter: Text;
    begin
        // [GIVEN] A request naming three lines, one of them twice
        SuppliedArray.Add(101);
        SuppliedArray.Add(102);
        SuppliedArray.Add(101);
        SuppliedArray.Add(103);
        RequestJson.Add('subscriptionLineEntryNos', SuppliedArray);

        // [WHEN] The selection is read
        EntryNoFilter := Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);

        // [THEN] The duplicate is folded away and the database is asked only for those three
        Assert.AreEqual(3, SelectedEntryNos.Count(), 'The repeated entry number should be counted once.');
        Assert.IsTrue(SelectedEntryNos.ContainsKey(101), 'Entry 101 should be in the selection.');
        Assert.IsTrue(SelectedEntryNos.ContainsKey(102), 'Entry 102 should be in the selection.');
        Assert.IsTrue(SelectedEntryNos.ContainsKey(103), 'Entry 103 should be in the selection.');
        Assert.AreEqual(2, StrLen(EntryNoFilter) - StrLen(DelChr(EntryNoFilter, '=', '|')), 'Three entry numbers make two separators.');
        Assert.IsTrue(EntryNoFilter.Contains('101'), 'The filter should name entry 101.');
        Assert.IsTrue(EntryNoFilter.Contains('102'), 'The filter should name entry 102.');
        Assert.IsTrue(EntryNoFilter.Contains('103'), 'The filter should name entry 103.');
    end;

    [Test]
    procedure GetEntryNoSelection_SelectsEverything_WhenThePropertyIsMissing()
    var
        RequestJson: JsonObject;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
    begin
        // [GIVEN] A request that names no lines at all
        RequestJson.Add('contractNo', 'CC000010');

        // [WHEN] The selection is read
        // [THEN] Nothing is filtered and nothing is selected, which means "take every eligible line"
        Assert.AreEqual('', Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos), 'No selection means no filter.');
        Assert.AreEqual(0, SelectedEntryNos.Count(), 'No selection means nothing to test rows against.');
    end;

    [Test]
    procedure GetEntryNoSelection_Errors_OnAnElementThatIsNotANumber()
    var
        RequestJson: JsonObject;
        SuppliedArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
    begin
        // [GIVEN] A request whose list carries something that is not an entry number
        SuppliedArray.Add(101);
        SuppliedArray.Add('not-a-number');
        RequestJson.Add('subscriptionLineEntryNos', SuppliedArray);

        // [WHEN] The selection is read
        asserterror Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);

        // [THEN] The caller is named the parameter, rather than the element being silently dropped
        // and every eligible line attached instead of the ones that were named
        Assert.ExpectedError('subscriptionLineEntryNos');
    end;

    [Test]
    procedure GetEntryNoSelection_Errors_OnANestedElement()
    var
        RequestJson: JsonObject;
        SuppliedArray: JsonArray;
        NestedArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
    begin
        // [GIVEN] A request whose list carries an array where an entry number belongs
        NestedArray.Add(101);
        SuppliedArray.Add(NestedArray);
        RequestJson.Add('subscriptionLineEntryNos', SuppliedArray);

        // [WHEN] The selection is read
        asserterror Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos);

        // [THEN] The caller is told, rather than the token being read as a value it is not
        Assert.ExpectedError('subscriptionLineEntryNos');
    end;

    [Test]
    procedure GetEntryNoSelection_DropsTheFilter_WhenTheListIsTooLongForOneExpression()
    var
        RequestJson: JsonObject;
        SuppliedArray: JsonArray;
        SelectedEntryNos: Dictionary of [Integer, Boolean];
        Index: Integer;
    begin
        // [GIVEN] A request naming more lines than fit in a single filter expression
        for Index := 1 to 60 do
            SuppliedArray.Add(Index);
        RequestJson.Add('subscriptionLineEntryNos', SuppliedArray);

        // [WHEN] The selection is read
        // [THEN] The filter is given up rather than built past the length a filter may have - the
        // selection itself still comes back whole, so the caller drops the extra rows row by row
        Assert.AreEqual('', Helper.GetEntryNoSelection(RequestJson, 'subscriptionLineEntryNos', SelectedEntryNos), 'A long list is not turned into a filter.');
        Assert.AreEqual(60, SelectedEntryNos.Count(), 'Every named entry number should still be selected.');
    end;

    [Test]
    procedure FormatDocumentType_ReturnsAStableToken()
    begin
        // [GIVEN] The recurring billing document types
        // [WHEN] Each is formatted for a JSON response
        // [THEN] The caller gets a token it can switch on, in any language, in any locale
        Assert.AreEqual('None', Helper.FormatDocumentType(Enum::"Rec. Billing Document Type"::None), 'None should format as a stable token.');
        Assert.AreEqual('Invoice', Helper.FormatDocumentType(Enum::"Rec. Billing Document Type"::Invoice), 'Invoice should format as a stable token.');
        Assert.AreEqual('Credit Memo', Helper.FormatDocumentType(Enum::"Rec. Billing Document Type"::"Credit Memo"), 'Credit Memo should format as a stable token.');
    end;

    [Test]
    procedure FormatProcessingStatus_ReturnsAStableToken()
    begin
        // [GIVEN] The usage data processing statuses
        // [WHEN] Each is formatted for a JSON response
        // [THEN] The caller gets a token it can switch on
        Assert.AreEqual('None', Helper.FormatProcessingStatus(Enum::"Processing Status"::None), 'None should format as a stable token.');
        Assert.AreEqual('Ok', Helper.FormatProcessingStatus(Enum::"Processing Status"::Ok), 'Ok should format as a stable token.');
        Assert.AreEqual('Error', Helper.FormatProcessingStatus(Enum::"Processing Status"::Error), 'Error should format as a stable token.');
        Assert.AreEqual('Closed', Helper.FormatProcessingStatus(Enum::"Processing Status"::Closed), 'Closed should format as a stable token.');
    end;

    [Test]
    procedure FormatDate_UsesTheIsoFormat()
    begin
        // [GIVEN] A date
        // [WHEN] It is formatted for a JSON response
        // [THEN] It is ISO, whatever the caller's locale
        Assert.AreEqual('2026-09-01', Helper.FormatDate(DMY2Date(1, 9, 2026)), 'Dates go out in the ISO format.');
        Assert.AreEqual('', Helper.FormatDate(0D), 'A blank date goes out as an empty string.');
    end;

    [Test]
    procedure GetDate_ReadsTheIsoFormat()
    var
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request carrying an ISO date
        RequestJson.Add('billingDate', '2026-09-01');

        // [WHEN] The date is read
        // [THEN] It is understood regardless of the session's own date format
        Assert.AreEqual(DMY2Date(1, 9, 2026), Helper.GetDate(RequestJson, 'billingDate', true), 'ISO dates should be read back exactly.');
    end;

    [Test]
    procedure GetDate_Errors_OnAnUnparseableDate()
    var
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request carrying something that is not a date
        RequestJson.Add('billingDate', '31/08/2026');

        // [WHEN] The date is read
        asserterror Helper.GetDate(RequestJson, 'billingDate', true);

        // [THEN] The caller is named the parameter that was wrong
        Assert.ExpectedError('billingDate');
    end;

    [Test]
    procedure GetDecimal_ReadsACultureInvariantNumber()
    var
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request carrying a decimal written with a point
        RequestJson.Add('amount', '1234.56');

        // [WHEN] The decimal is read
        // [THEN] The point is the decimal separator, whatever the session locale uses
        Assert.AreEqual(1234.56, Helper.GetDecimal(RequestJson, 'amount', true), 'Decimals use a point, not the session separator.');
    end;

    [Test]
    procedure GetServicePartner_AcceptsEitherPartnerInAnyCasing()
    var
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request naming the partner in mixed casing
        RequestJson.Add('partner', 'vEnDoR');

        // [WHEN] The partner is read
        // [THEN] Casing does not matter
        Assert.AreEqual(
            Enum::"Service Partner"::Vendor,
            Helper.GetServicePartner(RequestJson, 'partner', Enum::"Service Partner"::Customer),
            'The partner should be read in any casing.');
    end;

    [Test]
    procedure GetServicePartner_Errors_OnAnUnknownPartner()
    var
        RequestJson: JsonObject;
    begin
        // [GIVEN] A request naming something that is neither partner
        RequestJson.Add('partner', 'Reseller');

        // [WHEN] The partner is read
        asserterror Helper.GetServicePartner(RequestJson, 'partner', Enum::"Service Partner"::Customer);

        // [THEN] The caller is told which values are allowed
        Assert.ExpectedError('partner');
    end;
}
