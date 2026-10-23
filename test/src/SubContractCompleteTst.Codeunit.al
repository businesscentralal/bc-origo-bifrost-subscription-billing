namespace Origo.Bifrost.SubscriptionBilling.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Completeness tests over the contract and the discovery texts of every Subscription Billing message type,
/// the same bar Bifrost Foundation holds its own types to. A new type, or a type that loses a chapter, fails
/// here: every type declares the chapters a caller needs, every error entry carries a code or an error text with
/// a condition and a next step, the effect agrees with the message direction, the examples are real request and
/// response pairs, and the description, keywords and selection description are complete and translated.
/// </summary>
codeunit 95780 "Sub Contract Complete Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AllTypes_DeclareTheChaptersACallerNeeds()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Envelope: JsonObject;
        Subject: JsonObject;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        ChapterKey: Text;
        Index: Integer;
    begin
        // [SCENARIO] Every type declares envelope, parameters, response, errors, effect, metering, related, examples,
        //            overview and notes, and a target whenever the subject is used to identify a record.
        CollectTypes(TypeNames, TypeOrdinals);
        Assert.IsTrue(TypeNames.Count() > 0, 'No Subscription Billing message type was found.');

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));

            // [WHEN] The contract is read, which is what Help.Implementation.Get returns
            if not ContractMgt.GetContract(MessageType, Contract) then
                Problems.AppendLine(TypeNames.Get(Index) + ': declares no contract.')
            else begin
                // [THEN] Every required chapter is there
                foreach ChapterKey in RequiredChapters() do
                    if not Contract.Contains(ChapterKey) then
                        Problems.AppendLine(TypeNames.Get(Index) + ': chapter ' + ChapterKey + ' is missing.');

                // [THEN] The overview and notes are text that says something
                if StrLen(ReadChapterText(Contract, 'overview')) < 40 then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the overview is missing or too short to say what the type does and when to use it.');
                if StrLen(ReadChapterText(Contract, 'notes')) < 20 then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the notes are missing.');

                // [THEN] A type that reads the subject says how the record is identified
                if ReadChapterObject(Contract, 'envelope', Envelope) then
                    if Envelope.Contains('subject') then
                        if ReadObjectProperty(Envelope, 'subject', Subject) then
                            if ReadText(Subject, 'use') <> 'notUsed' then
                                if not Contract.Contains('target') then
                                    Problems.AppendLine(TypeNames.Get(Index) + ': the subject is used but no target chapter says how the record is identified.');
            end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_ErrorEntriesCarryACodeOrTextWithAConditionAndANextStep()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Errors: JsonArray;
        Entry: JsonObject;
        EntryToken: JsonToken;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        Index: Integer;
    begin
        // [SCENARIO] Every errors entry names a machine code (a Bifrost Error Code name, checked by GetContract) or the
        //            error text of an answer that has none, says when it happens and what the caller does next.
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            ContractMgt.GetContract(MessageType, Contract);

            if not ReadChapterArray(Contract, 'errors', Errors) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the errors chapter is missing.')
            else begin
                if Errors.Count() = 0 then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the errors chapter is empty.');
                foreach EntryToken in Errors do begin
                    Entry := EntryToken.AsObject();
                    if (ReadText(Entry, 'code') = '') and (ReadText(Entry, 'error') = '') then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an errors entry has neither a code nor an error text.');
                    if ReadText(Entry, 'code') = 'None' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an errors entry names the code None.');
                    if ReadText(Entry, 'when') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an errors entry has no condition (when).');
                    if ReadText(Entry, 'fix') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an errors entry has no next step (fix).');
                end;
            end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_EffectAgreesWithTheMessageDirection()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        MessageTypeInterface: Interface "Msg Interface ori";
        Direction: Enum "Msg Direction ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Preconditions: JsonArray;
        PreconditionsToken: JsonToken;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        EffectName: Text;
        Index: Integer;
    begin
        // [SCENARIO] The effect chapter states the effect, what changes, whether the call is idempotent, the permission
        //            set and the preconditions. A read type is Outbound or a preview, a write type is never Outbound,
        //            and a type named Preview is the only kind that reads.
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            MessageTypeInterface := MessageType;
            Direction := MessageTypeInterface.GetMessageDirection();
            ContractMgt.GetContract(MessageType, Contract);

            if not ReadChapterObject(Contract, 'effect', Effect) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the effect chapter is missing.')
            else begin
                EffectName := ReadText(Effect, 'effect');
                if not (EffectName in ['read', 'write', 'irreversible']) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the effect is ''' + EffectName + ''', not read, write or irreversible.');
                if ReadText(Effect, 'changes') = '' then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the effect does not say what changes.');
                if ReadText(Effect, 'permissionSet') = '' then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the effect names no permission set.');
                if not Effect.Contains('idempotent') then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the effect does not say whether the call is idempotent.');
                if not Effect.Get('preconditions', PreconditionsToken) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the effect lists no preconditions.')
                else begin
                    Preconditions := PreconditionsToken.AsArray();
                    if Preconditions.Count() = 0 then
                        Problems.AppendLine(TypeNames.Get(Index) + ': the effect lists no preconditions.');
                end;

                // Direction and effect: Outbound only reads; a write or irreversible type is Inbound or Both.
                if (Direction = Direction::Outbound) and (EffectName <> 'read') then
                    Problems.AppendLine(TypeNames.Get(Index) + ': it is Outbound but its effect is ' + EffectName + '.');
                if (Direction <> Direction::Outbound) and (EffectName = 'read') and not TypeNames.Get(Index).Contains('.Preview') then
                    Problems.AppendLine(TypeNames.Get(Index) + ': its effect is read but it is neither Outbound nor a preview.');
                if TypeNames.Get(Index).Contains('.Preview') and (EffectName <> 'read') then
                    Problems.AppendLine(TypeNames.Get(Index) + ': it is a preview but its effect is ' + EffectName + '.');
            end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_ParametersAndResponseAreWellFormed()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Parameters: JsonArray;
        Response: JsonObject;
        Fields: JsonArray;
        FieldsToken: JsonToken;
        Entry: JsonObject;
        EntryToken: JsonToken;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        FieldNames: List of [Text];
        Problems: TextBuilder;
        Index: Integer;
    begin
        // [SCENARIO] Every parameter has a name, a JSON type, a required flag and a description, and the response
        //            declares its fields, among them status.
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            ContractMgt.GetContract(MessageType, Contract);

            if ReadChapterArray(Contract, 'parameters', Parameters) then
                foreach EntryToken in Parameters do begin
                    Entry := EntryToken.AsObject();
                    if ReadText(Entry, 'name') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': a parameter has no name.');
                    if not (ReadText(Entry, 'type') in ['string', 'integer', 'number', 'boolean', 'array', 'object']) then
                        Problems.AppendLine(TypeNames.Get(Index) + ': parameter ' + ReadText(Entry, 'name') + ' has no valid JSON type.');
                    if not Entry.Contains('required') then
                        Problems.AppendLine(TypeNames.Get(Index) + ': parameter ' + ReadText(Entry, 'name') + ' does not say whether it is required.');
                    if ReadText(Entry, 'description') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': parameter ' + ReadText(Entry, 'name') + ' has no description.');
                end;

            Clear(FieldNames);
            if not ReadChapterObject(Contract, 'response', Response) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the response chapter is missing.')
            else
                if not Response.Get('fields', FieldsToken) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the response declares no fields.')
                else begin
                    Fields := FieldsToken.AsArray();
                    foreach EntryToken in Fields do begin
                        Entry := EntryToken.AsObject();
                        FieldNames.Add(ReadText(Entry, 'name'));
                        if ReadText(Entry, 'type') = '' then
                            Problems.AppendLine(TypeNames.Get(Index) + ': response field ' + ReadText(Entry, 'name') + ' has no type.');
                        if ReadText(Entry, 'description') = '' then
                            Problems.AppendLine(TypeNames.Get(Index) + ': response field ' + ReadText(Entry, 'name') + ' has no description.');
                    end;
                    if not FieldNames.Contains('status') then
                        Problems.AppendLine(TypeNames.Get(Index) + ': the response does not declare status.');
                end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_ExamplesAreRealRequestAndResponsePairs()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Examples: JsonArray;
        Entry: JsonObject;
        EntryToken: JsonToken;
        RequestObject: JsonObject;
        ResponseObject: JsonObject;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        Index: Integer;
    begin
        // [SCENARIO] Every type has at least one example with a title, a request object that names the type and a
        //            response object that carries status.
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            ContractMgt.GetContract(MessageType, Contract);

            if not ReadChapterArray(Contract, 'examples', Examples) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the examples chapter is missing.')
            else begin
                if Examples.Count() = 0 then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the examples chapter is empty.');
                foreach EntryToken in Examples do begin
                    Entry := EntryToken.AsObject();
                    if ReadText(Entry, 'title') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an example has no title.');
                    if not ReadObjectProperty(Entry, 'request', RequestObject) then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an example request is not a JSON object.')
                    else
                        if ReadText(RequestObject, 'type') <> TypeNames.Get(Index) then
                            Problems.AppendLine(TypeNames.Get(Index) + ': an example request names the type ''' + ReadText(RequestObject, 'type') + '''.');
                    if not ReadObjectProperty(Entry, 'response', ResponseObject) then
                        Problems.AppendLine(TypeNames.Get(Index) + ': an example response is not a JSON object.')
                    else
                        if ReadText(ResponseObject, 'status') = '' then
                            Problems.AppendLine(TypeNames.Get(Index) + ': an example response carries no status.');
                end;
            end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_WorkflowAndRelatedNameRealTypes()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Related: JsonArray;
        Workflow: JsonObject;
        Steps: JsonArray;
        StepsToken: JsonToken;
        Entry: JsonObject;
        EntryToken: JsonToken;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        Index: Integer;
    begin
        // [SCENARIO] Every type names at least one related type with the reason to use it, and a workflow, when a type
        //            declares one, lists steps that each carry a purpose. GetContract itself refuses a name that is no
        //            message type.
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            ContractMgt.GetContract(MessageType, Contract);

            if not ReadChapterArray(Contract, 'related', Related) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the related chapter is missing.')
            else begin
                if Related.Count() = 0 then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the related chapter is empty.');
                foreach EntryToken in Related do begin
                    Entry := EntryToken.AsObject();
                    if ReadText(Entry, 'name') = TypeNames.Get(Index) then
                        Problems.AppendLine(TypeNames.Get(Index) + ': it lists itself as related.');
                    if ReadText(Entry, 'useInsteadWhen') = '' then
                        Problems.AppendLine(TypeNames.Get(Index) + ': a related entry does not say when to use it.');
                end;
            end;

            if ReadChapterObject(Contract, 'workflow', Workflow) then
                if not Workflow.Get('steps', StepsToken) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the workflow lists no steps.')
                else begin
                    Steps := StepsToken.AsArray();
                    if Steps.Count() = 0 then
                        Problems.AppendLine(TypeNames.Get(Index) + ': the workflow lists no steps.');
                    foreach EntryToken in Steps do begin
                        Entry := EntryToken.AsObject();
                        if ReadText(Entry, 'purpose') = '' then
                            Problems.AppendLine(TypeNames.Get(Index) + ': a workflow step has no purpose.');
                    end;
                end;
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_ContractTextNamesNoAlObjectOrInternalProcedure()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Problems: TextBuilder;
        ContractText: Text;
        Forbidden: Text;
        Index: Integer;
    begin
        // [SCENARIO] The help text is public. It names no codeunit, no AL procedure, no AL statement and no number of an
        //            object of this app (they all start with 10035).
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            ContractMgt.GetContract(MessageType, Contract);
            Contract.WriteTo(ContractText);
            foreach Forbidden in ForbiddenTexts() do
                if ContractText.Contains(Forbidden) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the contract text contains ''' + Forbidden + '''.');
        end;

        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_DiscoveryTextsAreCompleteAndSeparateTheTypeFromItsSiblings()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        DiscoveryInterface: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Keywords: List of [Text];
        Segments: List of [Text];
        Problems: TextBuilder;
        DescriptionText: Text;
        SelectionText: Text;
        Keyword: Text;
        SiblingName: Text;
        Segment: Text;
        NamesSibling: Boolean;
        SavedLanguage: Integer;
        Index: Integer;
    begin
        // [SCENARIO] The description is a sentence that starts with a verb, is 20 to 200 characters and names no
        //            codeunit. The keywords are at least six distinct phrases people say and are not derived from the
        //            type name. The selection description is its own text and names a sibling type to use instead.
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        CollectTypes(TypeNames, TypeOrdinals);

        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            MessageTypeInterface := MessageType;
            DiscoveryInterface := MessageType;
            DescriptionText := MessageTypeInterface.GetDescription();
            SelectionText := DiscoveryInterface.GetSelectionDescription();

            if (StrLen(DescriptionText) < 20) or (StrLen(DescriptionText) > 200) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the description must be 20 to 200 characters, it is ' + Format(StrLen(DescriptionText)) + '.');
            if not StartsWithVerb(DescriptionText) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the description must start with a verb such as Creates.');
            if LowerCase(DescriptionText).Contains('codeunit') then
                Problems.AppendLine(TypeNames.Get(Index) + ': the description names a codeunit.');

            Clear(Keywords);
            foreach Keyword in DiscoveryInterface.GetKeywords().Split(',') do
                if (Keyword.Trim() <> '') and not Keywords.Contains(LowerCase(Keyword.Trim())) then
                    Keywords.Add(LowerCase(Keyword.Trim()));
            if Keywords.Count() < 6 then
                Problems.AppendLine(TypeNames.Get(Index) + ': it has ' + Format(Keywords.Count()) + ' distinct keywords, at least 6 are needed.');
            if Keywords.Contains(LowerCase(TypeNames.Get(Index))) then
                Problems.AppendLine(TypeNames.Get(Index) + ': a keyword is the type name; keywords are phrases people say.');
            Segments := LowerCase(TypeNames.Get(Index)).Split('.');
            foreach Segment in Segments do
                if Keywords.Contains(Segment) then
                    Problems.AppendLine(TypeNames.Get(Index) + ': the keyword ''' + Segment + ''' is a part of the type name.');

            if StrLen(SelectionText) < 60 then
                Problems.AppendLine(TypeNames.Get(Index) + ': the selection description is missing or too short.');
            if SelectionText = DescriptionText then
                Problems.AppendLine(TypeNames.Get(Index) + ': the selection description repeats the description.');
            NamesSibling := false;
            foreach SiblingName in TypeNames do
                if (SiblingName <> TypeNames.Get(Index)) and SelectionText.Contains(SiblingName) then
                    NamesSibling := true;
            if not NamesSibling then
                Problems.AppendLine(TypeNames.Get(Index) + ': the selection description names no sibling type to use instead.');
        end;

        GlobalLanguage(SavedLanguage);
        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure AllTypes_DiscoveryTextsHaveAnIcelandicTranslation()
    var
        MessageTypeInterface: Interface "Msg Interface ori";
        DiscoveryInterface: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        EnglishDescription: List of [Text];
        EnglishKeywords: List of [Text];
        EnglishSelection: List of [Text];
        Problems: TextBuilder;
        IcelandicKeywords: Text;
        SavedLanguage: Integer;
        Index: Integer;
    begin
        // [SCENARIO] The description, the keywords and the selection description of every type are translated: the
        //            Icelandic text differs from the English one, and the keyword list is at least as long.
        SavedLanguage := GlobalLanguage();
        CollectTypes(TypeNames, TypeOrdinals);

        GlobalLanguage(1033);
        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            MessageTypeInterface := MessageType;
            DiscoveryInterface := MessageType;
            EnglishDescription.Add(MessageTypeInterface.GetDescription());
            EnglishKeywords.Add(DiscoveryInterface.GetKeywords());
            EnglishSelection.Add(DiscoveryInterface.GetSelectionDescription());
        end;

        GlobalLanguage(1039);
        for Index := 1 to TypeNames.Count() do begin
            MessageType := Enum::"Message Type ori".FromInteger(TypeOrdinals.Get(Index));
            MessageTypeInterface := MessageType;
            DiscoveryInterface := MessageType;
            if MessageTypeInterface.GetDescription() = EnglishDescription.Get(Index) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the description has no Icelandic translation.');
            IcelandicKeywords := DiscoveryInterface.GetKeywords();
            if IcelandicKeywords = EnglishKeywords.Get(Index) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the keywords have no Icelandic translation.');
            if IcelandicKeywords.Split(',').Count() < EnglishKeywords.Get(Index).Split(',').Count() then
                Problems.AppendLine(TypeNames.Get(Index) + ': the Icelandic keyword list is shorter than the English one.');
            if DiscoveryInterface.GetSelectionDescription() = EnglishSelection.Get(Index) then
                Problems.AppendLine(TypeNames.Get(Index) + ': the selection description has no Icelandic translation.');
        end;

        GlobalLanguage(SavedLanguage);
        Assert.AreEqual('', Problems.ToText(), Problems.ToText());
    end;

    [Test]
    procedure BillingWorkflow_StartsWithTheTemplateFilter_AndUsageWorkflowCoversTheReset()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Workflow: JsonObject;
        StepsToken: JsonToken;
        Steps: JsonArray;
        Entry: JsonObject;
        StepToken: JsonToken;
        StepNames: List of [Text];
    begin
        // [SCENARIO] The billing run, the vendor invoice and the usage workflows that gained a step in the contract
        //            completeness work declare it.
        // [GIVEN] The contract of Subscription.Billing.SetTemplateFilter
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Billing.SetTemplateFilter", Contract);

        // [THEN] It declares the billing run workflow, and the template filter is its first step
        Assert.IsTrue(ReadChapterObject(Contract, 'workflow', Workflow), 'Subscription.Billing.SetTemplateFilter must declare the billing run workflow.');
        Workflow.Get('steps', StepsToken);
        Steps := StepsToken.AsArray();
        Steps.Get(0, StepToken);
        Entry := StepToken.AsObject();
        Assert.AreEqual('Subscription.Billing.SetTemplateFilter', ReadText(Entry, 'messageType'), 'The template filter is the first step of the billing run.');

        // [WHEN] The usage workflow of Subscription.Usage.DeleteData is read
        Clear(Contract);
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.Usage.DeleteData", Contract);

        // [THEN] The reset is part of the usage workflow text, and the type declares the workflow
        Assert.IsTrue(ReadChapterObject(Contract, 'workflow', Workflow), 'Subscription.Usage.DeleteData must declare the usage workflow.');
        Assert.IsTrue(ReadText(Workflow, 'text').Contains('Subscription.Usage.DeleteData'), 'The usage workflow names the reset.');
        Workflow.Get('steps', StepsToken);
        foreach StepToken in StepsToken.AsArray() do
            StepNames.Add(ReadText(StepToken.AsObject(), 'messageType'));
        Assert.IsTrue(StepNames.Contains('Subscription.Usage.Process'), 'The usage workflow still processes the import.');

        // [WHEN] The vendor workflow of Subscription.VendorContract.AddLinesToInvoice is read
        Clear(Contract);
        ContractMgt.GetContract(Enum::"Message Type ori"::"Subscription.VendorContract.AddLinesToInvoice", Contract);

        // [THEN] It declares the vendor workflow
        Assert.IsTrue(ReadChapterObject(Contract, 'workflow', Workflow), 'Subscription.VendorContract.AddLinesToInvoice must declare the vendor workflow.');
    end;

    local procedure CollectTypes(var TypeNames: List of [Text]; var TypeOrdinals: List of [Integer])
    var
        Ordinal: Integer;
        Index: Integer;
    begin
        // The app id range 10035035-10035090; the enum extension itself is 10035035 and is not a message type.
        for Index := 1 to Enum::"Message Type ori".Ordinals().Count() do begin
            Ordinal := Enum::"Message Type ori".Ordinals().Get(Index);
            if (Ordinal >= 10035036) and (Ordinal <= 10035090) then begin
                TypeNames.Add(Enum::"Message Type ori".Names().Get(Index));
                TypeOrdinals.Add(Ordinal);
            end;
        end;
    end;

    local procedure RequiredChapters() Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('parameters');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        Chapters.Add('examples');
        Chapters.Add('overview');
        Chapters.Add('notes');
    end;

    local procedure ForbiddenTexts() Forbidden: List of [Text]
    begin
        Forbidden.Add('codeunit');
        Forbidden.Add('Codeunit');
        Forbidden.Add('Delete(true)');
        Forbidden.Add('Insert(true)');
        Forbidden.Add('Modify(true)');
        Forbidden.Add('RecordRef');
        Forbidden.Add('PerformWrite');
        Forbidden.Add('ExecuteBifrostTask');
        Forbidden.Add('Mgt.');
        Forbidden.Add('docs/');
        Forbidden.Add('10035');
    end;

    local procedure StartsWithVerb(Description: Text): Boolean
    var
        FirstWord: Text;
        FirstChar: Char;
    begin
        if Description = '' then
            exit(false);
        FirstWord := Description.Split(' ').Get(1);
        if FirstWord in ['This', 'Is', 'Has'] then
            exit(false);
        FirstChar := FirstWord[1];
        exit((FirstChar in ['A' .. 'Z']) and FirstWord.EndsWith('s'));
    end;

    local procedure ReadText(Entry: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Entry.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadChapterText(Contract: JsonObject; ChapterKey: Text): Text
    begin
        exit(ReadText(Contract, ChapterKey));
    end;

    local procedure ReadChapterArray(Contract: JsonObject; ChapterKey: Text; var Chapter: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not Contract.Get(ChapterKey, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Chapter := Token.AsArray();
        exit(true);
    end;

    local procedure ReadChapterObject(Contract: JsonObject; ChapterKey: Text; var Chapter: JsonObject): Boolean
    begin
        exit(ReadObjectProperty(Contract, ChapterKey, Chapter));
    end;

    local procedure ReadObjectProperty(Entry: JsonObject; PropertyName: Text; var Value: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Entry.Get(PropertyName, Token) then
            exit(false);
        if not Token.IsObject() then
            exit(false);
        Value := Token.AsObject();
        exit(true);
    end;
}
