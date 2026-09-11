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
//               Candidate source is the `Contracts` sheet of
//               EMS Fixed Fee Forecast.xlsx, already loaded as
//               stg_EMS Fixed Fee Forecast_Contracts1. It carries
//               `crbb5_currentannualfee` (the indexed-up annual fee) and
//               `Supersector`, and joins to dim_Project_Live for
//               `Upstream Report A`, the sector lead.
//
// Grain:        One row per Upstream Report A reporting line.
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// This query tests a hypothesis. It is not a client requirement and
// nothing downstream depends on it. If the variances are material on
// every line the hypothesis is wrong and the fee book has to be
// requested from the client instead of derived.
//
// What to look at:
//   - `Variance` per line, and on the TOTAL row against 24,520,619.28.
//   - Run Debug_FeeBook_Coverage FIRST. A large negative variance across
//     every line usually means projects failed the join or fell outside
//     the contract-status filter, not that the fee values are wrong.
//   - `Model Fee Book GBP` applies `Exchange` when that column is present
//     on the sheet, because Euro contracts hold EUR in
//     `crbb5_currentannualfee`. If the column is absent the rate falls
//     back to 1 and Italy will read low.
//   - `Model All Statuses` drops the IsInScope filter. If that column is
//     much closer to the workbook than `Model Fee Book GBP`, the fee book
//     includes contract statuses the profitability report excludes.
// ---------------------------------------------------------------------
// Comparison values are `For JC file` H28:H37 and H40 as at the July 2026
// close (26.07 EMS Revenue NS JC LIVE updated v2.xlsx). They are a
// point-in-time snapshot: `crbb5_currentannualfee` moves with indexation,
// so an exact match is not expected indefinitely and a small positive
// drift over time is normal rather than a defect.
//
// Known exclusion: HARP is a separate sheet in the source workbook
// (stg_EMS Fixed Fee Forecast_Project HARP, a single HAP-03 row at
// 4,500,000). The workbook fee book shows Environmental Services at
// 1,738,022.42, so the matrix excludes HARP. Debug_FeeBook_Coverage
// checks whether HAP-03 has leaked into the Contracts sheet.
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Contracts1",
    ProjectDim = #"dim_Project_Live",

    // Step 1 - narrow to metadata columns. The sheet is wide with one
    //          column per forecast month; none of those are used here.
    //          `Supersector` is carried but deliberately not grouped on:
    //          this query tests the row totals (workbook column H) first.
    //          Splitting out the six supersector columns is only worth
    //          doing once the row totals reconcile.
    Wanted = List.Intersect({Table.ColumnNames(Source),
        {"Project Code", "Supersector", "crbb5_currentannualfee", "Entity", "Exchange"}}),
    Narrowed = Table.SelectColumns(Source, Wanted),

    // Step 2 - normalised join key, matching how dim_Project_Live is keyed.
    KeyedRows = Table.AddColumn(Narrowed, "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    // Step 3 - fee converted to GBP. Record.FieldOrDefault covers the case
    //          where the sheet carries no `Exchange` column at all.
    WithFee = Table.AddColumn(KeyedRows, "Fee GBP",
        each
            let
                Fee  = try Number.From([crbb5_currentannualfee]) otherwise null,
                Rate = try Number.From(Record.FieldOrDefault(_, "Exchange", 1)) otherwise 1
            in
                if Fee = null then null
                else Fee * (if Rate = null or Rate = 0 then 1 else Rate),
        type nullable number),

    // Step 4 - attach the sector lead from the project dimension.
    DimKeyed = Table.AddColumn(
        Table.SelectColumns(ProjectDim, {"Project Code", "Upstream Report A", "IsInScope"}),
        "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    Joined = Table.NestedJoin(WithFee, {"Project Code Key"},
        DimKeyed, {"Project Code Key"}, "Dim", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Dim",
        {"Upstream Report A", "IsInScope"}, {"Upstream Report A", "IsInScope"}),

    InScopeRows = Table.SelectRows(Expanded, each [IsInScope] = true),

    SumFee = (Rows as table) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, "Fee GBP"))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    // Step 5 - the workbook fee book, by reporting line.
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
            Line         = Entry[Line],
            ModelInScope = SumFee(Table.SelectRows(InScopeRows, each [#"Upstream Report A"] = Line)),
            ModelAll     = SumFee(Table.SelectRows(Expanded,    each [#"Upstream Report A"] = Line))
        in
            [#"Reporting Line"     = Line,
             #"Model Fee Book GBP" = ModelInScope,
             #"Workbook Fee Book"  = Entry[Amount],
             Variance              = Number.Round(ModelInScope - Entry[Amount], 2),
             #"Model All Statuses" = ModelAll]),

    // TOTAL covers only the ten lines the workbook carries, so it stays
    // comparable to H40. Fee sitting on any other reporting line, or on
    // none, is reported by Debug_FeeBook_Coverage rather than inflating
    // this total.
    TotalModelInScope = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model Fee Book GBP"])), 2),
    TotalModelAll = Number.Round(
        List.Sum(List.Transform(ComparisonRows, each _[#"Model All Statuses"])), 2),

    TotalRow = [
        #"Reporting Line"     = "TOTAL (listed lines)",
        #"Model Fee Book GBP" = TotalModelInScope,
        #"Workbook Fee Book"  = 24520619.28,
        Variance              = Number.Round(TotalModelInScope - 24520619.28, 2),
        #"Model All Statuses" = TotalModelAll],

    Output = Table.FromRecords(ComparisonRows & {TotalRow},
        type table [
            #"Reporting Line"     = text,
            #"Model Fee Book GBP" = number,
            #"Workbook Fee Book"  = number,
            Variance              = number,
            #"Model All Statuses" = number])
in
    Output
