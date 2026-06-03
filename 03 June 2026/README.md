# Power Query scripts — Equitix Profitability Report

Each `.pq` file in this folder is the Power Query M script for **one query** in the `_Live` model. They're kept in source control so changes can be diffed, reviewed and reverted independently of the `.pbix` binary.

## Two ways to use these files

### Option A — Power BI Project format (`.pbip`) — **recommended**

Power BI introduced the **Power BI Project** format in 2023. A `.pbip` is a folder, not a binary file: the model definition (including every Power Query script as a separate file) lives as readable text that's git-friendly.

To convert the current `.pbix`:
1. Open the `.pbix` in Power BI Desktop.
2. **File** → **Options and settings** → **Options** → **Preview features** → tick **Power BI Project (.pbip) save option**.
3. **File** → **Save as** → choose **Power BI Project file (.pbip)**.
4. Power BI creates a folder structure like:
   ```
   ReportName/
   ├── ReportName.Report/
   ├── ReportName.SemanticModel/
   │   └── definition/
   │       ├── tables/
   │       │   ├── dim_Date_Live.tmdl
   │       │   ├── fact_Revenue_Live.tmdl
   │       │   └── ...
   │       └── ...
   └── ReportName.pbip
   ```
5. Each table's Power Query M is inside its `.tmdl` file under a `partition` block.
6. Commit the whole folder to git. Diffs are now readable.

This is the gold standard for source-controlled Power BI. The `.pq` files in this folder are a complementary reference — the source of truth becomes the `.tmdl` files in the `.pbip` folder.

### Option B — Paste-in via Advanced Editor

If you're not on `.pbip` yet, use the `.pq` files in this folder as the source of truth:

1. In Power BI Desktop, open Power Query Editor (**Home** → **Transform data**).
2. **New Source** → **Blank Query**.
3. Rename the new query to match the `.pq` file name (without the extension).
4. Open **Advanced Editor**.
5. Copy the entire contents of the `.pq` file and paste into the editor.
6. Click **Done**.
7. Repeat for each `.pq` file.

When you edit a query in Power BI Desktop, **also update the `.pq` file** so the source-controlled copy stays in sync. Recommend a pre-commit checklist: "did this branch touch a query? If yes, did you update the corresponding `.pq` file?"

## Folder structure

```
powerquery/
├── README.md
├── dimensions/         # one file per dim_*_Live query
├── facts/              # one file per fact_*_Live query
└── helpers/            # sub-queries used inside fact_Revenue_Live and fact_Cost_Live (load disabled in PBI)
```

## Build order

Queries depend on each other. If you're pasting them in for the first time, create them in this order:

1. **Foundations**
   - `dimensions/dim_Date_Live.pq`
   - `dimensions/dim_StaffCosts_Live.pq` (depends on `stg_Staff Costs Summary`, `crbb5_bamboohr`)
2. **Core dimensions**
   - `dimensions/dim_Employee_Live.pq` (depends on `crbb5_bamboohr`)
   - `dimensions/dim_Accounts_Live.pq` (depends on `stg_FinanceOutput FY26_CoA`)
   - `dimensions/dim_Project_Live.pq` (depends on `crbb5_project`, `crbb5_contractregister`)
   - `dimensions/dim_Transaction_Live.pq` (depends on `stg_FinanceOutput FY26_FY2026`)
   - `dimensions/dim_ForecastSnapshot_Live.pq` (standalone)
   - `dimensions/dim_ForecastVersion_Live.pq` (depends on `crbb5_jedoxallocation`)
3. **Helpers** (load-disabled — these are sub-queries that get appended into the facts)
   - `helpers/_Revenue_*.pq` — note `_Revenue_Forecast_OOC` depends on `stg_AdditionalServicesForecast` (delivered SharePoint file, by month + project code)
   - `helpers/_Cost_*.pq` — note `_Cost_Subcontractor_Forecast` depends on `stg_SubcontractorForecast` (delivered SharePoint file, by month + project code)
4. **Facts**
   - `facts/fact_Timesheet_Live.pq` (depends on `dogma_timesheet`, `dim_StaffCosts_Live`)
   - `facts/fact_Revenue_Live.pq` (depends on the `_Revenue_*` helpers)
   - `facts/fact_Cost_Live.pq` (depends on the `_Cost_*` helpers and `fact_Timesheet_Live`)

## Notes on each script

- The header comment in each `.pq` lists its dependencies and any open questions.
- `TODO:` comments mark places where a column name or value needs to be verified against the actual source data before going live.
- For helpers, the **load** setting must be disabled in Power BI Desktop (right-click the query → uncheck "Enable load"). The `.pq` files contain the M code only; the load flag is set in the PBI UI.
- For dimensions and facts, leave **load** enabled (default).

## Naming convention

Every query name carries the **`_Live`** suffix so the new model can coexist with the existing one during development. After Phase 5 verification, run Phase 6 (swap-over) to drop the suffix.

## Companion documents

- **`../Power BI Refactor Plan.md`** — step-by-step task instructions, definition-of-done per task.
- **`../Power BI Schema Audit - Equip Profitability Report.md`** — full schema context, business rules, client meeting notes.
