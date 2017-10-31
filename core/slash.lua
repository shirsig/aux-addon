module 'aux.core.slash'

include 'aux'

local info = require 'aux.util.info'

function handle.LOAD2()
	tooltip_settings = character_data'tooltip'
end

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
	    tooltip_settings.value = not tooltip_settings.value
        print('tooltip value ' .. status(tooltip_settings.value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    tooltip_settings.daily = not tooltip_settings.daily
        print('tooltip daily ' .. status(tooltip_settings.daily))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    tooltip_settings.merchant_buy = not tooltip_settings.merchant_buy
        print('tooltip merchant buy ' .. status(tooltip_settings.merchant_buy))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    tooltip_settings.merchant_sell = not tooltip_settings.merchant_sell
        print('tooltip merchant sell ' .. status(tooltip_settings.merchant_sell))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    tooltip_settings.disenchant_value = not tooltip_settings.disenchant_value
        print('tooltip disenchant value ' .. status(tooltip_settings.disenchant_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    tooltip_settings.disenchant_distribution = not tooltip_settings.disenchant_distribution
        print('tooltip disenchant distribution ' .. status(tooltip_settings.disenchant_distribution))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    _G.aux_items = {}
	    _G.aux_item_ids = {}
	    _G.aux_auctionable_items = {}
        print('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
	    info.populate_wdb()
	else
		print('Usage:')
		print('- scale [' .. color.blue(aux_scale) .. ']')
		print('- ignore owner [' .. status(aux_ignore_owner) .. ']')
		print('- post bid [' .. status(aux_post_bid) .. ']')
		print('- tooltip value [' .. status(tooltip_settings.value) .. ']')
		print('- tooltip daily [' .. status(tooltip_settings.daily) .. ']')
		print('- tooltip merchant buy [' .. status(tooltip_settings.merchant_buy) .. ']')
		print('- tooltip merchant sell [' .. status(tooltip_settings.merchant_sell) .. ']')
		print('- tooltip disenchant value [' .. status(tooltip_settings.disenchant_value) .. ']')
		print('- tooltip disenchant distribution [' .. status(tooltip_settings.disenchant_distribution) .. ']')
		print('- clear item cache')
		print('- populate wdb')
    end
end