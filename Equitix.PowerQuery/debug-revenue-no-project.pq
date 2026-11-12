// =====================================================================
// Debug_Revenue_No_Project  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Feature 5009. Actual revenue with no dim_Project_Live
//               row belongs to no contract, so the summary page cannot
//               rank it. The investigation queries show 871,076.25 of
//               in-contract revenue in this position for 2025, and
//               631,940.38 for 2024, besides the out-of-contract amounts
//               already explained by debug-as-bridge-gap.pq. This query
//               lists those rows by year, account, subsidiary, project
//               code and month.
// Grain:        One row per (Year, Contract Type, Account Code,
//               Subsidiary, Project Code, Month).
// Dependencies: fact_Revenue_Live, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// "Blank code"    the GL line has no Class External ID
// "Unknown code"  the code is set but has no dim_Project_Live row, or
//                 its project was dropped for having no Sector
// The join uses an upper-case key, so it ignores case as the model
// relationship does.
// =====================================================================
let
    Actuals = Table.SelectRows(#"fact_Revenue_Live", each
        [Type] = "Actual" and [Date] <> null),

    Narrowed = Table.SelectColumns(Actuals,
        {"Date", "Project Code", "Account Code", "Subsidiary", "Contract Type", "Amount"}),

    Keyed = Table.AddColumn(Narrowed, "Join Key",
        each if [Project Code] = null then null
             else Text.Upper(Text.Trim(Text.From([Project Code]))),
        type nullable text),

    ProjectKeys = Table.Buffer(Table.Distinct(Table.SelectColumns(
        Table.AddColumn(#"dim_Project_Live", "Join Key",
            each Text.Upper(Text.Trim(Text.From([Project Code]))), type nullable text),
        {"Join Key"}))),

    Joined = Table.NestedJoin(Keyed, {"Join Key"},
        ProjectKeys, {"Join Key"}, "Project", JoinKind.LeftAnti),

    AddReason = Table.AddColumn(Joined, "Reason", each
        if [Join Key] = null or [Join Key] = "" then "Blank code" else "Unknown code",
        type text),

    AddYear = Table.AddColumn(AddReason, "Year",
        each Date.Year(Date.From([Date])), Int64.Type),

    AddMonth = Table.AddColumn(AddYear, "Month",
        each Date.StartOfMonth(Date.From([Date])), type date),

    Grouped = Table.Group(AddMonth,
        {"Year", "Contract Type", "Reason", "Account Code", "Subsidiary", "Project Code", "Month"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Revenue", each Number.Round(-(List.Sum(List.RemoveNulls([Amount])) ?? 0), 2), type number}
    }),

    Sorted = Table.Sort(Grouped, {
        {"Year", Order.Descending}, {"Contract Type", Order.Ascending},
        {"Reason", Order.Ascending}, {"Account Code", Order.Ascending},
        {"Project Code", Order.Ascending}, {"Month", Order.Ascending}})
in
    Sorted
