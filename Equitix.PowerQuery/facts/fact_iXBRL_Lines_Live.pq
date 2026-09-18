// =====================================================================
// fact_iXBRL_Lines_Live
// ---------------------------------------------------------------------
// Purpose:      Evidence table for the iXBRL reclassification. One row
//               per GL line the rule matched, carrying the Memo that
//               triggered it, so the client can see which lines were
//               moved to 1.07 Corporate Finance and why.
// Grain:        One row per matched GL row in the FY26 extract.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _CutoverDate
// Load:         enabled.
// Relationships (Many-to-One, single direction, active):
//   [Date]         -> dim_Date_Live[Date]
//   [Project Code] -> dim_Project_Live[Project Code]
// ---------------------------------------------------------------------
// Client requirement: Chris Rolls asked on the 18 Sep 2026 call how the
// iXBRL reclassification is set up and whether it is working. This table
// shows the matched lines behind the reclassification page.
//
// THE MATCH RULE MUST STAY IDENTICAL TO _Revenue_Adjustment_iXBRL (Step 1
// there, Step 1 here). Change both together or the evidence stops
// describing what the report does:
//   Account 40013 AND lower-cased Memo contains "ixbrl", on or before
//   _CutoverDate.
//
// Why a separate table rather than a relationship from fact_Revenue_Live
// to dim_Transaction_Live on TransactionLineKey:
//   - That relationship does not exist in the model, and adding one would
//     change the fact behind the already-accepted pages.
//   - TransactionLineKey is not unique in the GL extract (Power BI
//     proposed many-to-many), so a de-duplicated dimension would pick an
//     arbitrary row per key.
//
// Amount is shown in report sign (revenue positive), the negation of the
// raw GL credit, so it reads the same way as `AS Revenue`.
//
// `Moved To 1.07` is FALSE for lines already booked to EMS-04: they match
// the rule but self-cancel in the reclassification and stay where they
// are. Summing Amount where it is TRUE gives the reclassification onto
// 1.07 Corporate Finance.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    // Step 1 — the iXBRL rule, identical to _Revenue_Adjustment_iXBRL
    MatchedRows = Table.SelectRows(AccountCodeAsText, each
        [#"Account No."] = "40013"
        and Text.Contains(Text.Lower([Memo] ?? ""), "ixbrl")),

    // Step 2 — output shape
    Renamed = Table.RenameColumns(MatchedRows, {
        {"Period End Date",          "Date"},
        {"Class: Class External ID", "Project Code"},
        {"Customer: Full Name",      "Customer"}
    }),

    WithAmount = Table.AddColumn(Renamed, "Amount",
        each -([#"Sum of Amount"] ?? 0), Currency.Type),

    WithMoved = Table.AddColumn(WithAmount, "Moved To 1.07",
        each [Project Code] <> "EMS-04", type logical),

    Final = Table.SelectColumns(WithMoved,
        {"Date", "Transaction Ref.", "Transaction Line ID", "Project Code",
         "Customer", "Memo", "Amount", "Moved To 1.07"}),

    Typed = Table.TransformColumnTypes(Final, {{"Date", type date}}),

    // Same boundary as the reclassification and the actuals
    FilteredByCutover = Table.SelectRows(Typed, each [Date] <= _CutoverDate)
in
    FilteredByCutover
