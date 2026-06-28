// =====================================================================
// _Cost_Subcontractor_Forecast  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Subcontractor cost forecast from the client's
//               "Subcontractor Fees Forecast" file. Conformed to the
//               fact_Cost_Live schema.
// Grain:        One row per (Project Code, Month).
// Dependencies: stg_SubcontractorForecast  (SharePoint Data folder)
// Load:         DISABLED.
// ---------------------------------------------------------------------
// File layout (CONFIRMED from the delivered file):
//   - WIDE monthly layout: value columns are month-end dates
//     (1/31/2026 … 12/31/2026), one column per month.
//   - The header row is ROW 3 (rows 1-2 are a title + blank). The
//     stg_SubcontractorForecast staging query MUST skip those rows and
//     promote row 3 as headers before this helper runs.
//   - Metadata columns: Netsuite N/C, Project Code, Department, Location.
//   - `Netsuite N/C` holds the account code (60201) — mapped to Account Code.
//   - `Project Code` is the join key to dim_Project (BWS-01, HAP-03, …).
// ---------------------------------------------------------------------
// TODO:
//   - Month headers display as US M/d/yyyy (see Revenue OOC helper note).
//   - All rows seen carry N/C 60201; confirm 60203 never appears here.
// =====================================================================
let
    Source = #"stg_SubcontractorForecast",

    // Step 1 — anchor on the metadata columns; unpivot the month columns
    NonDateColumns = {"Netsuite N/C", "Project Code", "Department", "Location"},
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 2 — parse the month-end header (US M/d/yyyy) into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.FromText([#"Forecast Date Text"], [Format="dd/MM/yyyy", Culture="en-US"]),
        type date),
    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    // Step 3 — Account Code from Netsuite N/C, then constants
    Renamed        = Table.RenameColumns(Typed, {{"Netsuite N/C", "Account Code"}}),
    AccountCodeAsText = Table.TransformColumnTypes(Renamed, {{"Account Code", type text}}),
    AddTWR         = Table.AddColumn(AccountCodeAsText, "TimeWorkReference", each null,         type text),
    AddCategory    = Table.AddColumn(AddTWR,         "Category",          each "Subcontractor", type text),
    AddType        = Table.AddColumn(AddCategory,    "Type",              each "Forecast",      type text),
    AddSnapshot    = Table.AddColumn(AddType,        "Snapshot Date",     each null,            type date),

    Final = Table.SelectColumns(AddSnapshot,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"}),

    // Keep only months after the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] > _CutoverDate)
in
    FilteredByCutover
