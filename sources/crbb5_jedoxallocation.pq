let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_crbb5_jedoxallocation = Source{[Schema="dbo",Item="crbb5_jedoxallocation"]}[Data]
in
    dbo_crbb5_jedoxallocation