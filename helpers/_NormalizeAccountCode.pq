// =====================================================================
// _NormalizeAccountCode  (helper function - load disabled)
// ---------------------------------------------------------------------
// Purpose:      Normalizes source account-code values into the shared
//               five-character text key used by dim_Accounts_Live and
//               fact_*_Live relationship columns.
// Grain:        Scalar function.
// Dependencies: none.
// Load:         DISABLED.
// ---------------------------------------------------------------------
// Handles numeric source values, text labels, whitespace, and decimal
// suffixes so joins do not fail when sources expose account codes with
// different physical types or display formats.
// =====================================================================
let
    NormalizeAccountCode = (value as any) as nullable text =>
        let
            TextValue = try Text.Trim(Text.From(value)) otherwise null,
            NumericValue = try Number.From(value) otherwise null,
            Digits = if TextValue = null then null else Text.Select(TextValue, {"0".."9"}),
            Result =
                if TextValue = null or TextValue = "" then null
                else if NumericValue is number then Text.From(Int64.From(NumericValue))
                else if Digits = null or Digits = "" then null
                else Text.Start(Digits, 5)
        in
            Result
in
    NormalizeAccountCode
