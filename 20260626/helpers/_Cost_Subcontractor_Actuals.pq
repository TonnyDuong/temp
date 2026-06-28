// =====================================================================
// _Cost_Subcontractor_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Subcontractor cost actuals from NetSuite GL.
// Grain:        One row per NetSuite expense line where Account Code in
//               {60201, 60203}.
// Dependencies: stg_FinanceOutput FY26_FY2026
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Account codes (CONFIRMED by Chris, 29 May meeting):
//   60201, 60202, 60203  →  Subcontractor (consultancy/agency, not on
//                            BambooHR or timesheets).
//   607*                 →  EXCLUDED (handled in _Cost_Other_Actuals — these
//                            workers ARE on timesheets, so the cost is
//                            already counted via fact_Timesheet).
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",

    // Normalize to the five-digit text key before filtering; subcontractor codes are compared as text.
    AccountCodeAsText = Table.TransformColumns(Source, {{"Account No.", each
        let
            TextValue = try Text.Trim(Text.From(_)) otherwise null,
            NumericValue = try Number.From(_) otherwise null,
            Digits = if TextValue = null then null else Text.Select(TextValue, {"0".."9"})
        in
            if TextValue = null or TextValue = "" then null
            else if NumericValue is number then Text.From(Int64.From(NumericValue))
            else if Digits = null or Digits = "" then null
            else Text.Start(Digits, 5),
        type text}}),

    SubcontractorOnly = Table.SelectRows(AccountCodeAsText, each
        List.Contains({"60201", "60202", "60203"}, [#"Account No."])),

    FilledLocation = Table.ReplaceValue(
        SubcontractorOnly,
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

    AddCategory = Table.AddColumn(FilledLocation, "Category", each "Subcontractor", type text),
    AddType     = Table.AddColumn(AddCategory,    "Type",     each "Actual",        type text),
    AddSnapshot = Table.AddColumn(AddType,        "Snapshot Date", each null,       type date),
    AddTWR      = Table.AddColumn(AddSnapshot,    "TimeWorkReference", each null,   type text),

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
