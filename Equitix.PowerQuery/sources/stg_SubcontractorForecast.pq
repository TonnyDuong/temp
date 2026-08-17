let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"Subcontractor forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="Subcontractor forecast.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"Subcontractor forecast xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    Sheet1_Sheet = #"Imported Excel Workbook"{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"Removed Top Rows" = Table.Skip(Sheet1_Sheet,2),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Netsuite N/C", Int64.Type}, {"Project Code", type text}, {"Department", type text}, {"Location", type text}, {"31/01/2026", type number}, {"28/02/2026", type number}, {"31/03/2026", type number}, {"30/04/2026", type number}, {"31/05/2026", type number}, {"30/06/2026", type number}, {"31/07/2026", type number}, {"31/08/2026", type number}, {"30/09/2026", type number}, {"31/10/2026", type number}, {"30/11/2026", type number}, {"31/12/2026", type number}, {"Column17", type any}})
in
    #"Changed Type"