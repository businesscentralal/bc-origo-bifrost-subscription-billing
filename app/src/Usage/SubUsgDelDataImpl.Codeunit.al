namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;

/// <summary>
/// Implements the <c>Subscription.Usage.DeleteData</c> Bifrost message type (#41 AC03).
/// Undoes a usage import so it can be re-run or dropped. Mode resetLines does what the Delete Usage
/// Data Lines and Billing action does: the imported lines and the Usage Data Billing rows of the import
/// are deleted and its processing status and step are reset, while the stored file stays, so
/// Subscription.Usage.Process with CreateImportedLines runs it again. Mode deleteImport deletes the
/// Usage Data Import itself with Delete(true), which removes the same data and the file.
/// "Usage Data Import".DeleteUsageDataBillingLines is internal, so its steps are rebuilt here from
/// Microsoft's source (see docs/microsoft-dependencies.md). An import whose usage billing is on a
/// billing line or a document is refused.
/// 
/// Portions copyright (c) Microsoft Corporation, licensed under the MIT License (BCApps releases/28.x
/// a674a13, src/Apps/W1/Subscription Billing/App/Usage Based Billing/Tables/UsageDataImport.Table.al).
/// </summary>
codeunit 10035069 "Sub Usg DelData Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractParts: Codeunit "Sub Contract Parts ori";
        Helper: Codeunit "Sub Helper ori";
        InvalidSubjectErr: Label 'The subject ''%1'' is not a Usage Data Import entry number. Send the entry number as a whole number.', Comment = '%1 = the subject||is-IS=Efnið ''%1'' er ekki færslunúmer innflutnings notkunargagna. Sendu færslunúmerið sem heila tölu.';
        NotFoundErr: Label 'The Usage Data Import entry %1 does not exist.', Comment = '%1 = entry number||is-IS=Færsla %1 í innflutningi notkunargagna er ekki til.';
        InvalidModeErr: Label 'The parameter ''mode'' must be either ''resetLines'' or ''deleteImport'', not ''%1''.', Comment = '%1 = the supplied mode||is-IS=Færibreytan ''mode'' verður að vera annaðhvort ''resetLines'' eða ''deleteImport'', ekki ''%1''.';
        InvoicedErr: Label 'Usage Data Import entry %1 has usage billing on document %2. Delete or cancel that document first; usage that is posted cannot be imported again.', Comment = '%1 = entry number, %2 = document number||is-IS=Færsla %1 í innflutningi notkunargagna hefur reikningsgerð fyrir notkunargögn á skjali %2. Eyddu eða hættu við það skjal fyrst; ekki er hægt að flytja bókaða notkun inn aftur.';
        InBillingErr: Label 'Usage Data Import entry %1 has usage billing on billing line %2. Clear that billing proposal first with Subscription.Billing.ClearProposal.', Comment = '%1 = entry number, %2 = billing line entry number||is-IS=Færsla %1 í innflutningi notkunargagna hefur reikningsgerð fyrir notkunargögn á reikningslínu %2. Hreinsaðu þá reikningstillögu fyrst með Subscription.Billing.ClearProposal.';
        ResetLinesTok: Label 'resetlines', Locked = true;
        DeleteImportTok: Label 'deleteimport', Locked = true;
        DescriptionLbl: Label 'Deletes the imported lines and usage billing of a usage import so it can be processed again, or deletes the whole import. Refuses imports already on a billing line or document.', MaxLength = 250, Comment = 'is-IS=Eyðir innfluttum línum og reikningsgerð fyrir innflutt notkunargögn svo hægt sé að vinna hann aftur, eða eyðir öllum innflutningnum. Hafnar innflutningi sem er þegar á reikningslínu eða skjali.';

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Usage Data Import");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete usage data, reset usage import, undo usage import, delete imported usage lines, reprocess usage data, re-run usage import, delete usage data import, clear imported usage', Comment = 'is-IS=eyða notkunargögnum, núllstilla innflutning notkunar, afturkalla innflutning notkunar, eyða innfluttum notkunarlínum, vinna notkunargögn aftur, keyra innflutning notkunar aftur, eyða innflutningi notkunargagna, hreinsa innflutta notkun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Delete usage data: deletes the imported lines and usage billing of one Usage Data Import so it can be processed again (resetLines), or deletes the whole import (deleteImport). Irreversible, and imports already on a billing line or document are refused. To process the import again use Subscription.Usage.Process.', Comment = 'is-IS=Eyða notkunargögnum: eyðir innfluttum línum og reikningsgerð fyrir gögn eins notkunarinnflutnings svo hægt sé að vinna hann aftur (resetLines), eða eyðir öllum innflutningnum (deleteImport). Óafturkræf aðgerð og innflutningi sem er þegar á reikningslínu eða skjali er hafnað. Til að vinna innflutninginn aftur skal nota Subscription.Usage.Process.';
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
        Parameters := ContractParts.DeleteUsageDataParameters();
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
        Examples.Add(ContractMgt.Example('Reset an import to re-run it',
            '{"type":"Subscription.Usage.DeleteData","subject":"42","data":{"mode":"resetLines"}}',
            '{"status":"Success","usageDataImportEntryNo":42,"mode":"resetLines","usageDataBillingDeleted":12,"importDeleted":false,"processingStatus":"None"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Undoes a usage import. mode resetLines (the default) deletes its imported lines and its Usage Data Billing rows and resets its processing status and ' +
            'step, keeping the stored file: run Subscription.Usage.Process with the steps CreateImportedLines, ProcessImportedLines, CreateUsageDataBilling and ' +
            'ProcessUsageDataBilling to process it again. mode deleteImport deletes the Usage Data Import with its file as well.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := ('This is Microsoft''s Delete Usage Data Lines and Billing action and the delete of the import, rebuilt because Microsoft''s action cannot be called from outside Business Central. The ' +
            'call is refused while a Usage Data Billing row of the import is on a billing line (clear the proposal with Subscription.Billing.ClearProposal) or on a ' +
            'document, posted or not. Deleting a Usage Data Billing row reverts the Next Billing Date Microsoft moved for a rebilling. ' +
            ContractParts.IsolationNote()).TrimEnd();
        exit(true);
    end;

    local procedure ContractType(): Text
    begin
        exit('Subscription.Usage.DeleteData');
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

        if not Codeunit.Run(Codeunit::"Sub Usg DelData Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes the data of the usage import. Called directly, or through the isolated write process.</summary>
    procedure PerformWrite(var Argument: Record "Message Argument ori")
    var
        UsageDataImport: Record "Usage Data Import";
        UsageDataBilling: Record "Usage Data Billing";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Mode: Text;
        EntryNo: Integer;
        BillingRowsBefore: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        EntryNo := 0;
        if Argument.Subject <> '' then
            if not Evaluate(EntryNo, Argument.Subject, 9) then
                Error(InvalidSubjectErr, Argument.Subject);
        if EntryNo = 0 then
            EntryNo := Helper.GetInteger(RequestJson, 'usageDataImportEntryNo', true);
        Mode := LowerCase(Helper.GetText(RequestJson, 'mode', false));
        if Mode = '' then
            Mode := ResetLinesTok;
        if not (Mode in [ResetLinesTok, DeleteImportTok]) then
            Error(InvalidModeErr, Helper.GetText(RequestJson, 'mode', false));

        if not UsageDataImport.Get(EntryNo) then
            Error(NotFoundErr, EntryNo);
        CheckNotBilled(EntryNo);

        UsageDataBilling.SetRange("Usage Data Import Entry No.", EntryNo);
        BillingRowsBefore := UsageDataBilling.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('usageDataImportEntryNo', EntryNo);
        if Mode = DeleteImportTok then begin
            UsageDataImport.Delete(true);
            ResponseJson.Add('mode', 'deleteImport');
            ResponseJson.Add('usageDataBillingDeleted', BillingRowsBefore - UsageDataBilling.Count());
            ResponseJson.Add('importDeleted', true);
        end else begin
            DeleteUsageDataBillingLines(UsageDataImport);
            ResponseJson.Add('mode', 'resetLines');
            ResponseJson.Add('usageDataBillingDeleted', BillingRowsBefore - UsageDataBilling.Count());
            ResponseJson.Add('importDeleted', false);
            ResponseJson.Add('processingStatus', Helper.FormatProcessingStatus(UsageDataImport."Processing Status"));
        end;
        Helper.RespondWithSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Microsoft refuses a Usage Data Billing row with a document (CheckAndDeleteUsageDataBilling). A row on a billing line is
    /// refused here as well, so a proposal line is never left pointing at usage that no longer exists.
    /// </summary>
    local procedure CheckNotBilled(EntryNo: Integer)
    var
        UsageDataBilling: Record "Usage Data Billing";
    begin
        UsageDataBilling.SetRange("Usage Data Import Entry No.", EntryNo);
        UsageDataBilling.SetFilter("Document No.", '<>%1', '');
        UsageDataBilling.SetLoadFields("Usage Data Import Entry No.", "Document No.");
        if UsageDataBilling.FindFirst() then
            Error(InvoicedErr, EntryNo, UsageDataBilling."Document No.");
        UsageDataBilling.SetRange("Document No.");
        UsageDataBilling.SetFilter("Billing Line Entry No.", '<>0');
        UsageDataBilling.SetLoadFields("Usage Data Import Entry No.", "Billing Line Entry No.");
        if UsageDataBilling.FindFirst() then
            Error(InBillingErr, EntryNo, UsageDataBilling."Billing Line Entry No.");
    end;

    /// <summary>
    /// Microsoft: internal "Usage Data Import".DeleteUsageDataBillingLines, without its local OnDeleteUsageDataBillingLines event:
    /// deletes the supplier type's imported data and the Usage Data Billing rows, and resets status, step and reason.
    /// </summary>
    local procedure DeleteUsageDataBillingLines(var UsageDataImport: Record "Usage Data Import")
    var
        UsageDataSupplier: Record "Usage Data Supplier";
        UsageDataBilling: Record "Usage Data Billing";
        UsageDataProcessing: Interface "Usage Data Processing";
    begin
        if UsageDataSupplier.Get(UsageDataImport."Supplier No.") then begin
            UsageDataProcessing := UsageDataSupplier.Type;
            UsageDataProcessing.DeleteImportedData(UsageDataImport);
        end;
        UsageDataBilling.SetRange("Usage Data Import Entry No.", UsageDataImport."Entry No.");
        if not UsageDataBilling.IsEmpty() then
            UsageDataBilling.DeleteAll(true);

        UsageDataImport."Processing Status" := UsageDataImport."Processing Status"::None;
        UsageDataImport."Processing Step" := UsageDataImport."Processing Step"::None;
        Clear(UsageDataImport."Reason (Preview)");
        Clear(UsageDataImport.Reason);
        UsageDataImport.Modify(false);
    end;
}
