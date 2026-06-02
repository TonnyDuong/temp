# Power BI Refactor Plan — Equitix Profitability Report

**Audience**: junior developer building / refactoring the `.pbix` model.
**Companion documents**:
- `Power BI Schema Audit - Equip Profitability Report.md` — full audit + business context. Refer to it for any business rule below that needs more background.
- `powerquery/` — the M scripts for every query in this plan, in source-controllable `.pq` files. See `powerquery/README.md` for how to use them (paste-in vs `.pbip` workflow).

This plan is sequenced so each phase only depends on the previous one. Pick tasks in order. Each task has a definition-of-done so you can self-verify before moving on.

## Naming convention — `_Live` suffix

**All new and refactored tables built in this plan get a `_Live` suffix** (e.g. `dim_Date_Live`, `fact_Revenue_Live`). This lets the new tables exist **side-by-side** with the current tables while you work, so the existing report keeps functioning.

How this plays out:

- When the plan says "create `dim_Date`", you create `dim_Date_Live`.
- When the plan says "refactor `dim_Project`", you leave `dim_Project` untouched and build a parallel `dim_Project_Live`.
- Existing `dim_Project`, `dim_Contracts`, `fact_Actuals`, etc. **stay in the model unchanged** until Phase 5 (verification) confirms the `_Live` versions are correct.
- At the very end (Phase 6, to be scheduled later), the old tables are deleted and the `_Live` suffix is dropped.

When you write Power Query M, name your queries with the `_Live` suffix from the start — that becomes the table name in the model.

Every code block, table reference, and definition-of-done in this plan uses the `_Live` name. Don't strip the suffix until the swap-over phase.

## Why we are refactoring

The current model has three structural problems that will produce wrong totals or break under load if we build measures on top:

1. **Star schema violations.** `dim_Contracts` holds 9 numeric measures (`BaseAnnualFee`, `Monthly Fee`, `ForecastAmmount`, etc.) — a real dimension holds attributes only. Three tables (`dim_Contracts`, `fact_Contracts`, `fact_ProjectHARP`) hold nearly identical contract-level data; measures built across them will fan out and multiply.
2. **Source tables exposed to visuals.** `stg_*`, `crbb5_*`, `dogma_*` are staging / source layers. They must be hidden, with everything the report consumes materialised into a `dim_*` / `fact_*` first. Staging schemas change without notice and break visuals silently.
3. **Missing essentials.** No `dim_Date`, wide-pivoted forecast files not unpivoted, no `Cost Category` to drive the cost-split chart, contractor → permanent EmployeeID duplicates not collapsed.

## Target model (end state)

The end state of this refactor is a clean star. Everything below `dim_*` / `fact_*` is hidden.

```
                       dim_Date_Live
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
fact_Revenue_Live    fact_Cost_Live    fact_Timesheet_Live
       │                    │                    │
       └─────────┬──────────┴──────────┬─────────┘
                 │                     │
         dim_Project_Live      dim_Accounts_Live
                 │                     │
         dim_Employee_Live     dim_Transaction_Live
                 │
         dim_StaffCosts_Live

(plus dim_ForecastSnapshot_Live and dim_ForecastVersion_Live
 joined to forecast rows in fact_Revenue_Live / fact_Cost_Live)
```

### Dimensions

| Table to build | Grain | Source | Status |
|---|---|---|---|
| `dim_Date_Live` | One row per day, 2024-01-01 → 2035-12-31 | Power Query | Build new |
| `dim_Project_Live` | One row per project | `crbb5_project` + attributes from `crbb5_contractregister` | Build new (existing `dim_Project` stays untouched) |
| `dim_Employee_Live` | One row per current employee | `crbb5_bamboohr` | Build new |
| `dim_StaffCosts_Live` | One row per (Employee, Year) rate | `stg_Staff Costs Summary` + `crbb5_bamboohr.Country` | Build new (existing `dim_StaffCosts` stays untouched) |
| `dim_Accounts_Live` | One row per Account Code | `stg_FinanceOutput FY26_CoA` | Build new (existing `dim_Accounts` stays untouched) |
| `dim_Transaction_Live` | One row per NetSuite transaction line | `stg_FinanceOutput FY26_FY2026` | Build new (existing `dim_Transaction` stays untouched) |
| `dim_ForecastSnapshot_Live` | One row per forecast snapshot date | derived during ingest | Build new |
| `dim_ForecastVersion_Live` | One row per Jedox version | `crbb5_jedoxallocation[Version]` distinct values | Build new |

### Facts

| Table to build | Grain | Source | Status |
|---|---|---|---|
| `fact_Revenue_Live` | One row per (Date, Project, Account, Type, Snapshot) | actuals from `stg_FinanceOutput FY26_FY2026`; in-contract forecast from `stg_EMS Fixed Fee Forecast_*`; OOC forecast from the Additional Services Forecast file (`stg_AdditionalServicesForecast`) | Build new |
| `fact_Cost_Live` | One row per (Date, Project, Employee, Account, Category, Type, Snapshot) | actuals from `stg_FinanceOutput FY26_FY2026`; staff actuals aggregated from `fact_Timesheet_Live`; staff forecast from `crbb5_jedoxallocation × dim_StaffCosts_Live`; subcontractor forecast from the Subcontractor Forecast file (`stg_SubcontractorForecast`) | Build new |
| `fact_Timesheet_Live` | One row per (Date, Employee, Project, Hours, Cost) | `dogma_timesheet` joined to `dim_Employee_Live` and `dim_StaffCosts_Live`, with country-aware hourly rate applied | Build new |

### Tables to retire after restructure

- `dim_Contracts` — attributes → `dim_Project`; measures → `fact_Revenue` / `fact_Cost`
- `fact_Actuals` — verbatim copy of `stg_EMS Fixed Fee Forecast_Actuals`. Replaced by `fact_Revenue[Type=Actual]`
- `fact_ProjectHARP` — schema-identical to `dim_Contracts`. HARP is just a project code filter on `fact_Revenue`
- `fact_Contracts` — duplicate `crbb5_*` columns. Replaced by `dim_Project` + `fact_Revenue`
- `fact_FinanceFY2026` — consider retiring once `fact_Revenue` and `fact_Cost` cover both YTD actuals and forecast

## Source map — what comes from where

The SharePoint side is **three workbooks**, not seven independent files. Knowing this matters when you wire up the Power Query connections (one workbook = one source query that can fan out to multiple sheets).

### SharePoint workbooks

| Workbook | Sheet | Feeds |
|---|---|---|
| `EMS Fixed Fee Forecast.xlsx` | `CONTRACTS` | `dim_Project` (contract attributes — MSA Reference, Project Code, Billing Schedule Item, Entity, Project Type, SuperSector) |
| | `ProjectHARP` | possibly `dim_Project` for HARP contract attributes (overlaps with `CONTRACTS`) |
| | `HARP_DATA` | `fact_Revenue` (forecast rows for the HARP project — wide / date-pivoted, needs unpivot) |
| | `Actuals` | `fact_Revenue[Type=Actual]` and/or `fact_Cost[Type=Actual]` (slim NetSuite extract) |
| | `31.12.2025` | `fact_Revenue[Type=Forecast, Snapshot=31Dec2025]` after unpivot |
| `FinanceOutput FY26.xlsx` | `CoA` | `dim_Accounts` |
| | `FY2026` | `fact_Revenue[Type=Actual]` (revenue lines, account codes 40010/11/12/14) **AND** `fact_Cost[Type=Actual]` (all expense lines including 60201/60203 for subcontractor) |
| `Staff Costs Summary.xlsx` | `Employee Info (Sheet1)` | `dim_StaffCosts` |

### Dataverse sources

| Source table | Feeds |
|---|---|
| `crbb5_bamboohr` | `dim_Employee` (Country, Job Title, Hire/Termination dates, IsActive flag) |
| `crbb5_project` | `dim_Project` (Project Code, Project Name, key) |
| `crbb5_contractregister` | `dim_Project` (Sector, Portfolio, MSA Reference, Project Type, Billing Method) |
| `crbb5_billingschedule` | `fact_Revenue` (in-contract forecast — may overlap with `HARP_DATA` and `31.12.2025`; needs reconciliation) |
| `crbb5_jedoxallocation` | `fact_Cost[Category=Staff, Type=Forecast]` (× `dim_StaffCosts` rates) |
| `dogma_timesheet` | `fact_Timesheet` (joined to `dim_Employee` via `systemuser(owninguser).crbb5_timeworkreference`) |
| `dogma_timesheetheader` | filter scope for `fact_Timesheet` (period boundaries) |
| `dogma_timesheetperiod` | filter scope for `fact_Timesheet` (approval state) |

### SharePoint forecast files (delivered)

Both forecast files have now been delivered to the shared SharePoint **Data** folder (confirmed by email). Both are broken down **by month and project code**, so each joins straight to `dim_Project[Project Code]` and rolls up by month — no whole-year-minus-YTD subtraction is required.

| Source | Staging query | Feeds | Status |
|---|---|---|---|
| **Additional Services Forecast** (SharePoint Excel file) | `stg_AdditionalServicesForecast` | `fact_Revenue[Type=Forecast, Contract Type=Out of Contract]` (Account Code 40014) | **Delivered.** By month + project code. |
| **Subcontractor Forecast** (SharePoint Excel file) | `stg_SubcontractorForecast` | `fact_Cost[Type=Forecast, Category=Subcontractor]` | **Delivered.** By month + project code. |

## Phase 0 — Branch and back up

**Before touching anything:**

1. Take a full copy of the current `.pbix` and save with a `_pre-refactor_YYYY-MM-DD` suffix.
2. Run a DAX Studio dump of the existing model so we have a reference of every current column, measure, and relationship:
   ```dax
   EVALUATE INFO.VIEW.COLUMNS()
   EVALUATE INFO.VIEW.MEASURES()
   EVALUATE INFO.VIEW.RELATIONSHIPS()
   ```
   Save the outputs as CSV in this folder.
3. Take a screenshot of the current Model view.

**Done when**: the `_pre-refactor` `.pbix`, three CSVs, and Model view screenshot are saved alongside this plan.

---

## Phase 1 — Foundations

### Task 1.1: Build `dim_Date_Live`

**What this does**: creates a calendar table with one row per day from 2024-01-01 to 2035-12-31. Every time-based filter, YTD measure and "actual vs forecast" chart in the report relies on this table.

**Where to do it**: Power Query (not DAX). In Power BI Desktop:
1. Click the **Home** ribbon → **Transform data** to open the Power Query Editor.
2. In the Power Query Editor, click **Home** → **New Source** → **Blank Query**.
3. A new query called `Query1` appears in the left-hand Queries panel.
4. Right-click `Query1` → **Rename** → type **`dim_Date_Live`** → press Enter.
5. With `dim_Date_Live` selected, click **Home** → **Advanced Editor**.
6. Delete all the text in the Advanced Editor and paste the code below.
7. Click **Done**.

**Code** (Power Query M):
```m
let
    StartDate = #date(2024, 1, 1),
    EndDate   = #date(2035, 12, 31),
    DayCount  = Duration.Days(EndDate - StartDate) + 1,
    Dates     = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    AsTable   = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(AsTable, {{"Date", type date}}),
    AddYear           = Table.AddColumn(Typed,            "Year",           each Date.Year([Date]),                                                                                  Int64.Type),
    AddMonth          = Table.AddColumn(AddYear,          "Month",          each Date.Month([Date]),                                                                                 Int64.Type),
    AddMonthName      = Table.AddColumn(AddMonth,         "MonthName",      each Date.MonthName([Date]),                                                                             type text),
    AddQuarter        = Table.AddColumn(AddMonthName,     "Quarter",        each Date.QuarterOfYear([Date]),                                                                         Int64.Type),
    AddMonthYear      = Table.AddColumn(AddQuarter,       "MonthYear",      each Date.ToText([Date], "MMM yyyy"),                                                                    type text),
    AddYearMonth      = Table.AddColumn(AddMonthYear,     "YearMonth",      each Date.Year([Date]) * 100 + Date.Month([Date]),                                                       Int64.Type),
    AddIsYTD          = Table.AddColumn(AddYearMonth,     "IsYTD",          each [Date] <= Date.From(DateTime.LocalNow()),                                                           type logical),
    AddIsCurrentMonth = Table.AddColumn(AddIsYTD,         "IsCurrentMonth", each Date.Year([Date]) = Date.Year(DateTime.LocalNow()) and Date.Month([Date]) = Date.Month(DateTime.LocalNow()), type logical)
in
    AddIsCurrentMonth
```

8. Click **Home** → **Close & Apply**. Power Query Editor closes, and the table loads into the model.

**Now mark it as a date table**:
9. In Power BI Desktop, switch to **Model view** (left sidebar icon).
10. Click on `dim_Date_Live`.
11. Right-click the `Date` column → **Mark as date table** → **Mark as date table** → pick `Date` from the dropdown → **OK**.

**How to check it worked**:
- Switch to **Data view** (left sidebar icon → table icon).
- Click `dim_Date_Live` in the right-hand Fields panel.
- The table should show **4,383 rows** (count visible at the bottom of the screen).
- First row is `2024-01-01`, last row is `2035-12-31`.
- Today's date row has `IsYTD = TRUE` and `IsCurrentMonth = TRUE`.

**Common errors**:
- `Expression.Error: The name 'Duration.Days' wasn't recognized` → you pasted the code into a DAX New Table window. Go back, follow step 1 above, you must be in **Power Query**, not DAX.
- Wrong row count → check the start and end dates in the code are exactly as shown.

---

### Task 1.1b: Build `dim_HolidayPolicy_Live`

**What this does**: a tiny **manually-maintained** parameter table holding the holiday-day allowance per year. Used by `dim_StaffCosts_Live` to compute `WorkedDays` (= net working days minus holiday minus public holiday). Chris explicitly asked (02 Jun email) for the option to amend the holiday days per year in case of policy change.

**Where to do it**: Power Query Editor → **New Source** → **Blank Query**.

**Steps**:
1. Rename the new query to **`dim_HolidayPolicy_Live`**.
2. Open **Advanced Editor** and paste the full script from `powerquery/dimensions/dim_HolidayPolicy_Live.pq`. The default rows are `{2025, 28, 8}` and `{2026, 28, 8}`.
3. **Close & Apply**. Right-click the query → **Hide** (it's a parameter, not for slicers).

**How to check it worked**:
- `dim_HolidayPolicy_Live` has one row per year, with `HolidayDays` and `PublicHolidayDays` columns.
- `Year` is Int64.

**Future years**: edit the script (or the table) to add new rows as Chris confirms the allowance for 2027+.

---

### Task 1.2: Build `dim_StaffCosts_Live` — deduplicate contractor → permanent EmployeeID

**Background you need**: when a contractor becomes a permanent employee, Equitix gives them a new EmployeeID. The contractor ID starts with `EMPEMCON`; the permanent ID starts with `EMPEM`. The same person ends up with **two** rows in `stg_Staff Costs Summary` — same Name, same Time@work Reference (TWR), different EmployeeID.

**Confirmed test cases** (use these to verify your work later):
- Gill Aran has rows `EMPEMCON010` (contractor) and `EMPEM97` (permanent)
- McClure Jim has `EMPEMCON002` and `EMPEM284`
- Ramanathan Kirthi has `EMPEMCON019` and `EMPEM300`
- Robbins Andrew has `EMPEMCON003` and `EMPEM287`

**The rule to apply**: always join on `Time@work Reference`, not on `EmployeeID`. When deduplicating, keep the `EMPEM*` (permanent) ID and discard the `EMPEMCON*` row.

**Where to do it**: Power Query Editor.

**Steps**:
1. Open Power Query Editor (**Home** → **Transform data**).
2. Right-click the existing `stg_Staff Costs Summary` query in the Queries panel → **Reference**. (This creates a new query that points at it — leaves the original untouched.)
3. Rename the new query to **`dim_StaffCosts_Live`**.
4. Open the **Advanced Editor** with `dim_StaffCosts_Live` selected.
5. Replace the contents with:

```m
let
    Source = #"stg_Staff Costs Summary",

    // Step A — rename columns to friendly names
    Renamed = Table.RenameColumns(Source, {
        {"Employee #",              "EmployeeID"},
        {"Time@work Reference",     "TimeWorkReference"},
        {"Last Name, First Name",   "EmployeeName"}
    }),

    // Step B — unpivot the 2025 / 2026 columns. The value IS the DAY RATE
    //          (£/day) directly — confirmed from the data, not an annual figure.
    Unpivoted = Table.UnpivotOtherColumns(
        Renamed,
        {"EmployeeID", "TimeWorkReference", "EmployeeName"},
        "Year",
        "DayRate"
    ),
    YearAsInt = Table.TransformColumnTypes(Unpivoted, {{"Year", Int64.Type}, {"DayRate", Currency.Type}}),

    // Step C — group by TWR + Year; keep the EMPEM (permanent) ID if both exist
    Grouped = Table.Group(YearAsInt,
        {"TimeWorkReference", "Year"},
        {
            {"EmployeeID",   each List.First(List.Select([EmployeeID], (id) => not Text.StartsWith(id, "EMPEMCON")), List.First([EmployeeID])), type text},
            {"EmployeeName", each List.First([EmployeeName]), type text},
            {"DayRate",      each List.Max([DayRate]), Currency.Type}
        }
    )
in
    Grouped
```

6. Click **Done**.

**How to check it worked**:
- After **Close & Apply**, switch to **Data view** and click `dim_StaffCosts_Live`.
- Search the table for `Robbins Andrew`. You should see **one row per year**, not two. The `EmployeeID` should be `EMPEM287` (not `EMPEMCON003`).
- Repeat for the other three test cases.
- Row count should be one per unique `TimeWorkReference` per Year. If `stg_Staff Costs Summary` had ~250 employees × 2 years, expect ~500 rows here (a bit fewer once duplicates collapse).

**If `EMPEMCON*` ID still appears** in any test case, the `Text.StartsWith(id, "EMPEMCON")` step didn't fire — check the column name in the source query exactly matches `EmployeeID`.

---

### Task 1.3: Add `Country` to `dim_StaffCosts_Live`

**What this does**: brings each employee's country from BambooHR into the staff-cost dim, so the next task can apply the country-aware hourly-rate divisor (7.5 for UK/Ireland, 8 for Italy).

**Where to do it**: continue editing `dim_StaffCosts_Live` in Power Query Editor.

**Steps**:
1. In the Power Query Editor, click `dim_StaffCosts_Live`.
2. Click **Home** → **Merge Queries** → **Merge Queries** (the option that does **not** say "Merge Queries as New").
3. In the Merge dialog:
   - Top table: `dim_StaffCosts_Live` (auto-selected).
   - Click the `TimeWorkReference` column to highlight it.
   - Bottom table dropdown: select **`crbb5_bamboohr`**.
   - In the `crbb5_bamboohr` preview, click **`crbb5_timeworkreference`** (the table is exposed by logical name — confirmed against its column list).
   - Join Kind: **Left Outer (all from first, matching from second)**.
   - Click **OK**.
4. A new column called `crbb5_bamboohr` appears at the right with table-icon cells.
5. Click the expand icon (◄►) on that column header → uncheck **all** boxes → tick only **`crbb5_country`** → uncheck "Use original column name as prefix" → **OK**. Rename the resulting column to `Country`.
6. A new `Country` column appears.
7. Apply a default for blank country values: click **Add Column** → **Conditional Column**:
   - New column name: `Country` (this will overwrite — actually call it `CountryFilled` for safety)
   - If `Country` is `null` → return `"UK"` else return `Country`.
   - **OK**.
8. Right-click the original `Country` column → **Remove**. Then right-click `CountryFilled` → **Rename** → `Country`.

**How to check it worked**:
- Every row in `dim_StaffCosts_Live` should have a non-blank `Country`.
- Spot-check known Italian staff: their `Country` should be `Italy`. (If you don't know any Italian staff names, ask Chris for one to test with.)
- Spot-check known UK staff: should be `UK`.

---

### Task 1.4: Add country-aware Day Rate and Hourly Rate to `dim_StaffCosts_Live`

**What this does**: applies the confirmed staff-cost formula (confirmed by client email):
```
Hourly rate = Day rate / Hours-per-day
Hours-per-day = 7.5 (UK + Ireland), 8 (Italy)
Project Cost = timesheet hours booked × Hourly rate
```

The client supplies **day rates** directly. No floor, no ceiling, no monthly cap, and **no adjustment for time booked over or below the standard hours per day** — the hourly charge is applied straight to the hours booked by project. This calc is final per the client email.

**Where to do it**: continue editing `dim_StaffCosts_Live` in Power Query Editor.

**Steps**:
1. Click **Add Column** → **Conditional Column** to add `HoursPerDay`:
   - New column name: `HoursPerDay`
   - If `Country` equals `"Italy"` → Output: `8`
   - Else → Output: `7.5`
   - **OK**.
2. Change the type of `HoursPerDay` to **Decimal Number** (click the column header type icon `123` → Decimal Number).
3. `DayRate` already exists — it is the unpivoted `2025` / `2026` value from Task 1.2, which the data confirms is the **day rate** (£/day) directly. **Do not** divide by 261 or apply any annual-to-day conversion.
4. Click **Add Column** → **Custom Column** to add `StaffCostPerHour`:
   - New column name: `StaffCostPerHour`
   - Custom column formula: `[DayRate] / [HoursPerDay]`
   - **OK**.
   - Change type to **Currency**.
5. Add the **forecast-cost inputs** Chris confirmed in his 02 Jun 2026 email. See `powerquery/dimensions/dim_StaffCosts_Live.pq` for the full M — in summary:
   - Expand `crbb5_contracthours` alongside Country in the BambooHR merge.
   - `FullTimeHours` = 37.5 (UK/IE) / 40 (Italy); `HoursRatio` = `ContractHours / FullTimeHours` (handles part-timers).
   - `NetWorkingDays` per year (≈ 261 for 2026, computed dynamically).
   - Join **`dim_HolidayPolicy_Live`** on Year to get `HolidayDays` (default 28) and `PublicHolidayDays` (default 8). Holiday allowance is configurable per year as Chris requested.
   - `WorkedDays = (NetWorkingDays − HolidayDays − PublicHolidayDays) × HoursRatio`.
   - `AnnualCost = NetWorkingDays × HoursRatio × DayRate`.
   - **`RevisedAnnualCost = WorkedDays × DayRate`** (cost net of holiday allowance — the per-employee envelope `_Cost_Staff_Forecast` allocates by project).
6. Add a composite `StaffKey` column (so a single-column relationship can join `dim_StaffCosts_Live` to a fact that carries the same key):
   - **Add Column** → **Custom Column**.
   - New column name: `StaffKey`
   - Custom column formula: `[TimeWorkReference] & "-" & Text.From([Year])`
   - **OK**. Change type to **Text**.
7. Click **Home** → **Close & Apply**.

**How to check it worked**:
- Find `Agnew, Samantha` (TWR `SAG`): `DayRate` = £241.55 (her 2026 value) and `StaffCostPerHour` = £32.21 (241.55 / 7.5).
- Pick any Italian staff row: `StaffCostPerHour` = `DayRate / 8`.
- Pick any UK/Ireland row: `StaffCostPerHour` = `DayRate / 7.5`. The same day rate yields a **higher** hourly rate in the UK than Italy (shorter UK day). If reversed, the country conditional in step 1 is backwards.

**Note on the source column**: rate type is **resolved by the data** — `stg_Staff Costs Summary` `2025` / `2026` columns hold day rates directly. There is no `/ 261` step.

---

## Phase 2 — Dimensions

### Task 2.1: Build `dim_Employee_Live`

**What this does**: creates an Employee dimension table that the report can slice and filter by. Separate from `dim_StaffCosts_Live` (which holds rates per year). One row per employee here; rates live in the other table.

**Where to do it**: Power Query Editor.

**Steps**:
1. Open Power Query Editor (**Home** → **Transform data**).
2. Right-click `crbb5_bamboohr` in the Queries panel → **Reference**.
3. Rename the new query to **`dim_Employee_Live`**.
4. With `dim_Employee_Live` selected, click **Home** → **Choose Columns** → **Choose Columns**.
5. In the dialog that opens, **untick "(Select All Columns)"** to deselect everything, then tick **only** these columns (exposed by **logical** name — confirmed against the `crbb5_bamboohr` column list):
   - `crbb5_bamboohrid` (the key — a GUID; see note below)
   - `crbb5_firstnamelastname`
   - `crbb5_timeworkreference`
   - `crbb5_country`
   - `crbb5_department`
   - `crbb5_employmentstatus`
   - `crbb5_hiredate`
   - `crbb5_terminationdate`
   - `crbb5_jobtitle`
   - `crbb5_managerbackupname`
   - `crbb5_budgetholder`
   - **OK**.
6. Rename the columns to friendly names. Right-click each header → **Rename**:
   - `crbb5_bamboohrid` → `EmployeeID`
   - `crbb5_firstnamelastname` → `EmployeeName`
   - `crbb5_timeworkreference` → `TimeWorkReference`
   - `crbb5_managerbackupname` → `Manager`
7. Add an `IsActive` flag. Click **Add Column** → **Conditional Column**:
   - New column name: `IsActive`
   - If `crbb5_employmentstatus` equals `"Active"` → Output: `true`
   - Else → Output: `false`
   - **OK**.
   - Change the type of `IsActive` to **True/False** (column header `ABC` icon → True/False).

**Note on `EmployeeID`**: this is currently `crbb5_bamboohrid`, which is a GUID. If the report needs the `EMPEM*` employee-number style used by `dim_StaffCosts` / `stg_Staff Costs Summary`, source it from `crbb5_employee` (or whichever column holds the EMPEM* code) instead. Relationships use `TimeWorkReference` so this is cosmetic.
8. **Close & Apply**.

**How to check it worked**:
- In **Data view**, `dim_Employee_Live` should have one row per employee (about 250 rows).
- No column should start with `crbb5_`.
- No column ending in `yominame` should be visible.
- The four test-case employees from Task 1.2 should each appear here as **a single row** (one row per person, not one per ID).
- `IsActive` is `TRUE` for currently-employed staff and `FALSE` for terminated.

**Confirm with the team before going live**: what values `Employment Status` can take. The step above assumes `"Active"` is the only "current employee" value — if there are others (e.g. `"On leave"`), update the conditional column.

---

### Task 2.2: Build `dim_Project_Live` (absorbing contract attributes)

**What this does**: creates the unified Project dimension that combines project-level info (from `crbb5_project`) with the contract-level attributes a project belongs to (from `crbb5_contractregister`). Later in Phase 3, the old `dim_Contracts` will be retired — its useful columns end up here.

**Where to do it**: Power Query Editor.

**Steps**:
1. Right-click `crbb5_project` → **Reference**.
2. Rename to **`dim_Project_Live`**.
3. **Choose Columns** to keep only these from `crbb5_project` (exposed by **logical** name — confirmed against the column list):
   - `crbb5_projectid` (GUID — keep as a backup key)
   - `crbb5_projectcode`
   - `crbb5_projectname`
   - `crbb5_projecttypename` (the Project Type **text** name, e.g. Operational/Construction — NOT the numeric `crbb5_projecttype`. Project Type is a **project-level** attribute, not on `crbb5_contractregister`)
   - `crbb5_contract` (this is the lookup to contract — needed for the merge step below)
   - `crbb5_subsidiaryname`
4. **Merge Queries** (Home → Merge Queries → Merge Queries):
   - Top table: `dim_Project_Live` (auto).
   - Click `crbb5_contract` column.
   - Bottom dropdown: **`crbb5_contractregister`**.
   - In the contract register preview, click **`crbb5_contractregisterid`** (the contract register primary-key GUID — confirmed to match `crbb5_contract`).
   - Join Kind: **Left Outer**.
   - **OK**.
5. A new column `crbb5_contractregister` appears. Click its expand icon (◄►), untick "(Select All)", then tick only these columns (all **confirmed** present on `crbb5_contractregister`):
   - `crbb5_supersectorchoicename` (the sector **name** — Social Infrastructure, Renewables, etc. Confirmed by Chris, 27 May: use the name, **not** the numeric `crbb5_supersectorchoice`, which is just a table ID)
   - `crbb5_portfolio`
   - `crbb5_msareference`
   - `crbb5_concessionexpiry`
   - Note: **Project Type, Billing Method, and Billing Start/End dates are NOT on `crbb5_contractregister`.** Project Type comes from `crbb5_project` (selected in step 3); billing fields live on `crbb5_billingschedule` (add that join later only if the report needs them).
   - Untick "Use original column name as prefix" → **OK**.
6. Rename each column to friendly names:
   - `crbb5_projectcode` → `Project Code`
   - `crbb5_projectname` → `Project Name`
   - `crbb5_projecttypename` → `Project Type` (from `crbb5_project`)
   - `crbb5_subsidiaryname` → `Subsidiary`
   - `crbb5_supersectorchoicename` → `Sector`
   - `crbb5_portfolio` → `Portfolio`
   - `crbb5_msareference` → `MSA Reference`
   - `crbb5_concessionexpiry` → `Concession Expiry`
7. Add a merged **`Project Display`** column (Chris, 27 May — show project code and name together):
   - **Add Column** → **Custom Column**: `Text.From([Project Code]) & " - " & Text.From([Project Name])`
   - Name it `Project Display`. This is the label the PoC tables drill into under each sector.
8. Add a default for blank `Portfolio`:
   - **Add Column** → **Conditional Column**:
   - New column: `Portfolio_Filled` — if `Portfolio` is `null` → `"Unportfolioed"`, else → `Portfolio`.
   - Remove the original `Portfolio` column. Rename `Portfolio_Filled` → `Portfolio`.
9. Add a `Contract Phase` column derived from MSA prefix:
   - **Add Column** → **Custom Column**:
     ```m
     if Text.StartsWith([MSA Reference], "EMS-MSA") then "Live"
     else if Text.StartsWith([MSA Reference], "EMSI-IT") then "Live"   // live Italian / ESS — note the extra "I"; distinct from legacy EMS-IT
     else if Text.StartsWith([MSA Reference], "EMS-PR") then "Pipeline"
     else if Text.StartsWith([MSA Reference], "EMS-IT") then "Legacy"
     else "Other"
     ```
   - Name it `Contract Phase`.
   - **OK**. Change column type to text.
10. **Close & Apply**.

**How to check it worked**:
- `dim_Project_Live` should have one row per project.
- Every row should have `Sector`, `Portfolio`, `MSA Reference`, `Contract Phase`, `Project Display`.
- `Sector` shows readable **names** (Social Infrastructure, Renewables, …), not numbers. If you see "1, 2, 3" you mapped the numeric `crbb5_supersectorchoice` instead of `crbb5_supersectorchoicename` — fix the expand step.
- `Project Display` reads like `"ASH-01 - Ashfield HoldCo"` (code then name).
- Spot-check a project with MSA Reference `EMS-MSA289` — `Contract Phase` should be `Live`.
- Spot-check a project with MSA Reference starting `EMS-PR` — `Contract Phase` should be `Pipeline`.
- No column should start with `crbb5_` (except the GUID `crbb5_projectid` if you kept it).
- Click on `Portfolio` column header → filter dropdown. You should see `Apollo`, `Caterham`, possibly `Unportfolioed`, and any other portfolios that exist.

---

### Task 2.3: Build `dim_Accounts_Live`

**What this does**: creates the Account dimension with two extra classification columns the dashboard needs:
- `Contract Type` (In Contract / Out of Contract) — drives the revenue split.
- `Cost Category` (Staff / Subcontractor / Other Cost) — drives the cost split.

The base data comes from the Chart of Accounts sheet in the FinanceOutput workbook.

**Where to do it**: Power Query Editor.

**Steps**:
1. Right-click `stg_FinanceOutput FY26_CoA` → **Reference**.
2. Rename to **`dim_Accounts_Live`**.
3. Rename `Nominal Code` → `Account Code` (right-click the column header → Rename). These are the same field, the rename makes the model consistent.
4. **Add Column** → **Conditional Column** for `Contract Type`:
   - New column name: `Contract Type`
   - If `Account Code` equals `40010` → `"In Contract"`
   - Else if `Account Code` equals `40011` → `"In Contract"`
   - Else if `Account Code` equals `40012` → `"In Contract"`
   - Else if `Account Code` equals `40014` → `"Out of Contract"`
   - Else → `null`
   - **OK**. Set type to **Text**.
5. **Add Column** → **Conditional Column** for `Cost Category`:
   - New column name: `Cost Category`
   - If `Account Code` equals `60201` → `"Subcontractor"`
   - Else if `Account Code` equals `60203` → `"Subcontractor"`
   - Else if `Account Type` equals `"Expense"` → `"Other Cost"`
   - Else if `Account Type` equals `"Income"` → `"(not a cost)"`
   - Else → `null`
   - **OK**. Set type to **Text**.
6. **Close & Apply**.

**Note**: there's a fourth Cost Category — `"Staff"` — which doesn't come from an account code at all. It applies to rows in `fact_Cost_Live` that are sourced from `fact_Timesheet_Live`. The category column for those rows is set directly during the fact build, not looked up via `dim_Accounts_Live`.

**How to check it worked**:
- In **Data view**, click `dim_Accounts_Live`.
- Filter `Account Code` to `40010` — `Contract Type` should be `In Contract`.
- Filter to `40014` — `Contract Type` should be `Out of Contract`.
- Filter to `60201` or `60203` — `Cost Category` should be `Subcontractor`.
- Filter to any other Expense account — `Cost Category` should be `Other Cost`.
- Filter to any Income account (e.g. `40010`) — `Cost Category` should be `(not a cost)`.

---

### Task 2.4: Build `dim_ForecastSnapshot_Live` and `dim_ForecastVersion_Live`

**What this does**: creates two small lookup tables that let the report filter to a specific forecast snapshot or version.

#### Part A — `dim_ForecastSnapshot_Live`

Each forecast file in SharePoint represents a snapshot taken at a particular date (e.g. `31.12.2025` sheet was the snapshot taken on 31 Dec 2025). This table holds one row per known snapshot.

**Steps**:
1. In Power Query Editor, click **Home** → **New Source** → **Blank Query**.
2. Rename to **`dim_ForecastSnapshot_Live`**.
3. **Advanced Editor** → paste:

```m
let
    // Add a row for each forecast snapshot we ingest. Update when a new one arrives.
    SnapshotList = #table(
        type table [SnapshotDate = date, SnapshotName = text],
        {
            {#date(2025, 12, 31), "31Dec2025"}
            // Append more rows here as new snapshots are delivered, e.g.
            // ,{#date(2026, 3, 31), "31Mar2026"}
        }
    )
in
    SnapshotList
```

4. **Done** → **Close & Apply**.

**How to check it worked**: `dim_ForecastSnapshot_Live` has 1 row showing `2025-12-31` and `31Dec2025`. When the next snapshot arrives, edit the query to add another row.

#### Part B — `dim_ForecastVersion_Live`

Each row of `crbb5_jedoxallocation` carries a `Version` (e.g. `Forecast`, `Actual`, possibly others). This table holds one row per distinct version so the user can filter by it.

**Steps**:
1. Right-click `crbb5_jedoxallocation` → **Reference**.
2. Rename to **`dim_ForecastVersion_Live`**.
3. **Choose Columns** → keep only `Version` (untick everything else).
4. Right-click `Version` column → **Remove Duplicates**.
5. **Close & Apply**.

**How to check it worked**: `dim_ForecastVersion_Live` has a small number of rows (3–5 expected), each a distinct value of `Version`. Confirm the values with Chris if any are unexpected.

---

### Task 2.5: Hide source tables and tables-to-retire

**What this does**: enforces the rule that visuals and measures may not reference `stg_*`, `crbb5_*`, or `dogma_*` tables directly. Also pre-emptively hides the four existing `dim_*` / `fact_*` tables that will be retired in Phase 5 once the `_Live` versions are validated.

**Where to do it**: Model View in Power BI Desktop.

**Steps**:
1. Switch to **Model view** (left sidebar icon — third one down, looks like linked boxes).
2. For each table in the list below, right-click the table in the canvas (or in the Data pane on the right) → **Hide in report view**:

**Source / staging tables — hide all of these:**
- `stg_EMS Fixed Fee Forecast_31Dec2025`
- `stg_EMS Fixed Fee Forecast_Actuals`
- `stg_EMS Fixed Fee Forecast_Contracts1`
- `stg_EMS Fixed Fee Forecast_Project HARP`
- `stg_FinanceOutput FY26_CoA`
- `stg_FinanceOutput FY26_FY2026`
- `stg_Staff Costs Summary`
- `crbb5_bamboohr`
- `crbb5_billingschedule`
- `crbb5_contractregister`
- `crbb5_jedoxallocation`
- `crbb5_project`
- `dogma_timesheet`
- `dogma_timesheetheader`
- `dogma_timesheetperiod`

**Existing tables to be retired in Phase 5 — hide now to catch any visual that still references them:**
- `dim_Contracts`
- `dim_Project` (the original, not `dim_Project_Live`)
- `dim_StaffCosts` (the original)
- `dim_Accounts` (the original)
- `dim_Transaction` (the original)
- `dim_timesheet`
- `fact_Actuals`
- `fact_Contracts`
- `fact_ProjectHARP`
- `fact_FinanceFY2026`

**How to check it worked**:
- Switch to **Report view** (top icon in left sidebar — chart icon).
- In the **Data** pane on the right, the only tables visible should be the new `_Live` ones plus `Equitix_Measures`.
- If a hidden table is still visible, right-click it and confirm **Hide in report view** has a tick next to it.
- If any visual on the report turns red / errors out, it was bound to a table you just hid. Note which visual; you'll fix it when you build the corresponding measure in Phase 4.

---

## Phase 3 — Facts

### Task 3.1: Build `fact_Timesheet_Live`

**What this does**: builds the granular per-day-per-employee-per-project cost table. Every timesheet line gets a cost stamped on it by joining to the rate from `dim_StaffCosts_Live`. This becomes the staff-cost feeder for `fact_Cost_Live`.

**Where to do it**: Power Query Editor.

**Background you need**:
- The cost formula is final: `Duration × StaffCostPerHour`. No floor, no ceiling. (See audit doc, Final staff-cost formula section.)
- Booked hours go to projects; un-booked hours stay as overhead and are **not** in this table.
- The internal placeholder `EMS 90` (used when an employee hasn't submitted timesheets) must be flagged so it can be excluded from contract / sector visuals.
- Some timesheet rows are flagged as duplicates or marked-to-delete — those must be filtered out.

**Steps**:
1. Right-click `dogma_timesheet` → **Reference**.
2. Rename to **`fact_Timesheet_Live`**.
3. **Filter out** rows we don't want:
   - Click the dropdown arrow on `is Duplicate?` → untick `TRUE` → **OK**.
   - Click the dropdown arrow on `mark to delete` → untick `TRUE` → **OK**.
4. **Filter to 2026 only**:
   - Click the dropdown arrow on `Date` → Date Filters → Between → From `01/01/2026` to `31/12/2026` → **OK**.
   - (If the client later asks for prior years too, this filter is the only line to change.)
5. **Surface the Time@work Reference** from the related user lookup:
   - In the Power Query Editor, find a column that points to the `owninguser` lookup. It will likely show table-icon cells.
   - **Important — use the corrected column**: Chris confirmed (post-Wednesday meeting) that you must expand the column called **`crbb5_crbb5_timeworkreferencename`** (note the **doubled** `crbb5_`). Do **not** use `systemuser(owninguser).crbb5_timeworkreference` — that's a workaround that misses some users; the doubled-prefix version has full coverage.
   - Click the expand icon (◄►) on the lookup column → tick only `crbb5_crbb5_timeworkreferencename` → untick "Use original column name as prefix" → **OK**.
   - Right-click the new column → **Rename** → `TimeWorkReference`.
6. **Choose Columns** — keep only:
   - `Date`
   - `TimeWorkReference`
   - `dogma_project` (rename to `Project Code`)
   - `Duration` (this is hours booked)
   - `crbb5_originalprojectcode` (used in the next step for the EMS 90 flag)
7. **Add a Year column** for joining to the rate dim:
   - **Add Column** → **Date** → **Year** → **Year**. A new `Year` column appears.
8. **Join to `dim_StaffCosts_Live`** to fetch the hourly rate:
   - **Home** → **Merge Queries** → **Merge Queries**.
   - Top: `fact_Timesheet_Live`.
   - Click both `TimeWorkReference` and `Year` columns while holding Ctrl (compound key).
   - Bottom dropdown: `dim_StaffCosts_Live`.
   - Click `TimeWorkReference` and `Year` in the same order.
   - Join Kind: **Left Outer**.
   - **OK**.
9. Click the expand icon on the new `dim_StaffCosts_Live` column → tick only `StaffCostPerHour` → untick "Use original column name as prefix" → **OK**.
10. **Compute the cost**:
    - **Add Column** → **Custom Column**:
    - New column: `Cost`
    - Formula: `[Duration] * [StaffCostPerHour]`
    - **OK**. Set type to **Currency**.
11. **Add the EMS 90 flag**:
    - **Add Column** → **Custom Column**:
    - New column: `IsEMS90`
    - Formula: `[Project Code] = "EMS 90" or [crbb5_originalprojectcode] = "EMS 90"`
    - **OK**. Set type to **True/False**.
12. **Remove** the `crbb5_originalprojectcode` column (no longer needed after the flag is set).
13. **Close & Apply**.

**How to check it worked**:
- In **Data view**, `fact_Timesheet_Live` has the columns: `Date`, `TimeWorkReference`, `Project Code`, `Duration`, `Year`, `StaffCostPerHour`, `Cost`, `IsEMS90`.
- All rows have `Year = 2026`.
- For any row with `IsEMS90 = TRUE`, the `Project Code` is `EMS 90`.
- For a sample row: if `Duration = 7.5` and `StaffCostPerHour = £40`, `Cost` should equal `£300`.
- If `StaffCostPerHour` is blank on some rows, the merge in step 8 didn't find a match — likely because the employee's TWR isn't in `dim_StaffCosts_Live` (the rate file is missing them). Flag these to the team for the DQ tile in Phase 4.

---

### Task 3.2: Build `fact_Revenue_Live`

**What this does**: unifies revenue actuals (from NetSuite) and revenue forecasts (in-contract + out-of-contract) into a single fact table. Every row carries flags so the dashboard can split In/Out Contract and Actual/Forecast.

**Schema** (every row carries these columns):
| Column | Meaning |
|---|---|
| `Date` | the period the row applies to |
| `Project Code` | for joining to `dim_Project_Live` |
| `Account Code` | for joining to `dim_Accounts_Live` |
| `Subsidiary` | for joining to subsidiary filter |
| `Type` | `"Actual"` or `"Forecast"` |
| `Contract Type` | `"In Contract"` or `"Out of Contract"` |
| `Snapshot Date` | for forecast rows only — which snapshot this belongs to. Blank for actuals. |
| `Amount` | the £ value |
| `TransactionLineKey` | unique key for actuals (Transaction ID + Transaction Line ID). Blank for forecasts. |

This table is built by **appending** three sub-queries together: actuals, in-contract forecast, OOC forecast. Build each sub-query first, then append.

**Where to do it**: Power Query Editor.

#### Sub-query A — `_Revenue_Actuals`

1. Right-click `stg_FinanceOutput FY26_FY2026` → **Reference**.
2. Rename to **`_Revenue_Actuals`** (the leading underscore tells you it's a helper query, not the final fact).
3. **Filter** `Account No.` to `40010`, `40011`, `40012`, `40014` only (the four revenue codes).
4. **Add Column** → **Custom Column** for `TransactionLineKey`:
   ```m
   Text.From([Transaction Line ID]) & "-" & Text.From([Transaction Ref.])
   ```
   (Confirm the exact column names with the source. The unique key concat was confirmed by Chris.)
5. **Apply the blank `Location: Full Name` defaults** (confirmed by Chris in the post-Wednesday meeting). Add a Conditional Column called `Location: Full Name (Filled)`:
   - If `Location: Full Name` is not blank → return `Location: Full Name`
   - Else if `Subsidiary: Full Name` ends in `"ESS"` → return `"Italy"`
   - Else → return `"UK"`
   - **OK**. Remove the original `Location: Full Name` column and rename the new one back.
6. **Add Column** → **Custom Column** to derive `Contract Type` from the account code:
   ```m
   if [#"Account No."] = 40014 then "Out of Contract" else "In Contract"
   ```
7. **Add Column** → constant `Type = "Actual"`, constant `Snapshot Date = null`.
8. Rename `Period End Date` → `Date`, `Account No.` → `Account Code`, `Sum of Amount` → `Amount`, `Subsidiary: Full Name` → `Subsidiary`, and keep `Project Code`.
9. **Choose Columns** to keep only: `Date`, `Project Code`, `Account Code`, `Subsidiary`, `Type`, `Contract Type`, `Snapshot Date`, `Amount`, `TransactionLineKey`.
10. Right-click the query → ensure **Enable load** is **unticked** (we don't need this in the model; only `fact_Revenue_Live` loads).

#### Sub-query B — `_Revenue_Forecast_InContract`

1. Open the `EMS Fixed Fee Forecast.xlsx` workbook source. The sheets we want are `31.12.2025` and `HARP_DATA`. Each has wide date columns that must be unpivoted.

2. For each sheet, build a reference query (e.g. `_Revenue_Forecast_31Dec2025` and `_Revenue_Forecast_HARP`):

```m
let
    Source = #"stg_EMS Fixed Fee Forecast_31Dec2025",   // or the HARP one
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),

    // Tell Power Query which columns are NOT date columns. Adjust based on the actual file.
    // Anything NOT in this list will be treated as a date column and unpivoted.
    NonDateColumns = {"Project Code", "Account Code"},

    Unpivoted = Table.UnpivotOtherColumns(PromotedHeaders, NonDateColumns, "Forecast Date Text", "Amount"),
    ParsedDate = Table.AddColumn(Unpivoted, "Date", each Date.From([Forecast Date Text]), type date),
    ParsedAmount = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),

    AddSnapshot = Table.AddColumn(ParsedAmount, "Snapshot Date", each #date(2025, 12, 31), type date),    // change for the HARP sheet to its own date
    AddType     = Table.AddColumn(AddSnapshot, "Type",          each "Forecast",            type text),
    AddContractType = Table.AddColumn(AddType, "Contract Type", each "In Contract",         type text),
    AddTLK      = Table.AddColumn(AddContractType, "TransactionLineKey", each null,         type text),
    AddSubsidiary = Table.AddColumn(AddTLK,    "Subsidiary",     each null,                 type text),    // fill if the sheet has it

    Final = Table.SelectColumns(AddSubsidiary, {"Date","Project Code","Account Code","Subsidiary","Type","Contract Type","Snapshot Date","Amount","TransactionLineKey"})
in
    Final
```

3. **Confirm with the team**: what `Account Code` to default to for forecast rows. The PoC dashboard suggests `40010` (Operational revenue) — apply that if the sheet doesn't have its own Account Code column.
4. Disable load on these helpers.

#### Sub-query C — `_Revenue_Forecast_OOC`

This is the **Additional Services Forecast** file (delivered to the SharePoint Data folder). It is a **wide monthly** layout: metadata columns (`Supersector`, `Sector`, `Upstream Reports`, `Project Code`, `Department`, `Location`) then one value column per month-end (`1/31/2026` … `12/31/2026`). **The header row is row 5** — the `stg_AdditionalServicesForecast` staging query must skip the title/note rows and promote row 5 before this runs. Additional services = Account Code 40014 = Out of Contract; per-month, so **no YTD-actual subtraction**. See `powerquery/helpers/_Revenue_Forecast_OOC.pq` for the full script.

```m
let
    Source = #"stg_AdditionalServicesForecast",
    NonDateColumns = {"Supersector", "Sector", "Upstream Reports", "Project Code", "Department", "Location"},
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),
    ParsedDate = Table.AddColumn(Unpivoted, "Date", each Date.FromText([#"Forecast Date Text"], [Format="M/d/yyyy", Culture="en-US"]), type date),
    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),
    AddSubsidiary   = Table.AddColumn(Typed,           "Subsidiary",    each [Location],        type text),
    AddAccountCode  = Table.AddColumn(AddSubsidiary,   "Account Code",  each 40014,             Int64.Type),
    AddType         = Table.AddColumn(AddAccountCode,  "Type",          each "Forecast",        type text),
    AddContractType = Table.AddColumn(AddType,         "Contract Type", each "Out of Contract", type text),
    AddSnapshot     = Table.AddColumn(AddContractType, "Snapshot Date", each null,              type date),
    AddTLK          = Table.AddColumn(AddSnapshot,     "TransactionLineKey", each null,         type text),
    Final = Table.SelectColumns(AddTLK,
        {"Date", "Project Code", "Account Code", "Subsidiary",
         "Type", "Contract Type", "Snapshot Date", "Amount", "TransactionLineKey"})
in
    Final
```

#### Combine into `fact_Revenue_Live`

1. **Home** → **New Source** → **Blank Query**.
2. Rename to **`fact_Revenue_Live`**.
3. **Advanced Editor**:

```m
let
    Combined = Table.Combine({
        #"_Revenue_Actuals",
        #"_Revenue_Forecast_31Dec2025",
        #"_Revenue_Forecast_HARP",
        #"_Revenue_Forecast_OOC"
    })
in
    Combined
```

4. **Close & Apply**.

**How to check it worked**:
- `fact_Revenue_Live` should contain rows from each sub-query: filter by `Type` and confirm both `Actual` and `Forecast` are present; filter by `Contract Type` and confirm both `In Contract` and `Out of Contract`.
- Sum of `Amount` where `Type = "Actual"` and `Account Code in {40010, 40011, 40012}` should equal the NetSuite year-to-date in-contract revenue total (cross-check with Chris's source figures).
- Sum where `Type = "Actual"` and `Account Code = 40014` matches the OOC YTD revenue total.
- No row has both `Type = "Actual"` and a `Snapshot Date`.
- No row has `Type = "Forecast"` and a `TransactionLineKey`.

---

### Task 3.3: Build `fact_Cost_Live`

**What this does**: unifies cost actuals and forecasts into a single fact table. Three actual sources (subcontractor from NetSuite, other expenses from NetSuite, staff cost aggregated from `fact_Timesheet_Live`) plus two forecast sources (staff from Jedox, subcontractor from the delivered Subcontractor Forecast file `stg_SubcontractorForecast`).

**Schema**:
| Column | Meaning |
|---|---|
| `Date` | the period |
| `Project Code` | for joining to `dim_Project_Live` |
| `TimeWorkReference` | for staff cost rows only (null otherwise) |
| `Account Code` | for joining to `dim_Accounts_Live` |
| `Category` | `"Staff"` / `"Subcontractor"` / `"Other Cost"` |
| `Type` | `"Actual"` or `"Forecast"` |
| `Snapshot Date` | for forecast rows only |
| `Amount` | the £ value |

Same pattern as `fact_Revenue_Live`: build sub-queries, append.

#### Sub-query A — `_Cost_Subcontractor_Actuals`

1. Right-click `stg_FinanceOutput FY26_FY2026` → **Reference**.
2. Rename to **`_Cost_Subcontractor_Actuals`**.
3. Filter `Account No.` to `60201` and `60203` only.
4. Apply the same `Location: Full Name` default rule as in `_Revenue_Actuals` (ESS → Italy, else UK).
5. Add constants: `Category = "Subcontractor"`, `Type = "Actual"`, `Snapshot Date = null`, `TimeWorkReference = null`.
6. Rename and reshape so columns are: `Date`, `Project Code`, `TimeWorkReference`, `Account Code`, `Category`, `Type`, `Snapshot Date`, `Amount`.
7. Disable load.

#### Sub-query B — `_Cost_Other_Actuals`

1. Right-click `stg_FinanceOutput FY26_FY2026` → **Reference**.
2. Rename to **`_Cost_Other_Actuals`**.
3. Filter `Account No.` to expense accounts only, **excluding** `60201` and `60203` (subcontractor) **and excluding the temp-staff account** (those people book timesheets — confirm the exact code with Chris before going live).
4. Same `Location: Full Name` default rule.
5. Constants: `Category = "Other Cost"`, `Type = "Actual"`, `Snapshot Date = null`, `TimeWorkReference = null`.
6. Same reshape as Sub-query A.
7. Disable load.

#### Sub-query C — `_Cost_Staff_Actuals`

This one aggregates `fact_Timesheet_Live` rows up to the cost-fact grain (one row per Date × Project × Employee).

1. Right-click `fact_Timesheet_Live` → **Reference**.
2. Rename to **`_Cost_Staff_Actuals`**.
3. **Home** → **Group By** → **Advanced**:
   - Group by: `Date`, `Project Code`, `TimeWorkReference`
   - New columns: `Amount = Sum([Cost])`
   - **OK**.
4. Add constants: `Account Code = null` (no account for timesheet-derived cost), `Category = "Staff"`, `Type = "Actual"`, `Snapshot Date = null`.
5. Reshape columns to match the schema.
6. Disable load.

#### Sub-query D — `_Cost_Staff_Forecast`

`crbb5_jedoxallocation` is exposed by **logical** names (confirmed against its column list). The full calculation principle was confirmed by Chris's 02 Jun 2026 email + workbook. See `powerquery/helpers/_Cost_Staff_Forecast.pq` for the full script.

1. Right-click `crbb5_jedoxallocation` → **Reference**.
2. Rename to **`_Cost_Staff_Forecast`**.
3. Filter **`crbb5_version`** to `"Forecast"` only.
4. Rename (use the **`_name`** lookup columns for the human-readable codes; the plain lookup columns are GUIDs):
   - `crbb5_hrreferencename` → `TimeWorkReference`
   - `crbb5_projectreferencename` → `Project Code`
   - `crbb5_value` → `AllocationFraction` (the % of FTE time, e.g. 0.25)
   - `crbb5_year` → `Year`
5. Merge with `dim_StaffCosts_Live` on `(TimeWorkReference, Year)` and expand **`RevisedAnnualCost`** (this is the cost net of holiday + public-holiday allowance, already pro-rated for part-timers — see dim_StaffCosts script).
6. Compute the annual project forecast: `AnnualForecastCost = AllocationFraction × RevisedAnnualCost`. Wrap with `if RevisedAnnualCost = null then 0 else ...` to handle missing-rate edge cases.
7. **Expand each annual row into 12 monthly rows** (Jan-end through Dec-end of the row's Year), with `Amount = AnnualForecastCost / 12`. The monthly granularity is needed so the cutover-date measures (which gate by `Date`) can pick which months show as forecast vs actual.
8. Add constants: `Account Code = null`, `Category = "Staff"`, `Type = "Forecast"`, `Snapshot Date = year-end`.
9. Disable load.

**Worked example (Chris's workbook).** Full-time UK employee on £500/day, 2026 (NetWorkingDays = 261, holiday = 28, public = 8 → WorkedDays = 225 → RevisedAnnualCost = £112,500). Allocated 25% to YUN-01: annual forecast = 0.25 × £112,500 = £28,125 = £2,343.75/month. Part-time same person at 20 h/wk (HoursRatio = 0.5333): RevisedAnnualCost = £60,000; 25% of YUN-01 = £15,000 annual / £1,250 per month.

**Overhead bucket** — the holiday cost (`AnnualCost − RevisedAnnualCost`) is **not emitted** to `fact_Cost_Live`. It's classed as overhead and not shown in sector profitability tables (per Chris). Add a separate helper later if a "fully-loaded staff cost" view is ever required.

#### Sub-query E — `_Cost_Subcontractor_Forecast`

This is the **Subcontractor Fees Forecast** file (delivered to the SharePoint Data folder). **Wide monthly** layout: metadata columns (`Netsuite N/C`, `Project Code`, `Department`, `Location`) then one value column per month-end. **The header row is row 3** — the `stg_SubcontractorForecast` staging query must skip the title rows and promote row 3. `Netsuite N/C` holds the account code (60201) → mapped to `Account Code`. See `powerquery/helpers/_Cost_Subcontractor_Forecast.pq` for the full script.

```m
let
    Source = #"stg_SubcontractorForecast",
    NonDateColumns = {"Netsuite N/C", "Project Code", "Department", "Location"},
    Unpivoted = Table.UnpivotOtherColumns(Source, NonDateColumns, "Forecast Date Text", "Amount"),
    ParsedDate = Table.AddColumn(Unpivoted, "Date", each Date.FromText([#"Forecast Date Text"], [Format="M/d/yyyy", Culture="en-US"]), type date),
    Typed = Table.TransformColumnTypes(ParsedDate, {{"Amount", Currency.Type}}),
    Renamed        = Table.RenameColumns(Typed, {{"Netsuite N/C", "Account Code"}}),
    AddTWR         = Table.AddColumn(Renamed,        "TimeWorkReference", each null,            type text),
    AddCategory    = Table.AddColumn(AddTWR,         "Category",          each "Subcontractor", type text),
    AddType        = Table.AddColumn(AddCategory,    "Type",              each "Forecast",      type text),
    AddSnapshot    = Table.AddColumn(AddType,        "Snapshot Date",     each null,            type date),
    Final = Table.SelectColumns(AddSnapshot,
        {"Date", "Project Code", "TimeWorkReference", "Account Code",
         "Category", "Type", "Snapshot Date", "Amount"})
in
    Final
```

#### Combine into `fact_Cost_Live`

```m
let
    Combined = Table.Combine({
        #"_Cost_Subcontractor_Actuals",
        #"_Cost_Other_Actuals",
        #"_Cost_Staff_Actuals",
        #"_Cost_Staff_Forecast",
        #"_Cost_Subcontractor_Forecast"
    })
in
    Combined
```

**Close & Apply**.

**How to check it worked**:
- `fact_Cost_Live` has rows tagged with each `Category` (`Staff`, `Subcontractor`, `Other Cost`) and each `Type` (`Actual`, `Forecast`).
- `Sum(Amount)` where `Type = "Actual"` and `Category = "Subcontractor"` should match the NetSuite total of accounts `60201 + 60203`.
- `Sum(Amount)` where `Type = "Actual"` and `Category = "Staff"` should match the total `Cost` in `fact_Timesheet_Live` excluding `EMS 90` rows.
- No row has both `Type = "Actual"` and a `Snapshot Date`.
- Staff rows always have a `TimeWorkReference`; non-staff rows do not.

---

### Task 3.4: Build `dim_Transaction_Live`

**What this does**: a clean Transaction dim that mirrors `dim_Transaction` but with the unique-key concat baked in. Used by drill-through and DQ measures.

**Steps**:
1. Right-click `stg_FinanceOutput FY26_FY2026` → **Reference**.
2. Rename to **`dim_Transaction_Live`**.
3. **Choose Columns**: keep `Transaction Ref.`, `Transaction Line ID`, `Account No.`, `Memo`, `Class: Class External ID`, `Customer: Full Name`, `Vendor: Full Name`, `Department: Department ID`, `Department: Full Name`, `Subsidiary: Full Name`, `Location: Location ID`, `Location: Full Name`, `Employee: Employee External ID`.
4. Apply the same `Location: Full Name` blank-default rule.
5. Add `TransactionLineKey` column: `Text.From([Transaction Line ID]) & "-" & Text.From([Transaction Ref.])`.
6. Right-click `TransactionLineKey` → **Remove Duplicates** to make it a clean primary key.
7. **Close & Apply**.

**How to check it worked**:
- Row count of `dim_Transaction_Live` equals distinct `TransactionLineKey` count in `stg_FinanceOutput FY26_FY2026`.
- No row has a blank `Location: Full Name`.

---

### Task 3.5: Set up relationships in Model view

**What this does**: wires up the joins so visuals slicing by Sector / Project / Date / Account / etc. actually filter the facts correctly.

**Where to do it**: Model View in Power BI Desktop.

**Steps**:
1. Switch to **Model view**.
2. Arrange the new `_Live` tables in a star pattern: facts in the middle, dims around the edges.
3. For each relationship below, drag from the **fact** column to the **dim** column. The relationship should be Many-to-One (`*` → `1`), single direction.

All relationships are **Many-to-One** (fact = many `*`, dim = one `1`) with **single** cross-filter direction (dim filters fact), and **active**, unless noted.

| From Table | From Column | To Table | To Column | Relationship | Status |
|---|---|---|---|---|---|
| fact_Revenue_Live | Date | dim_Date_Live | Date | Many-to-One | Active |
| fact_Revenue_Live | Project Code | dim_Project_Live | Project Code | Many-to-One | Active |
| fact_Revenue_Live | Account Code | dim_Accounts_Live | Account Code | Many-to-One | Active |
| fact_Revenue_Live | Snapshot Date | dim_ForecastSnapshot_Live | SnapshotDate | Many-to-One | Active |
| fact_Revenue_Live | TransactionLineKey | dim_Transaction_Live | TransactionLineKey | Many-to-One | Active |
| fact_Cost_Live | Date | dim_Date_Live | Date | Many-to-One | Active |
| fact_Cost_Live | Project Code | dim_Project_Live | Project Code | Many-to-One | Active |
| fact_Cost_Live | Account Code | dim_Accounts_Live | Account Code | Many-to-One | Active |
| fact_Cost_Live | TimeWorkReference | dim_Employee_Live | TimeWorkReference | Many-to-One | Active |
| fact_Cost_Live | Snapshot Date | dim_ForecastSnapshot_Live | SnapshotDate | Many-to-One | Active |
| fact_Timesheet_Live | Date | dim_Date_Live | Date | Many-to-One | Active |
| fact_Timesheet_Live | Project Code | dim_Project_Live | Project Code | Many-to-One | Active |
| fact_Timesheet_Live | TimeWorkReference | dim_Employee_Live | TimeWorkReference | Many-to-One | Active |

The same relationships with implementation notes:

| # | From (Many side — fact) | To (One side — dim) | Notes |
|---|---|---|---|
| 1 | `fact_Revenue_Live[Date]` | `dim_Date_Live[Date]` | |
| 2 | `fact_Revenue_Live[Project Code]` | `dim_Project_Live[Project Code]` | |
| 3 | `fact_Revenue_Live[Account Code]` | `dim_Accounts_Live[Account Code]` | |
| 4 | `fact_Revenue_Live[Snapshot Date]` | `dim_ForecastSnapshot_Live[SnapshotDate]` | actual rows have null Snapshot → unrelated (expected) |
| 5 | `fact_Revenue_Live[TransactionLineKey]` | `dim_Transaction_Live[TransactionLineKey]` | for drill-through; only **actual** rows have a key (forecast = null, unrelated) |
| 6 | `fact_Cost_Live[Date]` | `dim_Date_Live[Date]` | |
| 7 | `fact_Cost_Live[Project Code]` | `dim_Project_Live[Project Code]` | |
| 8 | `fact_Cost_Live[Account Code]` | `dim_Accounts_Live[Account Code]` | staff rows have null Account Code → only filters subcontractor/other rows |
| 9 | `fact_Cost_Live[TimeWorkReference]` | `dim_Employee_Live[TimeWorkReference]` | only staff rows carry a TWR |
| 10 | `fact_Cost_Live[Snapshot Date]` | `dim_ForecastSnapshot_Live[SnapshotDate]` | |
| 11 | `fact_Timesheet_Live[Date]` | `dim_Date_Live[Date]` | |
| 12 | `fact_Timesheet_Live[Project Code]` | `dim_Project_Live[Project Code]` | |
| 13 | `fact_Timesheet_Live[TimeWorkReference]` | `dim_Employee_Live[TimeWorkReference]` | |

**Notes / non-relationships:**
- **`dim_StaffCosts_Live`** keys on (`TimeWorkReference`, `Year`). Its rate is already baked into `fact_Timesheet_Live[Cost]` and the staff forecast, so it doesn't need to be active in the model. It now carries a **`StaffKey` = `<TWR>-<Year>`** column — if a future use case wants to expose `DayRate` / `StaffCostPerHour` to visuals, derive the same `StaffKey` on `fact_Timesheet_Live` (`= [TimeWorkReference] & "-" & Text.From([Year])`) and relate `fact_Timesheet_Live[StaffKey]` → `dim_StaffCosts_Live[StaffKey]` (Many-to-One, single-direction). Until then, hide `dim_StaffCosts_Live` with no relationship.
- **`dim_ForecastVersion_Live`** is currently **disconnected** — no fact carries a `Version` column (we filter Jedox to `Forecast` during ingest). To make it a usable slicer, add a `Version` column to `fact_Cost_Live` forecast rows, then relate `fact_Cost_Live[Version]` → `dim_ForecastVersion_Live[Version]`. Until then, hide it or drop it.
- **`Subsidiary`** is a plain text column on the facts (no `dim_Subsidiary`); slice on it directly, or build a small dim later if a hierarchy is needed.

**Key uniqueness pre-checks** (a relationship fails if the "one" side isn't unique):
- `dim_Date_Live[Date]`, `dim_Project_Live[Project Code]`, `dim_Accounts_Live[Account Code]`, `dim_Employee_Live[TimeWorkReference]`, `dim_ForecastSnapshot_Live[SnapshotDate]`, `dim_Transaction_Live[TransactionLineKey]` must each be **unique, no blanks**. If `dim_Employee_Live[TimeWorkReference]` has duplicates (contractor→permanent), dedupe it the same way `dim_StaffCosts_Live` does.

**Type pre-check** (a relationship fails if the two sides disagree on type):
- `Account Code` is **Int64** on both sides. The source `Nominal Code` is text in the CoA, but `dim_Accounts_Live` casts to `Int64.Type` (see the script header note) so it matches the fact-side `Account No.` (which is numeric in NetSuite). If the cast ever errors at refresh, fix the offending row in the CoA — every Nominal Code is expected to be a 5-digit integer.
- `TransactionLineKey` is **text** on both sides (built as `Text.From([Transaction: Transaction ID]) & "-" & Text.From([Transaction Line ID])`).

**Canonical filter for "Live contracts":** after Chris's 29 May decision (Pipeline excluded; only Live / Mobilised / Live-Stage in scope), use **`dim_Project_Live[IsInScope] = TRUE`** as the slicer / filter on report pages. It cascades through the project relationships and filters every fact correctly. Avoid filtering by the legacy MSA-prefix-derived `Contract Phase` column — that's informational only.

**How to check it worked**:
- In Model view all relationship lines should be solid (active), not dotted (inactive).
- No relationship has a yellow exclamation icon (cardinality mismatch).
- Build a quick test visual: a table with `dim_Project_Live[Sector]` and a measure `SUM(fact_Revenue_Live[Amount])`. Rows should appear, grouped by sector, with totals.

### Three ways to apply the 13 relationships

You don't have to drag-and-drop all 13 in Model view. Pick the option that matches your file format:

| Your situation | Use |
|---|---|
| `.pbip` (Power BI Project format) | Option B — TMDL paste below |
| `.pbix`, comfortable installing Tabular Editor (free) | Option C — C# script below |
| `.pbix`, don't want to install anything | Option A — drag-and-drop following the table above |

#### Option B — TMDL paste (`.pbip` only)

Add these to `…\<model>.SemanticModel\definition\relationships.tmdl` (Power BI normally assigns GUID names; readable names are fine in TMDL). Defaults are many-to-one + single-direction + active, so only inactive/extra options need spelling out — none here.

```tmdl
relationship rel_Revenue_Date
	fromColumn: fact_Revenue_Live.Date
	toColumn: dim_Date_Live.Date

relationship rel_Revenue_Project
	fromColumn: fact_Revenue_Live.'Project Code'
	toColumn: dim_Project_Live.'Project Code'

relationship rel_Revenue_Account
	fromColumn: fact_Revenue_Live.'Account Code'
	toColumn: dim_Accounts_Live.'Account Code'

relationship rel_Revenue_Snapshot
	fromColumn: fact_Revenue_Live.'Snapshot Date'
	toColumn: dim_ForecastSnapshot_Live.SnapshotDate

relationship rel_Revenue_Transaction
	fromColumn: fact_Revenue_Live.TransactionLineKey
	toColumn: dim_Transaction_Live.TransactionLineKey

relationship rel_Cost_Date
	fromColumn: fact_Cost_Live.Date
	toColumn: dim_Date_Live.Date

relationship rel_Cost_Project
	fromColumn: fact_Cost_Live.'Project Code'
	toColumn: dim_Project_Live.'Project Code'

relationship rel_Cost_Account
	fromColumn: fact_Cost_Live.'Account Code'
	toColumn: dim_Accounts_Live.'Account Code'

relationship rel_Cost_Employee
	fromColumn: fact_Cost_Live.TimeWorkReference
	toColumn: dim_Employee_Live.TimeWorkReference

relationship rel_Cost_Snapshot
	fromColumn: fact_Cost_Live.'Snapshot Date'
	toColumn: dim_ForecastSnapshot_Live.SnapshotDate

relationship rel_Timesheet_Date
	fromColumn: fact_Timesheet_Live.Date
	toColumn: dim_Date_Live.Date

relationship rel_Timesheet_Project
	fromColumn: fact_Timesheet_Live.'Project Code'
	toColumn: dim_Project_Live.'Project Code'

relationship rel_Timesheet_Employee
	fromColumn: fact_Timesheet_Live.TimeWorkReference
	toColumn: dim_Employee_Live.TimeWorkReference
```

#### Option C — Tabular Editor C# script (works on `.pbix` and `.pbip`)

Tabular Editor 2 is free (download: tabulareditor.com). With Power BI Desktop open on the model, launch Tabular Editor (External Tools → Tabular Editor, or open TE2 manually and connect to the localhost port Desktop is hosting), paste this into the **Advanced Scripting** pane, and press **F5**. Then save the `.pbix` back in Desktop.

```csharp
// Create the 13 _Live model relationships in one go.
// Many-to-One, single cross-filter direction, active.
// Skips any relationship that already exists.

void AddRel(string fromTable, string fromCol, string toTable, string toCol)
{
    var f = Model.Tables[fromTable].Columns[fromCol];
    var t = Model.Tables[toTable].Columns[toCol];
    if (Model.Relationships.OfType<SingleColumnRelationship>()
            .Any(r => r.FromColumn == f && r.ToColumn == t)) return;

    var r = Model.AddRelationship();
    r.FromColumn = f;
    r.ToColumn   = t;
    r.FromCardinality = RelationshipEndCardinality.Many;
    r.ToCardinality   = RelationshipEndCardinality.One;
    r.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
    r.IsActive = true;
}

AddRel("fact_Revenue_Live",   "Date",               "dim_Date_Live",             "Date");
AddRel("fact_Revenue_Live",   "Project Code",       "dim_Project_Live",          "Project Code");
AddRel("fact_Revenue_Live",   "Account Code",       "dim_Accounts_Live",         "Account Code");
AddRel("fact_Revenue_Live",   "Snapshot Date",      "dim_ForecastSnapshot_Live", "SnapshotDate");
AddRel("fact_Revenue_Live",   "TransactionLineKey", "dim_Transaction_Live",      "TransactionLineKey");

AddRel("fact_Cost_Live",      "Date",               "dim_Date_Live",             "Date");
AddRel("fact_Cost_Live",      "Project Code",       "dim_Project_Live",          "Project Code");
AddRel("fact_Cost_Live",      "Account Code",       "dim_Accounts_Live",         "Account Code");
AddRel("fact_Cost_Live",      "TimeWorkReference",  "dim_Employee_Live",         "TimeWorkReference");
AddRel("fact_Cost_Live",      "Snapshot Date",      "dim_ForecastSnapshot_Live", "SnapshotDate");

AddRel("fact_Timesheet_Live", "Date",               "dim_Date_Live",             "Date");
AddRel("fact_Timesheet_Live", "Project Code",       "dim_Project_Live",          "Project Code");
AddRel("fact_Timesheet_Live", "TimeWorkReference",  "dim_Employee_Live",         "TimeWorkReference");
```

---

### Task 3.6: Decide on existing fact_FinanceFY2026

The original `fact_FinanceFY2026` will become redundant once `fact_Revenue_Live` and `fact_Cost_Live` are validated. For now, leave it in place but hidden (already done in Task 2.5). It will be retired in Phase 5.

### Task 3.2: Build `fact_Revenue`

Unified actual + forecast revenue.

Schema:
| Column | Source |
|---|---|
| `Date` | actuals: `Period End Date`; forecasts: `Forecast Date` from unpivoted columns |
| `Project Code` | actuals: `Class: Class External ID` from the GL (there is no literal Project Code column — the project is the NetSuite Class); forecasts: staging Project Code |
| `Account Code` | NetSuite Account Code; for OOC forecast, default to `40014` |
| `Subsidiary` | from `dim_Transaction` (actuals) or contract subsidiary (forecasts) |
| `Type` | `Actual` or `Forecast` |
| `Contract Type` | `In Contract` / `Out of Contract` — derive from Account Code |
| `Snapshot Date` | for forecast rows, the snapshot the value belongs to. Null for actuals. |
| `Amount` | NetSuite `Sum of Amount` or unpivoted forecast value |
| `TransactionLineKey` | for actuals: `Transaction ID & "-" & Transaction Line ID`. Null for forecasts. |

Sources to union:
1. **Actuals**: from `FinanceOutput FY26.xlsx` → `FY2026` sheet, filter to revenue rows (`Account No.` in `{40010, 40011, 40012, 40014}`). Materialise the unique line key as `Transaction: Transaction ID & "-" & Transaction Line ID` (e.g. `770163-0`). **Note**: this sheet has **no `Project Code` column** — the project is the NetSuite Class, with the code in `Class: Class External ID` (e.g. `ASH-01`). Rename that to `Project Code`.
2. **In-contract forecast**: from `EMS Fixed Fee Forecast.xlsx`:
    - `31.12.2025` sheet — unpivot the wide date columns. Tag `Snapshot Date = 2025-12-31`, `Type=Forecast`.
    - `HARP_DATA` sheet — same unpivot, monthly columns 31/01/2025→31/12/2035. The code column is literally `Project Code` (`HAP-03`) here, NOT `Project` (which is the name). Drop the junk trailing columns `Column154`/`Column155`/`BLANK` before unpivot. HARP is **Construction** (Project Type), so default its `Account Code` to **40011** (Construction revenue), not 40010 — confirm.
    - Both should land into `fact_Revenue` with `Type=Forecast`. For the `31.12.2025` sheet default `Account Code` to `40010` (Operational revenue) unless the sheet specifies otherwise — confirm at next client meeting.
3. **OOC forecast**: ingest the **Additional Services Forecast** file (`stg_AdditionalServicesForecast`, delivered, by month + project code). Tag `Type=Forecast, Account Code = 40014, Contract Type = Out of Contract`. No YTD subtraction needed — it is already per-month.

Power Query for the unpivot step on `stg_EMS Fixed Fee Forecast_31Dec2025`:
```m
let
    Source = Excel.Workbook(File.Contents("...path..."), null, true){[Item="ForecastSheet", Kind="Sheet"]}[Data],
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    // Assume non-date columns are: Project Code, ... — adjust to actual file
    Unpivoted = Table.UnpivotOtherColumns(PromotedHeaders, {"Project Code", "Account Code"}, "Forecast Date", "Amount"),
    ParsedDate = Table.TransformColumnTypes(Unpivoted, {{"Forecast Date", type date}, {"Amount", Currency.Type}}),
    AddSnapshot = Table.AddColumn(ParsedDate, "Snapshot Date", each #date(2025, 12, 31), type date),
    AddType = Table.AddColumn(AddSnapshot, "Type", each "Forecast", type text)
in
    AddType
```

**Blank `Location: Full Name` defaults (confirmed by Chris)**:
- If `Subsidiary: Full Name` ends in `ESS` → set `Location: Full Name` default to `Italy`.
- If `Subsidiary: Full Name` ends in `EMS`, `BWG`, or `BWS` → set `Location: Full Name` default to `UK`.
- Apply this transform during the `fact_Revenue` and `fact_Cost` ingest (Power Query M `Table.ReplaceValue` step).

**Done when**: `fact_Revenue` has both actual and forecast rows, the four revenue account codes are present, the `Type` and `Contract Type` columns drive the slicers, blank `Location: Full Name` rows are defaulted per the rule above, and `Sum(Amount)` filtered to `Type=Actual` matches the NetSuite revenue total for FY2026 to date.

### Task 3.3: Build `fact_Cost`

Unified actual + forecast cost.

Schema:
| Column | Source |
|---|---|
| `Date` | actuals: `Period End Date` or `Transaction Date`; staff actuals: aggregated from `fact_Timesheet`; forecasts: `Forecast Date` |
| `Project Code` | NetSuite actuals: `Class: Class External ID` (no literal Project Code column in the GL); timesheet staff: `dogma_project` (or `EMS 90`); forecasts: staging Project Code |
| `Employee TWR` | for staff cost only; null otherwise |
| `Account Code` | NetSuite Account Code; staff cost has no account code → use a placeholder like `STAFF` |
| `Category` | `Staff` / `Subcontractor` / `Other Cost` — looked up via `dim_Accounts[Cost Category]` |
| `Type` | `Actual` or `Forecast` |
| `Snapshot Date` | for forecast rows |
| `Amount` | sum of cost |

Sources to union:
1. **Subcontractor actuals**: from `FinanceOutput FY26.xlsx` → `FY2026` sheet, filter to `Account No. IN {60201, 60203}`. Tag `Category=Subcontractor, Type=Actual`.
2. **Other actuals**: from same sheet, filter to expense accounts that are **not** `60201`, **not** `60203`, **not** the temp-staff account (confirm exact code with client). Tag `Category=Other Cost, Type=Actual`.
3. **Staff actuals**: aggregate `fact_Timesheet` grouped by `Date`, `Project Code`, `TimeWorkReference`, summing `Cost`. Tag `Category=Staff, Type=Actual`.
4. **Staff forecast**: from Dataverse `crbb5_jedoxallocation`, filter `crbb5_version = "Forecast"`. Join via `crbb5_hrreference` → `TimeWorkReference` and `crbb5_projectreference` → `Project Code`, period from `crbb5_year`/`crbb5_yeardate` (annual). Compute `Amount = crbb5_value × DayRate` (assuming `crbb5_value` = days — confirm via `crbb5_resourcemeasure`). Tag `Category=Staff, Type=Forecast`.
5. **Subcontractor forecast**: ingest the **Subcontractor Forecast** file (`stg_SubcontractorForecast`, delivered, by month + project code). Tag `Category=Subcontractor, Type=Forecast`.

**Done when**: `fact_Cost` has rows for all five sources, `Sum(Amount)` filtered to `Category=Subcontractor, Type=Actual` matches NetSuite's 60201+60203 total, and `Category=Staff, Type=Actual` matches the timesheet × rate total.

### Task 3.4: Verify retire-list tables are unused, then delete

For each of `dim_Contracts`, `fact_Actuals`, `fact_Contracts`, `fact_ProjectHARP`:

1. In Power BI Desktop, right-click → View dependencies (or use Tabular Editor's "Find dependencies"). Confirm no measure, calculated column, or visual references it.
2. Delete the table.
3. Save. If Power BI complains, fix the broken reference (it'll point at the offending measure / visual).

**Done when**: those four tables no longer exist in the model and the `.pbix` opens cleanly with no warnings.

### Task 3.5: Decide on `fact_FinanceFY2026`

Once `fact_Revenue` and `fact_Cost` are in place, `fact_FinanceFY2026` may be redundant. Audit:

1. Are any measures still bound to `fact_FinanceFY2026`?
2. Does any visual reference it?
3. If yes, migrate those references to `fact_Revenue` / `fact_Cost` and retire.
4. If no, retire immediately.

**Done when**: `fact_FinanceFY2026` is either retired or has a documented reason for staying (e.g. transaction-line detail drill-through that needs columns the unified facts don't carry).

---

## Phase 4 — Measures

**What this does**: builds the DAX measures the dashboard will use. Every measure references only `_Live` tables — never `stg_*`, `crbb5_*`, or `dogma_*`.

**Where to do it**: Power BI Desktop, Report or Model view.

**Steps for every measure below**:
1. In **Model view** or **Report view**, click `Equitix_Measures` in the right-hand Data pane.
2. Click **Home** ribbon → **New Measure**.
3. Replace `Measure = ` with the formula below.
4. Press **Enter** or click the tick. The measure appears under `Equitix_Measures`.
5. With the measure selected, change **Format** in the Measure tools ribbon to Currency / Percentage / Whole Number as appropriate.

### Revenue measures
```dax
Revenue = SUM(fact_Revenue_Live[Amount])

Revenue Actual = CALCULATE([Revenue], fact_Revenue_Live[Type] = "Actual")
Revenue Forecast = CALCULATE([Revenue], fact_Revenue_Live[Type] = "Forecast")

In-Contract Revenue = CALCULATE([Revenue], fact_Revenue_Live[Contract Type] = "In Contract")
Out-of-Contract Revenue = CALCULATE([Revenue], fact_Revenue_Live[Contract Type] = "Out of Contract")

Revenue YTD = CALCULATE([Revenue Actual], DATESYTD(dim_Date_Live[Date]))

-- Cutover-date logic (Chris, 29 May meeting): the report flips on the
-- 12th of the month. Before the 12th, the current month is still treated
-- as Forecast; from the 12th onward, the prior completed month flips to
-- Actual. The "Forecast" side of the YTF table is therefore "remaining
-- months only" (everything from the cutover month onward).
Cutover Month Start =
    VAR Today = TODAY()
    RETURN
    IF(DAY(Today) >= 12,
        DATE(YEAR(Today), MONTH(Today), 1),                                  -- include current month as forecast
        DATE(YEAR(Today), MONTH(Today)-1, 1) )                               -- before 12th: include prior month too as forecast

-- Four-way split for the PoC tables (Act/For × In/Oo).
-- Actuals are capped at "before cutover month"; Forecast is from cutover
-- month onward, so Actual + Forecast sums cleanly to the full-year total.
Rev Act In = CALCULATE([Revenue],
    fact_Revenue_Live[Type]="Actual",   fact_Revenue_Live[Contract Type]="In Contract",
    fact_Revenue_Live[Date] < [Cutover Month Start])
Rev Act Oo = CALCULATE([Revenue],
    fact_Revenue_Live[Type]="Actual",   fact_Revenue_Live[Contract Type]="Out of Contract",
    fact_Revenue_Live[Date] < [Cutover Month Start])
Rev For In = CALCULATE([Revenue],
    fact_Revenue_Live[Type]="Forecast", fact_Revenue_Live[Contract Type]="In Contract",
    fact_Revenue_Live[Date] >= [Cutover Month Start])
Rev For Oo = CALCULATE([Revenue],
    fact_Revenue_Live[Type]="Forecast", fact_Revenue_Live[Contract Type]="Out of Contract",
    fact_Revenue_Live[Date] >= [Cutover Month Start])
```

### Cost measures
```dax
Total Costs = SUM(fact_Cost_Live[Amount])

Staff Costs = CALCULATE([Total Costs], fact_Cost_Live[Category] = "Staff")
Subcontractor Costs = CALCULATE([Total Costs], fact_Cost_Live[Category] = "Subcontractor")
Other Costs = CALCULATE([Total Costs], fact_Cost_Live[Category] = "Other Cost")

Costs Actual = CALCULATE([Total Costs], fact_Cost_Live[Type] = "Actual")
Costs Forecast = CALCULATE([Total Costs], fact_Cost_Live[Type] = "Forecast")

Costs YTD = CALCULATE([Costs Actual], DATESYTD(dim_Date_Live[Date]))

-- Category × Type split for the PoC tables (Staff/Subcontractor × Act/For).
-- Same cutover-date rule as revenue: Actual < cutover month, Forecast >= cutover month.
Staff Cost Act  = CALCULATE([Staff Costs],
    fact_Cost_Live[Type]="Actual",   fact_Cost_Live[Date] < [Cutover Month Start])
Staff Cost For  = CALCULATE([Staff Costs],
    fact_Cost_Live[Type]="Forecast", fact_Cost_Live[Date] >= [Cutover Month Start])
Subcon Cost Act = CALCULATE([Subcontractor Costs],
    fact_Cost_Live[Type]="Actual",   fact_Cost_Live[Date] < [Cutover Month Start])
Subcon Cost For = CALCULATE([Subcontractor Costs],
    fact_Cost_Live[Type]="Forecast", fact_Cost_Live[Date] >= [Cutover Month Start])
```

Note: `Category` filters in the cost measures sit directly on `fact_Cost_Live`, not via `dim_Accounts_Live`, because staff cost rows have a null `Account Code` (timesheet-derived) and would be lost if we filtered via the dim.

### Profit and margin
```dax
Profit = [Revenue] - [Total Costs]
Profit Actual = [Revenue Actual] - [Costs Actual]
Profit Forecast = [Revenue Forecast] - [Costs Forecast]
Profit Full Year = [Profit Actual] + [Profit Forecast]

Margin % = DIVIDE([Profit], [Revenue])
Margin Actual % = DIVIDE([Profit Actual], [Revenue Actual])
Margin Forecast % = DIVIDE([Profit Forecast], [Revenue Forecast])

Profit Variance = [Profit Forecast] - [Profit Actual]
```

### PoC table roll-ups

These compose the named columns of the two PoC tables (YTD and YTF + Forecast). Both tables now carry **Staff Cost** and **Subcontractor Costs** columns per the v2 layout.

```dax
-- YTD Profitability table (Account-code actuals only)
Rev Act In YTD  = CALCULATE([Rev Act In], DATESYTD(dim_Date_Live[Date]))
Rev Act Oo YTD  = CALCULATE([Rev Act Oo], DATESYTD(dim_Date_Live[Date]))
Total Rev YTD   = [Rev Act In YTD] + [Rev Act Oo YTD]
Staff Cost YTD  = CALCULATE([Staff Cost Act], DATESYTD(dim_Date_Live[Date]))
Subcon Cost YTD = CALCULATE([Subcon Cost Act], DATESYTD(dim_Date_Live[Date]))
Total Cost YTD  = [Staff Cost YTD] + [Subcon Cost YTD]
Profit YTD      = [Total Rev YTD] - [Total Cost YTD]
Margin YTD %    = DIVIDE([Profit YTD], [Total Rev YTD])

-- YTF + Forecast table (full-year = actual + forecast)
Total Rev FY    = [Rev Act In] + [Rev Act Oo] + [Rev For In] + [Rev For Oo]
Total Cost FY   = [Staff Cost Act] + [Staff Cost For] + [Subcon Cost Act] + [Subcon Cost For]
Profit FY       = [Total Rev FY] - [Total Cost FY]
Margin FY %     = DIVIDE([Profit FY], [Total Rev FY])
```

**Row hierarchy (both tables)** — confirmed by Chris, 27 May check-in:
- **Top level = `dim_Project_Live[Sector]`** — the sector **name** (Social Infrastructure, Renewables, …), not the numeric "Sector 1/2/3" placeholders shown in the PoC mock-up (those were just row IDs).
- **Drill level = `dim_Project_Live[Project Display]`** — the merged `"<Project Code> - <Project Name>"` label, so each project shows its code and full description together.

**Matrix layout — YTD table** (rows = `Sector` → `Project Display`): `Rev Act In YTD` (In Contract), `Rev Act Oo YTD` (Oo Contract), `Total Rev YTD`, `Staff Cost YTD`, `Subcon Cost YTD` (Subcontractor Costs), `Total Cost YTD`, `Profit YTD`, `Margin YTD %`.

**Matrix layout — YTF + Forecast table** (rows = `Sector` → `Project Display`): `Rev Act In`, `Rev Act Oo`, `Rev For In`, `Rev For Oo`, `Total Rev FY`, `Staff Cost Act`, `Staff Cost For`, `Subcon Cost Act`, `Subcon Cost For`, `Total Cost FY`, `Profit FY`, `Margin FY %`. Power BI's Matrix cannot reproduce the banded `Revenue Act / Revenue For / Cost Act / Cost For` super-headers from a flat value list — accept flat headers, or use a calculation group crossing a `Scenario` (Actual/Forecast) item with Contract Type on columns.

**Sanity check (Chris, 27 May):** with staff cost = booked hours × hourly rate, he expects sector **margins around 50–55%** — a lot of time is booked to these projects, so staff cost is high. If a sector reads a much higher margin (e.g. 80–90%), staff costs are probably under-counting (missing timesheet hours, unmatched rates, or `EMS 90` leakage) — investigate before sign-off.

### Data quality measures
```dax
DQ Missing Project Code =
    COUNTROWS(FILTER(fact_Revenue_Live, ISBLANK(fact_Revenue_Live[Project Code])))
    + COUNTROWS(FILTER(fact_Cost_Live, ISBLANK(fact_Cost_Live[Project Code])))

DQ Employees Missing Rate =
    COUNTROWS(
        FILTER(
            dim_StaffCosts_Live,
            dim_StaffCosts_Live[StaffCostPerHour] = 0
            || ISBLANK(dim_StaffCosts_Live[StaffCostPerHour])
        )
    )

DQ Unmapped Project Codes =
    COUNTROWS(
        FILTER(
            VALUES(fact_Revenue_Live[Project Code]),
            ISBLANK(
                LOOKUPVALUE(
                    dim_Project_Live[MSA Reference],
                    dim_Project_Live[Project Code],
                    fact_Revenue_Live[Project Code]
                )
            )
        )
    )
```

**How to check each measure worked**:
- Drop the measure into a Card visual on a test report page. The Card should show a number, not blank or error.
- `[Revenue Actual]` for the current year, compared against the previous report's YTD revenue figure, should match within rounding.
- `[Subcontractor Costs]` filtered to `Type = Actual` should equal the NetSuite total of `60201 + 60203` for the YTD period.
- `[Profit Actual]` should match the previous report's YTD profit.

---

## Phase 5 — Verification

**What this does**: confirms the new `_Live` model produces the same numbers as the existing report before you delete the old tables.

**Where to do it**: Power BI Desktop + DAX Studio.

### Model checks
- [ ] All `stg_*`, `crbb5_*`, `dogma_*` tables are hidden from Report View (Task 2.5).
- [ ] All existing-but-soon-to-be-retired tables (`dim_Contracts`, `dim_Project`, `dim_StaffCosts`, `dim_Accounts`, `dim_Transaction`, `dim_timesheet`, `fact_Actuals`, `fact_Contracts`, `fact_ProjectHARP`, `fact_FinanceFY2026`) are hidden but **not yet deleted**. They stay until Phase 6 swap-over.
- [ ] In Model view, every `_Live`-to-`_Live` relationship is single-direction (`*` → `1`), active, and has no warning icon.
- [ ] `dim_Date_Live` is marked as Date Table; no other table has a Date marking.
- [ ] No measure references a `stg_*`, `crbb5_*`, or `dogma_*` column. Use Tabular Editor's "Best Practice Analyzer" with the default ruleset to verify.

### Numeric reconciliation against the existing report
Open both `.pbix` files side-by-side: the `_pre-refactor` backup and the working one with `_Live` tables.

- [ ] `[Revenue YTD]` from `_Live` measures matches the old report's YTD revenue (within £1).
- [ ] `[In-Contract Revenue]` matches.
- [ ] `[Out-of-Contract Revenue]` matches.
- [ ] `[Subcontractor Costs]` matches the NetSuite total of `60201 + 60203`.
- [ ] `[Staff Costs]` (Actual) matches a manual spot-check: pick 5 employees, multiply their booked hours × hourly rate from `dim_StaffCosts_Live`, sum, compare.
- [ ] **YUN-01 worked-example reconciliation (client-provided, in the Data folder).** Filter `[Staff Cost Act]` to `dim_Project_Live[Project Code] = "YUN-01"` and confirm the totals match the client's reference workbook:
  - 2025: **£58,770.73**
  - 2026: **£18,984.92**
  - **Total: £77,755.65**
  - Per-employee spot-checks (within rounding): ATE £6,721.41, DTH £8,917.51, RLU £11,499.82, TWH £44,495.80.
  - All ten employees in the reference file are UK/IE (the example formula hard-codes `÷ 7.5`). If our model reads any of those TWRs as `Italy` and applies `÷ 8`, totals will differ — that's a `dim_Employee_Live[Country]` data issue, not a formula bug.
- [ ] `[Profit YTD]` matches.
- [ ] Contractor → permanent dedup test: filter to `EmployeeName = "Robbins Andrew"` in `dim_Employee_Live` — one row only. His historic cost in `fact_Cost_Live` should sum to the contractor + permanent total combined.

### Slicer behaviour
- [ ] Sector slicer shows distinct sectors, no blanks or duplicates.
- [ ] Portfolio slicer shows `Apollo`, `Caterham`, and `Unportfolioed`.
- [ ] Project Code slicer shows all `EMS-MSA*` projects. `EMS-PR*` / `EMS-IT*` inclusion behaviour follows whatever the client confirmed for pipeline contracts.
- [ ] Country / employee filter: an Italian employee's hourly rate uses ÷ 8; UK / Ireland uses ÷ 7.5.

### Performance
- [ ] Open the `.pbix` cold (close and reopen). First report page loads in < 5 seconds on the VM.
- [ ] Toggle a slicer; visuals re-render in < 2 seconds.

**If any check fails**: do not proceed to Phase 6. Diagnose the failing measure or relationship first.

---

## Phase 6 — Swap-over (do this only after Phase 5 is green)

**What this does**: deletes the old tables and removes the `_Live` suffix. After this, the model only contains the cleaned `dim_*` / `fact_*` tables.

**Important**: this phase is destructive. Only run it after:
- All Phase 5 checks pass.
- The team / client has signed off on the new numbers.
- A fresh backup of the `.pbix` has been taken (`_post-verification_YYYY-MM-DD`).

### Steps

1. **Delete the retired tables** (in Model view, right-click → Delete):
   - `dim_Contracts`
   - `dim_Project` (old)
   - `dim_StaffCosts` (old)
   - `dim_Accounts` (old)
   - `dim_Transaction` (old)
   - `dim_timesheet`
   - `fact_Actuals`
   - `fact_Contracts`
   - `fact_ProjectHARP`
   - `fact_FinanceFY2026`

2. **Rename the `_Live` tables** to drop the suffix. In Model view, double-click each table name:
   - `dim_Date_Live` → `dim_Date`
   - `dim_Project_Live` → `dim_Project`
   - `dim_Employee_Live` → `dim_Employee`
   - `dim_StaffCosts_Live` → `dim_StaffCosts`
   - `dim_Accounts_Live` → `dim_Accounts`
   - `dim_Transaction_Live` → `dim_Transaction`
   - `dim_ForecastSnapshot_Live` → `dim_ForecastSnapshot`
   - `dim_ForecastVersion_Live` → `dim_ForecastVersion`
   - `fact_Revenue_Live` → `fact_Revenue`
   - `fact_Cost_Live` → `fact_Cost`
   - `fact_Timesheet_Live` → `fact_Timesheet`

3. **Re-check measures**: renaming a referenced table updates measures automatically in DAX, but **Power Query queries that reference each other by name will break**. After each rename, do **Home** → **Refresh** and watch for errors. Any helper query (`_Revenue_Actuals`, etc.) that referenced `*_Live` needs the same rename.

4. **Run all Phase 5 checks again** to confirm nothing regressed.

5. **Save the `.pbix`** with a clean name (no `_Live`, no `_pre-refactor`).

6. **Publish** to the Power BI workspace.

**Done when**: the model contains only the clean `dim_*` / `fact_*` tables (no `_Live` suffix anywhere) and all measures and visuals still work.

---

## Blockers to escalate

### ✅ Resolved
1. ~~Staff-cost formula~~ — client email. Final: `booked hours × (Day rate / hours-per-day)`, hours-per-day 7.5 UK+IE / 8 Italy, no cap, no over/under-standard-hours adjustment. Validated by the YUN-01 worked example (target £77,755.65, see Phase 5).
2. ~~OOC revenue forecast file~~ — delivered. **Additional Services Forecast** → `stg_AdditionalServicesForecast`.
3. ~~Subcontractor cost forecast file~~ — delivered. **Subcontractor Forecast** → `stg_SubcontractorForecast`.
4. ~~Annual / Day / Hourly rate~~ — client supplies **day rates** directly (the `2025` / `2026` columns in `stg_Staff Costs Summary`).

### ✅ Resolved at the 29 May meeting
5. ~~HARP revenue account code~~ → **40011 Construction** confirmed. Will switch to 40010 Operational after HARP's 9-year construction phase ends. Helper already defaults to 40011.
6. ~~`EMSI-IT*` / `EMS-IT*` = Live Italian~~ → **No.** Both prefixes are **legacy numbering** from when the contract register was first set up (briefly used, then dropped). They do NOT indicate Italian. Country is determined by **subsidiary**: `ESS` → Italian; `EMS / BWG / BWS` → UK. `dim_Project_Live` header updated to remove the country-from-prefix inference.
7. ~~Temp-staff / agency invoice account~~ → **Any account starting `607`** (607xxx) is temp staff / consultancy fees whose workers are also on timesheets. **Excluded** from `_Cost_Other_Actuals` to avoid double-counting. Subcontractor accounts confirmed as **60201, 60202, 60203** (60202 was missing — now added).
8. ~~Pipeline contracts inclusion~~ → **Exclude.** Only **Live / Mobilised / Live-Stage** contracts in the profitability report. `dim_Project_Live` now expands `crbb5_contractstatus` and derives an `IsInScope` flag; exact status list to keep is pending from Chris.
9. ~~Mid-year rate changes~~ → **Not expected.** Annual rate assumption is fine. Nice-to-have for future flexibility — would require a monthly profile if introduced later.
10. ~~Forecast columns: full year or remaining months~~ → **Remaining months only.** Forecast is forward-looking; Actual + Forecast must sum to total (otherwise the rolled-up totals confuse readers). **Cutover day = 12th of the month** — before the 12th, current month is still forecast; from the 12th onward, the prior month flips to actual.

### ✅ Resolved at the 02 Jun email + workbook
11. ~~Jedox forecast calculation~~ — confirmed by Chris's email + the worked-example workbook. `crbb5_value` is % of FTE time. The full formula is now implemented in `dim_StaffCosts_Live` + `_Cost_Staff_Forecast`:
   - `dim_StaffCosts_Live` derives **`RevisedAnnualCost = WorkedDays × DayRate`**, where `WorkedDays = (NetWorkingDays − HolidayDays − PublicHolidayDays) × HoursRatio`. `HoursRatio = ContractHours / FullTimeHours` (37.5 UK/IE, 40 Italy) — handles part-timers correctly.
   - `_Cost_Staff_Forecast` then does `AnnualForecastCost = crbb5_value × RevisedAnnualCost`, spread evenly across 12 months.
   - Holiday allowance is held in **`dim_HolidayPolicy_Live`** (2025 / 2026 default 28 / 8) — configurable per year as Chris requested.
12. ~~Contract statuses to include~~ — confirmed: **`Live`, `Mobilised`, `Terminated`** (the three statuses indicating Live or previously-Live). `dim_Project_Live[IsInScope]` updated.

### 🟡 Still open — pending Chris
13. **2025 financials feed** — Chris will deliver a separate Excel file in the Data folder for YoY comparisons. Ingest into a new staging table when delivered.
14. **Timesheet data scope** — once 2025 financials arrive, we likely want 2025 timesheets too for a like-for-like comparison. Currently we only ingest 2026.

### 🟢 Logistics
15. ~~Fabric workspace~~ → Dashboard 1 has been **published to the Fabric workspace**; client team to review and feed back.
16. ~~VM clipboard~~ → Chris changed Sanjana's workspace access from **Contributor to Member**, which should restore copy-paste. Sanjana to retest and flag if still blocked.

## Reference: where each business rule comes from

If you're unsure why something is the way it is, check the audit doc:

- Account codes (40010/11/12 = In Contract revenue, 40014 = OOC, 60201/03 = Subcontractor) → audit § Revenue/Cost classification
- Country-aware divisor (7.5 vs 8) → audit § Day-rate to hourly conversion
- Contractor → permanent ID dedupe → audit § dim_StaffCosts duplicate employee rows
- `EMS 90` exclusion → audit § Confirmed business rules
- Portfolio dimension → audit § New dimension level — Portfolio
- MSA Reference prefixes → audit § MSA Reference glossary
- Subsidiary hierarchy → audit § Subsidiary hierarchy in NetSuite
