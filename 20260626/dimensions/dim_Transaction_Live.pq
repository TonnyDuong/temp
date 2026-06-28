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
// identifier for transaction lines. Concatenate [Transaction: Transaction
// ID] and [Transaction Line ID] to produce one (e.g. "770163-0", "770163-1").
//
// Project Code (corrected): the GL has no literal Project Code column; the
// project is the NetSuite Class. [Class: Class External ID] holds the code
// (e.g. "ASH-01") and [Class: Full Name] the description.
//
// Blank Location: Full Name rule (confirmed by Chris):
//   Subsidiary ending in ESS  →  "Italy"
//   Subsidiary ending in EMS / BWG / BWS  →  "UK"
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    Selected = Table.SelectColumns(Source, {
        "Transaction: Transaction ID",
        "Transaction Ref.",
        "Transaction Line ID",
        "Account No.",
        "Account Name",
        "Memo",
        "Class: Class ID",
        "Class: Class External ID",
        "Class: Full Name",
        "Customer: Full Name",
        "Vendor: Full Name",
        "Department: Department ID",
        "Department: Full Name",
        "Subsidiary: Full Name",
        "Location: Location ID",
        "Location: Full Name",
        "Employee: Employee External ID",
        "Employee: First Name",
        "Employee: Last Name"
    }),

    // Project Code = Class External ID (corrected); keep Class: Full Name as the name
    AddProjectCode = Table.RenameColumns(Selected, {{"Class: Class External ID", "Project Code"}}),

    // Step 1 — default blank Location: Full Name by subsidiary
    FilledLocation = Table.ReplaceValue(
        AddProjectCode,
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

    // Step 2 — unique key concat (Transaction ID + Transaction Line ID)
    AddKey = Table.AddColumn(FilledLocation, "TransactionLineKey",
        each Text.From([#"Transaction: Transaction ID"]) & "-" & Text.From([#"Transaction Line ID"]),
        type text),

    // Step 3 — dedupe on the key (one row per line)
    Deduped = Table.Distinct(AddKey, {"TransactionLineKey"})
in
    Deduped