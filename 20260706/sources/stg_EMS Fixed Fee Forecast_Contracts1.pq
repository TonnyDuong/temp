let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"EMS Fixed Fee Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="EMS Fixed Fee Forecast.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"EMS Fixed Fee Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    #"Filtered Rows" = Table.SelectRows(#"Imported Excel Workbook", each ([Hidden] = false)),
    Contracts_Sheet = #"Filtered Rows"{[Item="Contracts",Kind="Sheet"]}[Data],
    #"Skipped Top Rows" = Table.Skip(Contracts_Sheet, 6),
    #"Promoted Headers" = Table.PromoteHeaders(#"Skipped Top Rows", [PromoteAllScalars=true])
in
    #"Promoted Headers"