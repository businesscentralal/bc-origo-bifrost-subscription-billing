namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>Guides administrators through Subscription Billing operations, Foundation HTTP setup and access.</summary>
page 10035035 "SubBil Setup Wizard ori"
{
    PageType = NavigatePage;
    Extensible = false;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ContextSensitiveHelpPage = 'subscription-billing-setup';
    Caption = 'Set up Bifrost Subscription Billing', Comment = 'is-IS=Setja upp Bifröst áskriftareikningagerð';

    layout
    {
        area(Content)
        {
            group(Welcome)
            {
                Visible = CurrentStep = 1;
                Caption = 'Welcome', Comment = 'is-IS=Velkomin';
                InstructionalText = 'Bifrost Subscription Billing adds contracts and their lines, billing from proposal to posting, usage billing, price updates, renewals, deferrals, contract analysis and subscription migration to the Subscription domain in Bifrost.', Comment = 'is-IS=Bifröst áskriftareikningagerð bætir samningum og línum þeirra, reikningagerð frá tillögu til bókunar, notkunarreikningagerð, verðuppfærslum, endurnýjunum, frestunum, samningagreiningu og flutningi áskrifta við Subscription-sviðið í Bifröst.';
                group(AccessContext)
                {
                    ShowCaption = false;
                    InstructionalText = 'AI assistants and other systems use these operations through Bifrost as the signed-in user and within that user''s permissions. See the installed operations on the Bifrost Message Types page or open the app documentation.', Comment = 'is-IS=Gervigreindaraðstoð og önnur kerfi nota þessar aðgerðir í gegnum Bifröst sem innskráður notandi og innan heimilda hans. Skoðaðu uppsettar aðgerðir á síðunni Skilaboðategundir Bifröst eða opnaðu skjölun forritsins.';
                }
            }
            group(Http)
            {
                Visible = CurrentStep = 2;
                Caption = 'HTTP', Comment = 'is-IS=HTTP';
                InstructionalText = 'Bifrost needs outbound HTTP for licensing. Foundation enables HTTP for registered apps in Bifrost Setup.', Comment = 'is-IS=Bifröst þarf HTTP út á við fyrir leyfisveitingu. Foundation virkjar HTTP fyrir skráð forrit í uppsetningu Bifröst.';
                field(HttpEnabled; HttpEnabled)
                {
                    Caption = 'HTTP enabled', Comment = 'is-IS=HTTP virkt';
                    ToolTip = 'Shows whether Allow HttpClient Requests is enabled for this app.', Comment = 'is-IS=Sýnir hvort Leyfa HttpClient-beiðnir sé virkt fyrir þetta forrit.';
                    Editable = false;
                }
                group(AdminHelp)
                {
                    Visible = not CanWriteAppSetting;
                    ShowCaption = false;
                    InstructionalText = 'You do not have permission to change extension settings. Ask an administrator with the SUPER permission set (or write permission on table NAV App Setting) to enable Allow HttpClient Requests for the applications listed above.', Comment = 'is-IS=Þú hefur ekki heimild til að breyta stillingum viðbóta. Biddu kerfisstjóra sem hefur SUPER heimildasamstæðuna (eða skrifheimild á töfluna NAV App Setting) um að virkja Leyfa HttpClient-beiðnir fyrir forritin hér að ofan.';
                }
            }
            group(Access)
            {
                Visible = CurrentStep = 3;
                Caption = 'Access', Comment = 'is-IS=Aðgangur';
                InstructionalText = 'Users also need Foundation''s Bifrost permission sets. Assign permission sets to users or through an Entra security group. This wizard does not assign permissions.', Comment = 'is-IS=Notendur þurfa einnig Bifröst heimildasamstæður Foundation. Úthlutaðu heimildasamstæðum til notenda eða með Entra-öryggishópi. Þessi leiðsögn úthlutar ekki heimildum.';
                group(OperationsAccess)
                {
                    Caption = 'BIFROST SubBil ori', Comment = 'is-IS=BIFROST SubBil ori';
                    InstructionalText = 'Allows Subscription Billing operations within the user''s existing access to subscription and contract data.', Comment = 'is-IS=Leyfir áskriftarreikningaaðgerðir innan núverandi aðgangs notandans að áskriftar- og samningsgögnum.';
                }
                group(PostingAccess)
                {
                    Caption = 'BIFROST SubPost ori', Comment = 'is-IS=BIFROST SubPost ori';
                    InstructionalText = 'Allows posting subscription billing documents. Assign it separately to users who should post.', Comment = 'is-IS=Leyfir bókun áskriftarreikningsskjala. Úthlutaðu henni sérstaklega til notenda sem eiga að bóka.';
                }
            }
            group(FinishSummary)
            {
                Visible = CurrentStep = 4;
                Caption = 'Finish setup', Comment = 'is-IS=Ljúka uppsetningu';
                InstructionalText = 'Review the summary. Finish marks this assisted setup complete. You can repeat the wizard later.', Comment = 'is-IS=Farðu yfir samantektina. Ljúka merkir þessari leiðsögn um uppsetningu lokið. Þú getur endurtekið leiðsögnina síðar.';
                field(OperationsSummary; DoneTxt)
                {
                    Caption = 'Operations reviewed', Comment = 'is-IS=Aðgerðir skoðaðar';
                    ToolTip = 'Shows that the introduction to subscription operations has been reviewed.', Comment = 'is-IS=Sýnir að kynning á áskriftaraðgerðum hafi verið skoðuð.';
                    Editable = false;
                }
                field(HttpSummary; HttpSummary)
                {
                    Caption = 'HTTP', Comment = 'is-IS=HTTP';
                    ToolTip = 'Shows whether HTTP is enabled or needs an administrator.', Comment = 'is-IS=Sýnir hvort HTTP sé virkt eða þarfnist stjórnanda.';
                    Editable = false;
                }
                field(AccessSummary; DoneTxt)
                {
                    Caption = 'Access guidance reviewed', Comment = 'is-IS=Aðgangsleiðbeiningar skoðaðar';
                    ToolTip = 'Shows that the permission-set guidance has been reviewed; no permissions were assigned.', Comment = 'is-IS=Sýnir að leiðbeiningar um heimildasamstæður hafi verið skoðaðar; engum heimildum var úthlutað.';
                    Editable = false;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Back)
            {
                InFooterBar = true;
                Enabled = CurrentStep > 1;
                Caption = 'Back', Comment = 'is-IS=Til baka';
                ToolTip = 'Return to the previous step.', Comment = 'is-IS=Farðu aftur í fyrra skref.';
                Image = PreviousRecord;
                trigger OnAction()
                begin
                    CurrentStep := WizardMgt.NextStep(CurrentStep, false);
                    RefreshStatus();
                end;
            }
            action(Next)
            {
                InFooterBar = true;
                Visible = CurrentStep < 4;
                Caption = 'Next', Comment = 'is-IS=Áfram';
                ToolTip = 'Continue to the next step.', Comment = 'is-IS=Haltu áfram í næsta skref.';
                Image = NextRecord;
                trigger OnAction()
                begin
                    CurrentStep := WizardMgt.NextStep(CurrentStep, true);
                    RefreshStatus();
                end;
            }
            action(FinishSetup)
            {
                InFooterBar = true;
                Visible = CurrentStep = 4;
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                ToolTip = 'Mark this assisted setup complete and close the wizard.', Comment = 'is-IS=Merktu þessari leiðsögn um uppsetningu lokið og lokaðu henni.';
                Image = Approve;
                trigger OnAction()
                begin
                    WizardMgt.Finish();
                    CurrPage.Close();
                end;
            }
            action(EnableHttp)
            {
                InFooterBar = true;
                Visible = (CurrentStep = 2) and not HttpEnabled;
                Caption = 'Enable HTTP in Bifrost Setup', Comment = 'is-IS=Virkja HTTP í uppsetningu Bifröst';
                ToolTip = 'Open Foundation''s setup wizard, then refresh this app''s HTTP status.', Comment = 'is-IS=Opnaðu uppsetningarleiðsögn Foundation og endurnýjaðu síðan HTTP-stöðu þessa forrits.';
                Image = Setup;
                trigger OnAction()
                begin
                    if not CanWriteAppSetting then begin
                        Message(AskAdministratorTxt);
                        exit;
                    end;
                    Page.RunModal(Page::"Setup Wizard ori");
                    RefreshStatus();
                end;
            }
            action(Verify)
            {
                InFooterBar = true;
                Visible = CurrentStep = 2;
                Caption = 'Verify', Comment = 'is-IS=Staðfesta';
                ToolTip = 'Read this app''s HTTP status again without changing it.', Comment = 'is-IS=Lestu HTTP-stöðu þessa forrits aftur án þess að breyta henni.';
                Image = Refresh;
                trigger OnAction()
                begin
                    RefreshStatus();
                end;
            }
            action(ShowOperations)
            {
                InFooterBar = true;
                Visible = CurrentStep = 1;
                Caption = 'Show operations', Comment = 'is-IS=Sýna aðgerðir';
                ToolTip = 'Open Bifrost Message Types to see installed operations.', Comment = 'is-IS=Opnaðu Skilaboðategundir Bifröst til að sjá uppsettar aðgerðir.';
                Image = List;
                trigger OnAction()
                begin
                    Page.RunModal(Page::"SubBil Operations ori");
                end;
            }
            action(Documentation)
            {
                InFooterBar = true;
                Visible = CurrentStep = 1;
                Caption = 'Documentation', Comment = 'is-IS=Skjölun';
                ToolTip = 'Open the Subscription Billing documentation.', Comment = 'is-IS=Opnaðu skjölun áskriftareikningagerðar.';
                Image = Help;
                trigger OnAction()
                begin
                    Hyperlink('https://docs.bifrost.origo.is/en-us/subscription-billing/');
                end;
            }
            action(OpenUsers)
            {
                InFooterBar = true;
                Visible = CurrentStep = 3;
                Caption = 'Open Users', Comment = 'is-IS=Opna notendur';
                ToolTip = 'Open Users to review and assign access.', Comment = 'is-IS=Opnaðu Notendur til að skoða og úthluta aðgangi.';
                Image = Users;
                RunObject = page Users;
            }
            action(OpenPermissionSets)
            {
                InFooterBar = true;
                Visible = CurrentStep = 3;
                Caption = 'Open Permission Sets', Comment = 'is-IS=Opna heimildasamstæður';
                ToolTip = 'Open the standard Permission Sets page.', Comment = 'is-IS=Opnaðu stöðluðu síðuna Heimildasamstæður.';
                Image = Permission;
                RunObject = page "Permission Sets";
            }
        }
    }
    trigger OnOpenPage()
    begin
        CurrentStep := 1;
        RefreshStatus();
    end;

    local procedure RefreshStatus()
    begin
        HttpEnabled := WizardMgt.IsHttpEnabled();
        CanWriteAppSetting := WizardMgt.CanEnableHttp();
        if HttpEnabled then
            HttpSummary := DoneTxt
        else
            HttpSummary := NeedsAdministratorTxt;
    end;

    var
        WizardMgt: Codeunit "SubBil Wizard Mgt ori";
        CurrentStep: Integer;
        HttpEnabled: Boolean;
        CanWriteAppSetting: Boolean;
        HttpSummary: Text;
        DoneTxt: Label 'Done', Comment = 'is-IS=Lokið';
        NeedsAdministratorTxt: Label 'Needs an administrator', Comment = 'is-IS=Þarfnast stjórnanda';
        AskAdministratorTxt: Label 'HTTP could not be enabled here. Ask an administrator to enable it in Bifrost Setup, then choose Verify.', Comment = 'is-IS=Ekki var hægt að virkja HTTP hér. Biddu stjórnanda um að virkja það í uppsetningu Bifröst og veldu síðan Staðfesta.';
}
