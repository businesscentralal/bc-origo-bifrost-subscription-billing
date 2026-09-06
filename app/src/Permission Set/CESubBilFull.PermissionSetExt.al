namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Origo.APP.CloudEvents;

/// <summary>
/// Extends the Cloud Events full access permission set with the Subscription Billing objects,
/// so anyone already granted full Cloud Events access can invoke these message types too.
/// Execute rights on the implementation codeunits are required for that: without them the
/// dispatcher resolves the interface and then fails when it tries to run the implementation.
/// The message types still run under the caller's own permissions on the Microsoft Subscription
/// Billing tables, so this does not widen access to subscription or contract data.
/// </summary>
permissionsetextension 10035063 "CE Sub Bil Full ori" extends "CE Full Access ori"
{
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
