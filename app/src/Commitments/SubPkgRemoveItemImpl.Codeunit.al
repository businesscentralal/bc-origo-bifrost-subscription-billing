namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Package.RemoveItemAssignment</c> Bifrost message type (#41 AC05).
/// Removes the assignment of a Subscription Package to an item (Item Subscription Package) with
/// Delete(true). Sales lines and Subscriptions created from the package earlier keep their lines; only
/// items sold or extended from now on stop getting the package.
/// </summary>
codeunit 10035072 "Sub Pkg RemoveItem Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        AssignmentNotFoundErr: Label 'Subscription Package ''%1'' is not assigned to item ''%2''.', Comment = '%1 = package code, %2 = item number||is-IS=Áskriftarpakkanum ''%1'' er ekki úthlutað á vöruna ''%2''.';
        DescriptionLbl: Label 'Removes the assignment of a Subscription Package to an item, so the item no longer gets the package. Existing Subscriptions keep their lines.', MaxLength = 250, Comment = 'is-IS=Fjarlægir úthlutun áskriftarpakka á vöru, svo varan fær ekki lengur pakkann. Fyrirliggjandi áskriftir halda línum sínum.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Item Subscription Package");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Package.RemoveItemAssignment, Subscription, Package, RemoveItemAssignment, item, subscription package, remove', Comment = 'is-IS=Subscription.Package.RemoveItemAssignment, áskrift, pakki, fjarlægja úthlutun vöru, vara, áskriftarpakki, fjarlægja';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Package.RemoveItemAssignment: Removes a Subscription Package from an item.', Comment = 'is-IS=Subscription.Package.RemoveItemAssignment: Fjarlægir áskriftarpakka af vöru.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope := ContractParts.GetEnvelope(ContractType());
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target := ContractParts.GetTarget(ContractType());
        exit(Target.Count() > 0);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := ContractParts.GetParameters(ContractType());
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response := ContractParts.GetResponse(ContractType());
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors := ContractParts.GetErrors(ContractType());
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect := ContractParts.GetEffect(ContractType());
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related := ContractParts.GetRelated(ContractType());
        exit(Related.Count() > 0);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow := ContractParts.GetWorkflow(ContractType());
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Remove a package from an item',
            '{"type":"Subscription.Package.RemoveItemAssignment","subject":"1896-S","data":{"subscriptionPackageCode":"MONTHLY-SUPPORT"}}',
            '{"status":"Success","itemNo":"1896-S","subscriptionPackageCode":"MONTHLY-SUPPORT","wasStandard":true}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes the Item Subscription Package row that assigns a Subscription Package to an item. New sales lines, Subscriptions and extensions of the item no ' +
            'longer get the package; Subscription Lines created from it before stay as they are.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('wasStandard reports whether the package was a standard package of the item, which Business Central applies without asking. The package itself is not ' +
            'deleted. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Package.RemoveItemAssignment');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformWrite(Rec);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Sub Pkg RemoveItem Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes the package assignment. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        ItemSubscriptionPackage: Record "Item Subscription Package";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
        PackageCode: Code[20];
        WasStandard: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        ItemNo := Helper.GetSubjectOr(RequestJson, 'itemNo', Argument, true);
        PackageCode := Helper.GetCode20(RequestJson, 'subscriptionPackageCode', true);

        if not ItemSubscriptionPackage.Get(ItemNo, PackageCode) then
            Error(AssignmentNotFoundErr, PackageCode, ItemNo);
        WasStandard := ItemSubscriptionPackage.Standard;
        ItemSubscriptionPackage.Delete(true);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('subscriptionPackageCode', PackageCode);
        ResponseJson.Add('wasStandard', WasStandard);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
