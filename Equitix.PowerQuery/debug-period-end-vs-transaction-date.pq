// =====================================================================
// Debug_Period_End_Vs_Transaction_Date  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      SUP-187. Eve Dillon reported on 12 Oct 2026 that the
//               YTD Profitability report appears to bring Additional
//               Services revenue in by Transaction Date rather than
//               Period End Date. This query shows, line by line, which
//               of the two dates the model actually assigns.
// Grain:        One revenue GL line (accounts 40010-40013) whose
//               Transaction Date and Period End Date fall in different
//               months. Lines where both dates share a month cannot
//               tell the two rules apart, so they are left out.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _Revenue_Actuals, _CutoverDate
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// How to read it:
//   - `Model Date` is the [Date] the line carries in _Revenue_Actuals,
//     joined on TransactionLineKey. It is null when the line is not in
//     the model at all, which `In Model` shows as FALSE.
//   - `Model Uses` reads "Period End Date" when Model Date equals the
//     line's Period End Date, and "Transaction Date" when it equals the
//     Transaction Date. The two dates differ by month on every row, so
//     only one can match.
//   - The first rows are the strongest examples: Out of Contract
//     (40013, the Additional Services account) lines posted after the
//     cutover month but dated to a period on or before it. Under a
//     Period End Date rule they are IN the report; under a Transaction
//     Date rule they would be OUT.
//   - Any row where `In Model` is FALSE and `Period End Date` is on or
//     before `Cutover Date` is a genuine defect and should be reported.
//
// This query reads the repository version of the helpers. If the
// published model's helpers were edited in Power BI Desktop, run this
// inside the published model so it reads those edits instead.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    RevenueOnly = Table.SelectRows(AccountCodeAsText, each
        List.Contains({"40010", "40011", "40012", "40013"}, [#"Account No."])),

    // Only lines whose two dates fall in different months can show
    // which rule the model applies.
    MonthsDiffer = Table.SelectRows(RevenueOnly, each
        [Transaction Date] <> null and [Period End Date] <> null
        and Date.StartOfMonth(Date.From([Transaction Date]))
            <> Date.StartOfMonth(Date.From([Period End Date]))),

    AddTLK = Table.AddColumn(MonthsDiffer, "TransactionLineKey",
        each Text.From([#"Transaction: Transaction ID"]) & "-" & Text.From([#"Transaction Line ID"]),
        type text),

    // The model's own view of each line.
    ModelLines = Table.SelectColumns(#"_Revenue_Actuals",
        {"TransactionLineKey", "Date", "Contract Type"}),

    Joined = Table.NestedJoin(AddTLK, {"TransactionLineKey"},
        ModelLines, {"TransactionLineKey"}, "Model", JoinKind.LeftOuter),

    Expanded = Table.ExpandTableColumn(Joined, "Model",
        {"Date", "Contract Type"}, {"Model Date", "Contract Type"}),

    AddInModel = Table.AddColumn(Expanded, "In Model",
        each [Model Date] <> null, type logical),

    AddModelUses = Table.AddColumn(AddInModel, "Model Uses", each
        if [Model Date] = null then "(not loaded)"
        else if Date.From([Model Date]) = Date.From([Period End Date]) then "Period End Date"
        else if Date.From([Model Date]) = Date.From([Transaction Date]) then "Transaction Date"
        else "(neither)",
        type text),

    AddCutover = Table.AddColumn(AddModelUses, "Cutover Date",
        each _CutoverDate, type date),

    // Posted after the cutover month but belonging to a period on or
    // before it: the case Eve described.
    AddLatePosting = Table.AddColumn(AddCutover, "Late Posting", each
        Date.From([Transaction Date]) > _CutoverDate
        and Date.From([Period End Date]) <= _CutoverDate,
        type logical),

    AddRank = Table.AddColumn(AddLatePosting, "Example Rank", each
        (if [#"Account No."] = "40013" then 0 else 2)
        + (if [Late Posting] then 0 else 1),
        Int64.Type),

    Final = Table.SelectColumns(AddRank, {
        "Example Rank", "Transaction Ref.", "TransactionLineKey",
        "Account No.", "Contract Type", "Class: Class External ID",
        "Transaction Date", "Period End Date", "Model Date",
        "Model Uses", "In Model", "Late Posting", "Cutover Date",
        "Sum of Amount", "Memo"}),

    Sorted = Table.Sort(Final, {
        {"Example Rank", Order.Ascending},
        {"Transaction Date", Order.Descending}})
in
    Sorted
