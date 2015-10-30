AuxVersion = "2.0.0"
AuxAuthors = "shirsig; Zerf; Zirco (Auctionator); Nimeral (Auctionator backport)"

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
}

function Aux_OnLoad()
	Aux.log('Aux v'..AuxVersion..' loaded.')
	Aux.loaded = true
end

function Aux_OnEvent()
	if event == "VARIABLES_LOADED" then
		Aux_OnLoad()
	elseif event == "ADDON_LOADED" then
		Aux_OnAddonLoaded()
	elseif event == "AUCTION_HOUSE_SHOW" then
		Aux_OnAuctionHouseShow()
	elseif event == "AUCTION_HOUSE_CLOSED" then
		Aux_OnAuctionHouseClosed()
	end
end

function Aux_OnAddonLoaded()
	if string.lower(arg1) == "blizzard_auctionui" then
        AuctionFrame:SetScript('OnHide', nil)
		Aux_SetupHookFunctions()
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

    Aux.orig.AuctionFrame_OnShow = AuctionFrame_OnShow
    -- TODO for some reason this breaks the auction house functionality
--    AuctionFrame_OnShow = function()
--        if not Aux.blizzard_ui_shown then
--            HideUIPanel(AuctionFrame)
--        else
--            return Aux.orig.AuctionFrame_OnShow()
--        end
--    end

    Aux.orig.PickupContainerItem = PickupContainerItem
	PickupContainerItem = Aux.PickupContainerItem
	
	Aux.orig.ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
	ContainerFrameItemButton_OnClick = Aux_ContainerFrameItemButton_OnClick

    Aux.orig.AuctionFrameAuctions_OnEvent = AuctionFrameAuctions_OnEvent
    AuctionFrameAuctions_OnEvent = Aux.AuctionFrameAuctions_OnEvent

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

    Aux.buy.on_close()
    Aux.sell.on_close()
	
	AuxFrame:Hide()
end

function Aux.on_tab_click(index)
    Aux.post.stop()
    Aux.stack.stop()
    Aux.scan.abort(function()
        Aux.buy.on_close()
        Aux.sell.on_close()
        Aux.manage_frame.on_close()
        Aux.history.on_close()

        for i=1,4 do
            getglobal('AuxTab'..i):SetAlpha(i == index and 1 or 0.5)
        end

        AuxSellFrame:Hide()
        AuxBuyFrame:Hide()
        AuxHistoryFrame:Hide()
        AuxManageFrame:Hide()

        if index == 1 then
            AuxBuyFrame:Show()
            Aux.buy.on_open()
        elseif index == 2 then
            AuxSellFrame:Show()
            Aux.sell.on_open()
        elseif index == 3 then
            AuxManageFrame:Show()
            Aux.manage_frame.on_open()
        elseif index == 4 then
            AuxHistoryFrame:Show()
            Aux.history.on_open()
        end
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
	local container_item = Aux.info.container_item(bag, slot)
	
	if AuctionFrame:IsVisible() and button == "LeftButton" and container_item then
	
		if IsShiftKeyDown()
				and not ChatFrameEditBox:IsVisible()
				and AuxBuyFrame:IsVisible()
		then
            AuxBuyNameInputBox.completor.set_quietly(container_item.name)
			return
		elseif AUX_BUY_SHORTCUT and IsAltKeyDown() then
			if not AuxBuyFrame:IsVisible() then
                Aux.on_tab_click(1)
			end
			AuxBuyNameInputBox.completor.set_quietly(container_item.name)
			Aux.buy.SearchButton_onclick()
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
	end
end

function Aux.auction_signature(hyperlink, stack_size, amount)
	return hyperlink .. (stack_size or '0') .. '_' .. (amount or '0')
end