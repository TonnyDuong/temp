---
tags: [equitix, power-bi, power-query, setup]
project: "[[Equitix]]"
---

# Power Query scripts, [[Equitix]] Profitability Report

Companion to [[Power BI Refactor Plan]] and [[Power BI Schema Audit - Equip Profitability Report]].

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
Equitix.PowerQuery/
|-- README.md
|-- AGENTS.md
|-- sources/            # one .pq script per source/staging query
|-- dimensions/         # one file per dim_*_Live query
|-- facts/              # one file per fact_*_Live query
|-- helpers/            # sub-queries used inside fact_Revenue_Live and fact_Cost_Live
|-- docs/               # companion plan and audit markdown
`-- Equitix_Measures.txt
```

The source folder is named `sources` (plural). There is no active singular `source` folder.

## Source query names

The `.pq` files under `sources/` are the Power Query source/staging queries that the other `.pq` files reference by name. Keep the filename stem aligned with the Power BI query name.

| Query name | Source |
|---|---|
| `crbb5_bamboohr` | Dataverse table `dbo.crbb5_bamboohr` |
| `crbb5_billingschedule` | Dataverse table `dbo.crbb5_billingschedule` |
| `crbb5_contractregister` | Dataverse table `dbo.crbb5_contractregister` |
| `crbb5_jedoxallocation` | Dataverse table `dbo.crbb5_jedoxallocation` |
| `crbb5_project` | Dataverse table `dbo.crbb5_project`, with `Project Display` added |
| `dogma_timesheet` | Dataverse table `dbo.dogma_timesheet`, with owning-user Time@work fields expanded |
| `dogma_timesheetheader` | Dataverse table `dbo.dogma_timesheetheader` |
| `dogma_timesheetperiod` | Dataverse table `dbo.dogma_timesheetperiod` |
| `stg_EMS Fixed Fee Forecast_Contracts1` | `EMS Fixed Fee Forecast.xlsx`, `Contracts` sheet |
| `stg_EMS Fixed Fee Forecast_Project HARP` | `EMS Fixed Fee Forecast.xlsx`, `ProjectHARP` sheet |
| `stg_EMS Fixed Fee Forecast_31Dec2025` | `EMS Fixed Fee Forecast.xlsx`, `31.12.2025` sheet |
| `stg_EMS Fixed Fee Forecast_Actuals` | `EMS Fixed Fee Forecast.xlsx`, `Actuals` sheet |
| `stg_FinanceOutput FY26_CoA` | `FinanceOutput FY26.xlsx`, `CoA` sheet |
| `stg_FinanceOutput FY26_FY2026` | `FinanceOutput FY26.xlsx`, `FY2026` sheet |
| `stg_Staff Costs Summary` | `Staff Costs Summary.xlsx`, `Sheet1` |
| `stg_AdditionalServicesForecast` | `Additional Services Forecast.xlsx`, `AdditionalServices Forecast` sheet |
| `stg_SubcontractorForecast` | `Subcontractor forecast.xlsx`, `Sheet1` |
| `Equitix_Measures` | Empty placeholder query for the measure container |

## Build order

Queries depend on each other. If you're pasting them in for the first time, create them in this order:

1. **Foundations**
   - `dimensions/dim_Date_Live.pq`
   - `dimensions/dim_HolidayPolicy_Live.pq` (standalone parameter table; per-year holiday allowance, configurable)
   - `dimensions/dim_StaffCosts_Live.pq` (depends on `stg_Staff Costs Summary`, `crbb5_bamboohr`, `dim_HolidayPolicy_Live`)
2. **Core dimensions**
   - `dimensions/dim_Employee_Live.pq` (depends on `crbb5_bamboohr`)
   - `dimensions/dim_Accounts_Live.pq` (depends on `stg_FinanceOutput FY26_CoA`)
   - `dimensions/dim_Project_Live.pq` (depends on `crbb5_project`, `crbb5_contractregister`)
   - `dimensions/dim_Transaction_Live.pq` (depends on `stg_FinanceOutput FY26_FY2026`)
   - `dimensions/dim_ForecastSnapshot_Live.pq` (standalone)
   - `dimensions/dim_ForecastVersion_Live.pq` (depends on `crbb5_jedoxallocation`)
3. **Helpers** (load-disabled — these are sub-queries that get appended into the facts)
   - `helpers/_Revenue_*.pq` — note `_Revenue_Forecast_OOC` depends on `stg_AdditionalServicesForecast` (delivered SharePoint file, by month + project code)
   - `helpers/_Revenue_Adjustment_iXBRL.pq` — Additional Services iXBRL reclassification, derived from `stg_FinanceOutput FY26_FY2026` (no input file). Emits `Type = "Adjustment"` rows that net to zero overall
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

## Missing Data Troubleshooting

Before changing M code for blank helpers, facts, or measures, verify the source workbook state. A client-saved Excel filter can hide rows from the source table or worksheet and make downstream queries appear empty even when the `.pq` logic is correct.

Keep troubleshooting changes to the exact request. If a possible model issue, normalization issue, or cleanup opportunity is found while investigating missing data, record it as a finding and get explicit approval before changing the implementation.

First checks for missing actuals or forecast rows:

1. Open the source Excel file used by the staging query.
2. Clear filters on the relevant worksheet or Excel table.
3. Confirm the expected account, project, and date rows are visible in Excel.
4. Save the workbook after clearing filters.
5. Refresh Power BI and then re-check the staging query before debugging helpers.

If rows are present in staging but missing later, continue with query-step checks in the affected helper, especially account-code filters, cutover-date filters, and joins to dimensions.

## Naming convention

Every query name carries the **`_Live`** suffix so the new model can coexist with the existing one during development. After Phase 5 verification, run Phase 6 (swap-over) to drop the suffix.

## Companion documents

- **`docs/Power BI Refactor Plan.md`** — step-by-step task instructions, definition-of-done per task.
- **`docs/Power BI Schema Audit - Equip Profitability Report.md`** — full schema context, business rules, client meeting notes.
- **`docs/Client Decision Log.md`** — dated client decisions and exact quoted rationale for account-code/reporting rules.
