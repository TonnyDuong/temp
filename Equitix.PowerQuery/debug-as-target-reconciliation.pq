// =====================================================================
// Debug_AS_Target_Reconciliation  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Confirm the source of the Additional Services Target
//               column on the bottom table, as named by Chris Rolls on
//               the 11 Sep 2026 call.
//
//               Chris pointed at Additional Services Forecast.xlsx —
//               already loaded as stg_AdditionalServicesForecast — and
//               said the target is the sum of the monthly columns
//               "G to R" grouped by sector, quoting Finance Only as
//               "236,231". `For JC file` K28 is 236,231.02, so if that
//               holds, the per-sector targets are already in a file the
//               model ingests and no fee-book derivation is needed.
//
// Grain:        One row per Upstream Reports value.
// Dependencies: stg_AdditionalServicesForecast
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// What to look at:
//   - `Variance` on `2.00 Finance Only` first. That is the line Chris
//     quoted from memory, so it is the one he will check.
//   - The TOTAL row against 1,958,075.
//   - Rows where `Workbook Target` is null are reporting lines present in
//     the forecast file but absent from the workbook table — expected for
//     `2.71 Scotland Development` and similar, and deliberately shown
//     rather than dropped so nothing hides.
//   - If `Model Target` is populated but every variance is large, check
//     whether `Upstream Reports` carries the `2.xx` prefix. The join is
//     on the raw text, and the workbook labels may differ in form.
// ---------------------------------------------------------------------
// This replaces the fee-book line of enquiry for delivery purposes. The
// fee-book diagnostics stay in the repo as a record of what was ruled
// out, but the fee book is no longer on the critical path: the targets it
// was being reverse-engineered to produce are already in the Data folder.
//
// Comparison values are `For JC file` K28:K37 and K40 as at the July 2026
// close (26.07 EMS Revenue NS JC LIVE updated v2.xlsx).
// =====================================================================
let
    Source = #"stg_AdditionalServicesForecast",

    // Step 1 - month columns are everything that is not metadata. The
    //          staging query names them "31/01/2026" and so on, but
    //          anchoring on the metadata names instead of parsing dates
    //          avoids the header-format problem that stalled the fee-book
    //          reconciliation.
    KnownMetaColumns = {
        "Supersector", "Sector", "Upstream Reports", "Project Code",
        "Department", "Location"},

    MonthColumns = List.Select(Table.ColumnNames(Source), each
        not List.Contains(KnownMetaColumns, _) and not Text.StartsWith(_, "Column")),

    // Surfaced on the TOTAL row so the run says what it actually summed.
    // Chris described "column G to R", which is 12 months.
    MonthColumnNote = " [" & Text.From(List.Count(MonthColumns)) & " month cols]",

    // Step 2 - row total across the month columns.
    WithTotal = Table.AddColumn(Source, "Forecast Total",
        each
            let
                Row = _,
                Values = List.Transform(MonthColumns,
                    (ColumnName) => try Number.From(Record.Field(Row, ColumnName))
                                    otherwise null)
            in
                List.Sum(List.RemoveNulls(Values)) ?? 0,
        type nullable number),

    // Step 3 - group on the reporting line. `Upstream Reports` is the same
    //          field the source workbook calls `Sector Lead Reporting`.
    Grouped = Table.Group(WithTotal, {"Upstream Reports"},
        {{"Model Target", each
            Number.Round(List.Sum(List.RemoveNulls(Table.Column(_, "Forecast Total"))) ?? 0, 2),
            type number}}),

    // Step 4 - the workbook target column, for comparison.
    WorkbookTargets = {
        [Line = "2.00 Finance Only",               Amount = 236231.02],
        [Line = "2.01 Social Infra Scotland",      Amount = 146748.99],
        [Line = "2.02 Social Infra England North", Amount = 459480.61],
        [Line = "2.03 Social Infra England South", Amount = 361602.28],
        [Line = "2.04 Social Infra Ireland",       Amount = 38843.93],
        [Line = "2.05 Social Infra Italy",         Amount = 159412.65],
        [Line = "2.30 Highways",                   Amount = 8787.18],
        [Line = "2.40 Streetlighting",             Amount = 116464.60],
        [Line = "2.50 Renewables",                 Amount = 291715.31],
        [Line = "2.60 Environmental Services",     Amount = 138788.43]
    },
    WorkbookTable = Table.FromRecords(WorkbookTargets,
        type table [Line = text, Amount = number]),

    Joined = Table.NestedJoin(Grouped, {"Upstream Reports"},
        WorkbookTable, {"Line"}, "Workbook", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Workbook",
        {"Amount"}, {"Workbook Target"}),

    WithVariance = Table.AddColumn(Expanded, "Variance",
        each if [Workbook Target] = null then null
             else Number.Round([Model Target] - [Workbook Target], 2),
        type nullable number),

    Renamed = Table.RenameColumns(WithVariance, {{"Upstream Reports", "Reporting Line"}}),
    Ordered = Table.Sort(Renamed, {{"Reporting Line", Order.Ascending}}),

    ModelTotal = Number.Round(
        List.Sum(List.RemoveNulls(Table.Column(Ordered, "Model Target"))) ?? 0, 2),

    TotalRow = Table.FromRecords({[
        #"Reporting Line"  = "TOTAL (all lines)" & MonthColumnNote,
        #"Model Target"    = ModelTotal,
        #"Workbook Target" = 1958075,
        Variance           = Number.Round(ModelTotal - 1958075, 2)]},
        type table [
            #"Reporting Line"  = text,
            #"Model Target"    = number,
            #"Workbook Target" = nullable number,
            Variance           = nullable number]),

    Output = Table.Combine({Ordered, TotalRow})
in
    Output
