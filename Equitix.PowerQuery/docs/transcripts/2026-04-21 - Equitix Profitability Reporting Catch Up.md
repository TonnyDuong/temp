---
tags: [equitix, power-bi, transcript, historical-source]
project: "[[Equitix]]"
meeting_date: 2026-04-21
meeting_name: Equitix profitability reporting - Catch up
status: historical
---

# 2026-04-21 - Equitix Profitability Reporting Catch Up

> Historical source note. This transcript records an earlier staff-cost equalisation discussion and should not override later client decisions in [[Client Decision Log]] or [[Power BI Schema Audit - Equip Profitability Report]].

Archived source document: [[raw/2026-04-21 Equitix profitability reporting - Catch up.docx]]

Searchable text extract: [[raw/2026-04-21 Equitix profitability reporting - Catch up.txt]]

## Meeting Context

- Meeting: Equitix profitability reporting - Catch up.
- Date/time shown in transcript: 21 April 2026, 03:03pm.
- Duration shown in transcript: 16m 29s.
- Main participants in transcript: Chris Rolls, Sanjana Nagaraj, Stavros Tsagkarakis, Andrew Settle.

## Historical Signals Captured

- Staff-cost equalisation was discussed as an early approach. The idea was to hold an active employee's monthly cost constant and flex the effective hourly rate up/down according to booked hours.
- Chris described the issue with using a simple hourly cost when projects experience heavy overtime: it can make distressed projects look more unprofitable even where the business does not incur extra salary cost.
- Joiner/leaver and part-time scenarios were acknowledged as complications in the equalisation approach.
- Reporting was confirmed as monthly, even though timesheets are weekly.
- `EMS 90` was described as a placeholder/non-project code used to capture costs for unsubmitted timesheets for internal reconciliation.
- `EMS 90` cost was not expected to be visible to contract leads or sector heads.
- Data-refresh pattern discussed:
  - Dataverse tables, including contracts/projects/timesheets and related user data, were described as live/current.
  - Jedox was described as live data.
  - NetSuite actual revenue/cost data and employee cost spreadsheets were described as monthly refreshes after the ledgers/books closed.
- Chris noted a manual BambooHR/spreadsheet path for staff-cost calculations because direct Bamboo integration had restrictions at that point.
- Chris noted that almost all forecast revenue was in one file, with an exception for the largest variable-fee project, which had been added in an appendable format.

## Supersession Guardrails

Use this transcript to understand why the floor/ceiling idea existed, not as the current formula.

- Later Q&A withdrew the equalisation approach. Current staff actual cost uses booked hours multiplied by country-aware hourly rate, with no monthly cap, floor, or ceiling.
- `EMS 90` remains useful historical context for unsubmitted-time reconciliation and report visibility decisions, but it should not be treated as a live report-facing project without a later explicit decision.
- Later delivered forecast files and current source queries supersede early assumptions about forecast-file shape and handling.

## Notes For Future Use

This is the source for the earlier staff-cost equalisation conversation. Cite it when explaining why the model originally considered a floor/ceiling method, then cite later records when explaining why that method is not the active implementation.
