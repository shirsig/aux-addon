module 'aux.core.tooltip'

include 'green_t'
include 'aux'

local info = require 'aux.util.info'
local money =  require 'aux.util.money'
local cache = require 'aux.core.cache'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local auction_listing = require 'aux.gui.auction_listing'

_G.aux_tooltip_value = true

local game_tooltip_hooks, game_tooltip_money = t, 0

function LOAD()
	do
		local inside_hook = false
	    for name, f in game_tooltip_hooks do
	        local name, f = name, f
	        hook(name, GameTooltip, function(...) auto_release(arg, true)
	            inside_hook = true
	            game_tooltip_money = 0
	            local ret = temp-A(orig[GameTooltip][name](unpack(arg)))
	            inside_hook = false
	            f(unpack(arg))
	            return unpack(ret)
	        end)
	    end
	    local orig = GameTooltip:GetScript('OnTooltipAddMoney')
	    GameTooltip:SetScript('OnTooltipAddMoney', function(...) auto_release(arg, true)
		    if inside_hook then
			    game_tooltip_money = arg1
		    else
			    return orig(unpack(arg))
		    end
	    end)
    end
    local orig = SetItemRef
    setglobal('SetItemRef', function(...) auto_release(arg, true)
        local name, _, quality = GetItemInfo(arg[1])
        local ret = A(orig(unpack(arg)))
        if not IsShiftKeyDown() and not IsControlKeyDown() and name then
            local color_code = select(4, GetItemQualityColor(quality))
            local link = color_code ..  '|H' .. arg[1] .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
            extend_tooltip(ItemRefTooltip, link, 1)
        end
        return ret
    end)
end

function extend_tooltip(tooltip, link, quantity)
    local item_id, suffix_id = info.parse_link(link)
    quantity = IsShiftKeyDown() and quantity or 1
    if aux_tooltip_disenchant_source then
        local color = {r=.7, g=.7, b=.7}
        local type, range = disenchant.source(item_id)
        if type == 'CRYSTAL' then
            tooltip:AddLine(format('Can disenchant from level %s |cffa335eeEpic|r and |cff0070ddRare|r items.', range), color.r, color.g, color.b, true)
        elseif type == 'SHARD' then
            tooltip:AddLine(format('Can disenchant from level %s |cff0070ddRare|r and |cff1eff00Uncommon|r items.', range), color.r, color.g, color.b, true)
        elseif type == 'ESSENCE' then
            tooltip:AddLine(format('Can disenchant from level %s |cff1eff00Uncommon|r items.', range), color.r, color.g, color.b, true)
        elseif type == 'DUST' then
            tooltip:AddLine(format('Can disenchant from level %s |cff1eff00Uncommon|r items.', range), color.r, color.g, color.b, true)
        end
    end
    local item_info = info.item(item_id)
    if item_info then
        local distribution = disenchant.distribution(item_info.slot, item_info.quality, item_info.level)
        if getn(distribution) > 0 then
            if aux_tooltip_disenchant_distribution then
                local color = {r=.8, g=.8, b=.2}

                tooltip:AddLine('Disenchants into:', color.r, color.g, color.b)
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in distribution do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), color.r, color.g, color.b)
                end
            end
            if aux_tooltip_disenchant_value then
                local color = {r=.1, g=.6, b=.6}

                local disenchant_value = disenchant.value(item_info.slot, item_info.quality, item_info.level)
                tooltip:AddLine('Disenchant Value: ' .. (disenchant_value and money.to_string2(disenchant_value) or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
            end
        end
    end
    if aux_tooltip_vendor_buy then
        local color = {r=.8, g=.5, b=.1}
        local _, price, limited = cache.merchant_info(item_id)
        if price then
            tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. money.to_string2(price * quantity), color.r, color.g, color.b)
        end
    end
    if aux_tooltip_vendor_sell then
        local color = {r=.8, g=.5, b=.1}
        local price = cache.merchant_info(item_id)
        if price ~= 0 then
            tooltip:AddLine('Vendor Sell: ' .. (price and money.to_string2(price * quantity) or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
    end
    local color = {r=1, g=1, b=.6}
    local auctionable = not item_info or info.auctionable(info.tooltip(function(tooltip) tooltip:SetHyperlink(item_info.itemstring) end), item_info.quality)
    local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
    local value = history.value(item_key)
    if auctionable then
        if aux_tooltip_value then
            tooltip:AddLine('Value: ' .. (value and money.to_string2(value * quantity) or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
        if aux_tooltip_daily  then
            local market_value = history.market_value(item_key)
            tooltip:AddLine('Today: ' .. (market_value and money.to_string2(market_value * quantity) .. ' (' .. auction_listing.percentage_historical(round(market_value / value * 100)) .. ')' or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
    end

    if tooltip == GameTooltip and game_tooltip_money > 0 then
        SetTooltipMoney(tooltip, game_tooltip_money)
    end
    tooltip:Show()
end

function game_tooltip_hooks:SetHyperlink(itemstring)
    local name, _, quality = GetItemInfo(itemstring)
    if name then
        local hex = select(4, GetItemQualityColor(quality))
        local link = hex ..  '|H' .. itemstring .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetAuctionItem(type, index)
    for link in present(GetAuctionItemLink(type, index)) do
        extend_tooltip(GameTooltip, link, select(3, GetAuctionItemInfo(type, index)))
    end
end

function game_tooltip_hooks:SetLootItem(slot)
    for link in present(GetLootSlotLink(slot)) do
        extend_tooltip(GameTooltip, link, select(3, GetLootSlotInfo(slot)))
    end
end

function game_tooltip_hooks:SetQuestItem(qtype, slot)
    for link in present(GetQuestItemLink(qtype, slot)) do
        extend_tooltip(GameTooltip, link, select(3, GetQuestItemInfo(qtype, slot)))
    end
end

function game_tooltip_hooks:SetQuestLogItem(qtype, slot)
    for link in present(GetQuestLogItemLink(qtype, slot)) do
        extend_tooltip(GameTooltip, link, select(3, GetQuestLogRewardInfo(slot)))
    end
end

function game_tooltip_hooks:SetBagItem(bag, slot)
    for link in present(GetContainerItemLink(bag, slot)) do
        extend_tooltip(GameTooltip, link, select(2, GetContainerItemInfo(bag, slot)))
    end
end

function game_tooltip_hooks:SetInboxItem(index)
    local name, _, quantity = GetInboxItem(index)
    for id in present(name and cache.item_id(name)) do
        local _, itemstring, quality = GetItemInfo(id)
        local hex = select(4, GetItemQualityColor(tonumber(quality)))
        local link = hex ..  '|H' .. itemstring .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetInventoryItem(unit, slot)
    for link in present(GetInventoryItemLink(unit, slot)) do
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetMerchantItem(slot)
    for link in present(GetMerchantItemLink(slot)) do
        local quantity = select(4, GetMerchantItemInfo(slot))
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftItem(skill, slot)
    local link, quantity
    if slot then
        link, quantity = GetCraftReagentItemLink(skill, slot), select(3, GetCraftReagentInfo(skill, slot))
    else
        link, quantity = GetCraftItemLink(skill), 1
    end
    if link then
	    extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftSpell(slot)
    for link in present(GetCraftItemLink(slot)) do
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetTradeSkillItem(skill, slot)
    local link, quantity
    if slot then
        link, quantity = GetTradeSkillReagentItemLink(skill, slot), select(3, GetTradeSkillReagentInfo(skill, slot))
    else
        link, quantity = GetTradeSkillItemLink(skill), 1
    end
    if link then
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetAuctionSellItem()
    local name, _, quantity = GetAuctionSellItemInfo()
    if name then
        for slot in info.inventory do auto_release(slot, true)
            local link = GetContainerItemLink(unpack(slot))
            if link and select(5, info.parse_link(link)) == name then
                extend_tooltip(GameTooltip, link, quantity)
                return
            end
        end
    end
end