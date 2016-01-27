AuxVersion = '2.3.3'
AuxAuthors = 'shirsig; Zerf; Zirco (Auctionator); Nimeral (Auctionator backport)'

local lastRightClickAction = GetTime()

Aux = {
    blizzard_ui_shown = false,
	loaded = false,
	orig = {},
	last_picked_up = {},
    view = {
        BUYOUT = 1,
        BID = 2,
        FULL = 3,
    },
}

aux_view = Aux.view.BUYOUT

function Aux_OnLoad()
	Aux.log('Aux v'..AuxVersion..' loaded.')
	Aux.loaded = true
    tinsert(UISpecialFrames, 'AuxFrame')
    LoadAddOn('EnhTooltip')
    if IsAddOnLoaded('EnhTooltip') then
        Stubby.RegisterFunctionHook('EnhTooltip.AddTooltip', 100, function(_ ,_ ,_ ,_ , link, _, count)
            local item_id, suffix_id = EnhTooltip.BreakLink(link)
            local item_key = (item_id or 0)..':'..(suffix_id or 0)

            local auction_count, day_count, TDA, EMA7 = Aux.history.price_data(item_key)

            if auction_count == 0 then
                EnhTooltip.AddLine('Never seen at auction', nil, true)
                EnhTooltip.LineColor(0.5, 0.8, 0.5)
            else
                EnhTooltip.AddLine('Seen '..auction_count..' '..Aux_PluralizeIf('time', auction_count)..' at auction', nil, true)
                EnhTooltip.LineColor(0.5, 0.8, 0.1)

                local market_value = Aux.history.market_value(item_key)
                local market_value_line
                if count == 1 then
                    market_value_line = 'Market Value: '..EnhTooltip.GetTextGSC(market_value)
                else
                    market_value_line = 'Market Value: '..EnhTooltip.GetTextGSC(market_value * count)..' / '..EnhTooltip.GetTextGSC(market_value)
                end

                EnhTooltip.AddLine(market_value_line, nil, true)
                EnhTooltip.LineColor(0.1,0.8,0.5)
            end
        end)
    end

    do
        local tab_group = Aux.gui.tab_group(AuxFrame, 'BOTTOM')
        tab_group:create_tab('Item Search')
        tab_group:create_tab('Filter Search')
        tab_group:create_tab('Post')
        tab_group:create_tab('Auctions')
        tab_group:create_tab('Bids')
        tab_group.on_select = Aux.on_tab_click
        Aux.tab_group = tab_group
    end
    do
        local btn = Aux.gui.button(AuxFrame, 12)
        btn:SetPoint('TOPRIGHT', 0, 0)
        btn:SetWidth(60)
        btn:SetHeight(17)
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

    do
        local btn = Aux.gui.button(AuxFrame, 16)
        btn:SetPoint('BOTTOMRIGHT', -6, 6)
        btn:SetWidth(65)
        btn:SetHeight(24)
        btn:SetText('Close')
        btn:SetScript('OnClick',function()
            HideUIPanel(this:GetParent())
        end)
    end

    Aux.item_search_frame.on_load()
    Aux.filter_search_frame.on_load()
    Aux.post_frame.on_load()
    Aux.auctions_frame.on_load()
    Aux.bids_frame.on_load()
end

function Aux_OnEvent()
	if event == 'VARIABLES_LOADED' then
		Aux_OnLoad()
	elseif event == 'ADDON_LOADED' then
		Aux_OnAddonLoaded()
	elseif event == 'AUCTION_HOUSE_SHOW' then
		Aux_OnAuctionHouseShow()
	elseif event == 'AUCTION_HOUSE_CLOSED' then
		Aux_OnAuctionHouseClosed()
        Aux.bids_loaded = false
        Aux.current_owner_page = nil
    elseif event == 'AUCTION_BIDDER_LIST_UPDATE' then
        Aux.bids_loaded = true
	elseif event == 'AUCTION_OWNED_LIST_UPDATE' then
        Aux.current_owner_page = Aux.last_owner_page_requested or 0
    end
end

function Aux_OnAddonLoaded()
	if string.lower(arg1) == "blizzard_auctionui" then
		Aux_SetupHookFunctions()
    end
    if string.lower(arg1) == "EnhTooltip" then

    end
end

do
    local locked

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

function Aux.log_frame_load()
    this:SetFading(false)
    this:EnableMouseWheel()
    -- this.flashTimer = 0 TODO remove
end

function Aux.log_frame_update(elapsedSec)
    if not this:IsVisible() then
        return
    end

    local flash = getglobal(this:GetName()..'BottomButtonFlash')

    if not flash then
        return
    end

    if this:AtBottom() then
        if flash:IsVisible() then
            flash:Hide()
        end
        return
    end

    local flashTimer = this.flashTimer + elapsedSec
    if flashTimer < CHAT_BUTTON_FLASH_TIME then
        this.flashTimer = flashTimer
        return
    end

    while flashTimer >= CHAT_BUTTON_FLASH_TIME do
        flashTimer = flashTimer - CHAT_BUTTON_FLASH_TIME
    end
    this.flashTimer = flashTimer

    if flash:IsVisible() then
        flash:Hide()
    else
        flash:Show()
    end
end

function Aux.log(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
end

function Aux_SetupHookFunctions()

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
	
	Aux.orig.ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
	ContainerFrameItemButton_OnClick = Aux_ContainerFrameItemButton_OnClick

    Aux.orig.AuctionFrameAuctions_OnEvent = AuctionFrameAuctions_OnEvent
    AuctionFrameAuctions_OnEvent = Aux.AuctionFrameAuctions_OnEvent

    Aux.orig.UIDropDownMenu_StartCounting = UIDropDownMenu_StartCounting
    UIDropDownMenu_StartCounting = Aux.completion.UIDropDownMenu_StartCounting

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

function Aux_OnAuctionHouseShow()

    AuxFrame:Show()

    Aux.tab_group:set_tab(1)

end

function Aux_OnAuctionHouseClosed()
	Aux.post.stop()
	Aux.stack.stop()
	Aux.scan.abort()

    Aux.item_search_frame.on_close()
    Aux.filter_search_frame.on_close()
    Aux.post_frame.on_close()
    Aux.auctions_frame.on_close()
    Aux.bids_frame.on_close()
    Aux.history_frame.on_close()
	
	AuxFrame:Hide()
end

function Aux.on_tab_click(index)
    Aux.post.stop()
    Aux.stack.stop()
    Aux.scan.abort(function()
        Aux.item_search_frame.on_close()
        Aux.filter_search_frame.on_close()
        Aux.post_frame.on_close()
        Aux.auctions_frame.on_close()
        Aux.bids_frame.on_close()
        Aux.history_frame.on_close()

        AuxItemSearchFrame:Hide()
        AuxFilterSearchFrame:Hide()
        AuxPostFrame:Hide()
        AuxAuctionsFrame:Hide()
        AuxBidsFrame:Hide()
        AuxHistoryFrame:Hide()

        if index == 1 then
            AuxItemSearchFrame:Show()
            Aux.item_search_frame.on_open()
        elseif index == 2 then
            AuxFilterSearchFrame:Show()
            Aux.filter_search_frame.on_open()
        elseif index == 3 then
            AuxPostFrame:Show()
            Aux.post_frame.on_open()
        elseif index == 4 then
            AuxAuctionsFrame:Show()
            Aux.auctions_frame.on_open()
        elseif index == 5 then
            AuxBidsFrame:Show()
            Aux.bids_frame.on_open()
        end

        Aux.active_panel = index
    end)
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

function Aux_AuctionsButton_OnClick(button)
	if arg1 == "LeftButton" then -- because we additionally registered right clicks we only let left ones pass here
		Aux.orig.BrowseButton_OnClick(button)
	end
end

function Aux_AuctionsButton_OnMouseDown()
	if arg1 == "RightButton" and GetTime() - lastRightClickAction > 0.5 then
		local index = this:GetID() + FauxScrollFrame_GetOffset(AuctionsScrollFrame)
	
		SetSelectedAuctionItem("owner", index)
		
		CancelAuction(index)
		
		AuctionFrameAuctions_Update()
		lastRightClickAction = GetTime()
	end
end

function Aux.PickupContainerItem(bag, item)
	Aux.last_picked_up = { bag=bag, slot=item }
	return Aux.orig.PickupContainerItem(bag, item)
end

function Aux_ContainerFrameItemButton_OnClick(button)
	local bag, slot = this:GetParent():GetID(), this:GetID()
	local container_item_info = Aux.info.container_item(bag, slot)
	
	if AuxFrame:IsVisible() and button == "LeftButton" and container_item_info then
		if IsAltKeyDown() then
			if Aux.active_panel ~= 1 then
                Aux.on_tab_click(1)
            end

            Aux.control.as_soon_as(function() return Aux.active_panel == 1 end, function()
                AuxItemSearchFrameItemItemInputBox:Hide()
                Aux.item_search_frame.set_item(container_item_info.item_id)
            end)

            return
		end
    end

	return Aux.orig.ContainerFrameItemButton_OnClick(button)
end

function Aux_QualityColor(code)
	if code == 0 then
		return "ff9d9d9d" -- poor, gray
	elseif code == 1 then
		return "ffffffff" -- common, white
	elseif code == 2 then
		return "ff1eff00" -- uncommon, green
	elseif code == 3 then -- rare, blue
		return "ff0070dd"
	elseif code == 4 then
		return "ffa335ee" -- epic, purple
	elseif code == 5 then
		return "ffff8000" -- legendary, orange
    elseif code == 6 then
        return "ffe6cc80" -- artifact, pale gold
    end
end

function Aux.item_class_index(item_class)
    for i, class in ipairs({ GetAuctionItemClasses() }) do
        if class == item_class then
            return i
        end
    end
end

function Aux.item_subclass_index(class_index, item_subclass)
    for i, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
        if subclass == item_subclass then
            return i
        end
    end
end