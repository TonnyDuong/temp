// =====================================================================
// _Cost_Staff_Forecast  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Staff cost forecast from Jedox allocations × employee
//               day rates.
// Grain:        One row per (Project Code, TimeWorkReference, Year).
// Dependencies: crbb5_jedoxallocation, dim_StaffCosts_Live
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Column names (CONFIRMED against the crbb5_jedoxallocation column list;
// exposed by LOGICAL name):
//   crbb5_version         → forecast version filter (Forecast / Baseline / ...)
//   crbb5_hrreference     → the employee HR reference (join to dim_StaffCosts
//                           TimeWorkReference). NOTE: crbb5_hrcode and
//                           crbb5_hrreferencename also exist — confirm which
//                           one carries the TWR code (SAG, CAL, ...).
//   crbb5_projectreference→ the project code (EEC-01, ...)
//   crbb5_value           → the allocation figure
//   crbb5_year / crbb5_yeardate / crbb5_yeartext → the period (ANNUAL).
//                           There is NO "Allocation Date" — Jedox is yearly.
//   crbb5_resourcemeasure → the unit of crbb5_value (days / % / FTE — TBC)
// ---------------------------------------------------------------------
// TODO (business rule — confirm with Chris before go-live):
//   - What does crbb5_value represent (allocated DAYS, a % of the year, or
//     an FTE fraction)? See crbb5_resourcemeasure. This drives the £ formula:
//       * days  → Amount = value × DayRate
//       * % year→ Amount = value × 261 × DayRate
//     The line below assumes DAYS (Amount = value × DayRate). FIX once known.
//   - Jedox is ANNUAL. The PoC "Cost For (staff)" full-year column is fine
//     with an annual figure; if a monthly spread is needed, define it.
//   - Confirm crbb5_version value to filter on ("Forecast" vs a choice id).
//   - Confirm crbb5_hrreference (vs crbb5_hrcode) is the TWR join key.
// =====================================================================
let
    Source = #"crbb5_jedoxallocation",

    // Step 1 — keep Forecast rows only
    ForecastOnly = Table.SelectRows(Source, each [crbb5_version] = "Forecast"),

    // Step 2 — friendly names (logical → friendly)
    Renamed = Table.RenameColumns(ForecastOnly, {
        {"crbb5_hrreference",      "TimeWorkReference"},
        {"crbb5_projectreference", "Project Code"},
        {"crbb5_yeardate",         "Date"},
        {"crbb5_value",            "Allocation"},
        {"crbb5_year",             "Year"}
    }),
    TypedYear = Table.TransformColumnTypes(Renamed, {{"Year", Int64.Type}}),

    // Step 3 — fetch DayRate from the rate dim (by TWR + Year)
    MergedRate = Table.NestedJoin(
        TypedYear, {"TimeWorkReference", "Year"},
        #"dim_StaffCosts_Live", {"TimeWorkReference", "Year"},
        "Rate_Lookup", JoinKind.LeftOuter
    ),
    ExpandRate = Table.ExpandTableColumn(MergedRate, "Rate_Lookup",
        {"DayRate"}, {"DayRate"}),

    // Step 4 — compute forecast amount
    // ASSUMES crbb5_value = allocated days. Confirm via crbb5_resourcemeasure (see TODO).
    AddAmount = Table.AddColumn(ExpandRate, "Amount",
        each [Allocation] * [DayRate],
        Currency.Type),

    // Step 5 — constants
    AddAccountCode = Table.AddColumn(AddAmount,      "Account Code",  each null,        Int64.Type),
    AddCategory    = Table.AddColumn(AddAccountCode, "Category",      each "Staff",     type text),
    AddType        = Table.AddColumn(AddCategory,    "Type",          each "Forecast",  type text),
    AddSnapshot    = Table.AddColumn(AddType,        "Snapshot Date",
        each Date.FromText(Text.From([Year]) & "-12-31"),
        type date),

    Final = Table.SelectColumns(AddSnapshot,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"})
in
    Final
