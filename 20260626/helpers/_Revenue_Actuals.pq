// =====================================================================
// _Revenue_Actuals  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:      Revenue actuals from NetSuite GL, conformed to the
//               fact_Revenue_Live schema. Filtered to the revenue
//               account codes only.
// Grain:        One row per NetSuite revenue line.
// Dependencies: stg_FinanceOutput FY26_FY2026
// Load:         DISABLED — right-click query → untick "Enable load"
// ---------------------------------------------------------------------
// Account codes included (confirmed by Chris):
//   40010, 40011, 40012  →  Contract Type = "In Contract"
//   40013, 40014         →  Contract Type = "Out of Contract"
//   40013 is included because the 24 Jun 2026 YPS-04 extract showed
//   OOC actual rows posted to this account.
//
// Blank Location: Full Name rule:
//   Subsidiary ends in "ESS"             →  "Italy"
//   Subsidiary ends in EMS/BWG/BWS or other → "UK"
//
// Unique transaction-line key (corrected): [Transaction: Transaction ID]
//   & "-" & [Transaction Line ID]  →  e.g. "770163-0", "770163-1".
//
// Project Code source (corrected): the FY2026 GL has NO literal Project
//   Code column. The project is the NetSuite Class; the code lives in
//   [Class: Class External ID] (e.g. "ASH-01"). Renamed below.
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",
    ToAccountCode = (value as any) as nullable number =>
        let
            NumericValue = try Number.From(value) otherwise null,
            TextValue = try Text.Trim(Text.From(value)) otherwise null,
            Characters = if TextValue = null then {} else Text.ToList(TextValue),
            DigitOrSpace = List.Transform(Characters, each if List.Contains({"0".."9"}, _) then _ else " "),
            Tokens = List.Select(Text.Split(Text.Combine(DigitOrSpace), " "), each Text.Length(_) >= 5),
            Candidate =
                if NumericValue is number then Text.From(Int64.From(NumericValue))
                else if List.Count(Tokens) = 0 then null
                else Text.Start(List.Last(Tokens), 5)
        in
            if Candidate = null then null else Int64.From(Candidate),

    // Normalize to the five-digit Int64 key before filtering.
    AccountCodeAsInt = Table.TransformColumns(Source, {{"Account No.", each ToAccountCode(_), Int64.Type}}),

    // Step 1 — keep only revenue rows
    RevenueOnly = Table.SelectRows(AccountCodeAsInt, each
        List.Contains({40010, 40011, 40012, 40013, 40014}, [#"Account No."])),

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
        each if List.Contains({40013, 40014}, [#"Account No."]) then "Out of Contract" else "In Contract",
        type text),

    // Step 4 — unique line key (Transaction ID + Transaction Line ID)
    AddTLK = Table.AddColumn(AddContractType, "TransactionLineKey",
        each Text.From([#"Transaction: Transaction ID"]) & "-" & Text.From([#"Transaction Line ID"]),
        type text),

    // Step 5 — constants for the fact schema
    AddType = Table.AddColumn(AddTLK, "Type", each "Actual", type text),
    AddSnapshot = Table.AddColumn(AddType, "Snapshot Date", each null, type date),

    // Step 6 — final shape (matches fact_Revenue_Live schema)
    Renamed = Table.RenameColumns(AddSnapshot, {
        {"Period End Date",          "Date"},
        {"Account No.",              "Account Code"},
        {"Sum of Amount",            "Amount"},
        {"Subsidiary: Full Name",    "Subsidiary"},
        {"Class: Class External ID", "Project Code"}   // GL has no literal Project Code; Class External ID holds it
    }),

    Final = Table.SelectColumns(Renamed,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"}),

    // Keep only months on or before the cutover date
    FilteredByCutover = Table.SelectRows(Final,
        each [Date] <= _CutoverDate),
    #"Filtered Rows" = Table.SelectRows(FilteredByCutover, each true)
in
    #"FilteredByCutover"
