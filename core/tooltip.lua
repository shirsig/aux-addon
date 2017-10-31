module 'aux.core.tooltip'

include 'aux'

local T = require 'T'

local info = require 'aux.util.info'
local money =  require 'aux.util.money'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local auction_listing = require 'aux.gui.auction_listing'

local UNKNOWN = GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE

local game_tooltip_hooks, game_tooltip_money = {}, 0

function handle.LOAD()
	settings = character_data('tooltip', {value=true})
	do
		local inside_hook = false
	    for name, f in pairs(game_tooltip_hooks) do
	        local name, f = name, f
	        hook(name, GameTooltip, T.vararg-function(arg)
	            inside_hook = true
	            game_tooltip_money = 0
	            local tmp = T.list(orig[GameTooltip][name](unpack(arg)))
	            inside_hook = false
	            f(unpack(arg))
	            return T.unpack(tmp)
	        end)
	    end
	    local orig = GameTooltip:GetScript'OnTooltipAddMoney'
	    GameTooltip:SetScript('OnTooltipAddMoney', T.vararg-function(arg)
		    if inside_hook then
			    game_tooltip_money = arg1
		    else
			    return orig(unpack(arg))
		    end
	    end)
    end
    local orig = SetItemRef
    setglobal('SetItemRef', T.vararg-function(arg)
        local name, _, quality = GetItemInfo(arg[1])
        local tmp = T.list(orig(unpack(arg)))
        if not IsShiftKeyDown() and not IsControlKeyDown() and name then
            local color_code = select(4, GetItemQualityColor(quality))
            local link = color_code ..  '|H' .. arg[1] .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
            extend_tooltip(ItemRefTooltip, link, 1)
        end
        return T.unpack(tmp)
    end)
end

function M.extend_tooltip(tooltip, link, quantity)
    local item_id, suffix_id = info.parse_link(link)
    quantity = IsShiftKeyDown() and quantity or 1
    local item_info = T.temp-info.item(item_id)
    if item_info then
        local distribution = disenchant.distribution(item_info.slot, item_info.quality, item_info.level)
        if getn(distribution) > 0 then
            if settings.disenchant_distribution then
                tooltip:AddLine('Disenchants into:', color.tooltip.disenchant.distribution())
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in ipairs(distribution) do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), color.tooltip.disenchant.distribution())
                end
            end
            if settings.disenchant_value then
                local disenchant_value = disenchant.value(item_info.slot, item_info.quality, item_info.level)
                tooltip:AddLine('Disenchant: ' .. (disenchant_value and money.to_string2(disenchant_value) or UNKNOWN), color.tooltip.disenchant.value())
            end
        end
    end
    if settings.merchant_buy then
        local _, price, limited = info.merchant_info(item_id)
        if price then
            tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. money.to_string2(price * quantity), color.tooltip.merchant())
        end
    end
    if settings.merchant_sell then
        local price = info.merchant_info(item_id)
        if price ~= 0 then
            tooltip:AddLine('Vendor: ' .. (price and money.to_string2(price * quantity) or UNKNOWN), color.tooltip.merchant())
        end
    end
    local auctionable = not item_info or info.auctionable(T.temp-info.tooltip('link', item_info.itemstring), item_info.quality)
    local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
    local value = history.value(item_key)
    if auctionable then
        if settings.value then
            tooltip:AddLine('Value: ' .. (value and money.to_string2(value * quantity) or UNKNOWN), color.tooltip.value())
        end
        if settings.daily  then
            local market_value = history.market_value(item_key)
            tooltip:AddLine('Today: ' .. (market_value and money.to_string2(market_value * quantity) .. ' (' .. auction_listing.percentage_historical(round(market_value / value * 100)) .. ')' or UNKNOWN), color.tooltip.value())
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
	local link = GetAuctionItemLink(type, index)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetAuctionItemInfo(type, index)))
    end
end

function game_tooltip_hooks:SetLootItem(slot)
	local link = GetLootSlotLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetLootSlotInfo(slot)))
    end
end

function game_tooltip_hooks:SetQuestItem(qtype, slot)
	local link = GetQuestItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetQuestItemInfo(qtype, slot)))
    end
end

function game_tooltip_hooks:SetQuestLogItem(qtype, slot)
	local link = GetQuestLogItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetQuestLogRewardInfo(slot)))
    end
end

function game_tooltip_hooks:SetBagItem(bag, slot)
	local link = GetContainerItemLink(bag, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(2, GetContainerItemInfo(bag, slot)))
    end
end

function game_tooltip_hooks:SetInboxItem(index)
    local name, _, quantity = GetInboxItem(index)
    local id = name and info.item_id(name)
    if id then
        local _, itemstring, quality = GetItemInfo(id)
        local hex = select(4, GetItemQualityColor(tonumber(quality)))
        local link = hex ..  '|H' .. itemstring .. '|h[' .. name .. ']|h' .. FONT_COLOR_CODE_CLOSE
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetInventoryItem(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetMerchantItem(slot)
	local link = GetMerchantItemLink(slot)
    if link then
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
	local link = GetCraftItemLink(slot)
    if link then
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
        for slot in info.inventory() do
	        T.temp(slot)
            local link = GetContainerItemLink(unpack(slot))
            if link and select(5, info.parse_link(link)) == name then
                extend_tooltip(GameTooltip, link, quantity)
                return
            end
        end
    end
end