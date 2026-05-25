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
| `fact_Revenue_Live` | One row per (Date, Project, Account, Type, Snapshot) | actuals from `stg_FinanceOutput FY26_FY2026`; in-contract forecast from `stg_EMS Fixed Fee Forecast_*`; OOC forecast from Grant's file | Build new |
| `fact_Cost_Live` | One row per (Date, Project, Employee, Account, Category, Type, Snapshot) | actuals from `stg_FinanceOutput FY26_FY2026`; staff actuals aggregated from `fact_Timesheet_Live`; staff forecast from `crbb5_jedoxallocation × dim_StaffCosts_Live`; subcontractor forecast (pending file from Chris) | Build new |
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

### Pending SharePoint files (confirmed sources, not yet delivered)

| Source | Feeds | Status |
|---|---|---|
| **Grant's OOC revenue forecast** (new SharePoint Excel file) | `fact_Revenue[Type=Forecast, Contract Type=Out of Contract]` | **Pending delivery from Chris.** Confirmed location: SharePoint. Structure TBC — likely whole-year totals per sector that need YTD-actual subtraction to derive the remaining-forecast figure. |
| **Subcontractor cost forecast** (new SharePoint Excel file) | `fact_Cost[Type=Forecast, Category=Subcontractor]` | **Pending delivery from Chris.** Confirmed location: SharePoint. Chris will check whether the data is already broken down by project; if not, his team will reshape it before sending. |

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

    // Step B — unpivot the 2025 / 2026 columns so each row is (TWR, Year, AnnualRate)
    Unpivoted = Table.UnpivotOtherColumns(
        Renamed,
        {"EmployeeID", "TimeWorkReference", "EmployeeName"},
        "Year",
        "AnnualRate"
    ),
    YearAsInt = Table.TransformColumnTypes(Unpivoted, {{"Year", Int64.Type}, {"AnnualRate", Currency.Type}}),

    // Step C — group by TWR + Year; keep the EMPEM (permanent) ID if both exist
    Grouped = Table.Group(YearAsInt,
        {"TimeWorkReference", "Year"},
        {
            {"EmployeeID",   each List.First(List.Select([EmployeeID], (id) => not Text.StartsWith(id, "EMPEMCON")), List.First([EmployeeID])), type text},
            {"EmployeeName", each List.First([EmployeeName]), type text},
            {"AnnualRate",   each List.Max([AnnualRate]), Currency.Type}
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
   - In the `crbb5_bamboohr` preview, click the `Time@work Reference` column (it may be named slightly differently — find the column that holds the TWR).
   - Join Kind: **Left Outer (all from first, matching from second)**.
   - Click **OK**.
4. A new column called `crbb5_bamboohr` appears at the right with table-icon cells.
5. Click the expand icon (◄►) on that column header → uncheck **all** boxes → tick only **`Country`** → uncheck "Use original column name as prefix" → **OK**.
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

**What this does**: applies the confirmed staff-cost formula from Chris's post-Wednesday meeting:
```
Day rate    = Annual rate / 261
Hourly rate = Day rate / Hours-per-day
Hours-per-day = 7.5 (UK + Ireland), 8 (Italy)
```

No floor, no ceiling, no monthly cap. The cost is simply `timesheet hours × hourly rate`. This calc is final per the latest client call.

**Where to do it**: continue editing `dim_StaffCosts_Live` in Power Query Editor.

**Steps**:
1. Click **Add Column** → **Conditional Column** to add `HoursPerDay`:
   - New column name: `HoursPerDay`
   - If `Country` equals `"Italy"` → Output: `8`
   - Else → Output: `7.5`
   - **OK**.
2. Change the type of `HoursPerDay` to **Decimal Number** (click the column header type icon `123` → Decimal Number).
3. Click **Add Column** → **Custom Column** to add `DayRate`:
   - New column name: `DayRate`
   - Custom column formula: `[AnnualRate] / 261`
   - **OK**.
   - Change type to **Currency** (`£`).
4. Click **Add Column** → **Custom Column** to add `StaffCostPerHour`:
   - New column name: `StaffCostPerHour`
   - Custom column formula: `[DayRate] / [HoursPerDay]`
   - **OK**.
   - Change type to **Currency**.
5. Click **Home** → **Close & Apply**.

**How to check it worked**:
- Pick any Italian staff row. If their `AnnualRate` is £80,000, you should see `DayRate ≈ £306.51` and `StaffCostPerHour ≈ £38.31` (£306.51 / 8).
- Pick any UK or Ireland staff row with the same £80,000 annual rate — `StaffCostPerHour ≈ £40.87` (£306.51 / 7.5).
- The same employee at the same annual rate should show a **higher** hourly rate in the UK than in Italy (because of the shorter UK working day). If you see the opposite, the conditional column in step 1 has the country backwards.

**Note on the source column**: the existing `stg_Staff Costs Summary` may provide the rate as a **Day rate** rather than an **Annual rate**. Open the workbook and check. If it's already a Day rate, skip the `/ 261` step — set `DayRate = [whatever the column is called]` directly. Confirm with Chris which it is and tell the team. (Audit doc Q1 covers this — recommend Annual rate so we own the conversion.)

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
5. In the dialog that opens, **untick "(Select All Columns)"** to deselect everything, then tick **only** these columns:
   - `BambooHR` (the key)
   - `First Name Last Name`
   - `Time@work Reference`
   - `Country`
   - `Department`
   - `Employment Status`
   - `Hire Date`
   - `Termination Date`
   - `Job Title`
   - `Manager Backup`
   - `Budget Holder`
   - **OK**.
6. Rename the columns to friendly names. Right-click each header → **Rename**:
   - `BambooHR` → `EmployeeID`
   - `First Name Last Name` → `EmployeeName`
   - `Time@work Reference` → `TimeWorkReference`
   - `Manager Backup` → `Manager`
7. Add an `IsActive` flag. Click **Add Column** → **Conditional Column**:
   - New column name: `IsActive`
   - If `Employment Status` equals `"Active"` → Output: `true`
   - Else → Output: `false`
   - **OK**.
   - Change the type of `IsActive` to **True/False** (column header `ABC` icon → True/False).
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
3. **Choose Columns** to keep only these from `crbb5_project`:
   - `crbb5_projectid` (GUID — keep as a backup key)
   - `Project Code`
   - `Project Name`
   - `crbb5_contract` (this is the lookup to contract — needed for the merge step below)
   - `crbb5_subsidiaryname`
4. **Merge Queries** (Home → Merge Queries → Merge Queries):
   - Top table: `dim_Project_Live` (auto).
   - Click `crbb5_contract` column.
   - Bottom dropdown: **`crbb5_contractregister`**.
   - In the contract register preview, click the corresponding key column (usually `Contract Register` or a `crbb5_*` ID — pick the one that matches the GUID format of `crbb5_contract`).
   - Join Kind: **Left Outer**.
   - **OK**.
5. A new column `crbb5_contractregister` appears. Click its expand icon (◄►), untick "(Select All)", then tick only these columns:
   - `crbb5_supersectorchoice` (the canonical sector field — confirmed by Chris)
   - `crbb5_portfolio`
   - `crbb5_contractname` (or `MSA Reference` if present)
   - `crbb5_projecttype`
   - The Billing Method / Billing Start / Billing End / Concession Expiry fields if they exist in the contract register (column names may vary)
   - Untick "Use original column name as prefix" → **OK**.
6. Rename each new column to friendly names:
   - `crbb5_supersectorchoice` → `Sector`
   - `crbb5_portfolio` → `Portfolio`
   - `crbb5_contractname` → `Contract Name`
   - `crbb5_projecttype` → `Project Type`
   - `crbb5_subsidiaryname` → `Subsidiary`
7. Add a default for blank `Portfolio`:
   - **Add Column** → **Conditional Column**:
   - New column: `Portfolio_Filled` — if `Portfolio` is `null` → `"Unportfolioed"`, else → `Portfolio`.
   - Remove the original `Portfolio` column. Rename `Portfolio_Filled` → `Portfolio`.
8. Add a `Contract Phase` column derived from MSA prefix:
   - **Add Column** → **Custom Column**:
     ```m
     if Text.StartsWith([MSA Reference], "EMS-MSA") then "Live"
     else if Text.StartsWith([MSA Reference], "EMS-PR") then "Pipeline"
     else if Text.StartsWith([MSA Reference], "EMS-IT") then "Legacy"
     else "Other"
     ```
   - Name it `Contract Phase`.
   - **OK**. Change column type to text.
9. **Close & Apply**.

**How to check it worked**:
- `dim_Project_Live` should have one row per project.
- Every row should have `Sector`, `Portfolio`, `MSA Reference`, `Contract Phase`.
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

This is Grant's standalone OOC file. **Not yet delivered as of writing**. Build the query stub now so the append in the next step has a placeholder; populate it when the file arrives.

```m
let
    // Placeholder until Grant's file is delivered.
    // When delivered, replace this with: Excel.Workbook(File.Contents("...path to Grant's file..."))
    Source = #table(
        type table [
            Date = date, #"Project Code" = text, #"Account Code" = Int64.Type, Subsidiary = text,
            Type = text, #"Contract Type" = text, #"Snapshot Date" = date, Amount = Currency.Type, TransactionLineKey = text
        ],
        {}
    )
in
    Source
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

**What this does**: unifies cost actuals and forecasts into a single fact table. Three actual sources (subcontractor from NetSuite, other expenses from NetSuite, staff cost aggregated from `fact_Timesheet_Live`) plus two forecast sources (staff from Jedox, subcontractor from a pending SharePoint file).

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

1. Right-click `crbb5_jedoxallocation` → **Reference**.
2. Rename to **`_Cost_Staff_Forecast`**.
3. Filter `Version` to `"Forecast"` only.
4. Surface `TimeWorkReference` from the related lookup (same approach as in `fact_Timesheet_Live` step 5).
5. Rename `Project Reference` → `Project Code`, `Allocation Date` → `Date`, `Value` → `Allocation` (this is a percentage or fraction — confirm with Chris).
6. Merge with `dim_StaffCosts_Live` on `TimeWorkReference` + `Year` to fetch `StaffCostPerDay` (or `StaffCostPerHour`).
7. Compute the forecast cost. **Exact formula needs confirmation** — likely `Allocation × StaffCostPerDay × Working Days In Period`. For now, use:
   ```
   Amount = [Allocation] × [StaffCostPerDay] × 21      // 21 working days as a placeholder; refine after confirming with Chris
   ```
8. Add constants: `Account Code = null`, `Category = "Staff"`, `Type = "Forecast"`, `Snapshot Date = (the relevant snapshot)`.
9. Disable load.

#### Sub-query E — `_Cost_Subcontractor_Forecast`

This is **the new SharePoint file from Chris** — confirmed source, not yet delivered. Build a stub.

```m
let
    Source = #table(
        type table [
            Date = date, #"Project Code" = text, TimeWorkReference = text, #"Account Code" = Int64.Type,
            Category = text, Type = text, #"Snapshot Date" = date, Amount = Currency.Type
        ],
        {}
    )
in
    Source
```

When the file arrives, replace the stub.

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

| From (Many side — fact) | To (One side — dim) | Notes |
|---|---|---|
| `fact_Revenue_Live[Date]` | `dim_Date_Live[Date]` | active |
| `fact_Revenue_Live[Project Code]` | `dim_Project_Live[Project Code]` | active |
| `fact_Revenue_Live[Account Code]` | `dim_Accounts_Live[Account Code]` | active |
| `fact_Revenue_Live[Snapshot Date]` | `dim_ForecastSnapshot_Live[SnapshotDate]` | active |
| `fact_Cost_Live[Date]` | `dim_Date_Live[Date]` | active |
| `fact_Cost_Live[Project Code]` | `dim_Project_Live[Project Code]` | active |
| `fact_Cost_Live[Account Code]` | `dim_Accounts_Live[Account Code]` | active — note: staff rows will have null Account Code, so this only filters non-staff rows |
| `fact_Cost_Live[TimeWorkReference]` | `dim_Employee_Live[TimeWorkReference]` | active |
| `fact_Cost_Live[Snapshot Date]` | `dim_ForecastSnapshot_Live[SnapshotDate]` | active |
| `fact_Timesheet_Live[Date]` | `dim_Date_Live[Date]` | active |
| `fact_Timesheet_Live[Project Code]` | `dim_Project_Live[Project Code]` | active |
| `fact_Timesheet_Live[TimeWorkReference]` | `dim_Employee_Live[TimeWorkReference]` | active |
| `dim_StaffCosts_Live[TimeWorkReference]` | `dim_Employee_Live[TimeWorkReference]` | active — links the rate dim to the employee dim |

**How to check it worked**:
- In Model view all relationship lines should be solid (active), not dotted (inactive).
- No relationship has a yellow exclamation icon (cardinality mismatch).
- Build a quick test visual: a table with `dim_Project_Live[Sector]` and a measure `SUM(fact_Revenue_Live[Amount])`. Rows should appear, grouped by sector, with totals.

---

### Task 3.6: Decide on existing fact_FinanceFY2026

The original `fact_FinanceFY2026` will become redundant once `fact_Revenue_Live` and `fact_Cost_Live` are validated. For now, leave it in place but hidden (already done in Task 2.5). It will be retired in Phase 5.

### Task 3.2: Build `fact_Revenue`

Unified actual + forecast revenue.

Schema:
| Column | Source |
|---|---|
| `Date` | actuals: `Period End Date`; forecasts: `Forecast Date` from unpivoted columns |
| `Project Code` | NetSuite Project Code (actuals) or staging Project Code (forecasts) |
| `Account Code` | NetSuite Account Code; for OOC forecast, default to `40014` |
| `Subsidiary` | from `dim_Transaction` (actuals) or contract subsidiary (forecasts) |
| `Type` | `Actual` or `Forecast` |
| `Contract Type` | `In Contract` / `Out of Contract` — derive from Account Code |
| `Snapshot Date` | for forecast rows, the snapshot the value belongs to. Null for actuals. |
| `Amount` | NetSuite `Sum of Amount` or unpivoted forecast value |
| `TransactionLineKey` | for actuals: `Transaction ID & "-" & Transaction Line ID`. Null for forecasts. |

Sources to union:
1. **Actuals**: from `FinanceOutput FY26.xlsx` → `FY2026` sheet, filter to revenue rows (`Account No.` in `{40010, 40011, 40012, 40014}`). Materialise the unique line key as `Transaction Line ID & "-" & Transaction Ref.` (or whichever columns NetSuite uses for the unique pair — confirm).
2. **In-contract forecast**: from `EMS Fixed Fee Forecast.xlsx`:
    - `31.12.2025` sheet — unpivot the wide date columns. Tag `Snapshot Date = 2025-12-31`, `Type=Forecast`.
    - `HARP_DATA` sheet — same unpivot, tag `Snapshot Date` based on the file modified date or a column inside. Project Code is the HARP project code (confirm).
    - Both should land into `fact_Revenue` with `Type=Forecast`. Default `Account Code` to `40010` (Operational revenue) unless the source sheet specifies otherwise — confirm at next client meeting.
3. **OOC forecast**: ingest Grant's file once delivered. Tag `Type=Forecast, Account Code = 40014, Contract Type = Out of Contract`.

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
| `Project Code` | NetSuite Project Code (or null for `EMS 90`) |
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
4. **Staff forecast**: from Dataverse `crbb5_jedoxallocation`, filter `Version = "Forecast"`. Compute `Cost = Value × (StaffCostPerDay × Working Days In Period)` joined via `HR Reference` → `TimeWorkReference` and `Project Reference` → `Project Code`. Tag `Category=Staff, Type=Forecast`.
5. **Subcontractor forecast**: source TBD (pending client). Leave as an empty union branch until file arrives.

**Done when**: `fact_Cost` has rows for all four sources, `Sum(Amount)` filtered to `Category=Subcontractor, Type=Actual` matches NetSuite's 60201+60203 total, and `Category=Staff, Type=Actual` matches the timesheet × rate total.

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

Most original blockers were resolved in the post-Wednesday meeting. Remaining:

1. ~~Staff-cost formula~~ — ✅ **resolved**. Final: `hours × (Annual rate / 261 / hours-per-day)`, no cap. Booked hours allocate to projects; un-booked goes to overhead.
2. **OOC revenue forecast file (Grant)** — confirmed coming from SharePoint, **not yet delivered**. Without it, `fact_Revenue[Type=Forecast, Contract Type=Out of Contract]` will be empty.
3. **Subcontractor cost forecast file** — ✅ source confirmed (new SharePoint Excel file from Chris). **Not yet delivered**. Without it, `fact_Cost[Type=Forecast, Category=Subcontractor]` will be empty.
4. **Annual rate vs Day rate vs Hourly rate** — ask the client which they'll send. Recommend Annual rate.
5. **Fabric workspace** — currently Power BI Pro only. Confirm whether Fabric is being enabled.
6. **VM clipboard** — copy-paste block; slows development. Client to investigate.
7. **Timesheet data scope** — `dogma_timesheet` has rows from 2023; confirm we only ingest 2026 (Sanjana asked, not yet answered in transcript).

- Emplyooee contractor => permanent relationshipc
- Days in a year
- Subsisry
- 

## Reference: where each business rule comes from

If you're unsure why something is the way it is, check the audit doc:

- Account codes (40010/11/12 = In Contract revenue, 40014 = OOC, 60201/03 = Subcontractor) → audit § Revenue/Cost classification
- Country-aware divisor (7.5 vs 8) → audit § Day-rate to hourly conversion
- Contractor → permanent ID dedupe → audit § dim_StaffCosts duplicate employee rows
- `EMS 90` exclusion → audit § Confirmed business rules
- Portfolio dimension → audit § New dimension level — Portfolio
- MSA Reference prefixes → audit § MSA Reference glossary
- Subsidiary hierarchy → audit § Subsidiary hierarchy in NetSuite
