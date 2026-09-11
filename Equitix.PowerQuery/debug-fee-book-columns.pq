// =====================================================================
// Debug_FeeBook_Columns  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      List the actual column names on the Contracts sheet and
//               show how each one responds to a date parse.
//
//               Round 3 of Debug_FeeBook_Reconciliation returned exactly
//               0.00 for every reporting line, which is what happens when
//               the 2026 month-column detection matches nothing and there
//               is no column left to sum. Before guessing at a different
//               date format, read the headers.
//
// Grain:        One row per column on stg_EMS Fixed Fee Forecast_Contracts1.
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// What to look at:
//   - Scroll to the end of `Column Name`. If the month columns are there
//     at all, whichever of the three parse columns resolves is the one the
//     reconciliation should use.
//   - `Date.FromText en-GB` resolving means the headers are "31/01/2026"
//     text and the round-3 parse should have worked; look for padding or
//     a trailing time component in the raw name instead.
//   - `Via Serial Number` resolving means the headers promoted as Excel
//     date serials (e.g. "46053") and have to be converted from a number.
//   - All three failing on every row, with no date-like names present at
//     all, means the Contracts sheet carries no month columns. The schema
//     audit is ambiguous here: its prose says the sheet is wide with
//     date-named monthly columns, but its authoritative column list for
//     this table stops at `Concession expiry`.
//
// Worth knowing either way: `_Revenue_Forecast_31Dec2025` reads this same
// table and relies on the same parse (Date.From, then Date.FromText with
// en-GB) to decide which unpivoted rows to keep, discarding any that fail
// via `DateRows`. If the headers here do not parse, that production helper
// is contributing nothing to the in-contract forecast. Check the row count
// it returns before assuming this is only a diagnostic problem.
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Contracts1",
    Names = Table.ColumnNames(Source),

    Show = (Value as any) as text =>
        if Value = null then "(fails)" else Date.ToText(Value, "yyyy-MM-dd"),

    Rows = List.Transform(List.Positions(Names), (Index) =>
        let
            Name        = Names{Index},
            ViaDateFrom = try Date.From(Name) otherwise null,
            ViaEnGB     = try Date.FromText(Name, [Culture = "en-GB"]) otherwise null,
            ViaSerial   = try Date.From(Number.From(Name)) otherwise null
        in
            [Position               = Index + 1,
             #"Column Name"         = Name,
             #"Date.From"           = Show(ViaDateFrom),
             #"Date.FromText en-GB" = Show(ViaEnGB),
             #"Via Serial Number"   = Show(ViaSerial)]),

    Output = Table.FromRecords(Rows,
        type table [
            Position               = Int64.Type,
            #"Column Name"         = text,
            #"Date.From"           = text,
            #"Date.FromText en-GB" = text,
            #"Via Serial Number"   = text])
in
    Output
