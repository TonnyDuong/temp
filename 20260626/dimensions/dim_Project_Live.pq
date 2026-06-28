// =====================================================================
// dim_Project_Live
// ---------------------------------------------------------------------
// Purpose:      Project dimension. Absorbs contract-level attributes so
//               the old dim_Contracts can be retired.
// Grain:        One row per project.
// Dependencies: crbb5_project, crbb5_contractregister
// Load:         enabled.
// ---------------------------------------------------------------------
// Current report hierarchy, agreed 24 Jun 2026:
//   Sector -> Contract -> Project Display
//
// Region is intentionally not surfaced in this sprint. The client asked
// to remove the Region split and revisit region filtering later.
//
// Display rules:
//   Sector          = crbb5_contractregister[crbb5_supersectorchoicename].
//   Contract        = crbb5_contractregister[crbb5_title], falling back to
//                     MSA Reference when the title is blank.
//   MSA Reference   = crbb5_contractregister[crbb5_msareference], retained
//                     as a separate audit/drill-through attribute.
//   Project Display = "<Project Code> - <Project Name>".
// =====================================================================
let
    Source = #"crbb5_project",

    // Step 1 - narrow to the project columns used by the report model.
    Selected = Table.SelectColumns(Source, {
        "crbb5_projectid",
        "crbb5_projectcode",
        "crbb5_projectname",
        "crbb5_projecttypename",
        "crbb5_contract",
        "crbb5_subsidiaryname"
    }),

    // Step 1b - friendly project names.
    RenamedProject = Table.RenameColumns(Selected, {
        {"crbb5_projectcode",     "Project Code"},
        {"crbb5_projectname",     "Project Name"},
        {"crbb5_projecttypename", "Project Type"},
        {"crbb5_subsidiaryname",  "Subsidiary"}
    }),

    // Step 2 - merge contract register attributes via crbb5_contract GUID.
    Merged = Table.NestedJoin(
        RenamedProject, {"crbb5_contract"},
        #"crbb5_contractregister", {"crbb5_contractregisterid"},
        "ContractRegister_Lookup", JoinKind.LeftOuter
    ),
    Expanded = Table.ExpandTableColumn(Merged, "ContractRegister_Lookup",
        {"crbb5_supersectorchoicename", "crbb5_portfolio", "crbb5_title", "crbb5_msareference", "crbb5_concessionexpiry", "crbb5_contractstatus"},
        {"Sector", "Portfolio", "Contract Title", "MSA Reference", "Concession Expiry", "Contract Status"}
    ),

    // Step 3 - IsInScope flag. Live / Mobilised / Terminated contracts are
    // in scope for the profitability report; pipeline and other statuses are not.
    AddIsInScope = Table.AddColumn(Expanded, "IsInScope",
        each List.Contains({"Live", "Mobilised", "Mobilized", "Terminated"}, [Contract Status] ?? ""),
        type logical),

    // Step 4 - default blank Portfolio for future use; not in the current hierarchy.
    FilledPortfolio = Table.ReplaceValue(
        AddIsInScope,
        each [Portfolio],
        each (if [Portfolio] = null or [Portfolio] = "" then "Unportfolioed" else [Portfolio]),
        Replacer.ReplaceValue,
        {"Portfolio"}
    ),

    // Step 5 - explicit Contract label for report hierarchies.
    AddContract = Table.AddColumn(FilledPortfolio, "Contract",
        each
            let
                ContractTitle = try Text.Trim(Text.From([Contract Title])) otherwise "",
                MSAReference = try Text.Trim(Text.From([MSA Reference])) otherwise ""
            in
                if ContractTitle <> "" then ContractTitle else MSAReference,
        type text),

    // Step 6 - derive Contract Phase from MSA Reference prefix.
    AddContractPhase = Table.AddColumn(AddContract, "Contract Phase", each
        if [MSA Reference] = null then "Other"
        else if Text.StartsWith([MSA Reference], "EMS-MSA") then "Live"
        else if Text.StartsWith([MSA Reference], "EMSI-IT") then "Live"
        else if Text.StartsWith([MSA Reference], "EMS-PR") then "Pipeline"
        else if Text.StartsWith([MSA Reference], "EMS-IT") then "Legacy"
        else "Other",
        type text),

    // Step 7 - merged "<Project Code> - <Project Name>" label for report rows.
    AddProjectDisplay = Table.AddColumn(AddContractPhase, "Project Display",
        each Text.From([Project Code]) & " - " & Text.From([Project Name]),
        type text),

    FilteredRows = Table.SelectRows(AddProjectDisplay, each [Sector] <> null)
in
    FilteredRows
