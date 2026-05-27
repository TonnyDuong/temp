// =====================================================================
// dim_Project_Live
// ---------------------------------------------------------------------
// Purpose:      Project dimension — absorbs contract-level attributes so
//               the old dim_Contracts can be retired.
// Grain:        One row per project.
// Dependencies: crbb5_project, crbb5_contractregister
// Load:         enabled.
// ---------------------------------------------------------------------
// Contract Phase rule (derived from MSA Reference prefix):
//   EMS-MSA*  →  Live
//   EMSI-IT*  →  Live   (live Italian / ESS contracts — confirmed by data:
//                        active billing 2024→2040, current fees populated.
//                        NOTE distinct from legacy EMS-IT*.)
//   EMS-PR*   →  Pipeline
//   EMS-IT*   →  Legacy (old Italian numbering, no longer used)
//   else      →  Other
// ---------------------------------------------------------------------
// Display rules (confirmed by Chris, 27 May check-in):
//   Sector          = the sector NAME (Social Infrastructure, Renewables,
//                     ...), NOT the numeric choice ID. The numeric
//                     crbb5_supersectorchoice is just a table ID and is
//                     not surfaced. Source the *name* column instead.
//   Project Display = "<Project Code> - <Project Name>" so report rows
//                     show the code and the full description together.
// ---------------------------------------------------------------------
// Column sources (CONFIRMED against the crbb5_contractregister column list):
//   Join key       = crbb5_contractregister[crbb5_contractregisterid]  (confirmed).
//   Sector (name)  = crbb5_supersectorchoicename                        (confirmed).
//   Portfolio      = crbb5_portfolio                                    (confirmed).
//   MSA Reference  = crbb5_msareference                                 (confirmed).
//   Concession Exp = crbb5_concessionexpiry                             (confirmed).
//   Project Type   = crbb5_project[crbb5_projecttypename] (the text name,
//                     e.g. Operational / Construction — NOT the numeric
//                     crbb5_projecttype choice ID).
//   Billing Method / Start / End dates are NOT on crbb5_contractregister
//     (they live on crbb5_billingschedule). Dropped here; add a
//     crbb5_billingschedule join later only if the report needs them.
// ---------------------------------------------------------------------
// Column names (CONFIRMED against the crbb5_project column list): the
// entity is exposed by LOGICAL name (crbb5_projectcode, crbb5_projectname,
// crbb5_projecttypename, crbb5_subsidiaryname), not display names. Renamed
// to friendly names in Step 1b. (crbb5_project also carries its own
// `Project Display` column; we build ours explicitly to guarantee the
// "<code> - <name>" format Chris asked for on 27 May.)
// =====================================================================
let
    Source = #"crbb5_project",

    // Step 1 — narrow to the columns we'll use (logical names)
    Selected = Table.SelectColumns(Source, {
        "crbb5_projectid",
        "crbb5_projectcode",
        "crbb5_projectname",
        "crbb5_projecttypename",
        "crbb5_contract",
        "crbb5_subsidiaryname"
    }),

    // Step 1b — friendly names
    RenamedProject = Table.RenameColumns(Selected, {
        {"crbb5_projectcode",     "Project Code"},
        {"crbb5_projectname",     "Project Name"},
        {"crbb5_projecttypename", "Project Type"},
        {"crbb5_subsidiaryname",  "Subsidiary"}
    }),

    // Step 2 — merge contract register attributes via crbb5_contract GUID
    Merged = Table.NestedJoin(
        RenamedProject, {"crbb5_contract"},
        #"crbb5_contractregister", {"crbb5_contractregisterid"},   // confirmed key column
        "ContractRegister_Lookup", JoinKind.LeftOuter
    ),
    Expanded = Table.ExpandTableColumn(Merged, "ContractRegister_Lookup",
        {"crbb5_supersectorchoicename", "crbb5_portfolio", "crbb5_msareference", "crbb5_concessionexpiry"},
        {"Sector", "Portfolio", "MSA Reference", "Concession Expiry"}
    ),

    // Step 3 — default blank Portfolio
    FilledPortfolio = Table.ReplaceValue(
        Expanded,
        each [Portfolio],
        each (if [Portfolio] = null or [Portfolio] = "" then "Unportfolioed" else [Portfolio]),
        Replacer.ReplaceValue,
        {"Portfolio"}
    ),

    // Step 4 — derive Contract Phase from MSA Reference prefix
    AddContractPhase = Table.AddColumn(FilledPortfolio, "Contract Phase", each
        if [MSA Reference] = null then "Other"
        else if Text.StartsWith([MSA Reference], "EMS-MSA") then "Live"
        else if Text.StartsWith([MSA Reference], "EMSI-IT") then "Live"      // live Italian / ESS — distinct from legacy EMS-IT
        else if Text.StartsWith([MSA Reference], "EMS-PR")  then "Pipeline"
        else if Text.StartsWith([MSA Reference], "EMS-IT")  then "Legacy"
        else "Other",
        type text),

    // Step 5 — merged "<Project Code> - <Project Name>" label for report rows
    AddProjectDisplay = Table.AddColumn(AddContractPhase, "Project Display",
        each Text.From([Project Code]) & " - " & Text.From([Project Name]),
        type text)
in
    AddProjectDisplay
