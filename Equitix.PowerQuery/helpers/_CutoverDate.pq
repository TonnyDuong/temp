// =====================================================================
// _CutoverDate  (helper — load disabled)
// ---------------------------------------------------------------------
// Purpose:  Returns the last day of the most recent month for which
//           actuals should be used. On/after the 12th of the current
//           month, actuals are available for the PREVIOUS month, so
//           the cutover = end of previous month.
//           Before the 12th, actuals are NOT yet reliable, so the
//           cutover = end of the month two months ago.
//
// Examples (CutoffDay = 12):
//   Today = 10 Jun 2026  →  CutoverDate = 30 Apr 2026
//   Today = 12 Jun 2026  →  CutoverDate = 31 May 2026
//   Today = 20 Jun 2026  →  CutoverDate = 31 May 2026
//
// Dependencies: none — uses system date only (DateTime.LocalNow()).
// Load:         DISABLED — right-click query → untick "Enable load"
// =====================================================================
let
    Today       = Date.From(DateTime.LocalNow()),
    CutoffDay   = 12,

    // If on/after the 12th, previous month's actuals are ready.
    // If before the 12th, go back one more month.
    MonthsBack  = if Date.Day(Today) >= CutoffDay then 1 else 2,

    CutoverDate = Date.EndOfMonth(Date.AddMonths(Today, -MonthsBack))
in
    CutoverDate
