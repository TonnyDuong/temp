---
tags: [equitix, power-bi, transcript, historical-source]
project: "[[Equitix]]"
meeting_date: 2026-05-13
meeting_name: Equitix Profitability Reporting Weekly Check-in
status: historical
---

# 2026-05-13 - Equitix Profitability Reporting Weekly Check-in

> Historical source note. This transcript records May 2026 clarifications. It is useful evidence for where earlier assumptions came from, but later client decisions in [[Client Decision Log]] remain authoritative where they conflict.

Archived source document: [[raw/2026-05-13 Equitix Profitability Reporting Weekly Check-in.docx]]

Searchable text extract: [[raw/2026-05-13 Equitix Profitability Reporting Weekly Check-in.txt]]

## Meeting Context

- Meeting: Equitix Profitability Reporting Weekly Check-in.
- Date shown in filename: 13 May 2026.
- Main participants in transcript: Sanjana Nagaraj, Chris Rolls, Tonny Duong.
- Main purpose: answer follow-up questions about revenue classification, additional-services forecast data, subcontractor costs, and data access.

## Historical Signals Captured

- Chris explained that actual NetSuite revenue should be split into in-contract and out-of-contract streams by account code. The transcript text refers to `0010`, `40011`, and `40012` as in-contract revenue, with context/later records treating `0010` as `40010`.
- The transcript identified `40014` as the out-of-contract/additional-services code at that time.
- Additional-services/OOC forecast was expected to come from a separate internal/director-owned data table/file, rather than directly from NetSuite or Dataverse.
- Subcontractor costs were to be separated from staff costs in the report, with distinct columns for subcontractor costs, staff costs, and total costs.
- Subcontractor codes discussed at this point were `60201` and `60203`.
- Temporary staff/contractors were to be excluded from subcontractor costs if they also book timesheets, to avoid double-counting via staff costs.
- Dataverse access was discussed through the corporate finance/Power BI workspace route.
- Dataverse-held tables called out in the transcript included contract register, project, billing schedule, timesheet tables, BambooHR/user data, and Jedox-related data.
- Timesheet volume was called out as too large for spreadsheet handling, reinforcing the need to use Dataverse for timesheets.
- SharePoint folder ingestion into Power BI depended on consistent file naming and column structures.
- Fabric was described as a more robust longer-term environment, while the immediate route was still Power BI/SharePoint workspace based.

## Supersession Guardrails

Later decisions refine or supersede several May 13 points:

- Current actual/report OOC revenue uses account code `40013` only. `40014` is retained for OOC forecast/additional-services handling, not actual/report OOC revenue.
- Current actual subcontractor reconciliation is `60201` only, with the later 07 Aug 2026 rule excluding `EMS-04` and blank project/class transactions. Do not use this May 13 note to re-add `60203` to current actual reconciliation.
- A later 29 May clarification added `60202` to the broader subcontractor-account discussion, but the active decision log still governs the current actual reconciliation.
- Additional Services Forecast was later delivered as a SharePoint file by month and project code; no whole-year-minus-YTD calculation is needed for that feed.

## Notes For Future Use

This is the source for the earlier additional-services forecast-file expectation and the first subcontractor-code discussion. Keep it as audit trail for origin/context, then defer to newer dated decision-log entries for implementation rules.
