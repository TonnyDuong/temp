// =====================================================================
// _Cost_Staff_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Aggregate fact_Timesheet_Live up to the fact_Cost_Live
//               grain (Date × Project Code × TimeWorkReference).
// Grain:        One row per (Date, Project Code, TimeWorkReference).
// Dependencies: fact_Timesheet_Live
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Note: EMS 90 rows ARE included here (Chris said they should still
// reconcile per employee). They are excluded from contract / sector
// visuals via measure-level filters, not here.
// =====================================================================
let
    Source = #"fact_Timesheet_Live",

    Grouped = Table.Group(Source,
        {"Date", "Project Code", "TimeWorkReference"},
        {{"Amount", each List.Sum([Cost]), Currency.Type}}
    ),

    AddAccountCode = Table.AddColumn(Grouped,        "Account Code",  each null,     Int64.Type),
    AddCategory    = Table.AddColumn(AddAccountCode, "Category",      each "Staff",  type text),
    AddType        = Table.AddColumn(AddCategory,    "Type",          each "Actual", type text),
    AddSnapshot    = Table.AddColumn(AddType,        "Snapshot Date", each null,     type date),

    Final = Table.SelectColumns(AddSnapshot,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"}),
    #"Added Custom" = Table.AddColumn(Final, "StaffKey", each [TimeWorkReference] & "-" & Text.From(Date.Year([Date])), type text),

    // Keep only months on or before the cutover date
    FilteredByCutover = Table.SelectRows(#"Added Custom",
        each [Date] <= DateTime.From(_CutoverDate))
in
    FilteredByCutover