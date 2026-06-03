// =====================================================================
// _Revenue_Forecast_31Dec2025  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      In-contract revenue forecast from the 31.12.2025
//               snapshot sheet, unpivoted from wide → long.
// Grain:        One row per (Project, Forecast Date).
// Dependencies: stg_EMS Fixed Fee Forecast_31Dec2025
// Load:         DISABLED — right-click query → untick "Enable load"
// ---------------------------------------------------------------------
// TODO:
//   - Verify the non-date columns list (currently {"Project Code"}).
//     Anything NOT listed will be treated as a date column and unpivoted.
//   - Verify the default Account Code 40010 is correct, or whether the
//     source sheet specifies its own.
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_31Dec2025",

    // Step 1 — define which columns are dimensions (not values to unpivot)
    NonDateColumns = {"Project", "Item", "Project Name (Project) (Project)", "Billing Method", "Currency", "Billing frequency p.a.", "Index Uplift Date", "Index Month", "Subsidiary (Project) (Project)", "Billing Reference", "Index this month ?", "Base Index", "Current Index", "Inedxation Basis", "Exchange", "Monthly Fee", "Base annual fee", "Current Annual Fee", "Index Day of Month", "Billing Start Date", "Billing End Date"},  

    // Step 2 — unpivot the wide date columns
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 3 — parse the "28/02/2026" column name into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.From([#"Forecast Date Text"]),
        type date),

    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    // Step 4 — constants
    AddSnapshot       = Table.AddColumn(Typed,           "Snapshot Date",      each #date(2025, 12, 31), type date),
    AddType           = Table.AddColumn(AddSnapshot,     "Type",               each "Forecast",          type text),
    AddContractType   = Table.AddColumn(AddType,         "Contract Type",      each "In Contract",       type text),
    AddAccountCode    = Table.AddColumn(AddContractType, "Account Code",       each 40010,               Int64.Type),    // TODO: confirm default
    AddSubsidiary     = Table.AddColumn(AddAccountCode,  "Subsidiary",         each null,                type text),
    AddTLK            = Table.AddColumn(AddSubsidiary,   "TransactionLineKey", each null,                type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"})
in
    Final
