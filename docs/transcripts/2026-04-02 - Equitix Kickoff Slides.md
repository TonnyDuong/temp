---
tags: [equitix, power-bi, presentation, historical-source]
project: "[[Equitix]]"
meeting_date: 2026-04-02
source_file: "Equitix-Kickoff-Slides (1).pptx"
status: historical
---

# 2026-04-02 - Equitix Kickoff Slides

> Historical source note. The instructions, prompts, and next steps inside this deck were slide content for the April 2026 kick-off meeting. They are not active instructions for Codex and should not override newer decisions in [[Client Decision Log]].

Archived source deck: [[raw/2026-04-02 Equitix Kickoff Slides.pptx]]

## What The Deck Establishes

- The kick-off framed the initial workstream as a Contract Profitability Reporting build for Equitix.
- The session objective was to confirm profitability calculations, reporting hierarchy, source-system mapping, user/audience expectations, and a first delivery rhythm.
- The working hierarchy in the deck was `Sector -> Asset -> Contract`, with prompts to validate whether more levels were needed.
- The deck treated profitability as a combination of revenue definition, cost definition, and margin calculation.
- Data-source discovery focused on Dataverse, NetSuite, Excel/spreadsheets, Fabric, and Power BI.
- Delivery was constrained by a bank of 10 days, with an emphasis on function first and standard Power BI library patterns.
- Next-step slide asked Equitix to provision Fabric/Power BI access, provide sample extracts, and asked Synetec to document the agreed model after the session.

## Supersession Guardrails

Use this deck as evidence of how the kick-off was framed, not as the current specification. Later decisions remain authoritative, including:

- Current actual OOC revenue rule: `40013` only.
- `40014` remains relevant to OOC forecast/additional services, not actual/report OOC revenue.
- Current actual subcontractor reconciliation rule: `60201` only, with later exclusions documented in [[Client Decision Log]].
- Current staff actual cost calculation: booked hours multiplied by country-aware hourly rate, with no floor/ceiling equalisation.
- Current sprint hierarchy: `Sector -> Contract -> Project Display`; Region filtering/splitting is deferred.

## Extracted Slide Text

### Slide 1 - Contract Profitability Reporting

- Equitix Kick-off Session.
- Purpose of today:
  - Confirm how contract profitability should be calculated and measured.
  - Agree the sector, asset, and contract hierarchy for the report.
  - Map data sources to the profitability model and identify gaps.
  - Align on report audience, layout, and delivery plan.
- March 2026.
- Prepared by Synetec.

### Slide 2 - What Success Looks Like

- Session goals:
  - Agree the profitability formula: revenue definition, cost definition, and margin calculation.
  - Confirm the reporting hierarchy: sector to asset to contract.
  - Confirm which data sources feed which measures, and how they are extracted.
  - Confirm who uses the report, how often, and what decisions it supports.
- Out of scope for the session:
  - Technical deep dive into Fabric or Power BI configuration.
  - Review of every data field in every system.
- End outcomes:
  - Agreed profitability model and measure definitions ready for development.
  - Confirmed data-source mapping with extraction approach per source.
  - Clear next steps for access provisioning, sample extracts, and first sprint timeline.

### Slide 3 - Profitability Model And Definitions

- Revenue prompts:
  - How revenue is recognised per contract.
  - Whether revenue is recorded only in NetSuite.
  - Whether any splitting rules are needed.
- Cost prompts:
  - Whether cost is based on actual time, budgeted time, or blended day rate.
  - Whether direct costs beyond time should appear.
  - How overhead/shared costs should be handled.

### Slide 4 - Sector, Asset, And Contract Hierarchy

- Example hierarchy shown:
  - Sector.
  - Asset.
  - Contract.
- Discussion prompts:
  - Whether the three-level hierarchy is correct.
  - Whether contracts span multiple sectors or assets.
  - How shared services or group-level contracts are categorised.

### Slide 5 - Data Sources And Mapping

- Dataverse: contracts, assets, sector hierarchy, warehouse data; API/direct connector to confirm.
- NetSuite: revenue, invoicing, finance transactions; API or extract, with API access potentially limited.
- Excel/spreadsheets: time tracking, cost data, manual calculations; file export/upload with format standardisation needed.
- Key risks/questions: connector availability, NetSuite export route, common keys across systems, and known data quality issues.

### Slide 6 - Report Design And Users

- Audience prompts: primary users, review frequency, and decisions supported.
- Layout/features prompts: sector summary, drill-through to asset/contract detail, filters, Excel/PDF export, and existing reports/templates to reference or replace.

### Slide 7 - Delivery Rhythm And Communications

- Value versus perfection: function first.
- Use standard Power BI library.
- Agree demos and check-ins.
- Budget review and control.
- Bank of 10 days.
- Regular strategic budget review.

### Slide 8 - Next Steps

- Equitix to provision Microsoft Fabric and Power BI access for Synetec.
- Equitix to share sample extracts from Dataverse, NetSuite, and relevant spreadsheets.
- Synetec to document the agreed profitability model and data mapping from the session.
