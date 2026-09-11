let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_crbb5_bamboohr = Source{[Schema="dbo",Item="crbb5_bamboohr"]}[Data]
in
    dbo_crbb5_bamboohr