// =====================================================================
// _Cost_Staff_Forecast  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Staff cost forecast from Jedox allocations × employee
//               day rates.
// Grain:        One row per (Date, Project Code, TimeWorkReference).
// Dependencies: crbb5_jedoxallocation, dim_StaffCosts_Live
// Load:         DISABLED.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm the exact formula for converting Jedox Allocation %
//     into a £ cost per period. Currently assumed:
//     Amount = Allocation × StaffCostPerDay × Working Days In Period
//   - Confirm the column name on crbb5_jedoxallocation that holds the
//     employee TWR. May be a related lookup that needs expanding.
//   - Confirm the Snapshot Date logic — currently set to the
//     allocation's Year-end.
// =====================================================================
let
    Source = #"crbb5_jedoxallocation",

    // Step 1 — keep Forecast rows only
    ForecastOnly = Table.SelectRows(Source, each [Version] = "Forecast"),

    // Step 2 — surface TimeWorkReference and friendly Project Code
    // TODO: replace the column names below if the source uses different ones
    Renamed = Table.RenameColumns(ForecastOnly, {
        {"HR Reference",      "TimeWorkReference"},
        {"Project Reference", "Project Code"},
        {"Allocation Date",   "Date"},
        {"Value",             "Allocation"}
    }),

    // Step 3 — add Year for joining to the rate dim
    AddYear = Table.AddColumn(Renamed, "Year", each Date.Year([Date]), Int64.Type),

    // Step 4 — fetch StaffCostPerDay
    MergedRate = Table.NestedJoin(
        AddYear, {"TimeWorkReference", "Year"},
        #"dim_StaffCosts_Live", {"TimeWorkReference", "Year"},
        "Rate_Lookup", JoinKind.LeftOuter
    ),
    ExpandRate = Table.ExpandTableColumn(MergedRate, "Rate_Lookup",
        {"DayRate"}, {"DayRate"}),

    // Step 5 — compute forecast amount
    // TODO: confirm working-days-in-period logic. Placeholder uses 21 (avg).
    AddAmount = Table.AddColumn(ExpandRate, "Amount",
        each [Allocation] * [DayRate] * 21,
        Currency.Type),

    // Step 6 — constants
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
