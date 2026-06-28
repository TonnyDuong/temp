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
// Exclusions (CONFIRMED by Chris, 29 May meeting):
//   60201 / 60202 / 60203  → routed to _Cost_Subcontractor_Actuals.
//   607*  (any account starting 607) → temp staff / consultancy fees
//          whose workers ARE on timesheets. Including them here would
//          double-count, so they are dropped entirely.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",
    AccountCodeAsText = Table.TransformColumnTypes(Source, {{"Account No.", type text}}),

    // Step 1 — join account type so we can filter to Expense only
    MergedAccountType = Table.NestedJoin(
        AccountCodeAsText, {"Account No."},
        #"dim_Accounts_Live", {"Account Code"},
        "Account_Lookup", JoinKind.LeftOuter
    ),
    ExpandAccountType = Table.ExpandTableColumn(MergedAccountType, "Account_Lookup",
        {"Account Type"}, {"Account Type"}),

    // Step 2 — keep Expense rows that are NOT subcontractor (60201/02/03)
    //          and NOT temp-staff (any 607*xx code, already in timesheets)
    ExpensesOnly = Table.SelectRows(ExpandAccountType, each
        [Account Type] = "Expense"
        and not List.Contains({"60201", "60202", "60203"}, [#"Account No."])
        and not Text.StartsWith([#"Account No."] ?? "", "607")
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
         "Category", "Type", "Snapshot Date", "Amount"}),

    // Keep only months on or before the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] <= _CutoverDate)
in
    FilteredByCutover
