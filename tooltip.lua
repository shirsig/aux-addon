local private, public = {}, {}
Aux.tooltip = public

local game_tooltip_hooks = {}
local hooked_setter
local game_tooltip_money

function public.on_load()
    for func, hook in game_tooltip_hooks do
        local func, hook = func, hook
        Aux.hook(
            func,
            function(...)
                hooked_setter = true
                game_tooltip_money = 0
                local results = {Aux.orig[GameTooltip][func](unpack(arg)) }
                hooked_setter = false
                hook(unpack(arg))
                return unpack(results)
            end,
            GameTooltip
        )
    end
    local orig = SetItemRef
    SetItemRef = function(...)
        local result = orig(unpack(arg))
        local name, _, quality = GetItemInfo(arg[1])
        if not IsShiftKeyDown() and not IsControlKeyDown() and name then
            local _, _, _, hex = GetItemQualityColor(quality)
            local link = hex.. '|H'..arg[1]..'|h['..name..']|h|r'
            private.extend_tooltip(ItemRefTooltip, link, 1)
        end
        return result
    end
    local orig = GameTooltip:GetScript('OnTooltipAddMoney')
    GameTooltip:SetScript('OnTooltipAddMoney', function(...)
        if hooked_setter then
            game_tooltip_money = arg1
        else
            return orig(unpack(arg))
        end
    end)
end

function private.extend_tooltip(tooltip, hyperlink, quantity)
    local item_id, suffix_id = Aux.info.parse_hyperlink(hyperlink)

    if aux_tooltip_disenchant_source then
        local color = {r=0.7, g=0.7, b=0.7 }

        local type, range = Aux.disenchant.source(item_id)

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

    local item_info = Aux.info.item(item_id)
    if item_info then
        local distribution = Aux.disenchant.distribution(item_info.slot, item_info.quality, item_info.level)

        if getn(distribution) > 0 then

            if aux_tooltip_disenchant_distribution then
                local color = {r=0.8, g=0.8, b=0.2}

                tooltip:AddLine('Disenchants into:', color.r, color.g, color.b)
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in distribution do
                    tooltip:AddLine(format('  %s%% %s x%s', event.probability * 100, Aux.info.display_name(event.item_id, true) or 'item:'..event.item_id, event.quantity), color.r, color.g, color.b)
                end
            end

            if aux_tooltip_disenchant_value then
                local color = {r=0.1, g=0.6, b=0.6}

                local disenchant_value = Aux.disenchant.value(item_info.slot, item_info.quality, item_info.level)
                tooltip:AddLine('Disenchant Value: '..(disenchant_value and Aux.util.format_money(disenchant_value) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
            end
        end
    end

    if aux_tooltip_vendor_buy then
        local color = {r=0.8, g=0.5, b=0.1}

        local _, price, limited = Aux.merchant.info(item_id)
        if price then
            tooltip:AddLine('Vendor Buy '..(limited and '(limited): ' or ': ')..Aux.util.format_money(price), color.r, color.g, color.b)
        end
    end
    if aux_tooltip_vendor_sell then
        local color = {r=0.8, g=0.5, b=0.1}

        local price = Aux.merchant.info(item_id)
        if price ~= 0 then
            tooltip:AddLine('Vendor Sell: '..(price and Aux.util.format_money(price) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
    end

    local color = {r=1, g=1, b=0.6 }

    local auctionable = not item_info or Aux.info.auctionable(Aux.info.tooltip(function(tt) tt:SetHyperlink(item_info.itemstring) end), item_info.quality)
    local item_key = (item_id or 0)..':'..(suffix_id or 0)

    local value = Aux.history.value(item_key)
    if auctionable then
        tooltip:AddLine('Value: '..(value and Aux.util.format_money(value) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        if aux_tooltip_daily  then
            local market_value = Aux.history.market_value(item_key)
            tooltip:AddLine('Today: '..(market_value and Aux.util.format_money(market_value)..' ('..Aux.auction_listing.percentage_historical(Aux.round(market_value / value * 100))..')' or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
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
        local _, _, _, hex = GetItemQualityColor(quality)
        local link = hex.. '|H'..itemstring..'|h['..name..']|h|r'
        private.extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetAuctionItem(type, index)
    local link = GetAuctionItemLink(type, index)
    if link then
        local _, _, quantity = GetAuctionItemInfo(type, index)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetLootItem(slot)
    local link = GetLootSlotLink(slot)
    if link then
        local _, _, quantity = GetLootSlotInfo(slot)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetQuestItem(qtype, slot)
    local link = GetQuestItemLink(qtype, slot)
    if link then
        local _, _, quantity = GetQuestItemInfo(qtype, slot)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetQuestLogItem(qtype, slot)
    local link = GetQuestLogItemLink(qtype, slot)
    if link then
        local _, _, quantity = GetQuestLogRewardInfo(slot)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetBagItem(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        local _, quantity = GetContainerItemInfo(bag, slot)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

--function game_tooltip_hooks:SetInboxItem(index)
--    local name, _, quantity = GetInboxItem(index)
--
--    for itemID = 1, 30000 do
--        local itemName, itemstring, itemQuality = GetItemInfo(itemID)
--        if (itemName and itemName == inboxItemName) then
--            local _, _, _, hex = GetItemQualityColor(tonumber(itemQuality))
--            local itemLink = hex.. '|H'..itemstring..'|h['..itemName..']|h|r'
--            tooltipCall(GameTooltip, inboxItemName, itemLink, inboxItemQuality, inboxItemCount)
--            break
--        end
--    end
--end

function game_tooltip_hooks:SetInventoryItem(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        private.extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetMerchantItem(slot)
    local link = GetMerchantItemLink(slot)
    if link then
        local _, _, _, quantity = GetMerchantItemInfo(slot)
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftItem(skill, slot)
    local link, quantity
    if slot then
        link = GetCraftReagentItemLink(skill, slot)
        quantity = ({GetCraftReagentInfo(skill, slot)})[3]
    else
        link = GetCraftItemLink(skill)
        quantity = 1
    end
    if link then
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetCraftSpell(slot)
    local link = GetCraftItemLink(slot)
    if link then
        private.extend_tooltip(GameTooltip, link, 1)
    end
end

function game_tooltip_hooks:SetTradeSkillItem(skill, slot)
    local link, quantity
    if slot then
        link = GetTradeSkillReagentItemLink(skill, slot)
        quantity = ({GetTradeSkillReagentInfo(skill, slot)})[3]
    else
        link = GetTradeSkillItemLink(skill)
        quantity = 1
    end
    if link then
        private.extend_tooltip(GameTooltip, link, quantity)
    end
end

function game_tooltip_hooks:SetAuctionSellItem()
    local name, _, quantity, _, _, _ = GetAuctionSellItemInfo()
    if name then
        for bag = 0, 4 do
            if GetBagName(bag) then
                for slot = 1, GetContainerNumSlots(bag) do
                    local link = GetContainerItemLink(bag, slot)
                    if link and ({Aux.info.parse_hyperlink(link)})[5] == name then
                        private.extend_tooltip(GameTooltip, link, quantity)
                        return
                    end
                end
            end
        end
    end
end