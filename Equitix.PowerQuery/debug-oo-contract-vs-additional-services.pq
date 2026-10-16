// =====================================================================
// Debug_OO_Contract_Vs_Additional_Services  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      SUP-187. Eve Dillon, 16 Oct 2026: the YTD Profitability
//               `Revenue Act OO-Contract` column shows 1,445,818 but
//               "should agree to the additional services report
//               (1,405,109)", and she attributes the 40,709 gap to the
//               column using Transaction Date. This query bridges the
//               two figures for 2026 so the gap can be explained line by
//               line.
// Grain:        One row per (Section, Bucket, Sector, Type).
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _CutoverDate, fact_Revenue_Live, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// Section "1 Date rule" tests Eve's explanation directly. It sums GL
// account 40013 for 2026 up to the cutover twice: once bucketed by
// Period End Date and once by Transaction Date. Whichever matches
// 1,445,818 is the rule the column is using.
//
// Section "2 Scope" splits the 2026 Out of Contract rows in
// fact_Revenue_Live by how the Additional Services pages treat them.
// Those pages carry a visual-level filter, agreed 25 Sep 2026, that
// `Sector Reporting - Mapping` is not blank and is not
// `2.71 Scotland Development`. The YTD Profitability column has no such
// filter. Buckets:
//   "In AS scope"                 shown on both pages
//   "No project row"              Project Code has no dim_Project_Live
//                                 row (e.g. ZZZ-01, blank class)
//   "Blank mapping"               project row exists, mapping is blank
//   "2.71 Scotland Development"   hidden on the AS pages by name
// Type "Actual" rows feed both figures. Type "Adjustment" rows (the iXBRL
// reclassification) feed only the AS pages, and net to zero only when
// both legs land in "In AS scope".
//
// Expected reconciliation, using `Revenue` (presentation sign):
//   YTD column  = sum of Actual rows across every bucket
//   AS report   = sum of Actual + Adjustment rows in "In AS scope"
// If a Sector slicer or other filter was applied on either page when
// Eve read her figure, filter the Sector column here the same way.
// =====================================================================
let
    ReportYear = 2026,

    // ---- Section 1: date rule --------------------------------------
    Gl = Table.TransformColumns(#"stg_FinanceOutput FY26_FY2026",
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    Gl40013 = Table.Buffer(Table.SelectRows(Gl, each [#"Account No."] = "40013")),

    RuleTotal = (DateColumn as text) as number =>
        -List.Sum(List.RemoveNulls(Table.Column(
            Table.SelectRows(Gl40013, each
                let d = Record.Field(_, DateColumn) in
                    d <> null
                    and Date.Year(Date.From(d)) = ReportYear
                    and Date.From(d) <= _CutoverDate),
            "Sum of Amount"))),

    DateRule = #table(
        type table [Section = text, Bucket = text, Sector = text, Type = text,
                    Lines = Int64.Type, Revenue = number],
        {
            {"1 Date rule", "GL 40013 by Period End Date", null, "Actual", null,
                Number.Round(RuleTotal("Period End Date"), 2)},
            {"1 Date rule", "GL 40013 by Transaction Date", null, "Actual", null,
                Number.Round(RuleTotal("Transaction Date"), 2)}
        }),

    // ---- Section 2: scope ------------------------------------------
    Ooc = Table.SelectRows(#"fact_Revenue_Live", each
        [Contract Type] = "Out of Contract"
        and List.Contains({"Actual", "Adjustment"}, [Type])
        and [Date] <> null
        and Date.Year(Date.From([Date])) = ReportYear),

    Projects = Table.SelectColumns(#"dim_Project_Live",
        {"Project Code", "Sector", "Sector Reporting - Mapping"}),

    Joined = Table.NestedJoin(Ooc, {"Project Code"},
        Projects, {"Project Code"}, "Project", JoinKind.LeftOuter),

    AddProject = Table.AddColumn(Joined, "ProjectRow",
        each if Table.IsEmpty([Project]) then null else [Project]{0}),

    AddBucket = Table.AddColumn(AddProject, "Bucket", each
        if [ProjectRow] = null then "No project row"
        else if [ProjectRow][#"Sector Reporting - Mapping"] = null
             or [ProjectRow][#"Sector Reporting - Mapping"] = "" then "Blank mapping"
        else if Text.Contains([ProjectRow][#"Sector Reporting - Mapping"], "2.71 Scotland Development")
            then "2.71 Scotland Development"
        else "In AS scope",
        type text),

    AddSector = Table.AddColumn(AddBucket, "Sector",
        each if [ProjectRow] = null then null else [ProjectRow][Sector], type text),

    Grouped = Table.Group(AddSector, {"Bucket", "Sector", "Type"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Revenue", each Number.Round(-(List.Sum(List.RemoveNulls([Amount])) ?? 0), 2), type number}
    }),

    Scope = Table.AddColumn(Grouped, "Section", each "2 Scope", type text),

    Combined = Table.Combine({DateRule,
        Table.SelectColumns(Scope, {"Section", "Bucket", "Sector", "Type", "Lines", "Revenue"})}),

    Sorted = Table.Sort(Combined, {
        {"Section", Order.Ascending}, {"Bucket", Order.Ascending},
        {"Sector", Order.Ascending}, {"Type", Order.Ascending}})
in
    Sorted
