// =====================================================================
// Debug_Contract_Sector_Split  (temporary diagnostic query)
// ---------------------------------------------------------------------
// Purpose:      Story 5013. The summary page shows each contract's
//               sector and subsector on the contract row. Sector and
//               Subsector come from the contract register, so every
//               project on one register row carries the same values.
//               The report's Contract field is the contract title (or
//               MSA Reference), and two register rows can share a
//               title. This query lists every Contract value whose
//               projects carry more than one Sector, Subsector or
//               register row, so the contract row would show two
//               values.
// Grain:        One row per Contract value with a split. An empty
//               result means no contract row carries two values.
// Dependencies: dim_Project_Live
// Load:         ENABLE during diagnosis only; remove afterward.
// ---------------------------------------------------------------------
// Internal projects and blank contracts are left out, as on the page.
// Where a split exists, Summary Sector and Summary Subsector show the
// values joined with ", " on the contract row.
// =====================================================================
let
    Projects = Table.SelectRows(#"dim_Project_Live", each
        [Sector] <> "Internal"
        and [Contract] <> null
        and [Contract] <> ""),

    Narrowed = Table.SelectColumns(Projects,
        {"Contract", "crbb5_contract", "MSA Reference", "Contract Status",
         "Sector", "Subsector", "Project Code"}),

    Distinct = (values as list) as list =>
        List.Sort(List.Distinct(List.Transform(values, each
            if _ = null or _ = "" then "(blank)" else Text.From(_)))),

    Grouped = Table.Group(Narrowed, {"Contract"}, {
        {"Register Rows", each List.Count(Distinct([crbb5_contract])), Int64.Type},
        {"MSA References", each Text.Combine(Distinct([MSA Reference]), ", "), type text},
        {"Contract Statuses", each Text.Combine(Distinct([Contract Status]), ", "), type text},
        {"Project Codes", each Text.Combine(Distinct([Project Code]), ", "), type text},
        {"Sectors", each Text.Combine(Distinct([Sector]), ", "), type text},
        {"Sector Count", each List.Count(Distinct([Sector])), Int64.Type},
        {"Subsectors", each Text.Combine(Distinct([Subsector]), ", "), type text},
        {"Subsector Count", each List.Count(Distinct([Subsector])), Int64.Type},
        {"Projects", each Table.RowCount(_), Int64.Type}
    }),

    Split = Table.SelectRows(Grouped, each
        [Register Rows] > 1 or [Sector Count] > 1 or [Subsector Count] > 1),

    Sorted = Table.Sort(Split, {{"Contract", Order.Ascending}})
in
    Sorted
