// =====================================================================
// _Revenue_Forecast_OOC  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Out-of-contract revenue forecast from Grant's standalone
//               file. Conformed to the fact_Revenue_Live schema.
// Grain:        One row per (Sector or Project, Forecast Date).
// Dependencies: TBD — pending file delivery from Grant.
// Load:         DISABLED.
// ---------------------------------------------------------------------
// STATUS: STUB. Grant's file has not been delivered yet (confirmed in
// post-Wednesday meeting). When delivered:
//   1. Add the file as a new source in Power BI (named e.g.
//      stg_OOC_RevenueForecast).
//   2. Replace this stub's Source with that staging table.
//   3. Apply whatever shaping is needed to reach the fact schema.
//   4. The stub returns an empty table of the correct shape, so
//      fact_Revenue_Live still builds in the meantime.
// =====================================================================
let
    // Empty table of the correct shape. Replace when file arrives.
    Source = #table(
        type table [
            Date = date,
            #"Project Code" = text,
            #"Account Code" = Int64.Type,
            Subsidiary = text,
            Type = text,
            #"Contract Type" = text,
            #"Snapshot Date" = date,
            Amount = Currency.Type,
            TransactionLineKey = text
        ],
        {}
    )
in
    Source
