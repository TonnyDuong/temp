let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"Target Profitability xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="Target Profitability.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"Target Profitability xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    #"First Sheet" = Table.SelectRows(#"Imported Excel Workbook", each [Kind] = "Sheet"){0}[Data]
in
    #"First Sheet"
