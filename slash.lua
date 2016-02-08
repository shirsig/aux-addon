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
    elseif parameter == 'market bid' then
        aux_market_value_type = 'bid'
        Aux.log('Set market value to bid based.')
    elseif parameter == 'market buyout' then
        aux_market_value_type = 'buyout'
        Aux.log('Set market value to buyout based.')
    end
end