// =====================================================================
// _Revenue_Forecast_HARP  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      In-contract revenue forecast for the HARP project,
//               unpivoted from the wide HARP_DATA sheet.
// Grain:        One row per (Project, Forecast Date).
// Dependencies: stg_EMS Fixed Fee Forecast_Project HARP
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Column names (corrected from the latest data screenshots):
//   - HARP is a SINGLE contract row: MSA `EMS-MSA289`, Project Code `HAP-03`,
//     Project (name) "HARP - Construction Phase delivery", Entity EMS,
//     Project Type "Construction", Supersector "Environmental Services".
//   - The project-code column is literally `Project Code` (HAP-03) here —
//     NOT `Project` (which is the name). This is the OPPOSITE of the
//     31.12.2025 sheet, so the two helpers anchor on different columns.
//   - Wide forecast columns run monthly from 31/01/2025 → 31/12/2035.
//   - The sheet carries junk trailing columns `Column154`, `Column155`
//     (and a `BLANK` column) that MUST be removed before unpivot, else
//     Date.From("Column154") errors.
// ---------------------------------------------------------------------
// TODO:
//   - Account Code: HARP is Construction-phase delivery (Project Type =
//     Construction) so the revenue is most likely account 40011
//     (Construction revenue), NOT 40010. Confirm with Chris; default set
//     to 40011 below.
//   - Confirm the snapshot date for this file (currently 2025-12-31).
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Project HARP",

    // Step 0 — drop junk trailing columns if present (safe if absent)
    JunkColumns = List.Select(Table.ColumnNames(Source),
        each Text.StartsWith(_, "Column") or _ = "BLANK"),
    Cleaned = Table.RemoveColumns(Source, JunkColumns, MissingField.Ignore),

    // Step 1 — all NON-forecast-period columns (anchors). Everything else
    //          (the date-named month columns) gets unpivoted.
    NonDateColumns = {
        "MSA Reference", "Project Code", "Billing Schedule item",
        "crbb5_billingmethod", "crbb5_billingmethodname",
        "crbb5_billingstartdate", "crbb5_billingenddate",
        "crbb5_baseannualfee", "crbb5_basecurrency", "crbb5_basecurrencyname",
        "crbb5_indexmonth", "crbb5_currentannualfee",
        "Entity", "Project", "Project Type", "Monthly Fee",
        "Supersector", "Concession expiry", "Exchange", "GBP Value"
    },

    // Step 2 — unpivot the wide date columns
    Unpivoted = Table.UnpivotOtherColumns(Cleaned, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 3 — parse the "31/01/2025" column name into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each Date.From([#"Forecast Date Text"]),
        type date),

    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    // Step 4 — surface Subsidiary from Entity (single HARP contract = EMS)
    AddSubsidiary = Table.AddColumn(Typed, "Subsidiary", each [Entity], type text),

    // Step 5 — constants
    AddSnapshot       = Table.AddColumn(AddSubsidiary,   "Snapshot Date",      each #date(2025, 12, 31), type date),  // TODO: confirm
    AddType           = Table.AddColumn(AddSnapshot,     "Type",               each "Forecast",          type text),
    AddContractType   = Table.AddColumn(AddType,         "Contract Type",      each "In Contract",       type text),
    AddAccountCode    = Table.AddColumn(AddContractType, "Account Code",       each 40011,               Int64.Type),  // Construction revenue — TODO confirm
    AddTLK            = Table.AddColumn(AddAccountCode,  "TransactionLineKey", each null,                type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"})
in
    Final
