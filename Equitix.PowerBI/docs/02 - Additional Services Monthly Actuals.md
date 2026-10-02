# 02 - Additional Services Monthly Actuals

Tab: **Additional Services Monthly Actuals**. Visible.

Out-of-contract (account `40013`) revenue by reporting line and month, after the iXBRL
reclassification. It replaces the top table of the client's `For JC file` workbook: *"a rolling what's
happened month on month"*.

Shared header, canvas, slicer rules and formats: [Report Overview](00%20-%20Report%20Overview.md).

## Header

| Element | Setting |
|---|---|
| Title text | **Confirm** |
| Period card | `AS Reporting Period`, same styling as the profitability tab (white on header blue) |

## Layout (top to bottom)

1. Header band
2. Filter area: Year, Mapping, Sector, Project slicers
3. Main matrix

**Confirm** the slicer positions and order.

## Slicers

| Title | Field | Selection | Visual-level filters | Sync |
|---|---|---|---|---|
| Year | `dim_Date_Live[Year]` | Single select | `Year Has Actuals` is 1 | No |
| Mapping | `dim_Project_Live[Upstream Report A]` | Dropdown, multi-select, select all | Not blank | With tab 03 |
| Sector | `dim_Project_Live[Sector]` | Dropdown, multi-select, select all | Not blank | With tab 03 |
| Project | `dim_Project_Live[Project Display]` | Multi-select, search, select all | Does not start with `AAA`; not blank | No |

- **Sector** is the supersector (Data Infra, Environmental Services, ...), the same field as the top
  level of the profitability matrix (30 Sep 2026).
- **Mapping** is the reporting line ("filter by upstream report", 18 Sep 2026).

## Main matrix

| Setting | Value |
|---|---|
| Visual | Matrix, stepped layout on |
| Rows | `dim_Project_Live[Sector Reporting - Mapping]` -> `[Sector]` -> `[Contract]` -> `[Project Display]` |
| Row sort | `Sector Reporting - Mapping` sorted by `Upstream Report A` (model sort-by column), so lines run 1.07, 2.00 ... 2.60 |
| Columns | Month from `dim_Date_Live`, twelve columns. **Confirm** the field (`MonthYear` sorted by `YearMonth`, or `MonthName` sorted by `Month`) |
| Values | `AS Revenue` |
| Totals | Row subtotals on. The column grand total is the **year to date** |

The row label combines the short label and the raw reporting line, e.g.
`SI Scotland - 2.01 Social Infra Scotland`. Unmapped lines show only the raw name. Both labels share
one field because a stepped matrix cannot put two row fields side by side (25 Sep 2026).

### Filters

| Level | Filter | Reason |
|---|---|---|
| Visual | `dim_Project_Live[Sector Reporting - Mapping]` is not blank | Hides the unmapped row (`ZZZ-01`), at the client's request on 30 Sep 2026; it will be remapped in the September figures. **The headline total excludes it** (10,357.60 at the July close) |
| Visual | `dim_Project_Live[Sector Reporting - Mapping]` is not `2.71 Scotland Development` | Client request, 30 Sep 2026 |

**Do not** exclude the `Internal` sector here. `EMS-04` and `EMI-01` are Internal, and they are the
`1.07 Corporate Finance` (iXBRL) line.

## What the figures include

- `AS Revenue` = out-of-contract revenue rows of type `Actual` plus `Adjustment`, sign flipped to
  positive.
- The `Adjustment` rows are the iXBRL reclassification: account `40013` lines whose lower-cased Memo
  contains `ixbrl` are moved from their project to `EMS-04` (`1.07 Corporate Finance`). They net to
  zero overall.

## Measures used

`AS Revenue`, `AS Reporting Period`, `Year Has Actuals`.

## Confirm in Desktop

- [ ] Title text
- [ ] Month column field and its sort
- [ ] Slicer positions and order, and whether Year is single select
- [ ] Whether the Mapping slicer should also hide `2.71 Scotland Development`, which is no longer in
      the table
- [ ] The values in `dim_Project_Live[Sector]` match the sector names the client uses
