// =====================================================================
// _Revenue_Forecast_31Dec2025  (helper - load disabled)
// ---------------------------------------------------------------------
// Purpose:      In-contract revenue forecast from the Contracts sheet,
//               unpivoted from wide to long. This replaces the old
//               31.12.2025 snapshot source so forecast rows use the
//               indexed monthly contract values from EMS Forecast Fee.
// Grain:        One row per (Project, Forecast Date).
// Dependencies: stg_EMS Fixed Fee Forecast_Contracts1
// Load:         DISABLED - right-click query -> untick "Enable load"
// ---------------------------------------------------------------------
// Column names (corrected from the latest data screenshots):
//   - Project code column is `Project Code`; `Project` is the description.
//   - Subsidiary is `Entity` (EMS / ESS / BWS etc.).
//   - The wide forecast columns are date-named headers ("31/01/2025", ...).
//   - Metadata columns, including billing dates, current fees, exchange and
//     GBP Value, must be anchored so only forecast-period columns unpivot.
// TODO:
//   - Verify the default Account Code 40010 is correct (in-contract operational).
// =====================================================================
let
    Source = #"stg_EMS Fixed Fee Forecast_Contracts1",

    // Step 0 - drop helper/trailing columns if present (safe if absent)
    JunkColumns = List.Select(Table.ColumnNames(Source),
        each Text.StartsWith(_, "Column") or _ = "BLANK"),
    Cleaned = Table.RemoveColumns(Source, JunkColumns, MissingField.Ignore),

    // Step 1 - all NON-forecast-period columns (anchors). Everything else
    //          (the date-named month columns) gets unpivoted.
    DeclaredNonDateColumns = {
        "MSA Reference", "Project Code", "Billing Schedule item", "Billing Schedule Item",
        "crbb5_billingmethod", "crbb5_billingmethodname",
        "crbb5_billingstartdate", "crbb5_billingenddate",
        "crbb5_baseannualfee", "crbb5_basecurrency", "crbb5_basecurrencyname",
        "crbb5_indexmonth", "crbb5_currentannualfee",
        "Entity", "Project", "Project Type", "Monthly Fee",
        "Supersector", "SuperSector", "Concession expiry", "Concession Expiry",
        "Exchange", "GBP Value"
    },
    NonDateColumns = List.Intersect({Table.ColumnNames(Cleaned), DeclaredNonDateColumns}),

    // Step 2 - unpivot the wide date columns
    Unpivoted = Table.UnpivotOtherColumns(Cleaned, NonDateColumns, "Forecast Date Text", "Amount"),

    // Step 3 - parse the "31/01/2025" column name into a real Date
    ParsedDate = Table.AddColumn(Unpivoted, "Date",
        each
            let
                RawDate = [#"Forecast Date Text"]
            in
                try Date.From(RawDate) otherwise (try Date.FromText(Text.From(RawDate), [Culture = "en-GB"]) otherwise null),
        type nullable date),

    DateRows = Table.SelectRows(ParsedDate, each [Date] <> null),

    Typed = Table.TransformColumns(DateRows,
        {{"Amount", each try Currency.From(_) otherwise null, Currency.Type}}),

    // Step 4 - surface Subsidiary from Entity
    AddSubsidiary = Table.AddColumn(Typed, "Subsidiary", each [Entity], type text),

    // Step 5 - constants
    AddSnapshot       = Table.AddColumn(AddSubsidiary,   "Snapshot Date",      each #date(2025, 12, 31), type date),
    AddType           = Table.AddColumn(AddSnapshot,     "Type",               each "Forecast",          type text),
    AddContractType   = Table.AddColumn(AddType,         "Contract Type",      each "In Contract",       type text),
    AddAccountCode    = Table.AddColumn(AddContractType, "Account Code",       each "40010",             type text),    // Text key matches dim_Accounts_Live; TODO: confirm default.
    AddTLK            = Table.AddColumn(AddAccountCode,  "TransactionLineKey", each null,                type text),

    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"}),

    // Keep only months after the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] > _CutoverDate
            and [Project Code] <> null
            and Text.Trim(Text.From([Project Code])) <> ""
            and [Amount] <> null)
in
    FilteredByCutover
