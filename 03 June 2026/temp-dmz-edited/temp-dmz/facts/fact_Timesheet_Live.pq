// =====================================================================
// fact_Timesheet_Live
// ---------------------------------------------------------------------
// Purpose:      Per-day-per-employee-per-project timesheet line with
//               cost already computed (Duration × StaffCostPerHour).
//               Feeds _Cost_Staff_Actuals (aggregated to fact_Cost_Live).
// Grain:        One row per timesheet line (after duplicate filter).
// Dependencies: dogma_timesheet, dim_StaffCosts_Live
// Load:         enabled.
// ---------------------------------------------------------------------
// Cost rule (final, confirmed by Chris post-Wednesday):
//   Cost = Duration × StaffCostPerHour
//   No floor, no ceiling, no monthly cap. Booked hours go to projects;
//   un-booked hours stay as overhead (not in this table).
//
// Join key:
//   Use the lookup column crbb5_crbb5_timeworkreferencename (DOUBLED
//   crbb5_ prefix). Confirmed by Chris — the alternative
//   systemuser(owninguser).crbb5_timeworkreference misses some users.
//
// EMS 90 flag:
//   Internal placeholder for unsubmitted timesheets. Flagged here for
//   exclusion in contract/sector/project visuals (via measure filters).
// =====================================================================
let
    Source = #"dogma_timesheet",

    // Step 1 — filter out flagged-bad rows
    NotDuplicate = Table.SelectRows(Source, each [#"crbb5_isduplicate"] <> true),
    NotMarkToDelete = Table.SelectRows(NotDuplicate, each [#"crbb5_marktodelete"] <> true),

    // Step 2 — filter to 2026 only
    Year2026Only = Table.SelectRows(NotMarkToDelete, each Date.Year([dogma_date]) = 2026),

    // Step 3 — surface TWR from the (doubled-prefix) lookup column
    // TODO: confirm the exact source column name; this assumes
    //       crbb5_crbb5_timeworkreferencename is already exposed as a column.
    //       If it sits inside a lookup table, expand it first.
    Renamed = Table.RenameColumns(Year2026Only, {
        {"crbb5_crbb5_timeworkreferencename", "TimeWorkReference"},
        {"dogma_project",                     "Project Code"}
    }),

    // Step 4 — keep only columns we need
    Selected = Table.SelectColumns(Renamed, {
        "dogma_date", "TimeWorkReference", "Project Code",
        "dogma_duration", "crbb5_originalprojectcode"
    }),

    // Step 5 — add Year for joining to the rate dim
    AddYear = Table.AddColumn(Selected, "Year", each Date.Year([dogma_date]), Int64.Type),

    // Step 6 — fetch StaffCostPerHour
    MergedRate = Table.NestedJoin(
        AddYear, {"TimeWorkReference", "Year"},
        #"dim_StaffCosts_Live", {"TimeWorkReference", "Year"},
        "Rate_Lookup", JoinKind.LeftOuter
    ),
    ExpandRate = Table.ExpandTableColumn(MergedRate, "Rate_Lookup",
        {"StaffCostPerHour"}, {"StaffCostPerHour"}),

    // Step 7 — compute cost
    AddCost = Table.AddColumn(ExpandRate, "Cost",
        each [dogma_duration] * [StaffCostPerHour],
        Currency.Type),

    // Step 8 — flag EMS 90 rows
    AddIsEMS90 = Table.AddColumn(AddCost, "IsEMS90",
        each [Project Code] = "EMS 90" or [crbb5_originalprojectcode] = "EMS 90",
        type logical),

    // Step 9 — drop the helper column used for EMS 90 detection
    Final = Table.RemoveColumns(AddIsEMS90, {"crbb5_originalprojectcode"})
in
    Final
