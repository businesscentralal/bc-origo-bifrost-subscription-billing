namespace Origo.Bifrost.SubscriptionBilling;

/// <summary>
/// Grants execute permission on every object in the Bifrost Subscription Billing extension.
/// Assign this alongside a Bifrost Core permission set to let a user or service invoke the
/// Subscription Billing message types. The message types themselves still run under the caller's
/// own permissions on the Microsoft Subscription Billing tables, so this set does not widen
/// access to subscription or contract data.
/// </summary>
permissionset 10035062 "BIFROST SubBil ori"
{
    Caption = 'Bifrost Sub. Billing', MaxLength = 30, Comment = 'is-IS=Bifröst - áskriftir';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Sub Helper ori" = X,
        codeunit "Sub Write Process ori" = X,
        codeunit "Sub Line Create Impl ori" = X,
        codeunit "Sub Con GetLines Impl ori" = X,
        codeunit "Sub Con CrInvoice Impl ori" = X,
        codeunit "Sub Con PrvInvoice Impl ori" = X,
        codeunit "Sub Con UpdDates Impl ori" = X,
        codeunit "Sub Con UpdFCY Impl ori" = X,
        codeunit "Sub Vend GetLines Impl ori" = X,
        codeunit "Sub Vend CrInvoice Impl ori" = X,
        codeunit "Sub Vend PrvInv Impl ori" = X,
        codeunit "Sub Bil CrProposal Impl ori" = X,
        codeunit "Sub Bil CrDocs Impl ori" = X,
        codeunit "Sub Bil PrvDocs Impl ori" = X,
        codeunit "Sub PU SetFilter Impl ori" = X,
        codeunit "Sub PU CrProposal Impl ori" = X,
        codeunit "Sub PU Perform Impl ori" = X,
        codeunit "Sub Ren Extend Impl ori" = X,
        codeunit "Sub Ren CrQuote Impl ori" = X,
        codeunit "Sub Usg Import Impl ori" = X,
        codeunit "Sub Usg Process Impl ori" = X,
        codeunit "Sub Def Release Impl ori" = X,
        codeunit "Sub Ana Recalc Impl ori" = X,
        codeunit "Sub Imp CrContr Impl ori" = X,
        codeunit "Sub Line Help ori" = X,
        codeunit "Sub Con Help ori" = X,
        codeunit "Sub Vend Help ori" = X,
        codeunit "Sub Bil Help ori" = X,
        codeunit "Sub PU Help ori" = X,
        codeunit "Sub Ren Help ori" = X,
        codeunit "Sub Usg Help ori" = X,
        codeunit "Sub Def Help ori" = X,
        codeunit "Sub Ana Help ori" = X,
        codeunit "Sub Imp Help ori" = X;
}
