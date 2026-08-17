let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_dogma_timesheetperiod = Source{[Schema="dbo",Item="dogma_timesheetperiod"]}[Data]
in
    dbo_dogma_timesheetperiod