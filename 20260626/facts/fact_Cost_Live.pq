// =====================================================================
// fact_Cost_Live
// ---------------------------------------------------------------------
// Purpose:      Unified cost fact — actuals + forecast, across staff,
//               subcontractor and other categories — in a single table.
// Grain:        One row per (Date, Project, Employee, Account, Category,
//               Type, Snapshot).
// Dependencies: _Cost_Subcontractor_Actuals, _Cost_Other_Actuals,
//               _Cost_Staff_Actuals, _Cost_Staff_Forecast,
//               _Cost_Subcontractor_Forecast
// Load:         enabled.
// ---------------------------------------------------------------------
// Each helper conforms to the same column shape. Adding a new cost
// source means:
//   1. Build a new helper query in helpers/ with the same column shape.
//   2. Reference it in the Table.Combine call below.
// =====================================================================
let
    Combined = Table.Combine({
        #"_Cost_Subcontractor_Actuals",
        #"_Cost_Other_Actuals",
        #"_Cost_Staff_Actuals",
        #"_Cost_Staff_Forecast",
        #"_Cost_Subcontractor_Forecast"
    }),
    #"Changed Type" = Table.TransformColumnTypes(Combined,{{"Date", type date}})
in
    #"Changed Type"
