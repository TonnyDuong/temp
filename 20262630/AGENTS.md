# AGENTS.md

## Purpose

`Equitix.PowerQuery` is the source-controlled Power Query layer for the Equitix profitability model.

It contains:

- one `.pq` file per `_Live` query
- helper queries that feed the unified revenue and cost facts
- companion documentation that explains business rules, source mapping, and refactor intent
- text measure exports used as reference during model maintenance

Treat this folder as the maintainable source for the Power Query logic, even when the active report is still edited in Power BI Desktop.

## What To Optimize For

When changing this area:

1. Keep the `_Live` model internally consistent.
2. Preserve the star-schema intent from the docs: report-facing logic should land in `dim_*` and `fact_*`, not in `stg_*`, `crbb5_*`, or `dogma_*`.
3. Prefer small, reviewable edits over broad rewrites.
4. Keep query code, business-rule docs, and measure references aligned in the same change.
5. Call out any place where code and docs disagree instead of silently picking one.
6. Make only precise changes tied to explicit client requirements or verified defects. Do not rewrite headers, reformat files, remove fields, or update docs unless the change is needed for the requested fix.

## Change Authority

Changes must be made exactly to the user request and no further.

- Do not implement best-practice improvements, cleanups, refactors, renames, helper extraction, type normalisation, relationship changes, or documentation rewrites unless the user explicitly requests that exact change.
- If investigation reveals a likely defect outside the requested scope, report it as a finding and ask before changing code or docs.
- If a change was not requested by the client or the user, do not describe it as client-requested. Record it as an unrequested finding or proposed remediation only.
- Prefer the smallest reversible edit that satisfies the stated request. One extra "while here" change can create hours of recovery work.
- When unsure whether a change is in scope, stop and ask instead of applying it.

## Canonical References

Read these before making non-trivial changes:

- [README.md](C:\Github\Equitix\Equitix\Equitix.PowerQuery\README.md)
- [Power BI Refactor Plan.md](<C:\Github\Equitix\Equitix\Equitix.PowerQuery\docs\Power BI Refactor Plan.md>)
- [Power BI Schema Audit - Equip Profitability Report.md](<C:\Github\Equitix\Equitix\Equitix.PowerQuery\docs\Power BI Schema Audit - Equip Profitability Report.md>)
- [Equitix_Measures.txt](C:\Github\Equitix\Equitix\Equitix.PowerQuery\Equitix_Measures.txt)

Use the docs for business intent, but verify against the `.pq` files before editing because some comments and plans have drifted from current code.

## Folder Rules

- `dimensions/`: one file per `dim_*_Live` query, load enabled unless the file clearly acts as a parameter table.
- `facts/`: top-level `fact_*_Live` queries, built by combining helpers.
- `helpers/`: load-disabled subqueries that normalize a single source into fact-compatible shape.
- `docs/`: business context, refactor sequencing, and schema notes that must stay in sync with code changes.

## Current Build Shape

The current design is:

- `fact_Revenue_Live` = append of `_Revenue_*` helpers
- `fact_Cost_Live` = append of `_Cost_*` helpers
- `fact_Timesheet_Live` = timesheet-level staff-cost fact feeding `_Cost_Staff_Actuals`
- `dim_StaffCosts_Live` = shared rate and forecast-cost input table
- `dim_ForecastSnapshot_Live` and `dim_ForecastVersion_Live` = forecast filtering support

When adding a new source:

1. Prefer a new helper in `helpers/`.
2. Conform it to the existing fact column shape.
3. Append it in the matching `fact_*_Live` query.
4. Update the docs and measure references if report semantics change.

## Query Conventions

- Keep the `_Live` suffix until a deliberate Phase 6-style swap-over is requested.
- Preserve the header block at the top of each `.pq` file and update it when dependencies, grain, or business rules change.
- Helpers should remain load-disabled in Power BI Desktop.
- Use friendly output column names that match the existing fact and dimension contracts.
- Keep revenue and cost facts append-friendly: new helpers should match the established schema instead of introducing one-off columns.

## Business Rules To Preserve

Unless the user explicitly asks to change them, preserve these current rules:

- HARP forecast may arrive through its own ingest helper, but report-facing revenue logic must treat it as part of the single in-contract forecast dataset.
- Staff actual cost in `fact_Timesheet_Live` is `Duration * StaffCostPerHour`.
- `dim_StaffCosts_Live` deduplicates contractor-to-permanent transitions by `TimeWorkReference`, preferring `EMPEM*` over `EMPEMCON*`.
- Hourly rate is country-aware: UK and Ireland use `DayRate / 7.5`, Italy uses `DayRate / 8`.
- Forecast staff cost is based on Jedox allocation fraction times `RevisedAnnualCost`, then spread evenly across 12 months.
- `EMS 90` is flagged in timesheets and handled downstream rather than removed at source.
- Revenue and cost facts use cutover-based filtering to split actuals from forecast rows.
- The current profitability report hierarchy is `Sector -> Contract -> Project Display`. Region split/filtering is out of scope for the current sprint and should only be reintroduced after a new client request.
- Out-of-contract actual revenue includes account codes `40013` and `40014`; OOC forecast remains the Additional Services forecast stream using `40014`.
- The cutover day is the 12th of the month unless explicitly changed for a controlled test.
- `Account Code` must stay as text in the dimension and all helpers/facts.
- DAX measure updates must preserve existing filter/category boundaries unless the client requirement explicitly changes them. For example, YTD + Forecast revenue should reuse the existing In-Contract and Out-of-Contract forecast measures rather than replacing them with an unrestricted forecast sum.

## High-Risk Areas

Be careful in these spots because changes ripple widely:

- Source Excel workbooks: before changing Power Query for missing rows, confirm the client has not left filters applied in the workbook/table. A saved filter can make staging or helpers appear empty while the data is still present in the file.
- `_CutoverDate.pq`: used by both actual and forecast helpers.
- `dim_StaffCosts_Live.pq`: shared by timesheet actuals and Jedox-based forecast cost.
- `dim_Accounts_Live.pq`: classification logic and account-code typing affect both fact joins and measure semantics.
- `_Revenue_Forecast_31Dec2025.pq` and `_Revenue_Forecast_HARP.pq`: same concept, different source column conventions.
- `Equitix_Measures.txt`: measures assume current fact names, cutover behavior, and category semantics.

## Known Drift To Check Before Editing

At time of writing, these areas need explicit verification before further maintenance:

- Several helpers still carry `TODO` notes for source-column or default-account confirmation.
- `dim_Accounts_Live.pq` is a maintenance hotspot because account classification rules drive both joins and report semantics.

Do not "clean up" any of these silently. If you touch one, state whether you are preserving the current behavior or reconciling it to the docs.

## Change Checklist

For any substantive Power Query change:

1. Update the affected `.pq` file header comment.
2. Check whether a paired helper, fact, dimension, or measure export also needs updating.
3. Update the relevant Markdown doc if the business rule, dependency, or source mapping changed.
4. Verify load-enabled versus load-disabled intent was not accidentally changed.
5. In code comments and Markdown, state the client requirement or data evidence that justifies any added, removed, or changed field/rule.
6. Call out unresolved assumptions and `TODO` items in your summary.

## Output Expectations

When reporting changes in this area:

1. Name the queries and docs changed.
2. Summarize the business rule or schema impact.
3. Mention any follow-on work needed in Power BI Desktop or the semantic model.
4. Flag mismatches between docs and implementation explicitly.
5. When documenting a Power BI visual, specify the exact `Rows`, `Columns`, `Values`, and required filters or slicers instead of describing the layout at a high level only.
