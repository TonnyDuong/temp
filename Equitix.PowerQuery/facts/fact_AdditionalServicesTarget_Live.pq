// =====================================================================
// fact_AdditionalServicesTarget_Live
// ---------------------------------------------------------------------
// Purpose:      Full-year Additional Services target per project and
//               month, for the "Forecast vs Year to Date" table.
// Grain:        One row per (Project Code, Month) with a non-zero value.
// Dependencies: stg_AdditionalServicesForecast  (SharePoint Data folder)
// Load:         enabled.
// Relationships (Many-to-One, single direction, active):
//   [Date]         -> dim_Date_Live[Date]
//   [Project Code] -> dim_Project_Live[Project Code]
// ---------------------------------------------------------------------
// Client requirement (Chris Rolls, 11 Sep 2026 catch-up): the target is
// "a sum of those" monthly columns in Additional Services Forecast.xlsx,
// grouped by sector. Verified 18 Sep 2026 by
// debug-as-target-reconciliation.pq: 1,958,074.80 against the workbook's
// 1,958,075, every sector line within 0.06.
//
// Why this is not a helper appended to fact_Revenue_Live:
//   - _Revenue_Forecast_OOC reads the same file but keeps only months
//     AFTER _CutoverDate, because it is the remaining-forecast stream.
//     The target is the whole year regardless of cutover, so it cannot
//     come from that helper or from fact_Revenue_Live.
//   - The `Revenue` measure sums fact_Revenue_Live with no Type filter,
//     so appending target rows there would change existing totals.
//
// No cutover filter here, deliberately: the target is fixed for the year.
//
// Month columns are recognised by parsing the header as a dd/MM/yyyy date
// rather than by name, so extending the file to the right for 2027 (as
// agreed on 11 Sep) needs no change here. Non-date columns (the trailing
// `Column19` / `Column20` in the staging query) are ignored.
//
// `Upstream Reports (Source)` carries the file's own sector label for
// reconciliation only. Report visuals group on dim_Project_Live
// [Upstream Report A] through the Project Code relationship, the same
// axis as the year-to-date actuals. debug-as-target-mapping.pq checks the
// two agree.
// =====================================================================
let
    Source = #"stg_AdditionalServicesForecast",

    // Step 1 - month columns are the headers that parse as dates
    MonthColumns = List.Select(Table.ColumnNames(Source), each
        (try Date.FromText(_, [Format = "dd/MM/yyyy", Culture = "en-GB"]) otherwise null) <> null),

    Trimmed = Table.SelectColumns(Source,
        {"Project Code", "Upstream Reports"} & MonthColumns),

    // Step 2 - unpivot to one row per project and month
    Unpivoted = Table.UnpivotOtherColumns(Trimmed,
        {"Project Code", "Upstream Reports"}, "Month Text", "Amount Raw"),

    WithDate = Table.AddColumn(Unpivoted, "Date",
        each Date.FromText([Month Text], [Format = "dd/MM/yyyy", Culture = "en-GB"]),
        type date),

    WithAmount = Table.AddColumn(WithDate, "Amount",
        each try Number.From([Amount Raw]) otherwise null,
        Currency.Type),

    NonZero = Table.SelectRows(WithAmount,
        each [Amount] <> null and [Amount] <> 0),

    // Step 3 - output shape
    Renamed = Table.RenameColumns(NonZero,
        {{"Upstream Reports", "Upstream Reports (Source)"}}),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Project Code", "Upstream Reports (Source)", "Amount"})
in
    Final
