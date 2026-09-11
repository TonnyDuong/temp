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
  - Clarified 11 Sep 2026: "separate report" means a separate tab/page within the existing `.pbix`. Do not create an additional `.pbix` or a live-connected thin report.
- Client-supplied inputs: only the adjustments data set is outstanding. All other inputs, including Grant's out-of-contract forecast projection (the 1.9m figure), are already available through the profitability model. The email-supplied EMS Revenue workbook is not required in SharePoint.
- Adjustments decision: a separate adjustments data set goes into the SharePoint Data folder, manual entry, project plus monthly adjustment. Chris: "it's just moving the revenue in the period." The `ARevenueADJUSTMENTS` tab route was not adopted.
- Expected variance until then: the Additional Services report will be out by exactly the adjustments amount.
- Drill-down decision: reuse the existing drill-down behaviour so all three reports are consistent. Equitix will review the built report and raise any differences.
  - Clarified 11 Sep 2026: this means the **matrix row drill-down hierarchy**, matching the existing `Sector -> Contract -> Project Display` pattern. It is not the separate Power BI drill-through feature, and no drill-through target page is required by this decision.
  - "Report" throughout this entry means a **tab/page inside the existing `.pbix`**, not an additional file for the client to manage. All three reports live in one file.
- Not revisited on this call: subcontractor account-code scope. The active rule remains `60201` only with the 07 Aug 2026 exclusions.

## 10 Sep 2026 - Adjustments Become An Automated iXBRL Reclassification

- Source: Eve Dillon (Financial Controller) email, 10 Sep 2026 14:05, thread "Equitix profitability reporting: follow-up on files and clarifications".
- Supersedes the 04 Sep 2026 adjustments decision. There is no manually-maintained adjustments data set and none is required.
- Client reason for the change: "the source data for the adjustments data can come directly from the existing Finance Output FY26 transaction data loaded into the model."
- Scope reduction: "We are no longer planning to bring across the wider finance adjustment process (e.g. one-off accruals, Derby Street Lighting adjustments, etc.) so the only adjustment logic required in the Power BI model is the automated iXBRL reclassification."
- Current rule: match Financial Output FY26 transactions on account number `40013` AND `Memo` containing `ixbrl`, reverse the value off the original project code, and reallocate the same value to `EMS-04`, which maps to reporting line `1.07 Corporate Finance`.
- Case sensitivity is an explicit client instruction: "The memo should be checked against a lower-case version of the field." Power Query's `Text.Contains` is case-sensitive by default, so the field is lowered before comparison.
- Generation method: "The intention is that this is generated automatically within Power Query rather than being maintained through a separate adjustment input file."
- Implementation: `helpers/_Revenue_Adjustment_iXBRL.pq`, appended into `fact_Revenue_Live` and carrying `Type = "Adjustment"` so the movement stays visible as its own row type rather than being netted into the actuals.
- Open with the client: whether the rule also applies to prior-year GL data. The specification is stated for FY26 only.
- Rule validated 11 Sep 2026 against the 11 Aug workbook: of 311 sector-side amounts on the manual `ARevenueADJUSTMENTS` tab, **309 trace to a NetSuite `40013` line whose `Memo` contains `iXBRL`**. Eve's specification is therefore the correct rule, and the memo marker is genuinely present in the source data. The remaining 2 have no memo marker; because the rule is anchored on `40013` they simply stay on their original project, which is the safe direction to fail in.
- Feed shortfall found the same day, and it is a data issue rather than a logic one: the workbook's `NSRevenue` extract holds **1,398** `40013` rows totalling **-995,256.87**, of which **323 rows totalling -21,270.00** carry an iXBRL memo. The model's `stg_FinanceOutput FY26_FY2026` matches only **5** rows totalling **-400.00**. Check `FinanceOutput FY26.xlsx` for a saved Excel filter or a partial extract before changing any query logic.
- ~~Separate discrepancy to resolve with the client: `iXBRLProof` states iXBRL project fees of **62,070** as a hard-coded constant.~~ **CLOSED 11 Sep 2026.** Once the July close was present in the GL, the automated rule reproduced it exactly: the reclassification posts **+62,070.00** to `1.07 Corporate Finance`, against a pre-adjustment balance of **-32,560.10** (`EMS-04` -32,631.40 plus `EMI-01` +71.30), giving **29,509.90** — the workbook's iXBRL line to the penny. The earlier shortfall was the missing July data, not a gap in the rule. Do not raise this with the client.
- Reconciliation caveat: this derived rule is net-nil by construction, whereas the manual `ARevenueADJUSTMENTS` tab netted to `+10,557.60` because it also carried entries compensating for revenue that the reporting-line mapping drops (`ZZZ-01` at `-10,357.60` and `SWH-01` on `2.71 Scotland Development` at `-200.00`). The automated reclassification therefore will not reproduce the workbook total until that unmapped revenue has a confirmed home.
- Stakeholder note: memo-text matching was raised as a risk by Chris Rolls on the 11 Aug 2026 call ("that may or that could break"). The `40013` account filter narrows the failure mode so an unmatched memo under-collects rather than mis-allocates, but both stakeholders are on the thread and neither has been shown the other's position. Confirm with both before this ships.

## 11 Sep 2026 - Additional Services Grouping Field, And GL Feed Missing July 2026

Both findings are ours, from investigation. Neither is a client decision; the second needs a client action.

### Grouping field resolved

- `crbb5_contractregister` carries two reporting-line lookups to the Areas of Responsibility entity: `crbb5_upstreamreportaname` and `crbb5_upstreamreportbname`, surfaced in `dim_Project_Live` as `Upstream Report A` / `Upstream Report B`.
- **`Upstream Report A` is the Additional Services report's primary grouping.** Its values are the `2.xx` operations/sector series plus `1.07 Corporate Finance`, matching the `Sector Lead Reporting` column on the source workbook's `Project` tab (1,246 projects, one value each, 16 distinct values).
- `Upstream Report B` is a regional **finance** reporting line (`1.01 London Finance`, `1.03 Nottingham Finance`, `1.04 Manchester Finance`, `1.05 Leeds, Newcastle Finance`, `1.06 Glasgow Finance`, `1.02 Italy Finance`). It does not appear in the source workbook.
- `crbb5_revenuefinance` / `crbb5_revenueops` on `crbb5_project` are allocation fractions summing to 1 that split a project's revenue between the finance line (B) and the operations line (A).
- Current rule: group on `Upstream Report A` alone, because that is what the workbook the client has signed off does. **Open question for the client:** whether the finance/ops split should be applied. If it should, the present report overstates the sector lines and omits the regional finance lines entirely.
- Reporting lines that exist in the data but have no row on the report: `2.71 Scotland Development` (142 projects), `4.01 Risk Management` (26), `3.12 Information Systems` (8), `1.01 London Finance` (2). `2.71` is the fourth-largest line by project count, which raises the significance of the existing open question about adding it.

### GL feed is missing the July 2026 close

- Period profile of account `40013` in the workbook's `NSRevenue` extract: Jan 167 rows, Feb 107, Mar 191, Apr 191, May 140, Jun 136, **Jul 466**. Total 1,398 rows, -995,256.87.
- **313 of the 323 iXBRL-memo rows are in July 2026.** The model's `stg_FinanceOutput FY26_FY2026` matches only 5, and per-memo line counts across unrelated memos run at roughly two-thirds of the workbook's (48 vs 33, 32 vs 22, 16 vs 11), which is consistent with July being absent.
- **This is the same root cause as Eve Dillon's 09 Sep 2026 report that YTD revenue shows 17.9m against an expected 20.7m.** One missing month's data explains both symptoms.
- It is not an Excel filter and not a query defect. The outstanding action recorded on 04 Sep 2026 — "full report refresh including end-of-July month-end data before Equitix re-reviews July" — has not taken effect in the GL the model reads.
- Consequence for the iXBRL reclassification: it cannot be reconciled or shipped until the July close is present in `FinanceOutput FY26.xlsx`. No code change is required.

## 11 Sep 2026 - Additional Services Report Reconciled To The July 2026 Close

Verification result, not a client decision. Recorded because it closes several open items.

- The Additional Services page reconciles to `For JC file` table 1 at **995,256.87**, with ten of the eleven reporting lines matching to the penny: Finance Only 146,009.02, SI Scotland 16,958.28, SI England North 135,117.43, SI England South 63,015.06, SI Ireland 1,292.46, SI Italy 83,185.21, Highways 115,576.95, Renewables 160,140.99, Environmental Services 225,312.13, and the iXBRL line (`1.07 Corporate Finance`) 29,509.90.
- The single difference is **Streetlighting: 8,781.84 against the workbook's 19,139.44**, a gap of exactly **10,357.60**, which appears in the model as an explicit **unmapped (blank) reporting-line row** of the same amount.
- That is the `ZZZ-01` New Business Code artefact. The workbook parks the compensating +10,357.60 on Streetlighting, which is why its total ties while Streetlighting itself is overstated. The model instead surfaces the revenue in an unmapped bucket. **The model's treatment is the more correct of the two** and it is the intended design: an explicit unmapped bucket rather than the workbook's silent `IFNA(..., 0)`.
- Per-line iXBRL movements also match the workbook's manual tab: `1.07 Corporate Finance` +62,070.00, `2.00 Finance Only` -21,520.00, `2.02 SI England North` -18,810.00, `2.03 SI England South` -6,920.00, `2.01 SI Scotland` -4,080.00. Streetlighting's pure movement is **-8,270.00**; the workbook shows +2,087.60 because it carries the +10,357.60 compensation on the same line (-8,270.00 + 10,357.60 = 2,087.60).
- **`ZZZ-01` is excluded, and this is settled — do not raise it with the client.** Established on 03 Jul 2026 in the profitability reporting thread: "Project `ZZZ-01` also seems to be missing from the project filter... When comparing against the FY2026 sheet, the figures for Revenue Actuals Out of Contract and SubContractor Cost Actuals match if these projects are filtered out." The `Internal` sector (EMI and EMS projects) is filtered out on the same basis for that report.
- Mechanism, worth knowing: `ZZZ-01` is not present in `crbb5_project`, so it has no `dim_Project_Live` row and lands in the unmatched (blank) member of the relationship. It is excluded by absence rather than by an explicit rule.
- **Caveat for the Additional Services report specifically.** The exclusion rule above was validated against the *Contract Profitability* out-of-contract figures. The Additional Services workbook does the opposite: `For JC file` includes `ZZZ-01`'s 10,357.60 in its 995,256.87 total by parking a compensating entry on Streetlighting. So applying the exclusion here moves the headline total JC sees from **995,256.87 to 984,899.27** — which is the figure the workbook's own `Checks` block already carries alongside the NSRevenue total. Flag the change to the client rather than letting it be noticed.
- Note the `Internal` sector must NOT be filtered out of the Additional Services report: `EMS-04` and `EMI-01` are Internal, and they are the `1.07 Corporate Finance` line that carries the iXBRL total.
- The July 2026 close is present in the GL as at this date, so the feed shortfall recorded above is resolved.

## 11 Sep 2026 - Additional Services Bottom Table: Source Trace And Target Inputs

Findings from investigation, not client decisions. Recorded because they define what
the second half of the Additional Services report still needs and what it does not.
Source workbook: `26.07 EMS Revenue NS JC LIVE updated v2.xlsx`, `For JC file` rows 26-45.

### The deliverable reduces to four inputs

Blocks B, C and D repeat the same figures (`P = K`, `U = L`, `V = Q`, with the deltas
plain arithmetic), and column `S` is a sign-flipped duplicate of `Q` that Chris already
confirmed as testing residue. Stripping the copies leaves four distinct inputs:

1. **YTD actuals by reporting line** (`Q`, via table 1). **Solved** - already reproduced
   by the model at 995,256.87.
2. **Target total 1,958,075** (`D26` = `K40`). **Derivable, with one gap** - see below.
3. **Per-sector target split** (`K28:K37`). **Not sourced** - pasted values equal to
   column `I` times 1,958,075, verified to nine decimal places.
4. **Current Estimate**, the revisable sector target (`L28:L37`). **Absent** - no
   formulas, no values, and no source anywhere in the file.

### The target total is NetSuite budget data, not a spreadsheet

`BRevenueByProject` columns F/G/H call `_xll.NSGLAPBUD(entity, "Forecast", account,
01/01/2026, 31/12/2026, "Class", project)` - the NetSuite **budget** function, budget
category `Forecast`. So 1,958,075 is NetSuite FY2026 budget on account `40013`, less a
hard-coded **87,169** in `BudgetTarget!C3` that the workbook does not explain. "Solution 7"
is only the label on the project list in `B4`, not the data source. The model already reads
NetSuite actuals through `FinanceOutput FY26`; the budget is the same system, another extract.

- **Open question for the client:** what the 87,169 deduction represents.

### The per-sector split cannot be recovered from the budget

`BRevenueByProject` column H is the per-project `40013` budget and carries a reporting line,
so in principle the split is a `SUMIFS`. In practice **the entire 2,045,244 sits on project
code `ZZZ-01`** - one non-zero row out of 1,204, every sector line zero. This is the same
`ZZZ-01` that holds the 10,357.60 of unmapped actual revenue; it is the unallocated bucket on
both the actual and budget sides. Chris described this on the 11 Aug call: the forecast was
allocated to a single project code rather than spread across sectors. An apportionment is
therefore structurally necessary, and the workbook contains three that disagree.

### The fee book is the one input with no derivation

`For JC file` `B28:G37` is a sector-lead by supersector matrix totalling 24,520,619.28, held
as pasted values. It does not reconcile to the budget - fee book over operational budget
averages 86.4% but ranges from 35.0% (Highways) to 101.3% (Environmental Services) - so it is
an independent dataset. It also omits two of the eight supersector values on the `Project` tab
(`Internal` and blank), so it cannot be validated by totalling the project estate.

Chris confirmed the fee book **matrix** is not required for 2026. That removes the display,
not the dependency: column `K` still needs the fee-book percentages.

- **Candidate source, untested:** the `Contracts` sheet of `EMS Fixed Fee Forecast.xlsx`,
  already loaded as `stg_EMS Fixed Fee Forecast_Contracts1`, carries `crbb5_currentannualfee`
  and `Supersector`, and joins to `dim_Project_Live` for `Upstream Report A`. The same fees
  also sit on `crbb5_billingschedule`, which is loaded as a source query and consumed by
  nothing. `debug-fee-book-coverage.pq` and `debug-fee-book-reconciliation.pq` test whether
  this reproduces 24,520,619.28. **Do not rely on the hypothesis until those have been run.**

### `ExCoReporting` holds a third split, and the budget branch terminates there

The tab was previously logged as legacy and ignorable. That holds for its **actuals**, which
are pre-iXBRL and differ line by line (Finance Only +21,520.00, Streetlighting +8,270.00,
Corporate Finance -61,670.00, total 995,056.88 against 995,256.87). It does **not** hold for
its targets:

- `For JC file` never references `BudgetTarget` or `BRevenueByProject`. The only sheet that
  reads `BudgetTarget` is `ExCoReporting`, at `F15` = `BudgetTarget!G17`. So the budget-share
  derivation feeds the legacy tab, not the deliverable.
- `ExCoReporting` `F` and `I` are hard-coded per-sector targets summing to 1,958,075 and
  annotated **"Provided by GC"**. Column `I` is headed `Latest YTD Target` and `J`
  `Latest Estimate Delta` - the revisable-target concept that `For JC file` column `L` is
  waiting for. `I` currently equals `F` on every row, consistent with no revision this year.
- Dividing each GC figure by its fee-book share implies a common base of ~1,922,075 on five
  of the ten sectors, with the other five adjusted and the deltas against column `K` netting
  to exactly zero. GC's split therefore looks like **the fee-book split with five manual
  overrides**, not the budget split. Inference from the arithmetic, not stated in the file.

- **Open question for the client:** whether GC's figures are the authoritative split, who GC
  is, and how a revised target reaches us mid-year. Do not ask them to confirm `ExCoReporting`
  is ignorable without excluding the target columns from that statement.

### Two defects in `BudgetTarget`, neither material to the split choice

- The `Other Growth` block apportions 493,560 across Finance Only, Highways and Streetlighting
  but sums to **662,083.37**, over by 168,523.37, because `D46` and `D47` reference `C7`/`C8`
  (Social Infra Scotland, England North) instead of `C12`/`C13`. A drag-fill that incremented
  the rows. Correcting it moves the Highways budget-share target from 24,178.91 to 21,762.94,
  so it does not change which split to pick.
- `D41` and `D42` (Renewables 522,473, Environmental Services 688,735) are typed constants,
  not derived, so the budget-share route is not fully reproducible either.
- `For JC file` rows 41 and 42 apportion the same 1,958,075 across the six supersectors and
  are referenced by nothing in the workbook.

Neither defect is raised with the client; the budget split is not currently the basis of the
deliverable.
