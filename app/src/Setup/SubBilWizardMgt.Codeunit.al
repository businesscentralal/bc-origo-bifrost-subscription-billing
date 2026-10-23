namespace Origo.Bifrost.SubscriptionBilling;

using System.Apps;
using System.Environment.Configuration;

/// <summary>Read-only wizard state and explicit assisted-setup completion; never changes HTTP or access.</summary>
codeunit 10035062 "SubBil Wizard Mgt ori"
{
    Access = Internal;

    /// <summary>Reads the HTTP setting of this app without creating or changing it.</summary>
    internal procedure IsHttpEnabled(): Boolean
    var
        AppSetting: Record "NAV App Setting";
        AppInfo: ModuleInfo;
    begin
        if not AppSetting.ReadPermission() then
            exit(false);
        NavApp.GetCurrentModuleInfo(AppInfo);
        exit(AppSetting.Get(AppInfo.Id()) and AppSetting."Allow HttpClient Requests");
    end;

    /// <summary>Reports whether the caller may change extension settings through Foundation.</summary>
    internal procedure CanEnableHttp(): Boolean
    var
        AppSetting: Record "NAV App Setting";
    begin
        exit(AppSetting.WritePermission());
    end;

    /// <summary>Returns exactly the assignable permission sets this app supplies.</summary>
    internal procedure PermissionSets() Names: List of [Text]
    begin
        Names.Add('BIFROST SubBil ori');
        Names.Add('BIFROST SubPost ori');
    end;

    /// <summary>Moves between the four wizard steps and refuses an invalid current step.</summary>
    internal procedure NextStep(CurrentStep: Integer; Forward: Boolean): Integer
    var
        InvalidStepErr: Label 'The setup step is invalid. Close the wizard and open it again from Assisted Setup.', Comment = 'is-IS=Uppsetningarskrefið er ógilt. Lokaðu leiðsögninni og opnaðu hana aftur úr Leiðsögn um uppsetningu.';
    begin
        if not (CurrentStep in [1 .. 4]) then
            Error(InvalidStepErr);
        if Forward then begin
            if CurrentStep < 4 then
                exit(CurrentStep + 1);
        end else
            if CurrentStep > 1 then
                exit(CurrentStep - 1);
        exit(CurrentStep);
    end;

    /// <summary>Marks setup complete only after the caller explicitly chooses Finish.</summary>
    internal procedure Finish()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"SubBil Setup Wizard ori");
    end;
}
