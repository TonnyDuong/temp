// =====================================================================
// dim_ForecastVersion_Live
// ---------------------------------------------------------------------
// Purpose:      Lookup table for distinct Jedox forecast versions
//               (e.g. "Forecast", "Actual"). Joined to forecast rows in
//               fact_Cost_Live.
// Grain:        One row per Version value.
// Dependencies: crbb5_jedoxallocation
// Load:         enabled.
// =====================================================================
let
    Source = #"crbb5_jedoxallocation",
    KeepVersion = Table.SelectColumns(Source, {"crbb5_version"}),
    Deduped = Table.Distinct(KeepVersion)
in
    Deduped
