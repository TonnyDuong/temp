// =====================================================================
// _Revenue_Forecast_31Dec2025  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      In-contract revenue forecast from the 31.12.2025
//               snapshot sheet, unpivoted from wide → long.
// Grain:        One row per (Project, Forecast Date).
// Dependencies: stg_EMS Fixed Fee Forecast_31Dec2025
// Load:         DISABLED — right-click query → untick "Enable load"
// ---------------------------------------------------------------------
// Column names (corrected from the latest data screenshots):
//   - Project code column is `Project` (e.g. "EEC-01"), NOT "Project Code".
//   - Subsidiary is `Subsidiary (Project) (Project)` (EMS / ESS).
//   - The wide forecast columns are date-named headers ("31/01/2026", ...).
//   - The remaining metadata columns (Item, Billing Method, Base/Current
//     fees, indexation fields, Billing Start/End Date, etc.) MUST all be
//     listed as anchors so they are NOT unpivoted. Note Billing Start Date /
//     Billing End Date / Index Uplift Date are real dates but are metadata,
//     so they belong in the anchor list, not the forecast-period columns.
// TODO:
//   - Verify the default Account Code 40010 is correct (in-contract operational).
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_31Dec2025",

    // Step 1 — all NON-forecast-period columns (anchors). Everything else
    //          (the date-named month columns) gets unpivoted.
    NonDateColumns = {
        "Item", "Project", "Project Name (Project) (Project)", "Billing Method",
        "Base annual fee", "Current Annual Fee", "Currency", "Billing frequency p.a.",
        "Index Uplift Date", "Index Month", "Index Day of Month",
        "Subsidiary (Project) (Project)", "Billing Start Date", "Billing End Date",
        "Billing Reference", "Index this month ?", "Base Index", "Current Index",
        "Inedxation Basis", "Exchange", "Monthly Fee"
    },

    // Step 2 — unpivot the wide date columns
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 3 — parse the "31/01/2026" column name into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.From([#"Forecast Date Text"]),
        type date),

    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    // Step 4 — surface Project Code and Subsidiary from the source names
    Renamed = Table.RenameColumns(Typed, {
        {"Project",                          "Project Code"},
        {"Subsidiary (Project) (Project)",   "Subsidiary"}
    }),

    // Step 5 — constants
    AddSnapshot       = Table.AddColumn(Renamed,         "Snapshot Date",      each #date(2025, 12, 31), type date),
    AddType           = Table.AddColumn(AddSnapshot,     "Type",               each "Forecast",          type text),
    AddContractType   = Table.AddColumn(AddType,         "Contract Type",      each "In Contract",       type text),
    AddAccountCode    = Table.AddColumn(AddContractType, "Account Code",       each 40010,               Int64.Type),    // TODO: confirm default
    AddTLK            = Table.AddColumn(AddAccountCode,  "TransactionLineKey", each null,                type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"}),

    // Keep only months after the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] > _CutoverDate)
in
    FilteredByCutover