// =====================================================================
// _Cost_Subcontractor_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Subcontractor cost actuals from NetSuite GL.
// Grain:        One row per NetSuite expense line where Account Code in
//               {60201, 60203}.
// Dependencies: stg_FinanceOutput FY26_FY2026, _CutoverDate
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Account codes (CONFIRMED by Chris, 29 May meeting):
//   60201, 60202, 60203  →  Subcontractor (consultancy/agency, not on
//                            BambooHR or timesheets).
//   607*                 →  EXCLUDED (handled in _Cost_Other_Actuals — these
//                            workers ARE on timesheets, so the cost is
//                            already counted via fact_Timesheet).
// ---------------------------------------------------------------------
// Cutover logic (driven by _CutoverDate):
//   Only rows where Date <= _CutoverDate are kept. Months after the
//   cutover are covered by _Cost_Subcontractor_Forecast instead.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    SubcontractorOnly = Table.SelectRows(Source, each
        List.Contains({60201, 60202, 60203}, [#"Account No."])),

    FilledLocation = Table.ReplaceValue(
        SubcontractorOnly,
        each [#"Location: Full Name"],
        each (
            if [#"Location: Full Name"] <> null and [#"Location: Full Name"] <> ""
                then [#"Location: Full Name"]
            else if Text.EndsWith([#"Subsidiary: Full Name"] ?? "", "ESS")
                then "Italy"
            else
                "UK"
        ),
        Replacer.ReplaceValue,
        {"Location: Full Name"}
    ),

    AddCategory = Table.AddColumn(FilledLocation, "Category", each "Subcontractor", type text),
    AddType     = Table.AddColumn(AddCategory,    "Type",     each "Actual",        type text),
    AddSnapshot = Table.AddColumn(AddType,        "Snapshot Date", each null,       type date),
    AddTWR      = Table.AddColumn(AddSnapshot,    "TimeWorkReference", each null,   type text),

    Renamed = Table.RenameColumns(AddTWR, {
        {"Period End Date",          "Date"},
        {"Account No.",              "Account Code"},
        {"Sum of Amount",            "Amount"},
        {"Class: Class External ID", "Project Code"}
    }),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"}),

    // Keep only months on or before the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] <= _CutoverDate)
in
    FilteredByCutover
