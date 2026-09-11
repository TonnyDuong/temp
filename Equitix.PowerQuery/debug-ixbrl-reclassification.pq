// =====================================================================
// Debug_iXBRL_Reclassification  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Visibility over the automated iXBRL reclassification
//               (Eve Dillon, 10 Sep 2026). The rule matches on free-text
//               Memo, so a reworded or truncated memo drops a
//               transaction out of the reclassification with no error.
//               This query surfaces the match count so a sudden change
//               is visible instead of silent.
// Grain:        One diagnostic row per check.
// Dependencies: stg_FinanceOutput FY26_FY2026, _Revenue_Adjustment_iXBRL,
//               dim_Project_Live, _NormalizeAccountCode
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// What to look at:
//   - `Matched GL Lines` is the number of 40013 rows whose Memo contains
//     "ixbrl". Record it at each close. A drop means memos changed
//     wording, not that the recharges stopped.
//   - `Gross Amount Matched` is the raw GL (negative) total being moved.
//   - `Net Adjustment Amount` must be 0.00. Anything else means the two
//     legs are not cancelling and the reclassification is changing the
//     revenue total rather than only moving it.
//   - `EMS-04 In Project Dim` must be TRUE. dim_Project_Live drops rows
//     with a null Sector, so if EMS-04 is absent or unsectored the
//     reallocation leg vanishes from every visual that slices by a
//     project attribute while the reversal leg stays — which removes
//     revenue instead of moving it.
//   - `Already On EMS-04` counts matched lines already booked to EMS-04.
//     Those self-cancel by design and correctly stay put.
// =====================================================================
let
    StagingSource = #"stg_FinanceOutput FY26_FY2026",
    AdjustmentSource = #"_Revenue_Adjustment_iXBRL",
    ProjectDim = #"dim_Project_Live",

    AccountCodeAsText = Table.TransformColumns(StagingSource,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    MatchedRows = Table.SelectRows(AccountCodeAsText, each
        [#"Account No."] = "40013"
        and Text.Contains(Text.Lower([Memo] ?? ""), "ixbrl")),

    SumColumn = (Rows as table, ColumnName as text) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, ColumnName))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    MatchedProjectCodes = List.Distinct(
        List.RemoveNulls(Table.Column(MatchedRows, "Class: Class External ID"))),

    AlreadyOnEMS04 = Table.RowCount(
        Table.SelectRows(MatchedRows, each
            Text.Upper(Text.Trim([#"Class: Class External ID"] ?? "")) = "EMS-04")),

    EMS04Present = List.Contains(
        List.Transform(
            List.RemoveNulls(Table.Column(ProjectDim, "Project Code")),
            each Text.Upper(Text.Trim(Text.From(_)))),
        "EMS-04"),

    Rows40013 = Table.SelectRows(AccountCodeAsText,
        each [#"Account No."] = "40013"),

    MonthsPresent = Text.Combine(
        List.Sort(List.Distinct(
            List.Transform(
                List.RemoveNulls(Table.Column(Rows40013, "Period End Date")),
                each Date.ToText(Date.From(_), "yyyy-MM")))), ", "),

    Checks = Table.FromRecords({
        // Feed-integrity checks. The workbook's NSRevenue tab is the
        // authoritative NetSuite 40013 extract for Jan-Jul 2026 and holds
        // 1,398 rows totalling -995,256.87, of which 323 rows totalling
        // -21,270.00 carry an iXBRL memo. If the rows/total below fall
        // short, the GL feed is incomplete and no memo rule can work:
        // check FinanceOutput FY26.xlsx for a saved Excel filter first
        // (see "Missing Data Troubleshooting" in README.md).
        [Check = "All 40013 Lines (workbook has 1398)",
         Value = Text.From(Table.RowCount(Rows40013))],
        [Check = "All 40013 Total (workbook has -995256.87)",
         Value = Text.From(SumColumn(Rows40013, "Sum of Amount"))],
        [Check = "40013 Period Months Present",
         Value = MonthsPresent],
        [Check = "Matched GL Lines (workbook has 323)",
         Value = Text.From(Table.RowCount(MatchedRows))],
        [Check = "Gross Amount Matched (raw GL sign)",
         Value = Text.From(SumColumn(MatchedRows, "Sum of Amount"))],
        [Check = "Distinct Project Codes Touched",
         Value = Text.From(List.Count(MatchedProjectCodes))],
        [Check = "Already On EMS-04 (self-cancelling)",
         Value = Text.From(AlreadyOnEMS04)],
        [Check = "Adjustment Rows Emitted (expect 2x matched)",
         Value = Text.From(Table.RowCount(AdjustmentSource))],
        [Check = "Net Adjustment Amount (expect 0.00)",
         Value = Text.From(SumColumn(AdjustmentSource, "Amount"))],
        [Check = "EMS-04 In Project Dim (expect TRUE)",
         Value = Text.From(EMS04Present)]
    }, type table [Check = text, Value = text])
in
    Checks
