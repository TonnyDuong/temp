// =====================================================================
// fact_Revenue_Live
// ---------------------------------------------------------------------
// Purpose:      Unified revenue fact — actuals + forecast,
//               in-contract + out-of-contract — in a single table.
// Grain:        One row per (Date, Project, Account, Type, Snapshot).
// Dependencies: _Revenue_Actuals, _Revenue_Forecast_31Dec2025,
//               _Revenue_Forecast_HARP, _Revenue_Forecast_OOC
// Load:         enabled.
// ---------------------------------------------------------------------
// Reporting rule:
//   HARP is INGESTED through its own helper because the source sheet has a
//   different shape, but it is NOT a separate report dataset. Report
//   measures and visuals must treat it as part of the single in-contract
//   forecast stream exposed by fact_Revenue_Live.
// ---------------------------------------------------------------------
// Each helper conforms to the same column shape, so a Table.Combine
// produces the final fact. Adding a new revenue source means:
//   1. Build a new helper query in helpers/ with the same column shape.
//   2. Reference it in the Table.Combine call below.
// =====================================================================
let
    Combined = Table.Combine({
        #"_Revenue_Actuals",
        #"_Revenue_Forecast_31Dec2025",
        #"_Revenue_Forecast_HARP",
        #"_Revenue_Forecast_OOC"
    }),
    #"Filtered Rows" = Table.SelectRows(Combined, each true)
in
    Combined
