// =====================================================================
// dim_Accounts_Live
// ---------------------------------------------------------------------
// Purpose:      Account dimension with Contract Type and Cost Category
//               classification columns.
// Grain:        One row per Account Code.
// Dependencies: stg_FinanceOutput FY26_CoA
// Load:         enabled.
// ---------------------------------------------------------------------
// Account code classifications (confirmed by Chris):
//   Contract Type:
//     40010 / 40011 / 40012  →  In Contract
//     40014                  →  Out of Contract
//
//   Cost Category:
//     60201 / 60203          →  Subcontractor
//     other Expense accounts →  Other Cost
//     Income accounts        →  (not a cost)
//
// "Staff" cost category does NOT appear here — it's stamped directly on
// timesheet-derived rows in fact_Cost_Live (which have no Account Code).
// ---------------------------------------------------------------------
// TYPE NOTE: the source `Nominal Code` is TEXT (the CoA screenshot shows
// the ABC icon). But fact_Revenue_Live and fact_Cost_Live carry
// `Account Code` as Int64 (NetSuite `Account No.` is numeric, and the
// forecast helpers set 40014 etc. as Int64). Power BI relationships are
// type-strict — if this dim's Account Code stays text the relationship
// dim_Accounts_Live[Account Code] → fact_*[Account Code] will not build.
// Step 2 below CASTS to Int64 so the relationship works and the rest of
// the comparisons can use unquoted integers.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_CoA",

    // Step 1 — Nominal Code IS the Account Code; rename for consistency.
    Renamed = Table.RenameColumns(Source, {{"Nominal Code", "Account Code"}}),

    // Step 2 — cast Account Code to Int64 to match the facts (see TYPE NOTE).
    //          If the cast errors on refresh, investigate the offending row
    //          in the CoA source — every Nominal Code is expected to be a
    //          5-digit integer (e.g. 10000, 40010, 60201).
    Typed = Table.TransformColumnTypes(Renamed, {{"Account Code", Int64.Type}}),

    // Step 3 — Contract Type
    AddContractType = Table.AddColumn(Typed, "Contract Type", each
        if [Account Code] = 40010 then "In Contract"
        else if [Account Code] = 40011 then "In Contract"
        else if [Account Code] = 40012 then "In Contract"
        else if [Account Code] = 40014 then "Out of Contract"
        else null,
        type text),

    // Step 4 — Cost Category
    AddCostCategory = Table.AddColumn(AddContractType, "Cost Category", each
        if [Account Code] = 60201 then "Subcontractor"
        else if [Account Code] = 60203 then "Subcontractor"
        else if [Account Type] = "Expense" then "Other Cost"
        else if [Account Type] = "Income"  then "(not a cost)"
        else null,
        type text)
in
    AddCostCategory
