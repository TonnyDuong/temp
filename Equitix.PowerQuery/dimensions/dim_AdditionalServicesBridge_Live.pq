// =====================================================================
// dim_AdditionalServicesBridge_Live
// ---------------------------------------------------------------------
// Purpose:      The lines of the YTD bridge on the Additional Services
//               Monthly Actuals page, which reconciles the Additional
//               Services total to the management accounts figure
//               including the internal contracts.
// Grain:        One row per bridge line.
// Dependencies: none (manually maintained).
// Load:         enabled. No relationships: the `AS Bridge Amount` measure
//               returns the figure for each line.
// ---------------------------------------------------------------------
// Line Order  = the line's position, and the key `AS Bridge Amount`
//               switches on. Set it as the sort-by column of Bridge Line.
// Bridge Line = the row label shown on the page.
// =====================================================================
let
    Source = #table(
        type table [
            #"Line Order"  = Int64.Type,
            #"Bridge Line" = text
        ],
        {
            {1, "Additional Services, as reported"},
            {2, "Internal projects (EMS and EMI)"},
            {3, "Total including internal contracts"}
        }
    )
in
    Source
