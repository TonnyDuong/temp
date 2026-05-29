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
//   crbb5_hrreferencename → the employee HR reference as TEXT — the *_name
//                           column of the HR lookup, which carries the
//                           human-readable TWR code (vs crbb5_hrreference
//                           which is the lookup GUID). Joins to
//                           dim_StaffCosts[TimeWorkReference].
//   crbb5_projectreferencename → the project code as TEXT (the *_name of the
//                           project-reference lookup).
//   crbb5_value           → the allocation figure
//   crbb5_year / crbb5_yeardate / crbb5_yeartext → the period (ANNUAL).
//                           There is NO "Allocation Date" — Jedox is yearly.
//   crbb5_resourcemeasure → the unit of crbb5_value (days / % / FTE — TBC)
// ---------------------------------------------------------------------
// Business rule (29 May meeting — partial; full example pending from Chris):
//   crbb5_value is most likely the **% of FTE time** allocated (e.g. 0.25
//   = a quarter of the person's year). The naive formula
//     Amount = value × 261 × DayRate
//   would over-state cost because the 261 working days include public
//   holidays + annual leave that are NOT charged to projects on the
//   actuals side (only booked timesheet hours are). To reconcile with
//   actuals we need to strip a standard holiday-day allowance from the
//   261-day base, e.g.:
//     Amount = value × (261 - holiday_days) × DayRate
//   Chris is preparing a worked example and will confirm the exact
//   holiday-day allowance + formula. UPDATE THIS HELPER WHEN RECEIVED.
//
// The line below currently uses the placeholder `value × DayRate`
// (the "value is in days" assumption from the previous pass). LEAVE A
// BIG VISIBLE GAP until the FTE-with-holiday formula is confirmed.
// ---------------------------------------------------------------------
// TODO:
//   - Replace AddAmount formula with Chris's confirmed FTE+holiday calc.
//   - Confirm crbb5_version value to filter on ("Forecast" vs a choice id).
//   - Confirm the *_name lookup columns carry the human-readable TWR / project
//     code values. If not, expand the underlying lookup or switch to crbb5_hrcode.
// =====================================================================
let
    Source = #"crbb5_jedoxallocation",

    // Step 1 — keep Forecast rows only
    ForecastOnly = Table.SelectRows(Source, each [crbb5_version] = "Forecast"),

    // Step 2 — friendly names (logical → friendly). Use the *_name lookup
    //          columns for the join keys: they hold the human-readable codes
    //          (TWR, project code), whereas crbb5_hrreference / crbb5_projectreference
    //          hold the lookup GUIDs.
    Renamed = Table.RenameColumns(ForecastOnly, {
        {"crbb5_hrreferencename",      "TimeWorkReference"},
        {"crbb5_projectreferencename", "Project Code"},
        {"crbb5_yeardate",             "Date"},
        {"crbb5_value",                "Allocation"},
        {"crbb5_year",                 "Year"}
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
