local m, public, private = Aux.module'tooltip'

aux_tooltip_value = true

private.game_tooltip_hooks = {}
private.hooked_setter = nil
private.game_tooltip_money = nil

function public.LOAD()
    for func, hook in m.game_tooltip_hooks do
        local func, hook = func, hook
        Aux.hook(
            func,
            function(...)
                m.hooked_setter = true
                m.game_tooltip_money = 0
                local results = {Aux.orig[GameTooltip][func](unpack(arg)) }
                m.hooked_setter = false
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
            m.extend_tooltip(ItemRefTooltip, link, 1)
        end
        return result
    end
    local orig = GameTooltip:GetScript('OnTooltipAddMoney')
    GameTooltip:SetScript('OnTooltipAddMoney', function(...)
        if m.hooked_setter then
            m.game_tooltip_money = arg1
        else
            return orig(unpack(arg))
        end
    end)
end

function private.extend_tooltip(tooltip, hyperlink, quantity)
    local item_id, suffix_id = Aux.info.parse_hyperlink(hyperlink)
    quantity = IsShiftKeyDown() and quantity or 1

    if aux_tooltip_disenchant_source then
        local color = {r=0.7, g=0.7, b=0.7}

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
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, Aux.info.display_name(event.item_id, true) or 'item:'..event.item_id, event.min_quantity, event.max_quantity), color.r, color.g, color.b)
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

        local _, price, limited = Aux.cache.merchant_info(item_id)
        if price then
            tooltip:AddLine('Vendor Buy '..(limited and '(limited): ' or ': ')..Aux.util.format_money(price * quantity), color.r, color.g, color.b)
        end
    end
    if aux_tooltip_vendor_sell then
        local color = {r=0.8, g=0.5, b=0.1}

        local price = Aux.cache.merchant_info(item_id)
        if price ~= 0 then
            tooltip:AddLine('Vendor Sell: '..(price and Aux.util.format_money(price * quantity) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
    end

    local color = {r=1, g=1, b=0.6}

    local auctionable = not item_info or Aux.info.auctionable(Aux.info.tooltip(function(tt) tt:SetHyperlink(item_info.itemstring) end), item_info.quality)
    local item_key = (item_id or 0)..':'..(suffix_id or 0)

    local value = Aux.history.value(item_key)
    if auctionable then
        if aux_tooltip_value then
            tooltip:AddLine('Value: '..(value and Aux.util.format_money(value * quantity) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
        if aux_tooltip_daily  then
            local market_value = Aux.history.market_value(item_key)
            tooltip:AddLine('Today: '..(market_value and Aux.util.format_money(market_value * quantity)..' ('..Aux.auction_listing.percentage_historical(Aux.util.round(market_value / value * 100))..')' or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE), color.r, color.g, color.b)
        end
    end

    if tooltip == GameTooltip and m.game_tooltip_money > 0 then
        SetTooltipMoney(tooltip, m.game_tooltip_money)
    end
    tooltip:Show()
end

function m.game_tooltip_hooks:SetHyperlink(itemstring)
    local name, _, quality = GetItemInfo(itemstring)
    if name then
        local _, _, _, hex = GetItemQualityColor(quality)
        local link = hex.. '|H'..itemstring..'|h['..name..']|h|r'
        m.extend_tooltip(GameTooltip, link, 1)
    end
end

function m.game_tooltip_hooks:SetAuctionItem(type, index)
    local link = GetAuctionItemLink(type, index)
    if link then
        local _, _, quantity = GetAuctionItemInfo(type, index)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetLootItem(slot)
    local link = GetLootSlotLink(slot)
    if link then
        local _, _, quantity = GetLootSlotInfo(slot)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetQuestItem(qtype, slot)
    local link = GetQuestItemLink(qtype, slot)
    if link then
        local _, _, quantity = GetQuestItemInfo(qtype, slot)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetQuestLogItem(qtype, slot)
    local link = GetQuestLogItemLink(qtype, slot)
    if link then
        local _, _, quantity = GetQuestLogRewardInfo(slot)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetBagItem(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        local _, quantity = GetContainerItemInfo(bag, slot)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetInboxItem(index)
    local name, _, quantity = GetInboxItem(index)

    local id = name and Aux.cache.item_id(name)
    if id then
        local _, itemstring, quality = GetItemInfo(id)
        local _, _, _, hex = GetItemQualityColor(tonumber(quality))
        local link = hex.. '|H'..itemstring..'|h['..name..']|h|r'
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetInventoryItem(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        m.extend_tooltip(GameTooltip, link, 1)
    end
end

function m.game_tooltip_hooks:SetMerchantItem(slot)
    local link = GetMerchantItemLink(slot)
    if link then
        local _, _, _, quantity = GetMerchantItemInfo(slot)
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetCraftItem(skill, slot)
    local link, quantity
    if slot then
        link = GetCraftReagentItemLink(skill, slot)
        quantity = ({GetCraftReagentInfo(skill, slot)})[3]
    else
        link = GetCraftItemLink(skill)
        quantity = 1
    end
    if link then
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetCraftSpell(slot)
    local link = GetCraftItemLink(slot)
    if link then
        m.extend_tooltip(GameTooltip, link, 1)
    end
end

function m.game_tooltip_hooks:SetTradeSkillItem(skill, slot)
    local link, quantity
    if slot then
        link = GetTradeSkillReagentItemLink(skill, slot)
        quantity = ({GetTradeSkillReagentInfo(skill, slot)})[3]
    else
        link = GetTradeSkillItemLink(skill)
        quantity = 1
    end
    if link then
        m.extend_tooltip(GameTooltip, link, quantity)
    end
end

function m.game_tooltip_hooks:SetAuctionSellItem()
    local name, _, quantity, _, _, _ = GetAuctionSellItemInfo()
    if name then
        for slot in Aux.util.inventory() do
            local link = GetContainerItemLink(unpack(slot))
            if link and ({Aux.info.parse_hyperlink(link)})[5] == name then
                m.extend_tooltip(GameTooltip, link, quantity)
                return
            end
        end
    end
end