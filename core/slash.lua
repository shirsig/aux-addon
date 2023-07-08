select(2, ...) 'aux.core.slash'

local aux = require 'aux'
local post = require 'aux.tabs.post'
local info = require 'aux.util.info'
local scan = require 'aux.core.scan'

function status(enabled)
	return (enabled and aux.color.green'on' or aux.color.red'off')
end

_G.SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = aux.tokenize(command)
    local tooltip_settings = aux.character_data.tooltip
    if arguments[1] == 'scale' and tonumber(arguments[2]) then
    	local scale = tonumber(arguments[2])
	    aux.frame:SetScale(scale)
	    aux.account_data.scale = scale
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    aux.account_data.ignore_owner = not aux.account_data.ignore_owner
        aux.print('ignore owner ' .. status(aux.account_data.ignore_owner))
    elseif arguments[1] == 'action' and arguments[2] == 'shortcuts' then
        aux.account_data.action_shortcuts = not aux.account_data.action_shortcuts
        aux.print('action shortcuts ' .. status(aux.account_data.action_shortcuts))
    elseif arguments[1] == 'post' and arguments[2] == 'full' and arguments[3] == 'scan' then
        aux.account_data.post_full_scan = not aux.account_data.post_full_scan
        aux.print('post full scan ' .. status(aux.account_data.post_full_scan))
    elseif arguments[1] == 'post' and arguments[2] == 'bid' then
        aux.account_data.post_bid = ({ unit = 'unit', stack = 'stack' })[arguments[3]]
	    aux.print('post bid ' .. aux.color.blue(aux.account_data.post_bid or 'off'))
    elseif arguments[1] == 'post' and arguments[2] == 'duration' and  ({ ['12'] = post.DURATION_12, ['24'] = post.DURATION_24, ['48'] = post.DURATION_48 })[arguments[3]] then
        aux.account_data.post_duration = ({ ['12'] = post.DURATION_12, ['24'] = post.DURATION_24, ['48'] = post.DURATION_48 })[arguments[3]]
        aux.print('post duration ' .. aux.color.blue(info.duration_hours(aux.account_data.post_duration) .. 'h'))
    elseif arguments[1] == 'crafting' and arguments[2] == 'cost' then
		aux.account_data.crafting_cost = not aux.account_data.crafting_cost
		aux.print('crafting cost ' .. status(aux.account_data.crafting_cost))
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
    elseif arguments[1] == 'tooltip' and arguments[2] == 'prospecting' and arguments[3] == 'value' then
        tooltip_settings.prospecting_value = not tooltip_settings.prospecting_value
        aux.print('tooltip prospecting value ' .. status(tooltip_settings.prospecting_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'prospecting' and arguments[3] == 'distribution' then
        tooltip_settings.prospecting_distribution = not tooltip_settings.prospecting_distribution
        aux.print('tooltip prospecting distribution ' .. status(tooltip_settings.prospecting_distribution))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'money'  and arguments[3] == 'icons' then
	    tooltip_settings.money_icons = not tooltip_settings.money_icons
        aux.print('tooltip money icons ' .. status(tooltip_settings.money_icons))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    aux.account_data.items = {}
        aux.account_data.item_ids = {}
        aux.account_data.unused_item_ids = {}
        aux.account_data.auctionable_items = {}
        aux.print('Item cache cleared.')
    elseif arguments[1] == 'clear' and arguments[2] == 'post' then
        aux.faction_data.post = {}
        aux.print('Post data cleared.')
	else
		aux.print('Usage:')
        aux.print('- scale [' .. aux.color.blue(aux.account_data.scale) .. ']')
		aux.print('- ignore owner [' .. status(aux.account_data.ignore_owner) .. ']')
        aux.print('- action shortcuts [' .. status(aux.account_data.action_shortcuts) .. ']')
        aux.print('- post full scan [' .. status(aux.account_data.post_full_scan) .. ']')
        aux.print('- post bid [' .. aux.color.blue(aux.account_data.post_bid or 'off') .. ']')
        aux.print('- post duration [' .. aux.color.blue(info.duration_hours(aux.account_data.post_duration) .. 'h') .. ']')
        aux.print('- crafting cost [' .. status(aux.account_data.crafting_cost) .. ']')
		aux.print('- tooltip value [' .. status(tooltip_settings.value) .. ']')
		aux.print('- tooltip daily [' .. status(tooltip_settings.daily) .. ']')
		aux.print('- tooltip merchant buy [' .. status(tooltip_settings.merchant_buy) .. ']')
		aux.print('- tooltip merchant sell [' .. status(tooltip_settings.merchant_sell) .. ']')
		aux.print('- tooltip disenchant value [' .. status(tooltip_settings.disenchant_value) .. ']')
		aux.print('- tooltip disenchant distribution [' .. status(tooltip_settings.disenchant_distribution) .. ']')
        aux.print('- tooltip prospecting value [' .. status(tooltip_settings.prospecting_value) .. ']')
        aux.print('- tooltip prospecting distribution [' .. status(tooltip_settings.prospecting_distribution) .. ']')
        aux.print('- tooltip money icons [' .. status(tooltip_settings.money_icons) .. ']')
		aux.print('- clear item cache')
        aux.print('- clear post')
    end
end
