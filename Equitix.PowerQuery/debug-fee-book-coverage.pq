// =====================================================================
// Debug_FeeBook_Coverage  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Companion to Debug_FeeBook_Reconciliation. Run this one
//               FIRST. It answers "is the join sound and is the data the
//               shape we assumed", so that a variance in the
//               reconciliation can be read as a real difference in the
//               fee values rather than as projects quietly dropping out.
// Grain:        One diagnostic row per check.
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1, dim_Project_Live
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// What to look at:
//   - `Rows Failing Project Join` and the fee attached to them. Any
//     material amount here invalidates the reconciliation, because that
//     fee cannot reach a reporting line at all.
//   - `Projects With Multiple Fee Rows`. The Contracts sheet is one row
//     per billing schedule item, so a project with several items
//     contributes several rows. Summing is correct if each row is a
//     distinct fee line, and overstates if `crbb5_currentannualfee`
//     repeats the contract-level fee on every row. Inspect a couple of
//     the named projects before trusting the totals.
//   - `HAP-03 On Contracts Sheet` should be FALSE. HARP has its own
//     sheet and the workbook fee book excludes it, so a TRUE here means
//     Environmental Services will overstate by roughly 4.5m.
//   - `Distinct Supersector Values`. The workbook matrix has six columns
//     (Data infrastructure, Environmental services, Group structures,
//     Renewable energy, Social infrastructure, Transportation). The
//     project estate also carries `Internal` and blanks, which the
//     matrix omits.
//   - `Exchange Column Present`. If FALSE, Euro contracts are being
//     counted at their EUR face value and SI Italy will read low.
//   - `Fee On Lines Outside The Workbook Ten` is fee mapped to a
//     reporting line the report has no row for (2.71 Scotland
//     Development, 4.01 Risk Management, 1.07 Corporate Finance and so
//     on). It is expected to be non-zero and is not an error; it is
//     sized here so the TOTAL in the reconciliation can be read fairly.
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Contracts1",
    ProjectDim = #"dim_Project_Live",

    SourceColumns = Table.ColumnNames(Source),

    Wanted = List.Intersect({SourceColumns,
        {"Project Code", "Supersector", "crbb5_currentannualfee",
         "crbb5_basecurrencyname", "Entity", "Exchange"}}),
    Narrowed = Table.SelectColumns(Source, Wanted),

    KeyedRows = Table.AddColumn(Narrowed, "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    // EUR fees are divided by the workbook rate. The 11 Sep run confirmed
    // the sheet carries neither `Exchange` nor `GBP Value`, so the currency
    // has to come from `crbb5_basecurrencyname`. Same treatment as
    // debug-fee-book-reconciliation.pq - keep the two in step.
    EuroRate = 1.15,

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

    WithRawFee = Table.AddColumn(WithFee, "Fee Raw",
        each try Number.From([crbb5_currentannualfee]) otherwise null,
        type nullable number),

    DimKeyed = Table.AddColumn(
        Table.SelectColumns(ProjectDim, {"Project Code", "Upstream Report A", "IsInScope"}),
        "Project Code Key",
        each Text.Upper(Text.Trim(Text.From([Project Code] ?? ""))), type text),

    Joined = Table.NestedJoin(WithRawFee, {"Project Code Key"},
        DimKeyed, {"Project Code Key"}, "Dim", JoinKind.LeftOuter),
    JoinCount = Table.AddColumn(Joined, "Dim Match Count",
        each Table.RowCount([Dim]), Int64.Type),
    Expanded = Table.ExpandTableColumn(JoinCount, "Dim",
        {"Upstream Report A", "IsInScope"}, {"Upstream Report A", "IsInScope"}),

    SumColumn = (Rows as table, ColumnName as text) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, ColumnName))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    Unmatched = Table.SelectRows(Expanded, each [Dim Match Count] = 0),
    FannedOut = Table.SelectRows(Expanded, each [Dim Match Count] > 1),
    MaxDimMatches =
        let
            Counts = List.RemoveNulls(Table.Column(Expanded, "Dim Match Count"))
        in
            if List.IsEmpty(Counts) then 0 else List.Max(Counts),
    NullLine  = Table.SelectRows(Expanded, each [Dim Match Count] > 0 and [#"Upstream Report A"] = null),
    InScope   = Table.SelectRows(Expanded, each [IsInScope] = true),

    ProjectRowCounts = Table.Group(KeyedRows, {"Project Code Key"},
        {{"Fee Rows", each Table.RowCount(_), Int64.Type}}),
    DistinctProjects = List.RemoveNulls(Table.Column(ProjectRowCounts, "Project Code Key")),
    MultiRowProjects = List.Sort(List.RemoveNulls(Table.Column(
        Table.SelectRows(ProjectRowCounts, each [Fee Rows] > 1), "Project Code Key"))),

    SupersectorValues = if List.Contains(SourceColumns, "Supersector")
        then List.Sort(List.Distinct(List.Transform(
            Table.Column(Narrowed, "Supersector"), each Text.From(_ ?? "(blank)"))))
        else {"(column absent)"},

    WorkbookLines = {
        "2.00 Finance Only", "2.01 Social Infra Scotland",
        "2.02 Social Infra England North", "2.03 Social Infra England South",
        "2.04 Social Infra Ireland", "2.05 Social Infra Italy",
        "2.30 Highways", "2.40 Streetlighting",
        "2.50 Renewables", "2.60 Environmental Services"},

    OutsideTen = Table.SelectRows(InScope, each
        [#"Upstream Report A"] <> null
        and not List.Contains(WorkbookLines, [#"Upstream Report A"])),

    Checks = Table.FromRecords({
        [Check = "Contracts Sheet Rows",
         Value = Text.From(Table.RowCount(Source))],
        [Check = "Distinct Project Codes",
         Value = Text.From(List.Count(DistinctProjects))],
        [Check = "Projects With Multiple Fee Rows",
         Value = Text.From(List.Count(MultiRowProjects))],
        [Check = "Projects With Multiple Fee Rows (first 10)",
         Value = Text.Combine(List.FirstN(MultiRowProjects, 10), ", ")],
        [Check = "Current Annual Fee Column Present (expect TRUE)",
         Value = Text.From(List.Contains(SourceColumns, "crbb5_currentannualfee"))],
        [Check = "Exchange Column Present",
         Value = Text.From(List.Contains(SourceColumns, "Exchange"))],
        [Check = "GBP Value Column Present",
         Value = Text.From(List.Contains(SourceColumns, "GBP Value"))],
        // Fan-out check. Already answered on the 11 Sep run - 323 sheet
        // rows in, 323 rows out, so the expand does not duplicate. Kept
        // as an explicit check so the next reader does not have to infer
        // it from the row counts, and so a later change to
        // dim_Project_Live that introduced duplicate project codes would
        // show up here rather than as a silent overstatement.
        [Check = "Rows Fanning Out On Join (dim match > 1)",
         Value = Text.From(Table.RowCount(FannedOut))],
        [Check = "Max Dim Matches For One Fee Row (expect 1)",
         Value = Text.From(MaxDimMatches)],
        [Check = "Rows Failing Project Join",
         Value = Text.From(Table.RowCount(Unmatched))],
        [Check = "Fee On Rows Failing Join (GBP)",
         Value = Text.From(SumColumn(Unmatched, "Fee GBP"))],
        [Check = "Rows Joined But No Upstream Report A",
         Value = Text.From(Table.RowCount(NullLine))],
        [Check = "Fee On Rows With No Reporting Line (GBP)",
         Value = Text.From(SumColumn(NullLine, "Fee GBP"))],
        [Check = "Rows In Scope (Live/Mobilised/Terminated)",
         Value = Text.From(Table.RowCount(InScope))],
        [Check = "Rows Out Of Scope Or Unknown Status",
         Value = Text.From(Table.RowCount(Expanded) - Table.RowCount(InScope))],
        [Check = "HAP-03 On Contracts Sheet (expect FALSE)",
         Value = Text.From(List.Contains(DistinctProjects, "HAP-03"))],
        [Check = "Distinct Supersector Values",
         Value = Text.Combine(SupersectorValues, " | ")],
        [Check = "Total Fee Raw (as booked, mixed currency)",
         Value = Text.From(SumColumn(Expanded, "Fee Raw"))],
        [Check = "Total Fee GBP (all rows)",
         Value = Text.From(SumColumn(Expanded, "Fee GBP"))],
        [Check = "Total Fee GBP (in scope only)",
         Value = Text.From(SumColumn(InScope, "Fee GBP"))],
        [Check = "Fee On Lines Outside The Workbook Ten (GBP)",
         Value = Text.From(SumColumn(OutsideTen, "Fee GBP"))],
        [Check = "Workbook Fee Book Total For Reference",
         Value = "24520619.28"]
    }, type table [Check = text, Value = text])
in
    Checks
