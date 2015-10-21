AuxVersion = "1.6.0"
AuxAuthors = "shirsig; Zerf; Zirco (Auctionator); Nimeral (Auctionator backport)"

local lastRightClickAction = GetTime()

Aux = {
	loaded = false,
	orig = {},
	elements = {},
    tabs = {
        sell = {
            index = 4
        },
        buy = {
            index = 1
        }
    },
	last_picked_up = {},
}

-----------------------------------------

local relevel

-----------------------------------------

function Aux_OnLoad()
	Aux.log("Aux v"..AuxVersion.." loaded")
	Aux.loaded = true
end

-----------------------------------------

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

-----------------------------------------

function Aux_OnAddonLoaded()

	if string.lower(arg1) == "blizzard_auctionui" then
		Aux_AddTabs()
		Aux_AddPanels()
		
		Aux_SetupHookFunctions()
		
		Aux.tabs.sell.hiddenElements = {
                AuctionsPriceText,
                StartPrice,
                AuctionsBuyoutText,
                BuyoutPrice,
                AuctionsDurationText,
                AuctionsShortAuctionButton,
                AuctionsMediumAuctionButton,
                AuctionsLongAuctionButton,
				AuctionsCreateAuctionButton,
				AuctionsItemButton,
				AuctionsTitle,
				AuctionsScrollFrame,
				AuctionsButton1,
				AuctionsButton2,
				AuctionsButton3,
				AuctionsButton4,
				AuctionsButton5,
				AuctionsButton6,
				AuctionsButton7,
				AuctionsButton8,
				AuctionsButton9,
				AuctionsQualitySort,
				AuctionsDurationSort,
				AuctionsHighBidderSort,
				AuctionsBidSort,
				AuctionsCancelAuctionButton
		}
		
		Aux.tabs.buy.hiddenElements = {
				AuctionFrameBrowse,
		}

		Aux.tabs.sell.recommendationElements = {
				AuxRecommendText,
				AuxRecommendPerItemText,
				AuxRecommendPerItemPrice,
				AuxRecommendPerStackText,
				AuxRecommendPerStackPrice,
				AuxRecommendBasisText,
				AuxRecommendItemTex,
		}
	end
end

function Aux.log_frame_load()
    this:EnableMouseWheel()
    -- this.flashTimer = 0 TODO remove
end

function Aux.log_frame_update(elapsedSec)
    if not this:IsVisible() then
        return
    end

    local flash = getglobal(this:GetName().."BottomButtonFlash")

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
    local info = ChatTypeInfo["SYSTEM"]
    AuxLogFrame:AddMessage(msg, 1, 1, 0)
    if not AuxLogFrame:IsVisible() and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
    end
end

function Aux_SetupHookFunctions()

	Aux.orig.AuctionFrameAuctions_OnShow = AuctionFrameAuctions_OnShow
	AuctionFrameAuctions_OnShow = Aux_Sell_AuctionFrameAuctions_OnShow
	
	Aux.orig.BrowseButton_OnClick = BrowseButton_OnClick
	BrowseButton_OnClick = Aux_BrowseButton_OnClick

	AuctionsButton1:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton1:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton2:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton2:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton3:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton3:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton4:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton4:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton5:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton5:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton6:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton6:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton7:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton7:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton8:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton8:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	AuctionsButton9:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	AuctionsButton9:SetScript("OnMouseDown", Aux_AuctionsButton_OnMouseDown)
	
	BrowseButton1:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton1:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton2:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton2:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton3:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton3:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton4:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton4:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton5:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton5:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton6:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton6:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton7:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton7:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)
	BrowseButton8:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton8:SetScript("OnMouseDown", Aux_BrowseButton_OnMouseDown)

	Aux.orig.PickupContainerItem = PickupContainerItem
	PickupContainerItem = Aux.PickupContainerItem
	
	Aux.orig.AuctionSellItemButton_OnEvent = AuctionSellItemButton_OnEvent
	AuctionSellItemButton_OnEvent = Aux.sell.AuctionSellItemButton_OnEvent
	
	Aux.orig.AuctionFrameTab_OnClick = AuctionFrameTab_OnClick
	AuctionFrameTab_OnClick = Aux_AuctionFrameTab_OnClick
	
	Aux.orig.ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
	ContainerFrameItemButton_OnClick = Aux_ContainerFrameItemButton_OnClick
	
	Aux.orig.AuctionFrameBid_Update = AuctionFrameBid_Update
	AuctionFrameBid_Update = Aux_AuctionFrameBid_Update
	
	Aux.orig.AuctionFrameAuctions_Update = AuctionFrameAuctions_Update
	AuctionFrameAuctions_Update = Aux_AuctionFrameAuctions_Update
end

-----------------------------------------

function Aux_OnAuctionHouseShow()

	AuxOptionsButtonPanel:Show()

	if AUX_OPEN_SELL then
		AuctionFrameTab_OnClick(Aux.tabs.sell.index)
	elseif AUX_OPEN_BUY then
		-- AuctionFrameTab_OnClick(Aux.tabs.buy.index)
	end

end

-----------------------------------------

function Aux_OnAuctionHouseClosed()

	Aux.post.stop()
	Aux.stack.stop()
	Aux.buy.exit()
	Aux.scan.abort()
	
	AuxOptionsButtonPanel:Hide()
	AuxOptionsFrame:Hide()
	AuxAboutFrame:Hide()
	AuxSellPanel:Hide()
	AuxBuyPanel:Hide()
	
end

function Aux_AuctionFrameTab_OnClick(index)
	
	if not index then
		index = this:GetID()
	end
	
	Aux.post.stop()
	Aux.stack.stop()
	Aux.buy.exit()
	Aux.scan.abort()

	AuxSellPanel:Hide()
	AuxBuyPanel:Hide()

	if index == 2 then		
		Aux_ShowElems(Aux.tabs.buy.hiddenElements)
	end
	
	if index == 3 then		
		Aux_ShowElems(Aux.tabs.sell.hiddenElements)
	end
	
	if index == Aux.tabs.sell.index then
		AuctionFrameTab_OnClick(3)
		Aux.sell.on_open()
		
		PanelTemplates_SetTab(AuctionFrame, Aux.tabs.sell.index)
		
		Aux_HideElems(Aux.tabs.sell.hiddenElements)
		
		AuxSellPanel:Show()
		AuctionFrame:EnableMouse(false)
		
	elseif index == Aux.tabs.buy.index then
		Aux.orig.AuctionFrameTab_OnClick(1)
		
		PanelTemplates_SetTab(AuctionFrame, Aux.tabs.buy.index)
		
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
		
		AuxBuyPanel:Show()
		AuctionFrame:EnableMouse(false)
		
		Aux.buy.on_open()
	else
		Aux.orig.AuctionFrameTab_OnClick(index)
		lastItemPosted = nil
	end
end

function Aux_AddPanels()
	
	local sellFrame = CreateFrame("Frame", "AuxSellPanel", AuctionFrame, "AuxSellTemplate")
	sellFrame:SetParent("AuctionFrame")
	sellFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(sellFrame)
	sellFrame:Hide()
    
    local buyFrame = CreateFrame("Frame", "AuxBuyPanel", AuctionFrame, "AuxBuyTemplate")
	buyFrame:SetParent("AuctionFrame")
	buyFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
    AuxLogFrame:SetParent(buyFrame)
    AuxLogFrame:SetPoint('TOP', buyFrame, 100, -43)
	relevel(buyFrame)
	buyFrame:Hide()
	
	local optionsFrame = CreateFrame("Frame", "AuxOptionsButtonPanel", AuctionFrame, "AuxOptionsButtonTemplate")
	optionsFrame:SetParent("AuctionFrame")
	optionsFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(optionsFrame)
	optionsFrame:Hide()
end

-----------------------------------------

function Aux_AddTabs()
	
	AuctionFrameTab1:SetText('Buy')
	
	Aux.tabs.sell.index = AuctionFrame.numTabs + 1

	local sellTabName = "AuctionFrameTab"..Aux.tabs.sell.index

	local sellTab = CreateFrame("Button", sellTabName, AuctionFrame, "AuctionTabTemplate")

	setglobal(sellTabName, sellTab)
    
	sellTab:SetID(Aux.tabs.sell.index)
	sellTab:SetText("Sell")
	sellTab:SetPoint("LEFT", getglobal("AuctionFrameTab"..AuctionFrame.numTabs), "RIGHT", -8, 0)
	
	PanelTemplates_SetNumTabs(AuctionFrame, Aux.tabs.sell.index)
    PanelTemplates_EnableTab(AuctionFrame, Aux.tabs.sell.index)
end

-----------------------------------------

function Aux_HideElems(tt)

	if not tt then
		return;
	end
	
	for i,x in ipairs(tt) do
		x:Hide()
	end
end

-----------------------------------------

function Aux_ShowElems(tt)

	for i,x in ipairs(tt) do
		x:Show()
	end
end

-----------------------------------------

function Aux_PluralizeIf(word, count)

	if count and count == 1 then
		return word
	else
		return word.."s"
	end
end

-----------------------------------------

function Aux_Round(v)
	return math.floor(v + 0.5)
end

-----------------------------------------

function relevel(frame)
	local myLevel = frame:GetFrameLevel() + 1
	local children = { frame:GetChildren() }
	for _,child in pairs(children) do
		child:SetFrameLevel(myLevel)
		relevel(child)
	end
end

-----------------------------------------

function Aux_BrowseButton_OnClick(button)
	if arg1 == "LeftButton" then -- because we additionally registered right clicks we only let left ones pass here
		Aux.orig.BrowseButton_OnClick(button)
	end
end

-----------------------------------------

function Aux_AuctionsButton_OnClick(button)
	if arg1 == "LeftButton" then -- because we additionally registered right clicks we only let left ones pass here
		Aux.orig.BrowseButton_OnClick(button)
	end
end

-----------------------------------------

function Aux_BrowseButton_OnMouseDown()
	if arg1 == "RightButton" and AUX_INSTANT_BUYOUT and GetTime() - lastRightClickAction > 0.5 then
		local index = this:GetID() + FauxScrollFrame_GetOffset(BrowseScrollFrame)
	
		SetSelectedAuctionItem("list", index)
		
		local auction_item = Aux.info.auction_item(index)
		if auction_item.buyout_price > 0 then
			PlaceAuctionBid("list", index, auction_item.buyout_price)
		end
		
		AuctionFrameBrowse_Update()
		lastRightClickAction = GetTime()
	end
end

-----------------------------------------

function Aux_AuctionsButton_OnMouseDown()
	if arg1 == "RightButton" and GetTime() - lastRightClickAction > 0.5 then
		local index = this:GetID() + FauxScrollFrame_GetOffset(AuctionsScrollFrame)
	
		SetSelectedAuctionItem("owner", index)
		
		CancelAuction(index)
		
		AuctionFrameAuctions_Update()
		lastRightClickAction = GetTime()
	end
end

-----------------------------------------

function Aux.PickupContainerItem(bag, item)
	Aux.last_picked_up = { bag=bag, slot=item }
	return Aux.orig.PickupContainerItem(bag, item)
end

-----------------------------------------

function Aux_ContainerFrameItemButton_OnClick(button)
	local bag, slot = this:GetParent():GetID(), this:GetID()
	local container_item = Aux.info.container_item(bag, slot)
	
	if AuctionFrame:IsVisible() and button == "LeftButton" and container_item then
	
		if IsShiftKeyDown()
				and not ChatFrameEditBox:IsVisible()
				and (PanelTemplates_GetSelectedTab(AuctionFrame) == 1 or PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index)
		then
			if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index then
				AuxBuyNameInputBox.completor.set_quietly(container_item.name)
			end
			return
		elseif AUX_SELL_SHORTCUT and IsAltKeyDown()then
			Aux.sell.set_auction(bag, slot)	
			if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Aux.tabs.sell.index then
				AuctionFrameTab_OnClick(Aux.tabs.sell.index)
			end			
			return
		elseif AUX_BUY_SHORTCUT and IsControlKeyDown() then
			if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Aux.tabs.buy.index then
				AuctionFrameTab_OnClick(Aux.tabs.buy.index)
			end
			AuxBuyNameInputBox.completor.set_quietly(container_item.name)
			Aux.buy.SearchButton_onclick()
			return
		end
	end
	return Aux.orig.ContainerFrameItemButton_OnClick(button)
end

-----------------------------------------

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

-----------------------------------------

function Aux.auction_signature(hyperlink, stack_size, amount)
	return hyperlink .. (stack_size or '0') .. '_' .. (amount or '0')
end