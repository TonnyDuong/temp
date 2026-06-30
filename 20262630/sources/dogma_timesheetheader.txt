let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_dogma_timesheetheader = Source{[Schema="dbo",Item="dogma_timesheetheader"]}[Data]
in
    dbo_dogma_timesheetheader