SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(parameter)
    if parameter == 'clear history' then
        Aux.persistence.load_dataset().history = nil
        Aux.log('History cleared.')
    elseif parameter == 'clear post' then
        Aux.persistence.load_dataset().post = nil
        Aux.log('Post settings cleared.')
    elseif parameter == 'clear' then
        aux_datasets = {}
        Aux.log('Database cleared.')
    elseif parameter == 'generate item cache' then
        Aux.static.generate_cache()
    elseif parameter == 'delete item cache' then
        aux_auctionable_items = nil
        aux_auctionable_item_ids = nil
        Aux.log('Item cache deleted; falling back to the default.')
    elseif parameter == 'tooltip daily' then
        aux_tooltip_daily = not aux_tooltip_daily
        Aux.log('Market value in tooltip '..(aux_tooltip_daily and 'enabled' or 'disabled')..'.')
    end
end