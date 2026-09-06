namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Line.Create</c> Cloud Event message type.
/// Applies a Subscription Package to an existing Subscription Header, letting Microsoft's own
/// package application logic derive prices, billing rhythms and dates for each new Subscription
/// Line. A plain Data.Records.Set cannot do this because the lines to insert, and the values on
/// them, are computed by the package application codeunit rather than supplied by the caller.
/// </summary>
codeunit 10035036 "CE Sub Line Create Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
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

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    /// <summary>Builds the Markdown help document returned when the message type is inspected.</summary>
    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Line.Create');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Creates Subscription Lines (table 8059) on an existing Subscription Header by applying a');
        HelpBuilder.AppendLine('Subscription Package. Every package line becomes a Subscription Line, with prices, billing');
        HelpBuilder.AppendLine('rhythm and dates derived by Microsoft''s own package application logic - the same logic the');
        HelpBuilder.AppendLine('Subscription Header page uses when a package is applied from the client.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| subscriptionHeaderNo | Code[20] | Yes | The Subscription Header to add lines to. May also be supplied as the message subject. |');
        HelpBuilder.AppendLine('| subscriptionPackageCode | Code[20] | Yes | The Subscription Package to apply. |');
        HelpBuilder.AppendLine('| subscriptionLineStartDate | Date | No | Start date for the new lines. Omit, or send 0001-01-01, to let the package''s own formula decide. |');
        HelpBuilder.AppendLine('| subscriptionLineEndDate | Date | No | End date for the new lines. Omit to leave the lines open ended. |');
        HelpBuilder.AppendLine('| usageBasedBillingPackageLinesOnly | Boolean | No | When true, only the package''s usage based lines are created. Defaults to false. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SUB000010",');
        HelpBuilder.AppendLine('  "subscriptionPackageCode": "STANDARD",');
        HelpBuilder.AppendLine('  "subscriptionLineStartDate": "2026-09-01"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "subscriptionHeaderNo": "SUB000010",');
        HelpBuilder.AppendLine('  "subscriptionPackageCode": "STANDARD",');
        HelpBuilder.AppendLine('  "linesCreated": 3,');
        HelpBuilder.AppendLine('  "createdLines": [1001, 1002, 1003]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`createdLines` holds the `Entry No.` of every Subscription Line this call added. A package');
        HelpBuilder.AppendLine('that adds nothing - for example because every line is filtered out by');
        HelpBuilder.AppendLine('`usageBasedBillingPackageLinesOnly` - is still a success, with `linesCreated` of 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| The Subscription Header does not exist | The Subscription Header ''%1'' does not exist. |');
        HelpBuilder.AppendLine('| The header has no Source No. | Standard TestField error naming ''Source No.''. |');
        HelpBuilder.AppendLine('| The Subscription Package does not exist | The Subscription Package ''%1'' does not exist. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is written.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('This message type writes. Only Subscription Lines under the given header are created - no');
        HelpBuilder.AppendLine('contract is touched and nothing is billed. The write runs in an isolated transaction that');
        HelpBuilder.AppendLine('rolls back on error.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Contract.GetLines`');
        HelpBuilder.AppendLine('- `Subscription.Contract.CreateInvoice`');

        Argument.SetResponseMarkdown(HelpBuilder.ToText());
    end;

    internal procedure ExecuteCloudEventTask(var Argument: Record "CE Message Argument ori")
    var
        WriteProcess: Codeunit "CE Sub Write Process ori";
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
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
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
