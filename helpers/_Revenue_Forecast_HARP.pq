// =====================================================================
// _Revenue_Forecast_HARP  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      In-contract revenue forecast for the HARP project,
//               unpivoted from the wide HARP_DATA sheet.
// Grain:        One row per (Project, Forecast Date).
// Dependencies: stg_EMS Fixed Fee Forecast_Project HARP
// Load:         DISABLED.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm with Chris the HARP project's Project Code.
//   - Confirm the snapshot date for this file (currently assuming end of
//     last calendar year — may need to read from a metadata column).
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Project HARP",

    NonDateColumns = {"Project Code"},   // TODO: extend if HARP sheet carries other dim columns

    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),

    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.From([#"Forecast Date Text"]),
        type date),

    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    AddSnapshot       = Table.AddColumn(Typed,           "Snapshot Date",      each #date(2025, 12, 31), type date),  // TODO: confirm
    AddType           = Table.AddColumn(AddSnapshot,     "Type",               each "Forecast",          type text),
    AddContractType   = Table.AddColumn(AddType,         "Contract Type",      each "In Contract",       type text),
    AddAccountCode    = Table.AddColumn(AddContractType, "Account Code",       each 40010,               Int64.Type),
    AddSubsidiary     = Table.AddColumn(AddAccountCode,  "Subsidiary",         each null,                type text),
    AddTLK            = Table.AddColumn(AddSubsidiary,   "TransactionLineKey", each null,                type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"})
in
    Final
