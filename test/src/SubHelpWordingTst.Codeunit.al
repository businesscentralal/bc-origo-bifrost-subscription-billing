namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

/// <summary>Checks localized document captions in app-owned refusal text without posting a document.</summary>
codeunit 95727 "Sub Help Wording Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "Sub Test Library ori";

    [Test]
    procedure Scenario_64AC06_RefusalCaptions_EN()
    begin
        AssertCaptions(1033, 'Invoice', 'Credit Memo');
    end;

    [Test]
    procedure Scenario_64AC06_RefusalCaptions_IS()
    begin
        AssertCaptions(1039, 'Reikningur', 'Kreditreikningur');
    end;

    [Test]
    procedure Scenario_64AC02_PreviewDescriptions_EN()
    begin
        AssertPreviewDescriptions(1033);
    end;

    [Test]
    procedure Scenario_64AC02_PreviewDescriptions_IS()
    begin
        AssertPreviewDescriptions(1039);
    end;

    local procedure AssertPreviewDescriptions(LanguageId: Integer)
    var
        CustomerPreview: Codeunit "Sub Con PrvInvoice Impl ori";
        VendorPreview: Codeunit "Sub Vend PrvInv Impl ori";
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Assert.IsTrue((StrLen(CustomerPreview.GetDescription()) >= 20) and (StrLen(CustomerPreview.GetDescription()) <= 200), 'Customer preview description must be 20–200 characters.');
        Assert.IsTrue((StrLen(VendorPreview.GetDescription()) >= 20) and (StrLen(VendorPreview.GetDescription()) <= 200), 'Vendor preview description must be 20–200 characters.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertCaptions(LanguageId: Integer; InvoiceCaption: Text; CreditMemoCaption: Text)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", ForeignRequest('Invoice'));
        Assert.ExpectedError(InvoiceCaption);
        asserterror TestLibrary.Run(Enum::"Message Type ori"::"Subscription.Billing.PostDocuments", ForeignRequest('Credit Memo'));
        Assert.ExpectedError(CreditMemoCaption);
        if LanguageId = 1039 then
            Assert.ExpectedError('áskriftarreikningagerð');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure ForeignRequest(DocumentType: Text) Request: JsonObject
    var
        Entry: JsonObject;
        Documents: JsonArray;
    begin
        Entry.Add('partner', 'Vendor');
        Entry.Add('documentType', DocumentType);
        Entry.Add('documentNo', 'XS64-OWN-NONEXIST');
        Documents.Add(Entry);
        Request.Add('documents', Documents);
    end;
}
