---
tags: [equitix, power-bi, transcript, historical-source]
project: "[[Equitix]]"
meeting_date: 2026-04-02
meeting_name: Synetec & Equitix Kick-off - Equitix Power BI Contract Profitability Reporting
status: historical
---

# 2026-04-02 - Synetec & Equitix Kick-off - Contract Profitability Reporting

> Historical source note. This transcript records early discovery and should not override later client decisions in [[Client Decision Log]] or the updated rules in [[Power BI Schema Audit - Equip Profitability Report]].

Archived source document: [[raw/2026-04-02 Synetec Equitix Kick-off - Contract Profitability Reporting.docx]]

Searchable text extract: [[raw/2026-04-02 Synetec Equitix Kick-off - Contract Profitability Reporting.txt]]

Related kick-off deck: [[2026-04-02 - Equitix Kickoff Slides]]

## Meeting Context

- Meeting: Synetec & Equitix Kick-off - Equitix Power BI Contract Profitability Reporting.
- Date/time shown in transcript: 2 April 2026, 02:01pm.
- Purpose: align on the first Power BI/Fabric contract profitability reporting workstream, data sources, access needs, delivery approach, and key unresolved business rules.
- Main participants in transcript: Jonjo Challands, Chris Rolls, Stavros Tsagkarakis, Sanjana Nagaraj, Andrew Settle.

## Historical Signals Captured

- First release concept: two profitability views, one for year-to-date actuals and one combining actuals with forecast to show expected full-year profitability.
- Revenue concept: NetSuite revenue split broadly into in-contract and out-of-contract revenue.
- In-contract definition: fixed/inflated contractual fees for agreed scope.
- Out-of-contract definition: work outside the agreed scope, typically charged by hourly rate, daily rate, or separately agreed fixed price.
- Cost concept: staff costs based on timesheets and employee rates, plus subcontractor costs from NetSuite.
- Project coding: revenue and costs are coded to project codes, which then roll up to contract/asset and sector; region/location was discussed as a possible segmentation.
- Forecast sources discussed at kickoff: billing schedule and indexation for in-contract revenue, Grant/director-owned data for out-of-contract revenue, Jedox for future staff allocation, and separate/manual handling for some inputs.
- Access needs: Dataverse, Power BI workspace, Fabric tenant/workspace, sample data extracts, and relevant manual spreadsheets.
- Initial audience: around 40 associate directors/directors as read-only users, with Jonjo and Chris involved in admin/data control/testing/sign-off.
- Initial target: a mid-May 2026 rollout using April/YTD data was described as aspirational, not guaranteed.

## Supersession Guardrails

The following later decisions are more current than this kickoff transcript:

- Actual out-of-contract revenue uses account code `40013` only. Account code `40014` is excluded from actual/report OOC revenue because it is recharged cost; `40014` remains relevant to OOC forecast from the Additional Services Forecast file.
- Actual subcontractor cost reconciliation currently uses account code `60201` only, with the later 07 Aug 2026 exclusion rule for `EMS-04` and blank project/class transactions.
- The early staff-cost floor/ceiling concept was later withdrawn. Current staff actuals use booked hours multiplied by country-aware hourly rate, with no cap/equalisation.
- Region filtering/splitting is deferred from the current sprint; the active report hierarchy is `Sector -> Contract -> Project Display`.
- Additional Services Forecast and Subcontractor Forecast were later delivered as SharePoint forecast files by month and project code, so the earlier idea of whole-year-minus-YTD treatment is no longer required for those feeds.

## Notes For Future Use

Use this transcript as evidence of original intent, vocabulary, and project background. Where it conflicts with later entries, keep the later dated client decisions as authoritative and cite this note only as historical context.
