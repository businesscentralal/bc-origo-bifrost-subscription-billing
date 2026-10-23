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
        codeunit "Sub Posting Context ori" = X,
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
        codeunit "Sub Bil PostDocs Impl ori" = X,
        codeunit "Sub Con Ccy Restrict ori" = X,
        codeunit "Sub Con Merge Impl ori" = X,
        codeunit "Sub Con Merge Mgt ori" = X,
        codeunit "Sub Posting Gate ori" = X,
        codeunit "Sub PU SetFilter Impl ori" = X,
        codeunit "Sub PU CrProposal Impl ori" = X,
        codeunit "Sub PU Perform Impl ori" = X,
        codeunit "Sub PU Price Update Mgt ori" = X,
        codeunit "Sub PU Calc Base By Perc ori" = X,
        codeunit "Sub PU Price By Percent ori" = X,
        codeunit "Sub PU Recent Item Price ori" = X,
        codeunit "Sub PU Process Price Upd ori" = X,
        codeunit "Sub PU Line Mgt ori" = X,
        codeunit "Sub Ren Extend Impl ori" = X,
        codeunit "Sub Ren CrQuote Impl ori" = X,
        codeunit "Sub Usg Import Impl ori" = X,
        codeunit "Sub Usg Process Impl ori" = X,
        codeunit "Sub Def Release Impl ori" = X,
        codeunit "Sub Ana Recalc Impl ori" = X,
        codeunit "Sub Imp CrContr Impl ori" = X,
        codeunit "Sub Contract Parts ori" = X,
        codeunit "Sub Registration ori" = X,
        codeunit "Sub Bil ClrProposal Impl ori" = X,
        codeunit "Sub Bil DelDocs Impl ori" = X,
        codeunit "Sub Usg Connect Impl ori" = X,
        codeunit "Sub Usg Disconnect Impl ori" = X,
        codeunit "Sub Vend AddToInv Impl ori" = X,
        codeunit "Sub Usg DelData Impl ori" = X,
        codeunit "Sub Bil SetFilter Impl ori" = X,
        codeunit "Sub Con RemoveLine Impl ori" = X,
        codeunit "Sub Pkg RemoveItem Impl ori" = X;
}
