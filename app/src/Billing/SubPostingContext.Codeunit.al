namespace Origo.Bifrost.SubscriptionBilling;

using Microsoft.Sales.Document;
using Microsoft.Sales.Posting;

/// <summary>Captures the actual document entered by a scoped billing posting run without changing posting behavior.</summary>
codeunit 10035063 "Sub Posting Context ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        DocumentNo: Code[20];

    /// <summary>Returns the last sales document passed to Business Central posting in this bound run.</summary>
    procedure GetDocumentNo(): Code[20]
    begin
        exit(DocumentNo);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnBeforePostSalesDoc, '', false, false)]
    local procedure CapturePostingDocument(var SalesHeader: Record "Sales Header")
    begin
        DocumentNo := SalesHeader."No.";
    end;
}
