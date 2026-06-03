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
//   EMS-PR*   →  Pipeline
//   EMS-IT*   →  Legacy
//   else      →  Other
// ---------------------------------------------------------------------
// TODO:
//   - Confirm the exact lookup column on crbb5_contractregister that
//     matches crbb5_project.crbb5_contract. Likely the contractregister
//     primary key GUID.
//   - Confirm column names for: BillingMethod, BillingStartDate,
//     BillingEndDate, ConcessionExpiry in crbb5_contractregister.
// =====================================================================
let
    Source = #"crbb5_project",

    // Step 1 — narrow to columns we'll use
    Selected = Table.SelectColumns(Source, {
        "crbb5_projectid",
        "crbb5_projectcode",
        "crbb5_projectname",
        "crbb5_contract",
        "crbb5_subsidiaryname"
    }),

    // Step 2 — merge contract register attributes via crbb5_contract GUID
    Merged = Table.NestedJoin(
        Selected, {"crbb5_contract"},
        #"crbb5_contractregister", {"crbb5_contractregisterid"},   // TODO: confirm correct key column name
        "ContractRegister_Lookup", JoinKind.LeftOuter
    ),
    Expanded = Table.ExpandTableColumn(Merged, "ContractRegister_Lookup",
        {"crbb5_supersectorchoice", "crbb5_supersectorchoicename", "crbb5_portfolio", "MSA Reference", "crbb5_projecttype",
         "BillingMethodName", "BillingStartDate", "BillingEndDate", "ConcessionExpiry"},
        {"Sector", "Sector Name", "Portfolio", "MSA Reference", "Project Type",
         "Billing Method", "Billing Start Date", "Billing End Date", "Concession Expiry"}
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
        else if Text.StartsWith([MSA Reference], "EMS-PR")  then "Pipeline"
        else if Text.StartsWith([MSA Reference], "EMS-IT")  then "Legacy"
        else "Other",
        type text),

    // Step 5 — rename subsidiary
    RenameSubsidiary = Table.RenameColumns(AddContractPhase, {{"crbb5_subsidiaryname", "Subsidiary"}})
in
    RenameSubsidiary
