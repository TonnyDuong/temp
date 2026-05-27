// =====================================================================
// _Cost_Other_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Non-subcontractor expense actuals from NetSuite GL.
//               Captures everything booked to an Expense account that
//               is NOT subcontractor (60201/60203) and NOT the temp-staff
//               account (those staff book timesheets — double-count risk).
// Grain:        One row per NetSuite expense line.
// Dependencies: stg_FinanceOutput FY26_FY2026, dim_Accounts_Live
// Load:         DISABLED.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm the temp-staff account code (placeholder used here is
//     null — replace with actual code).
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Step 1 — join account type so we can filter to Expense only
    MergedAccountType = Table.NestedJoin(
        Source, {"Account No."},
        #"dim_Accounts_Live", {"Account Code"},
        "Account_Lookup", JoinKind.LeftOuter
    ),
    ExpandAccountType = Table.ExpandTableColumn(MergedAccountType, "Account_Lookup",
        {"Account Type"}, {"Account Type"}),

    // Step 2 — keep Expense rows that are NOT subcontractor and NOT temp-staff
    ExpensesOnly = Table.SelectRows(ExpandAccountType, each
        [Account Type] = "Expense"
        and not List.Contains({60201, 60203}, [#"Account No."])
        // TODO: add the temp-staff account code to this exclusion list:
        // and [#"Account No."] <> {{TEMP_STAFF_CODE}}
    ),

    FilledLocation = Table.ReplaceValue(
        ExpensesOnly,
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

    AddCategory = Table.AddColumn(FilledLocation, "Category", each "Other Cost", type text),
    AddType     = Table.AddColumn(AddCategory,    "Type",     each "Actual",     type text),
    AddSnapshot = Table.AddColumn(AddType,        "Snapshot Date", each null,    type date),
    AddTWR      = Table.AddColumn(AddSnapshot,    "TimeWorkReference", each null, type text),

    Renamed = Table.RenameColumns(AddTWR, {
        {"Period End Date",          "Date"},
        {"Account No.",              "Account Code"},
        {"Sum of Amount",            "Amount"},
        {"Class: Class External ID", "Project Code"}   // GL has no literal Project Code; Class External ID holds it
    }),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"})
in
    Final
