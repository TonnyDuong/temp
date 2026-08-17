// =====================================================================
// Debug_Subcontractor_Actuals_2026  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Screenshot-only reconciliation for the 2026 subcontractor
//               actual variance between FinanceOutput FY26 and Power BI.
// Grain:        One diagnostic row per comparison check.
// Dependencies: stg_FinanceOutput FY26_FY2026, dim_Project_Live,
//               _NormalizeAccountCode, _CutoverDate
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// Screenshot targets:
//   2026 Excel reconciliation magnitude =  243,536.16
//   Expected raw Power BI sign           = -243,536.16
//   Current screenshot raw Power BI      = -217,651.21
//   Variance ignoring sign               =   25,884.95
// =====================================================================
let
    Source = #"stg_FinanceOutput FY26_FY2026",
    Expected2026RawAmount = -243536.16,

    AccountCodeAsText = Table.TransformColumns(Source,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    AddProjectCode = Table.AddColumn(AccountCodeAsText, "Debug Project Code", each
        let
            ProjectCodeRaw = try Text.From([#"Class: Class External ID"]) otherwise ""
        in
            Text.Trim(ProjectCodeRaw ?? ""),
        type text),

    AddProjectCodeNormalized = Table.AddColumn(AddProjectCode, "Debug Project Code Normalized", each
        Text.Upper([Debug Project Code]),
        type text),

    AddProjectExclusionStatus = Table.AddColumn(AddProjectCodeNormalized, "Debug Project Exclusion Status", each
        if [Debug Project Code Normalized] = "" then "Blank project/class"
        else if [Debug Project Code Normalized] = "(BLANK)" then "Blank project/class"
        else if [Debug Project Code Normalized] = "EMS-04" then "EMS-04"
        else "Included",
        type text),

    Rows2026 = Table.SelectRows(AddProjectExclusionStatus, each
        [#"Period End Date"] <> null
        and Date.Year([#"Period End Date"]) = 2026),

    Raw60201 = Table.SelectRows(Rows2026, each
        [#"Account No."] = "60201"),

    AfterProjectExclusions = Table.SelectRows(Raw60201, each
        [Debug Project Exclusion Status] = "Included"),

    RemovedByProjectExclusions = Table.SelectRows(Raw60201, each
        [Debug Project Exclusion Status] <> "Included"),

    RemovedByCutover = Table.SelectRows(AfterProjectExclusions, each
        [#"Period End Date"] > _CutoverDate),

    FinalAfterCutover = Table.SelectRows(AfterProjectExclusions, each
        [#"Period End Date"] <= _CutoverDate),

    ProjectDimensionKeys = Table.Distinct(
        Table.SelectColumns(
            Table.AddColumn(#"dim_Project_Live", "Debug Project Code Normalized", each
                let
                    ProjectCodeRaw = try Text.From([Project Code]) otherwise ""
                in
                    Text.Upper(Text.Trim(ProjectCodeRaw ?? "")),
                type text),
            {"Debug Project Code Normalized"}
        )
    ),

    UnmappedProjectRows = Table.NestedJoin(
        FinalAfterCutover, {"Debug Project Code Normalized"},
        ProjectDimensionKeys, {"Debug Project Code Normalized"},
        "ProjectMatch", JoinKind.LeftAnti
    ),

    SumAmount = (Rows as table) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, "Sum of Amount"))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    Diagnostics = #table(
        type table [
            Check = text,
            Rows = Int64.Type,
            Amount = number,
            #"Expected Raw Amount" = nullable number,
            #"Difference to Expected" = nullable number,
            Notes = text
        ],
        {
            {
                "2026 raw 60201 before exclusions",
                Table.RowCount(Raw60201),
                SumAmount(Raw60201),
                null,
                null,
                "All 2026 GL rows where normalized Account No. = 60201."
            },
            {
                "2026 after blank/EMS-04 exclusion before cutover",
                Table.RowCount(AfterProjectExclusions),
                SumAmount(AfterProjectExclusions),
                null,
                null,
                "Matches the project/class exclusion rule before _CutoverDate is applied."
            },
            {
                "2026 final after exclusions and cutover",
                Table.RowCount(FinalAfterCutover),
                SumAmount(FinalAfterCutover),
                Expected2026RawAmount,
                Number.Round(SumAmount(FinalAfterCutover) - Expected2026RawAmount, 2),
                "This should match the raw Power BI subcontractor actual after refresh."
            },
            {
                "2026 rows removed by blank/EMS-04 exclusion",
                Table.RowCount(RemovedByProjectExclusions),
                SumAmount(RemovedByProjectExclusions),
                null,
                null,
                "Rows excluded before Class External ID is renamed to Project Code."
            },
            {
                "2026 rows removed by cutover",
                Table.RowCount(RemovedByCutover),
                SumAmount(RemovedByCutover),
                null,
                null,
                "If this amount explains the variance, the report is showing cutover-limited actuals."
            },
            {
                "2026 final rows unmapped to dim_Project_Live",
                Table.RowCount(UnmappedProjectRows),
                SumAmount(UnmappedProjectRows),
                null,
                null,
                "Rows here can appear in raw helper totals but drop from sector/contract/project visuals."
            }
        }
    )
in
    Diagnostics
