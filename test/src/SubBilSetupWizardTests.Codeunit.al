namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost.SubscriptionBilling;
using System.Apps;
using System.Environment.Configuration;
using System.TestLibraries.Utilities;

/// <summary>Wizard registration, read-only HTTP, navigation and explicit completion without consent or security writes.</summary>
codeunit 95721 "SubBil Setup Wizard Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        WizardMgt: Codeunit "SubBil Wizard Mgt ori";
        OperationsOpened: Boolean;

    [Test]
    procedure Scenario_AC01_AssistedSetup_RegistersWizard()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AssistedSetup: TestPage "Assisted Setup";
    begin
        GuidedExperience.Remove(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"SubBil Setup Wizard ori");
        AssistedSetup.OpenView();
        AssistedSetup.Close();
        Assert.IsTrue(GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"SubBil Setup Wizard ori"), 'Assisted Setup must register the wizard.');
        Assert.IsTrue(GuidedExperience.AssistedSetupExistsAndIsNotComplete(ObjectType::Page, Page::"SubBil Setup Wizard ori"), 'A freshly registered wizard must not be completed.');
    end;

    [Test]
    procedure Scenario_AC03_HttpRead_NeverCreatesASetting()
    var
        AppSetting: Record "NAV App Setting";
        Expected: Boolean;
        BeforeCount: Integer;
    begin
        // The setting is maintained only by Foundation; the fixture never changes it.
        BeforeCount := AppSetting.Count();
        Expected := AppSetting.Get('{DD7B8BD8-F93E-4AC4-A251-1A132A14EF3D}') and AppSetting."Allow HttpClient Requests";
        Assert.AreEqual(Expected, WizardMgt.IsHttpEnabled(), 'Read must describe this app, including an absent setting.');
        Assert.AreEqual(Expected, WizardMgt.IsHttpEnabled(), 'Repeated verification must have no side effects.');
        Assert.AreEqual(BeforeCount, AppSetting.Count(), 'Reading must not create or remove any setting.');
    end;

    [Test]
    procedure Scenario_AC03_Verify_StaysAvailable()
    var
        Wizard: TestPage "SubBil Setup Wizard ori";
    begin
        Wizard.OpenView();
        Wizard.Next.Invoke();
        Wizard.Verify.Invoke();
        Assert.IsTrue(Wizard.Verify.Visible(), 'Verify remains available on the HTTP step.');
        Wizard.Close();
    end;

    [Test]
    procedure Scenario_AC04_Access_ListsOnlyAssignableSets()
    var
        Names: List of [Text];
    begin
        Names := WizardMgt.PermissionSets();
        Assert.AreEqual(2, Names.Count(), 'The app has exactly two assignable sets.');
        Assert.IsTrue(Names.Contains('BIFROST SubBil ori'), 'Operations set must be named exactly.');
        Assert.IsTrue(Names.Contains('BIFROST SubPost ori'), 'Posting set must be named exactly.');
    end;

    [Test]
    procedure Scenario_AC05_CloseEarly_DoesNotCompleteSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AssistedSetup: TestPage "Assisted Setup";
        Wizard: TestPage "SubBil Setup Wizard ori";
        WasComplete: Boolean;
    begin
        AssistedSetup.OpenView();
        AssistedSetup.Close();
        WasComplete := GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"SubBil Setup Wizard ori");
        Wizard.OpenView();
        Wizard.Next.Invoke();
        Wizard.Close();
        Assert.AreEqual(WasComplete, GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"SubBil Setup Wizard ori"), 'Closing early must preserve completion state.');
    end;

    [Test]
    procedure Scenario_AC05_Finish_CompletesSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AssistedSetup: TestPage "Assisted Setup";
        Wizard: TestPage "SubBil Setup Wizard ori";
    begin
        AssistedSetup.OpenView();
        AssistedSetup.Close();
        Wizard.OpenView();
        Wizard.Next.Invoke();
        Wizard.Next.Invoke();
        Wizard.Next.Invoke();
        Wizard.FinishSetup.Invoke();
        Assert.IsTrue(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"SubBil Setup Wizard ori"), 'Only explicit Finish completes the wizard.');
    end;

    [Test]
    procedure Scenario_AC05_InvalidStep_ExplainsRecovery()
    begin
        asserterror WizardMgt.NextStep(0, true);
        Assert.ExpectedError('Assisted Setup');
    end;

    [Test]
    procedure Scenario_AC05_StepBoundaries_StayInRange()
    begin
        Assert.AreEqual(1, WizardMgt.NextStep(1, false), 'Back at the first step must not underflow.');
        Assert.AreEqual(4, WizardMgt.NextStep(4, true), 'Next at the last step must not overflow.');
    end;
    [Test]
    [HandlerFunctions('OperationsHandler')]
    procedure Scenario_AC02_ShowOperations_OpensUsableHostPage()
    var
        Wizard: TestPage "SubBil Setup Wizard ori";
    begin
        OperationsOpened := false;
        Wizard.OpenView();
        Wizard.ShowOperations.Invoke();
        Assert.IsTrue(OperationsOpened, 'Show operations must open a supported page hosting the installed Foundation list.');
        Wizard.Close();
    end;

    [ModalPageHandler]
    procedure OperationsHandler(var Operations: TestPage "SubBil Operations ori")
    begin
        OperationsOpened := true;
        Assert.IsTrue(Operations.MessageTypes.First(), 'The operations host must display installed Bifrost message types.');
        // The modal-page handler returns control to RunModal, which closes the page.
    end;

}
