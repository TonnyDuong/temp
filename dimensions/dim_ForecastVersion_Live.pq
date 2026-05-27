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
// crbb5_jedoxallocation is exposed by LOGICAL name: the version column is
// crbb5_version (not "Version"). Renamed to "Version" for the friendly dim.
let
    Source = #"crbb5_jedoxallocation",
    KeepVersion = Table.SelectColumns(Source, {"crbb5_version"}),
    Renamed = Table.RenameColumns(KeepVersion, {{"crbb5_version", "Version"}}),
    Deduped = Table.Distinct(Renamed)
in
    Deduped
