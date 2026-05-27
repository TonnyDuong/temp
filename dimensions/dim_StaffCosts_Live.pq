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
// Business rules (CONFIRMED by client email):
//   StaffCostPerHour  = DayRate / HoursPerDay
//   HoursPerDay       = 7.5 for UK + Ireland, 8 for Italy
//   Project Cost      = (booked hours) × StaffCostPerHour  [in fact_Timesheet_Live]
//   No over/under-standard-hours adjustment: the hourly charge is applied
//   straight to the hours booked by project. No floor, ceiling or cap.
//
// Rate source (CONFIRMED by data screenshots):
//   stg_Staff Costs Summary holds the DAY RATE per (employee, year)
//   directly in the year columns (`2025`, `2026`). Take DayRate straight
//   from that column — there is NO "/ 261" annual-to-day conversion.
//
// Dedupe rule:
//   When the same TimeWorkReference appears with both EMPEMCON* (contractor)
//   and EMPEM* (permanent) EmployeeIDs, keep the EMPEM* row.
// ---------------------------------------------------------------------
// RESOLVED (confirmed by the latest data screenshots): the per-year
// columns in stg_Staff Costs Summary (`2025`, `2026`) ARE DAY RATES
// (£/day, e.g. Agnew 2026 = 241.55 → StaffCostPerHour 241.55/7.5 = 32.21),
// NOT annual salaries. So DayRate is taken directly from the year column
// and there is NO "/ 261" step.
// ---------------------------------------------------------------------
// TODO:
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

    // Step 2 — unpivot the per-year columns so each row is (TWR, Year, DayRate)
    //          The year column value is the DAY RATE (£/day) directly.
    Unpivoted = Table.UnpivotOtherColumns(
        Renamed,
        {"EmployeeID", "TimeWorkReference", "EmployeeName"},
        "Year",
        "DayRate"
    ),
    YearAsInt = Table.TransformColumnTypes(Unpivoted, {{"Year", Int64.Type}, {"DayRate", Currency.Type}}),

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
            {"DayRate",      each List.Max([DayRate]),        Currency.Type}
        }
    ),

    // Step 4 — fetch Country from crbb5_bamboohr via TimeWorkReference.
    //          crbb5_bamboohr is exposed by LOGICAL name (confirmed against
    //          its column list): join on crbb5_timeworkreference, take crbb5_country.
    MergedCountry = Table.NestedJoin(
        Grouped, {"TimeWorkReference"},
        #"crbb5_bamboohr", {"crbb5_timeworkreference"},
        "BambooHR_Lookup", JoinKind.LeftOuter
    ),
    ExpandCountry = Table.ExpandTableColumn(MergedCountry, "BambooHR_Lookup", {"crbb5_country"}, {"Country"}),

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

    // Step 7 — hourly rate (DayRate comes straight from the source year column)
    AddHourlyRate = Table.AddColumn(AddHoursPerDay, "StaffCostPerHour",
        each [DayRate] / [HoursPerDay],
        Currency.Type)
in
    AddHourlyRate
