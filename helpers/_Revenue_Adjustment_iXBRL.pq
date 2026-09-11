// =====================================================================
// _Revenue_Adjustment_iXBRL  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Automated iXBRL reporting reclassification for the
//               Additional Services report. Moves iXBRL recharge revenue
//               off the operating project it was billed to and onto
//               EMS-04, which maps to reporting line
//               "1.07 Corporate Finance".
// Grain:        Two rows per matched GL line (one reversal, one
//               reallocation). Net effect on total revenue is nil.
// Dependencies: stg_FinanceOutput FY26_FY2026, _NormalizeAccountCode,
//               _CutoverDate
// Load:         DISABLED — right-click query → untick "Enable load"
// ---------------------------------------------------------------------
// Client requirement — Eve Dillon (Financial Controller), email
// 10 Sep 2026 14:05, thread "Equitix profitability reporting: follow-up
// on files and clarifications". This replaces the previously agreed
// manually-maintained adjustments spreadsheet:
//
//   "the source data for the adjustments data can come directly from the
//    existing Finance Output FY26 transaction data loaded into the model"
//
//   "We are no longer planning to bring across the wider finance
//    adjustment process (e.g. one-off accruals, Derby Street Lighting
//    adjustments, etc.) so the only adjustment logic required in the
//    Power BI model is the automated iXBRL reclassification."
//
// The rule as specified:
//   Filter     Account Number = 40013 AND Memo contains "ixbrl"
//   Transform  reverse the value off the original project code, then
//              reallocate the same value to EMS-04
//
// Memo matching is case-insensitive by client instruction: "The memo
// should be checked against a lower-case version of the field". M's
// Text.Contains is case-sensitive by default, so the field is lowered
// before comparison rather than relying on a comparer argument.
// ---------------------------------------------------------------------
// Sign handling: both legs stay in raw GL sign (NetSuite books revenue
// as a credit, i.e. negative). The reversal leg is the arithmetic
// negation of the same raw value, so the pair nets to zero without this
// query needing to know the report's presentation sign. Do not add a
// sign flip here.
//
// Type = "Adjustment" is deliberate. It keeps the reclassification
// visible as its own row type in drill-through instead of netting it
// invisibly into the actuals, and it keeps the existing Contract
// Profitability measures unaffected: those either filter
// fact_Revenue_Live[Type] = "Actual" or sum a helper table directly.
//
// Transactions already booked to EMS-04 self-cancel (reversal and
// reallocation land on the same project code), so they correctly stay
// where they are and are not double counted.
// ---------------------------------------------------------------------
// TODO: confirm with the client whether this rule should also apply to
//   prior-year GL data. The 10 Sep specification is stated for FY26 only
//   and this query reads the FY26 staging table.
// TODO: EMS-04 is deliberately excluded from the subcontractor cost
//   dataset (07 Aug 2026 rule). Reallocating revenue into it is a
//   revenue-side change only, but confirm the two rules are intended to
//   coexist before this ships.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Normalize to the shared five-character text key before filtering.
    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    // Step 1 — the client's two filter conditions. Memo is lowered
    //          before the comparison, per the 10 Sep instruction.
    MatchedRows = Table.SelectRows(AccountCodeAsText, each
        [#"Account No."] = "40013"
        and Text.Contains(Text.Lower([Memo] ?? ""), "ixbrl")),

    // Step 2 — conform to the fact_Revenue_Live column names, keeping
    //          the two transaction-id parts needed for the line key.
    Conformed = Table.SelectColumns(
        Table.RenameColumns(MatchedRows, {
            {"Period End Date",          "Date"},
            {"Account No.",              "Account Code"},
            {"Sum of Amount",            "Amount"},
            {"Subsidiary: Full Name",    "Subsidiary"},
            {"Class: Class External ID", "Project Code"}
        }),
        {"Date", "Project Code", "Account Code", "Subsidiary", "Amount",
         "Transaction: Transaction ID", "Transaction Line ID"}),

    // Step 3 — one leg of the reclassification. ProjectCodeOverride of
    //          null keeps the originating project code.
    Leg = (input as table, ProjectCodeOverride as nullable text,
           Multiplier as number, KeySuffix as text) as table =>
        let
            SetProject =
                if ProjectCodeOverride = null then input
                else Table.TransformColumns(input,
                    {{"Project Code", each ProjectCodeOverride, type text}}),
            SetAmount = Table.TransformColumns(SetProject,
                {{"Amount", each _ * Multiplier, type number}}),
            AddTLK = Table.AddColumn(SetAmount, "TransactionLineKey",
                each Text.From([#"Transaction: Transaction ID"])
                     & "-" & Text.From([#"Transaction Line ID"])
                     & KeySuffix,
                type text),
            AddType = Table.AddColumn(AddTLK, "Type", each "Adjustment", type text),
            AddContractType = Table.AddColumn(AddType, "Contract Type",
                each "Out of Contract", type text),
            AddSnapshot = Table.AddColumn(AddContractType, "Snapshot Date",
                each null, type date),
            Final = Table.SelectColumns(AddSnapshot,
                {"Date", "Project Code", "Account Code", "Subsidiary",
                 "Type", "Contract Type", "Snapshot Date", "Amount",
                 "TransactionLineKey"})
        in
            Final,

    // Step 4 — reverse off the original project, reallocate to EMS-04.
    Reversal     = Leg(Conformed, null,     -1, "-IXBRL-REV"),
    Reallocation = Leg(Conformed, "EMS-04",  1, "-IXBRL-ALLOC"),

    Combined = Table.Combine({Reversal, Reallocation}),

    // Keep the same cutover boundary as _Revenue_Actuals so an
    // adjustment can never reverse an actual the fact has not loaded.
    FilteredByCutover = Table.SelectRows(Combined,
        each [Date] <= _CutoverDate)
in
    FilteredByCutover
