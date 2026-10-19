namespace Origo.Bifrost.SubscriptionBilling;

using Origo.Bifrost;

/// <summary>
/// Posting gate for Bifrost Subscription Billing.
/// Subscription.Billing.PostDocuments requires write permission on Sub Posting ori,
/// which only BIFROST SubPost ori grants.
/// </summary>
codeunit 10035084 "Sub Posting Gate ori"
{
    Access = Internal;

    /// <summary>
    /// Returns false and writes the denial on Argument when the caller cannot post.
    /// Returns true and leaves Argument unchanged when the caller holds BIFROST SubPost ori.
    /// </summary>
    procedure AssertCanPost(var Argument: Record "Message Argument ori"): Boolean
    var
        PostingDeniedErr: Label 'Posting denied: missing ''%1'' permission set.', Comment = '%1 = permission set name||is-IS=Bókun hafnað: vantar heimildasettið ''%1''.';
        PermissionSetNameTok: Label 'BIFROST SubPost ori', Locked = true;
    begin
        if HasPostingPermission() then
            exit(true);

        Argument.RespondWithError(
            "Bifrost Error Code ori"::PermissionDenied,
            StrSubstNo(PostingDeniedErr, PermissionSetNameTok),
            '', '', '', '');
        exit(false);
    end;

    /// <summary>
    /// True when the current user has write permission on the subscription billing posting token.
    /// </summary>
    procedure HasPostingPermission(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(Database::"Sub Posting ori");
        exit(RecRef.WritePermission());
    end;
}
