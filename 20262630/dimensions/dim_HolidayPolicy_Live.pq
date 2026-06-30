// =====================================================================
// dim_HolidayPolicy_Live
// ---------------------------------------------------------------------
// Purpose:      Per-year holiday-day allowance used by the staff-cost
//               forecast calculation (Chris's 02 Jun 2026 email).
// Grain:        One row per Year.
// Dependencies: none (manually maintained).
// Load:         enabled (hidden — used as a join source in PQ).
// ---------------------------------------------------------------------
// HolidayDays       = annual-leave entitlement assumed in the forecast.
//                     28 is the AVERAGE entitlement rounded across all
//                     staff (the tenure-based range is 26–30). Chris
//                     explicitly wants this configurable per year in
//                     case of policy change.
// PublicHolidayDays = UK public holidays per year (8 typical).
//
// To change the allowance for a future year, edit the row below or add
// a new row. The forecast helper picks the row matching the Jedox row's
// Year; if no match, it falls back to the latest year present.
// =====================================================================
let
    Source = #table(
        type table [
            Year              = Int64.Type,
            HolidayDays       = number,
            PublicHolidayDays = number
        ],
        {
            {2025, 28, 8},
            {2026, 28, 8}
            // Append more rows here as policy is set for future years, e.g.
            // ,{2027, 28, 8}
        }
    )
in
    Source
