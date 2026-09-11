let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_crbb5_billingschedule = Source{[Schema="dbo",Item="crbb5_billingschedule"]}[Data]
in
    dbo_crbb5_billingschedule