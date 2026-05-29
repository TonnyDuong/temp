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
        "crbb5_bamboohrid",
        "crbb5_firstnamelastname",
        "crbb5_timeworkreference",
        "crbb5_country",
        "crbb5_department",
        "crbb5_employmentstatus",
        "crbb5_hiredate",
        "crbb5_terminationdate",
        "crbb5_jobtitle",
        "crbb5_managerbackupname",
        "crbb5_budgetholder"
    }),

    Renamed = Table.RenameColumns(Selected, {
        {"crbb5_bamboohrid",              "EmployeeID"},
        {"crbb5_firstnamelastname",  "EmployeeName"},
        {"crbb5_timeworkreference",   "TimeWorkReference"},
        {"crbb5_managerbackupname",        "Manager"}
    }),

    AddIsActive = Table.AddColumn(Renamed, "IsActive",
        each [crbb5_employmentstatus] = "Active",
        type logical)
in
    AddIsActive
