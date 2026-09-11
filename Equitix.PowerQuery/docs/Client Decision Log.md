# Client Decision Log

This log captures concise client decisions that explain current Power Query and measure behavior. Keep exact quoted rationale here when a rule has changed or could be disputed later.

## 02 Apr 2026 - Historical Kick-off Transcript And Slides Logged

- Source note: [[2026-04-02 - Synetec Equitix Kick-off - Contract Profitability Reporting]].
- Kick-off deck note: [[2026-04-02 - Equitix Kickoff Slides]].
- Raw transcript archive: [[2026-04-02 Synetec Equitix Kick-off - Contract Profitability Reporting.docx]] and searchable extract [[2026-04-02 Synetec Equitix Kick-off - Contract Profitability Reporting.txt]].
- Raw deck archive: [[2026-04-02 Equitix Kickoff Slides.pptx]].
- Historical context only: this kick-off captured the original YTD actuals plus full-year forecast profitability concept, source landscape, access needs, deck prompts, and early open questions.
- Do not use this entry to supersede later decisions. Current rules remain the later dated entries below, especially actual OOC revenue `40013` only, actual subcontractor reconciliation `60201` only, the simplified staff-cost calculation, and the deferred Region hierarchy.

## 21 Apr 2026 - Historical Staff-Cost Equalisation Transcript Logged

- Source note: [[2026-04-21 - Equitix Profitability Reporting Catch Up]].
- Raw transcript archive: [[2026-04-21 Equitix profitability reporting - Catch up.docx]] and searchable extract [[2026-04-21 Equitix profitability reporting - Catch up.txt]].
- Historical context only: this catch-up captured the early monthly staff-cost equalisation/floor-and-ceiling idea and the `EMS 90` unsubmitted-timesheet placeholder discussion.
- Do not use this entry to supersede the later simplified staff-cost rule. Current staff actual cost remains booked hours multiplied by country-aware hourly rate, with no monthly cap, floor, or ceiling.

## 13 May 2026 - Historical OOC Forecast And Subcontractor Transcript Logged

- Source note: [[2026-05-13 - Equitix Profitability Reporting Weekly Check-in]].
- Raw transcript archive: [[2026-05-13 Equitix Profitability Reporting Weekly Check-in.docx]] and searchable extract [[2026-05-13 Equitix Profitability Reporting Weekly Check-in.txt]].
- Historical context only: this weekly check-in captured the expected Additional Services/OOC forecast file, early actual revenue code split, early subcontractor-code discussion, temp-staff double-counting concern, and Dataverse/Power BI workspace access notes.
- Do not use this entry to supersede later decisions. Current rules remain actual OOC revenue `40013` only, OOC forecast via Additional Services Forecast, and actual subcontractor reconciliation `60201` only with later exclusions.

## 03 Jul 2026 - Actual Out-of-Contract Revenue

- Current rule: actual/report Revenue Out of Contract uses account code `40013` only.
- Superseded rule: account code `40014` was previously included in actual OOC revenue.
- Client reason for excluding `40014`: "40014 is recharged cost."
- Supporting purpose for the OOC revenue column: "the purpose of that column is just to give the sector teams their breakdown of the additional services they've earned in the year."
- Forecast exception: OOC forecast still uses account code `40014` from the Additional Services Forecast file.

## 02 Jul 2026 - Account-Code Reconciliation Rules

- Actual OOC revenue reconciliation: "Revenue OO-contract total should equal to the sum of 40013 (account no.) in the FinanceOutput FY26 data set."
- Actual subcontractor cost reconciliation: "Total subcontractor costs should equal the sum of 60201."

## 05 Jul 2026 - Subcontractor Actual Sign

- Current rule: `Subcontractor Actual` remains the raw actual subcontractor account `60201` sum.
- Reporting rule: use `Subcontractor Actual Flipped` when the report needs the displayed subcontractor actual sign reversed.
- HARP-specific handling is intentionally deferred.

## 07 Aug 2026 - Subcontractor GL Filter

- Current rule: actual subcontractor costs reference GL account code `60201` only, excluding `EMS-04` and blank project/class transactions.
- Screenshot reconciliation baseline: 2025 Power BI raw total `-217,158.69` matches the Excel magnitude `217,158.69`; 2026 Power BI raw total `-217,651.21` does not match the Excel magnitude `243,536.16`, a variance of `25,884.95` ignoring sign.
- Client reconciliation totals from Eve: 2026 excluding internal projects YTD = GBP 243.54k; 2025 = GBP 217.16k.
- Implementation note: apply the exclusion before renaming `Class: Class External ID` to `Project Code` in `_Cost_Subcontractor_Actuals`.

## 03 Jul 2026 - Employee Table Removal And Contract / Project Filters

Clean Power BI Desktop instructions:

1. Open the active profitability report page containing the top-left employee data table.
2. Select only the employee data table visual and delete it.
3. Do not delete or modify `dim_Employee_Live`, employee queries, staff-cost measures, timesheet relationships, or cost calculations.
4. Add a Contract slicer in the freed top-left area.
5. Configure the Contract slicer with `dim_Project_Live[Contract]`.
6. Set the Contract slicer title/header to `Contract`.
7. Add a Project slicer near the Contract slicer.
8. Configure the Project slicer with `dim_Project_Live[Project Display]`.
9. Set the Project slicer title/header to `Project`.
10. For both slicers, allow multi-select, enable search, and enable select-all.
11. Confirm both slicers filter the report tables/matrices on the page.
12. Do not change the matrix hierarchy unless separately requested; keep `Sector -> Contract -> Project Display`.

## 04 Sep 2026 - Additional Services Report Scope And TYH-01 Root Cause

- Source note: [[2026-09-04 - Equitix Profitability Reporting Follow-up Call]].
- Raw transcript archive: [[2026-09-04 Equitix Profitability Reporting Follow-up Call.docx]] and searchable extract [[2026-09-04 Equitix Profitability Reporting Follow-up Call.txt]].
- Root cause: a project-code mismatch between the project database and NetSuite, not a missing project or missing sector in `crbb5_projects`. Equitix amended NetSuite to match the project database and confirmed by email on 27 Aug 2026. This supersedes the 26 Aug 2026 email hypothesis.
- Correct project code is `TYH-01`. The 18 Aug and 26 Aug 2026 emails referred to it as `THY-01`; use `TYH-01` in future correspondence and queries.
- Verified 04 Sep 2026 after the full refresh: `TYH-01` is present in the report and the subcontractor totals reconcile.
- Action arising: full report refresh including end-of-July month-end data before Equitix re-reviews July.
- Additional Services report scope: bring account code `40013` into a separate report. Chris: "it needs to be brought into a separate report for just the additional services, the 40013 code."
- Client-supplied inputs: only the adjustments data set is outstanding. All other inputs, including Grant's out-of-contract forecast projection (the 1.9m figure), are already available through the profitability model. The email-supplied EMS Revenue workbook is not required in SharePoint.
- Adjustments decision: a separate adjustments data set goes into the SharePoint Data folder, manual entry, project plus monthly adjustment. Chris: "it's just moving the revenue in the period." The `ARevenueADJUSTMENTS` tab route was not adopted.
- Expected variance until then: the Additional Services report will be out by exactly the adjustments amount.
- Drill-through decision: reuse the existing drill-down behaviour so all three reports are consistent. Equitix will review the built report and raise any differences.
- Not revisited on this call: subcontractor account-code scope. The active rule remains `60201` only with the 07 Aug 2026 exclusions.

## 10 Sep 2026 - Adjustments Become An Automated iXBRL Reclassification

- Source: Eve Dillon (Financial Controller) email, 10 Sep 2026 14:05, thread "Equitix profitability reporting: follow-up on files and clarifications".
- Supersedes the 04 Sep 2026 adjustments decision. There is no manually-maintained adjustments data set and none is required.
- Client reason for the change: "the source data for the adjustments data can come directly from the existing Finance Output FY26 transaction data loaded into the model."
- Scope reduction: "We are no longer planning to bring across the wider finance adjustment process (e.g. one-off accruals, Derby Street Lighting adjustments, etc.) so the only adjustment logic required in the Power BI model is the automated iXBRL reclassification."
- Current rule: match Financial Output FY26 transactions on account number `40013` AND `Memo` containing `ixbrl`, reverse the value off the original project code, and reallocate the same value to `EMS-04`, which maps to reporting line `1.07 Corporate Finance`.
- Case sensitivity is an explicit client instruction: "The memo should be checked against a lower-case version of the field." Power Query's `Text.Contains` is case-sensitive by default, so the field is lowered before comparison.
- Generation method: "The intention is that this is generated automatically within Power Query rather than being maintained through a separate adjustment input file."
- Implementation: `helpers/_Revenue_Adjustment_iXBRL.pq`, appended into `fact_Revenue_Live` and carrying `Type = "Adjustment"` so the movement is visible in drill-through rather than netted into the actuals.
- Open with the client: whether the rule also applies to prior-year GL data. The specification is stated for FY26 only.
- Rule validated 11 Sep 2026 against the 11 Aug workbook: of 311 sector-side amounts on the manual `ARevenueADJUSTMENTS` tab, **309 trace to a NetSuite `40013` line whose `Memo` contains `iXBRL`**. Eve's specification is therefore the correct rule, and the memo marker is genuinely present in the source data. The remaining 2 have no memo marker; because the rule is anchored on `40013` they simply stay on their original project, which is the safe direction to fail in.
- Feed shortfall found the same day, and it is a data issue rather than a logic one: the workbook's `NSRevenue` extract holds **1,398** `40013` rows totalling **-995,256.87**, of which **323 rows totalling -21,270.00** carry an iXBRL memo. The model's `stg_FinanceOutput FY26_FY2026` matches only **5** rows totalling **-400.00**. Check `FinanceOutput FY26.xlsx` for a saved Excel filter or a partial extract before changing any query logic.
- Separate discrepancy to resolve with the client: `iXBRLProof` states iXBRL project fees of **62,070** as a hard-coded constant, but the GL-derived iXBRL rows total **-21,270.00**. The `+62,070.00` Chris posted to `1.07 Corporate Finance` is therefore not reproducible from the GL alone, so the automated rule will not land on the workbook's iXBRL line of `29,509.90` without an explanation of the difference.
- Reconciliation caveat: this derived rule is net-nil by construction, whereas the manual `ARevenueADJUSTMENTS` tab netted to `+10,557.60` because it also carried entries compensating for revenue that the reporting-line mapping drops (`ZZZ-01` at `-10,357.60` and `SWH-01` on `2.71 Scotland Development` at `-200.00`). The automated reclassification therefore will not reproduce the workbook total until that unmapped revenue has a confirmed home.
- Stakeholder note: memo-text matching was raised as a risk by Chris Rolls on the 11 Aug 2026 call ("that may or that could break"). The `40013` account filter narrows the failure mode so an unmatched memo under-collects rather than mis-allocates, but both stakeholders are on the thread and neither has been shown the other's position. Confirm with both before this ships.
