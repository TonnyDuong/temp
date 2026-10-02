# 04 - YTD+Forecast Profitability

Tab: **YtD+Forecast profitability**. **Hidden.** The client asked for it to be hidden on
25 Sep 2026: *"that will be a future launch, first step is to launch the YTD profit."*

Full-year view: year-to-date actuals plus the remaining forecast, by sector, contract and project.

Shared header, canvas, slicer rules and formats: [Report Overview](00%20-%20Report%20Overview.md).

> This tab has had no client review since July 2026. The launch formatting on the YTD tab (renamed
> headings, £1 rounding, margin to one decimal, Sector Head and Subsector filters, period label) has
> **not** been applied here. Bring it in line with [01 - YTD Profitability](01%20-%20YTD%20Profitability.md)
> before this tab launches.

## Header

| Element | Setting |
|---|---|
| Title text | `YEAR TO DATE + FORECAST ANALYSIS` |
| Period card | **Confirm**: `System Date` in the 30 Jun 2026 file |

## Slicers

| Title | Field | Selection | Visual-level filters |
|---|---|---|---|
| Year | `'Reporting Year'[Year]`. **Confirm**: `dim_Date_Live[Year]` in the 30 Jun 2026 file | Single select | none |
| Contract | `dim_Project_Live[Contract]` | Multi-select, search, select all | Not blank |
| Project | `dim_Project_Live[Project Display]` | Multi-select, search, select all | Not blank |

## Main matrix

| Setting | Value |
|---|---|
| Visual | Matrix |
| Rows | `dim_Project_Live[Sector]` -> `dim_Project_Live[Contract]` -> `dim_Project_Live[Project Display]` |
| Columns | none |

### Values (in order)

| Measure | Notes |
|---|---|
| `Revenue Act In-Contract` | |
| `Revenue Act Oo-Contract` | Account `40013` only |
| `Revenue For In-Contract` | Includes HARP. HARP has no separate column (16 Jun and 6 Jul 2026) |
| `Revenue For Oo-Contract` | Additional Services forecast, account `40014` |
| `Staff Cost Actual` | |
| `Staff Cost Forecast` | Jedox allocation x revised annual cost, spread over 12 months |
| `Subcontractor Actual` | **Confirm** sign handling, as on tab 01 |
| `Subcontractor Forecast` | |
| `Total Revenue FY` | |
| `Total Costs FY` | |
| `Profit FY` | |
| `Margin FY %` | |

Removed columns, which must not come back: `Revenue Forecast for 2025` (24 Jun 2026) and `Revenue
Forecast HARP` (16 Jun 2026).

## Confirm in Desktop

- [ ] Everything marked **Confirm** above. This spec is from the 30 Jun 2026 file and the July
      decisions, and the tab has not been checked since
- [ ] Whether the employee table from the 30 Jun 2026 file has been removed here too (it was removed
      from the YTD tab on 3 Jul 2026)
