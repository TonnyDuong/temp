// =====================================================================
// dim_Employee_Live
// ---------------------------------------------------------------------
// Purpose:      Employee dimension. One row per current employee.
// Grain:        One row per employee.
// Dependencies: crbb5_bamboohr
// Load:         enabled.
// ---------------------------------------------------------------------
// crbb5_bamboohr is exposed by LOGICAL name (confirmed against its column
// list) — use crbb5_* identifiers, NOT display names.
// ---------------------------------------------------------------------
// TODO:
//   - Confirm the full set of valid employment-status values for IsActive.
//     Currently treats only "Active" as active.
//   - "EmployeeID" is mapped from crbb5_bamboohrid (a GUID). If the report
//     needs the EMPEM* employee-number style used by dim_StaffCosts /
//     stg_Staff Costs Summary, source it from crbb5_employee (or whichever
//     column holds the EMPEM* code) instead. Relationships use
//     TimeWorkReference, so this doesn't block the model — but the
//     EmployeeID display value will be a GUID until changed.
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
        {"crbb5_bamboohrid",         "EmployeeID"},
        {"crbb5_firstnamelastname",  "EmployeeName"},
        {"crbb5_timeworkreference",  "TimeWorkReference"},
        {"crbb5_managerbackupname",  "Manager"}
    }),

    AddIsActive = Table.AddColumn(Renamed, "IsActive",
        each [crbb5_employmentstatus] = "Active",
        type logical)
in
    AddIsActive
