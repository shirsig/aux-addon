SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(parameter)
    if parameter == 'clear history' then
        Aux.persistence.load_dataset().history = nil
        Aux.log('History cleared.')
    elseif parameter == 'clear post' then
        Aux.persistence.load_dataset().post = nil
        Aux.log('Post settings cleared.')
    elseif parameter == 'clear datasets' then
        aux_datasets = {}
        Aux.log('Datasets cleared.')
    elseif parameter == 'clear merchant buy' then
        aux_merchant_buy = {}
        Aux.log('Merchant buy prices cleared.')
    elseif parameter == 'clear merchant sell' then
        aux_merchant_sell = {}
        Aux.log('Merchant sell prices cleared.')
    elseif parameter == 'clear item cache' then
        aux_items = {}
        aux_item_ids = {}
        aux_auctionable_items = {}
        Aux.log('Item cache cleared.')
    elseif parameter == 'populate wdb' then
        Aux.cache.populate_wdb()
    elseif parameter == 'tooltip daily' then
        aux_tooltip_daily = not aux_tooltip_daily
        Aux.log('Market value in tooltip '..(aux_tooltip_daily and 'enabled' or 'disabled')..'.')
    elseif parameter == 'tooltip vendor buy' then
        aux_tooltip_vendor_buy = not aux_tooltip_vendor_buy
        Aux.log('Vendor buy price in tooltip '..(aux_tooltip_vendor_buy and 'enabled' or 'disabled')..'.')
    elseif parameter == 'tooltip vendor sell' then
        aux_tooltip_vendor_sell = not aux_tooltip_vendor_sell
        Aux.log('Vendor sell price in tooltip '..(aux_tooltip_vendor_sell and 'enabled' or 'disabled')..'.')
    elseif parameter == 'tooltip disenchant value' then
        aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        Aux.log('Disenchant value in tooltip '..(aux_tooltip_disenchant_value and 'enabled' or 'disabled')..'.')
    elseif parameter == 'tooltip disenchant distribution' then
        aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        Aux.log('Disenchant distribution in tooltip '..(aux_tooltip_disenchant_distribution and 'enabled' or 'disabled')..'.')
    elseif parameter == 'tooltip disenchant source' then
        aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        Aux.log('Disenchant source in tooltip '..(aux_tooltip_disenchant_source and 'enabled' or 'disabled')..'.')
    end
end