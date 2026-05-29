// =====================================================================
// dim_ForecastSnapshot_Live
// ---------------------------------------------------------------------
// Purpose:      Lookup table for forecast snapshot dates. Joined to
//               fact_Revenue_Live and fact_Cost_Live for the "as-at"
//               filter on the forecast table.
// Grain:        One row per snapshot date.
// Dependencies: none (manually maintained).
// Load:         enabled.
// ---------------------------------------------------------------------
// Add a new row every time a new dated forecast snapshot arrives. The
// SnapshotDate must exactly match the date stamped on the corresponding
// rows in fact_Revenue_Live and fact_Cost_Live.
// =====================================================================
let
    SnapshotList = #table(
        type table [SnapshotDate = date, SnapshotName = text],
        {
            {#date(2025, 12, 31), "31Dec2025"}
            // Append more rows here as new snapshots are delivered, e.g.
            // ,{#date(2026, 3, 31), "31Mar2026"}
        }
    )
in
    SnapshotList
