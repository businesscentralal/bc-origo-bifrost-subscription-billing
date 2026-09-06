namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Analysis.Recalculate</c> Bifrost message type.
/// Rebuilds Subscription Contract analysis entries by running Microsoft's "Create Contract
/// Analysis" report. The report has no request page and no parameters of its own - it always
/// analyses as of the system date and walks every Subscription Line with a contract - so a plain
/// Data.Records.Set cannot do this: the analysis snapshot has to be produced by the report.
/// </summary>
codeunit 10035056 "Sub Ana Recalc Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Helper: Codeunit "Sub Helper ori";
        DescriptionLbl: Label 'Rebuilds Subscription Contract analysis entries as of today by running Microsoft''s Create Contract Analysis report across every Subscription Line with a contract.', MaxLength = 250, Comment = 'is-IS=Endurbyggir greiningarfærslur áskriftarsamnings miðað við daginn í dag með því að keyra skýrslu Microsoft, Create Contract Analysis, á allar áskriftarlínur með samningi.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Sub. Contr. Analysis Entry");
    end;

    internal procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AnaHelp: Codeunit "Sub Ana Help ori";
    begin
        Argument.SetResponseMarkdown(AnaHelp.GetHelpMarkdown('Subscription.Analysis.Recalculate'));
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

    /// <summary>Runs the contract analysis report and reports how many entries it added. Called directly, or through the isolated write process.</summary>
    internal procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        SubContrAnalysisEntry: Record "Sub. Contr. Analysis Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ContractNo: Code[20];
        MaxEntryNoBefore: Integer;
        EntriesCreated: Integer;
        TotalEntries: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ContractNo := Helper.GetCode20(RequestJson, 'contractNo', false);

        SubContrAnalysisEntry.Reset();
        if SubContrAnalysisEntry.FindLast() then
            MaxEntryNoBefore := SubContrAnalysisEntry."Entry No."
        else
            MaxEntryNoBefore := 0;

        Report.Run(Report::"Create Contract Analysis", false, false);

        SubContrAnalysisEntry.Reset();
        SubContrAnalysisEntry.SetFilter("Entry No.", '>%1', MaxEntryNoBefore);
        if ContractNo <> '' then
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
        EntriesCreated := SubContrAnalysisEntry.Count();

        SubContrAnalysisEntry.Reset();
        if ContractNo <> '' then
            SubContrAnalysisEntry.SetRange("Subscription Contract No.", ContractNo);
        TotalEntries := SubContrAnalysisEntry.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('analysisDate', Helper.FormatDate(Today()));
        ResponseJson.Add('entriesCreated', EntriesCreated);
        ResponseJson.Add('totalEntries', TotalEntries);
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;
}
