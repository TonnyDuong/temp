// =====================================================================
// Debug_Revenue_Accounts_By_Month  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Explain the gap between the client's expected total
//               revenue and the figure the report shows. On 09 Sep 2026
//               Eve Dillon reported 20.7m expected against 17.9m shown;
//               as at 11 Sep the report's Total Revenue YTD is
//               19,009,244.48, leaving roughly 1.69m unexplained.
// Grain:        One row per (Account No., period month).
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _CutoverDate
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// This query applies NO account filter and NO cutover filter, so it
// shows the whole GL as delivered. That is the point: the report's
// figure is a filtered subset of this, and the gap has to be visible
// in the difference.
//
// How to read it:
//   - `In Report Scope` marks the four accounts the model actually
//     reads ({40010, 40011, 40012, 40013}). Everything FALSE is revenue
//     the report never shows. Account 40014 is the one to look at
//     first: it was excluded on 03 Jul 2026 because the client said
//     "40014 is recharged cost". If FALSE rows total near 1.69m, that
//     is the answer and it is a definitional difference, not a defect.
//   - `After Cutover` marks months the actuals helpers drop. The
//     cutover is currently 31 Jul 2026 and only moves to 31 Aug on the
//     12th of September, so an August close sits here and is invisible
//     to the report until then.
//   - Sum `Amount` where `In Report Scope` = TRUE and `After Cutover` =
//     FALSE. Negated, that should reconcile to Total Revenue YTD
//     (19,009,244.48). If it does, the model is doing what it is told
//     and the gap is entirely scope or period, not logic.
//
// Note the GL books revenue as a credit, so amounts are negative here.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    WithMonth = Table.AddColumn(AccountCodeAsText, "Period Month", each
        if [Period End Date] = null then "(no date)"
        else Date.ToText(Date.From([Period End Date]), "yyyy-MM"),
        type text),

    Grouped = Table.Group(WithMonth, {"Account No.", "Period Month"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Amount", each Number.Round(
            List.Sum(List.RemoveNulls(Table.Column(_, "Sum of Amount"))) ?? 0, 2),
            type number},
        {"Account Name", each List.First(Table.Column(_, "Account Name")), type text}
    }),

    AddScope = Table.AddColumn(Grouped, "In Report Scope",
        each List.Contains({"40010", "40011", "40012", "40013"}, [#"Account No."]),
        type logical),

    AddCutover = Table.AddColumn(AddScope, "After Cutover",
        each [Period Month] <> "(no date)"
             and Date.From([Period Month] & "-01") > Date.StartOfMonth(_CutoverDate),
        type logical),

    Sorted = Table.Sort(AddCutover,
        {{"Account No.", Order.Ascending}, {"Period Month", Order.Ascending}})
in
    Sorted
