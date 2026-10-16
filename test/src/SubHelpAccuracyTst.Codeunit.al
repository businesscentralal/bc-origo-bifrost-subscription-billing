namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Checks the help accuracy of #44 on the types this app runs today: every type that reads
/// Subscription Billing records it does not create states the write guard precondition, and no
/// contract claims end-to-end operation, indexation or a Business Central version. The four
/// blocked types and the PriceUpdate types are covered by the issues that rewrite them.
/// </summary>
codeunit 95772 "Sub Help Accuracy Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        WriteGuardTxt: Label 'write guard set to Open, or Change Log coverage', Locked = true;

    [Test]
    procedure Scenario_AC02_TypesReadingSetupRecords_StateWriteGuardPrecondition()
    var
        TypeName: Text;
    begin
        // Issue #44, AC02 | Time: none | Risk: Branch A/B add types; their own tests cover them
        // [WHEN] The effect chapter of every type that reads records prepared by generic writes is built
        // [THEN] Its preconditions name the write guard and Change Log coverage
        foreach TypeName in GuardedTypes() do
            Assert.IsTrue(PreconditionsText(TypeName).Contains(WriteGuardTxt), TypeName + ' must state the write guard precondition.');
    end;

    [Test]
    procedure Scenario_AC02_TypesWithoutSetupRecords_OmitWriteGuardPrecondition()
    begin
        // Issue #44, AC02 edge case | Time: none | Risk: None
        // [THEN] Types that need no prepared record do not claim the precondition
        Assert.IsFalse(PreconditionsText('Subscription.Usage.Process').Contains(WriteGuardTxt), 'Usage.Process reads only the import it is given.');
        Assert.IsFalse(PreconditionsText('Subscription.Deferral.Release').Contains(WriteGuardTxt), 'Deferral.Release needs no prepared record.');
        Assert.IsFalse(PreconditionsText('Subscription.Analysis.Recalculate').Contains(WriteGuardTxt), 'Analysis.Recalculate needs no prepared record.');
    end;

    [Test]
    procedure Scenario_AC02_SetupPrecondition_AgreesInNumber()
    var
        CustomerText: Text;
        SeveralText: Text;
    begin
        // Issue #44 story note 15.10 | Time: none | Risk: None
        // [THEN] One record is "it"; several records are "them"; each sentence has a subject
        CustomerText := PreconditionsText('Subscription.Contract.GetLines');
        Assert.IsTrue(CustomerText.Contains('The Customer Subscription Contract must already exist; this call does not create it.'), 'A customer contract precondition needs a singular subject.');
        Assert.IsFalse(CustomerText.Contains('does not create them.'), 'A single customer contract is not "them".');
        Assert.IsTrue(PreconditionsText('Subscription.VendorContract.GetLines').Contains('The Vendor Subscription Contract must already exist; this call does not create it.'), 'A vendor contract precondition needs a singular subject.');
        Assert.IsTrue(PreconditionsText('Subscription.Billing.CreateProposal').Contains('The Billing Template must already exist; this call does not create it.'), 'A billing template precondition needs a singular subject.');
        SeveralText := PreconditionsText('Subscription.Line.Create');
        Assert.IsTrue(SeveralText.Contains('The Subscription Header and the Subscription Package must already exist; this call does not create them.'), 'Line.Create prepares two records.');
        Assert.IsTrue(PreconditionsText('Subscription.Import.CreateContracts').Contains('must already exist; this call does not create them.'), 'Import staging rows are plural.');
    end;

    [Test]
    procedure Scenario_AC06_ImportProcessedCount_LeavesSkippedRowsOut()
    var
        ContractText: Text;
    begin
        // Issue #44 story note 15.10 | Time: none | Risk: None
        // The note names Usage.Process. That type has no processed field. The field, and the
        // example that already separates skipped, belong to Subscription.Import.CreateContracts.
        // [THEN] processed says skipped rows are left out of the count
        ContractText := GetContractText('Subscription.Import.CreateContracts');
        Assert.IsTrue(ContractText.Contains('Skipped rows are left out of this count.'), 'processed must say skipped rows are left out.');
        Assert.IsFalse(ContractText.Contains('Unprocessed staging rows the stage found.'), 'The old processed description must be gone.');
    end;

    [Test]
    procedure Scenario_AC01_Contracts_MakeNoEndToEndOrVersionClaims()
    var
        ContractText: Text;
        TypeName: Text;
    begin
        // Issue #44, AC01 and AC03 | Time: none | Risk: None
        // [WHEN] The full contract of every running type is serialised
        foreach TypeName in RunningTypes() do begin
            ContractText := GetContractText(TypeName).ToLower();
            // [THEN] It claims no end-to-end operation, no indexation and names no Business Central version
            Assert.IsFalse(ContractText.Contains('end to end'), TypeName + ' must not claim end-to-end operation.');
            Assert.IsFalse(ContractText.Contains('end-to-end'), TypeName + ' must not claim end-to-end operation.');
            Assert.IsFalse(ContractText.Contains('indexation'), TypeName + ' must not claim indexation.');
            Assert.IsFalse(ContractText.Contains('business central 28.'), TypeName + ' must not name a Business Central version.');
        end;
    end;

    local procedure GuardedTypes() Types: List of [Text]
    begin
        Types.Add('Subscription.Line.Create');
        Types.Add('Subscription.Contract.GetLines');
        Types.Add('Subscription.Contract.CreateInvoice');
        Types.Add('Subscription.Contract.PreviewInvoice');
        Types.Add('Subscription.VendorContract.GetLines');
        Types.Add('Subscription.VendorContract.CreateInvoice');
        Types.Add('Subscription.VendorContract.PreviewInvoice');
        Types.Add('Subscription.Billing.CreateProposal');
        Types.Add('Subscription.Billing.CreateDocuments');
        Types.Add('Subscription.Billing.PreviewDocuments');
        Types.Add('Subscription.Renewal.Extend');
        Types.Add('Subscription.Renewal.CreateQuote');
        Types.Add('Subscription.Usage.ImportData');
        Types.Add('Subscription.Import.CreateContracts');
    end;

    local procedure RunningTypes() Types: List of [Text]
    begin
        Types := GuardedTypes();
        Types.Add('Subscription.Usage.Process');
        Types.Add('Subscription.Deferral.Release');
        Types.Add('Subscription.Analysis.Recalculate');
    end;

    local procedure PreconditionsText(TypeName: Text) Result: Text
    var
        Contract: JsonObject;
        Token: JsonToken;
        Precondition: JsonToken;
    begin
        Contract := GetContract(TypeName);
        Contract.Get('effect', Token);
        Token.AsObject().Get('preconditions', Token);
        foreach Precondition in Token.AsArray() do
            Result += Precondition.AsValue().AsText() + ' ';
    end;

    local procedure GetContractText(TypeName: Text) Result: Text
    begin
        GetContract(TypeName).WriteTo(Result);
    end;

    local procedure GetContract(TypeName: Text) Contract: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(TypeName)));
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
    end;
}
