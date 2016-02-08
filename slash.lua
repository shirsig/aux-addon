SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(parameter)
    if parameter == 'clear history' then
        Aux.persistence.load_dataset().history = {}
        Aux.log('History cleared.')
    elseif parameter == 'clear' then
        aux_database = {}
        Aux.log('Database cleared.')
    elseif parameter == 'generate item cache' then
        Aux.static.generate_cache()
    elseif parameter == 'delete item cache' then
        aux_auctionable_items = nil
        Aux.log('Item cache deleted; falling back to the default.')
    elseif parameter == 'conservative value on' then
        aux_conservative_value = true
        Aux.log('Conservative value activated')
    elseif parameter == 'conservative value off' then
        aux_conservative_value = false
        Aux.log('Conservative value deactivated.')
    end
end