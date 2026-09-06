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
        PostingDateNotSupportedErr: Label 'Business Central posts this release under the work date (%1) and offers no supported way to post it under a different one, so ''postingDate'' (%2) cannot be honoured. Omit ''postingDate'', or set the session work date to %2 before calling.', Comment = '%1 = work date, %2 = requested posting date||is-IS=Business Central bókar þessa losun miðað við vinnudagsetninguna (%1) og býður enga studda leið til að bóka hana miðað við aðra, svo ekki er hægt að virða ''postingDate'' (%2). Slepptu ''postingDate'', eða stilltu vinnudagsetningu setunnar á %2 áður en kallað er.';
        WouldOverReleaseErr: Label 'Refusing to run: Business Central would release %1 deferral(s) posted between ''postUntilDate'' (%2) and the work date (%3). The report cannot be told where to stop from an external app, so it always releases everything eligible up to the work date. Set the session work date to %2 before calling, or raise ''postUntilDate'' to %3 to accept releasing all of them.', Comment = '%1 = number of deferrals, %2 = post until date, %3 = work date||is-IS=Keyrslu hafnað: Business Central myndi losa %1 frestun(ar) sem bókast á milli ''postUntilDate'' (%2) og vinnudagsetningarinnar (%3). Ekki er hægt að segja skýrslunni hvar hún á að stoppa frá utanaðkomandi appi, svo hún losar alltaf allt sem uppfyllir skilyrði fram að vinnudagsetningu. Stilltu vinnudagsetningu setunnar á %2 áður en kallað er, eða hækkaðu ''postUntilDate'' í %3 til að samþykkja að þær losni allar.';
        OvershotWindowMsg: Label 'Business Central released %1 deferral(s) posted after ''postUntilDate'' (%2). The release has already posted to the general ledger and cannot be undone from here - reconcile before releasing again.', Comment = '%1 = number of deferrals released outside the window, %2 = post until date||is-IS=Business Central losaði %1 frestun(ar) sem bókast eftir ''postUntilDate'' (%2). Losunin er þegar bókfærð í fjárhagsbókhald og verður ekki afturkölluð héðan - stemmdu af áður en losað er aftur.';
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
        HelpBuilder.AppendLine('revenue and cost entry - customer (table 8066) and vendor (table 8072) - and posts the');
        HelpBuilder.AppendLine('release to the general ledger.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**The report always uses the session work date.** Its two dates live on its request page,');
        HelpBuilder.AppendLine('`SetRequestPageParameters` is internal to Microsoft''s app, and request page XML is not');
        HelpBuilder.AppendLine('applied to this report, so an external app cannot tell it where to stop. It releases');
        HelpBuilder.AppendLine('everything eligible up to the work date, posted under the work date.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('`postingDate` and `postUntilDate` are therefore **not instructions - they are a guard**. This');
        HelpBuilder.AppendLine('call checks what the report is about to do and refuses to run when that is more than the');
        HelpBuilder.AppendLine('caller asked for, rather than posting to the general ledger and reporting a number that does');
        HelpBuilder.AppendLine('not match what happened. To release up to an earlier date, set the session work date first.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Parameter | Type | Required | Description |');
        HelpBuilder.AppendLine('| --- | --- | --- | --- |');
        HelpBuilder.AppendLine('| postingDate | Date | No | The date the caller expects the release to post under. Must equal the work date, because that is the only date Business Central will use. Defaults to the work date. |');
        HelpBuilder.AppendLine('| postUntilDate | Date | No | The latest deferral posting date the caller is willing to release. The call is refused if the report would go past it. Defaults to postingDate. Must not be later than postingDate. |');
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
        HelpBuilder.AppendLine('The counts are measured across **every** unreleased deferral, not only the ones inside the');
        HelpBuilder.AppendLine('requested window, so they say what the run actually released. A run that finds nothing');
        HelpBuilder.AppendLine('eligible is still a success, with every count at 0.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('If anything outside the window is released anyway, the response carries');
        HelpBuilder.AppendLine('`releasedOutsideRequestedWindow` and a `warning`, so a run that got past the guard is');
        HelpBuilder.AppendLine('still visible in the response rather than only in the ledger.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('| Condition | Message |');
        HelpBuilder.AppendLine('| --- | --- |');
        HelpBuilder.AppendLine('| postUntilDate is later than postingDate | The parameter ''postUntilDate'' (%1) must not be later than ''postingDate'' (%2). |');
        HelpBuilder.AppendLine('| postingDate is not the work date | Business Central posts this release under the work date (%1) ... so ''postingDate'' (%2) cannot be honoured. |');
        HelpBuilder.AppendLine('| The report would release deferrals past postUntilDate | Refusing to run: Business Central would release %1 deferral(s) posted between ''postUntilDate'' (%2) and the work date (%3). |');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('Errors return `{ "status": "Error", "error": "...", "callstack": "..." }` and nothing is posted.');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('## Safety');
        HelpBuilder.AppendLine();
        HelpBuilder.AppendLine('**This message type posts to the general ledger and cannot be undone**, except by posting a');
        HelpBuilder.AppendLine('compensating credit memo through the normal deferral correction process. It is **not scoped**');
        HelpBuilder.AppendLine('to a single contract - it releases every eligible customer and vendor deferral, across every');
        HelpBuilder.AppendLine('Subscription Contract, up to the work date. The `postUntilDate` guard is what keeps that from');
        HelpBuilder.AppendLine('reaching further than the caller intended; it cannot narrow the run, only refuse it. Confirm');
        HelpBuilder.AppendLine('the work date carefully before calling this in a production environment.');
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        XmlBuilder: TextBuilder;
        RequestPageXml: Text;
        PostingDate: Date;
        PostUntilDate: Date;
        CustomerBeforeCount: Integer;
        CustomerBeforeInWindow: Integer;
        VendorBeforeCount: Integer;
        VendorBeforeInWindow: Integer;
        CustomerAfterCount: Integer;
        VendorAfterCount: Integer;
        CustomerReleased: Integer;
        VendorReleased: Integer;
        InWindowReleased: Integer;
        OutsideWindowReleased: Integer;
        WouldOverRelease: Integer;
        EffectiveDate: Date;
    begin
        RequestJson := Argument.GetRequestJson();
        PostingDate := Helper.GetDateOrDefault(RequestJson, 'postingDate', WorkDate());
        PostUntilDate := Helper.GetDateOrDefault(RequestJson, 'postUntilDate', PostingDate);

        if PostUntilDate > PostingDate then
            Error(PostUntilAfterPostingErr, Helper.FormatDate(PostUntilDate), Helper.FormatDate(PostingDate));

        // Microsoft's report takes its two dates from its request page, backed by global variables.
        // "Contract Deferrals Release".SetRequestPageParameters is internal, and Report.Execute's
        // request page XML is not applied to this report, so neither date can actually be passed in
        // from an external app: the report always uses the work date and releases everything
        // eligible up to it. Verified against Business Central 28.4. Rather than accept dates and
        // quietly ignore them - on a call that posts irreversibly to the general ledger - the two
        // parameters are enforced as a precondition on what the run is about to do.
        EffectiveDate := WorkDate();

        if PostingDate <> EffectiveDate then
            Error(PostingDateNotSupportedErr, Helper.FormatDate(EffectiveDate), Helper.FormatDate(PostingDate));

        if PostUntilDate < EffectiveDate then begin
            WouldOverRelease :=
                (CountUnreleasedCustomerDeferrals(EffectiveDate) - CountUnreleasedCustomerDeferrals(PostUntilDate)) +
                (CountUnreleasedVendorDeferrals(EffectiveDate) - CountUnreleasedVendorDeferrals(PostUntilDate));
            if WouldOverRelease > 0 then
                Error(WouldOverReleaseErr, WouldOverRelease, Helper.FormatDate(PostUntilDate), Helper.FormatDate(EffectiveDate));
        end;

        // Count every unreleased deferral, not only the ones inside the requested window. The report
        // decides for itself how far it goes, and measuring only the window would hide a run that
        // went past it - which is not something to find out later, because this posts to the
        // general ledger and cannot be undone.
        CustomerBeforeCount := CountUnreleasedCustomerDeferrals(0D);
        CustomerBeforeInWindow := CountUnreleasedCustomerDeferrals(PostUntilDate);
        VendorBeforeCount := CountUnreleasedVendorDeferrals(0D);
        VendorBeforeInWindow := CountUnreleasedVendorDeferrals(PostUntilDate);

        // Business Central matches request page values against the report they belong to, and drops
        // the whole parameter set without complaint when the document does not identify it. Omit the
        // name and id attributes and this report silently falls back to its own defaults - which
        // means releasing everything eligible up to the work date instead of up to postUntilDate.
        XmlBuilder.Append('<?xml version="1.0" encoding="utf-8" standalone="yes"?>');
        XmlBuilder.Append('<ReportParameters name="Contract Deferrals Release" id="8051">');
        XmlBuilder.Append('<Options><Field name="PostingDateReq">');
        XmlBuilder.Append(Helper.FormatDate(PostingDate));
        XmlBuilder.Append('</Field><Field name="PostUntilDateReq">');
        XmlBuilder.Append(Helper.FormatDate(PostUntilDate));
        XmlBuilder.Append('</Field></Options></ReportParameters>');
        RequestPageXml := XmlBuilder.ToText();

        Report.Execute(Report::"Contract Deferrals Release", RequestPageXml);

        CustomerAfterCount := CountUnreleasedCustomerDeferrals(0D);
        VendorAfterCount := CountUnreleasedVendorDeferrals(0D);

        CustomerReleased := CustomerBeforeCount - CustomerAfterCount;
        VendorReleased := VendorBeforeCount - VendorAfterCount;
        InWindowReleased :=
            (CustomerBeforeInWindow - CountUnreleasedCustomerDeferrals(PostUntilDate)) +
            (VendorBeforeInWindow - CountUnreleasedVendorDeferrals(PostUntilDate));
        OutsideWindowReleased := CustomerReleased + VendorReleased - InWindowReleased;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('postingDate', Helper.FormatDate(PostingDate));
        ResponseJson.Add('postUntilDate', Helper.FormatDate(PostUntilDate));
        ResponseJson.Add('customerDeferralsReleased', CustomerReleased);
        ResponseJson.Add('vendorDeferralsReleased', VendorReleased);
        ResponseJson.Add('totalDeferralsReleased', CustomerReleased + VendorReleased);
        if OutsideWindowReleased > 0 then begin
            ResponseJson.Add('releasedOutsideRequestedWindow', OutsideWindowReleased);
            ResponseJson.Add('warning', StrSubstNo(OvershotWindowMsg, OutsideWindowReleased, Helper.FormatDate(PostUntilDate)));
        end;
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>Counts unreleased customer deferrals - all of them, or only those posted up to UntilDate.</summary>
    local procedure CountUnreleasedCustomerDeferrals(UntilDate: Date): Integer
    var
        CustSubContractDeferral: Record "Cust. Sub. Contract Deferral";
    begin
        CustSubContractDeferral.SetRange(Released, false);
        if UntilDate <> 0D then
            CustSubContractDeferral.SetFilter("Posting Date", '<=%1', UntilDate);
        exit(CustSubContractDeferral.Count());
    end;

    /// <summary>Counts unreleased vendor deferrals - all of them, or only those posted up to UntilDate.</summary>
    local procedure CountUnreleasedVendorDeferrals(UntilDate: Date): Integer
    var
        VendSubContractDeferral: Record "Vend. Sub. Contract Deferral";
    begin
        VendSubContractDeferral.SetRange(Released, false);
        if UntilDate <> 0D then
            VendSubContractDeferral.SetFilter("Posting Date", '<=%1', UntilDate);
        exit(VendSubContractDeferral.Count());
    end;
}
