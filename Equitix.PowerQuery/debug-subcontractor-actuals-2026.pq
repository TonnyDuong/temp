// =====================================================================
// Debug_Subcontractor_Actuals_2026  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Project-code grouping for the 2026 subcontractor actual
//               report path, plus staging-side checks for source/debug
//               comparison.
// Grain:        One diagnostic row per External ID / project code.
// Dependencies: _Cost_Subcontractor_Actuals, fact_Cost_Live,
//               stg_FinanceOutput FY26_FY2026, dim_Project_Live,
//               _NormalizeAccountCode, _CutoverDate
// Load:         ENABLE during diagnosis only; remove or disable afterward.
// ---------------------------------------------------------------------
// Use for trial comparison:
//   - Compare Excel grouped External ID / Amount against
//     `Helper Actual Amount` first.
//   - If the visual uses fact_Cost_Live, compare against
//     `Fact Cost Actual Amount`.
//   - Staging columns are included only to diagnose source/read-step drift.
// =====================================================================
let
    StagingSource = #"stg_FinanceOutput FY26_FY2026",
    HelperSource = #"_Cost_Subcontractor_Actuals",
    FactSource = #"fact_Cost_Live",

    NormalizeProject = (value as any) as text =>
        let
            ProjectCodeRaw = try Text.From(value) otherwise "",
            ProjectCode = Text.Upper(Text.Trim(ProjectCodeRaw ?? ""))
        in
            if ProjectCode = "" then "(BLANK)" else ProjectCode,

    SumColumn = (Rows as table, ColumnName as text) as number =>
        let
            Amounts = List.RemoveNulls(Table.Column(Rows, ColumnName))
        in
            if List.IsEmpty(Amounts) then 0 else Number.Round(List.Sum(Amounts), 2),

    GroupByProject = (
        Rows as table,
        ProjectColumn as text,
        AmountColumn as text,
        RowColumnName as text,
        AmountColumnName as text
    ) as table =>
        let
            HasDebugExternalID = List.Contains(Table.ColumnNames(Rows), "Debug External ID"),
            RowsWithoutDebugExternalID =
                if HasDebugExternalID and ProjectColumn <> "Debug External ID"
                then Table.RemoveColumns(Rows, {"Debug External ID"})
                else Rows,
            AddExternalID =
                if HasDebugExternalID and ProjectColumn = "Debug External ID"
                then RowsWithoutDebugExternalID
                else Table.AddColumn(
                    RowsWithoutDebugExternalID,
                    "Debug External ID",
                    each NormalizeProject(Record.Field(_, ProjectColumn)),
                    type text
                ),
            Grouped = Table.Group(
                AddExternalID,
                {"Debug External ID"},
                {
                    {RowColumnName, each Table.RowCount(_), Int64.Type},
                    {AmountColumnName, each SumColumn(_, AmountColumn), type number}
                }
            )
        in
            Grouped,

    HelperRows2026 = Table.SelectRows(HelperSource, each
        [Date] <> null
        and Date.Year([Date]) = 2026
    ),

    HelperGrouped = GroupByProject(
        HelperRows2026,
        "Project Code",
        "Amount",
        "Helper Actual Rows",
        "Helper Actual Amount"
    ),

    FactRows2026 = Table.SelectRows(FactSource, each
        [Date] <> null
        and Date.Year([Date]) = 2026
        and [Category] = "Subcontractor"
        and [Type] = "Actual"
    ),

    FactGrouped = GroupByProject(
        FactRows2026,
        "Project Code",
        "Amount",
        "Fact Cost Actual Rows",
        "Fact Cost Actual Amount"
    ),

    AccountCodeAsText = Table.TransformColumns(StagingSource,
        {{"Account No.", each #"_NormalizeAccountCode"(_), type nullable text}}),

    AddStagingExternalID = Table.AddColumn(
        AccountCodeAsText,
        "Debug External ID",
        each NormalizeProject([#"Class: Class External ID"]),
        type text
    ),

    StagingRows2026 = Table.SelectRows(AddStagingExternalID, each
        [#"Period End Date"] <> null
        and Date.Year([#"Period End Date"]) = 2026
    ),

    StagingRaw60201 = Table.SelectRows(StagingRows2026, each
        [#"Account No."] = "60201"
    ),

    StagingIncluded = Table.SelectRows(StagingRaw60201, each
        [Debug External ID] <> "(BLANK)"
        and [Debug External ID] <> "EMS-04"
    ),

    RemovedByProjectExclusions = Table.SelectRows(StagingRaw60201, each
        [Debug External ID] = "(BLANK)"
        or [Debug External ID] = "EMS-04"
    ),

    RemovedByCutover = Table.SelectRows(StagingIncluded, each
        [#"Period End Date"] > _CutoverDate
    ),

    StagingFinalAfterCutover = Table.SelectRows(StagingIncluded, each
        [#"Period End Date"] <= _CutoverDate
    ),

    ProjectDimensionKeys = Table.Distinct(
        Table.SelectColumns(
            Table.AddColumn(#"dim_Project_Live", "Debug External ID", each
                NormalizeProject([Project Code]),
                type text),
            {"Debug External ID"}
        )
    ),

    UnmappedProjectRows = Table.NestedJoin(
        StagingFinalAfterCutover, {"Debug External ID"},
        ProjectDimensionKeys, {"Debug External ID"},
        "ProjectMatch", JoinKind.LeftAnti
    ),

    StagingRawGrouped = GroupByProject(
        StagingRaw60201,
        "Debug External ID",
        "Sum of Amount",
        "Staging Raw 60201 Rows",
        "Staging Raw 60201 Amount"
    ),

    StagingFinalGrouped = GroupByProject(
        StagingFinalAfterCutover,
        "Debug External ID",
        "Sum of Amount",
        "Staging Final Rows",
        "Staging Final Amount"
    ),

    RemovedProjectGrouped = GroupByProject(
        RemovedByProjectExclusions,
        "Debug External ID",
        "Sum of Amount",
        "Removed Blank/EMS-04 Rows",
        "Removed Blank/EMS-04 Amount"
    ),

    RemovedCutoverGrouped = GroupByProject(
        RemovedByCutover,
        "Debug External ID",
        "Sum of Amount",
        "Removed Cutover Rows",
        "Removed Cutover Amount"
    ),

    UnmappedGrouped = GroupByProject(
        UnmappedProjectRows,
        "Debug External ID",
        "Sum of Amount",
        "Unmapped Rows",
        "Unmapped Amount"
    ),

    AllProjectCodes = Table.Distinct(Table.Combine({
        Table.SelectColumns(HelperGrouped, {"Debug External ID"}),
        Table.SelectColumns(FactGrouped, {"Debug External ID"}),
        Table.SelectColumns(StagingRawGrouped, {"Debug External ID"}),
        Table.SelectColumns(StagingFinalGrouped, {"Debug External ID"}),
        Table.SelectColumns(RemovedProjectGrouped, {"Debug External ID"}),
        Table.SelectColumns(RemovedCutoverGrouped, {"Debug External ID"}),
        Table.SelectColumns(UnmappedGrouped, {"Debug External ID"})
    })),

    JoinTables = List.Accumulate(
        {
            [Table = HelperGrouped, Columns = {"Helper Actual Rows", "Helper Actual Amount"}, Name = "Helper"],
            [Table = FactGrouped, Columns = {"Fact Cost Actual Rows", "Fact Cost Actual Amount"}, Name = "Fact"],
            [Table = StagingRawGrouped, Columns = {"Staging Raw 60201 Rows", "Staging Raw 60201 Amount"}, Name = "StagingRaw"],
            [Table = StagingFinalGrouped, Columns = {"Staging Final Rows", "Staging Final Amount"}, Name = "StagingFinal"],
            [Table = RemovedProjectGrouped, Columns = {"Removed Blank/EMS-04 Rows", "Removed Blank/EMS-04 Amount"}, Name = "RemovedProject"],
            [Table = RemovedCutoverGrouped, Columns = {"Removed Cutover Rows", "Removed Cutover Amount"}, Name = "RemovedCutover"],
            [Table = UnmappedGrouped, Columns = {"Unmapped Rows", "Unmapped Amount"}, Name = "Unmapped"]
        },
        AllProjectCodes,
        (State as table, Current as record) as table =>
            let
                Joined = Table.NestedJoin(
                    State, {"Debug External ID"},
                    Current[Table], {"Debug External ID"},
                    Current[Name], JoinKind.LeftOuter
                ),
                Expanded = Table.ExpandTableColumn(
                    Joined,
                    Current[Name],
                    Current[Columns],
                    Current[Columns]
                )
            in
                Expanded
    ),

    NumericColumns = {
        "Helper Actual Rows",
        "Helper Actual Amount",
        "Fact Cost Actual Rows",
        "Fact Cost Actual Amount",
        "Staging Raw 60201 Rows",
        "Staging Raw 60201 Amount",
        "Staging Final Rows",
        "Staging Final Amount",
        "Removed Blank/EMS-04 Rows",
        "Removed Blank/EMS-04 Amount",
        "Removed Cutover Rows",
        "Removed Cutover Amount",
        "Unmapped Rows",
        "Unmapped Amount"
    },

    FillNulls = Table.ReplaceValue(
        JoinTables,
        null,
        0,
        Replacer.ReplaceValue,
        NumericColumns
    ),

    AddHelperVsFactVariance = Table.AddColumn(
        FillNulls,
        "Helper Less Fact Amount",
        each Number.Round([Helper Actual Amount] - [Fact Cost Actual Amount], 2),
        type number
    ),

    AddHelperVsStagingVariance = Table.AddColumn(
        AddHelperVsFactVariance,
        "Helper Less Staging Final Amount",
        each Number.Round([Helper Actual Amount] - [Staging Final Amount], 2),
        type number
    ),

    RenamedExternalID = Table.RenameColumns(
        AddHelperVsStagingVariance,
        {{"Debug External ID", "External ID"}}
    ),

    Sorted = Table.Sort(
        RenamedExternalID,
        {
            {"Helper Actual Amount", Order.Ascending},
            {"Fact Cost Actual Amount", Order.Ascending},
            {"External ID", Order.Ascending}
        }
    )
in
    Sorted
