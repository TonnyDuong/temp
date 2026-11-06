// =====================================================================
// Debug_AS_Bridge_Gap  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Story 5053. For 2025 the first line of the YTD bridge is
//               about 20,377 above the Additional Services matrix total.
//               This query splits the out-of-contract actuals for every
//               year by how the report treats them, and lists the rows
//               the matrix leaves out by project and month.
// Grain:        One row per (Section, Year, Bucket, Sector, Project Code,
//               Month). Summary rows carry Year and Bucket only.
// Dependencies: fact_Revenue_Live, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// Buckets:
//   "On the matrix"   non-Internal project with a reporting line
//   "Blank mapping"   non-Internal project with no reporting line, hidden
//                     by the matrix's visual filter
//   "No project row"  Project Code has no dim_Project_Live row, or is
//                     blank, so it lands in the relationship's unmatched
//                     member
//   "Internal"        Internal projects (EMS and EMI)
//
// Reading the summary, using `Revenue` (presentation sign):
//   Matrix total        = "On the matrix"
//   Bridge first line   = "On the matrix" + "Blank mapping"
//                         + "No project row"
//   Bridge Internal     = "Internal"
//   Bridge closing      = all four buckets
// If "On the matrix" is above the matrix total, the gap is not in these
// buckets. Look for a page or report-level filter on dim_Project_Live,
// which the matrix respects and the bridge measures remove.
//
// The join uses an upper-case key, so it ignores case as the model
// relationship does.
// =====================================================================
let
    Ooc = Table.SelectRows(#"fact_Revenue_Live", each
        [Contract Type] = "Out of Contract"
        and [Type] = "Actual"
        and [Date] <> null),

    Narrowed = Table.SelectColumns(Ooc, {"Date", "Project Code", "Amount"}),

    NarrowedKeyed = Table.AddColumn(Narrowed, "Join Key",
        each Text.Upper(Text.From([Project Code])), type nullable text),

    Projects = Table.SelectColumns(#"dim_Project_Live",
        {"Project Code", "Sector", "Sector Reporting - Mapping"}),

    ProjectsKeyed = Table.Buffer(Table.AddColumn(Projects, "Join Key",
        each Text.Upper(Text.From([Project Code])), type nullable text)),

    Joined = Table.NestedJoin(NarrowedKeyed, {"Join Key"},
        ProjectsKeyed, {"Join Key"}, "Project", JoinKind.LeftOuter),

    // dim_Project_Live drops rows with a null Sector, so a null Sector
    // here means the row found no project.
    Expanded = Table.ExpandTableColumn(Joined, "Project",
        {"Sector", "Sector Reporting - Mapping"}, {"Sector", "Mapping"}),

    AddBucket = Table.AddColumn(Expanded, "Bucket", each
        if [Sector] = null then "No project row"
        else if [Sector] = "Internal" then "Internal"
        else if [Mapping] = null or [Mapping] = "" then "Blank mapping"
        else "On the matrix",
        type text),

    AddYear = Table.AddColumn(AddBucket, "Year",
        each Date.Year(Date.From([Date])), Int64.Type),

    AddMonth = Table.AddColumn(AddYear, "Month",
        each Date.StartOfMonth(Date.From([Date])), type date),

    Prepared = Table.Buffer(AddMonth),

    // ---- Section 1: summary ----------------------------------------
    SummaryGrouped = Table.Group(Prepared, {"Year", "Bucket"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Revenue", each Number.Round(-(List.Sum(List.RemoveNulls([Amount])) ?? 0), 2), type number}
    }),

    SummarySection = Table.AddColumn(SummaryGrouped, "Section", each "1 Summary", type text),
    SummarySector = Table.AddColumn(SummarySection, "Sector", each null, type nullable text),
    SummaryCode = Table.AddColumn(SummarySector, "Project Code", each null, type nullable text),
    Summary = Table.AddColumn(SummaryCode, "Month", each null, type nullable date),

    // ---- Section 2: rows the matrix leaves out ---------------------
    LeftOut = Table.SelectRows(Prepared, each
        List.Contains({"No project row", "Blank mapping"}, [Bucket])),

    DetailGrouped = Table.Group(LeftOut,
        {"Year", "Bucket", "Sector", "Project Code", "Month"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Revenue", each Number.Round(-(List.Sum(List.RemoveNulls([Amount])) ?? 0), 2), type number}
    }),

    Detail = Table.AddColumn(DetailGrouped, "Section", each "2 Left out of the matrix", type text),

    Columns = {"Section", "Year", "Bucket", "Sector", "Project Code", "Month", "Lines", "Revenue"},

    Combined = Table.Combine({
        Table.SelectColumns(Summary, Columns),
        Table.SelectColumns(Detail, Columns)}),

    Sorted = Table.Sort(Combined, {
        {"Section", Order.Ascending}, {"Year", Order.Descending},
        {"Bucket", Order.Ascending}, {"Project Code", Order.Ascending},
        {"Month", Order.Ascending}})
in
    Sorted
