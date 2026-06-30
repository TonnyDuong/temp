// =====================================================================
// dim_Date_Live
// ---------------------------------------------------------------------
// Purpose:      Calendar dimension, 2024-01-01 to 2035-12-31.
// Grain:        One row per day (4,383 rows total).
// Dependencies: none.
// Load:         enabled.
// Post-load:    Mark as Date Table (Model view) → Date column.
// ---------------------------------------------------------------------
// Columns:
//   Date            (date)     primary key
//   Year            (Int64)
//   Month           (Int64)    1-12
//   MonthName       (text)     "January" etc.
//   Quarter         (Int64)    1-4
//   MonthYear       (text)     "Mar 2026"
//   YearMonth       (Int64)    202603 — useful for sort-by
//   IsYTD           (logical)  Date <= today
//   IsCurrentMonth  (logical)
// =====================================================================
let
    StartDate = #date(2024, 1, 1),
    EndDate   = #date(2035, 12, 31),
    DayCount  = Duration.Days(EndDate - StartDate) + 1,
    Dates     = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    AsTable   = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(AsTable, {{"Date", type date}}),

    AddYear           = Table.AddColumn(Typed,            "Year",           each Date.Year([Date]),                                       Int64.Type),
    AddMonth          = Table.AddColumn(AddYear,          "Month",          each Date.Month([Date]),                                      Int64.Type),
    AddMonthName      = Table.AddColumn(AddMonth,         "MonthName",      each Date.MonthName([Date]),                                  type text),
    AddQuarter        = Table.AddColumn(AddMonthName,     "Quarter",        each Date.QuarterOfYear([Date]),                              Int64.Type),
    AddMonthYear      = Table.AddColumn(AddQuarter,       "MonthYear",      each Date.ToText([Date], "MMM yyyy"),                         type text),
    AddYearMonth      = Table.AddColumn(AddMonthYear,     "YearMonth",      each Date.Year([Date]) * 100 + Date.Month([Date]),            Int64.Type),
    AddIsYTD          = Table.AddColumn(AddYearMonth,     "IsYTD",          each [Date] <= Date.From(DateTime.LocalNow()),                type logical),
    AddIsCurrentMonth = Table.AddColumn(AddIsYTD,         "IsCurrentMonth",
        each Date.Year([Date]) = Date.Year(DateTime.LocalNow())
         and Date.Month([Date]) = Date.Month(DateTime.LocalNow()),
        type logical)
in
    AddIsCurrentMonth