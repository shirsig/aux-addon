Aux = {
    version = '2.6.8',
    blizzard_ui_shown = false,
	orig = {},
}

function Aux.on_load()
	Aux.log('Aux v'..Aux.version..' loaded.')
    tinsert(UISpecialFrames, 'AuxFrame')
    LoadAddOn('EnhTooltip')
    if IsAddOnLoaded('EnhTooltip') then
        Stubby.RegisterFunctionHook('EnhTooltip.AddTooltip', 100, function(_ ,_ ,_ ,_ , link, _, count)
            if EnhTooltip.LinkType(link) ~= 'item' then return end

            local item_id, suffix_id = EnhTooltip.BreakLink(link)

            if not Aux.static.item_info(item_id) then
                return
            end

            local item_key = (item_id or 0)..':'..(suffix_id or 0)

            local value = Aux.history.value(item_key)

            local value_line = 'Value: '

            value_line = value_line..(value and EnhTooltip.GetTextGSC(value) or '---')

            local _, _, _, market_values = Aux.history.price_data(item_key)
            if value and getn(market_values) < 5 then
                value_line = value_line..' (?)'
            end

            EnhTooltip.AddLine(value_line, nil, true)
            EnhTooltip.LineColor(0.1, 0.8, 0.5)

            if aux_tooltip_daily then
                local market_value = Aux.history.market_value(item_key)

                local market_value_line = 'Today: '
                market_value_line = market_value_line..(market_value and EnhTooltip.GetTextGSC(market_value)..' ('..Aux.auction_listing.percentage_historical(Aux.round(market_value / value * 100))..')' or '---')

                EnhTooltip.AddLine(market_value_line, nil, true)
                EnhTooltip.LineColor(0.1, 0.8, 0.5)
            end
        end)
    end

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

    Aux.persistence.on_load()
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
    if string.lower(arg1) == 'blizzard_auctionui' then
        Aux.setup_hooks()
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

    Aux.orig.AuctionFrame_OnShow = AuctionFrame_OnShow
    AuctionFrame_OnShow = function()
        if not Aux.blizzard_ui_shown then
            Aux.control.as_soon_as(function() return AuctionFrame:GetScript('OnHide') == blizzard_ui_on_hide end, function()
                HideUIPanel(AuctionFrame)
            end)
        end
        return Aux.orig.AuctionFrame_OnShow()
    end

    Aux.orig.GetOwnerAuctionItems = GetOwnerAuctionItems
    GetOwnerAuctionItems = Aux.GetOwnerAuctionItems

    Aux.orig.PickupContainerItem = PickupContainerItem
	PickupContainerItem = Aux.PickupContainerItem

    Aux.orig.SetItemRef = SetItemRef
    SetItemRef = Aux.SetItemRef

	Aux.orig.UseContainerItem = UseContainerItem
    UseContainerItem = Aux.UseContainerItem

    Aux.orig.AuctionFrameAuctions_OnEvent = AuctionFrameAuctions_OnEvent
    AuctionFrameAuctions_OnEvent = Aux.AuctionFrameAuctions_OnEvent

end

function Aux.GetOwnerAuctionItems(page)
    Aux.last_owner_page_requested = page
    return Aux.orig.GetOwnerAuctionItems(page)
end

function Aux.AuctionFrameAuctions_OnEvent()
    if AuctionFrameAuctions:IsVisible() then
        Aux.orig.AuctionFrameAuctions_OnEvent()
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
    function Aux.PickupContainerItem(bag, slot)
        last_picked_up = { bag, slot }
        return Aux.orig.PickupContainerItem(bag, slot)
    end
    function Aux.cursor_item()
        if last_picked_up and CursorHasItem() then
            return Aux.info.container_item(unpack(last_picked_up))
        end
    end
end

function Aux.SetItemRef(itemstring, text, button)
    if IsAltKeyDown() and AuxSearchFrame:IsVisible() then
        local item_info = Aux.static.item_info(tonumber(({strfind(itemstring, '^item:(%d+)')})[3]))
        if item_info then
            Aux.search_frame.set_filter(item_info.name..'/exact')
            Aux.search_frame.start_search()
            return
        end
    end
    return Aux.orig.SetItemRef(itemstring, text, button)
end

function Aux.UseContainerItem(bag, slot)
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
        return Aux.orig.UseContainerItem(bag, slot)
    end

    if AuxSearchFrame:IsVisible() then
        local item_info = Aux.info.container_item(bag, slot)
        item_info = item_info and Aux.static.item_info(item_info.item_id)
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

	return Aux.orig.UseContainerItem(bag, slot)
end

function Aux.quality_color(code)
	if code == 0 then
		return 'ff9d9d9d' -- poor, gray
	elseif code == 1 then
		return 'ffffffff' -- common, white
	elseif code == 2 then
		return 'ff1eff00' -- uncommon, green
	elseif code == 3 then -- rare, blue
		return 'ff0070dd'
	elseif code == 4 then
		return 'ffa335ee' -- epic, purple
	elseif code == 5 then
		return 'ffff8000' -- legendary, orange
    elseif code == 6 then
        return 'ffe6cc80' -- artifact, pale gold
    end
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

Aux.huge = 2^100000