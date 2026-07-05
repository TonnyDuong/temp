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

## 03 Jul 2026 - Employee Table Removal And Contract Filter

Clean Power BI Desktop instructions:

1. Open the active profitability report page containing the top-left employee data table.
2. Select only the employee data table visual and delete it.
3. Do not delete or modify `dim_Employee_Live`, employee queries, staff-cost measures, timesheet relationships, or cost calculations.
4. Add a slicer visual in the freed top-left area.
5. Configure the slicer with `dim_Project_Live[Contract]`.
6. Set the slicer title/header to `Contract`.
7. Allow multi-select, enable search, and enable select-all.
8. Confirm the slicer filters the report tables/matrices on the page.
9. Do not change the matrix hierarchy unless separately requested; keep `Sector -> Contract -> Project Display`.
