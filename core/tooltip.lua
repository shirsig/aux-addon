select(2, ...) 'aux.core.tooltip'

local aux = require 'aux'
local info = require 'aux.util.info'
local money =  require 'aux.util.money'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local gui = require 'aux.gui'

local UNKNOWN = GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE

local game_tooltip_hooks = {}
--local game_tooltip_money = 0

function aux.event.AUX_LOADED()
    settings = aux.character_data.tooltip
--    do
--        local inside_hook = false
    for name, f in pairs(game_tooltip_hooks) do
        hooksecurefunc(GameTooltip, name, function(self, ...)
            if not self:IsForbidden() then
                f(...)
            end
        end)
    end

    ItemRefTooltip:HookScript('OnTooltipSetItem', function(self)
        local _, link = self:GetItem()
        extend_tooltip(self, link)
    end)

--        for name, hook in pairs(game_tooltip_hooks) do
--            local name, f = name, f
--            aux.hook(name, GameTooltip, function(...)
--                game_tooltip_money = 0
--                inside_hook = true
--                local tmp = {aux.orig[GameTooltip][name](...)}
--                inside_hook = false
--                f(...)
--                return T.unpack(tmp)
--            end)
--        end
--        SetTooltipMoney = SetTooltipMoney
--        function _G.SetTooltipMoney(...)
--            if inside_hook then
--                game_tooltip_money = select(2, ...)
--            else
--                return SetTooltipMoney(...)
--            end
--        end
--    end
--    local orig = SetItemRef
--    function _G.SetItemRef(...)
--        local _, link = GetItemInfo(...)
--        local tmp = {orig(...)}
--        if link and not IsShiftKeyDown() and not IsControlKeyDown() then
--            extend_tooltip(ItemRefTooltip, link, 1)
--        end
--        return T.unpack(tmp)
--    end
end

function extend_tooltip(tooltip, link, quantity)
    local item_id, suffix_id = info.parse_link(link)
    quantity = IsShiftKeyDown() and quantity or 1
    local item_info = info.item(item_id)
    if item_info then
        local distribution = disenchant.distribution(item_info.slot, item_info.quality, item_info.level)
        if #distribution > 0 then
            if settings.disenchant_distribution then
                tooltip:AddLine('Disenchants into:', aux.color.tooltip.disenchant.distribution())
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in ipairs(distribution) do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), aux.color.tooltip.disenchant.distribution())
                end
            end
            if settings.disenchant_value then
                local disenchant_value = disenchant.value(item_info.slot, item_info.quality, item_info.level)
                tooltip:AddLine('Disenchant: ' .. (disenchant_value and money.to_string2(disenchant_value) or UNKNOWN), aux.color.tooltip.disenchant.value())
            end
        end
    end
    if settings.merchant_buy then
        local price, limited = info.merchant_buy_info(item_id)
        if price then
            tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. money.to_string2(price * quantity), aux.color.tooltip.merchant())
        end
    end
    if settings.merchant_sell then
        local price = item_info and item_info.sell_price
        if price ~= 0 then
            tooltip:AddLine('Vendor: ' .. (price and money.to_string2(price * quantity) or UNKNOWN), aux.color.tooltip.merchant())
        end
    end
    local auctionable = not item_info or info.auctionable(info.tooltip('link', item_info.link), item_info.quality)
    local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
    local value = history.value(item_key)
    if auctionable then
        if settings.value then
            tooltip:AddLine('Value: ' .. (value and money.to_string2(value * quantity) or UNKNOWN), aux.color.tooltip.value())
        end
        if settings.daily  then
            local market_value = history.market_value(item_key)
            tooltip:AddLine('Today: ' .. (market_value and money.to_string2(market_value * quantity) .. ' (' .. gui.percentage_historical(aux.round(market_value / value * 100)) .. ')' or UNKNOWN), aux.color.tooltip.value())
        end
    end

--    if tooltip == GameTooltip and game_tooltip_money > 0 then
--        SetTooltipMoney(tooltip, game_tooltip_money)
--    end
    tooltip:Show()
end

function game_tooltip_hooks.SetHyperlink(itemstring)
    local _, link = GetItemInfo(itemstring)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks.SetItemByID(itemId)
    local _, link = GetItemInfo(itemId)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks.SetAuctionItem(type, index)
    local link = GetAuctionItemLink(type, index)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetAuctionItemInfo(type, index)))
    end
end

function game_tooltip_hooks.SetLootItem(slot)
    local link = GetLootSlotLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetLootSlotInfo(slot)))
    end
end

function game_tooltip_hooks.SetQuestItem(qtype, slot)
    local link = GetQuestItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetQuestItemInfo(qtype, slot)))
    end
end

function game_tooltip_hooks.SetQuestLogItem(qtype, slot)
    local link = GetQuestLogItemLink(qtype, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetQuestLogRewardInfo(slot)))
    end
end

function game_tooltip_hooks.SetBagItem(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        extend_tooltip(GameTooltip, link, select(2, GetContainerItemInfo(bag, slot)))
    end
end

function game_tooltip_hooks.SetInboxItem(index, itemIndex)
    itemIndex = itemIndex or 1 -- TODO is this default correct?
    local link = GetInboxItemLink(index, itemIndex)
    if link then
        extend_tooltip(GameTooltip, link, select(4, GetInboxItem(index, itemIndex)))
    end
end

function game_tooltip_hooks.SetInventoryItem(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks.SetMerchantItem(slot)
    local link = GetMerchantItemLink(slot)
    if link then
        local quantity = select(4, GetMerchantItemInfo(slot))
        extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks.SetCraftItem(skill, slot)
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

function game_tooltip_hooks.SetCraftSpell(slot)
    local link = GetCraftItemLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks.SetTradeSkillItem(skill, slot)
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

function game_tooltip_hooks.SetAuctionSellItem()
    local name, _, quantity = GetAuctionSellItemInfo()
    if name then
        for slot in info.inventory() do
            local link = GetContainerItemLink(unpack(slot))
            if link and select(5, info.parse_link(link)) == name then
                extend_tooltip(GameTooltip, link, quantity)
                return
            end
        end
    end
end

function game_tooltip_hooks.SetTradePlayerItem(index)
    local link = GetTradePlayerItemLink(index)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetTradePlayerItemInfo(index)))
    end
end

function game_tooltip_hooks.SetTradeTargetItem(index)
    local link = GetTradeTargetItemLink(index)
    if link then
        extend_tooltip(GameTooltip, link, select(3, GetTradeTargetItemInfo(index)))
    end
end

function game_tooltip_hooks.SetSendMailItem(sendMailIndex)
    local link = GetSendMailItemLink(sendMailIndex)
    if link then
        extend_tooltip(GameTooltip, link, select(4, GetSendMailItem(sendMailIndex)))
    end
end

function game_tooltip_hooks.SetBuybackItem(slot)
    local link = GetBuybackItemLink(slot)
    if link then
        extend_tooltip(GameTooltip, link, select(4, GetBuybackItemInfo(slot)))
    end
end
