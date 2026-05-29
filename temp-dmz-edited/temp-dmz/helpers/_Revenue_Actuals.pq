// =====================================================================
// _Revenue_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Revenue actuals from NetSuite GL, conformed to the
//               fact_Revenue_Live schema. Filtered to the four revenue
//               account codes only.
// Grain:        One row per NetSuite revenue line.
// Dependencies: stg_FinanceOutput FY26_FY2026
// Load:         DISABLED — right-click query → untick "Enable load"
// ---------------------------------------------------------------------
// Account codes included (confirmed by Chris):
//   40010, 40011, 40012  →  Contract Type = "In Contract"
//   40014                →  Contract Type = "Out of Contract"
//
// Blank Location: Full Name rule:
//   Subsidiary ends in "ESS"             →  "Italy"
//   Subsidiary ends in EMS/BWG/BWS or other → "UK"
//
// Unique transaction-line key: Transaction Line ID & "-" & Transaction Ref.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Step 1 — keep only revenue rows
    RevenueOnly = Table.SelectRows(Source, each
        List.Contains({"40010", "40011", "40012", "40014"}, Text.From([#"Account No."]))),

    // Step 2 — default blank Location: Full Name
    FilledLocation = Table.ReplaceValue(
        RevenueOnly,
        each [#"Location: Full Name"],
        each (
            if [#"Location: Full Name"] <> null and [#"Location: Full Name"] <> ""
                then [#"Location: Full Name"]
            else if Text.EndsWith([#"Subsidiary: Full Name"] ?? "", "ESS")
                then "Italy"
            else
                "UK"
        ),
        Replacer.ReplaceValue,
        {"Location: Full Name"}
    ),

    // Step 3 — Contract Type from Account Code
    AddContractType = Table.AddColumn(FilledLocation, "Contract Type",
        each if Text.From([#"Account No."]) = "40014" then "Out of Contract" else "In Contract",
        type text),

    // Step 4 — unique line key
    AddTLK = Table.AddColumn(AddContractType, "TransactionLineKey",
        each Text.From([#"Transaction Line ID"]) & "-" & Text.From([#"Transaction Ref."]),
        type text),

    // Step 5 — constants for the fact schema
    AddType = Table.AddColumn(AddTLK, "Type", each "Actual", type text),
    AddSnapshot = Table.AddColumn(AddType, "Snapshot Date", each null, type date),

    // Step 6 — final shape (matches fact_Revenue_Live schema)
    Renamed = Table.RenameColumns(AddSnapshot, {
        {"Period End Date",        "Date"},
        {"Account No.",            "Account Code"},
        {"Sum of Amount",          "Amount"},
        {"Subsidiary: Full Name",  "Subsidiary"}
        // TODO: confirm "Project Code" is the literal column name in source
    }),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Class: Class External ID", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"})
in
    Final
