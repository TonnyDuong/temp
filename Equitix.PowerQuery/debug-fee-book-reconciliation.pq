// =====================================================================
// Debug_FeeBook_Reconciliation  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Test whether the Additional Services fee book can be
//               rebuilt from data the model already loads, rather than
//               being pasted into the source workbook by hand.
//
//               `For JC file` rows 28-37 columns B:G hold a fee book of
//               sector lead x supersector totalling 24,520,619.28. Those
//               cells are pasted values with no derivation anywhere in
//               the workbook. Column I (% of fee book) apportions the
//               Additional Services target from them, so the fee book is
//               a hard dependency of the target column even though the
//               matrix itself is not required on the 2026 report.
//
// Grain:        One row per Upstream Report A reporting line.
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// ROUND 1 RESULT (recorded so the next reader does not repeat it).
// Summing `crbb5_currentannualfee` by `Upstream Report A` gave
// 33,804,432.60 against the workbook 24,520,619.28, with every line high
// by a different multiple. Debug_FeeBook_Coverage then ruled out the
// obvious causes:
//   - 323 sheet rows, 323 rows after the join: no fan-out.
//   - 0 rows failed the join, 0 rows landed with no reporting line.
//   - 0 rows out of contract-status scope, so IsInScope is not the gap.
//   - HAP-03 absent, so HARP is not leaking in.
// The per-line multiples were 1.0475 (SI Scotland) up to 4.0000 (Highways),
// so it is not a units or a duplication problem either.
//
// ROUND 2 TESTED AND REJECTED: the operations allocation fraction.
// `crbb5_project` carries `crbb5_revenueops` / `crbb5_revenuefinance`,
// fractions summing to 1 that split a project between the operations line
// (Upstream Report A) and the regional finance line (Upstream Report B).
// Applying `crbb5_revenueops` gave 18,457,968.60 against the workbook
// 24,520,619.28 — undershooting by as much as the raw annual fee
// overshoots — and put Highways on 301,941.64 rather than 110,040.25.
// The fee book is not ops-apportioned. Do not retry this.
//
// ROUND 3 HYPOTHESIS, which this version tests.
// Highways is high by EXACTLY 4.0000x on the unadjusted annual fee
// (110,040.25 x 4 = 440,161.00), and that survived the currency fix. A
// clean quarter of an annual run-rate is what a contract live for three
// months of the year looks like.
//
// `crbb5_currentannualfee` is a full-year run-rate regardless of when the
// contract starts or ends. The Contracts sheet also carries twelve
// date-named 2026 columns holding the indexed monthly fee — the same
// columns `_Revenue_Forecast_31Dec2025` unpivots. Summing those gives the
// fee actually falling into 2026, pro-rated for mid-year starts and ends,
// which would sit below the annual figure by a different amount per
// sector. That is the shape observed.
//
// What to look at:
//   - `Variance (2026)` per line, and on the TOTAL row.
//   - If `Model 2026 Months GBP` reconciles, Highways lands on
//     110,040.25 and the fee book is derivable from data already loaded.
//   - If it does not, three shapes of the same source have now failed and
//     the fee book should be requested from the client rather than
//     derived. Record the result here before trying a fourth.
//   - `Model Annual Fee GBP` is retained as the round-1 reference.
// ---------------------------------------------------------------------
// Currency: Debug_FeeBook_Coverage confirmed the Contracts sheet has
// NEITHER an `Exchange` NOR a `GBP Value` column, so no conversion can
// come from the sheet itself. The workbook clearly converts: SI Ireland
// 486,435.4782608696, SI Italy 1,996,295.826086957 and Renewables
// 3,653,098.043369564 each land on clean pence when multiplied by 1.15
// (559,400.80 / 2,295,740.20 / 4,201,062.75), and those are the only three
// lines with Euro exposure. So EUR fees are divided by 1.15 below, using
// `crbb5_basecurrencyname` to identify them.
//
// The 1.15 rate is taken from the source workbook and is a point-in-time
// figure, not a live rate. It is fine for a reconciliation test and must
// not be carried into a production query without a proper rate source.
// ---------------------------------------------------------------------
// Comparison values are `For JC file` H28:H37 and H40 as at the July 2026
// close (26.07 EMS Revenue NS JC LIVE updated v2.xlsx), a point-in-time
// snapshot. `crbb5_currentannualfee` moves with indexation, so small
// positive drift is expected rather than a defect.
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Contracts1",
    ProjectDim = #"dim_Project_Live",

    EuroRate = 1.15,

    // Step 1 - find the 2026 month columns by parsing the column name, the
    //          same way _Revenue_Forecast_31Dec2025 decides what to
    //          unpivot. Headers may arrive as real dates or as "31/01/2026"
    //          text, so both are tried.
    //          `Supersector` is carried but deliberately not grouped on:
    //          this query tests the row totals (workbook column H) first.
    //          Splitting out the six supersector columns is only worth
    //          doing once the row totals reconcile.
    //          Round 3 first ran with only the two parses that
    //          _Revenue_Forecast_31Dec2025 uses, matched no columns at all
    //          and returned 0.00 on every line. The four attempts below
    //          cover every shape debug-fee-book-columns.pq tests for, so
    //          whichever one the headers turn out to be, this resolves.
    //
    //          The serial attempt is bounded to 40000-60000 (roughly 2009
    //          to 2064) on purpose: without it a column named "2026" would
    //          parse as serial 2026 and be silently treated as a date in
    //          1905.
    ParseHeaderDate = (Name as text) as nullable date =>
        let
            Trimmed = Text.Trim(Name),
            ViaDate = try Date.From(Trimmed) otherwise null,
            ViaEnGB = if ViaDate <> null then ViaDate
                      else try Date.FromText(Trimmed, [Culture = "en-GB"]) otherwise null,
            ViaDateTime = if ViaEnGB <> null then ViaEnGB
                          else try Date.From(DateTime.FromText(Trimmed, [Culture = "en-GB"]))
                               otherwise null,
            ViaSerial = if ViaDateTime <> null then ViaDateTime
                        else
                            let
                                AsNumber = try Number.From(Trimmed) otherwise null
                            in
                                if AsNumber <> null and AsNumber >= 40000 and AsNumber <= 60000
                                then try Date.From(AsNumber) otherwise null
                                else null
        in
            ViaSerial,

    Columns2026 = List.Select(Table.ColumnNames(Source), each
        let
            Parsed = ParseHeaderDate(_)
        in
            Parsed <> null and Date.Year(Parsed) = 2026),

    MetaColumns = List.Intersect({Table.ColumnNames(Source),
        {"Project Code", "Supersector", "crbb5_currentannualfee",
         "crbb5_basecurrencyname", "Entity"}}),
    Narrowed = Table.SelectColumns(Source, MetaColumns & Columns2026),

    // Step 2 - normalised join key, matching how dim_Project_Live is keyed.
    KeyedRows = Table.AddColumn(Narrowed, "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    // Step 3 - fee in GBP. EUR contracts are divided by the workbook rate.
    WithFee = Table.AddColumn(KeyedRows, "Fee GBP",
        each
            let
                Fee = try Number.From([crbb5_currentannualfee]) otherwise null,
                Currency = Text.Upper(Text.Trim(Text.From(
                    Record.FieldOrDefault(_, "crbb5_basecurrencyname", "") ?? ""))),
                IsEuro = Text.Contains(Currency, "EUR")
            in
                if Fee = null then null
                else if IsEuro then Fee / EuroRate
                else Fee,
        type nullable number),

    // Step 4 - attach the sector lead from the project dimension.
    DimKeyed = Table.AddColumn(
        Table.SelectColumns(ProjectDim, {"Project Code", "Upstream Report A"}),
        "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    Joined = Table.NestedJoin(WithFee, {"Project Code Key"},
        DimKeyed, {"Project Code Key"}, "Dim", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Dim",
        {"Upstream Report A"}, {"Upstream Report A"}),

    // Step 5 - sum the 2026 month columns for each contract row. This is
    //          the fee actually falling into the year, as against the
    //          full-year run-rate in `crbb5_currentannualfee`. EUR rows are
    //          converted on the same basis as the annual figure.
    WithFee2026 = Table.AddColumn(Expanded, "Fee 2026 GBP",
        each
            let
                Row = _,
                Monthly = List.Transform(Columns2026,
                    (ColumnName) => try Number.From(Record.Field(Row, ColumnName))
                                    otherwise null),
                Total = List.Sum(List.RemoveNulls(Monthly)),
                Currency = Text.Upper(Text.Trim(Text.From(
                    Record.FieldOrDefault(Row, "crbb5_basecurrencyname", "") ?? ""))),
                IsEuro = Text.Contains(Currency, "EUR")
            in
                if Total = null then 0
                else if IsEuro then Total / EuroRate
                else Total,
        type nullable number),

    SumColumn = (Rows as table, ColumnName as text) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, ColumnName))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    // Step 6 - the workbook fee book, by reporting line.
    WorkbookFeeBook = {
        [Line = "2.00 Finance Only",               Amount = 2958278.41],
        [Line = "2.01 Social Infra Scotland",      Amount = 1837711.11],
        [Line = "2.02 Social Infra England North", Amount = 5753992.66],
        [Line = "2.03 Social Infra England South", Amount = 4528279.98],
        [Line = "2.04 Social Infra Ireland",       Amount = 486435.48],
        [Line = "2.05 Social Infra Italy",         Amount = 1996295.83],
        [Line = "2.30 Highways",                   Amount = 110040.25],
        [Line = "2.40 Streetlighting",             Amount = 1458465.10],
        [Line = "2.50 Renewables",                 Amount = 3653098.04],
        [Line = "2.60 Environmental Services",     Amount = 1738022.42]
    },

    ComparisonRows = List.Transform(WorkbookFeeBook, (Entry) =>
        let
            Line      = Entry[Line],
            LineRows  = Table.SelectRows(WithFee2026, each [#"Upstream Report A"] = Line),
            AnnualFee = SumColumn(LineRows, "Fee GBP"),
            Fee2026   = SumColumn(LineRows, "Fee 2026 GBP")
        in
            [#"Reporting Line"         = Line,
             #"Model Annual Fee GBP"   = AnnualFee,
             #"Model 2026 Months GBP"  = Fee2026,
             #"Workbook Fee Book"      = Entry[Amount],
             #"Variance (2026)"        = Number.Round(Fee2026 - Entry[Amount], 2)]),

    // TOTAL covers only the ten lines the workbook carries, so it stays
    // comparable to H40. Fee on any other reporting line is sized by
    // Debug_FeeBook_Coverage rather than inflating this total.
    TotalAnnual = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model Annual Fee GBP"])), 2),
    Total2026 = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model 2026 Months GBP"])), 2),

    TotalRow = [
        #"Reporting Line"         = "TOTAL (listed lines)",
        #"Model Annual Fee GBP"   = TotalAnnual,
        #"Model 2026 Months GBP"  = Total2026,
        #"Workbook Fee Book"      = 24520619.28,
        #"Variance (2026)"        = Number.Round(Total2026 - 24520619.28, 2)],

    Output = Table.FromRecords(ComparisonRows & {TotalRow},
        type table [
            #"Reporting Line"         = text,
            #"Model Annual Fee GBP"   = number,
            #"Model 2026 Months GBP"  = number,
            #"Workbook Fee Book"      = number,
            #"Variance (2026)"        = number])
in
    Output
