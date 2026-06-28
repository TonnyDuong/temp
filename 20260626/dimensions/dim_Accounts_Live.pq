// =====================================================================
// dim_Accounts_Live
// ---------------------------------------------------------------------
// Purpose:      Account dimension with Contract Type and Cost Category
//               classification columns.
// Grain:        One row per Account Code.
// Dependencies: stg_FinanceOutput FY26_CoA
// Load:         enabled.
// ---------------------------------------------------------------------
// Account code classifications:
//   Contract Type:
//     40010 / 40011 / 40012  ->  In Contract
//     40013 / 40014          ->  Out of Contract
//     40013 was confirmed by the 24 Jun 2026 YPS-04 OOC actuals extract.
//     40014 remains the Additional Services / OOC forecast code.
//
//   Cost Category:
//     60201 / 60202 / 60203  ->  Subcontractor
//     Accounts starting 607* ->  excluded from cost facts when sourced
//                                from GL because those workers are already
//                                counted through timesheets.
//     Other Expense accounts ->  Other Cost
//
// Account Code is kept as text here and in all fact helpers so Power BI
// relationships are type-consistent.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_CoA",

    // Step 1 - Nominal Code is the Account Code; keep as text.
    Renamed = Table.RenameColumns(Source, {{"Nominal Code", "Account Code"}}),
    AccountCodeAsText = Table.TransformColumnTypes(Renamed, {{"Account Code", type text}}),

    // Step 2 - Contract Type.
    AddContractType = Table.AddColumn(AccountCodeAsText, "Contract Type", each
        if List.Contains({"40010", "40011", "40012"}, [Account Code]) then "In Contract"
        else if List.Contains({"40013", "40014"}, [Account Code]) then "Out of Contract"
        else null,
        type text),

    // Step 3 - Cost Category.
    AddCostCategory = Table.AddColumn(AddContractType, "Cost Category", each
        if List.Contains({"60201", "60202", "60203"}, [Account Code]) then "Subcontractor"
        else if Text.StartsWith([Account Code] ?? "", "607") then "(exclude - on timesheets)"
        else if [Account Type] = "Expense" then "Other Cost"
        else if [Account Type] = "Income" then "(not a cost)"
        else if [Account Type] = "Other Income" then "(not a cost)"
        else null,
        type text)
in
    AddCostCategory
