let
    Source = SharePoint.Files("https://eqmanserv.sharepoint.com/sites/EMS_FPA", [ApiVersion = 15]),
    #"FinanceOutput FY26 xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/" = Source{[Name="FinanceOutput FY26.xlsx",#"Folder Path"="https://eqmanserv.sharepoint.com/sites/EMS_FPA/Shared Documents/Profitability/Data/"]}[Content],
    #"Imported Excel Workbook" = Excel.Workbook(#"FinanceOutput FY26 xlsx_https://eqmanserv sharepoint com/sites/EMS_FPA/Shared Documents/Profitability/Data/"),
    FY2026_Sheet = #"Imported Excel Workbook"{[Item="FY2026",Kind="Sheet"]}[Data],
    #"Removed Top Rows" = Table.Skip(FY2026_Sheet,3),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Transaction Line ID", Int64.Type}, {"Transaction Ref.", type text}, {"Transaction Date", type date}, {"Period End Date", type date}, {"Account No.", Int64.Type}, {"Account Name", type text}, {"Memo", type text}, {"Customer: Full Name", type text}, {"Vendor: Full Name", type text}, {"Class: Class ID", type any}, {"Class: Class External ID", type text}, {"Class: Full Name", type text}, {"Location: Location ID", type any}, {"Location: Full Name", type text}, {"Department: Department ID", type any}, {"Department: Full Name", type text}, {"Subsidiary: Full Name", type text}, {"Employee: Employee External ID", type text}, {"Employee: First Name", type text}, {"Employee: Last Name", type text}, {"Sum of Amount", type number}})
in
    #"Changed Type"