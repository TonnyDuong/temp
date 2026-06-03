// =====================================================================
// _Cost_Staff_Forecast  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Staff cost forecast from Jedox allocations × per-employee
//               Revised Annual Cost. Expanded to MONTHLY rows so the
//               cutover-date measures (which gate by Date) can pick which
//               months show as forecast vs actual.
// Grain:        One row per (Project Code, TimeWorkReference, Year, Month).
// Dependencies: crbb5_jedoxallocation, dim_StaffCosts_Live
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Calculation (CONFIRMED by Chris's 02 Jun 2026 email + workbook):
//   For each Jedox row (employee, project, year, % FTE):
//     AnnualForecastCost = crbb5_value × dim_StaffCosts[RevisedAnnualCost]
//   RevisedAnnualCost is the cost net of standard holiday + public-holiday
//   allowance (computed in dim_StaffCosts — see that script for the full
//   chain). Part-time staff are already pro-rated there via HoursRatio.
//
//   The annual figure is spread evenly across 12 months:
//     MonthlyForecast = AnnualForecastCost / 12
//   and emitted as 12 rows (Jan-end … Dec-end) so the cutover-date
//   measure can filter on Date.
//
//   The "overhead bucket" (employee-level holiday cost = AnnualCost −
//   RevisedAnnualCost) is NOT emitted here — it's not shown in sector
//   profitability tables (Chris's note: "classed as overheads, not in
//   sector report"). If a separate overhead view is later required, emit
//   it as a synthetic project (e.g. "EMS-05") in its own helper.
// ---------------------------------------------------------------------
// Column names (CONFIRMED against the crbb5_jedoxallocation column list;
// LOGICAL names; using the *_name lookup columns for the human codes):
//   crbb5_version              → filter on "Forecast"
//   crbb5_hrreferencename      → TimeWorkReference (TWR code SAG/CAL/…)
//   crbb5_projectreferencename → Project Code (EEC-01/…)
//   crbb5_value                → % of FTE time (0.25, 0.15 …)
//   crbb5_year                 → Year (annual; we spread to months below)
// =====================================================================
let
    Source = #"crbb5_jedoxallocation",

    // Step 1 — keep Forecast rows only
    ForecastOnly = Table.SelectRows(Source, each [crbb5_version] = "Forecast"),

    //Step 1b
    Deduplicated= Table.Distinct(ForecastOnly,
    {"crbb5_hrreferencename", "crbb5_projectreferencename",  "crbb5_year" }),

    // Step 2 — friendly names; use the *_name lookup columns (text codes,
    //          not lookup GUIDs)
    Renamed = Table.RenameColumns(Deduplicated, {
        {"crbb5_hrreferencename",      "TimeWorkReference"},
        {"crbb5_projectreferencename", "Project Code"},
        {"crbb5_value",                "AllocationFraction"},
        {"crbb5_year",                 "Year"}
    }),
    TypedYear = Table.TransformColumnTypes(Renamed, {{"Year", Int64.Type}, {"AllocationFraction", type number}}),

    // Step 3 — join dim_StaffCosts on (TWR, Year) to get RevisedAnnualCost
    MergedRate = Table.NestedJoin(
        TypedYear, {"TimeWorkReference", "Year"},
        #"dim_StaffCosts_Live", {"TimeWorkReference", "Year"},
        "Rate_Lookup", JoinKind.LeftOuter
    ),
    ExpandRate = Table.ExpandTableColumn(MergedRate, "Rate_Lookup",
        {"RevisedAnnualCost"}, {"RevisedAnnualCost"}),

    // Step 4 — annual forecast cost per (employee, project)
    AddAnnual = Table.AddColumn(ExpandRate, "AnnualForecastCost",
        each [AllocationFraction] * (if [RevisedAnnualCost] = null then 0 else [RevisedAnnualCost]),
        Currency.Type),

    // Step 5 — expand each annual row into 12 monthly rows (Jan-end …
    //          Dec-end of the row's Year). Even spread: Amount = annual / 12.
    AddMonthly = Table.AddColumn(AddAnnual, "Monthly",
        each List.Transform({1..12}, (m) => [
            Date   = Date.EndOfMonth(#date([Year], m, 1)),
            Amount = [AnnualForecastCost] / 12
        ]),
        type list),
    Expanded = Table.ExpandListColumn(AddMonthly, "Monthly"),
    ExpandedCols = Table.ExpandRecordColumn(Expanded, "Monthly",
        {"Date", "Amount"}, {"Date", "Amount"}),
    TypedMonthly = Table.TransformColumnTypes(ExpandedCols,
        {{"Date", type date}, {"Amount", Currency.Type}}),

    // Step 6 — constants for the fact schema
    AddAccountCode = Table.AddColumn(TypedMonthly,   "Account Code",  each null,        Int64.Type),
    AddCategory    = Table.AddColumn(AddAccountCode, "Category",      each "Staff",     type text),
    AddType        = Table.AddColumn(AddCategory,    "Type",          each "Forecast",  type text),
    AddSnapshot    = Table.AddColumn(AddType,        "Snapshot Date",
        each Date.FromText(Text.From([Year]) & "-12-31"),
        type date),

    Final = Table.SelectColumns(AddSnapshot,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"}),
    #"Added Custom" = Table.AddColumn(Final, "StaffKey", each [TimeWorkReference] & "-" & Text.From(Date.Year([Date])), type text),

// Step 7 — suppress forecast rows already covered by actuals
    FilteredByCutover = Table.SelectRows(#"Added Custom",
        each [Date] > _CutoverDate),
    #"Filtered Rows" = Table.SelectRows(FilteredByCutover, each true)
in
    #"Filtered Rows"