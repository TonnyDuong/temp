// =====================================================================
// Debug_iXBRL_Source_Sectors  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Story 5050. Equitix asked on 30 Oct 2026 for the Internal
//               projects (EMS and EMI) to be excluded from the Additional
//               Services pages so their totals match the YTD Profitability
//               page. The iXBRL reclassification moves matched 40013 lines
//               onto EMS-04, which is Internal. A Sector filter would drop
//               that reallocation leg but keep the reversal leg on the
//               originating project. This query shows, per year, which
//               sector the matched lines were billed to, and therefore how
//               far a Sector filter would leave the Additional Services
//               total below YTD Profitability.
// Grain:        One row per (Section, Year, Source Sector, Project Code).
// Dependencies: fact_iXBRL_Lines_Live, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// Amount is in report sign (revenue positive), as in fact_iXBRL_Lines_Live.
//
// Gap If Sector Filtered:
//   Internal source project   0. Both legs are Internal, so both are
//                             filtered out together and cancel.
//   Any other source project  the line's Amount. Its reversal stays on
//                             the page and its reallocation onto EMS-04
//                             is filtered out, so the Additional Services
//                             total falls below YTD Profitability by this
//                             much.
//   No project row            shown separately. The originating project
//                             has no dim_Project_Live row, so its reversal
//                             is already hidden by the blank-mapping
//                             filter on the Additional Services pages.
//
// Section "1 Summary" totals the gap per year. If it is 0 for every year,
// a Sector filter alone meets story 5050.
// =====================================================================
let
    Lines = Table.SelectColumns(#"fact_iXBRL_Lines_Live",
        {"Date", "Project Code", "Amount"}),

    Projects = Table.SelectColumns(#"dim_Project_Live",
        {"Project Code", "Sector"}),

    Joined = Table.NestedJoin(Lines, {"Project Code"},
        Projects, {"Project Code"}, "Project", JoinKind.LeftOuter),

    AddSector = Table.AddColumn(Joined, "Source Sector", each
        if Table.IsEmpty([Project]) then "No project row"
        else [Project]{0}[Sector] ?? "No project row",
        type text),

    AddYear = Table.AddColumn(AddSector, "Year",
        each Date.Year([Date]), Int64.Type),

    AddGap = Table.AddColumn(AddYear, "Gap If Sector Filtered", each
        if [Source Sector] = "Internal" or [Source Sector] = "No project row" then 0
        else [Amount] ?? 0,
        type number),

    // ---- Section 2: detail -----------------------------------------
    Detail = Table.Group(AddGap, {"Year", "Source Sector", "Project Code"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Amount", each Number.Round(List.Sum(List.RemoveNulls([Amount])) ?? 0, 2), type number},
        {"Gap If Sector Filtered", each Number.Round(List.Sum([Gap If Sector Filtered]), 2), type number}
    }),

    DetailSection = Table.AddColumn(Detail, "Section", each "2 Detail", type text),

    // ---- Section 1: summary per year -------------------------------
    Summary = Table.Group(AddGap, {"Year"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Amount", each Number.Round(List.Sum(List.RemoveNulls([Amount])) ?? 0, 2), type number},
        {"Gap If Sector Filtered", each Number.Round(List.Sum([Gap If Sector Filtered]), 2), type number}
    }),

    SummaryWithKeys = Table.AddColumn(
        Table.AddColumn(Summary, "Source Sector", each "(all)", type text),
        "Project Code", each "(all)", type text),

    SummarySection = Table.AddColumn(SummaryWithKeys, "Section", each "1 Summary", type text),

    Combined = Table.Combine({SummarySection, DetailSection}),

    Ordered = Table.SelectColumns(Combined,
        {"Section", "Year", "Source Sector", "Project Code", "Lines", "Amount",
         "Gap If Sector Filtered"}),

    Sorted = Table.Sort(Ordered, {
        {"Section", Order.Ascending}, {"Year", Order.Descending},
        {"Source Sector", Order.Ascending}, {"Project Code", Order.Ascending}})
in
    Sorted
