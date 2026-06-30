let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"EMS Fixed Fee Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="EMS Fixed Fee Forecast.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"EMS Fixed Fee Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    Actuals_Sheet = #"Imported Excel Workbook"{[Item="Actuals",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Actuals_Sheet, [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Transaction Ref.", type text}, {"Transaction Date", type date}, {"Period End Date", type date}, {"Account No.", Int64.Type}, {"Account Name", type text}, {"Memo", type text}, {"Class: Class External ID", type text}, {"Sum of Amount", type number}})
in
    #"Changed Type"