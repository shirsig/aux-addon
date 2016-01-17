AuxVersion = '2.2.0'
AuxAuthors = 'shirsig; Zerf; Zirco (Auctionator); Nimeral (Auctionator backport)'

local lastRightClickAction = GetTime()

Aux = {
    blizzard_ui_shown = false,
	loaded = false,
	orig = {},
	elements = {},
    tabs = {
        browse = {
            index = 1
        },
        post = {
            index = 2
        },
    },
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
    Stubby.RegisterFunctionHook('EnhTooltip.AddTooltip', 100, function(_ ,_ ,_ ,_ , link, _, count)
        local item_id, suffix_id = EnhTooltip.BreakLink(link)
        local item_key = item_id..':'..suffix_id

        local auction_count, seen_days, daily_average, EMA3, EMA7, EMA14 = Aux.stat_average.get_price_data(item_key)

        if auction_count == 0 then
            EnhTooltip.AddLine('Never seen at auction', nil, true)
            EnhTooltip.LineColor(0.5, 0.8, 0.5)
        else
            EnhTooltip.AddLine('Seen '..auction_count..' '..Aux_PluralizeIf('time', auction_count)..' at auction', nil, true)
            EnhTooltip.LineColor(0.5, 0.8, 0.1)


            local median = Aux.stat_histogram.get_price_data(item_key)
            if count == 1 then
                EnhTooltip.AddLine('Median: '..Aux.util.money_string(median), nil, true)
            else
                EnhTooltip.AddLine('Median: '..Aux.util.money_string(median * count)..' ('..Aux.util.money_string(median)..' ea.)', nil, true)
            end
            EnhTooltip.LineColor(0.1,0.8,0.5)

--            EnhTooltip.AddLine('AVG TDA: '..(daily_average > 0 and Aux.util.money_string(daily_average) or RED_FONT_COLOR_CODE..'n/a'..FONT_COLOR_CODE_CLOSE), nil, true)
--            EnhTooltip.LineColor(0.1,0.8,0.5)
--            EnhTooltip.AddLine('EMA3: '..(EMA3 > 0 and Aux.util.money_string(EMA3) or RED_FONT_COLOR_CODE..'n/a'..FONT_COLOR_CODE_CLOSE), nil, true)
--            EnhTooltip.LineColor(0.1,0.8,0.5)
--            EnhTooltip.AddLine('EMA7: '..(EMA7 > 0 and Aux.util.money_string(EMA7) or RED_FONT_COLOR_CODE..'n/a'..FONT_COLOR_CODE_CLOSE), nil, true)
--            EnhTooltip.LineColor(0.1,0.8,0.5)
--            EnhTooltip.AddLine('EMA14: '..(EMA14 > 0 and Aux.util.money_string(EMA14) or RED_FONT_COLOR_CODE..'n/a'..FONT_COLOR_CODE_CLOSE), nil, true)
--            EnhTooltip.LineColor(0.1,0.8,0.5)
        end
    end)
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
    local info = ChatTypeInfo['SYSTEM']
    AuxLogFrameMessageFrame:AddMessage(msg, 1, 1, 0)
    if not AuxLogFrameMessageFrame:IsVisible() and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
    end
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

    Aux.on_tab_click(1)
	if AUX_OPEN_SELL then
        Aux.on_tab_click(2)
	elseif AUX_OPEN_BUY then

	end

end

function Aux_OnAuctionHouseClosed()
	Aux.post.stop()
	Aux.stack.stop()
	Aux.scan.abort()

    Aux.filter_search_frame.on_close()
    Aux.sell.on_close()
	
	AuxFrame:Hide()
end

function Aux.on_tab_click(index)
    Aux.post.stop()
    Aux.stack.stop()
    Aux.scan.abort(function()
        Aux.item_search_frame.on_close()
        Aux.filter_search_frame.on_close()
        Aux.sell.on_close()
        Aux.auctions_frame.on_close()
        Aux.bids_frame.on_close()
        Aux.history_frame.on_close()

        for i=1,5 do
            getglobal('AuxTab'..i):SetAlpha(i == index and 1 or 0.5)
        end

        AuxItemSearchFrame:Hide()
        AuxFilterSearchFrame:Hide()
        AuxSellFrame:Hide()
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
            AuxSellFrame:Show()
            Aux.sell.on_open()
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

function Aux_Round(v)
	return math.floor(v + 0.5)
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

function Aux.auction_signature(hyperlink, stack_size, bid, amount)
	return hyperlink .. (stack_size or '0') .. '_' .. (bid or '0') .. '_' .. (amount or '0')
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