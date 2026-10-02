# Report Overview

Current-state specification of the Equitix profitability Power BI report: what is on each tab and how
it is built. It is written so a tab can be rebuilt from scratch, and so a future change can be checked
against what is there now.

- Model (Power Query and DAX): [`Equitix.PowerQuery/`](../../Equitix.PowerQuery/)
- Measures: [`Equitix_Measures.txt`](../../Equitix.PowerQuery/Equitix_Measures.txt)
- Why things are the way they are: [Client Decision Log](../../Equitix.PowerQuery/docs/Client%20Decision%20Log.md)

**Keep these files current.** When a report change ships, update the tab's file in the same change as
the query or measure it depends on.

Items marked **Confirm** are not pinned down by the written record. Check them in Desktop and replace
the marker with the actual setting.

## Tabs

| Order | Tab | Visibility | Spec |
|---|---|---|---|
| 1 | YtD actual profitability | Visible | [01 - YTD Profitability](01%20-%20YTD%20Profitability.md) |
| 2 | Additional Services Monthly Actuals | Visible | [02 - Additional Services Monthly Actuals](02%20-%20Additional%20Services%20Monthly%20Actuals.md) |
| 3 | Additional Services Forecast vs YTD | Visible | [03 - Additional Services Forecast vs YTD](03%20-%20Additional%20Services%20Forecast%20vs%20YTD.md) |
| 4 | YtD+Forecast profitability | **Hidden** (future launch, 25 Sep 2026) | [04 - YTD+Forecast Profitability](04%20-%20YTD%2BForecast%20Profitability.md) |

Removed: `[TEMP] Additional Services - iXBRL Reclassification`. The client signed off the iXBRL
reallocation on 30 Sep 2026. `fact_iXBRL_Lines_Live` and the `AS iXBRL Reclassification`,
`AS Revenue Before Adjustment` and `AS Adjustment Row Count` measures stay in the model for
reconciliation.

**Confirm** the tab display names. The two profitability names come from the 30 Jun 2026 project file.
The Additional Services names are as used in client correspondence.

## Canvas (all tabs)

| Setting | Value |
|---|---|
| Page size | 1600 x 900 (custom). **Requirement (30 Sep 2026):** canvas and text must fit the screen space of a Power BI app. **Confirm** the final size and page view (Fit to width) once set |
| Canvas background | `#325EA1` |
| Vertical alignment | Middle |

## Header band (all visible tabs)

Every tab has the same header. Positions are from the 30 Jun 2026 file at 1600 x 900. Scale them if
the canvas changes.

| Element | Visual | Position (x, y, w, h) | Settings |
|---|---|---|---|
| Band | Shape, rectangle | 0, 0, 1600, 90 | Fill: theme colour 3, 25% darker. This is the **header blue** referred to elsewhere |
| Logo | Image | 0, 16, 128, 64 | `ems-logo-white-out.png` ([`assets/`](../../assets/ems-logo-white-out.png)), transparent background so it sits on the band. Scaling Normal |
| Title | Text box | 128, 16, ~600, 64 | Bold, 24pt, white (`#FFFFFF`), background header blue. Text per tab, see the tab's file |
| Period card | Card (new) | 1296, 16, 288, 64 | Field per tab (see the tab's file). Category label off. Value 20pt, left aligned, **white text on header blue background** (30 Sep 2026). Title off |

## Slicer rules (all tabs)

- **No blank option in any slicer** (25 Sep 2026). Each slicer has a visual-level filter excluding
  blank on its own field.
- **The Project slicer never offers `AAA` codes** (25 Sep 2026). They are system errors. They stay in
  the totals because their costs are real.
- Dropdown style, multi-select with select all and search, unless the tab says otherwise.

### Sync groups

| Slicer | Synced across |
|---|---|
| Mapping (`dim_Project_Live[Upstream Report A]`) | Additional Services Monthly Actuals, Additional Services Forecast vs YTD |
| Sector (`dim_Project_Live[Sector]`) | Additional Services Monthly Actuals, Additional Services Forecast vs YTD |

The Year slicers are **not** synced between the profitability and Additional Services tabs, because
they use different fields. See each tab.

## Number formats

| Kind | Format |
|---|---|
| Currency values | £, nearest £1, thousands separator (25 Sep 2026) |
| Margin % | One decimal place, `0.0%` (25 Sep 2026) |
| Target margin | `0.##%`, so 46% and 37.07% both display as entered |

## Refresh

Scheduled refresh in the service at **08:00, 13:00 and 01:00** (from 8 Sep 2026). Actuals follow the
monthly cutover on the 12th (`_CutoverDate`), so a month's actuals appear after the refresh following
the 12th of the next month.

## Year and period: two patterns

| Tabs | Year slicer field | Period card measure | Why |
|---|---|---|---|
| Profitability | `'Reporting Year'[Year]` (disconnected table) | `Reporting Period` | Profitability measures read the year through `_Selected Reporting Year` |
| Additional Services | `dim_Date_Live[Year]` with visual-level filter `Year Has Actuals` is 1 | `AS Reporting Period` | `AS Revenue` and `AS Target` filter through the `dim_Date_Live` relationship |

Both show only 2024 up to the latest year with actuals loaded. Both label the period "Period to MMM
YYYY": the latest actual month for the current year, and December for past years.
