SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(parameter)
    if parameter == 'scan' then
        Aux.history_frame.start_scan()
    elseif parameter == 'clear snapshot' then
        Aux.persistence.load_dataset().snapshot = {}
        Aux.log('Snapshot cleared.')
    elseif parameter == 'clear' then
        aux_database = {}
        Aux.log('Database cleared.')
    elseif parameter == 'generate item cache' then
        Aux.static.generate_cache()
    elseif parameter == 'delete item cache' then
        aux_auctionable_items = nil
        Aux.log('Item cache deleted; falling back to the default.')
    end
end