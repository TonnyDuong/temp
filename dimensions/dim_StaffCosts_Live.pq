// =====================================================================
// dim_StaffCosts_Live
// ---------------------------------------------------------------------
// Purpose:      Per-(Employee, Year) day rate and hourly rate, with
//               country-aware divisor and contractor → permanent ID
//               deduplication.
// Grain:        One row per TimeWorkReference per Year.
// Dependencies: stg_Staff Costs Summary, crbb5_bamboohr
// Load:         enabled.
// ---------------------------------------------------------------------
// Business rules (confirmed by Chris):
//   DayRate           = AnnualRate / 261
//   StaffCostPerHour  = DayRate / HoursPerDay
//   HoursPerDay       = 7.5 for UK + Ireland, 8 for Italy
//
// Dedupe rule:
//   When the same TimeWorkReference appears with both EMPEMCON* (contractor)
//   and EMPEM* (permanent) EmployeeIDs, keep the EMPEM* row.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm whether the source provides AnnualRate, DayRate, or
//     HourlyRate. This script assumes AnnualRate. If source is DayRate,
//     remove the "/ 261" step.
//   - Confirm source column names exactly match those used here.
// =====================================================================
let
    Source = #"stg_Staff Costs Summary",

    // Step 1 — friendly column names
    Renamed = Table.RenameColumns(Source, {
        {"Employee #",              "EmployeeID"},
        {"Time@work Reference",     "TimeWorkReference"},
        {"Last Name, First Name",   "EmployeeName"}
    }),

    // Step 2 — unpivot the per-year columns so each row is (TWR, Year, AnnualRate)
    Unpivoted = Table.UnpivotOtherColumns(
        Renamed,
        {"EmployeeID", "TimeWorkReference", "EmployeeName"},
        "Year",
        "AnnualRate"
    ),
    YearAsInt = Table.TransformColumnTypes(Unpivoted, {{"Year", Int64.Type}, {"AnnualRate", Currency.Type}}),

    // Step 3 — group by (TWR, Year), pick the permanent (EMPEM*) ID when both contractor and permanent exist
    Grouped = Table.Group(YearAsInt,
        {"TimeWorkReference", "Year"},
        {
            {"EmployeeID",   each
                let
                    PermanentIds = List.Select([EmployeeID], (id) => not Text.StartsWith(id, "EMPEMCON"))
                in
                    if List.Count(PermanentIds) > 0 then List.First(PermanentIds) else List.First([EmployeeID]),
                type text},
            {"EmployeeName", each List.First([EmployeeName]), type text},
            {"AnnualRate",   each List.Max([AnnualRate]),     Currency.Type}
        }
    ),

    // Step 4 — fetch Country from crbb5_bamboohr via TimeWorkReference
    MergedCountry = Table.NestedJoin(
        Grouped, {"TimeWorkReference"},
        #"crbb5_bamboohr", {"Time@work Reference"},
        "BambooHR_Lookup", JoinKind.LeftOuter
    ),
    ExpandCountry = Table.ExpandTableColumn(MergedCountry, "BambooHR_Lookup", {"Country"}, {"Country"}),

    // Step 5 — default blank Country to UK
    FilledCountry = Table.ReplaceValue(
        ExpandCountry,
        each [Country],
        each (if [Country] = null or [Country] = "" then "UK" else [Country]),
        Replacer.ReplaceValue,
        {"Country"}
    ),

    // Step 6 — country-aware hours per day
    AddHoursPerDay = Table.AddColumn(FilledCountry, "HoursPerDay",
        each if [Country] = "Italy" then 8.0 else 7.5,
        type number),

    // Step 7 — day rate
    AddDayRate = Table.AddColumn(AddHoursPerDay, "DayRate",
        each [AnnualRate] / 261,
        Currency.Type),

    // Step 8 — hourly rate
    AddHourlyRate = Table.AddColumn(AddDayRate, "StaffCostPerHour",
        each [DayRate] / [HoursPerDay],
        Currency.Type)
in
    AddHourlyRate
