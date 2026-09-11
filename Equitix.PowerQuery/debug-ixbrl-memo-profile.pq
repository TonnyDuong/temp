// =====================================================================
// Debug_iXBRL_Memo_Profile  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Diagnose why the iXBRL memo match under-collects.
//               Debug_iXBRL_Reclassification returned 5 matched lines
//               and -400.00 gross against an expectation of roughly
//               314 lines and 62,070.00 for Jan-Jul 2026, so the
//               memo text in the FY26 GL does not look like the memo
//               text in the manual adjustments workbook.
// Grain:        One row per distinct Memo value on account 40013.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// How to read it:
//   - Sort by `Lines` descending and read the top 30 memos. We are
//     looking for how the recharges are actually worded.
//   - `Has ixbrl` and `Has xbrl` separate the two candidate rules. If
//     `Has xbrl` is TRUE where `Has ixbrl` is FALSE, the GL spells it
//     "XBRL" without the leading i and the filter needs widening.
//   - A memo like "statutory accounts" or "accounts filing" with no
//     xbrl token at all means the recharges are not identifiable from
//     this field and the rule needs to go back to the client.
//   - Blank memos are counted in the `(BLANK)` row.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    // Every out-of-contract line, unfiltered by memo or cutover.
    Rows40013 = Table.SelectRows(AccountCodeAsText,
        each [#"Account No."] = "40013"),

    Normalized = Table.AddColumn(Rows40013, "MemoKey", each
        let m = Text.Trim(Text.Lower([Memo] ?? ""))
        in if m = "" then "(BLANK)" else m,
        type text),

    Grouped = Table.Group(Normalized, {"MemoKey"}, {
        {"Lines", each Table.RowCount(_), Int64.Type},
        {"Amount", each Number.Round(
            List.Sum(List.RemoveNulls(Table.Column(_, "Sum of Amount"))) ?? 0, 2),
            type number},
        {"Example Memo", each List.First(Table.Column(_, "Memo")), type text}
    }),

    AddFlags = Table.AddColumn(
        Table.AddColumn(Grouped, "Has ixbrl",
            each Text.Contains([MemoKey], "ixbrl"), type logical),
        "Has xbrl",
        each Text.Contains([MemoKey], "xbrl"), type logical),

    Sorted = Table.Sort(AddFlags, {{"Lines", Order.Descending}})
in
    Sorted
