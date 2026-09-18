// =====================================================================
// Debug_iXBRL_Journal_Legs  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Show every line of every GL journal that carries at
//               least one iXBRL memo line, to check whether finance's own
//               iXBRL journals and the automated reclassification double
//               count.
//
//               fact_iXBRL_Lines_Live showed finance posting iXBRL
//               journals straight to EMS-04 (e.g. JE36048, Jun 2026:
//               "IXBRL Recharges 2025" 40,800 and "IXBRL Recharges
//               Jan-Mar26" 22,890). Those lines self-cancel under the
//               rule. The question is where the OTHER side of each
//               journal sits. If it is account 40013 on a sector project
//               with no "ixbrl" in its memo, finance has already moved
//               that revenue to EMS-04 and _Revenue_Adjustment_iXBRL
//               moves the underlying invoices again.
//
// Grain:        One row per GL line in an affected journal.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// How to read `Leg Type`:
//   - "EMS-04, stays": on EMS-04 already; the rule leaves it put.
//   - "40013 sector, rule also moves": iXBRL memo on another project, so
//     the rule reclassifies it to EMS-04 as well. Fine for the total, but
//     it cancels finance's journal on that line rather than adding to it.
//   - "40013 sector, NOT moved by rule": THE RISK CASE. Finance's journal
//     reduces this sector's revenue and the rule does not see it, so if
//     the same revenue's invoices are also matched, the sector is reduced
//     twice. Sum `GL Amount` of these rows per journal: if it offsets the
//     EMS-04 lines, the double count is real.
//   - "Other account": balance sheet, accrual or other P&L. No overlap
//     with the reclassification.
//
// `GL Amount` is raw GL sign: revenue credits are negative, so a journal
// moving revenue INTO EMS-04 shows negative on EMS-04's 40013 line and
// positive (a debit) on the line it came from.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Only journals can carry the offsetting legs, so drop invoices and
    // credit notes first, then buffer so SharePoint is read once rather
    // than once per step that references this table.
    JournalsOnly = Table.Buffer(Table.SelectRows(Source, each
        Text.StartsWith([#"Transaction Ref."] ?? "", "Journal"))),

    AccountCodeAsText = Table.TransformColumns(JournalsOnly,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    IsIXBRLMemo = (memo) => Text.Contains(Text.Lower(memo ?? ""), "ixbrl"),

    // Step 1 - journals with at least one iXBRL memo line
    AffectedJournals = Table.Distinct(Table.SelectColumns(
        Table.SelectRows(AccountCodeAsText, each IsIXBRLMemo([Memo])),
        {"Transaction: Transaction ID"})),

    // Step 2 - every line of those journals, whatever its account or memo.
    //          An inner join instead of a per-row List.Contains lookup.
    Joined = Table.NestedJoin(AccountCodeAsText, {"Transaction: Transaction ID"},
        AffectedJournals, {"Transaction: Transaction ID"}, "Match", JoinKind.Inner),
    AllLegs = Table.RemoveColumns(Joined, {"Match"}),

    WithLegType = Table.AddColumn(AllLegs, "Leg Type", each
        let
            project = [#"Class: Class External ID"],
            is40013 = [#"Account No."] = "40013"
        in
            if not is40013 then "Other account"
            else if project = "EMS-04" then "EMS-04, stays"
            else if IsIXBRLMemo([Memo]) then "40013 sector, rule also moves"
            else "40013 sector, NOT moved by rule",
        type text),

    Output = Table.SelectColumns(WithLegType, {
        "Transaction Ref.", "Transaction Line ID", "Period End Date",
        "Account No.", "Account Name", "Class: Class External ID", "Memo",
        "Sum of Amount", "Leg Type"}),

    Renamed = Table.RenameColumns(Output, {
        {"Class: Class External ID", "Project Code"},
        {"Sum of Amount",            "GL Amount"}}),

    Sorted = Table.Sort(Renamed, {
        {"Period End Date", Order.Ascending},
        {"Transaction Ref.", Order.Ascending},
        {"Transaction Line ID", Order.Ascending}})
in
    Sorted
