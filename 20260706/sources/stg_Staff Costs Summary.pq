let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"Staff Costs Summary xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="Staff Costs Summary.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"Staff Costs Summary xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    Sheet1_Sheet = #"Imported Excel Workbook"{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet1_Sheet, [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Employee #", type text}, {"Time@work Reference", type text}, {"Last Name, First Name", type text}, {"2025", Int64.Type}, {"2026", type number}})
in
    #"Changed Type"