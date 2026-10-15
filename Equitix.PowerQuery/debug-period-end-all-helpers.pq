// =====================================================================
// Debug_Period_End_All_Helpers  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      SUP-187. Companion to
//               debug-period-end-vs-transaction-date.pq, which proved
//               that _Revenue_Actuals dates each line by Period End
//               Date. Eve Dillon also asked on 12 Oct 2026 whether the
//               same date logic is used elsewhere the model reads the
//               finance transaction data. This query runs the same
//               check against every helper that reads
//               stg_FinanceOutput FY26_FY2026.
// Grain:        One row per (helper, GL line) where the line's account
//               is one the helper loads and its Transaction Date and
//               Period End Date fall in different months.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _Revenue_Actuals, _Revenue_Adjustment_iXBRL,
//               _Cost_Subcontractor_Actuals, _Cost_Other_Actuals
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// How each helper's rows are matched back to the GL line:
//   _Revenue_Actuals             TransactionLineKey
//   _Revenue_Adjustment_iXBRL    TransactionLineKey with the
//                                "-IXBRL-REV" / "-IXBRL-ALLOC" suffix
//                                removed, so both legs match the line
//   _Cost_Subcontractor_Actuals  Account Code | Project Code | Amount
//   _Cost_Other_Actuals          Account Code | Project Code | Amount
// The two cost helpers carry no transaction key, so they are matched on
// the composite. Two GL lines that share account, project and amount
// can collide, which shows up as "(both)" below.
//
// How to read `Model Uses`:
//   "Period End Date"   the helper dated this line by Period End Date.
//   "Transaction Date"  the helper dated it by Transaction Date. Any
//                       row with this value is a defect.
//   "(both)"            a composite-key collision on a cost helper.
//                       Inspect `Model Date(s)` and the GL by hand.
//   "(not in helper)"   the helper excluded the line by one of its own
//                       filters (iXBRL memo, EMS-04 or blank project,
//                       account type, or the cutover). Expected, and not
//                       evidence either way.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    // Only lines whose two dates fall in different months can show
    // which rule a helper applies.
    MonthsDiffer = Table.SelectRows(AccountCodeAsText, each
        [Transaction Date] <> null and [Period End Date] <> null
        and Date.StartOfMonth(Date.From([Transaction Date]))
            <> Date.StartOfMonth(Date.From([Period End Date]))),

    AddTLK = Table.AddColumn(MonthsDiffer, "TransactionLineKey",
        each Text.From([#"Transaction: Transaction ID"]) & "-" & Text.From([#"Transaction Line ID"]),
        type text),

    // Buffered so the four checks below share one read of the source
    // instead of each re-running the staging query.
    Lines = Table.Buffer(Table.AddColumn(AddTLK, "CostKey",
        each [#"Account No."] & "|" & Text.From([#"Class: Class External ID"] ?? "")
             & "|" & Text.From([Sum of Amount]),
        type text)),

    // Runs the check for one helper. HelperRows must carry
    // [Account Code], [Date] and [MatchKey]. LineKeyColumn names the
    // column on Lines that MatchKey corresponds to.
    Check = (HelperName as text, HelperRowsIn as table, LineKeyColumn as text) as table =>
        let
            // Buffered because the helper is read twice below; unbuffered,
            // each read re-runs the whole helper query.
            HelperRows = Table.Buffer(HelperRowsIn),
            HelperAccounts = List.Buffer(List.Distinct(HelperRows[Account Code])),
            Candidates = Table.SelectRows(Lines, each
                List.Contains(HelperAccounts, [#"Account No."])),
            DatesByKey = Table.Group(HelperRows, {"MatchKey"}, {
                {"Model Dates", each List.Distinct(List.Transform([Date], Date.From)), type list}}),
            Joined = Table.NestedJoin(Candidates, {LineKeyColumn},
                DatesByKey, {"MatchKey"}, "Match", JoinKind.LeftOuter),
            Expanded = Table.ExpandTableColumn(Joined, "Match",
                {"Model Dates"}, {"Model Dates"}),
            AddUses = Table.AddColumn(Expanded, "Model Uses", each
                let
                    Dates = [Model Dates] ?? {},
                    OnPeriodEnd = List.Contains(Dates, Date.From([Period End Date])),
                    OnTransaction = List.Contains(Dates, Date.From([Transaction Date]))
                in
                    if OnPeriodEnd and OnTransaction then "(both)"
                    else if OnPeriodEnd then "Period End Date"
                    else if OnTransaction then "Transaction Date"
                    else "(not in helper)",
                type text),
            AddDatesText = Table.AddColumn(AddUses, "Model Date(s)", each
                Text.Combine(List.Transform([Model Dates] ?? {},
                    each Date.ToText(_, "dd/MM/yyyy")), ", "),
                type text),
            AddHelper = Table.AddColumn(AddDatesText, "Helper",
                each HelperName, type text)
        in
            AddHelper,

    Revenue = Check("_Revenue_Actuals",
        Table.AddColumn(
            Table.SelectColumns(#"_Revenue_Actuals", {"Account Code", "Date", "TransactionLineKey"}),
            "MatchKey", each [TransactionLineKey], type text),
        "TransactionLineKey"),

    Ixbrl = Check("_Revenue_Adjustment_iXBRL",
        Table.AddColumn(
            Table.SelectColumns(#"_Revenue_Adjustment_iXBRL", {"Account Code", "Date", "TransactionLineKey"}),
            "MatchKey", each Text.BeforeDelimiter([TransactionLineKey], "-IXBRL"), type text),
        "TransactionLineKey"),

    CostKeyed = (helper as table) as table =>
        Table.AddColumn(
            Table.SelectColumns(helper, {"Account Code", "Project Code", "Amount", "Date"}),
            "MatchKey",
            each [Account Code] & "|" & Text.From([Project Code] ?? "") & "|" & Text.From([Amount]),
            type text),

    Subcontractor = Check("_Cost_Subcontractor_Actuals",
        CostKeyed(#"_Cost_Subcontractor_Actuals"), "CostKey"),

    OtherCost = Check("_Cost_Other_Actuals",
        CostKeyed(#"_Cost_Other_Actuals"), "CostKey"),

    Combined = Table.Combine({Revenue, Ixbrl, Subcontractor, OtherCost}),

    Final = Table.SelectColumns(Combined, {
        "Helper", "Model Uses", "Transaction Ref.", "TransactionLineKey",
        "Account No.", "Class: Class External ID",
        "Transaction Date", "Period End Date", "Model Date(s)",
        "Sum of Amount", "Memo"}),

    Sorted = Table.Sort(Final, {
        {"Helper", Order.Ascending},
        {"Model Uses", Order.Ascending},
        {"Transaction Date", Order.Descending}})
in
    Sorted
