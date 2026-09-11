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
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1, dim_Project_Live,
//               crbb5_project
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
// ROUND 2 HYPOTHESIS, which this version tests.
// Highways reconciles at EXACTLY 4.0000x: 110,040.25 x 4 = 440,161.00.
// A clean quarter is what an allocation fraction looks like, and
// `crbb5_project` carries `crbb5_revenueops` / `crbb5_revenuefinance` —
// fractions summing to 1 that split a project between the operations
// reporting line (Upstream Report A) and the regional finance line
// (Upstream Report B). See the 11 Sep 2026 decision log entry.
//
// If the fee book is apportioned by `crbb5_revenueops`, then assigning
// 100% of each fee to Upstream Report A overstates every line by a
// different amount — which is exactly the shape observed. `Model x Ops
// Share` tests it. If that column reconciles, the finance/ops split is
// not merely an open question about the report: it is already baked into
// the fee book the client signed off.
//
// What to look at:
//   - `Variance (Ops Share)` per line, and on the TOTAL row.
//   - If `Model x Ops Share` reconciles and `Model Fee Book GBP` does
//     not, the split is confirmed and Highways should land on 110,040.25.
//   - If neither reconciles, the fee book is not derivable from the
//     billing schedule and has to be requested from the client.
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
    ProjectSource = #"crbb5_project",

    EuroRate = 1.15,

    // Step 1 - narrow to metadata columns. The sheet is wide with one
    //          column per forecast month; none of those are used here.
    //          `Supersector` is carried but deliberately not grouped on:
    //          this query tests the row totals (workbook column H) first.
    //          Splitting out the six supersector columns is only worth
    //          doing once the row totals reconcile.
    Wanted = List.Intersect({Table.ColumnNames(Source),
        {"Project Code", "Supersector", "crbb5_currentannualfee",
         "crbb5_basecurrencyname", "Entity"}}),
    Narrowed = Table.SelectColumns(Source, Wanted),

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

    // Step 5 - attach the operations allocation fraction. Sourced from
    //          crbb5_project directly because dim_Project_Live does not
    //          surface it; adding it to the dimension is a model change
    //          and is deliberately not done from a diagnostic query.
    OpsKeyed = Table.AddColumn(
        Table.SelectColumns(ProjectSource, {"crbb5_projectcode", "crbb5_revenueops"}),
        "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([crbb5_projectcode] ?? ""))), type text),

    JoinedOps = Table.NestedJoin(Expanded, {"Project Code Key"},
        OpsKeyed, {"Project Code Key"}, "Ops", JoinKind.LeftOuter),
    ExpandedOps = Table.ExpandTableColumn(JoinedOps, "Ops",
        {"crbb5_revenueops"}, {"Ops Share"}),

    // A missing fraction defaults to 1, i.e. wholly operations. That
    // matches how the current report treats every project.
    WithOpsFee = Table.AddColumn(ExpandedOps, "Fee Ops GBP",
        each
            let
                Fee = [Fee GBP],
                Share = try Number.From([Ops Share]) otherwise null
            in
                if Fee = null then null
                else Fee * (if Share = null then 1 else Share),
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
            Line     = Entry[Line],
            LineRows = Table.SelectRows(WithOpsFee, each [#"Upstream Report A"] = Line),
            FullFee  = SumColumn(LineRows, "Fee GBP"),
            OpsFee   = SumColumn(LineRows, "Fee Ops GBP")
        in
            [#"Reporting Line"        = Line,
             #"Model Fee Book GBP"    = FullFee,
             #"Model x Ops Share"     = OpsFee,
             #"Workbook Fee Book"     = Entry[Amount],
             #"Variance (Ops Share)"  = Number.Round(OpsFee - Entry[Amount], 2)]),

    // TOTAL covers only the ten lines the workbook carries, so it stays
    // comparable to H40. Fee on any other reporting line is sized by
    // Debug_FeeBook_Coverage rather than inflating this total.
    TotalFull = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model Fee Book GBP"])), 2),
    TotalOps = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model x Ops Share"])), 2),

    TotalRow = [
        #"Reporting Line"        = "TOTAL (listed lines)",
        #"Model Fee Book GBP"    = TotalFull,
        #"Model x Ops Share"     = TotalOps,
        #"Workbook Fee Book"     = 24520619.28,
        #"Variance (Ops Share)"  = Number.Round(TotalOps - 24520619.28, 2)],

    Output = Table.FromRecords(ComparisonRows & {TotalRow},
        type table [
            #"Reporting Line"        = text,
            #"Model Fee Book GBP"    = number,
            #"Model x Ops Share"     = number,
            #"Workbook Fee Book"     = number,
            #"Variance (Ops Share)"  = number])
in
    Output
