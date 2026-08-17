// =====================================================================
// Debug_Subcontractor_Actuals_2026  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Screenshot-only reconciliation for the 2026 subcontractor
//               actual variance between FinanceOutput FY26 and Power BI.
// Grain:        One diagnostic row per External ID / project code.
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

    SumAmount = (Rows as table) as nullable number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, "Sum of Amount"))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    GroupByProject = (
        Rows as table,
        RowColumnName as text,
        AmountColumnName as text
    ) as table =>
        Table.Group(
            Rows,
            {"Debug Project Code Normalized"},
            {
                {RowColumnName, each Table.RowCount(_), Int64.Type},
                {AmountColumnName, each SumAmount(_), type number}
            }
        ),

    RawGrouped = GroupByProject(
        Raw60201,
        "Raw 60201 Rows",
        "Raw 60201 Amount"
    ),

    FinalGrouped = GroupByProject(
        FinalAfterCutover,
        "PQ Debug Rows",
        "PQ Debug Amount"
    ),

    RemovedProjectGrouped = GroupByProject(
        RemovedByProjectExclusions,
        "Removed Blank/EMS-04 Rows",
        "Removed Blank/EMS-04 Amount"
    ),

    RemovedCutoverGrouped = GroupByProject(
        RemovedByCutover,
        "Removed Cutover Rows",
        "Removed Cutover Amount"
    ),

    UnmappedGrouped = GroupByProject(
        UnmappedProjectRows,
        "Unmapped Rows",
        "Unmapped Amount"
    ),

    AllProjectCodes = Table.Distinct(Table.Combine({
        Table.SelectColumns(RawGrouped, {"Debug Project Code Normalized"}),
        Table.SelectColumns(FinalGrouped, {"Debug Project Code Normalized"}),
        Table.SelectColumns(RemovedProjectGrouped, {"Debug Project Code Normalized"}),
        Table.SelectColumns(RemovedCutoverGrouped, {"Debug Project Code Normalized"}),
        Table.SelectColumns(UnmappedGrouped, {"Debug Project Code Normalized"})
    })),

    JoinRaw = Table.NestedJoin(
        AllProjectCodes, {"Debug Project Code Normalized"},
        RawGrouped, {"Debug Project Code Normalized"},
        "Raw", JoinKind.LeftOuter
    ),
    ExpandRaw = Table.ExpandTableColumn(
        JoinRaw,
        "Raw",
        {"Raw 60201 Rows", "Raw 60201 Amount"},
        {"Raw 60201 Rows", "Raw 60201 Amount"}
    ),

    JoinFinal = Table.NestedJoin(
        ExpandRaw, {"Debug Project Code Normalized"},
        FinalGrouped, {"Debug Project Code Normalized"},
        "Final", JoinKind.LeftOuter
    ),
    ExpandFinal = Table.ExpandTableColumn(
        JoinFinal,
        "Final",
        {"PQ Debug Rows", "PQ Debug Amount"},
        {"PQ Debug Rows", "PQ Debug Amount"}
    ),

    JoinRemovedProject = Table.NestedJoin(
        ExpandFinal, {"Debug Project Code Normalized"},
        RemovedProjectGrouped, {"Debug Project Code Normalized"},
        "RemovedProject", JoinKind.LeftOuter
    ),
    ExpandRemovedProject = Table.ExpandTableColumn(
        JoinRemovedProject,
        "RemovedProject",
        {"Removed Blank/EMS-04 Rows", "Removed Blank/EMS-04 Amount"},
        {"Removed Blank/EMS-04 Rows", "Removed Blank/EMS-04 Amount"}
    ),

    JoinRemovedCutover = Table.NestedJoin(
        ExpandRemovedProject, {"Debug Project Code Normalized"},
        RemovedCutoverGrouped, {"Debug Project Code Normalized"},
        "RemovedCutover", JoinKind.LeftOuter
    ),
    ExpandRemovedCutover = Table.ExpandTableColumn(
        JoinRemovedCutover,
        "RemovedCutover",
        {"Removed Cutover Rows", "Removed Cutover Amount"},
        {"Removed Cutover Rows", "Removed Cutover Amount"}
    ),

    JoinUnmapped = Table.NestedJoin(
        ExpandRemovedCutover, {"Debug Project Code Normalized"},
        UnmappedGrouped, {"Debug Project Code Normalized"},
        "Unmapped", JoinKind.LeftOuter
    ),
    ExpandUnmapped = Table.ExpandTableColumn(
        JoinUnmapped,
        "Unmapped",
        {"Unmapped Rows", "Unmapped Amount"},
        {"Unmapped Rows", "Unmapped Amount"}
    ),

    FillNulls = Table.ReplaceValue(
        ExpandUnmapped,
        null,
        0,
        Replacer.ReplaceValue,
        {
            "Raw 60201 Rows",
            "Raw 60201 Amount",
            "PQ Debug Rows",
            "PQ Debug Amount",
            "Removed Blank/EMS-04 Rows",
            "Removed Blank/EMS-04 Amount",
            "Removed Cutover Rows",
            "Removed Cutover Amount",
            "Unmapped Rows",
            "Unmapped Amount"
        }
    ),

    AddRawVsPQVariance = Table.AddColumn(
        FillNulls,
        "Raw Less PQ Debug Amount",
        each Number.Round([Raw 60201 Amount] - [PQ Debug Amount], 2),
        type number
    ),

    Renamed = Table.RenameColumns(
        AddRawVsPQVariance,
        {{"Debug Project Code Normalized", "External ID"}}
    ),

    Sorted = Table.Sort(
        Renamed,
        {
            {"Raw Less PQ Debug Amount", Order.Ascending},
            {"PQ Debug Amount", Order.Ascending},
            {"External ID", Order.Ascending}
        }
    )
in
    Sorted
