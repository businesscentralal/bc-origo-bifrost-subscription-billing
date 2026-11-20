namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>
/// Company gate for the 33 Subscription.* message types (#98).
/// A company is configured when setup has one of the three number series. The install record alone is not enough.
/// PostDocuments stays behind its posting permission as well; these tests run with permissions disabled, so that gate is open.
/// </summary>
codeunit 95725 "Sub Configured Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        SeriesTok: Label 'SB98', Locked = true;

    [Test]
    procedure BlankSetup_DisablesEveryType()
    begin
        // [GIVEN] The setup record exists and all three number series are blank, as after Microsoft's install
        SetSeries('', '', '');

        // [WHEN] Every Subscription Billing type is asked whether it is enabled
        // [THEN] All 33 are hidden, including PostDocuments
        AssertEveryType(false, 'Blank number series');
    end;

    [Test]
    procedure MissingSetup_DisablesEveryType()
    var
        Setup: Record "Subscription Contract Setup";
    begin
        // [GIVEN] The company has no Subscription Contract Setup record
        if Setup.Get() then
            Setup.Delete(false);

        // [WHEN] Every type is asked whether it is enabled
        // [THEN] All 33 are hidden
        AssertEveryType(false, 'Missing setup');
    end;

    [Test]
    procedure AnyOneSeries_EnablesEveryType()
    begin
        // [GIVEN] Only the customer contract series is set
        SetSeries('', SeriesTok, '');

        // [THEN] All 33 are enabled, including PostDocuments while the posting permission is granted
        AssertEveryType(true, 'Customer series only');

        // [GIVEN] Only the vendor contract series is set
        SetSeries('', '', SeriesTok);
        AssertEveryType(true, 'Vendor series only');

        // [GIVEN] Only Subscription Header No. is set
        SetSeries(SeriesTok, '', '');
        AssertEveryType(true, 'Subscription header series only');
    end;

    [Test]
    procedure ClearingLastSeries_HidesTypesWithoutRestart()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
    begin
        // [GIVEN] One series makes the types visible
        SetSeries('', SeriesTok, '');
        MessageTypeInterface := Enum::"Message Type ori"::"Subscription.Line.Create";
        Assert.IsTrue(MessageTypeInterface.IsEnabled(), 'A series must enable the type in this session.');

        // [WHEN] That series is cleared and the type is asked again, without a new session
        SetSeries('', '', '');

        // [THEN] It is hidden, and setting a different series shows it again
        Assert.IsFalse(MessageTypeInterface.IsEnabled(), 'Clearing the last series must hide the type on the next call.');
        SetSeries(SeriesTok, '', '');
        Assert.IsTrue(MessageTypeInterface.IsEnabled(), 'Setting a series again must show the type on the next call.');
    end;

    [Test]
    procedure BlankCompanyName_IsNotConfigured()
    var
        Configured: Codeunit "Sub Configured ori";
    begin
        // [GIVEN] An empty company name
        // [WHEN] The gate is asked
        // [THEN] It does not treat the name as a configured company
        Assert.IsFalse(Configured.IsConfiguredInCompany(''), 'An empty company name is not configured.');
    end;

    [Test]
    [CommitBehavior(CommitBehavior::Ignore)]
    procedure TwoCompanies_KeepIndependentNumberSeries()
    var
        Configured: Codeunit "Sub Configured ori";
        MessageTypeInterface: Interface "Msg Interface ori";
        OtherName: Text[30];
        CreatedCompany: Boolean;
        CurrentHadSetup: Boolean;
        SavedHeader: Code[20];
        SavedCustomer: Code[20];
        SavedVendor: Code[20];
        OtherHadSetup: Boolean;
        OtherHeader: Code[20];
        OtherCustomer: Code[20];
        OtherVendor: Code[20];
        CurrentEnabledWhenSet: Boolean;
        OtherConfiguredWhenBlank: Boolean;
        CurrentEnabledWhenBlank: Boolean;
        OtherConfiguredWhenSet: Boolean;
    begin
        // [GIVEN] This company and one other company, with their setup saved
        OtherName := FindOrCreateOtherCompany(CreatedCompany);
        CurrentHadSetup := SaveCurrent(SavedHeader, SavedCustomer, SavedVendor);
        OtherHadSetup := SaveOther(OtherName, OtherHeader, OtherCustomer, OtherVendor);

        // [WHEN] This company has a series and the other company has none
        SetSeries('', SeriesTok, '');
        WriteOther(OtherName, '', '', '');
        MessageTypeInterface := Enum::"Message Type ori"::"Subscription.Analysis.Recalculate";
        CurrentEnabledWhenSet := MessageTypeInterface.IsEnabled();
        OtherConfiguredWhenBlank := Configured.IsConfiguredInCompany(OtherName);

        // [WHEN] The series moves to the other company
        SetSeries('', '', '');
        WriteOther(OtherName, '', '', SeriesTok);
        CurrentEnabledWhenBlank := MessageTypeInterface.IsEnabled();
        OtherConfiguredWhenSet := Configured.IsConfiguredInCompany(OtherName);

        // Restore before asserting so a failed assertion does not leave the saved series cleared
        RestoreCurrent(CurrentHadSetup, SavedHeader, SavedCustomer, SavedVendor);
        RestoreOther(OtherName, OtherHadSetup, OtherHeader, OtherCustomer, OtherVendor);
        if CreatedCompany then
            DeleteCreatedCompany(OtherName);

        // [THEN] Each company follows only its own setup, and the current session reads its own
        Assert.IsTrue(CurrentEnabledWhenSet, 'The current company must be enabled when it has a series.');
        Assert.IsFalse(OtherConfiguredWhenBlank, 'The other company must stay disabled while its series are blank.');
        Assert.IsFalse(CurrentEnabledWhenBlank, 'Clearing this company must hide the type even when another company is configured.');
        Assert.IsTrue(OtherConfiguredWhenSet, 'The other company must be configured from its own series.');
    end;

    [Test]
    procedure Help_StatesWhenTypesAppear_InBothLanguages()
    var
        Configured: Codeunit "Sub Configured ori";
        SavedLanguage: Integer;
        EnglishText: Text;
        IcelandicText: Text;
    begin
        // [GIVEN] The availability sentence
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishText := Configured.AvailabilityExplanation();
        GlobalLanguage(1039);
        IcelandicText := Configured.AvailabilityExplanation();
        GlobalLanguage(SavedLanguage);

        // [THEN] English and Icelandic each say when the operations appear and that posting stays separate
        Assert.AreNotEqual(EnglishText, IcelandicText, '1039 must not repeat the English sentence.');
        Assert.AreNotEqual(0, StrPos(EnglishText, 'Subscription Header No.'), EnglishText);
        Assert.AreNotEqual(0, StrPos(EnglishText, 'no restart'), EnglishText);
        Assert.AreNotEqual(0, StrPos(EnglishText, 'BIFROST SubPost ori'), EnglishText);
        Assert.AreNotEqual(0, StrPos(IcelandicText, 'án endurræsingar'), IcelandicText);
        Assert.AreNotEqual(0, StrPos(IcelandicText, 'BIFROST SubPost ori'), IcelandicText);
    end;

    local procedure AssertEveryType(Expected: Boolean; Reason: Text)
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Ordinal: Integer;
        Found: Integer;
    begin
        foreach Ordinal in Enum::"Message Type ori".Ordinals() do
            if (Ordinal >= 10035036) and (Ordinal <= 10035090) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MessageTypeInterface := MessageType;
                Found += 1;
                if Expected then
                    Assert.IsTrue(MessageTypeInterface.IsEnabled(), StrSubstNo('%1 should be enabled. %2', Format(MessageType), Reason))
                else
                    Assert.IsFalse(MessageTypeInterface.IsEnabled(), StrSubstNo('%1 should be disabled. %2', Format(MessageType), Reason));
            end;
        Assert.AreEqual(33, Found, 'All 33 Subscription Billing types should be checked.');
    end;

    local procedure SetSeries(HeaderNo: Code[20]; CustomerNos: Code[20]; VendorNos: Code[20])
    var
        Setup: Record "Subscription Contract Setup";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."Subscription Header No." := HeaderNo;
        Setup."Cust. Sub. Contract Nos." := CustomerNos;
        Setup."Vend. Sub. Contract Nos." := VendorNos;
        Setup.Modify(false);
    end;

    local procedure SaveCurrent(var HeaderNo: Code[20]; var CustomerNos: Code[20]; var VendorNos: Code[20]): Boolean
    var
        Setup: Record "Subscription Contract Setup";
    begin
        HeaderNo := '';
        CustomerNos := '';
        VendorNos := '';
        if not Setup.Get() then
            exit(false);
        HeaderNo := Setup."Subscription Header No.";
        CustomerNos := Setup."Cust. Sub. Contract Nos.";
        VendorNos := Setup."Vend. Sub. Contract Nos.";
        exit(true);
    end;

    local procedure RestoreCurrent(HadSetup: Boolean; HeaderNo: Code[20]; CustomerNos: Code[20]; VendorNos: Code[20])
    var
        Setup: Record "Subscription Contract Setup";
    begin
        if not HadSetup then begin
            if Setup.Get() then
                Setup.Delete(false);
            exit;
        end;
        SetSeries(HeaderNo, CustomerNos, VendorNos);
    end;

    local procedure FindOrCreateOtherCompany(var Created: Boolean): Text[30]
    var
        Company: Record Company;
        CreatedName: Text[30];
    begin
        Created := false;
        Company.SetFilter(Name, '<>%1&<>%2', CompanyName(), 'SB98-CFG');
        if Company.FindFirst() then
            exit(Company.Name);

        CreatedName := 'SB98-CFG';
        if not Company.Get(CreatedName) then begin
            Company.Init();
            Company.Name := CreatedName;
            Company."Display Name" := CreatedName;
            Company.Insert(true);
            Created := true;
        end;
        exit(CreatedName);
    end;

    local procedure SaveOther(OtherName: Text[30]; var HeaderNo: Code[20]; var CustomerNos: Code[20]; var VendorNos: Code[20]): Boolean
    var
        Setup: Record "Subscription Contract Setup";
    begin
        HeaderNo := '';
        CustomerNos := '';
        VendorNos := '';
        Setup.ChangeCompany(OtherName);
        if not Setup.Get() then
            exit(false);
        HeaderNo := Setup."Subscription Header No.";
        CustomerNos := Setup."Cust. Sub. Contract Nos.";
        VendorNos := Setup."Vend. Sub. Contract Nos.";
        exit(true);
    end;

    local procedure WriteOther(OtherName: Text[30]; HeaderNo: Code[20]; CustomerNos: Code[20]; VendorNos: Code[20])
    var
        Setup: Record "Subscription Contract Setup";
    begin
        Setup.ChangeCompany(OtherName);
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."Subscription Header No." := HeaderNo;
        Setup."Cust. Sub. Contract Nos." := CustomerNos;
        Setup."Vend. Sub. Contract Nos." := VendorNos;
        Setup.Modify(false);
    end;

    local procedure RestoreOther(OtherName: Text[30]; HadSetup: Boolean; HeaderNo: Code[20]; CustomerNos: Code[20]; VendorNos: Code[20])
    var
        Setup: Record "Subscription Contract Setup";
    begin
        Setup.ChangeCompany(OtherName);
        if not HadSetup then begin
            if Setup.Get() then
                Setup.Delete(false);
            exit;
        end;
        WriteOther(OtherName, HeaderNo, CustomerNos, VendorNos);
    end;

    local procedure DeleteCreatedCompany(OtherName: Text[30])
    var
        Company: Record Company;
    begin
        if OtherName <> 'SB98-CFG' then
            exit;
        if Company.Get(OtherName) then
            Company.Delete(true);
    end;
}
