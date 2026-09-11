let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_crbb5_contractregister = Source{[Schema="dbo",Item="crbb5_contractregister"]}[Data]
in
    dbo_crbb5_contractregister