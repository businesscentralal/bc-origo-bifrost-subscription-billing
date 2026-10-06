namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.SubscriptionBilling;
using Origo.Bifrost;
using Origo.Bifrost.SubscriptionBilling;
using System.TestLibraries.Utilities;

codeunit 95705 "Sub Imp CrContr Tst ori"
{
    Subtype = Test;

    [Test]
    procedure CommentLineTypeFailsSubscriptionLinesStage()
    var
        ImportedSubscriptionLine: Record "Imported Subscription Line";
        Argument: Record "Message Argument ori";
        Impl: Codeunit "Sub Imp CrContr Impl ori";
        ResponseJson: JsonObject;
        Stages: JsonArray;
        Errors: JsonArray;
        StageToken: JsonToken;
        ErrorToken: JsonToken;
        StageJson: JsonObject;
        ErrorJson: JsonObject;
        RequestJson: JsonObject;
        RequestedStages: JsonArray;
    begin
        ImportedSubscriptionLine.Init();
        ImportedSubscriptionLine."Sub. Contract Line Type" := ImportedSubscriptionLine."Sub. Contract Line Type"::Comment;
        ImportedSubscriptionLine."Subscription Line created" := false;
        ImportedSubscriptionLine.Insert(true);

        RequestedStages.Add('SubscriptionLines');
        RequestJson.Add('stages', RequestedStages);
        Argument.SetRequestJson(RequestJson);
        Impl.PerformWrite(Argument);

        ResponseJson := Argument.GetResponseJson();
        ResponseJson.Get('stages', StageToken);
        Stages := StageToken.AsArray();
        Stages.Get(0, StageToken);
        StageJson := StageToken.AsObject();
        Assert.AreEqual(1, ReadInteger(StageJson, 'failed'), 'A Comment line type must fail the stage.');
        Assert.AreEqual(0, ReadInteger(StageJson, 'succeeded'), 'A Comment line type must not be counted as succeeded.');

        ResponseJson.Get('errors', ErrorToken);
        Errors := ErrorToken.AsArray();
        Errors.Get(0, ErrorToken);
        ErrorJson := ErrorToken.AsObject();
        Assert.AreEqual('Sub_ContractLineType is required: Subscription Line / Comment', ReadText(ErrorJson, 'error'), 'The required line type error must be returned.');

        ImportedSubscriptionLine.Get(ImportedSubscriptionLine."Entry No.");
        Assert.IsFalse(ImportedSubscriptionLine."Subscription Line created", 'A failed row must stay uncreated.');
        Assert.AreEqual('Sub_ContractLineType is required: Subscription Line / Comment', ImportedSubscriptionLine."Error Text", 'Error Text must be stored on the staging row.');
    end;

    local procedure ReadInteger(Json: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Json.Get(Name, Token);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadText(Json: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Json.Get(Name, Token);
        exit(Token.AsValue().AsText());
    end;

    var
        Assert: Codeunit Assert;
}
