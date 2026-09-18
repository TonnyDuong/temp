// =====================================================================
// Debug_iXBRL_Journal_Legs  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Check whether finance's own iXBRL journals and the
//               automated reclassification double count.
//
//               fact_iXBRL_Lines_Live showed finance posting iXBRL
//               journals straight to EMS-04 (e.g. JE36048, Jun 2026:
//               "IXBRL Recharges 2025" 40,800 and "IXBRL Recharges
//               Jan-Mar26" 22,890). Those lines self-cancel under the
//               rule. The question is where the OTHER side of them sits.
//               If it is account 40013 on a sector project that the rule
//               cannot see, finance has already moved that revenue to
//               EMS-04 and _Revenue_Adjustment_iXBRL moves the underlying
//               invoices again.
//
// Scope:        Only journals with an iXBRL-memo line on EMS-04, i.e.
//               finance's own iXBRL postings. A first version took every
//               journal with any iXBRL line and flagged every other line
//               in it; the large month-end accrual journals (JE15259 and
//               similar) then produced hundreds of unrelated rows.
//
// Grain:        One row per affected journal.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// Columns (raw GL sign: revenue credits negative):
//   EMS-04 iXBRL             40013 lines on EMS-04 with an iXBRL memo.
//   iXBRL Other Account      iXBRL-memo lines on any non-40013 account
//                            (balance sheet, accrued income 13009, ...).
//   iXBRL Sector Moved       iXBRL-memo 40013 lines on other projects;
//                            the rule reclassifies these too.
//   Unexplained Offset       EMS-04 iXBRL + iXBRL Other Account +
//                            iXBRL Sector Moved. The iXBRL lines of a
//                            journal should balance among themselves.
//
// How to read it:
//   - Unexplained Offset = 0 and the offset sits in iXBRL Other Account:
//     finance's journal pairs EMS-04 with a balance-sheet account. No
//     overlap with the rule, no double count.
//   - Unexplained Offset = 0 and the offset sits in iXBRL Sector Moved:
//     the rule moves the sector side back onto EMS-04, cancelling
//     finance's journal on those lines. Totals fine; worth noting.
//   - Unexplained Offset <> 0: the EMS-04 iXBRL lines are balanced by
//     lines WITHOUT an iXBRL memo. Open that journal in the staging
//     table and look at its non-iXBRL 40013 lines — that is the
//     double-count risk.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Only journals can carry the offsetting legs. Buffer so SharePoint
    // is read once.
    JournalsOnly = Table.Buffer(Table.SelectRows(Source, each
        Text.StartsWith([#"Transaction Ref."] ?? "", "Journal"))),

    AccountCodeAsText = Table.TransformColumns(JournalsOnly,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    IXBRLLines = Table.SelectRows(AccountCodeAsText, each
        Text.Contains(Text.Lower([Memo] ?? ""), "ixbrl")),

    // Step 1 - classify each iXBRL-memo line
    Classified = Table.AddColumn(IXBRLLines, "Bucket", each
        if [#"Account No."] <> "40013" then "Other"
        else if [#"Class: Class External ID"] = "EMS-04" then "EMS04"
        else "Sector",
        type text),

    // Step 2 - one row per journal
    SumBucket = (rows as table, bucket as text) as number =>
        Number.Round(List.Sum(List.RemoveNulls(Table.Column(
            Table.SelectRows(rows, each [Bucket] = bucket), "Sum of Amount"))) ?? 0, 2),

    PerJournal = Table.Group(Classified,
        {"Transaction Ref.", "Period End Date"},
        {{"Lines", each _, type table}}),

    WithSums = Table.AddColumn(PerJournal, "Sums", (row) =>
        let
            L = row[Lines],
            e = SumBucket(L, "EMS04"),
            o = SumBucket(L, "Other"),
            s = SumBucket(L, "Sector")
        in
            [
                EMS04    = e,
                Other    = o,
                Sector   = s,
                Offset   = Number.Round(e + o + s, 2),
                Accounts = Text.Combine(List.Sort(List.Distinct(List.Transform(
                    Table.SelectRows(L, each [Bucket] = "Other")[#"Account No."],
                    Text.From))), ", ")
            ]),

    Expanded = Table.ExpandRecordColumn(WithSums, "Sums",
        {"EMS04", "Other", "Sector", "Offset", "Accounts"},
        {"EMS-04 iXBRL", "iXBRL Other Account", "iXBRL Sector Moved",
         "Unexplained Offset", "Other Accounts Used"}),

    // Step 3 - keep finance's own iXBRL postings to EMS-04
    Affected = Table.SelectRows(Expanded, each [#"EMS-04 iXBRL"] <> 0),

    Output = Table.RemoveColumns(Affected, {"Lines"}),

    Sorted = Table.Sort(Output, {{"Period End Date", Order.Ascending}})
in
    Sorted
