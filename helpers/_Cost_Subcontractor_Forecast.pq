// =====================================================================
// _Cost_Subcontractor_Forecast  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Subcontractor cost forecast.
// Grain:        One row per (Date, Project Code).
// Dependencies: TBD — pending file delivery from Chris.
// Load:         DISABLED.
// ---------------------------------------------------------------------
// STATUS: STUB. The subcontractor forecast file has been confirmed by
// Chris as a forthcoming SharePoint Excel file. He'll check whether the
// data is already broken down by project; if not, his team will reshape
// before sending. When delivered:
//   1. Add the file as a new source (e.g. stg_SubcontractorForecast).
//   2. Replace this stub's Source with that staging table.
//   3. Shape to the fact schema below.
// The stub returns an empty table so fact_Cost_Live still builds.
// =====================================================================
let
    Source = #table(
        type table [
            Date = date,
            #"Project Code" = text,
            TimeWorkReference = text,
            #"Account Code" = Int64.Type,
            Category = text,
            Type = text,
            #"Snapshot Date" = date,
            Amount = Currency.Type
        ],
        {}
    )
in
    Source
