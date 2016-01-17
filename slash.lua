SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(parameter)
    if parameter == 'scan' then
        Aux.history_frame.start_scan()
    elseif parameter == 'clear snapshot' then
        Aux.persistence.load_dataset().snapshot = {}
        Aux.log('Snapshot cleared.')
    elseif parameter == 'clear database' then
        aux_database = {}
        Aux.log('Database cleared.')
    elseif parameter == 'clear' then
        aux_database = {}
        Aux.persistence.load_dataset().snapshot = {}
        Aux.log('Snapshot and database cleared.')
    end
end