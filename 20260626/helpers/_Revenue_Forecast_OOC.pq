// =====================================================================
// _Revenue_Forecast_OOC  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Out-of-contract revenue forecast from the client's
//               "Additional Services Forecast" file. Conformed to the
//               fact_Revenue_Live schema.
// Grain:        One row per (Project Code, Month).
// Dependencies: stg_AdditionalServicesForecast  (SharePoint Data folder)
// Load:         DISABLED.
// ---------------------------------------------------------------------
// File layout (CONFIRMED from the delivered file):
//   - WIDE monthly layout: the value columns are month-end dates
//     (1/31/2026 … 12/31/2026), one column per month.
//   - The header row is ROW 5 (rows 1-4 are a title + a note + blanks).
//     The stg_AdditionalServicesForecast staging query MUST skip those
//     rows and promote row 5 as headers before this helper runs.
//   - Metadata columns: Supersector, Sector, Upstream Reports,
//     Project Code, Department, Location.
//   - `Project Code` is the join key to dim_Project (JBL-02, D&G-03, …);
//     the file note confirms "Project code is chosen to allow modelling
//     to remain inline with the rest of the forecast model".
//   - additional services = Account Code 40014 = Out of Contract.
// ---------------------------------------------------------------------
// TODO:
//   - Month headers display as US M/d/yyyy. If they arrive as text in that
//     format, the explicit Culture below parses them; if the staging query
//     already types them as dates, replace the Date step with a direct type.
// =====================================================================
let
    Source = #"stg_AdditionalServicesForecast",

    // Step 1 — anchor on the metadata columns; unpivot the month columns
    NonDateColumns = {
        "Supersector", "Sector", "Upstream Reports", "Project Code", "Department", "Location"
    },
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 2 — parse the month-end header (US M/d/yyyy) into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.FromText([#"Forecast Date Text"], [Format="dd/MM/yyyy", Culture="en-US"]),
        type date),
    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    // Step 3 — map Subsidiary from Location, then constants for the fact schema
    AddSubsidiary   = Table.AddColumn(Typed,          "Subsidiary",    each [Location],        type text),
    AddAccountCode  = Table.AddColumn(AddSubsidiary,  "Account Code",  each 40014,             Int64.Type),
    AddType         = Table.AddColumn(AddAccountCode, "Type",          each "Forecast",        type text),
    AddContractType = Table.AddColumn(AddType,        "Contract Type", each "Out of Contract", type text),
    AddSnapshot     = Table.AddColumn(AddContractType,"Snapshot Date", each null,              type date),
    AddTLK          = Table.AddColumn(AddSnapshot,    "TransactionLineKey", each null,         type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"}),

    // Keep only months after the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] > _CutoverDate)
in
    FilteredByCutover
