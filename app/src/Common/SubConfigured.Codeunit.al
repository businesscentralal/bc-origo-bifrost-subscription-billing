namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Company-local availability of the Subscription Billing message types (#98).
/// A company is configured when its Subscription Contract Setup has at least one of
/// Subscription Header No., Cust. Sub. Contract Nos. or Vend. Sub. Contract Nos. set.
/// The record Microsoft creates on install does not count while those three are blank.
/// Each call reads the table again, so a setup change is visible without a restart.
/// The read does not insert setup and does not change it.
/// </summary>
codeunit 10035088 "Sub Configured ori"
{
    Access = Internal;
    // Execute is inherent so discovery can call this. The setup read uses the caller's own
    // permission. A caller who cannot read the table is treated as not configured, so listing
    // the types does not throw. This set does not grant the Microsoft table.
    InherentPermissions = X;
    InherentEntitlements = X;

    /// <summary>
    /// True when the current company has at least one Subscription Billing number series on setup.
    /// </summary>
    procedure IsConfigured(): Boolean
    begin
        exit(IsConfiguredInCompany(CopyStr(CompanyName(), 1, 30)));
    end;

    /// <summary>
    /// True when the named company has at least one Subscription Billing number series on setup.
    /// An empty name is not a company and is not configured.
    /// </summary>
    /// <param name="ForCompany">Company name whose setup is read. The current company is used when it matches.</param>
    procedure IsConfiguredInCompany(ForCompany: Text[30]): Boolean
    var
        Setup: Record "Subscription Contract Setup";
    begin
        if ForCompany = '' then
            exit(false);
        // ReadPermission does not throw. Callers without the Microsoft table stay "not configured".
        if not Setup.ReadPermission() then
            exit(false);

        if ForCompany <> CompanyName() then
            Setup.ChangeCompany(ForCompany);
        Setup.ReadIsolation := IsolationLevel::ReadCommitted;
        Setup.SetLoadFields("Subscription Header No.", "Cust. Sub. Contract Nos.", "Vend. Sub. Contract Nos.");
        if not Setup.Get() then
            exit(false);
        exit(HasNumberSeries(Setup));
    end;

    /// <summary>
    /// Explains when the Subscription Billing operations appear. The wizard shows the same sentence.
    /// </summary>
    procedure AvailabilityExplanation(): Text
    var
        ExplanationLbl: Label 'Subscription Billing operations appear in this company only when Subscription Contract Setup has at least one of Subscription Nos. (Subscription Header No.), Customer Subscription Contract Nos. or Vendor Subscription Contract Nos. set. Clearing all three hides them on the next call, with no restart. Posting still needs BIFROST SubPost ori.', Comment = 'is-IS=Aðgerðir áskriftareikningagerðar birtast í þessu fyrirtæki aðeins þegar uppsetning áskriftarsamninga hefur að minnsta kosti eitt af Subscription Nos. (Subscription Header No.), Customer Subscription Contract Nos. eða Vendor Subscription Contract Nos. skráð. Ef öll þrjú eru auð hverfa þær við næsta kall, án endurræsingar. Bókun þarf áfram BIFROST SubPost ori.';
    begin
        exit(ExplanationLbl);
    end;

    local procedure HasNumberSeries(Setup: Record "Subscription Contract Setup"): Boolean
    begin
        exit((Setup."Subscription Header No." <> '') or
            (Setup."Cust. Sub. Contract Nos." <> '') or
            (Setup."Vend. Sub. Contract Nos." <> ''));
    end;
}
