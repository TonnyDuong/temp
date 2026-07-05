let
    Source = CommonDataService.Database("emservices.crm11.dynamics.com"),
    dbo_dogma_timesheet = Source{[Schema="dbo",Item="dogma_timesheet"]}[Data],
    #"Expanded systemuser(owninguser)" = Table.ExpandRecordColumn(dbo_dogma_timesheet, "systemuser(owninguser)", {"crbb5_timeworkreference", "crbb5_crbb5_timeworkreference", "crbb5_crbb5_timeworkreferencename"}, {"systemuser(owninguser).crbb5_timeworkreference", "systemuser(owninguser).crbb5_crbb5_timeworkreference", "systemuser(owninguser).crbb5_crbb5_timeworkreferencename"}),
    #"Renamed Columns" = Table.RenameColumns(#"Expanded systemuser(owninguser)",{{"systemuser(owninguser).crbb5_crbb5_timeworkreferencename", "crbb5_crbb5_timeworkreferencename"}})
in
    #"Renamed Columns"