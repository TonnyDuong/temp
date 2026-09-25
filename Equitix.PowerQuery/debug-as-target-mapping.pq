// =====================================================================
// Debug_AS_Target_Mapping  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Check that grouping the Additional Services target on
//               dim_Project_Live[Upstream Report A] gives the same
//               sector totals as the forecast file's own
//               `Upstream Reports` column.
//
//               debug-as-target-reconciliation.pq verified the target on
//               the FILE's column. The report groups on the DIMENSION's
//               column (the same axis as the year-to-date actuals), via
//               the Project Code relationship. Any project that is
//               missing from dim_Project_Live, or sits on a different
//               line there, moves target between rows on the page.
//
// Grain:        One row per Project Code in the forecast file.
// Dependencies: fact_AdditionalServicesTarget_Live, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// How to read it:
//   - Filter `Status` <> "Match". An empty result means the page will
//     show exactly the reconciled targets.
//   - "Not in dim_Project_Live": the target lands on the blank row of the
//     table instead of its sector.
//   - "Different line": the target lands on `Dim Upstream Report A`
//     rather than the file's line.
//   - `IsInScope` = FALSE: the target disappears if the page filters on
//     dim_Project_Live[IsInScope].
// =====================================================================
let
    Source = #"fact_AdditionalServicesTarget_Live",

    PerProject = Table.Group(Source, {"Project Code", "Upstream Reports (Source)"},
        {{"Target", each Number.Round(List.Sum(Table.Column(_, "Amount")) ?? 0, 2), type number}}),

    Projects = Table.SelectColumns(#"dim_Project_Live",
        {"Project Code", "Upstream Report A", "IsInScope"}),

    Joined = Table.NestedJoin(PerProject, {"Project Code"},
        Projects, {"Project Code"}, "Dim", JoinKind.LeftOuter),

    // A duplicated Project Code in the dimension would fan out here and
    // break the relationship; the count makes that visible.
    WithDimCount = Table.AddColumn(Joined, "Dim Rows", each Table.RowCount([Dim]), Int64.Type),

    Expanded = Table.ExpandTableColumn(WithDimCount, "Dim",
        {"Upstream Report A", "IsInScope"}, {"Dim Upstream Report A", "IsInScope"}),

    WithStatus = Table.AddColumn(Expanded, "Status", each
        if [Project Code] = null then "No project code"
        else if [Dim Rows] = 0 then "Not in dim_Project_Live"
        else if [Dim Rows] > 1 then "Duplicate in dim_Project_Live"
        else if [Dim Upstream Report A] <> [#"Upstream Reports (Source)"] then "Different line"
        else "Match",
        type text),

    // Problems first, then largest target.
    Sorted = Table.Sort(WithStatus,
        {{each if [Status] = "Match" then 1 else 0, Order.Ascending},
         {"Target", Order.Descending}})
in
    Sorted
