# 03 - Additional Services Forecast vs YTD

Tab: **Additional Services Forecast vs YTD**. Visible.

Full-year Additional Services target against year to date, by reporting line. This is the
`Forecast v Accrued / Invoiced` block of the client's workbook, renamed *"forecast versus year to
date"* (11 Sep 2026). It is the only bottom-table block in scope.

Shared header, canvas, slicer rules and formats: [Report Overview](00%20-%20Report%20Overview.md).

## Header

| Element | Setting |
|---|---|
| Title text | **Confirm** |
| Period card | `AS Reporting Period`, same styling as the profitability tab (white on header blue) |

No empty strip between the header and the matrix (18 Sep 2026).

## Layout (top to bottom)

1. Header band
2. Filter area: Year, Mapping, Sector slicers
3. Main matrix

## Slicers

| Title | Field | Selection | Visual-level filters | Sync |
|---|---|---|---|---|
| Year | `dim_Date_Live[Year]` | Single select | `Year Has Actuals` is 1 | No |
| Mapping | `dim_Project_Live[Upstream Report A]` | Dropdown, multi-select, select all | Not blank | With tab 02 |
| Sector | `dim_Project_Live[Sector]` | Dropdown, multi-select, select all | Not blank | With tab 02 |

**No Contract or Project slicer on this tab.** Each reporting line's target sits on one placeholder
project (`JBL-02` Finance Only, `BLP-03` England North, `ABH-02` Highways, ...). Any contract or project
selection would blank the target (18 Sep 2026). The Mapping slicer filters whole reporting lines, so
targets stay intact.

## Main matrix

| Setting | Value |
|---|---|
| Visual | Matrix, stepped layout on |
| Rows | `dim_Project_Live[Sector Reporting - Mapping]` -> `[Sector]` -> `[Contract]` -> `[Project Display]` |
| Row sort | `Sector Reporting - Mapping` sorted by `Upstream Report A` |
| Columns | none |
| Totals | Row subtotals on. Grand total on |

### Values (in order)

| Column heading | Measure | Format |
|---|---|---|
| Additional Services Target | `AS Target` | £, nearest £1 |
| Year to Date | `AS Revenue` | £, nearest £1 |
| Variance to Target | `AS Variance to Target` | £, nearest £1. **Font colour: Format by field value, `AS Variance Colour`** (green `#00B050` at or above zero, red `#C00000` below) |

- `AS Target` and `AS Variance to Target` show on the reporting-line rows and the total only. They are
  blank when `Sector`, `Contract` or `Project Display` is in scope, because the target exists only at
  reporting-line level. The drill-down shows year to date only.
- Variance is **year to date minus target** (short = negative, red; ahead = positive, green). This
  matches the client's workbook (18 Sep 2026).
- `1.07 Corporate Finance` has no target, so its variance equals its year to date.

### Filters

| Level | Filter | Reason |
|---|---|---|
| Visual | `dim_Project_Live[Sector Reporting - Mapping]` is not blank | Hides the unmapped row (30 Sep 2026) |
| Visual | `dim_Project_Live[Sector Reporting - Mapping]` is not `2.71 Scotland Development` | Client request, 30 Sep 2026 |

Do not exclude the `Internal` sector (see tab 02).

## Target source

`fact_AdditionalServicesTarget_Live`: the monthly columns of `Additional Services Forecast.xlsx` in
the SharePoint Data folder, summed. It reconciles to the client workbook at 1,958,074.80 against
1,958,075. To add 2027, the client extends the file to the right. No change is needed here.

## Measures used

`AS Target`, `AS Revenue`, `AS Variance to Target`, `AS Variance Colour`, `AS Reporting Period`,
`Year Has Actuals`.

## Confirm in Desktop

- [ ] Title text
- [ ] **Sector slicer against targets.** Check each placeholder project's `Sector` in Data view. If a
      placeholder's Sector differs from the real projects on its reporting line, a Sector selection
      blanks or misstates that line's target
- [ ] Slicer positions and order, and whether Year is single select
