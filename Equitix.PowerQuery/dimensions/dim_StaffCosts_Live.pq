// =====================================================================
// dim_StaffCosts_Live
// ---------------------------------------------------------------------
// Purpose:      Per-(Employee, Year) day rate, hourly rate, AND the staff
//               forecast cost inputs (working hours, holiday allowance,
//               revised annual cost net of holidays). Country-aware
//               divisor for hourly; tenure-agnostic average for holidays.
// Grain:        One row per TimeWorkReference per Year.
// Dependencies: stg_Staff Costs Summary, crbb5_bamboohr, dim_HolidayPolicy_Live
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
//
// Forecast-cost inputs (CONFIRMED by Chris's 02 Jun 2026 email + workbook):
//   ContractHours      = crbb5_bamboohr.crbb5_contracthours (weekly, e.g. 37.5 FT / 20 PT)
//   FullTimeHours      = 37.5 for UK + Ireland, 40 for Italy
//   HoursRatio         = ContractHours / FullTimeHours  (FTE factor for the year)
//   NetWorkingDays(yr) = Date.NetWorkingDays equivalent for that calendar year (≈ 261)
//   HolidayDays        = dim_HolidayPolicy_Live[HolidayDays] for the year (default 28)
//   PublicHolidayDays  = dim_HolidayPolicy_Live[PublicHolidayDays] (default 8)
//   WorkedDays         = (NetWorkingDays − HolidayDays − PublicHolidayDays) × HoursRatio
//   AnnualCost         = NetWorkingDays × HoursRatio × DayRate
//   RevisedAnnualCost  = WorkedDays × DayRate
//                        (this is the cost net of holiday allowance — the
//                         figure used downstream by _Cost_Staff_Forecast as
//                         the per-employee envelope for project allocation)
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
    ExpandCountry = Table.ExpandTableColumn(MergedCountry, "BambooHR_Lookup",
        {"crbb5_country", "crbb5_contracthours"},
        {"Country", "ContractHours"}),

     // Step 5 — default blank Country to UK; default missing ContractHours
    //          to the country full-time standard (37.5 UK/IE, 40 Italy)
    FilledCountry = Table.ReplaceValue(
        ExpandCountry,
        each [Country],
        each (if [Country] = null or [Country] = "" then "UK" else [Country]),
        Replacer.ReplaceValue,
        {"Country"}
    ),
     AddFullTimeHours = Table.AddColumn(FilledCountry, "FullTimeHours",
        each if [Country] = "Italy" then 40.0 else 37.5,
        type number),
    FilledContractHours = Table.ReplaceValue(
        AddFullTimeHours,
        each [ContractHours],
        each (if [ContractHours] = null then [FullTimeHours] else [ContractHours]),
        Replacer.ReplaceValue,
        {"ContractHours"}
    ),
    AddHoursRatio = Table.AddColumn(FilledContractHours, "HoursRatio",
        each [ContractHours] / [FullTimeHours],
        type number),

    // Step 6 — country-aware hours per day (for the timesheet-based hourly rate)
    AddHoursPerDay = Table.AddColumn(AddHoursRatio, "HoursPerDay",
        each if [Country] = "Italy" then 8.0 else 7.5,
        type number),

    // Step 7 — hourly rate (DayRate comes straight from the source year column)
    AddHourlyRate = Table.AddColumn(AddHoursPerDay, "StaffCostPerHour",
        each [DayRate] / [HoursPerDay],
        Currency.Type),

    // Step 8 — NetWorkingDays for the year (≈ 261). Computed dynamically so
    //          2025/2026/2027 each get the right count (260/261/262).
    AddNetWorkingDays = Table.AddColumn(AddHourlyRate, "NetWorkingDays",
        each let yr = [Year] in
             List.Count(List.Select(
                List.Dates(#date(yr,1,1), Duration.Days(#date(yr,12,31) - #date(yr,1,1)) + 1, #duration(1,0,0,0)),
                (d) => Date.DayOfWeek(d, Day.Monday) < 5)),
        Int64.Type),

    // Step 9 — join the per-year holiday allowance
    MergedPolicy = Table.NestedJoin(
        AddNetWorkingDays, {"Year"},
        #"dim_HolidayPolicy_Live", {"Year"},
        "Policy_Lookup", JoinKind.LeftOuter
    ),
    ExpandPolicy = Table.ExpandTableColumn(MergedPolicy, "Policy_Lookup",
        {"HolidayDays", "PublicHolidayDays"},
        {"HolidayDays", "PublicHolidayDays"}),

    // Step 10 — forecast-cost inputs
    AddWorkedDays = Table.AddColumn(ExpandPolicy, "WorkedDays",
        each ([NetWorkingDays] - [HolidayDays] - [PublicHolidayDays]) * [HoursRatio],
        type number),
    AddAnnualCost = Table.AddColumn(AddWorkedDays, "AnnualCost",
        each [NetWorkingDays] * [HoursRatio] * [DayRate],
        Currency.Type),
    AddRevisedAnnualCost = Table.AddColumn(AddAnnualCost, "RevisedAnnualCost",
        each [WorkedDays] * [DayRate],
        Currency.Type),

    // Step 11 — composite StaffKey ("<TWR>-<Year>"). dim_StaffCosts keys on
    //          (TimeWorkReference, Year) — Power BI relationships can't model
    //          a composite key directly. This concat lets a single-column
    //          relationship work IF the corresponding facts/helpers also
    //          carry the same StaffKey shape.
    AddStaffKey = Table.AddColumn(AddRevisedAnnualCost, "StaffKey",
        each [TimeWorkReference] & "-" & Text.From([Year]),
        type text)
in
    AddStaffKey