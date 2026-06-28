// =====================================================================
// dim_Accounts_Live
// ---------------------------------------------------------------------
// Purpose:      Account dimension with Contract Type and Cost Category
//               classification columns.
// Grain:        One row per Account Code.
// Dependencies: stg_FinanceOutput FY26_CoA
// Load:         enabled.
// ---------------------------------------------------------------------
// Account code classifications (CONFIRMED by Chris, 29 May meeting):
//   Contract Type:
//     40010 / 40011 / 40012  →  In Contract
//     40013 / 40014          →  Out of Contract
//     40013 added from the 24 Jun 2026 YPS-04 OOC actuals extract.
//     (HARP currently posts to 40011 Construction; switches to 40010
//      Operational after its 9-year construction phase ends.)
//
//   Cost Category:
//     60201 / 60202 / 60203          →  Subcontractor (consultancy / agency
//                                       costs NOT in BambooHR or timesheets).
//     Other Expense accounts          →  Other Cost.
//     Accounts starting 607*          →  EXCLUDED (temp staff / consultancy
//                                       fees who ARE in timesheets — including
//                                       them as cost would double-count).
//     Income accounts                 →  (not a cost).
//
// "Staff" cost category does NOT appear here — it's stamped directly on
// timesheet-derived rows in fact_Cost_Live (which have no Account Code).
// ---------------------------------------------------------------------
// TYPE NOTE: Account Code is kept as Int64 here and in fact helpers.
// This matches the active report model relationship type.
// =====================================================================
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
//     40013 / 40014          →  Out of Contract
//
//   Cost Category:
//     60201 / 60203          →  Subcontractor
//     other Expense accounts →  Other Cost
//     Income accounts        →  (not a cost)
//
// "Staff" cost category does NOT appear here — it's stamped directly on
// timesheet-derived rows in fact_Cost_Live (which have no Account Code).
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_CoA",

    // Step 1 — Nominal Code IS the Account Code; rename for consistency.
    Renamed = Table.RenameColumns(Source, {{"Nominal Code", "Account Code"}}),

    AccountCodeAsInt = Table.TransformColumns(Renamed, {{"Account Code", each
        let
            TextValue = try Text.Trim(Text.From(_)) otherwise null,
            NumericValue = try Number.From(_) otherwise null,
            Digits = if TextValue = null then null else Text.Select(TextValue, {"0".."9"})
        in
            if TextValue = null or TextValue = "" then null
            else if NumericValue is number then Int64.From(NumericValue)
            else if Digits = null or Digits = "" then null
            else Int64.From(Text.Start(Digits, 5)),
        Int64.Type}}),

    // Step 2 — Contract Type
    AddContractType = Table.AddColumn(AccountCodeAsInt, "Contract Type", each
        if [Account Code] = 40010 then "In Contract"
        else if [Account Code] = 40011 then "In Contract"
        else if [Account Code] = 40012 then "In Contract"
        else if [Account Code] = 40013 then "Out of Contract"
        else if [Account Code] = 40014 then "Out of Contract"
        else null,
        type text),

    // Step 3 — Cost Category
    AddCostCategory = Table.AddColumn(AddContractType, "Cost Category", each
     if List.Contains({60201, 60202, 60203}, [Account Code])  then "Subcontractor"
     else if Text.StartsWith(Text.From([Account Code] ?? ""), "607") then "(exclude -- on timesheets"
        
        else if [Account Type] = "Expense" then "Other Cost"
        else if [Account Type] = "Income"  then "(not a cost)"
        else if [Account Type] = "Other Income" then "(not a cost)"
        else null,
        type text),

    // Enforce the documented grain: one row per Account Code for relationship keys.
    Deduplicated = Table.Distinct(AddCostCategory, {"Account Code"})
in
    Deduplicated
