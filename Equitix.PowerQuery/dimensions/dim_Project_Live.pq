// =====================================================================
// dim_Project_Live
// ---------------------------------------------------------------------
// Purpose:      Project dimension — absorbs contract-level attributes so
//               the old dim_Contracts can be retired.
// Grain:        One row per project.
// Dependencies: crbb5_project, crbb5_contractregister
// Load:         enabled.
// ---------------------------------------------------------------------
// Contract Phase — REVISED (29 May meeting):
//   The MSA-prefix rule below is INFORMATIONAL ONLY. Chris confirmed that
//   `EMS-IT` AND `EMSI-IT` are both LEGACY numbering from when the
//   contract register was first set up (briefly used, then dropped). They
//   do NOT indicate Italian — country is determined by SUBSIDIARY:
//     ESS         → Italian
//     EMS / BWG / BWS → UK
//
//   The canonical source for whether to include a contract in the
//   profitability report is the contract's STATUS — only Live / Mobilised /
//   Live-Stage contracts are in scope. Pipeline contracts are excluded.
//   `crbb5_contractstatus` is expanded below for this purpose; Chris will
//   send the exact list of statuses to keep.
//
//   Legacy MSA-prefix derivation (kept for informational drill-through,
//   not for filtering the report):
//     EMS-MSA*  → "Live (MSA-prefix)"
//     EMSI-IT*  → "Live (legacy IT prefix, still active)"
//     EMS-PR*   → "Pipeline"
//     EMS-IT*   → "Legacy"
//     else      → "Other"
// ---------------------------------------------------------------------
// Display rules (confirmed by Chris, 27 May check-in):
//   Sector          = the sector NAME (Social Infrastructure, Renewables,
//                     ...), NOT the numeric choice ID. The numeric
//                     crbb5_supersectorchoice is just a table ID and is
//                     not surfaced. Source the *name* column instead.
//   Contract        = MSA Reference (used as the contract level in the
//                     report hierarchy).
//   Region          = contract-level region from crbb5_region, falling
//                     back to crbb5_region2 when the primary field is blank.
//   Project Display = "<Project Code> - <Project Name>" so report rows
//                     show the code and the full description together.
//   Report hierarchy (top -> bottom drill path) =
//                     Region -> Sector -> Contract -> Project Display
//                     This implements the requested roll-up
//                     Project -> Contract -> Sector -> Region.
// ---------------------------------------------------------------------
// Column sources (CONFIRMED against the crbb5_contractregister column list):
//   Join key       = crbb5_contractregister[crbb5_contractregisterid]  (confirmed).
//   Sector (name)  = crbb5_supersectorchoicename                        (confirmed).
//   Portfolio      = crbb5_portfolio                                    (confirmed).
//   MSA Reference  = crbb5_msareference                                 (confirmed).
//   Region         = crbb5_region with fallback to crbb5_region2
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
        {"crbb5_supersectorchoicename", "crbb5_portfolio", "crbb5_msareference", "crbb5_concessionexpiry", "crbb5_contractstatus", "crbb5_region", "crbb5_region2"},
        {"Sector", "Portfolio", "MSA Reference", "Concession Expiry", "Contract Status", "Primary Region", "Secondary Region"}
    ),

    // Step 2b — canonical Region. Use the primary region from the contract
    //           register when present; otherwise fall back to the secondary
    //           region field.
    AddRegion = Table.AddColumn(Expanded, "Region", each
        let
            PrimaryRegion = try Text.Trim(Text.From([Primary Region])) otherwise "",
            SecondaryRegion = try Text.Trim(Text.From([Secondary Region])) otherwise ""
        in
            if PrimaryRegion <> "" then PrimaryRegion
            else if SecondaryRegion <> "" then SecondaryRegion
            else null,
        type text),
    RemovedRegionHelpers = Table.RemoveColumns(AddRegion, {"Primary Region", "Secondary Region"}),

     // Step 2c — IsInScope flag. TRUE if the contract status is in Chris's
    //           confirmed list for the profitability report. From his
    //           02 Jun 2026 email: "Live, Mobilised and Terminated. These 3
    //           stages all indicate a Live (or previously Live) contract."
    //           Pipeline (and any other status) is excluded.
    AddIsInScope = Table.AddColumn(RemovedRegionHelpers, "IsInScope",        
        each List.Contains({"Live", "Mobilised", "Mobilized", "Terminated"}, [Contract Status] ?? ""),
        type logical),

    // Step 3 — default blank Portfolio
    FilledPortfolio = Table.ReplaceValue(
        AddIsInScope,
        each [Portfolio],
        each (if [Portfolio] = null or [Portfolio] = "" then "Unportfolioed" else [Portfolio]),
        Replacer.ReplaceValue,
        {"Portfolio"}
    ),

    // Step 4 — explicit Contract level for report hierarchies.
    AddContract = Table.AddColumn(FilledPortfolio, "Contract",
        each [MSA Reference],
        type text),

    // Step 5 — derive Contract Phase from MSA Reference prefix
    AddContractPhase = Table.AddColumn(AddContract, "Contract Phase", each
        if [MSA Reference] = null then "Other"
        else if Text.StartsWith([MSA Reference], "EMS-MSA") then "Live"
        else if Text.StartsWith([MSA Reference], "EMSI-IT") then "Live"      // live Italian / ESS — distinct from legacy EMS-IT
        else if Text.StartsWith([MSA Reference], "EMS-PR")  then "Pipeline"
        else if Text.StartsWith([MSA Reference], "EMS-IT")  then "Legacy"
        else "Other",
        type text),

    // Step 6 — merged "<Project Code> - <Project Name>" label for report rows
    AddProjectDisplay = Table.AddColumn(AddContractPhase, "Project Display",
        each Text.From([Project Code]) & " - " & Text.From([Project Name]),
        type text),
    #"Filtered Rows" = Table.SelectRows(AddProjectDisplay, each ([Sector] <> null))
in
    #"Filtered Rows"
