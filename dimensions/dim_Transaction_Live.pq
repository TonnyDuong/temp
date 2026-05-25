// =====================================================================
// dim_Transaction_Live
// ---------------------------------------------------------------------
// Purpose:      Transaction dimension with the unique line-key concat
//               baked in.
// Grain:        One row per NetSuite transaction line.
// Dependencies: stg_FinanceOutput FY26_FY2026
// Load:         enabled.
// ---------------------------------------------------------------------
// Unique key rule (confirmed by Chris): NetSuite has no native unique
// identifier for transaction lines. Concatenate Transaction Line ID
// and Transaction Ref. to produce one (e.g. "763933-0", "763933-1").
//
// Blank Location: Full Name rule (confirmed by Chris):
//   Subsidiary ending in ESS  →  "Italy"
//   Subsidiary ending in EMS / BWG / BWS  →  "UK"
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    Selected = Table.SelectColumns(Source, {
        "Transaction Ref.",
        "Transaction Line ID",
        "Account No.",
        "Memo",
        "Class: Class ID",
        "Class: Class External ID",
        "Customer: Full Name",
        "vendor Full Name",
        "Department: Department ID",
        "Department: Full Name",
        "Subsidiary: Full Name",
        "Location: Location ID",
        "Location: Full Name",
        "Employee: Employee External ID"
    }),

    // Step 1 — default blank Location: Full Name by subsidiary
    FilledLocation = Table.ReplaceValue(
        Selected,
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

    // Step 2 — unique key concat
    AddKey = Table.AddColumn(FilledLocation, "TransactionLineKey",
        each Text.From([#"Transaction Line ID"]) & "-" & Text.From([#"Transaction Ref."]),
        type text),

    // Step 3 — dedupe on the key (one row per line)
    Deduped = Table.Distinct(AddKey, {"TransactionLineKey"})
in
    Deduped
