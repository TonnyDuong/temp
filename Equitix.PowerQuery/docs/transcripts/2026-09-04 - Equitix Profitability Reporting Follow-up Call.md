---
tags: [equitix, power-bi, transcript, current]
project: "[[Equitix]]"
meeting_date: 2026-09-04
meeting_name: Equitix profitability reporting - follow-up on files and clarifications
status: current
---

# 2026-09-04 - Equitix Profitability Reporting Follow-up Call

> Current source note. This call answered the four open questions sent on 26 Aug 2026 and sets the active scope for the third (Additional Services) report. Decisions here are authoritative over the earlier historical transcripts.

Archived source document: [[raw/2026-09-04 Equitix Profitability Reporting Follow-up Call.docx]]

Searchable text extract: [[raw/2026-09-04 Equitix Profitability Reporting Follow-up Call.txt]]

## Meeting Context

- Meeting: Equitix profitability reporting - follow-up on files and clarifications.
- Date/time shown in transcript: 4 September 2026, 01:31pm.
- Duration shown in transcript: approximately 7m 46s.
- Main participants in transcript: Stavros Tsagkarakis, Tonny Duong, Chris Rolls, Eve Dillon, Andrew Settle.
- Purpose: walk through the four open points sent by email on 26 Aug 2026 and agree next steps.

## Decisions And Answers Captured

### 1. Subcontractor actuals / TYH-01 - closed

- Root cause was a project-code mismatch between the project database and NetSuite, not a missing project or missing sector in `crbb5_projects`. Chris described the code as transposed at one end.
- The correct project code is `TYH-01`. Our 18 Aug and 26 Aug 2026 emails referred to it as `THY-01`.
- NetSuite was amended to match the project database, so the two now link.
- Eve confirmed by email the Thursday before this call (27 Aug 2026) that the project is now included in the data.
- Action on Synetec: run a full data refresh of the report, including the end-of-July month-end data, then confirm back to Equitix.
- Eve will re-check the July transaction data set and re-review the profitability report after the refresh; no further change is expected.

### 2. Additional Services report inputs - only adjustments are outstanding

- The email-supplied EMS Revenue workbook is **not** needed in SharePoint. Chris: everything that feeds the Additional Services report is already available through the profitability model, except the adjustments data.
- The Additional Services report is the `40013` nominal code brought into its own report: "it needs to be brought into a separate report for just the additional services, the 40013 code."
- Grant's out-of-contract forecast projection (the 1.9m figure) is already present in the model as the forecast input, so it does not need re-supplying.
- Until the adjustments data arrives the report can be built, and it is expected to be out by exactly the adjustments amount.

### 3. Adjustments - separate data set confirmed

- Equitix will set up the adjustments data separately and place it in the SharePoint Data folder. The `ARevenueADJUSTMENTS` tab route was not taken.
- Expected shape: manual entry, minimal columns, project plus the monthly adjustment. Chris: "it's just moving the revenue in the period."
- Equitix to notify Synetec once the adjustments file is uploaded, so the expected data can be confirmed before ingest.

### 4. Drill-through - keep consistent

- Confirmed: the Additional Services report reuses the existing drill-down behaviour so all three reports behave the same way.
- Chris will review once built and raise anything they want done differently.

## Next Steps Agreed

- Synetec: full data refresh including July month-end, then confirm to Equitix.
- Equitix: create the adjustments data set in the SharePoint Data folder and notify Synetec.
- Synetec: build and deliver the third (Additional Services) report on `40013`, drill-through consistent with the existing two reports.
- Recurring progress check-in agreed for Friday, next occurrence 11 Sep 2026 at 14:30.

## Notes For Future Use

- This note supersedes the 26 Aug 2026 email hypothesis that the project was absent from `crbb5_projects` or missing a sector. Record the cause as a NetSuite/project-database code mismatch since corrected by Equitix.
- Refresh outcome, verified 04 Sep 2026: `TYH-01` is present and the subcontractor totals reconcile.
- The subcontractor account-code scope was not revisited on this call. The active rule remains `60201` only with the 07 Aug 2026 exclusions in [[Client Decision Log]]; the refresh reconciliation is the practical test of whether that scope is complete.
