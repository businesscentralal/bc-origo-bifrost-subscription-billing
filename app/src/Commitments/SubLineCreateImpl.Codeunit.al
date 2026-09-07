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
codeunit 10035036 "Sub Line Create Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
        HeaderNotFoundErr: Label 'The Subscription Header ''%1'' does not exist.', Comment = '%1 = subscription header no.||is-IS=Áskriftarhausinn ''%1'' er ekki til.';
        PackageNotFoundErr: Label 'The Subscription Package ''%1'' does not exist.', Comment = '%1 = subscription package code||is-IS=Áskriftarpakkinn ''%1'' er ekki til.';
        DescriptionLbl: Label 'Applies a Subscription Package to a Subscription Header, creating Subscription Lines from the package. Returns the number and entry numbers of the lines created.', MaxLength = 250, Comment = 'is-IS=Beitir áskriftarpakka á áskriftarhaus og býr til áskriftarlínur út frá pakkanum. Skilar fjölda og færslunúmerum þeirra lína sem urðu til.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Subscription Header");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        LineHelp: Codeunit "Sub Line Help ori";
    begin
        Argument.SetResponseMarkdown(LineHelp.GetHelpMarkdown('Subscription.Line.Create'));
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
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
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
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
