namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Line.Create</c> Bifrost message type.
/// Applies a Subscription Package to an existing Subscription Header, letting Microsoft's own
/// package application logic derive prices, billing rhythms and dates for each new Subscription
/// Line. A plain Data.Records.Set cannot do this because the lines to insert, and the values on
/// them, are computed by the package application codeunit rather than supplied by the caller.
/// </summary>
codeunit 10035036 "Sub Line Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    var
        Helper: Codeunit "Sub Helper ori";
        ContractParts: Codeunit "Sub Contract Parts ori";
        HeaderNotFoundErr: Label 'The Subscription Header ''%1'' does not exist.', Comment = '%1 = subscription header no.||is-IS=Áskriftarhausinn ''%1'' er ekki til.';
        PackageNotFoundErr: Label 'The Subscription Package ''%1'' does not exist.', Comment = '%1 = subscription package code||is-IS=Áskriftarpakkinn ''%1'' er ekki til.';
        DescriptionLbl: Label 'Applies a Subscription Package to a Subscription Header, creating Subscription Lines from the package. Returns the number and entry numbers of the lines created.', MaxLength = 250, Comment = 'is-IS=Beitir áskriftarpakka á áskriftarhaus og býr til áskriftarlínur út frá pakkanum. Skilar fjölda og færslunúmerum þeirra lína sem urðu til.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'Subscription.Line.Create, Subscription, Line, Create, package, billing', Comment = 'is-IS=Subscription.Line.Create, áskrift, lína, stofna, pakki, reikningur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Subscription.Line.Create: Applies a package and creates subscription lines.', Comment = 'is-IS=Subscription.Line.Create: Beitir pakka og stofnar áskriftarlínur.';
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
        Examples.Add(ContractMgt.Example('Apply a package to a Subscription',
            '{"type":"Subscription.Line.Create","subject":"SUB000010","data":{"subscriptionPackageCode":"STANDARD","subscriptionLineStartDate":"2026-09-01"}}',
            '{"status":"Success","subscriptionHeaderNo":"SUB000010","subscriptionPackageCode":"STANDARD","linesCreated":3,"createdLines":[1001,1002,1003]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates Subscription Lines on an existing Subscription Header by applying a Subscription Package, through Microsoft''s own package application, the ' +
            'logic the Subscription page uses. Prices, billing rhythm and dates come from the package.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('Every package line becomes a Subscription Line, unless usageBasedBillingPackageLinesOnly leaves it out. ' +
            ContractParts.BooleanNote() +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Line.Create');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteProcess: Codeunit "Sub Write Process ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if Argument."Omit Commit" then begin
            PerformWrite(Argument);
            exit;
        end;

        Clear(WriteProcess);
        if not WriteProcess.Run(Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Applies the package and reports the Subscription Lines created. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        SubscriptionHeader: Record "Subscription Header";
        SubscriptionPackage: Record "Subscription Package";
        SubscriptionLine: Record "Subscription Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CreatedLinesArray: JsonArray;
        SubscriptionHeaderNo: Code[20];
        SubscriptionPackageCode: Code[20];
        StartDate: Date;
        EndDate: Date;
        UsageBasedOnly: Boolean;
        MaxEntryNoBefore: Integer;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        SubscriptionHeaderNo := Helper.GetSubjectOr(Argument, RequestJson, 'subscriptionHeaderNo', true);
        SubscriptionPackageCode := Helper.GetCode20(RequestJson, 'subscriptionPackageCode', true);
        StartDate := Helper.GetDate(RequestJson, 'subscriptionLineStartDate', false);
        EndDate := Helper.GetDate(RequestJson, 'subscriptionLineEndDate', false);
        UsageBasedOnly := Helper.GetBoolean(RequestJson, 'usageBasedBillingPackageLinesOnly', false);

        if not SubscriptionHeader.Get(SubscriptionHeaderNo) then
            Error(HeaderNotFoundErr, SubscriptionHeaderNo);
        SubscriptionHeader.TestField("Source No.");

        if not SubscriptionPackage.Get(SubscriptionPackageCode) then
            Error(PackageNotFoundErr, SubscriptionPackageCode);
        SubscriptionPackage.SetRange(Code, SubscriptionPackageCode);

        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        LinesBefore := SubscriptionLine.Count();
        MaxEntryNoBefore := 0;
        SubscriptionLine.SetLoadFields("Entry No.");
        if SubscriptionLine.FindLast() then
            MaxEntryNoBefore := SubscriptionLine."Entry No.";

        SubscriptionHeader.InsertServiceCommitmentsFromServCommPackage(StartDate, EndDate, SubscriptionPackage, UsageBasedOnly);

        SubscriptionLine.Reset();
        SubscriptionLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        LinesAfter := SubscriptionLine.Count();

        SubscriptionLine.SetFilter("Entry No.", '>%1', MaxEntryNoBefore);
        SubscriptionLine.SetLoadFields("Entry No.");
        if SubscriptionLine.FindSet() then
            repeat
                CreatedLinesArray.Add(SubscriptionLine."Entry No.");
            until SubscriptionLine.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('subscriptionHeaderNo', SubscriptionHeaderNo);
        ResponseJson.Add('subscriptionPackageCode', SubscriptionPackageCode);
        ResponseJson.Add('linesCreated', LinesAfter - LinesBefore);
        ResponseJson.Add('createdLines', CreatedLinesArray);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
