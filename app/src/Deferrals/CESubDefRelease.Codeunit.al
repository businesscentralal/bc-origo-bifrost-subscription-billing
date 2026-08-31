namespace Origo.APP.CloudEvents.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.APP.CloudEvents;

/// <summary>
/// Implements the <c>Subscription.Deferral.Release</c> Cloud Event message type.
/// Releases deferred revenue and cost up to a given date by running Microsoft's
/// "Contract Deferrals Release" report, which posts to the general ledger. The report's own
/// procedures are internal, so this runs the report object itself with request page parameters
/// built as XML - a plain Data.Records.Set cannot post G/L entries.
/// </summary>
codeunit 10035055 "CE Sub Def Release Impl ori" implements "Cloud Event Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "CE Sub Helper ori";
        PostUntilAfterPostingErr: Label 'The parameter ''postUntilDate'' (%1) must not be later than ''postingDate'' (%2).', Comment = '%1 = post until date, %2 = posting date||is-IS=Færibreytan ''postUntilDate'' (%1) má ekki vera síðar en ''postingDate'' (%2).';
        DescriptionLbl: Label 'Releases deferred revenue and cost for customer and vendor Subscription Contracts up to a date, posting the release to the general ledger.', MaxLength = 250, Comment = 'is-IS=Losar frestaðar tekjur og kostnað fyrir áskriftarsamninga viðskiptavina og birgja fram að tilteknum degi og bókfærir losunina í fjárhagsbókhald.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Cust. Sub. Contract Deferral");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Cloud Event Msg Direction ori"
    begin
        exit(Enum::"Cloud Event Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "CE Message Argument ori")
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Subscription.Deferral.Release');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Runs Microsoft''s "Contract Deferrals Release" report, which releases every eligible deferred');
        HelpBuilder.AppendLine('revenue and cost entry - customer (table 8066) and vendor (table 8072) - whose posting date');
        HelpBuilder.AppendLine('falls on or before the given date, and posts the release to the general ledger.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| postingDate | Date | No | The date the release is posted under. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postUntilDate | Date | No | Deferrals posted on or before this date are released. Defaults to postingDate. Must not be later than postingDate. |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Dates use the ISO format `YYYY-MM-DD`.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "postingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "postUntilDate": "2026-08-31"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "postingDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "postUntilDate": "2026-08-31",');
        HelpBuilder.AppendLine('  "customerDeferralsReleased": 8,');
        HelpBuilder.AppendLine('  "vendorDeferralsReleased": 3,');
        HelpBuilder.AppendLine('  "totalDeferralsReleased": 11');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('The released counts are measured by comparing the number of eligible, unreleased deferral');
        HelpBuilder.AppendLine('rows before and after the run. A run that finds nothing eligible is still a success, with');
        HelpBuilder.AppendLine('every count at 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| postUntilDate is later than postingDate | The parameter ''postUntilDate'' (%1) must not be later than ''postingDate'' (%2). |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is posted.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type posts to the general ledger and cannot be undone**, except by posting a');
        HelpBuilder.AppendLine('compensating credit memo through the normal deferral correction process. It is **not scoped**');
        HelpBuilder.AppendLine('to a single contract - it releases every eligible customer and vendor deferral, across every');
        HelpBuilder.AppendLine('Subscription Contract, whose posting date falls on or before `postUntilDate`. Confirm the date');
        HelpBuilder.AppendLine('carefully before calling this in a production environment.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('- `Subscription.Analysis.Recalculate`');

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

    /// <summary>Runs the deferral release report. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "CE Message Argument ori")
    var
        CustSubContractDeferral: Record "Cust. Sub. Contract Deferral";
        VendSubContractDeferral: Record "Vend. Sub. Contract Deferral";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        XmlBuilder: TextBuilder;
        RequestPageXml: Text;
        PostingDate: Date;
        PostUntilDate: Date;
        CustomerBeforeCount: Integer;
        VendorBeforeCount: Integer;
        CustomerAfterCount: Integer;
        VendorAfterCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        PostingDate := Helper.GetDateOrDefault(RequestJson, 'postingDate', WorkDate());
        PostUntilDate := Helper.GetDateOrDefault(RequestJson, 'postUntilDate', PostingDate);

        if PostUntilDate > PostingDate then
            Error(PostUntilAfterPostingErr, Helper.FormatDate(PostUntilDate), Helper.FormatDate(PostingDate));

        CustSubContractDeferral.SetRange(Released, false);
        CustSubContractDeferral.SetFilter("Posting Date", '<=%1', PostUntilDate);
        CustomerBeforeCount := CustSubContractDeferral.Count();

        VendSubContractDeferral.SetRange(Released, false);
        VendSubContractDeferral.SetFilter("Posting Date", '<=%1', PostUntilDate);
        VendorBeforeCount := VendSubContractDeferral.Count();

        XmlBuilder.Append('<?xml version="1.0" encoding="utf-8" standalone="yes"?><ReportParameters><Options><Field name="PostingDateReq">');
        XmlBuilder.Append(Helper.FormatDate(PostingDate));
        XmlBuilder.Append('</Field><Field name="PostUntilDateReq">');
        XmlBuilder.Append(Helper.FormatDate(PostUntilDate));
        XmlBuilder.Append('</Field></Options></ReportParameters>');
        RequestPageXml := XmlBuilder.ToText();

        Report.Execute(Report::"Contract Deferrals Release", RequestPageXml);

        CustSubContractDeferral.Reset();
        CustSubContractDeferral.SetRange(Released, false);
        CustSubContractDeferral.SetFilter("Posting Date", '<=%1', PostUntilDate);
        CustomerAfterCount := CustSubContractDeferral.Count();

        VendSubContractDeferral.Reset();
        VendSubContractDeferral.SetRange(Released, false);
        VendSubContractDeferral.SetFilter("Posting Date", '<=%1', PostUntilDate);
        VendorAfterCount := VendSubContractDeferral.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('postingDate', Helper.FormatDate(PostingDate));
        ResponseJson.Add('postUntilDate', Helper.FormatDate(PostUntilDate));
        ResponseJson.Add('customerDeferralsReleased', CustomerBeforeCount - CustomerAfterCount);
        ResponseJson.Add('vendorDeferralsReleased', VendorBeforeCount - VendorAfterCount);
        ResponseJson.Add('totalDeferralsReleased', (CustomerBeforeCount - CustomerAfterCount) + (VendorBeforeCount - VendorAfterCount));
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
