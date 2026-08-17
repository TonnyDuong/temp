# Client Decision Log

This log captures concise client decisions that explain current Power Query and measure behavior. Keep exact quoted rationale here when a rule has changed or could be disputed later.

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
