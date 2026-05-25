// =====================================================================
// dim_Employee_Live
// ---------------------------------------------------------------------
// Purpose:      Employee dimension. One row per current employee.
// Grain:        One row per employee.
// Dependencies: crbb5_bamboohr
// Load:         enabled.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm the full set of valid "Employment Status" values for the
//     IsActive flag. Currently treats only "Active" as active.
// =====================================================================
let
    Source = #"crbb5_bamboohr",

    Selected = Table.SelectColumns(Source, {
        "BambooHR",
        "First Name Last Name",
        "Time@work Reference",
        "Country",
        "Department",
        "Employment Status",
        "Hire Date",
        "Termination Date",
        "Job Title",
        "Manager Backup",
        "Budget Holder"
    }),

    Renamed = Table.RenameColumns(Selected, {
        {"BambooHR",              "EmployeeID"},
        {"First Name Last Name",  "EmployeeName"},
        {"Time@work Reference",   "TimeWorkReference"},
        {"Manager Backup",        "Manager"}
    }),

    AddIsActive = Table.AddColumn(Renamed, "IsActive",
        each [Employment Status] = "Active",
        type logical)
in
    AddIsActive
