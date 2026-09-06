namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests over the shared request parsing and response formatting the Subscription Billing
/// message types are built on. These lock in behaviour that live testing against Business
/// Central 28.4 showed had gone wrong once already: a list parameter that was silently ignored,
/// and enum values that reached the caller as a localised caption or a bare ordinal instead of
/// a stable token.
/// </summary>
codeunit 95702 "CE Sub Helper Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "CE Sub Helper ori";

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
