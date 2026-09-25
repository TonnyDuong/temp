// =====================================================================
// dim_TargetProfitability_Live
// ---------------------------------------------------------------------
// Purpose:      Target gross margin per financial year, shown as text
//               below the YTD profitability table: Breakeven, Approved
//               budget and 20% EBITDA.
// Grain:        One row per (Year, Target).
// Dependencies: stg_TargetProfitability  (SharePoint Data folder,
//               client-maintained)
// Load:         enabled. No relationships: measures pick the row for the
//               selected Reporting Year.
// ---------------------------------------------------------------------
// Source layout: a title row, a "FY" row, then a header row whose first
// cell is "Gross margin required" and whose other cells are years
// (2024, 2025, 2026, ...), then one row per target with a percentage
// under each year. The header row is found by its label rather than a
// fixed row number, and year columns are any header that parses as a
// whole number, so a new year added to the right needs no change here.
//
// Target Order keeps the sheet's row order for sorting the visual.
// =====================================================================
let
    Source = #"stg_TargetProfitability",

    // Step 1 - drop everything above the "Gross margin required" header row
    HeaderIndex = List.PositionOf(
        List.Transform(Table.Column(Source, Table.ColumnNames(Source){0}),
            each Text.Lower(Text.Trim(Text.From(_ ?? "")))),
        "gross margin required"),
    FromHeader = Table.Skip(Source, HeaderIndex),
    Promoted = Table.PromoteHeaders(FromHeader, [PromoteAllScalars = true]),
    Renamed = Table.RenameColumns(Promoted, {{Table.ColumnNames(Promoted){0}, "Target"}}),

    // Step 2 - keep target rows and year columns only
    Targets = Table.SelectRows(Renamed, each Text.Trim(Text.From([Target] ?? "")) <> ""),
    YearColumns = List.Select(Table.ColumnNames(Targets), each
        (try Int64.From(Text.Trim(_)) otherwise null) <> null),
    WithOrder = Table.AddIndexColumn(
        Table.SelectColumns(Targets, {"Target"} & YearColumns),
        "Target Order", 1, 1, Int64.Type),

    // Step 3 - one row per year and target
    Unpivoted = Table.UnpivotOtherColumns(WithOrder,
        {"Target", "Target Order"}, "Year Text", "Value Raw"),
    WithYear = Table.AddColumn(Unpivoted, "Year",
        each Int64.From(Text.Trim([Year Text])), Int64.Type),
    WithValue = Table.AddColumn(WithYear, "Target Margin",
        each try Number.From([Value Raw]) otherwise null, type number),
    NonBlank = Table.SelectRows(WithValue, each [Target Margin] <> null),

    Final = Table.SelectColumns(Table.TransformColumns(NonBlank, {{"Target", Text.Trim, type text}}),
        {"Year", "Target", "Target Order", "Target Margin"})
in
    Final
