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
    elseif parameter == 'history conservative' then
        aux_conservative_history = not aux_conservative_history
        Aux.log('Conservative history '..(aux_conservative_history and 'enabled.' or 'disabled.'))
--    elseif parameter == 'percentage conservative' then
--        aux_percentage_conservative = false
--        Aux.log('Conservative value deactivated.')
    end
end