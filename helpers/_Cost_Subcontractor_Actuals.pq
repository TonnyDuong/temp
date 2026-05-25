// =====================================================================
// _Cost_Subcontractor_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Subcontractor cost actuals from NetSuite GL.
// Grain:        One row per NetSuite expense line where Account Code in
//               {60201, 60203}.
// Dependencies: stg_FinanceOutput FY26_FY2026
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Account codes (confirmed by Chris):
//   60201, 60203  →  Subcontractor.
//   The temporary-staff / contractor code is EXCLUDED — those workers
//   book timesheets, so including them here would double-count.
//   TODO: confirm the exact temp-staff account code with Chris.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    SubcontractorOnly = Table.SelectRows(Source, each
        List.Contains({60201, 60203}, [#"Account No."])),

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
        {"Period End Date", "Date"},
        {"Account No.",     "Account Code"},
        {"Sum of Amount",   "Amount"}
    }),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"})
in
    Final
