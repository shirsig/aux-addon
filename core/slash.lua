module 'aux.core.slash'

local aux = require 'aux'

function aux.handle.LOAD2()
	tooltip_settings = aux.character_data'tooltip'
end

_G.aux_ignore_owner = true

function status(enabled)
	return (enabled and aux.color.green'on' or aux.color.red'off')
end

_G.SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = aux.tokenize(command)

    if arguments[1] == 'scale' and tonumber(arguments[2]) then
    	local scale = tonumber(arguments[2])
	    aux.frame:SetScale(scale)
	    _G.aux_scale = scale
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    _G.aux_ignore_owner = not aux_ignore_owner
        aux.print('ignore owner ' .. status(aux_ignore_owner))
    elseif arguments[1] == 'post' and arguments[2] == 'bid' then
	    _G.aux_post_bid = not aux_post_bid
	    aux.print('post bid ' .. status(aux_post_bid))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    tooltip_settings.value = not tooltip_settings.value
        aux.print('tooltip value ' .. status(tooltip_settings.value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    tooltip_settings.daily = not tooltip_settings.daily
        aux.print('tooltip daily ' .. status(tooltip_settings.daily))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    tooltip_settings.merchant_buy = not tooltip_settings.merchant_buy
        aux.print('tooltip merchant buy ' .. status(tooltip_settings.merchant_buy))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    tooltip_settings.merchant_sell = not tooltip_settings.merchant_sell
        aux.print('tooltip merchant sell ' .. status(tooltip_settings.merchant_sell))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    tooltip_settings.disenchant_value = not tooltip_settings.disenchant_value
        aux.print('tooltip disenchant value ' .. status(tooltip_settings.disenchant_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    tooltip_settings.disenchant_distribution = not tooltip_settings.disenchant_distribution
        aux.print('tooltip disenchant distribution ' .. status(tooltip_settings.disenchant_distribution))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    _G.aux_items = {}
	    _G.aux_item_ids = {}
	    _G.aux_auctionable_items = {}
        aux.print('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
	    info.populate_wdb()
	else
		aux.print('Usage:')
		aux.print('- scale [' .. aux.color.blue(aux_scale) .. ']')
		aux.print('- ignore owner [' .. status(aux_ignore_owner) .. ']')
		aux.print('- post bid [' .. status(aux_post_bid) .. ']')
		aux.print('- tooltip value [' .. status(tooltip_settings.value) .. ']')
		aux.print('- tooltip daily [' .. status(tooltip_settings.daily) .. ']')
		aux.print('- tooltip merchant buy [' .. status(tooltip_settings.merchant_buy) .. ']')
		aux.print('- tooltip merchant sell [' .. status(tooltip_settings.merchant_sell) .. ']')
		aux.print('- tooltip disenchant value [' .. status(tooltip_settings.disenchant_value) .. ']')
		aux.print('- tooltip disenchant distribution [' .. status(tooltip_settings.disenchant_distribution) .. ']')
		aux.print('- clear item cache')
		aux.print('- populate wdb')
    end
end