module 'aux.core.slash'

include 'T'
include 'aux'

local cache = require 'aux.core.cache'

_G.aux_ignore_owner = true

_G.SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = tokenize(command)
    if arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    _G.aux_items = T
	    _G.aux_item_ids = T
	    _G.aux_auctionable_items = T
        print('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
	    cache.populate_wdb()
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    _G.aux_tooltip_value = not aux_tooltip_value
        print('Historical value in tooltip ' .. (aux_tooltip_value and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    _G.aux_tooltip_daily = not aux_tooltip_daily
        print('Market value in tooltip ' .. (aux_tooltip_daily and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'buy' then
	    _G.aux_tooltip_vendor_buy = not aux_tooltip_vendor_buy
        print('Vendor buy price in tooltip ' .. (aux_tooltip_vendor_buy and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'sell' then
	    _G.aux_tooltip_vendor_sell = not aux_tooltip_vendor_sell
        print('Vendor sell price in tooltip ' .. (aux_tooltip_vendor_sell and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    _G.aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        print('Disenchant value in tooltip ' .. (aux_tooltip_disenchant_value and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    _G.aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        print('Disenchant distribution in tooltip ' .. (aux_tooltip_disenchant_distribution and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'source' then
	    _G.aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        print('Disenchant source in tooltip ' .. (aux_tooltip_disenchant_source and 'enabled' or 'disabled') .. '.')
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    _G.aux_ignore_owner = not aux_ignore_owner
        print('Ignoring of owner ' .. (aux_ignore_owner and 'enabled' or 'disabled') .. '.')
	else
		print('Unknown command: "' .. command .. '"')
	end
end