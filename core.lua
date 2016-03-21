Aux = {
    version = '2.9.0',
    blizzard_ui_shown = false,
	orig = {},
}

function Aux.on_load()
	Aux.log('Aux v'..Aux.version..' loaded.')
    tinsert(UISpecialFrames, 'AuxFrame')

    do
        local tab_group = Aux.gui.tab_group(AuxFrame, 'BOTTOM')
        tab_group:create_tab('Search')
        tab_group:create_tab('Post')
        tab_group:create_tab('Auctions')
        tab_group:create_tab('Bids')
        tab_group.on_select = Aux.on_tab_click
        Aux.tab_group = tab_group
    end

    do
        local btn = Aux.gui.button(AuxFrame, 16)
        btn:SetPoint('BOTTOMRIGHT', -6, 6)
        btn:SetWidth(65)
        btn:SetHeight(24)
        btn:SetText('Close')
        btn:SetScript('OnClick',function()
            HideUIPanel(this:GetParent())
        end)
        Aux.close_button = btn
    end

    do
        local btn = Aux.gui.button(AuxFrame, 16)
        btn:SetPoint('RIGHT', Aux.close_button, 'LEFT' , -5, 0)
        btn:SetWidth(65)
        btn:SetHeight(24)
        btn:SetText('Default UI')
        btn:SetScript('OnClick',function()
            if AuctionFrame:IsVisible() then
                Aux.blizzard_ui_shown = false
                HideUIPanel(AuctionFrame)
            else
                Aux.blizzard_ui_shown = true
                ShowUIPanel(AuctionFrame)
            end
        end)
    end

    Aux.cache.on_load()
    Aux.persistence.on_load()
    Aux.tooltip.on_load()
    Aux.search_frame.on_load()
    Aux.post_frame.on_load()
    Aux.auctions_frame.on_load()
    Aux.bids_frame.on_load()
end

function Aux.on_event()
	if event == 'VARIABLES_LOADED' then
		Aux.on_load()
	elseif event == 'ADDON_LOADED' then
		Aux.on_addon_loaded()
	elseif event == 'AUCTION_HOUSE_SHOW' then
		Aux.on_auction_house_show()
	elseif event == 'AUCTION_HOUSE_CLOSED' then
		Aux.on_auction_house_closed()
        Aux.bids_loaded = false
        Aux.current_owner_page = nil
    elseif event == 'AUCTION_BIDDER_LIST_UPDATE' then
        Aux.bids_loaded = true
	elseif event == 'AUCTION_OWNED_LIST_UPDATE' then
        Aux.current_owner_page = Aux.last_owner_page_requested or 0
    end
end

function Aux.on_addon_loaded()
    if arg1 == 'Blizzard_AuctionUI' then
        Aux.setup_hooks()
    end

    do
        local function cost_label(cost)
            local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
            label = label..(cost and Aux.util.format_money(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE)
            label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
            return label
        end

        if arg1 == 'Blizzard_CraftUI' then
            Aux.hook('CraftFrame_SetSelection', function(...)
                local results = {Aux.orig.CraftFrame_SetSelection(unpack(arg)) }

                local id = GetCraftSelectionIndex()
                local reagent_count = GetCraftNumReagents(id)

                local total_cost = 0
                for i=1,reagent_count do
                    local item_id, suffix_id = Aux.info.parse_hyperlink(GetCraftReagentItemLink(id, i))
                    local count = ({GetCraftReagentInfo(id, i)})[3]
                    local _, price, limited = Aux.cache.merchant_info(item_id)
                    local value = price and not limited and price or Aux.history.value(item_id..':'..suffix_id)
                    if not value then
                        total_cost = nil
                        break
                    else
                        total_cost = total_cost + value * count
                    end
                end

                CraftReagentLabel:SetText(SPELL_REAGENTS..' '..cost_label(total_cost))

                return unpack(results)
            end)
        end

        if arg1 == 'Blizzard_TradeSkillUI' then
            Aux.hook('TradeSkillFrame_SetSelection', function(...)
                local results = {Aux.orig.TradeSkillFrame_SetSelection(unpack(arg)) }

                local id = GetTradeSkillSelectionIndex()
                local reagent_count = GetTradeSkillNumReagents(id)

                local total_cost = 0
                for i=1,reagent_count do
                    local item_id, suffix_id = Aux.info.parse_hyperlink(GetTradeSkillReagentItemLink(id, i))
                    local count = ({GetTradeSkillReagentInfo(id, i)})[3]
                    local _, price, limited = Aux.cache.merchant_info(item_id)
                    local value = price and not limited and price or Aux.history.value(item_id..':'..suffix_id)
                    if not value then
                        total_cost = nil
                        break
                    else
                        total_cost = total_cost + value * count
                    end
                end

                TradeSkillReagentLabel:SetText(SPELL_REAGENTS..' '..cost_label(total_cost))

                return unpack(results)
            end)
        end
    end
end

do
    local locked

    function Aux.bid_in_progress()
        return locked
    end

    function Aux.place_bid(type, index, amount, on_success)

        if locked then
            return
        end

        local money = GetMoney()
        if money >= amount then
            locked = true
            local t0 = GetTime()
            Aux.control.as_soon_as(function() return GetMoney() < money or GetTime() - t0 > 10 end, function()
                if GetMoney() < money then
                    on_success()
                end
                locked = false
            end)
        end
        PlaceAuctionBid(type, index, amount)
    end
end

function Aux.log(msg)
    DEFAULT_CHAT_FRAME:AddMessage('[aux] '..msg, 1, 1, 0)
end

function Aux.setup_hooks()

    local blizzard_ui_on_hide = function()
        Aux.blizzard_ui_shown = false
    end
    AuctionFrame:SetScript('OnHide', blizzard_ui_on_hide)

    Aux.hook('AuctionFrame_OnShow', function(...)
        if not Aux.blizzard_ui_shown then
            Aux.control.as_soon_as(function() return AuctionFrame:GetScript('OnHide') == blizzard_ui_on_hide end, function()
                HideUIPanel(AuctionFrame)
            end)
        end
        return Aux.orig.AuctionFrame_OnShow(unpack(arg))
    end)

    Aux.hook('GetOwnerAuctionItems', Aux.GetOwnerAuctionItems)
    Aux.hook('PickupContainerItem', Aux.PickupContainerItem)
    Aux.hook('SetItemRef', Aux.SetItemRef)
    Aux.hook('UseContainerItem', Aux.UseContainerItem)
    Aux.hook('AuctionFrameAuctions_OnEvent', Aux.AuctionFrameAuctions_OnEvent)

end

function Aux.GetOwnerAuctionItems(...)
    local page = arg[1]
    Aux.last_owner_page_requested = page
    return Aux.orig.GetOwnerAuctionItems(unpack(arg))
end

function Aux.AuctionFrameAuctions_OnEvent(...)
    if AuctionFrameAuctions:IsVisible() then
        return Aux.orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end

function Aux.on_auction_house_show()
    if not UnitFactionGroup('target') then
        Aux.neutral = true
    end
    AuxFrame:Show()
    Aux.tab_group:set_tab(1)
end

function Aux.on_auction_house_closed()
	Aux.post.stop()
	Aux.stack.stop()
	Aux.scan.abort()

    Aux.search_frame.on_close()
    Aux.post_frame.on_close()
    Aux.auctions_frame.on_close()
    Aux.bids_frame.on_close()

	AuxFrame:Hide()
end

function Aux.on_tab_click(index)
    Aux.search_frame.on_close()
    Aux.post_frame.on_close()
    Aux.auctions_frame.on_close()
    Aux.bids_frame.on_close()

    AuxSearchFrame:Hide()
    AuxPostFrame:Hide()
    AuxAuctionsFrame:Hide()
    AuxBidsFrame:Hide()

    if index == 1 then
        AuxSearchFrame:Show()
        Aux.search_frame.on_open()
    elseif index == 2 then
        AuxPostFrame:Show()
        Aux.post_frame.on_open()
    elseif index == 3 then
        AuxAuctionsFrame:Show()
        Aux.auctions_frame.on_open()
    elseif index == 4 then
        AuxBidsFrame:Show()
        Aux.bids_frame.on_open()
    end

    Aux.active_panel = index
end

function Aux.round(v)
	return floor(v + 0.5)
end

function Aux.price_level_color(pct)
    if pct > 135 then
        return 1.0,0.0,0.0 -- red
    elseif pct > 110 then
        return 1.0,0.6,0.1 -- orange
    elseif pct > 80 then
        return 1.0,1.0,0.0 -- yellow
    elseif pct > 50 then
        return 0.1,1.0,0.1 -- green
    else
        return 0.2,0.6,1.0 -- blue
    end
end

do -- TODO make it work for other ways to pick up things
    local last_picked_up
    function Aux.PickupContainerItem(...)
        local bag, slot = unpack(arg)
        last_picked_up = { bag, slot }
        return Aux.orig.PickupContainerItem(unpack(arg))
    end
    function Aux.cursor_item()
        if last_picked_up and CursorHasItem() then
            return Aux.info.container_item(unpack(last_picked_up))
        end
    end
end

function Aux.SetItemRef(...)
    local itemstring, text, button = unpack(arg)
    if AuxSearchFrame:IsVisible() and button == 'RightButton' then
        local item_info = Aux.info.item(tonumber(({strfind(itemstring, '^item:(%d+)')})[3]))
        if item_info then
            Aux.search_frame.set_filter(item_info.name..'/exact')
            Aux.search_frame.start_search()
            return
        end
    end
    return Aux.orig.SetItemRef(unpack(arg))
end

function Aux.UseContainerItem(...)
    local bag, slot = unpack(arg)
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
        return Aux.orig.UseContainerItem(unpack(arg))
    end

    if AuxSearchFrame:IsVisible() then
        local item_info = Aux.info.container_item(bag, slot)
        item_info = item_info and Aux.info.item(item_info.item_id)
        if item_info then
            Aux.search_frame.start_search(strlower(item_info.name)..'/exact')
        end
        return
    end

    if AuxPostFrame:IsVisible() then
        local item_info = Aux.info.container_item(bag, slot)
        if item_info then
            Aux.post_frame.select_item(item_info.item_key)
        end
        return
    end

	return Aux.orig.UseContainerItem(unpack(arg))
end

function Aux.item_class_index(item_class)
    for i, class in ipairs({ GetAuctionItemClasses() }) do
        if strupper(class) == strupper(item_class) then
            return i
        end
    end
end

function Aux.item_subclass_index(class_index, item_subclass)
    for i, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
        if strupper(subclass) == strupper(item_subclass) then
            return i
        end
    end
end

function Aux.item_slot_index(class_index, subclass_index, slot_name)
    for i, slot in ipairs({ GetAuctionInvTypes(class_index, subclass_index) }) do
        if strupper(getglobal(slot)) == strupper(slot_name) then
            return i
        end
    end
end

function Aux.item_quality_index(item_quality)
    for i=0,4 do
        local quality = getglobal('ITEM_QUALITY'..i..'_DESC')
        if strupper(item_quality) == strupper(quality) then
            return i
        end
    end
end

function Aux.hide_elements(elements)
    for _, element in pairs(elements) do
        element:Hide()
    end
end

function Aux.show_elements(elements)
    for _, element in pairs(elements) do
        element:Show()
    end
end

function Aux.is_player(name)
    return UnitName('player') == name -- TODO support multiple chars
end

Aux.orig = {}
function Aux.hook(name, handler, object)
    local orig
    if object then
        Aux.orig[object] = Aux.orig[object] or {}
        orig = Aux.orig[object]
    else
        object = object or getfenv(0)
        orig = Aux.orig
    end

    if orig[name] then
        error('Already got a hook for '..name)
    end

    orig[name] = object[name]
    object[name] = handler
end

Aux.huge = 2^100000