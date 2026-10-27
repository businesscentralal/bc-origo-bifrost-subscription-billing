namespace Origo.Bifrost.SubscriptionBilling.Test;

using Microsoft.Sales.Document;
using Microsoft.Sales.Posting;

/// <summary>Scopes an invalid posting date to one owned customer so the real posting validation can be tested.</summary>
codeunit 95724 "Sub Posting Failure Test ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CustomerNo: Code[20];
        DocumentNo: Code[20];

    /// <summary>Restricts the fault to the test's freshly created customer.</summary>
    procedure SetCustomer(OwnedCustomerNo: Code[20])
    begin
        CustomerNo := OwnedCustomerNo;
    end;

    /// <summary>Returns the actual document that entered posting.</summary>
    procedure GetDocumentNo(): Code[20]
    begin
        exit(DocumentNo);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnBeforePostSalesDoc, '', false, false)]
    local procedure InvalidateOwnedPosting(var SalesHeader: Record "Sales Header")
    begin
        if SalesHeader."Sell-to Customer No." <> CustomerNo then
            exit;
        DocumentNo := SalesHeader."No.";
        SalesHeader."Posting Date" := 0D;
    end;
}
