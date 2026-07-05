let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"Additional Services Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="Additional Services Forecast.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"Additional Services Forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    #"AdditionalServices Forecast_Sheet" = #"Imported Excel Workbook"{[Item="AdditionalServices Forecast",Kind="Sheet"]}[Data],
    #"Removed Top Rows" = Table.Skip(#"AdditionalServices Forecast_Sheet",4),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Supersector", type text}, {"Sector", type text}, {"Upstream Reports", type text}, {"Project Code", type text}, {"Department", type text}, {"Location", type text}, {"31/01/2026", type number}, {"28/02/2026", type number}, {"31/03/2026", type number}, {"30/04/2026", type number}, {"31/05/2026", type number}, {"30/06/2026", type number}, {"31/07/2026", type number}, {"31/08/2026", type number}, {"30/09/2026", type number}, {"31/10/2026", type number}, {"30/11/2026", type number}, {"31/12/2026", type number}, {"Column19", type any}, {"Column20", type any}}),
    #"Removed Bottom Rows" = Table.RemoveLastN(#"Changed Type",1)
in
    #"Removed Bottom Rows"