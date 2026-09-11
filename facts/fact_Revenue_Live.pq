// =====================================================================
// fact_Revenue_Live
// ---------------------------------------------------------------------
// Purpose:      Unified revenue fact — actuals + forecast,
//               in-contract + out-of-contract — in a single table.
// Grain:        One row per (Date, Project, Account, Type, Snapshot).
// Dependencies: _Revenue_Actuals, _Revenue_Forecast_31Dec2025,
//               _Revenue_Forecast_HARP, _Revenue_Forecast_OOC,
//               _Revenue_Adjustment_iXBRL
// Load:         enabled.
// ---------------------------------------------------------------------
// Each helper conforms to the same column shape, so a Table.Combine
// produces the final fact. Adding a new revenue source means:
//   1. Build a new helper query in helpers/ with the same column shape.
//   2. Reference it in the Table.Combine call below.
//
// Row types carried in [Type]: "Actual", "Forecast", and "Adjustment".
// "Adjustment" was added for the Additional Services iXBRL
// reclassification (Eve Dillon, 10 Sep 2026) and nets to zero overall
// while moving revenue between reporting lines.
// =====================================================================
let
    Combined = Table.Combine({
        #"_Revenue_Actuals",
        #"_Revenue_Forecast_31Dec2025",
        #"_Revenue_Forecast_HARP",
        #"_Revenue_Forecast_OOC",
        #"_Revenue_Adjustment_iXBRL"
    }),
    #"Filtered Rows" = Table.SelectRows(Combined, each true)
in
    Combined
