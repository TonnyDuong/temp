let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"FinanceOutput FY26 xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="FinanceOutput FY26.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"FinanceOutput FY26 xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    #"Filtered Rows" = Table.SelectRows(#"Imported Excel Workbook", each ([Kind] = "Sheet")),
    CoA_Sheet = #"Filtered Rows"{[Item="CoA",Kind="Sheet"]}[Data],
    #"Removed Top Rows" = Table.Skip(CoA_Sheet,2),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Nominal Code", type text}, {"Account Name", type text}, {"Account Type", type text}, {"Balance Sheet", type text}, {"Mapping", type text}}),
    #"Removed Errors" = Table.RemoveRowsWithErrors(#"Changed Type", {"Nominal Code"})
in
    #"Removed Errors"