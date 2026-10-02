# 01 - YTD Profitability

Tab: **YtD actual profitability**. Visible. Launched to the business from 2 Oct 2026, replacing an
existing set of profitability reports.

Year-to-date revenue, cost, profit and margin by sector, contract and project for the selected year.

Shared header, canvas, slicer rules and formats: [Report Overview](00%20-%20Report%20Overview.md).

## Header

| Element | Setting |
|---|---|
| Title text | `YEAR TO DATE ANALYSIS` |
| Period card | `Reporting Period`, e.g. "Period to Aug 2026", "Period to Dec 2025". Replaces the former `System Date` card |

## Layout (top to bottom)

1. Header band
2. Filter area: Year, Sector Head, Subsector, Contract, Project slicers
3. Target profitability: title and table, **under the filters and above the main table** (25 Sep
   2026), so it stays in view when rows are expanded
4. Main matrix, full width, to the bottom of the canvas

**Confirm** the slicer positions and order within the filter area.

## Slicers

| Title | Field | Selection | Visual-level filters | Notes |
|---|---|---|---|---|
| Year | `'Reporting Year'[Year]` | **Single select**, defaults to the latest year | none needed (table holds 2024 to latest actual year only) | Disconnected table. Measures read it through `_Selected Reporting Year` |
| Sector Head | `dim_Project_Live[Upstream Report A]` | Multi-select | Starts with `2`; is not `2.71 Scotland Development`; not blank | Excludes `1.01 London Finance` and `1.07 Corporate Finance` by design (25 Sep 2026) |
| Subsector | `dim_Project_Live[Subsector]` | Multi-select | Not blank | Contract register `crbb5_sectorchoicename` |
| Contract | `dim_Project_Live[Contract]` | Multi-select, search, select all | Not blank | Contract title, falls back to MSA Reference |
| Project | `dim_Project_Live[Project Display]` | Multi-select, search, select all | `Project Has Activity` is 1; `Project Display` does not start with `AAA`; not blank | Hides projects with no revenue or cost for the year, and every `AAA` code |

## Target profitability

| Element | Visual | Setting |
|---|---|---|
| Title | Card or text box | `Target Profitability Title`, e.g. "Target profitability FY2026" |
| Targets | Table | Rows `dim_TargetProfitability_Live[Target]`, sorted by `[Target Order]`. Values `Target Margin`, format `0.##%` |

Source: the client-maintained `Target Profitability.xlsx` in the SharePoint Data folder, one column per
year. Targets are Breakeven, Approved budget and 20% EBITDA. A new year added to the right needs no
report change.

## Main matrix

| Setting | Value |
|---|---|
| Visual | Matrix |
| Rows | `dim_Project_Live[Sector]` -> `dim_Project_Live[Contract]` -> `dim_Project_Live[Project Display]` |
| Columns | none |
| Row subtotals | On. Grand total on |

### Values (in order)

| Column heading | Measure | Format |
|---|---|---|
| Contract fees | `Revenue Act In-Contract` | £, nearest £1 |
| Additional Services | `Revenue Act Oo-Contract` | £, nearest £1 |
| Total Revenue | `Total Revenue YTD` | £, nearest £1 |
| Staff Costs | `Staff Cost Actual` | £, nearest £1 |
| Subcontractor Costs | `Subcontractor Actual` or `Subcontractor Actual Flipped`, **Confirm** | £, nearest £1 |
| Total Costs | `Total Costs YTD` | £, nearest £1 |
| Profit | `Profit YTD` | £, nearest £1 |
| Margin % | `Margin YTD %` | `0.0%` |

Headings renamed in the visual (field rename), not in the model. Heading text from the client's 25 Sep
2026 list.

### Formatting

- **Column headings:** every value heading right-aligned to sit over its numbers. The Sector (row
  header) heading stays left-aligned (25 Sep 2026).
- **Font size:** reduced to fit the app width (25 and 30 Sep 2026). The 30 Jun file had 16pt values,
  row headers and column headers. **Confirm** the current size.

### Filters

| Level | Filter | Reason |
|---|---|---|
| Visual or page | `dim_Project_Live[Sector]` is not `Internal` | Internal (EMI, EMS) projects are excluded from profitability, so totals reconcile to the client's workings (3 Jul 2026). **Confirm** the level |
| - | Projects with a null `Sector` | Already removed in `dim_Project_Live`; no report filter needed |

`AAA` projects are **not** filtered here. They stay in the totals.

## Measures used

`Revenue Act In-Contract`, `Revenue Act Oo-Contract`, `Total Revenue YTD`, `Staff Cost Actual`,
`Subcontractor Actual` / `Subcontractor Actual Flipped`, `Total Costs YTD`, `Profit YTD`,
`Margin YTD %`, `Reporting Period`, `Project Has Activity`, `Target Margin`,
`Target Profitability Title`, `_Selected Reporting Year`.

## Confirm in Desktop

- [ ] Subcontractor Costs column: which measure, and that its sign is consistent with `Total Costs YTD`
- [ ] Level of the `Internal` sector exclusion (visual, page or report)
- [ ] Slicer positions and order
- [ ] Matrix font size and the final canvas size after the app-fit change
- [ ] Whether 2024 has actuals. `Reporting Year` starts at 2024 regardless. If 2024 is empty, the
      lower bound should move up so the Year filter shows only years with data
