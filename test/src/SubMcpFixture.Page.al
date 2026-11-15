namespace Origo.Bifrost.SubscriptionBilling.Test;

/// <summary>Explicit operator entry point for fixture creation in an owned verification container; never a product message type or installer.</summary>
page 95728 "Sub MCP Fixture ori"
{
    PageType = List;
    SourceTable = "Sub MCP Fixture ori";
    Caption = 'Owned MCP acceptance fixtures';
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            repeater(Fixtures)
            {
                field("Fixture Key"; Rec."Fixture Key") { ToolTip = 'Identifies the separate owned fixture family for one language.'; }
                field(Name; Rec.Name) { ToolTip = 'Identifies an owned record needed by the acceptance scenario.'; }
                field(Value; Rec.Value) { ToolTip = 'Shows the identifier of the record created by the explicit seed.'; }
            }
        }
    }
    actions
    {
        area(Promoted)
        {
            actionref(SeedIssue63Promoted; SeedIssue63) { }
        }
        area(Processing)
        {
            action(SeedIssue63)
            {
                Caption = 'Seed issue 63 once';
                ToolTip = 'Create the two owned issue 63 fixture families. Refuses existing fixtures; never changes consent, licensing or write guards.';
                Image = Create;
                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"Sub MCP Seed ori");
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
