module 'aux.core.slash'

include 'T'
include 'aux'

local cache = require 'aux.core.cache'

_G.aux_ignore_owner = true

function status(enabled)
	return (enabled and color.green'on' or color.red'off')
end

_G.SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = tokenize(command)

    if arguments[1] == 'scale' and tonumber(arguments[2]) then
    	local scale = tonumber(arguments[2])
	    AuxFrame:SetScale(scale)
	    _G.aux_scale = scale
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    _G.aux_ignore_owner = not aux_ignore_owner
        print('ignore owner ' .. status(aux_ignore_owner))
    elseif arguments[1] == 'post' and arguments[2] == 'bid' then
	    _G.aux_post_bid = not aux_post_bid
	    print('post bid ' .. status(aux_post_bid))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    _G.aux_tooltip_value = not aux_tooltip_value
        print('tooltip value ' .. status(aux_tooltip_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    _G.aux_tooltip_daily = not aux_tooltip_daily
        print('tooltip daily ' .. status(aux_tooltip_daily))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'buy' then
	    _G.aux_tooltip_merchant_buy = not aux_tooltip_merchant_buy
        print('tooltip vendor buy ' .. status(aux_tooltip_merchant_buy))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'vendor' and arguments[3] == 'sell' then
	    _G.aux_tooltip_merchant_sell = not aux_tooltip_merchant_sell
        print('tooltip vendor sell ' .. status(aux_tooltip_merchant_sell))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    _G.aux_tooltip_disenchant_value = not aux_tooltip_disenchant_value
        print('tooltip disenchant value ' .. status(aux_tooltip_disenchant_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    _G.aux_tooltip_disenchant_distribution = not aux_tooltip_disenchant_distribution
        print('tooltip disenchant distribution ' .. status(aux_tooltip_disenchant_distribution))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'source' then
	    _G.aux_tooltip_disenchant_source = not aux_tooltip_disenchant_source
        print('tooltip disenchant source ' .. status(aux_tooltip_disenchant_source))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    _G.aux_items = T
	    _G.aux_item_ids = T
	    _G.aux_auctionable_items = T
        print('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
	    cache.populate_wdb()
	else
		print('Usage:')
		print('- scale [' .. color.blue(aux_scale) .. ']')
		print('- ignore owner [' .. status(aux_ignore_owner) .. ']')
		print('- post bid [' .. status(aux_post_bid) .. ']')
		print('- tooltip value [' .. status(aux_tooltip_value) .. ']')
		print('- tooltip daily [' .. status(aux_tooltip_daily) .. ']')
		print('- tooltip vendor buy [' .. status(aux_tooltip_merchant_buy) .. ']')
		print('- tooltip vendor sell [' .. status(aux_tooltip_merchant_sell) .. ']')
		print('- tooltip disenchant value [' .. status(aux_tooltip_disenchant_value) .. ']')
		print('- tooltip disenchant distribution [' .. status(aux_tooltip_disenchant_distribution) .. ']')
		print('- tooltip disenchant source [' .. status(aux_tooltip_disenchant_source) .. ']')
		print('- clear item cache')
		print('- populate wdb')
    end
end