---
tags: [equitix, power-bi, audit]
project: "[[Equitix]]"
---

# Power BI Schema Audit, Equip Profitability Report

Companion to [[Power BI Refactor Plan]].

> 03 Jul 2026 amendment: OOC actual/report revenue uses account code `40013` only. `40014` was previously included, but the client later excluded it because "40014 is recharged cost." OOC forecast remains the Additional Services stream using `40014`. The current sprint hierarchy is `Sector -> Contract -> Project Display`; Region split/filtering is deferred.

Source: 21 video clips + 4 screenshots in `D:\Projects\Equitix\schema capture\` captured 2026-05-22, plus initial recording `2026-05-21 18-12-28.mkv`, plus four meeting / Q&A transcripts (kickoff 2 April, catch-up 21 April, weekly check-in 13 May, follow-up clarifications). Transcript source notes are archived at [[2026-04-02 - Synetec Equitix Kick-off - Contract Profitability Reporting]], [[2026-04-21 - Equitix Profitability Reporting Catch Up]], and [[2026-05-13 - Equitix Profitability Reporting Weekly Check-in]]. These transcript notes are historical only where later decisions conflict. For each table the Data panel was expanded so all column names are visible directly. No Model/Relationships view was captured, so relationships below are **inferred from column names and values**.

Sigma symbol (`Σ`) marks numeric/measure columns. Calendar icon marks date columns. All other columns are text/lookup.

## Ownership of each layer

This is important context for reading the issues list below — it determines who needs to act on each item.

| Layer | Origin | Owner | Editable? |
|---|---|---|---|
| `crbb5_*` (5 tables) | Client's Dataverse | Equitix | Read-only for us. Schema changes need client engagement. |
| `dogma_*` (3 tables) | Client's Dataverse (Dogma timesheet system) | Equitix | Read-only for us. |
| `stg_*` (7 tables) | Client's SharePoint Excel files | Equitix (file maintenance) | Read-only as data, but column names / file layout can be discussed with the client. |
| `dim_*` (6 tables) | **Built by [[Synetec|Synetec]]'s junior developer** as part of this engagement | [[Synetec|Synetec]] | **Fully editable. Currently work in progress.** |
| `fact_*` (4 tables) | **Built by [[Synetec|Synetec]]'s junior developer** | [[Synetec|Synetec]] | **Fully editable. Currently work in progress.** |
| `Equitix_Measures` | [[Synetec|Synetec]] | [[Synetec|Synetec]] | Measure container. |

**Implication**: most of the issues flagged in this audit (star-schema violations, typo'd column names, duplicate columns, fact-equals-dim schemas, wide-pivoted tables not unpivoted, missing `dim_Date`) are **internal [[Synetec|Synetec]] to-do items on a work-in-progress build**, not data quality problems to escalate to the client. The Questions for the next client meeting section below has been split to reflect that.

## Source workbook structure (SharePoint)

The checked-in source exports live in `Equitix.PowerQuery/sources` (plural). The SharePoint `stg_*` queries are not one independent workbook each: they are sheets across **five Excel workbooks** maintained by Equitix on SharePoint. This count includes the three core workbooks plus the delivered Additional Services and Subcontractor forecast workbooks.

### Workbook 1: `EMS Fixed Fee Forecast.xlsx`

| Sheet | Currently ingested as | Notes / open questions |
|---|---|---|
| `Contracts` | `stg_EMS Fixed Fee Forecast_Contracts1` | Source file currently reads `Item="Contracts"` and skips the first 6 rows before promoting headers. This is the source for live standard in-contract forecast values. **Concern flagged on the diagram**: contracts with entity other than EMS (BWS, ESS) were missing from the FY2026 tab — Chris rebuilt that file, but worth re-validating. |
| `ProjectHARP` | `stg_EMS Fixed Fee Forecast_Project HARP` | Source file currently reads `Item="ProjectHARP"` and contains the wide HARP monthly forecast columns out to 2035. Treat this as the current HARP ingest name unless the workbook is later changed. |
| `Actuals` | `stg_EMS Fixed Fee Forecast_Actuals` | columns: `Transaction Ref`, `Account No.`, `Class: Class External ID`. Slim — only 8 columns. NetSuite actuals subset. |
| `31.12.2025` | `stg_EMS Fixed Fee Forecast_31Dec2025` | legacy snapshot/reference sheet. Do not use it for live standard in-contract forecast values while `Contracts` carries the indexed monthly schedule; using this sheet misses indexation uplift in the forecast. |

### Workbook 2: `FinanceOutput FY26.xlsx`

| Sheet | Currently ingested as | Notes |
|---|---|---|
| `CoA` | `stg_FinanceOutput FY26_CoA` | columns: `Nominal Code`, `Account Name`, `Account Type`, `Balance Sheet`, `Mapping (all null)` — confirms `Mapping` is empty across the board |
| `FY2026` | `stg_FinanceOutput FY26_FY2026` | the NetSuite GL extract. Columns: `Transaction Line ID`, `Transaction Ref.`, `Account No.`, `Memo`, `Customer Full Name`, `Vendor Full Name`, `Class: Class ID`, `Class: Class External ID`, `Location: Location ID`, `Department: Department ID`, `Subsidiary: Full Name`, `Employee: Employee External ID`. **Answered concern**: the diagram asks "Is the MSA ref connected to Memo column in FY2026 tab" — confirmed by client `No, Memo is the invoice description; Project Codes are the correct link` |

### Workbook 3: `Staff Costs Summary.xlsx`

| Sheet | Currently ingested as | Notes |
|---|---|---|
| `Sheet1` | `stg_Staff Costs Summary` | columns: `Employee # (ID)`, `Time@work Reference`, `Year (2025, 2026)`, `Costs for year 2025, 2026` |

### Workbook 4: `Additional Services Forecast.xlsx`

| Sheet | Currently ingested as | Notes |
|---|---|---|
| `AdditionalServices Forecast` | `stg_AdditionalServicesForecast` | OOC revenue forecast; skips first 4 rows, promotes headers, then feeds `_Revenue_Forecast_OOC` with account code `40014`. |

### Workbook 5: `Subcontractor forecast.xlsx`

| Sheet | Currently ingested as | Notes |
|---|---|---|
| `Sheet1` | `stg_SubcontractorForecast` | Subcontractor cost forecast; skips first 2 rows, promotes headers, then feeds `_Cost_Subcontractor_Forecast`. |

(**Note**: `dogma_timesheet` shown on the diagram is **not** in this workbook — it lives in Dataverse. Excluded here.)

### Cross-workbook links observed on the diagram

These are the joins that wire the workbooks together — they're what the Power Query ingest needs to materialise into our `fact_Revenue` / `fact_Cost` joins:

| From | To | Key |
|---|---|---|
| `Contracts` → `FY2026` | join via `Project Code` — **corrected**: `FY2026` has no Project Code column, so the key is `Class: Class External ID` (which holds the project code, e.g. `ASH-01`) |
| `ProjectHARP` → `FY2026` | join via `Project Code` (HARP is one project's worth of rows in FY2026) |
| `Actuals` → `FY2026` | shared `Transaction Ref` / `Account No.` |
| `CoA` → `FY2026` | join via `Account No.` to `Nominal Code` |
| `FY2026` → `Employee Info` | join via `Employee: Employee External ID` ↔ `Employee #` |

### Open items on the diagram to confirm

1. **HARP workbook naming** — source control currently reads the wide HARP forecast from `ProjectHARP`. If Equitix later reintroduces or renames a separate HARP forecast sheet, update `stg_EMS Fixed Fee Forecast_Project HARP` and this audit together.
2. **`31.12.2025` sheet** — is this a one-time snapshot, or does the workbook get a new dated sheet every quarter / month?
3. **Sheets that exist but aren't ingested** — does the developer's Power Query touch every sheet, or are some ignored? `Actuals` is in the diagram but lightly used; `ProjectHARP` may overlap with HARP rows in `Contracts`.
4. **Subsidiary path in `Contracts`** — does the sheet hold contracts only for EMS UK, or all four subsidiaries (EMS UK / ESS / BWG / BWS)? Chris said the FY26 file was rebuilt to include BWS and ESS; confirm the same holds for `Contracts`.

## Architectural principle

**`stg_*` and `crbb5_*` (and `dogma_*`) tables must not be referenced directly by report visuals or measures.** They are source / staging layers. Everything the report consumes must first be materialised into a `dim_*` or `fact_*` table.

Why this matters:

- Source / staging schemas can change without notice (especially the SharePoint Excel files), and visuals bound to them break silently.
- The `crbb5_*` layer carries Dataverse system noise — audit fields, Yomi names, lookup GUIDs — that should be stripped before consumption.
- The dashboard's verdict needs to be expressed against `dim_*` / `fact_*` columns so a developer can implement it without re-deriving the chain each time.
- Hiding source tables from Report View is the simplest enforcement: `IsHidden = true` on every `stg_*`, `crbb5_*`, `dogma_*` table.

**Consequence for this audit**: wherever the dashboard achievability table currently cites a `stg_*` or `crbb5_*` column as a source, that's shorthand for *"this data needs to land in a new (or existing) `dim_*` / `fact_*` table first, sourced from the named staging column"*. The Internal [[Synetec|Synetec]] to-do list below names the specific new tables required.

## Confirmed business rules (from meeting transcripts)

The transcripts answer several questions left open by the schema-only inference. Capturing them here so they aren't lost:

### Revenue classification — by NetSuite Account Code
| Account Code | Account Name | Contract Type | Notes |
|---|---|---|---|
| `40010` | Operational revenue | **In Contract** | confirmed by Chris Rolls 13/05 |
| `40011` | Construction revenue | **In Contract** | confirmed |
| `40012` | Development revenue | **In Contract** | no balance currently — historical / future only |
| `40013` | Out of contract | **Out of Contract** | actual/report OOC revenue; client rule: "Revenue OO-contract total should equal to the sum of 40013 (account no.) in the FinanceOutput FY26 data set." |
| `40014` | Additional services / recharged costs | **Out of Contract** | retained for OOC forecast only. Previously included in actual OOC revenue, then excluded because "40014 is recharged cost." |

Only these five account codes feed the report's revenue measures.

### Cost classification — by NetSuite Account Code
| Account Code | Account Name | Cost Category | Notes |
|---|---|---|---|
| `60201` | Subcontractor costs | **Subcontractor** | actual subcontractor reconciliation; client rule: "Total subcontractor costs should equal the sum of 60201." |
| `60202` | Subcontractor costs | **Subcontractor** | confirmed by Chris 29/05 — was missing from the earlier list |
| `60203` | Subcontractor costs | **Subcontractor** | confirmed |
| `607xxx` (any 607-prefixed account) | Temporary staff / consultancy fees | **EXCLUDED** | these workers ARE on timesheets, so their cost is already counted via `fact_Timesheet`. Including them as cost here would double-count. (Chris, 29/05 meeting.) |
| (timesheet-derived) | — | **Staff costs** | calculated, not booked to a single account |

The dashboard's "Cost split" chart should expand to three columns: **Staff costs**, **Subcontractor costs**, **Total costs**.

### Contract / project / asset hierarchy
- One **contract** = one **asset** in business terminology. There are ~200 contracts.
- Each contract has **one or more projects**. Project code convention:
  - `…01` = in-contract fixed-fee project (delivers the contracted scope)
  - `…02`, `…03`, `…04` … = out-of-contract additional work streams (per-instance scope adds)
- Sector and region/location are held at **contract** level (in `crbb5_contractregister`) and roll up from there.
- For the current profitability report sprint, the required roll-up is **Sector → Contract → Project**. Region split/filtering is deferred.

### Staff cost calculation — the floor-and-ceiling rule
**Critical**: the staff cost measure cannot be a naive `Hours × Hourly Rate`. From the 21 April catch-up:

- An employee on £500/day has an **expected monthly cost** of `£500 × working days in month` (e.g. £10,875). That figure stays fixed regardless of hours booked.
- If the employee books **more than 7.5 hrs × working days** (e.g. on a stressed project with overtime), the effective hourly rate is **reduced** so total cost equals the monthly expected cost.
- If the employee books **less than 7.5 hrs × working days**, the effective hourly rate is **increased** so total cost still equals the monthly expected cost.
- The cost allocation to projects then uses this adjusted hourly rate × hours per project.
- This is called a "floor and ceiling" — total cost per active employee per month is fixed; only the per-project allocation flexes.

Naive `hours × rate` will overstate cost on overtime-heavy projects and understate cost on light months — both directions matter.

### Unsubmitted timesheets — the `EMS 90` placeholder
- When an employee fails to submit timesheets, an internal placeholder project code **`EMS 90`** captures the missing cost so the reconciliation still balances per employee per month.
- `EMS 90` cost is **not visible to contract leads / sector heads** in the report — it stays in the internal reconciliation only.
- Confirms that "missing timesheets" is a real data quality issue this report needs to handle.

### Forecast sources
| Forecast component | Source | Update mode |
|---|---|---|
| In-contract revenue | `crbb5_billingschedule` (Dataverse) + Excel indexation file | Dataverse live; indexation manual |
| In-contract revenue — **biggest project** with variable fee | separate Excel file, now appended into the same fixed-fee forecast file | manual refresh |
| Out-of-contract revenue (additional services) | **Additional Services Forecast** spreadsheet (SharePoint Data folder) | manual file. **Delivered** — broken down by month + project code, so no YTD-actual subtraction is needed (each row is that month's forecast). |
| Costs (staff) | **Jedox (API)** — % of each employee's time per contract × day rate | live API |
| Costs (subcontractor) | **Subcontractor Forecast** spreadsheet (SharePoint Data folder) | manual file. **Delivered** — by month + project code. |

Reporting note:
- HARP may continue to be ingested from its own `ProjectHARP` staging query because the worksheet shape differs from the standard contract forecast sheet, but it should not appear as a separate report dataset or separate forecast column. In report measures it belongs inside the single **in-contract forecast** stream.

This **resolves the ❌ in the dashboard assessment**: out-of-contract forecast revenue exists as a data feed, supplied as the **Additional Services Forecast** spreadsheet (now delivered to the SharePoint Data folder) — it isn't from the four `stg_EMS Fixed Fee Forecast_*` tables already in the model. Ingest it via a new staging table `stg_AdditionalServicesForecast`.

### Refresh cadence and audience
- Group ledger closes by working day 5 each month.
- Monthly refresh target: around the **10th–11th** of each month, with a 1-day contingency window for QA before going live to viewers.
- Audience: ~**40 associate directors + directors** read-only; **Jonjo Challands** and **Chris Rolls** manage data + admin.
- Dataverse tables (`crbb5_*`, `dogma_*`, BambooHR import) are **live**; NetSuite, employee rates and indexation are **manual / monthly refresh**.

### Data quality issues called out by the client themselves
- Employee rates spreadsheet is manually maintained (annual + new hires) — gaps when new starters aren't added.
- BambooHR (`crbb5_bamboohr`) ideally would feed automatically; currently a manual spreadsheet update sits in front of it.
- Indexation assumptions are a separate manual spreadsheet.
- Timesheets are sporadic (some submitted Friday 5pm, some after 7 weeks of chasing) — `EMS 90` exists to absorb this.

## Clarifications received from the latest Q&A round

These supersede / refine some of the earlier inferences. Items marked **(updated)** change a position taken earlier in this document.

### `dim_StaffCosts` — duplicate employee rows
The duplicates we'd otherwise have flagged as a data quality issue have a known cause:
- **Cause**: contractors who became permanent staff get a **new** Employee ID. The contractor ID is prefixed `EMPEMCON*`; the permanent ID is `EMPEM*`. Same person, same Name + Time@work Reference, two `dim_StaffCosts` rows.
- **Examples confirmed by client**:
  - Gill Aran (`EMPEMCON010` → `EMPEM97`)
  - McClure Jim (`EMPEMCON002` → `EMPEM284`)
  - Ramanathan Kirthi (`EMPEMCON019` → `EMPEM300`)
  - Robbins Andrew (`EMPEMCON003` → `EMPEM287`)
- **Scope**: historic data only. 2026 data is clean.
- **Action for developer**: build a contractor-to-permanent EmployeeID mapping (or always join on `Time@work Reference` rather than `EmployeeID`) so historic comparisons don't double-count.

### `dogma_timesheet` to `dim_StaffCosts` join — (updated)
Earlier inferred as joining via `crbb5_originalprojectcode`. **Corrected**: in Power Query, expand the `systemuser(owninguser)` lookup on `dogma_timesheet` and surface `crbb5_timeworkreference`. The join key from `dogma_timesheet` to `dim_StaffCosts` is then **`Time@work Reference`** (`crbb5_timeworkreference` ↔ `TimeWorkReference`). Employee ID is unreliable for the join because of the contractor → permanent ID change.

### Day-rate to hourly conversion — country-dependent — (updated)
`dim_StaffCosts.StaffCostPerDay` is the canonical figure. **The day-to-hour divisor depends on the employee's country**:
| Country | Standard working day | Divisor for hourly rate |
|---|---|---|
| UK | 7.5 hours | `StaffCostPerDay / 7.5` |
| Ireland | 7.5 hours | `StaffCostPerDay / 7.5` |
| Italy | 8 hours | `StaffCostPerDay / 8` |

The existing `dim_StaffCosts[StaffCostPerHour]` column likely uses a flat `÷7.5` for everyone — this will be wrong for Italian staff. The Power Query step should compute `StaffCostPerHour` conditionally on country (sourced from `crbb5_bamboohr[Country]`).

### Staff cost calculation rule — simplified — (updated)
The floor-and-ceiling rule documented in the **Confirmed business rules** section above has been **withdrawn**. From the latest Q&A: *"We're going to revert to simpler calculation method and just apply cost irrespective of hours worked per day"*. Awaiting the next call for the exact wording, but the direction is:

- Use the day rate (or hours × hourly rate) as-is.
- Do **not** cap or equalise against an expected monthly cost.
- Implication: overtime-heavy months will read as more expensive; light months will read as cheaper. The client has accepted that trade-off in exchange for a simpler formula.

The audit's prerequisite **#5** below is therefore **reduced in scope** — just hours × country-aware hourly rate, with `EMS 90` exclusion still applying.

### `fact_FinanceFY2026` rebuild and Transaction ID concat — (updated)
- An earlier bug meant contracts owned by entities other than EMS (BWS, ESS) were missing from FY2026. **Now rebuilt** and they should be included.
- NetSuite **has no native unique identifier for transaction lines**. To produce a unique key, **concatenate** `Transaction ID` and `Transaction Line ID`. Example: `763933-0`, `763933-1`. This becomes the natural key for `fact_FinanceFY2026` and the join to `dim_Transaction[TransactionLineKey]`.

### Subsidiary hierarchy in NetSuite — confirmed paths
The colon-separated path in `dim_Transaction[Subsidiary: Full Name]` is the NetSuite subsidiary hierarchy. Full paths confirmed:
| Subsidiary | Full path |
|---|---|
| EMS UK | `TOP : PTL : PBL : EHL : EMI : EMS` |
| EMS Italy (ESS) | `TOP : PTL : PBL : EHL : EMI : EMS : ESS` |
| Bridge Wind Management Group (BWG) | `TOP : PTL : PBL : EHL : EMI : EMS : BWG` |
| Bridge Wind Management Services (BWS) | `TOP : PTL : PBL : EHL : EMI : EMS : BWG : BWS` |

These four subsidiaries are all in scope.

### MSA Reference — glossary and prefix meanings
| Prefix | Meaning |
|---|---|
| `MSA` | **M**anagement **S**ervices **A**greement — the contract held with the project company (a.k.a. SPV — Special Purpose Vehicle) |
| `EMS-MSA*` | EMS contract that is **live** |
| `EMS-IT*` and `EMSI-IT*` | **Legacy numbering** from when the contract register was first set up — briefly used, then dropped. **Do not** indicate Italian (Chris, 29 May meeting). Contracts with these prefixes can still be live or otherwise; the live/active determination comes from **Contract Status** (`crbb5_contractstatus`), and the country determination comes from **Subsidiary** (ESS = Italian; EMS/BWG/BWS = UK), NOT from the MSA prefix. |
| `EMS-PR*` | Projects in **Pipeline phase** — no signed MSA yet. **Excluded** from the profitability report (Chris, 29 May meeting) — only Live / Mobilised / Live-Stage contracts are in scope. |
| `HARP` | **H**aweswater **A**queduct **R**esilience **P**roject — a single large project contract. MSA `EMS-MSA289`, project code `HAP-03`, Project Type **Construction**, Supersector **Environmental Services**. Posts to **40011 Construction revenue** for its 9-year construction phase, then switches to 40010 Operational. |

### Project Code is the link to NetSuite — not MSA Reference — (updated)
The earlier inferred relationship `dim_Contracts[MSA Reference] ↔ fact_FinanceFY2026` is **wrong**. Confirmed by client:
- The `Memo` column in `fact_FinanceFY2026` is the invoice/transaction description text — **not** linked to MSA Reference.
- **Project Codes are the correct link**. Projects are children of contracts, so the chain is:
  `fact_FinanceFY2026[Project Code]` → `dim_Project[crbb5_projectcode]` → `crbb5_project[crbb5_contract]` → `dim_Contracts[MSA Reference]`
- **Corrected source**: the GL extract (`stg_FinanceOutput FY26_FY2026`) carries no Project Code column; the value comes from `Class: Class External ID` and is renamed to `Project Code` during ingest.

### New dimension level — Portfolio
A reporting level the audit did not capture: **Portfolio** sits between Sector and Contract/Asset. Some projects are wrapped into a Portfolio so groups of contracts can be appraised together (examples: `Apollo`, `Caterham`).
- **Source**: `crbb5_contractregister[crbb5_portfolio]` (text field). Also surfaced in `dim_Project[crbb5_portfolio]`.
- **Hierarchy with this level included**:
  `Sector → Portfolio → Asset (Contract) → Project`

This must be added as a slicer on both sheets, and as an optional roll-up level in the project profitability table.

### Sector field — confirmed canonical column
Of the two sector columns previously flagged (`crbb5_supersectorchoicename` vs `crbb5_supersectorcontractname`), the **canonical** one is **`crbb5_supersectorchoice`** in the contract register (denormalised as `crbb5_supersectorchoicename` in `dim_Project`).
- Possible future change: report may pivot to `crbb5_upstreamreporta` for an "Upstream reporting" hierarchy. Build the sector slicer so this can be swapped easily (e.g. a single named measure `[Sector Label]` that points to one or the other).

### Confirmed KPI layer for first release
Client has agreed the Sheet 1 KPI layer as:
- Total Revenue
- Time-Based Cost (per employee)
- Total Costs
- Total Profit
- Profit Margin %

With drill-down by Sector → Portfolio → Asset/Project → Contract.

Client also asked the dashboard to:
- Show **subcontractor costs as a distinct KPI** feeding into Total Costs. Latest actual reconciliation uses account `60201` only: "Total subcontractor costs should equal the sum of 60201."
- Separate **In-contract and Out-of-contract revenue** at the KPI layer (both feed Total Revenue but should be visible side-by-side).

Both of these were already in the Sheet 1 design — confirmed as required, not optional.

### Outstanding items pending the next call

#### ✅ Resolved
- **Staff-cost formula** — resolved & validated. See Final staff-cost formula section below. YUN-01 worked example gives a reconciliation target of **£77,755.65**.
- **Blank `Location: Full Name`** — defaults by subsidiary (ESS → Italy; EMS/BWG/BWS → UK).
- **OOC revenue forecast source** — delivered: Additional Services Forecast (wide monthly, header row 5) → `stg_AdditionalServicesForecast`.
- **Subcontractor cost forecast source** — delivered: Subcontractor Fees Forecast (wide monthly, header row 3) → `stg_SubcontractorForecast`.
- **Rate type** — client provides **day rates** directly in the `2025` / `2026` columns of `Staff Costs Summary`. No `/261` step.

#### ✅ Resolved at the 29 May meeting
- **HARP revenue account** → **40011 Construction** (currently). Switches to 40010 Operational after HARP's 9-year construction phase ends.
- **`EMS-IT*` / `EMSI-IT*`** → **both are legacy numbering** from when the contract register was first set up. They do **not** indicate Italian. Country is identified by **subsidiary**: `ESS` → Italian, `EMS / BWG / BWS` → UK.
- **Subcontractor account codes** → **60201, 60202, 60203** (we were missing 60202). Helpers and `dim_Accounts` updated.
- **Temp staff / agency invoice accounts** → **any code starting `607`** (607xxx). These workers are already on timesheets — excluded from `_Cost_Other_Actuals` to prevent double-counting.
- **Pipeline contracts (`EMS-PR*`)** → **excluded** from profitability. Only **Live / Mobilised / Live-Stage** statuses in scope. `dim_Project_Live` now expands `crbb5_contractstatus` and derives `IsInScope`. Full status list to keep is pending from Chris.
- **Mid-year rate changes** → **not expected.** Annual assumption stays. Nice-to-have for future flexibility (would need a monthly rate profile if introduced).
- **Forecast on YTF table** → **remaining months only.** Actual + Forecast must sum to total. **Cutover day = 12th of the month** (before the 12th, current month is still forecast; from the 12th, prior month flips to actual).
- **VM clipboard** → Sanjana's workspace access upgraded from Contributor to **Member**. To retest.
- **Fabric** → Dashboard 1 has been published to the Fabric workspace; client team to review.

#### ✅ Resolved by the 02 Jun 2026 email + workbook

**Jedox forecast calculation** — confirmed: `crbb5_value` is the % of FTE time. Full formula (`value × RevisedAnnualCost`, with `RevisedAnnualCost` computed in `dim_StaffCosts_Live` from `WorkedDays × DayRate`) is implemented across `dim_StaffCosts_Live` + `_Cost_Staff_Forecast`, with monthly expansion. Holiday allowance per year held in the new `dim_HolidayPolicy_Live` parameter table (configurable as Chris requested). See the "Decisions from the 02 Jun 2026 …" section above for the full worked example.

**Contract statuses to include** — confirmed: **Live, Mobilised, Terminated**. `dim_Project_Live[IsInScope]` updated.

#### 🟡 Still open — pending Chris

**2025 financials feed.** Sanjana asked for 2025 NetSuite data alongside FY26 for YoY comparisons. Chris will deliver as a **separate Excel file** in the Data folder. Ingest into a new staging table on arrival.

**Timesheet data scope.** Dogma has 2023+ data; we currently ingest only 2026. When the 2025 financials arrive, we likely want 2025 timesheets too for a like-for-like comparison.

## Decisions from the 02 Jun 2026 staff-cost forecast email (most recent — supersede everything below)

Chris's email + the attached `Profitability model - forecast costs.xlsx` workbook lock down the staff-cost forecast formula and the contract-status filter.

### Staff-cost forecast formula (confirmed)
For each `(employee, year)`:
- **`HoursRatio` = `crbb5_bamboohr.crbb5_contracthours` / FullTimeHours**, where FullTimeHours = 37.5 (UK / Ireland) or 40 (Italy). This is the FTE factor — handles part-timers.
- **`NetWorkingDays(year)`** ≈ 261 for 2026, computed dynamically.
- **`HolidayDays`** = 28 (the **average** rounded across all staff; the tenure-based range is 26–30). Configurable per year — held in `dim_HolidayPolicy_Live`.
- **`PublicHolidayDays`** = 8 (UK). Also in `dim_HolidayPolicy_Live`.
- **`WorkedDays`** = `(NetWorkingDays − HolidayDays − PublicHolidayDays) × HoursRatio`.
- **`AnnualCost`** = `NetWorkingDays × HoursRatio × DayRate`.
- **`RevisedAnnualCost`** = `WorkedDays × DayRate`. This is the cost net of holiday allowance — the per-employee envelope that gets allocated to projects.

For each Jedox row `(employee, project, year, crbb5_value)`:
- **`AnnualForecastCost`** = `crbb5_value × RevisedAnnualCost`.
- **`MonthlyForecast`** = `AnnualForecastCost / 12` (evenly spread across 12 months).

**Worked example (Chris's workbook, full-time UK staff on £500/day, 2026):**
- HoursRatio = 1.0; NetWorkingDays = 261; WorkedDays = 225; RevisedAnnualCost = £112,500; AnnualCost = £130,500.
- 25% on YUN-01 → £28,125 annual / £2,343.75 per month.
- Overhead (= AnnualCost − RevisedAnnualCost) = £18,000 — **classed as overhead, NOT shown in sector profitability tables**.

**Part-time example (20 h/wk, same rate):**
- HoursRatio = 0.5333; RevisedAnnualCost = £60,000.
- 25% on YUN-01 → £15,000 annual / £1,250 per month.

### Contract status filter (confirmed)
The `crbb5_contractstatus` values to include in profitability: **`Live`, `Mobilised`, `Terminated`** ("these 3 stages all indicate a Live or previously-Live contract"). All others (including Pipeline) are excluded. `dim_Project_Live[IsInScope]` updated accordingly.

### What this means for the model
- New parameter table **`dim_HolidayPolicy_Live`** holds the per-year holiday + public-holiday allowance. Configurable.
- `dim_StaffCosts_Live` extended with `ContractHours`, `HoursRatio`, `NetWorkingDays`, `WorkedDays`, `AnnualCost`, `RevisedAnnualCost`.
- `_Cost_Staff_Forecast` rewritten: `value × RevisedAnnualCost`, then expanded to 12 monthly rows so the cutover-date measures can filter by `Date`.
- The overhead bucket (holiday cost per employee) is **not emitted** to `fact_Cost_Live` — explicitly excluded from sector reporting.

## Decisions from the 29 May 2026 Dashboard + Data Clarifications meeting (still in force, except where superseded above)

Walked through Eve Dillon's staff-cost worked example for YUN-01 (UK project, ÷ 7.5 divisor) and ran the open questions list. Resolutions:

1. **Identifying Italian staff.** Eve confirmed Italian employees can be identified from BambooHR's `crbb5_country` AND from the timesheet's `owning business unit name`. Our model already uses `crbb5_country` — no change needed; the business-unit-name path is a fallback.
2. **Italian contracts.** `EMS-IT*` and `EMSI-IT*` are both **legacy contract-register numbering** that was briefly used and dropped. Neither prefix indicates Italian. **Country comes from subsidiary** (ESS → Italian, EMS/BWG/BWS → UK). This corrects our earlier inference.
3. **Contract scope for profitability.** Only **Live / Mobilised / Live-Stage** contracts are in scope. **Pipeline** contracts (`EMS-PR*` and others) are excluded by default. Chris will send the full list of contract statuses with the include/exclude decision per value.
4. **HARP revenue account.** `40011 Construction` for the 9-year construction phase; switches to `40010 Operational` after. Our helper default (40011) is correct.
5. **Subcontractor account codes.** `60201 / 60202 / 60203` — we were missing `60202`. Fixed.
6. **Temp staff / agency invoices.** Any account starting `607*` is temp staff or consultancy fees — these workers ARE on timesheets, so the cost is already captured. **Excluded** from `_Cost_Other_Actuals` to avoid double-counting.
7. **Mid-year rate changes.** Not expected. The annual-rate assumption is fine.
8. **YTF forecast columns = remaining months only** (not full-year). Actual + Forecast must sum to total.
9. **Report cutover day = 12th of the month.** Before the 12th, the current month is still treated as forecast; from the 12th onward, the prior month flips to actual. Chris noted books close ~working day 5 and they need a couple of days reporting time — the 12th covers that.
10. **2025 financials.** Sanjana asked for 2025 NetSuite data alongside FY26 for YoY comparisons. Chris will deliver as a **separate Excel file** in the SharePoint Data folder.
11. **Jedox forecast calculation.** `crbb5_value` is most likely a **% of FTE time** (0.25, 0.15 etc.) rather than days. Naive `value × 261 × DayRate` over-states because the 261 base includes holidays / annual leave that aren't on the actuals side (which only count booked timesheet hours). Chris is preparing a **worked example** mirroring the YUN-01 actuals one, with a standard holiday-day allowance stripped from the 261-day base (not per-employee tenure-based). Update `_Cost_Staff_Forecast` formula on receipt.
12. **VM clipboard / scripts.** Chris upgraded Sanjana's workspace access from **Contributor to Member**, which should restore copy-paste from her local machine into the VM. To retest.
13. **Fabric / Dashboard 1.** Sanjana has published Dashboard 1 to the Fabric workspace. Client team to review.

## Decisions from the 27 May 2026 weekly check-in (still in force, except where superseded above)

[[Synetec|Synetec]] demoed the first build of the two PoC tables (sectors split on the super-sector route; columns: revenue actual in/out of contract, total revenue, staff cost, profit, margin). Chris's feedback:

1. **Sector axis = sector NAME, not the numeric ID.** The top of the hierarchy should be the sector name (Social Infrastructure, Renewables, …). The numeric "Sector 1/2/3" is *"just a table ID"* and should not be displayed. → in `dim_Project`, surface `crbb5_supersectorchoicename`, not the numeric `crbb5_supersectorchoice`.
2. **Project rows = code + name together.** Under each sector, show the project with **both its Project Code and Project Name** merged into one label (e.g. `Project Display = "<code> - <name>"`). People recognise the codes, but the full description is clearer. → add a merged `Project Display` column to `dim_Project`.
3. **Staff-cost calculation verbally re-confirmed.** *"the hours booked for the timesheet times by the hourly cost of the staff members is the correct calculation"* — matches the email and the build. Source is the `dogma_timesheet` duration.
4. **Margin sanity check.** Chris expects sector **margins around 50–55%** because a lot of time is booked to these projects (high staff cost). Use this as a validation target — a much higher margin signals under-counted staff cost (missing timesheets, unmatched rates, or `EMS 90` leakage).

## Decisions confirmed in the post-meeting (Dashboard and Data Clarifications)

These are from the working call **after** the Wednesday meeting — the most recent Q&A round. They supersede everything earlier.

### Final staff-cost formula — confirmed simple model

The floor-and-ceiling rule is **definitively withdrawn**. Chris's exact words: *"we will literally keep it… we will literally just apply it direct to the hours worked is the simplest way of doing it"*.

The formula:

```
Day rate     = stg_Staff Costs Summary [2025] / [2026] column (provided directly, £/day)
Hourly rate  = Day rate / Hours-per-day where Hours-per-day = 7.5 UK+IE, 8 Italy
Project Cost = Timesheet hours booked × Hourly rate
```

Behaviour:
- No monthly cap, no floor, no ceiling, and **no adjustment for time booked over or below the standard worked hours per day** — the hourly charge is applied straight to the hours booked by project. *"We won't sort of scale it up or down."*
- If someone books overtime, the project cost legitimately goes up (the company doesn't pay more, but the project carries the higher cost — accepted trade-off).
- If someone books less than full hours, the unbooked time goes to **holiday / non-chargeable / overhead** and is **not allocated to projects**: *"only the costs being booked to the projects will be the cost that sits in the profitability."*

**Rate type — RESOLVED (confirmed by data):** `stg_Staff Costs Summary` holds **day rates** directly in its `2025` / `2026` columns (verified against the dim_StaffCosts sample — Agnew 241.55/day → 32.21/hr at ÷7.5). Take `DayRate` straight from the year column and apply the country divisor (7.5 UK/IE, 8 Italy). There is **no `/ 261`** step.

**Worked example — project `YUN-01`** (client-provided reference workbook, in the Data folder). The formulas shown:

```
Total Cost  = [2025 Cost] + [2026 Cost]
2025 Cost   = IFERROR(XLOOKUP([User Reference], $B:$B, $E:$E, 0) / 7.5 * [2025 Hours], 0)
2026 Cost   = IFERROR(XLOOKUP([User Reference], $B:$B, $F:$F, 0) / 7.5 * [2026 Hours], 0)
```

Expected totals for `YUN-01`: **2025 £58,770.73 + 2026 £18,984.92 = £77,755.65**. Per-employee samples: ATE £6,721.41, DTH £8,917.51, RLU £11,499.82, TWH £44,495.80.

This is mathematically equivalent to our model: `fact_Timesheet[Cost] = Duration × StaffCostPerHour`, then summed across the year per (employee, project). Use this as the **Phase 5 staff-cost reconciliation target**.

Note: the example hard-codes `÷ 7.5` because every employee in the YUN-01 sample is UK/IE. The country-aware rule (`÷ 8` for Italy) still applies in the general model — confirmed by the earlier email and unchanged. The `IFERROR(..., 0)` defaults to zero when a rate is missing; `fact_Timesheet_Live[Cost]` now mirrors this with `if StaffCostPerHour = null then 0 else ...`.

### Future enhancement — proportional overhead allocation (Phase 2)

Chris flagged this for later, **not** in the first release:
- Non-chargeable / holiday / public-holiday cost currently has no project home — it's overhead.
- Eventually they want to **proportionally allocate** that overhead across projects (on a revenue basis, time basis, or other — TBD).
- Defer to phase 2. The first release leaves overhead as un-allocated overhead.

### Subcontractor cost forecast — DELIVERED

Originally confirmed by Chris as a forthcoming SharePoint file; **now delivered** (client email: *"Within the shared Data folder I have now saved … Subcontractor forecast files … they should be brought into the model by month and project code"*).

Confirmed (structure now verified from the delivered file):
- **Source**: **Subcontractor Fees Forecast** spreadsheet, SharePoint shared **Data** folder → `stg_SubcontractorForecast`.
- **Layout**: **WIDE monthly** — header row is **row 3** (title + blank above). Columns: `Netsuite N/C` (the account code, 60201), `Project Code`, `Department`, `Location`, then one value column per month-end (`1/31/2026`…`12/31/2026`).
- `Netsuite N/C` → `Account Code`; `Project Code` joins `dim_Project`. Staging query must skip the title rows + promote row 3, then unpivot the month columns.

Action: ingest into `fact_Cost[Type=Forecast, Category=Subcontractor]` via `stg_SubcontractorForecast`. See `Equitix.PowerQuery/helpers/_Cost_Subcontractor_Forecast.pq`.

### OOC revenue forecast (Additional Services) — DELIVERED

The out-of-contract / additional-services revenue forecast — earlier expected as "Grant's standalone table" — has **now been delivered**: the **Additional Services Forecast** spreadsheet in the SharePoint Data folder → `stg_AdditionalServicesForecast`.

Structure verified from the delivered file:
- **WIDE monthly** layout — header row is **row 5** (title + a note + blanks above; the note confirms *"Project code is chosen to allow modelling to remain inline with the rest of the forecast model. Supersector is the top level for profitability reporting data"*).
- Columns: `Supersector`, `Sector`, `Upstream Reports`, `Project Code`, `Department`, `Location`, then one value column per month-end. `Project Code` joins `dim_Project`; the file also carries its own `Supersector`/`Sector` names.
- Because it is per-month, the earlier "whole-year minus YTD" approach is **not required** — full-year is a SUM. Staging query must skip the title/note rows + promote row 5, then unpivot.

Ingest into `fact_Revenue[Type=Forecast, Contract Type=Out of Contract, Account Code=40014]`. See `Equitix.PowerQuery/helpers/_Revenue_Forecast_OOC.pq`.

### `dogma_timesheet` → staff cost join — corrected

Chris confirmed: use **`crbb5_crbb5_timeworkreferencename`** (note the doubled `crbb5_`). This **supersedes** the earlier guidance to use `systemuser(owninguser).crbb5_timeworkreference`.

Reason given by Chris: *"I think it's a workaround because some of the users don't show in that particular table. So the other table just brings everyone in to make sure that's populated."* — the column-naming convention is awkward, but it's the one that has full coverage. Use it.

### Blank `Location: Full Name` — resolution

For rows in `FinanceOutput FY26.xlsx > FY2026 sheet` where `Location: Full Name` is blank, **default by subsidiary**:

| Subsidiary path ending | Default Location |
|---|---|
| `ESS` | Italy |
| `EMS`, `BWG`, `BWS` | UK |

Chris explained: *"only going to be a handful of transactions on the P&L because they should have all been booked, but I bet they were to Italy because they had a period of not booking things properly"*. Apply this default in Power Query during the `fact_Revenue` / `fact_Cost` ingest.

### Default-value policy for missing fields

Chris extended the offer: *"if there's any other problems we can set, we'd be able to set some default values as well if we need to."*

Action: maintain a list of blank-field defaults agreed during build. If a new blank-field issue arises during dev, raise to Chris for a default rather than blocking.

## Confirmed PoC dashboard layout (v2 — from the latest "Profitability Tables PoC v2" workbook)

The client circulated an updated PoC Excel sheet (`Profitability Tables PoC v2.xlsx`) showing the agreed table structure. Two tables, both with **Sector** as the row axis. The "Sector 1–10" labels in the PoC are **placeholders only** — Chris confirmed (27 May) the rows should show the actual sector **names** (Social Infrastructure, Renewables, …). The v2 change versus the Wednesday version: **subcontractor costs are now a first-class column in both tables** (the earlier "Direct Costs" label is replaced by "Subcontractor Costs", and "Costs" is now explicitly "Staff Cost").

### Table 1: YTD Profitability

| Group | Columns | Source |
|---|---|---|
| Revenue | `In Contract` | NetSuite — Account Codes 40010/40011/40012 |
| | `Oo Contract` *(= Out-of-Contract)* | NetSuite — Account Code 40013 |
| | `Total Rev` | Sum |
| Costs | `Staff Cost` | Timesheets × Day Rates |
| | `Subcontractor Costs` | NetSuite — Account Code 60201 |
| | `Total Cost` | Sum |
| | `Profit` | Total Rev − Total Cost |
| | `%` | Profit / Total Rev |

### Table 2: YTF (Year-To-Finish) + Forecast Profitability

Same row axis (Sector). Columns split actuals + forecast and roll up to full year:

| Group | Sub-group | Columns | Source |
|---|---|---|---|
| Revenue Act | (YTD actuals) | `In Contract` | NetSuite |
| | | `Oo Contract` | NetSuite |
| Revenue For | (Remaining forecast) | `In Contract` | **Billing Schedule** (Dataverse) + spreadsheet export for inflation adjustments |
| | | `Oo Contract` | **Additional Services Forecast** spreadsheet (delivered, by month + project code) |
| | | `Total Rev` | Sum |
| Cost Act | (YTD actuals) | `Staff Cost` | Timesheets × Employee Day Rates |
| | | `Subcontractor Costs` | Subcontractor actuals (NetSuite 60201) |
| Cost For | (Remaining forecast) | `Staff Cost` | **Jedox × Employee Day Rates** |
| | | `Subcontractor Costs` | **Subcontractor Forecast** spreadsheet (delivered, by month + project code) |
| | | `Total Costs` | Sum |
| | | `Profit` | Total Rev − Total Cost |
| | | `%` | Profit / Total Rev |

Note: this PoC table layout is **narrower** than the earlier proposed dashboard (which had KPI cards + multiple tables). Treat this PoC as the **first release scope** — additional KPI cards, top/bottom 10 tables and DQ tiles from the original design are phase 2. Because both forecast feeds are delivered **by month**, the "Forecast Remaining = Full-Year − YTD Actual" subtraction is **not** needed for the OOC/subcontractor feeds — they are summed per month directly.

**Implications for the model**:
- `fact_Revenue` needs the `Contract Type` dimension (In / Out) — already designed.
- `fact_Cost` needs the `Category` dimension (Staff / Subcontractor / Other) — already designed.
- Both need the `Type` dimension (Actual / Forecast) — already designed.
- Row axis is `dim_Project[Sector]` — already designed.
- Both forecast feeds (Additional Services revenue, Subcontractor cost) arrive **by month**, so the full-year column is a straight SUM of actual + forecast months. The earlier `Forecast Remaining = Full-Year Forecast − YTD Actual` subtraction is **not** required.

## Tables in the model

26 tables, four layers by naming convention. Order matches the Data panel list.

| # | Table | Layer | Source system (inferred) |
|--:|-------|-------|--------------------------|
| 1 | `crbb5_bamboohr` | Source | Dataverse export of BambooHR |
| 2 | `crbb5_billingschedule` | Source | Dataverse billing master |
| 3 | `crbb5_contractregister` | Source | Dataverse contract master |
| 4 | `crbb5_jedoxallocation` | Source | Dataverse Jedox allocations |
| 5 | `crbb5_project` | Source | Dataverse project master |
| 6 | `dim_Accounts` | Dim | derived from `stg_FinanceOutput FY26_CoA` |
| 7 | `dim_Contracts` | Dim | derived from `crbb5_contractregister` + `crbb5_billingschedule` |
| 8 | `dim_Project` | Dim | derived from `crbb5_project` |
| 9 | `dim_StaffCosts` | Dim | derived from `stg_Staff Costs Summary` + `crbb5_bamboohr` |
| 10 | `dim_timesheet` | Dim | derived from `dogma_timesheet` |
| 11 | `dim_Transaction` | Dim | derived from `stg_FinanceOutput FY26_FY2026` |
| 12 | `dogma_timesheet` | Source | Dogma timesheet lines |
| 13 | `dogma_timesheetheader` | Source | Dogma timesheet header |
| 14 | `dogma_timesheetperiod` | Source | Dogma timesheet period |
| 15 | `Equitix_Measures` | Measures | measure container (no data columns) |
| 16 | `fact_Actuals` | Fact | NetSuite GL actuals |
| 17 | `fact_Contracts` | Fact | contracts pre-aggregation |
| 18 | `fact_FinanceFY2026` | Fact | NetSuite GL FY2026 |
| 19 | `fact_ProjectHARP` | Fact | HARP project forecast |
| 20 | `stg_EMS Fixed Fee Forecast_31Dec2025` | Staging | Excel snapshot (wide/pivoted) |
| 21 | `stg_EMS Fixed Fee Forecast_Actuals` | Staging | NetSuite GL extract |
| 22 | `stg_EMS Fixed Fee Forecast_Contracts1` | Staging | contracts staging |
| 23 | `stg_EMS Fixed Fee Forecast_Project HARP` | Staging | HARP staging (wide/pivoted) |
| 24 | `stg_FinanceOutput FY26_CoA` | Staging | NetSuite chart of accounts |
| 25 | `stg_FinanceOutput FY26_FY2026` | Staging | NetSuite GL FY2026 |
| 26 | `stg_Staff Costs Summary` | Staging | Staff costs |

## Columns per table

### 1. `crbb5_bamboohr` (BambooHR employee master, Dataverse)
**Columns `dim_StaffCosts` consumes from here (CONFIRMED against the full column list; exposed by LOGICAL name):**
- `crbb5_timeworkreference` — the join key to `dim_StaffCosts[TimeWorkReference]` (use this logical name, **not** the display "Time@work Reference").
- `crbb5_country` — the employee country, drives the hourly-rate divisor (7.5 UK/IE, 8 Italy). Renamed to `Country`.

**Dataverse audit columns** (also appear on every `crbb5_*` table — listed here once, referenced as "+ Dataverse audit" below):
`Created By`, `Created By (Delegate)`, `Created On`, `createdby`, `createdbyyominame`, `createdonbehalfby`, `createdonbehalfbyyominame`, `Modified By`, `Modified By (Delegate)`, `Modified On`, `modifiedby`, `modifiedbyyominame`, `modifiedonbehalfby`, `modifiedonbehalfbyyominame`, `Owner`, `ownerid`, `owneridyominame`, `Owning Business Unit`, `owningbusinessunit`, `owningteam`, `owninguser`, `Record Created On`, `Import Sequence Number Σ`, `Status Σ`, `statecodename`, `Status Reason Σ`, `statuscodename`, `Time Zone Rule Version Number Σ`, `UTC Conversion Time Zone Code Σ`

**Business columns:**
`Age Σ`, `BambooHR` (key), `Birth Date`, `Budget Holder`, `Budget Holder Lookup`, `Business Unit`, `Business Unit Text`, `Comments`, `Contract Hours Σ`, `Country`, `crbb5_budgetholderlookup`, `crbb5_budgetholderlookupyominame`, `crbb5_businessunit`, `crbb5_managerbackup`, `crbb5_managerbackupyominame`, `crbb5_managerreportingto`, `crbb5_systemuseraad`, `crbb5_systemuseraadyominame`, `Department`, `Eligible For Re-hire`, `Employee #`, `Employment Status`, `Employment Status: Date`, `First Name`, `First Name Last Name`, `Gender`, `Hire Date`, `Hours worked`, `Is Manager = Reporting To`, `Job Title`, `Last Name`, `Length of service`, `Length of service: Years Σ`, `Level Σ`, `Location`, `Manager Backup`, `Middle initial`, `Middle Name`, `Notes: Date Added`, `Notes: Entered By`, `Notes: Note`, `Original Hire Date`, `Pre-Termination Employment Status`, `Reporting to`, `Reporting to (T@W)`, `Status 2`, `System User AAD`, `Termination Date`, `Termination Reason`, `Termination Type`, `Time@work Reference`, `Work Email`, `Work phone + ext.`

### 2. `crbb5_billingschedule` (Billing schedule master, Dataverse)
\+ Dataverse audit columns

**This is the Dataverse home of the billing fields that are NOT on `crbb5_contractregister`** (confirmed against the full column list; exposed by LOGICAL name):
- `crbb5_billingmethod` / `crbb5_billingmethodname` (Billing Method)
- `crbb5_billingstartdate` / `crbb5_billingenddate` (Billing Start / End dates)
- `crbb5_project` / `crbb5_projectname` (link to project)
- `crbb5_item` (Billing Schedule Item, e.g. BSI-001016), `crbb5_billingreference`
- `crbb5_baseannualfee`, `crbb5_currentannualfee`, `crbb5_indexmonth`, `crbb5_indexupliftdate`, `crbb5_inedxationbasis` *(typo — Indexation Basis)*, `crbb5_feetype`

If the report ever needs contract billing method / start / end dates on `dim_Project`, join `crbb5_billingschedule` via `crbb5_project`. (Not needed for the current PoC tables.) Standard in-contract forecast values now come from the `Contracts` sheet in `EMS Fixed Fee Forecast.xlsx`; the `31.12.2025` Excel sheet is retained as a legacy snapshot/reference only.

**Business columns (original capture, mixed display/logical names):**
`Base annual fee Σ`, `Base Currency`, `Base Fee Σ`, `Base Fee (Base) Σ`, `Base Index`, `Base to Current Σ`, `Billing End Date`, `Billing frequency p.a. Σ`, `Billing Method`, `Billing month zero`, `Billing Reference`, `Billing Schedule` (key), `Billing Start Date`, `Billing start month Σ`, `Calculation`, `Client Code`, `crbb5_basecurrency`, `crbb5_billingmethod Σ`, `crbb5_indexcyclethismonth`, `crbb5_indexthismonth`, `crbb5_invoicecyclethismonth`, `crbb5_project`, `Currency`, `Current Annual Fee Σ`, `Current Index`, `Current month Σ`, `Exchange Rate`, `Fee Type`, `Index cycle this month?`, `Index Day of Month Σ`, `Index Month Σ`, `Index this month?`, `Index Uplift Date`, `Inedxation Basis` *(typo: should be "Indexation")*, `Invoice amount current Σ`, `Invoice amount current (Base) Σ`, `Invoice cycle decimal Σ`, plus more below the panel-view fold (Netsuite Description, Notes, etc.)

### 3. `crbb5_contractregister` (Contract register master, Dataverse — largest source table)
\+ Dataverse audit columns

**Columns `dim_Project` consumes from here (CONFIRMED against the full column list):**
- Join key: `crbb5_contractregisterid` (matches `crbb5_project[crbb5_contract]`).
- `crbb5_supersectorchoicename` → `Sector` (the sector **name**). The table also holds `crbb5_supersector`, `crbb5_supersectorchoice`, `crbb5_sectorchoice`, `crbb5_sectorchoicename`, `crbb5_sector` — use the **supersectorchoicename** for the report axis.
- `crbb5_portfolio` → `Portfolio`.
- `crbb5_msareference` → `MSA Reference`.
- `crbb5_concessionexpiry` → `Concession Expiry`.

**NOT on this table** (common mistakes): **Project Type** (`crbb5_projecttypename` lives on `crbb5_project`), and **Billing Method / Billing Start / Billing End dates** (on `crbb5_billingschedule`). Do not expand these from the contract register.

**Business columns (first ~40 visible in the original capture):**
`Amount of EFM Assets`, `Amount of EFM Assets (Last Updated On)`, `Amount of EFM Assets (State)`, `Attachments`, `Automatic Renewal`, `Automatic Renewal Long Stop Date`, `Banking Provider Reference 1`, `Banking Provider Reference 2`, `Banking Provider Reference 3`, `Banking Provider Reference 4`, `Base Currency`, `Base Fee`, `Base Fee (Legacy)`, `Billable Disbursements?`, `Board Meeting Master Ref`, `Budget Lead`, `BudgetLead.EMail`, `BudgetLead.Title`, `Building Contractor`, `Building Contractor 2`, `Business Unit`, `Change Of Control Clause Ref`, `Change of control termination?`, `Client Awarded Preferred Bidder`, `Client can terminate?`, `Client Count`, `Client has prequalified?`, `Client has submitted a bid?`, `Client introducer`, `Client Service Period`, `Closedown Start Date`, `Co-shareholders?`, `Company Count`, `Company Count (Last Updated On)`, `Company Count (State)`, `Company Secretarial?`, `Company Secretary`, `Commission Expiry`, `Confidence - SCD Delay Months`, `Confidence in Client Signature`, `Confidence in Service Commencement Date`, `Construction Management?`
plus many more below the panel-view fold (Editor*, FinanceLead*, Hard FM Contractor, Term Length*, Termination Clause*, Project Code Prefix, Update RAG, crbb5_boardmeetingmasterref, etc.). The full clip runs 2:01 — the longest table by far.

### 4. `crbb5_jedoxallocation` (Jedox allocation lines, Dataverse)
\+ Dataverse audit columns

**Columns the staff-cost forecast (`_Cost_Staff_Forecast`) consumes (CONFIRMED against the full column list; exposed by LOGICAL name):**
- `crbb5_version` — forecast version filter (Forecast / Baseline / …).
- `crbb5_hrreference` — employee HR reference → join to `dim_StaffCosts[TimeWorkReference]`. (Also `crbb5_hrcode`, `crbb5_hrreferencename` exist — confirm which carries the TWR code SAG/CAL/…)
- `crbb5_projectreference` — the project code (EEC-01, …). (Also `crbb5_projectreferencename`, `crbb5_project` lookup.)
- `crbb5_value` — the allocation figure; `crbb5_resourcemeasure` is its unit (days / % / FTE — **TBC**).
- **Period is ANNUAL**: `crbb5_year`, `crbb5_yeardate`, `crbb5_yeartext`. **There is NO "Allocation Date"** — earlier inferred from display names; the data is yearly.

**Open business rule:** what `crbb5_value` represents drives the £ formula — `days × DayRate`, or `% × 261 × DayRate`. The helper currently assumes **days** (`Amount = value × DayRate`); confirm with Chris. Also: Jedox is annual, so the "Cost For (staff)" full-year column is fine as-is, but a monthly spread would need defining if required.

### 5. `crbb5_project` (Project master, Dataverse)
\+ Dataverse audit columns

**Columns `dim_Project` consumes from here (CONFIRMED against the full column list; exposed by LOGICAL name):**
- `crbb5_projectcode` → `Project Code`, `crbb5_projectname` → `Project Name`.
- `crbb5_projecttypename` → `Project Type` (the **text** name, e.g. Operational / Construction — use this, **not** the numeric `crbb5_projecttype` choice ID).
- `crbb5_subsidiaryname` → `Subsidiary` (confirmed).
- `crbb5_contract` → the lookup GUID used to join `crbb5_contractregister[crbb5_contractregisterid]`.
- The entity also exposes its own `Project Display` column, plus `crbb5_supersectorcontract`/`crbb5_supersectorcontractname` (we still take Sector from the contract register's `crbb5_supersectorchoicename` per the canonical-sector decision).

**Business columns:**
`% Revenue Finance Σ`, `% Revenue Ops Σ`, `Approval`, `Approved`, `Approver`, `Baseline Fees Σ`, `Baseline Fees (Base) Σ`, `Baseline Revenue Σ`, `Baseline Revenue (Base)`, `Billing Annual Fee`, `Billing Annual Fee (Last Updated On)`, `Billing Annual Fee Total (Base)`, `Billing Annual Fee Total (Last Updated On)`, `Billing Annual Fee Total (State)`, `Billing Fee Total`, `Billing Fee Total (Base)`, `Billing Fee Total (Last Updated On)`, `Billing Fee Total (State)`, `Billing Profile`, `Client`, `Contract`, `crbb5_approval`, `crbb5_approved`, `crbb5_approver`, `crbb5_approveryominame`, `crbb5_billingprofile Σ`, `crbb5_contract`, `crbb5_jedoxbaseline`, `crbb5_jedoxforecasted`, `crbb5_jedoxpending`, `crbb5_jedoxplanned`, `crbb5_netsuitestatus Σ`, `crbb5_planned`, `crbb5_pmuallocation`, `crbb5_pmuallocationname`, `crbb5_pmustaffallocation Σ`, `crbb5_pmustaffallocationname`, `crbb5_pmustaffallocationreason`, `crbb5_profitabilityhealth`, `crbb5_projectquickstatus Σ`, `crbb5_projectstage`, `crbb5_projectstagecalculated`, `crbb5_projectstagetype`, `crbb5_projecttype Σ`, `crbb5_ratescard`, `crbb5_removejedoxbaseline`, `crbb5_revenueprofile Σ`, `crbb5_revenueprofilename`, `crbb5_sensitive`, `crbb5_service`, `crbb5_subsidiary`, `crbb5_supersectorbasedonresources`, `crbb5_supersectorcontract`, `crbb5_timesheetsrequirenotes`, plus more below fold

### 6. `dim_Accounts` (Chart of accounts dim, from `stg_FinanceOutput FY26_CoA`)
`Account Code`, `Account Name`, `Account Type`, `Balance Sheet`, `Mapping` (blank in data), `Contract Type`

Sample rows:
| Account Code | Account Name | Account Type | Balance Sheet | Mapping | Contract Type |
|---|---|---|---|---|---|
| 40010 | Operational revenue | Income | F | | In Contract |
| 40011 | Construction management | Income | F | | In Contract |
| 40012 | Development revenue | Income | F | | In Contract |
| 40014 | Recharged costs | Income | F | | Out of Contract |

### 7. `dim_Contracts` (Contracts dim)
`BaseAnnualFee Σ`, `BaseCurrencyName`, `Billing Schedule item`, `BillingEndDate`, `BillingMethodName`, `BillingStartDate`, `ConcessionExpiry`, `CurrentAnnualFee Σ`, `Entity`, `Exchange Σ`, `ForecastAmmount Σ` *(typo: should be "Amount")*, `ForecastDate`, `GBP Value Σ`, `IndexMonth Σ`, `Monthly Fee Σ`, `MSA Reference`, `Project`, `Project Code`, `Project Type`, `Supersector`

### 8. `dim_Project` (Project dim)
`crbb5_contractname`, `crbb5_msareference`, `crbb5_portfolio`, `crbb5_projectcode`, `crbb5_projectfees Σ`, `crbb5_projectid`, `crbb5_projectname`, `crbb5_revenueprofile Σ`, `crbb5_revenueprofilename`, `crbb5_subsidiaryname`, `crbb5_supersectorchoice Σ`, `crbb5_supersectorchoicename`, `crbb5_supersectorcontractname`, `createdbyname`, `ownerid`, `owneridname`, `Project Display`

### 9. `dim_StaffCosts` (Staff costs dim)
`EmployeeID`, `TimeWorkReference`, `EmployeeName`, `Year`, `StaffCostPerDay Σ`, `EmployeeNameMatch`, `StaffCostPerHour Σ`

Sample rows:
| EmployeeID | TimeWorkReference | EmployeeName | Year | StaffCostPerDay | EmployeeNameMatch | StaffCostPerHour |
|---|---|---|---|---|---|---|
| EMPEM353 | SAG | Agnew, Samantha | 2026 | £241.55 | Samantha Agnew | £32.21 |
| EMPEM23 | CAL | Allan, Christine | 2026 | £664.96 | Christine Allan | £88.66 |
| EMPEM185 | DAL | Allan, Derrick | 2026 | £0.00 | Derrick Allan | £0.00 |

### 10. `dim_timesheet` (Timesheet dim, from `dogma_timesheet`)
`crbb5_isduplicate`, `crbb5_isownermismatch`, `crbb5_marktodelete`, `crbb5_originalprojectcode`, `dogma_duration Σ`, `dogma_project`, `dogma_projectname`, `dogma_timesheetid`, `ownerid`, `owneridname`, `Year`

### 11. `dim_Transaction` (Transaction dim)
`Account Code`, `Class: Class ID`, `Class: Full Name`, `Department: Department ID`, `Department: Full Name`, `Employee: Employee External ID`, `Employee: First Name`, `Employee: Last Name`, `Location: Full Name`, `Location: Location ID`, `Project Code`, `Subsidary Entity` *(typo: should be "Subsidiary")*, `Subsidiary: Full Name`, `Sum of Amount Σ`, `Transaction Line ID Σ`, `Transaction: Transaction ID`, `TransactionLineKey`

### 12. `dogma_timesheet` (Timesheet lines, Dogma)
\+ Dataverse audit columns

**Confirmed against the full column list — exposed by LOGICAL name.** `fact_Timesheet` must reference the logical names, NOT display names:
- Hours: `dogma_duration` (not "Duration"). Date: `dogma_date` (not "Date"). Project: `dogma_project`.
- Bad-row flags: `crbb5_isduplicate`, `crbb5_marktodelete` (booleans — not "is Duplicate?" / "mark to delete").
- TWR join key: **`crbb5_crbb5_timeworkreferencename`** (the doubled-`crbb5_` name column Chris specified). The list also shows the lower-coverage `systemuser(owninguser).crbb5_timeworkreference` and `systemuser(owninguser).crbb5_crbb5_timeworkreference` — use the **`crbb5_crbb5_timeworkreferencename`** column for full coverage.
- `crbb5_originalprojectcode` (used for `EMS 90` detection).

**Business columns:**
`crbb5_isduplicate`, `crbb5_isownermismatch`, `crbb5_marktodelete`, `crbb5_originalprojectcode`, `Date`, `dogma_project`, `dogma_timesheetheader`, `dogma_timesheetperiod`, `Duration Σ`, `is Duplicate?`, `Is Owner Mismatch?`, `mark to delete`, `Name`, `Original Project Code`

### 13. `dogma_timesheetheader` (Timesheet header, Dogma)
\+ Dataverse audit columns

**Authoritative columns (logical names) — period boundaries + project rollup:**
`dogma_timesheetheaderid`, `dogma_name`, `dogma_notes`, `dogma_periodstartdate`, `dogma_periodenddate`, `dogma_project`, `dogma_projectname`, `dogma_timesheetperiod`, `crbb5_totalhoursproject`, `crbb5_originalprojectcode`

**Not currently consumed by `fact_Timesheet`** — the 2026 scope filter uses `dogma_timesheet[dogma_date]` directly. Join this only if we later want to scope by submitted period boundaries.

### 14. `dogma_timesheetperiod` (Timesheet period, Dogma)
\+ Dataverse audit columns

**Authoritative columns (logical names) — approval / submission state:**
`dogma_timesheetperiodid`, `dogma_name`, `dogma_periodstartdate`, `dogma_periodenddate`, `dogma_approvaldate`, `dogma_approver`, `dogma_submissiondate`, `dogma_submissionnotes`, `dogma_firstrejectiondate`, `dogma_lastrejectiondate`, `dogma_numberofrejections`, `dogma_overdue`, `dogma_response`, `dogma_billingperiod`

**Not currently consumed by `fact_Timesheet`.** Available if the report should restrict to **approved** timesheets only (e.g. filter on `dogma_approvaldate` not null) — a design decision; `EMS 90` currently absorbs unsubmitted time instead.

### 15. `Equitix_Measures` (measure container)
No data columns — DAX measure table (only Power BI measures).

### 16. `fact_Actuals` (NetSuite GL actuals)
Columns identical to `stg_EMS Fixed Fee Forecast_Actuals`:
`Transaction Ref.`, `Transaction Date`, `Period End Date`, `Account No. Σ`, `Account Name`, `Memo`, `Class: Class External ID`, `Sum of Amount Σ`

Sample row: `Journal: JE15141 | 01 January 2025 | 31 January 2025 | 40010 | Operational revenue | Ash HoldCo | ASH-01 | 0`

### 17. `fact_Contracts` (Contracts fact)
`Billing Schedule item`, `crbb5_baseannualfee Σ`, `crbb5_basecurrency`, `crbb5_basecurrencyname`, `crbb5_billingenddate`, `crbb5_billingmethod`, `crbb5_billingmethodname`, `crbb5_billingstartdate`, `crbb5_currentannualfee Σ`, `crbb5_indexmonth Σ`, `crbb5_msareference`, `crbb5_projectcode`, `crbb5_projecttype`, `crbb5_service`, `crbb5_subsidiary`, `crbb5_supersector`, `Entity`, `Monthly Fee`, `MSA Reference`, `Project`, `Project Code`, `Project Type`, `Supersector`

### 18. `fact_FinanceFY2026` (NetSuite GL FY2026 fact)
`Account Code`, `Account Name`, `Class: Class ID`, `Class: Full Name`, `Customer: Full Name`, `Department: Department ID`, `Department: Full Name`, `Employee: Employee External ID`, `Employee: First Name`, `Employee: Last Name`, `Location: Full Name`, `Location: Location ID`, `Memo`, `Period End Date`, `Project Code`, `Subsidiary: Full Name`, `Sum of Amount Σ`, `Transaction Date`, `Transaction Line ID`, `Transaction Ref.`, `Transaction: Transaction ID`, `Vendor: Full Name`

### 19. `fact_ProjectHARP` (HARP project fact)
Columns identical to `dim_Contracts`:
`BaseAnnualFee Σ`, `BaseCurrencyName`, `Billing Schedule item`, `BillingEndDate`, `BillingMethodName`, `BillingStartDate`, `ConcessionExpiry`, `CurrentAnnualFee Σ`, `Entity`, `Exchange Σ`, `ForecastAmmount Σ`, `ForecastDate`, `GBP Value Σ`, `IndexMonth Σ`, `Monthly Fee Σ`, `MSA Reference`, `Project`, `Project Code`, `Project Type`, `Supersector`

### 20. `stg_EMS Fixed Fee Forecast_31Dec2025` (legacy forecast snapshot)
**Authoritative metadata columns (corrected from the latest data screenshots):**
`Item` (Billing Schedule Item, e.g. BSI-001004), `Project` (the project **code**, e.g. EEC-01), `Project Name (Project) (Project)`, `Billing Method` (Annual Fixed Fee), `Base annual fee Σ`, `Current Annual Fee Σ`, `Currency` (British Pound / Euro), `Billing frequency p.a. Σ`, `Index Uplift Date`, `Index Month Σ`, `Index Day of Month Σ`, `Subsidiary (Project) (Project)` (EMS / ESS), `Billing Start Date` 📅, `Billing End Date` 📅, `Billing Reference` (e.g. EEC-01-1), `Index this month ?` (Yes/No), `Base Index`, `Current Index`, `Inedxation Basis` *(typo — Indexation; RPI/RPIX)*, `Exchange Σ` (1, or 1.15 for Euro), `Monthly Fee Σ`

This sheet is retained as a legacy snapshot/reference only. The live standard in-contract forecast now comes from `stg_EMS Fixed Fee Forecast_Contracts1`, because that sheet carries the indexed monthly forecast schedule expected by the client.

### 21. `stg_EMS Fixed Fee Forecast_Actuals`
`Account Name`, `Account No. Σ`, `Class: Class External ID`, `Memo`, `Period End Date`, `Sum of Amount Σ`, `Transaction Date`, `Transaction Ref.`

### 22. `stg_EMS Fixed Fee Forecast_Contracts1`
This staging table now supplies the live standard in-contract forecast values. The wide forecast columns are one per month, date-named (`31/01/2025`, `28/02/2025`, ...), and hold the indexed forecast fee values expected by the client.

**Authoritative column order (corrected from the latest data screenshots):**
`MSA Reference`, `Project Code`, `Billing Schedule item`, `crbb5_billingmethod Σ`, `crbb5_billingmethodname`, `crbb5_billingstartdate` 📅, `crbb5_billingenddate` 📅, `crbb5_baseannualfee Σ`, `crbb5_basecurrency Σ`, `crbb5_basecurrencyname`, `crbb5_indexmonth Σ`, `crbb5_currentannualfee Σ`, `Entity`, `Project`, `Project Type`, `Monthly Fee Σ`, `Supersector`, `Concession expiry` 📅

**Naming nuance (important):** in this sheet `Project Code` is the **code** (e.g. SUM-01, BSE-01) and `Project` is the **name/description** (e.g. "Seafort - Contract Fixed Fees"). This is the **opposite** of the `31.12.2025` sheet, where `Project` is the code. Don't conflate them across sheets.

`Supersector` carries the readable sector **names** (`Social infrastructure`, `Environmental services`, `Group structures`) — the values that should appear on the report's sector axis (per the 27 May decision). `Entity` is the subsidiary short code (EMS / ESS). `crbb5_currentannualfee` is the indexed-up fee; `Monthly Fee` ≈ current annual / 12.

### 23. `stg_EMS Fixed Fee Forecast_Project HARP` (wide/pivoted)
**Authoritative structure (corrected from the latest data screenshots):** a **single contract row** for HARP. Metadata columns (same shape as Contracts1):
`MSA Reference` (EMS-MSA289), `Project Code` (**HAP-03** — the code lives in `Project Code` here, NOT `Project`), `Billing Schedule item` (N/A), `crbb5_billingmethod`, `crbb5_billingmethodname` (Annual Fixed Fee), `crbb5_billingstartdate` (01/08/2025), `crbb5_billingenddate` (31/12/2058), `crbb5_baseannualfee` (4,500,000), `crbb5_basecurrency`, `crbb5_basecurrencyname` (GBP), `crbb5_indexmonth`, `crbb5_currentannualfee` (4,500,000), `Entity` (EMS), `Project` ("HARP - Construction Phase delivery"), `Project Type` (**Construction**), `Monthly Fee` (0), `Supersector` (**Environmental Services**), `Concession expiry` (31/12/2058), `BLANK`, `Exchange`, `GBP Value`

Then **wide monthly forecast columns 31/01/2025 → 31/12/2035** (values vary by month, some negative — lumpy construction cash flow). Trailing **junk columns `Column154`, `Column155`** (null) must be dropped before unpivot. Because the project is **Construction**, the forecast revenue most likely maps to account **40011 (Construction revenue)**, not 40010 — confirm with Chris.

### 24. `stg_FinanceOutput FY26_CoA` (Chart of accounts from NetSuite)
**Authoritative column list (corrected from the latest data screenshots):**
`Nominal Code`, `Account Name`, `Account Type`, `Balance Sheet`, `Mapping` (null across the board)

`Nominal Code` is the account code (`dim_Accounts_Live` renames it to `Account Code`). It is stored as **text** in the source and **not every value is a pure integer** (some carry alphanumeric content) — `dim_Accounts_Live` therefore keeps `Account Code` as text; an `Int64.Type` cast would error on refresh. Comparisons in the dim use quoted string values (`"40010"`, `"60201"`). For the dim→fact relationship to build, **every fact's `Account Code` must land as the same normalised text key** — use `_NormalizeAccountCode` for source columns such as `Account No.` and `Netsuite N/C`, and use `"40014"` / `type text` (not `40014` / `Int64.Type`) in forecast helpers that hard-code account codes.

`Balance Sheet` is a T/F flag — `T` for balance-sheet accounts (Bank, AR, current assets, etc.), `F` for P&L (income/expense). `Account Type` values seen: Bank, Credit Card, Accounts Receivable, Other Current Asset, Expense, Income, Other Income.

Sample rows:
| Nominal Code | Account Name | Account Type | Balance Sheet | Mapping |
|---|---|---|---|---|
| 50500 | Intercompany expenses | Expense | P | |
| 51020 | Pass-through intercompany expenses | Expense | P | |
| 51030 | Investment management fees | Expense | P | |
| 60101 | Legal and professional fees | Expense | P | |
| 60500 | Audit fees | Expense | P | |

### 25. `stg_FinanceOutput FY26_FY2026` (NetSuite GL FY2026 source)
**Authoritative column list (corrected from the latest data screenshots):**
`Transaction: Transaction ID Σ`, `Transaction Line ID Σ`, `Transaction Ref.`, `Transaction Date` 📅, `Period End Date` 📅, `Account No. Σ`, `Account Name`, `Memo`, `Customer: Full Name`, `Vendor: Full Name`, `Class: Class ID`, `Class: Class External ID`, `Class: Full Name`, `Location: Location ID`, `Location: Full Name`, `Department: Department ID`, `Department: Full Name`, `Subsidiary: Full Name`, `Employee: Employee External ID`, `Employee: First Name`, `Employee: Last Name`, `Sum of Amount Σ`

**No `Project Code` column.** The project is the NetSuite **Class**: `Class: Class External ID` holds the project code (e.g. `ASH-01` — see the `fact_Actuals` sample above) and `Class: Full Name` the description. All GL-sourced facts must rename `Class: Class External ID` → `Project Code`.

**Unique line key** = `Transaction: Transaction ID` & `"-"` & `Transaction Line ID` (e.g. `770163-0`, `770163-1`). NetSuite has no native line key.

### 26. `stg_Staff Costs Summary`
**Authoritative column list / order (corrected from the latest data screenshots):**
`Employee #`, `Time@work Reference`, `Last Name, First Name`, `2025 Σ`, `2026 Σ`

**The `2025` / `2026` columns are DAY RATES (£/day), not annual salaries.** Sample values: Adair 198.26, Allan (Christine) 664.96, Bourke 750.45 — and Agnew 2026 = 241.55, which equals her `dim_StaffCosts[StaffCostPerDay]` (£241.55) → `StaffCostPerHour` = 241.55 / 7.5 = £32.21. So `DayRate` is taken straight from the year column; there is **no `/ 261`** annual-to-day conversion. (Many rows are 0 in one year — leavers/joiners; 2025 values appear rounded to whole £, 2026 carries pence.)

## Inferred relationships

No Model view was captured. The following are best-guess joins based on matching column names and values across tables.

```
Source → Dimension → Fact

crbb5_contractregister
    └─ MSA Reference, Contract Register
crbb5_billingschedule
    └─ Billing Schedule, Billing Reference, crbb5_project
        ↓
    dim_Contracts (MSA Reference + Project Code + Billing Schedule item)
        ↓
    fact_Contracts (crbb5_msareference + crbb5_projectcode)
    fact_ProjectHARP (MSA Reference + Project Code)


crbb5_project (Project Code, crbb5_contract)
    ↓
dim_Project (crbb5_projectcode, crbb5_contractname, crbb5_projectid)


crbb5_bamboohr (Employee #, Time@work Reference)
stg_Staff Costs Summary (Employee #, Time@work Reference)
    ↓
dim_StaffCosts (EmployeeID, TimeWorkReference)


crbb5_jedoxallocation (Project Reference, HR Reference)
    → joins to dim_Project and dim_StaffCosts


dogma_timesheet ← dogma_timesheetheader ← dogma_timesheetperiod
    └─ dogma_timesheetid, dogma_project, dogma_timesheetheader, dogma_timesheetperiod
        ↓
    dim_timesheet (dogma_timesheetid, dogma_project)


stg_FinanceOutput FY26_CoA (Nominal Code)
    ↓
dim_Accounts (Account Code)


stg_FinanceOutput FY26_FY2026
    ↓
dim_Transaction (TransactionLineKey, Transaction Line ID, Transaction: Transaction ID)
    ↓
fact_FinanceFY2026 (Transaction Line ID, TransactionLineKey, Transaction: Transaction ID)


stg_EMS Fixed Fee Forecast_Actuals  →  fact_Actuals (identical schema)
stg_EMS Fixed Fee Forecast_Contracts1  →  fact_Contracts (matching crbb5_* columns) and standard in-contract forecast after unpivot
stg_EMS Fixed Fee Forecast_31Dec2025  →  legacy snapshot/reference
stg_EMS Fixed Fee Forecast_Project HARP  →  fact_ProjectHARP (date pivot)
```

### Join keys, by relationship

| From | To | Key (left) | Key (right) |
|---|---|---|---|
| `crbb5_contractregister` | `dim_Contracts` | `Contract Register` + MSA fields | `MSA Reference` + `Project Code` |
| `crbb5_billingschedule` | `dim_Contracts` | `Billing Schedule`, `Billing Reference` | `Billing Schedule item` |
| `crbb5_project` | `dim_Project` | Project key | `crbb5_projectid`/`crbb5_projectcode` |
| `dim_Project` | `dim_Contracts` | `crbb5_projectcode` | `Project Code` |
| `crbb5_bamboohr` | `dim_StaffCosts` | `Employee #`, `Time@work Reference` | `EmployeeID`, `TimeWorkReference` |
| `stg_Staff Costs Summary` | `dim_StaffCosts` | `Employee #`, `Time@work Reference` | `EmployeeID`, `TimeWorkReference` |
| `crbb5_jedoxallocation` | `dim_Project` | `Project Reference`, `crbb5_projectreference` | `crbb5_projectcode` |
| `crbb5_jedoxallocation` | `dim_StaffCosts` | `HR Reference`, `crbb5_hrreference` | `TimeWorkReference` |
| `dogma_timesheet` | `dogma_timesheetheader` | `dogma_timesheetheader` (FK) | header id |
| `dogma_timesheetheader` | `dogma_timesheetperiod` | `dogma_timesheetperiod` (FK) | period id |
| `dogma_timesheet` | `dim_timesheet` | `dogma_timesheetid`, `dogma_project` | same |
| `stg_FinanceOutput FY26_CoA` | `dim_Accounts` | `Nominal Code` | `Account Code` |
| `stg_FinanceOutput FY26_FY2026` | `dim_Transaction` | NetSuite line keys | `TransactionLineKey`, `Transaction Line ID` |
| `stg_FinanceOutput FY26_FY2026` | `fact_FinanceFY2026` | NetSuite line keys | same |
| `dim_Accounts` | `fact_FinanceFY2026` | `Account Code` | `Account Code` |
| `dim_Transaction` | `fact_FinanceFY2026` | `TransactionLineKey`, `Transaction Line ID` | same |
| `dim_Project` | `fact_FinanceFY2026` | `crbb5_projectcode` | `Project Code` *(confirmed canonical link — Memo column is NOT the link, see Q&A Clarifications)* |
| `dim_Project` | `fact_Contracts` | `crbb5_projectcode` | `crbb5_projectcode`/`Project Code` |
| `dim_Contracts` | `fact_Contracts` | `MSA Reference`+`Project Code` | same |
| `dim_Contracts` | `fact_ProjectHARP` | `MSA Reference`+`Project Code` | same |

## Issues to flag (mostly internal — our junior dev's WIP build)

> Most items below are about the `dim_*` / `fact_*` layer that [[Synetec|Synetec]]'s junior developer is mid-way through building. They are **for us to fix internally**, not data quality problems to escalate to the client. Items that affect client-owned data (`crbb5_*`, `stg_*`) are called out explicitly. See the Internal [[Synetec|Synetec]] to-do list near the end of this document for the consolidated action list.

### Schema-level

1. **`fact_Actuals` is a verbatim copy of `stg_EMS Fixed Fee Forecast_Actuals`** — same 8 columns, no aggregation or transformation. Either drop `fact_Actuals` and use the staging table directly, or actually transform it (e.g. aggregate by Period End Date + Account Code + Class).
2. **`fact_ProjectHARP` is a verbatim copy of `dim_Contracts`** — same 20 columns. A fact and a dim should not have identical schemas. Decide which it is, and remove the other or change its purpose.
3. **`fact_Contracts` mixes `crbb5_*` raw column names with cleaned ones** — has both `crbb5_msareference` AND `MSA Reference`, both `crbb5_projectcode` AND `Project Code`, both `crbb5_projecttype` AND `Project Type`, etc. Pick one set and drop the duplicates. Fact tables should not carry raw Dataverse internal names.
4. **`dim_Contracts` and `fact_Contracts` are out of sync** — `dim_Contracts` has `BaseAnnualFee` (clean), `fact_Contracts` has `crbb5_baseannualfee` (raw). Pick a single canonical column-naming convention across the model.
5. **`dim_timesheet` retains `dogma_*` and `crbb5_*` prefixes** — `dogma_timesheetid`, `dogma_project`, `crbb5_isduplicate` etc. A dim layer should have clean business names. Rename these.
6. **Two wide/pivoted forecast staging tables**: `stg_EMS Fixed Fee Forecast_Contracts1` and `stg_EMS Fixed Fee Forecast_Project HARP` have date-columns (`31/01/2025`, `28/02/2025`, ..., out to 2035). This is a brittle Excel-style layout. **Unpivot** these in Power Query to a long format with `(Project, ForecastDate, Amount)` columns before loading.
7. **Four near-identical fixed-fee forecast staging tables** (`_31Dec2025`, `_Actuals`, `_Contracts1`, `_Project HARP`). `_Contracts1` and `_Project HARP` now carry forecast values, `_Actuals` is journal-style, and `_31Dec2025` is retained as a legacy snapshot/reference. They probably should be three differently-named tables — or one snapshot table with a `snapshot_date` column.
8. **`Equitix_Measures` is a measure container** — make sure it is hidden from report view and that its name does not clash with the company.

### Data quality / naming

9. **Spelling typos in column names**, exposed in the report:
   - `ForecastAmmount` → `ForecastAmount` (in `dim_Contracts`, `fact_ProjectHARP`)
   - `Subsidary Entity` → `Subsidiary Entity` (in `dim_Transaction`)
   - `Inedxation Basis` → `Indexation Basis` (in `crbb5_billingschedule`)
10. **`Mapping` column is empty everywhere** (`dim_Accounts`, `stg_FinanceOutput FY26_CoA`). Either populate it or remove it.
11. **Dataverse system columns load into every `crbb5_*` table** (28 audit/system columns each — `createdbyyominame`, `owningbusinessunit`, `Time Zone Rule Version Number`, etc.). Remove them in Power Query unless a specific column is used downstream. Yomi-name columns (`*yominame`) are Japanese phonetic readings — never useful in a UK report.
12. **Two `Account Code` lookups** — `dim_Accounts.Account Code` (40010, 40011…) vs `stg_FinanceOutput FY26_CoA.Nominal Code` (50500, 51020…) appear to be the same field with different names. Standardise.
13. **Duplicate-detection flags inside `dogma_timesheet`** (`crbb5_isduplicate`, `crbb5_isownermismatch`, `crbb5_marktodelete`, `is Duplicate?`, `Is Owner Mismatch?`, `mark to delete`). The same flag appears twice with different casings — these are likely both raw and translated copies. Pick one, drop the other.
14. **`dim_Project` has no Year column** but `dim_StaffCosts` and `dim_timesheet` do — meaning project-level analysis doesn't share a time grain. Confirm the model handles slowly-changing project attributes correctly.

### Modelling concerns

15. **Multiple sources for the same fact**:
    - HR/staff cost appears in `crbb5_bamboohr`, `dim_Transaction[Employee: …]`, `stg_Staff Costs Summary`, `dim_StaffCosts`.
    - Contracts appear in `crbb5_contractregister`, `crbb5_billingschedule`, `dim_Contracts`, `fact_Contracts`, `stg_EMS Fixed Fee Forecast_Contracts1`.
    Declare which is authoritative.
16. **`stg_*` tables are loaded into the model alongside `dim_*`/`fact_*`** — staging tables should normally be hidden from the report view (set `IsHidden = true`) so report builders don't accidentally bind visuals to them.
17. **`fact_FinanceFY2026[Project Code]` has no explicit relationship to `dim_Project`** that we can see — confirm Project Code is actually joined and active.
18. **Currency handling**: `crbb5_project` carries `Currency`, `Exchange Rate`, and `Billing Fee Total (Base)` (pre-converted). `dim_Contracts.BaseAnnualFee` and `BaseCurrencyName` look like they hold pre-converted base-currency values. Risk: double-applying FX if a visual converts again. Document where FX is applied.
19. **Empty `Sum of Amount = 0` rows** are visible in the `fact_Actuals` sample. Check whether Power Query loads zero-value rows or should filter them out at the source.
20. **The `dim_*` / `fact_*` split does not follow star-schema rules** — and `dim_Contracts` is the clearest violation:
    - **`dim_Contracts` is not actually a dimension.** Of its 20 columns, **9 are numeric measures** (`BaseAnnualFee Σ`, `CurrentAnnualFee Σ`, `Monthly Fee Σ`, `IndexMonth Σ`, `Exchange Σ`, `ForecastAmmount Σ`, `GBP Value Σ` and the two dates `BillingStartDate` / `BillingEndDate` / `ConcessionExpiry` / `ForecastDate` acting as fact attributes). A true dimension holds descriptive attributes only — measures belong in a fact.
    - **Three tables hold the same contract-level data**: `dim_Contracts`, `fact_Contracts`, `fact_ProjectHARP` all have nearly identical schemas (see Issues 2, 3, 4). In a star model only one of these should exist at a given grain.
    - **Recommendation: flatten the contract attributes into `dim_Project`** and lift the measures into a single fact:
        - Move the descriptive contract attributes (`MSA Reference`, `BillingMethodName`, `Project Type`, `Supersector`, `Entity`, `BaseCurrencyName`) onto `dim_Project` as additional columns. A project has at most one contract context, so this is denormalisation, not duplication. Result: one unified project/contract dim.
        - Move the contract measures (`BaseAnnualFee`, `CurrentAnnualFee`, `Monthly Fee`, `ForecastAmmount`, `GBP Value`, `BillingStartDate`/`EndDate`, `ConcessionExpiry`) into a single `fact_ContractFinance` (or fold into `fact_FinanceFY2026` if grain aligns), joined to `dim_Project` via `Project Code`.
        - Retire `dim_Contracts`, `fact_Contracts`, `fact_ProjectHARP` after the consolidation.
    - **Exception**: if a project genuinely has multiple billing schedule items (the `Billing Schedule item` column in `dim_Contracts` hints at this), then either pivot those to columns on `dim_Project` (`Billing Schedule 1 …`, `Billing Schedule 2 …` — ugly but star-compliant), or keep a single `dim_BillingSchedule` joined to a `fact_Billing` table at that grain. Do not keep a multi-row "dim" that duplicates project attributes.

## Proposed dashboard — achievability assessment

Evaluating the two-sheet design (YTD Actual + Full-Year Forecast Profitability) against the columns captured above. Verdict per element: achievable ✅ as-is, achievable ⚠️ with caveats listed, ❌ data missing in the model.

### Sheet 1 — YTD Actual Profitability

| Element | Verdict | Source | Caveat |
|---|---|---|---|
| KPI: Total actual revenue (YTD) | ✅ | `fact_FinanceFY2026[Sum of Amount]` filtered by `dim_Accounts[Account Type] = "Income"` | — |
| KPI: In-contract revenue | ✅ | `fact_FinanceFY2026` filtered by `dim_Accounts[Account Code] IN { 40010, 40011, 40012 }` (Operational / Construction / Development revenue — confirmed by Chris 13/05) | `40012` Development revenue currently has no balance but should remain in the filter for future periods |
| KPI: Out-of-contract revenue | ✅ | same, filtered by `dim_Accounts[Account Code] = 40013` | 40014 was previously included, then excluded because "40014 is recharged cost." |
| KPI: Total actual costs | ✅ | `fact_FinanceFY2026[Sum of Amount]` filtered by `dim_Accounts[Account Type] = "Expense"` | — |
| KPI: Staff costs (timesheet-based) | ⚠️ | new `fact_Timesheet` (built from `dogma_timesheet`) joined to `dim_StaffCosts` and `dim_Employee` (new) via `Time@work Reference`. The hours × country-aware hourly rate calculation lives in the Power Query of `fact_Timesheet`, not in a measure on the raw `dogma_*` table | New `fact_Timesheet` and `dim_Employee` tables required (see Internal to-do). Hourly rate = `StaffCostPerDay / 7.5` for UK + Ireland, `/ 8` for Italy. Exclude `EMS 90` rows from contract/sector visuals. Exact replacement formula still pending on next call |
| KPI: Subcontractor costs | ✅ | `fact_FinanceFY2026` filtered by `dim_Accounts[Account Code] = 60201` | client rule: "Total subcontractor costs should equal the sum of 60201." Exclude the temporary-staff account (those people book timesheets and would double-count) |
| KPI: Actual profit | ✅ | DAX: `Revenue - Costs` | — |
| KPI: Actual margin % | ✅ | DAX: `DIVIDE(Profit, Revenue)` | — |
| Chart: Revenue split | ✅ | by `dim_Accounts[Contract Type]` | — |
| Chart: Cost split | ⚠️ | requires a cost-category column; currently has to combine timesheet-derived staff cost with Account-Name-derived subcontractor cost | needs a unified cost-classification dimension |
| Table: Sector profitability | ✅ | by `dim_Project[crbb5_supersectorchoicename]` or `dim_Contracts[Supersector]` | two sector columns exist (`supersectorchoicename`, `supersectorcontractname`) — pick one canonical |
| Table: Top/Bottom 10 contracts/assets | ✅ | rank by profit measure, grouped by `dim_Contracts[MSA Reference]` or `[Project]` | — |
| Table: Project profitability detail | ✅ | join `dim_Project` to `dim_Contracts` to `fact_FinanceFY2026` | depends on the `Project Code` join actually being active in the model (Issue 17) |
| Data quality tile | ⚠️ | `fact_FinanceFY2026` rows where `Project Code` is blank; `dim_StaffCosts` rows where `StaffCostPerDay = 0`; MSA References in fact tables not in `dim_Contracts` | feasible but needs explicit DAX measures defined |

### Sheet 1 filters

| Filter | Verdict | Source | Caveat |
|---|---|---|---|
| Reporting year | ⚠️ | derivable from `fact_FinanceFY2026[Period End Date]` / `[Transaction Date]` | **no `dim_Date` table exists in the model** — add one |
| Reporting month / YTD period | ⚠️ | same | needs `dim_Date` with month and YTD-flag columns |
| Sector | ✅ | `dim_Project[Sector]` — surfaced from `crbb5_supersectorchoice` during Power Query, **not** referenced from `crbb5_*` directly | build via a `[Sector Label]` measure so a future switch to `crbb5_upstreamreporta` is trivial |
| **Portfolio** (new) | ✅ | `dim_Project[Portfolio]` — surfaced from `crbb5_portfolio` during Power Query | examples: Apollo, Caterham. Add as a drill-down level between Sector and Asset/Project |
| Region / location | ✅ | `dim_Transaction[Location: Full Name]` (e.g. `UK : Leeds`) | — |
| Contract / asset | ✅ | `dim_Contracts[MSA Reference]` / `[Project]` | — |
| Project / project code | ✅ | `dim_Project[crbb5_projectcode]` | rename `crbb5_projectcode` to `Project Code` for slicer clarity |
| Revenue type | ✅ | `dim_Accounts[Contract Type]` (In/Out of Contract) | — |
| Cost type | ✅ | `dim_Accounts[Account Code]` against the confirmed lists (`60201`/`60203` Subcontractor; timesheet-derived Staff; everything else Other) | recommend still adding a derived `Cost Category` column to `dim_Accounts` so the slicer is by category name not code |

### Sheet 2 — Full-Year Forecast Profitability

| Element | Verdict | Source | Caveat |
|---|---|---|---|
| KPI: Full-year revenue (actual + forecast) | ⚠️ | new unified `fact_Revenue` (Type = Actual / Forecast, In-Contract / OOC) joined to `dim_Date`, `dim_Project`, `dim_Accounts` | requires the new revenue fact to land actuals from `stg_FinanceOutput FY26_FY2026` + in-contract forecast from `stg_EMS Fixed Fee Forecast_*` + OOC forecast from the Additional Services Forecast file (`stg_AdditionalServicesForecast`, delivered) |
| KPI: Forecast in-contract revenue | ⚠️ | new `fact_Revenue` rows where `Type = Forecast` and `Account Code IN { 40010, 40011, 40012 }` | sourced from unpivoted `stg_EMS Fixed Fee Forecast_*` files via Power Query — the staging files themselves are not referenced by visuals |
| KPI: Forecast out-of-contract revenue (additional services) | ✅ | new `fact_Revenue` rows where `Type = Forecast` and `Account Code = 40014` | Additional Services Forecast file **delivered** (by month + project code). Power Query ingests it into `fact_Revenue` via `stg_AdditionalServicesForecast` |
| KPI: Full-year costs | ⚠️ | new unified `fact_Cost` (Type = Actual / Forecast, Category = Staff / Subcontractor / Other) joined to `dim_Date`, `dim_Project`, `dim_Accounts` | requires the new cost fact to materialise the Jedox forecast × rates calc and the subcontractor cost forecast (Subcontractor Forecast file **delivered**, by month + project code → `stg_SubcontractorForecast`) |
| KPI: Forecast staff costs (Jedox-based) | ✅ | new `fact_Cost` rows where `Type = Forecast` and `Category = Staff` — computed in Power Query as `Jedox.Value × dim_StaffCosts.StaffCostPerDay` × working days, joined via `HR Reference` to `TimeWorkReference` and `Project Reference` to `crbb5_projectcode` | the Jedox allocation table (`crbb5_jedoxallocation`) is the source, not the visual binding. Filter the source by `Version = "Forecast"` during the Power Query step |
| KPI: Forecast profit | ✅ | DAX: `Full-Year Revenue - Full-Year Costs` | depends on the gaps above being resolved |
| KPI: Forecast margin % | ✅ | DAX | — |
| KPI: Variance to YTD actual profit | ✅ | DAX: `Forecast Profit - YTD Actual Profit` | — |
| Chart: Actual vs forecast revenue | ⚠️ | needs unified date-pivoted fact plus as-at-date logic | requires `dim_Date` + unpivoted forecast |
| Chart: Actual vs forecast costs | ⚠️ | same | same |
| Chart: Forecast revenue split | ⚠️ | depends on out-of-contract forecast (❌ above) | partial only |
| Table: Forecast profitability by sector | ✅ | as Sheet 1 | — |
| Table: Top/Bottom 10 by forecast profit | ✅ | rank by forecast profit measure | — |
| Table: Project forecast detail | ✅ | `dim_Project` to `dim_Contracts` to forecast fact | — |
| Data quality tile (forecast) | ⚠️ | missing forecast: count of `dim_Project` rows not in `stg_EMS Fixed Fee Forecast_*`; missing rates: `dim_StaffCosts` with 0; unmapped forecast projects: forecast tables with `Project Code` not in `dim_Project` | requires the unified forecast fact first |

### Sheet 2 filters

| Filter | Verdict | Source | Caveat |
|---|---|---|---|
| Forecast year | ⚠️ | `dim_Date[Year]` filtered on `fact_Revenue[ForecastDate]` / `fact_Cost[ForecastDate]` | needs `dim_Date` over 2025–2035 and unpivoted forecast lines materialised into `fact_Revenue`/`fact_Cost` — staging files cannot be directly bound |
| As-at month | ⚠️ | new `dim_ForecastSnapshot` table — one row per snapshot date — joined to `fact_Revenue`/`fact_Cost` | requires us to add a `SnapshotDate` column to the forecast facts during Power Query, sourced from the staging file's snapshot name (`_31Dec2025`, etc.) |
| Forecast version / scenario | ✅ | `dim_ForecastVersion[Version]` joined to the forecast facts | sourced from `crbb5_jedoxallocation[Version]` during ingest; confirm the full set of values with the client |
| Sector | ✅ | as Sheet 1 | — |
| Region / location | ⚠️ | deferred from the current profitability hierarchy | Do not expose Region as a slicer or visible hierarchy column in the current sprint; revisit in a future scope decision |
| Contract / asset | ✅ | `dim_Contracts[MSA Reference]` | — |
| Project / project code | ✅ | `dim_Project[crbb5_projectcode]` | — |
| Revenue type | ⚠️ | `dim_Accounts[Contract Type]` works for actuals; needs to also resolve for forecast lines | requires forecast lines to carry an Account Code or Contract Type — currently the forecast staging tables do not |
| Cost type | ⚠️ | as Sheet 1 | needs cost-classification dimension |

### Summary — prerequisites before this dashboard can be built

The design is **achievable**, but the current `dim_*` / `fact_*` build is WIP and must be restructured before measures can be built reliably against it. Prerequisites:

1. **Restructure the model** to the target shape described in the Internal [[Synetec|Synetec]] to-do list — new `fact_Revenue`, `fact_Cost`, `fact_Timesheet`, `dim_Date`, `dim_Employee`, `dim_ForecastSnapshot`, `dim_ForecastVersion`. Retire the duplicate / mislabeled `dim_Contracts`, `fact_Actuals`, `fact_Contracts`, `fact_ProjectHARP`.
2. **Hide all source/staging tables** (`stg_*`, `crbb5_*`, `dogma_*`) from Report View. No visual or measure should reference them.
3. **Unpivot the wide forecast staging files** during Power Query ingest (`_31Dec2025`, `_Project HARP`) into long format and land into `fact_Revenue` with `SnapshotDate` and `ForecastDate` columns.
4. **Bring in the Additional Services Forecast** (OOC revenue) as a new ingest source (`stg_AdditionalServicesForecast`) feeding `fact_Revenue[Type=Forecast, Contract Type=Out]`. **Delivered**, by month + project code. Bring in the **Subcontractor Forecast** (`stg_SubcontractorForecast`) feeding `fact_Cost[Type=Forecast, Category=Subcontractor]`. **Delivered**, by month + project code.
5. ★ **Implement the staff-cost rule** in the `fact_Timesheet` Power Query: `booked hours × hourly rate`, hourly rate country-aware (`/7.5` UK+IE, `/8` Italy), applied to a client-supplied **day rate**. No floor/ceiling and no over/under-standard-hours adjustment. Exclude `EMS 90`. **Confirmed by client email.**
6. ★ **Deduplicate `dim_StaffCosts`** for contractor → permanent transitions (`EMPEMCON*` → `EMPEM*`). Join on `Time@work Reference` not `EmployeeID`. Only affects historic; 2026 is clean.
7. ★ **Add `Portfolio` and `Sector` as columns on `dim_Project`** — sourced from `crbb5_contractregister[crbb5_portfolio]` and `crbb5_supersectorchoice` during ingest, never referenced from `crbb5_*` by visuals.
8. ★ **Build the unique transaction-line key** during the `fact_Revenue` / `fact_Cost` ingest: `Transaction ID & "-" & Transaction Line ID`.
9. ★ **Fix the timesheet → rate join** in `fact_Timesheet` Power Query: expand `systemuser(owninguser)` on `dogma_timesheet`, use `crbb5_timeworkreference` as the join key to `dim_StaffCosts[TimeWorkReference]`.

Three smaller dependencies:

- Make the `Project Code` relationship between `dim_Project` and `fact_FinanceFY2026` active (Issue 17).
- Pick one canonical sector column from `crbb5_supersectorchoicename` and `crbb5_supersectorcontractname`.
- Resolve the `fact_Actuals` vs `stg_EMS Fixed Fee Forecast_Actuals` duplication (Issue 1) so YTD actuals have one source of truth.

One structural cleanup that should happen before, not after, the dashboard is built:

- **Consolidate to a clean star schema** (Issue 20). Flatten `dim_Contracts` attributes into `dim_Project`, move the contract measures into a fact, and retire `fact_Contracts` and `fact_ProjectHARP`. Building dashboard measures on top of the current three-tables-same-data layout will produce wrong totals (the same contract row exists in `dim_Contracts`, `fact_Contracts`, and `fact_ProjectHARP` — any measure that fans out across them will multiply).

## Questions for the next client meeting

Only items that need a business / data-owner decision from the client are here. Anything that's a [[Synetec|Synetec]]-side cleanup of the `dim_*` / `fact_*` build is in the **Internal [[Synetec|Synetec]] to-do list** section below this one.

Items marked **[BLOCKER]** can hold up build progress until answered.

### 1. Staff-cost calculation (business rule)

1. ~~Exact replacement formula for the staff-cost measure~~ — ✅ **resolved (client email)**: `(timesheet hours booked) × (day rate / 7.5 or 8 depending on country)`, no monthly cap, **no adjustment for over/under standard hours**. Day rates are supplied by the client.
2. For employees on **part-time contracts** — is the day rate already pro-rated for them, or does the calculation need an FTE factor?
3. Should `EMS 90` cost be excluded from **all** report visuals (contract / sector / portfolio / project), or surfaced anywhere for QA / reconciliation?
4. Does a **contractor-to-permanent EmployeeID mapping** exist on Equitix's side (an authoritative list of which `EMPEMCON*` ID maps to which `EMPEM*`), or should we derive it ourselves from same Name + same `Time@work Reference`?

### 2. Forecast data

5. ~~Structure of the OOC revenue forecast file~~ — ✅ **resolved**: delivered as the **Additional Services Forecast** spreadsheet (SharePoint Data folder), **by month + project code**. Ingest into `stg_AdditionalServicesForecast`. (Verify exact column headers against the delivered file.)
6. ~~Source for forecast subcontractor cost~~ — ✅ **resolved**: delivered as the **Subcontractor Forecast** spreadsheet (SharePoint Data folder), **by month + project code**. Ingest into `stg_SubcontractorForecast`. (Verify exact column headers against the delivered file.)
7. Of the four `stg_EMS Fixed Fee Forecast_*` files, **which is authoritative** for in-contract revenue forecast going forward? Specifically:
   - Are the wide / date-pivoted layouts (`_31Dec2025`, `_Project HARP`) the format you intend to keep providing, or can the file structure change?
   - The variable-fee adjustment for the largest project — confirm which file that is now appended into.
8. **Jedox forecast versions**: what values does `crbb5_jedoxallocation[Version]` take (Forecast, Baseline, Approved, etc.) and which should drive the Sheet 2 "Forecast version / scenario" filter?

### 3. Scope and hierarchy decisions

9. **Portfolio coverage**: do **all** contracts belong to a portfolio, or only a subset? If only some, how should portfolio-less contracts appear in the drill-down (e.g. "Unportfolioed", "—")?
10. **Pipeline contracts (`EMS-PR*`)**: should pipeline-phase contracts (no signed MSA yet) be **included in the profitability reporting**, or filtered out? They may carry pre-contract costs but no revenue yet.
11. Subsidiaries in scope are EMS UK, EMS Italy (ESS), BWG, BWS. Confirm there are no other NetSuite subsidiaries that could leak into the report and need explicit exclusion.
12. Sector: the future pivot to `crbb5_upstreamreporta` (Upstream reporting) — within **first release** scope, or phase 2?
13. Slicers — **single-select or multi-select**? E.g. should a user be able to pick "Sector = Renewables + Social Infra" simultaneously?

### 4. Data quality — client decisions

14. **Blank `Location: Full Name`** in `fact_FinanceFY2026` — pending Chris's check. Cause, and how to display in the Region slicer (drop / "Unknown" / DQ alert)?
15. **Empty `Mapping` column** in `stg_FinanceOutput FY26_CoA` — column to keep or remove? Will it ever be populated?
16. **Zero-amount transaction lines** in NetSuite (`Sum of Amount = 0`) — should the extract include them, or filter at source?
17. The DQ tile concept mentions "**missing rates**" — what's the client's definition? `StaffCostPerDay = 0`, `NULL`, rates older than X years, or something else?
18. **Timesheet flags** (`is Duplicate?`, `Is Owner Mismatch?`, `mark to delete`) in `dogma_timesheet` — are these actively maintained by Equitix? Should the dashboard exclude any timesheet rows where they're set?
19. **Currency / FX**: `dim_Contracts.BaseAnnualFee` and `BaseCurrencyName` look pre-converted to a base currency at source. Confirm where FX is applied so we don't double-convert in the report. Particular risk for the Italian entity (ESS).

### 5. Operational and access

20. **[BLOCKER]** **Fabric workspace** — workspaces are currently Power BI Pro; Fabric is not enabled. Is Fabric being procured, or should we redesign within Power BI Pro constraints (no Lakehouse, no dataflows Gen2, no semantic-model items)?
21. **[BLOCKER]** **VM clipboard** — has the copy-paste block been investigated? Slowing dev work.
22. **Refresh model** for the first release — manual button-press (Jonjo/Chris around the 10th–11th), or automated scheduled refresh after working day 5?
23. **Excel vs CSV**: confirm we're sticking with Excel sources for first release (CSV conversion would need Power Automate).

## Internal [[Synetec|Synetec]] to-do list

These do not need a client conversation — they're things our junior developer's work-in-progress build needs to address before the dashboard can ship. Grouped by area.

### Target model — `dim_*` / `fact_*` only (everything else hidden)

Per the architectural principle above: `stg_*`, `crbb5_*`, `dogma_*` must be marked `IsHidden = true` and never referenced by visuals or measures. The target shape is:

**Dimensions:**
- `dim_Date` — new, 2024–2035
- `dim_Project` — keep; absorb contract attributes from current `dim_Contracts`; add `Portfolio`, `Sector`, `Subsidiary` columns surfaced from `crbb5_*`
- `dim_Employee` — new, sourced from `crbb5_bamboohr`. Includes `Time@work Reference`, `Country`, FTE/part-time flag. The current `dim_StaffCosts` becomes a related dim or merges in
- `dim_StaffCosts` — keep as a rates dim per (Employee, Year) with deduplicated contractor → permanent ID merge
- `dim_Accounts` — keep; add `Cost Category` (Staff / Subcontractor / Other) and `Contract Type` (In / Out) columns; canonicalise the Account Code vs Nominal Code naming
- `dim_Transaction` — keep
- `dim_ForecastSnapshot` — new, one row per forecast snapshot date (`31Dec2025`, etc.)
- `dim_ForecastVersion` — new, distinct values from `crbb5_jedoxallocation[Version]`
- (optional) `dim_BillingSchedule` — only if a project genuinely has multiple billing schedule items requiring separate analysis

**Facts:**
- `fact_Revenue` — unified actual + forecast revenue, columns: `Date`, `Project Code`, `Account Code`, `Subsidiary`, `Type` (Actual / Forecast), `Contract Type` (In / Out), `Snapshot`, `Amount`. Sourced from `stg_FinanceOutput FY26_FY2026` (actuals), `stg_EMS Fixed Fee Forecast_*` (in-contract forecast), and `stg_AdditionalServicesForecast` (OOC forecast — delivered)
- `fact_Cost` — unified actual + forecast cost, columns: `Date`, `Project Code`, `Employee` (nullable), `Account Code`, `Category` (Staff / Subcontractor / Other), `Type` (Actual / Forecast), `Snapshot`, `Amount`. Sourced from `stg_FinanceOutput FY26_FY2026` (subcontractor + other actuals), `fact_Timesheet` aggregated (staff actuals), `crbb5_jedoxallocation × dim_StaffCosts` (staff forecast), and `stg_SubcontractorForecast` (subcontractor forecast — delivered)
- `fact_Timesheet` — new, the granular per-day-per-employee-per-project line, with country-aware hourly rate already applied. Excludes `EMS 90`. Aggregates upward into `fact_Cost`
- `fact_FinanceFY2026` — keep as the raw NetSuite GL fact (with the unique transaction-line key Power Query step), but consider whether `fact_Revenue` + `fact_Cost` make it redundant. Most likely retire.
- `fact_ContractFinance` — optional, if contract-level measures (BaseAnnualFee, CurrentAnnualFee, Monthly Fee) are needed as standalone KPIs separate from `fact_Revenue` rows

### Tables to retire after restructure

a. **`dim_Contracts`** — attributes folded into `dim_Project`; measures lifted into `fact_Revenue` / `fact_ContractFinance`.
b. **`fact_Actuals`** — verbatim copy of `stg_EMS Fixed Fee Forecast_Actuals`. Replaced by `fact_Revenue[Type=Actual]`.
c. **`fact_ProjectHARP`** — schema-identical to `dim_Contracts`. HARP becomes a project code filter on `fact_Revenue`, not a separate fact.
d. **`fact_Contracts`** — carries both raw `crbb5_*` and cleaned columns. Replaced by `dim_Project` (attributes) + `fact_ContractFinance` (measures, if needed).

### Mandatory hiding rules

- All `stg_*` tables → `IsHidden = true` in the semantic model.
- All `crbb5_*` tables → `IsHidden = true`.
- All `dogma_*` tables → `IsHidden = true`.
- Verify in Power BI Desktop: in Report View only the user-friendly `dim_*` / `fact_*` are visible in the Fields list.

### Power Query / model build-out

f. **Add a `dim_Date`** (2024–2035, Year/Month/Quarter/MonthYear/IsYTD/IsCurrentMonth flags). Required by every time slicer and YTD measure.
g. **Unpivot the wide forecast staging tables** (`stg_EMS Fixed Fee Forecast_Contracts1`, `stg_EMS Fixed Fee Forecast_Project HARP`) into long format `(Project Code, Forecast Date, Amount, Snapshot)`.
h. **Add a `Cost Category`** column to `dim_Accounts` (Staff / Subcontractor / Other) based on the confirmed code lists.
i. **Add `Portfolio`** as a slicer-ready dimension — surface `crbb5_portfolio` on `dim_Project`.
j. **Build the unique transaction-line key** in Power Query: `Transaction ID & "-" & Transaction Line ID` for `fact_FinanceFY2026`.
k. **Fix the `dogma_timesheet` ↔ `dim_StaffCosts` join**: expand `systemuser(owninguser)` in Power Query and use `crbb5_timeworkreference` as the join key (not `crbb5_originalprojectcode`).
l. **Make the day-rate divisor country-aware**: `StaffCostPerHour = StaffCostPerDay / 7.5` for UK + Ireland, `/ 8` for Italy. Source country from `crbb5_bamboohr[Country]`.
m. **Deduplicate `dim_StaffCosts`** historic contractor-to-permanent rows — either via a mapping table or by keying on `Time@work Reference` everywhere.
n. **Make the `Project Code` relationship** between `dim_Project` and `fact_FinanceFY2026` active and bi-directional if needed (Issue 17).
o. **Build a `[Sector Label]` measure** pointing at `crbb5_supersectorchoice` so the future switch to `crbb5_upstreamreporta` is a one-line change.
p. **(Covered by the Mandatory hiding rules above.)** Verify enforcement: no visual, measure, or calculated column anywhere in the `.pbix` references a `stg_*`, `crbb5_*`, or `dogma_*` column.

### DAX measure build

q. **Revenue measures**:
   - `[Revenue] = CALCULATE(SUM(fact_FinanceFY2026[Sum of Amount]), dim_Accounts[Account Code] IN { 40010, 40011, 40012, 40013 })`
   - `[In-Contract Revenue] = CALCULATE([Revenue], dim_Accounts[Account Code] IN { 40010, 40011, 40012 })`
   - `[Out-of-Contract Revenue] = CALCULATE([Revenue], dim_Accounts[Account Code] = 40013)`
r. **Cost measures**:
   - `[Subcontractor Costs] = CALCULATE(SUM(fact_FinanceFY2026[Sum of Amount]), dim_Accounts[Account Code] = 60201)`
   - `[Staff Costs]` — per the country-aware hours × hourly-rate formula, excluding `EMS 90`, awaiting the exact formula from Q1
   - `[Total Costs] = [Subcontractor Costs] + [Staff Costs] + [Other Costs]`
s. **Profit / margin measures**:
   - `[Profit] = [Revenue] - [Total Costs]`
   - `[Margin %] = DIVIDE([Profit], [Revenue])`
t. **YTD / forecast measures** — `[Revenue YTD]`, `[Forecast Revenue Remaining]`, `[Full-Year Revenue] = [Revenue YTD] + [Forecast Revenue Remaining]`, etc.
u. **Data quality measures** for the DQ tile — `[# Rows missing Project Code]`, `[# Employees with zero StaffCostPerDay]`, `[# MSA References unmapped to dim_Contracts/dim_Project]`.

### Naming hygiene

v. Rename typo'd columns in our Power Query layer (do not need to push these upstream to Dataverse): `ForecastAmmount` → `ForecastAmount`, `Subsidary Entity` → `Subsidiary Entity`, `Inedxation Basis` → `Indexation Basis`.
w. Strip Yomi-name columns (`*yominame`) and unused Dataverse system columns from `crbb5_*` tables during ingest.
x. Hide `Equitix_Measures` if it isn't already, and don't let DQ logic flag it as an empty table.
y. Decide a single sector column (`crbb5_supersectorchoicename` from `dim_Project`) and rename to a friendlier `[Sector]`.

### Things to verify against the actual `.pbix` Model view

z. Confirm relationships exist and are active for every join in the Inferred relationships table — most importantly `dim_Project[crbb5_projectcode] → fact_FinanceFY2026[Project Code]`.
aa. Confirm `stg_*` tables are not also being used as data sources for visuals by accident.
bb. Run the DAX Studio dump (`INFO.VIEW.COLUMNS()` / `INFO.VIEW.RELATIONSHIPS()`) and check against this audit for any hidden columns we couldn't see in the recording.

## Next steps

- Run the actual Model view (View → Model in Power BI Desktop) and confirm the relationships against the inferred table above. Anywhere the actual model differs from this inference, the model is probably what needs fixing — most of the issues above appear when relationships were added by Power BI's autodetect rather than by design.
- For a definitive column list (including hidden columns) and data types, run in DAX Studio:
  ```dax
  EVALUATE
  SELECTCOLUMNS(
      INFO.VIEW.COLUMNS(),
      "Table", [Table],
      "Column", [Name],
      "DataType", [DataType],
      "IsHidden", [IsHidden]
  )
  ORDER BY [Table], [Name]
  ```
  and export to CSV. That will catch any columns hidden from the Data view that the recordings could not show.
