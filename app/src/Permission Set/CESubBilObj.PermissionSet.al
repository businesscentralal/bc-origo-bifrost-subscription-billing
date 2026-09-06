namespace Origo.APP.CloudEvents.SubscriptionBilling;

/// <summary>
/// Grants execute permission on every object in the Cloud Events Subscription Billing extension.
/// Assign this alongside a Cloud Events Core permission set to let a user or service invoke the
/// Subscription Billing message types. The message types themselves still run under the caller's
/// own permissions on the Microsoft Subscription Billing tables, so this set does not widen
/// access to subscription or contract data.
/// </summary>
permissionset 10035062 "CE Sub Bil Obj ori"
{
    Caption = 'Cloud Events Sub. Billing', MaxLength = 30, Comment = 'is-IS=Atburðir í skýinu - áskriftir';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "CE Sub Helper ori" = X,
        codeunit "CE Sub Write Process ori" = X,
        codeunit "CE Sub Line Create Impl ori" = X,
        codeunit "CE Sub Con GetLines Impl ori" = X,
        codeunit "CE Sub Con CrInvoice Impl ori" = X,
        codeunit "CE Sub Con PrvInvoice Impl ori" = X,
        codeunit "CE Sub Con UpdDates Impl ori" = X,
        codeunit "CE Sub Con UpdFCY Impl ori" = X,
        codeunit "CE Sub Vend GetLines Impl ori" = X,
        codeunit "CE Sub Vend CrInvoice Impl ori" = X,
        codeunit "CE Sub Vend PrvInv Impl ori" = X,
        codeunit "CE Sub Bil CrProposal Impl ori" = X,
        codeunit "CE Sub Bil CrDocs Impl ori" = X,
        codeunit "CE Sub Bil PrvDocs Impl ori" = X,
        codeunit "CE Sub PU SetFilter Impl ori" = X,
        codeunit "CE Sub PU CrProposal Impl ori" = X,
        codeunit "CE Sub PU Perform Impl ori" = X,
        codeunit "CE Sub Ren Extend Impl ori" = X,
        codeunit "CE Sub Ren CrQuote Impl ori" = X,
        codeunit "CE Sub Usg Import Impl ori" = X,
        codeunit "CE Sub Usg Process Impl ori" = X,
        codeunit "CE Sub Def Release Impl ori" = X,
        codeunit "CE Sub Ana Recalc Impl ori" = X,
        codeunit "CE Sub Imp CrContr Impl ori" = X;
}
