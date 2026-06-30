let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_crbb5_project = Source{[Schema="dbo",Item="crbb5_project"]}[Data],
    #"Added Custom" = Table.AddColumn(dbo_crbb5_project, "Project Display", each [crbb5_projectcode] & " - " & [crbb5_projectname])
in
    #"Added Custom"