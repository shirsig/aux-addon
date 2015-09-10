AuxVersion = "1.0.0"
AuxAuthors = "shirsig; Zerf; Zirco (Auctionator); Nimeral (Auctionator backport);"

AUCTIONATOR_ENABLE_ALT = true
AUCTIONATOR_OPEN_FIRST = false
AUCTIONATOR_INSTANT_BUYOUT = false

Aux = {
	loaded = false,
	orig = {},
	elements = {},
    tabs = {
        sell = {
            index = 4
        },
        buy = {
            index = 5
        }
    }
}

-----------------------------------------

local relevel

-----------------------------------------

function Aux_OnLoad()
	Aux_Log("Aux v"..AuxVersion.." loaded")
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
				BidTitle,
				BidScrollFrame,
				BidQualitySort,
				BidLevelSort,
				BidDurationSort,
				BidBuyoutSort,
				BidStatusSort,
				BidBidSort,
				BidBidButton,
				BidBuyoutButton,
				BidBidPrice,
				BidBidText
		}

		Aux.tabs.sell.shownElements = {
				getglobal("Aux_Recommend_Text"),
				getglobal("Aux_RecommendPerItem_Text"),
				getglobal("Aux_RecommendPerItem_Price"),
				getglobal("Aux_RecommendPerStack_Text"),
				getglobal("Aux_RecommendPerStack_Price"),
				getglobal("Aux_Recommend_Basis_Text"),
				getglobal("Aux_RecommendItem_Tex")
		}
	end
end

-----------------------------------------

function Aux_OnAuctionHouseShow()

	AuxOptionsButtonPanel:Show()

	if AUCTIONATOR_OPEN_FIRST then
		AuctionFrameTab_OnClick(Aux.tabs.sell.index)
	end

end

-----------------------------------------

function Aux_OnAuctionHouseClosed()

	if not Aux_Scan_IsIdle() then
		Aux_Scan_Abort()
	end
	
	AuxOptionsButtonPanel:Hide()
	AuxOptionsFrame:Hide()
	AuxDescriptionFrame:Hide()
	AuxSellPanel:Hide()
    AuxBuyPanel:Hide()
	
end

-----------------------------------------

function Aux_AuctionFrameTab_OnClick(index)
	
	if not index then
		index = this:GetID()
	end
	
	if not Aux_Scan_IsIdle() then
		Aux_Scan_Abort()
	end
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
		
		PanelTemplates_SetTab(AuctionFrame, Aux.tabs.sell.index)
		
		Aux_HideElems(Aux.tabs.sell.hiddenElements)
		
		AuxSellPanel:Show()
		AuctionFrame:EnableMouse(false)
		
		Aux_OnNewAuctionUpdate()
    elseif index == Aux.tabs.buy.index then
        AuctionFrameTab_OnClick(2)
		
		PanelTemplates_SetTab(AuctionFrame, Aux.tabs.buy.index)
		
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
		
		AuxBuyPanel:Show()
		AuctionFrame:EnableMouse(false)
		
		Aux_Buy_ScrollbarUpdate()
    else
        Aux.orig.AuctionFrameTab_OnClick(index)
		lastItemPosted = nil
	end
end

-----------------------------------------

function Aux_Log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
	end
end

-----------------------------------------

function Aux_AddPanels()
	
	local sellFrame = CreateFrame("Frame", "AuxSellPanel", AuctionFrame, "AuxSellTemplate")
	sellFrame:SetParent("AuctionFrame")
	sellFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(sellFrame)
	sellFrame:Hide()
    
    local buyFrame = CreateFrame("Frame", "AuxBuyPanel", AuctionFrame, "AuxBuyTemplate")
	buyFrame:SetParent("AuctionFrame")
	buyFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
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
	
	Aux.tabs.sell.index = AuctionFrame.numTabs + 1
    Aux.tabs.buy.index = AuctionFrame.numTabs + 2

	local sellTabName = "AuctionFrameTab"..Aux.tabs.sell.index
    local buyTabName = "AuctionFrameTab"..Aux.tabs.buy.index

	local sellTab = CreateFrame("Button", sellTabName, AuctionFrame, "AuctionTabTemplate")
    local buyTab = CreateFrame("Button", buyTabName, AuctionFrame, "AuctionTabTemplate")

	setglobal(sellTabName, sellTab)
    setglobal(buyTabName, buyTab)
    
	sellTab:SetID(Aux.tabs.sell.index)
	sellTab:SetText("Sell")
	sellTab:SetPoint("LEFT", getglobal("AuctionFrameTab"..AuctionFrame.numTabs), "RIGHT", -8, 0)
    
    buyTab:SetID(Aux.tabs.buy.index)
	buyTab:SetText("Buy")
	buyTab:SetPoint("LEFT", getglobal("AuctionFrameTab"..Aux.tabs.sell.index), "RIGHT", -8, 0)
	
	PanelTemplates_SetNumTabs(AuctionFrame, Aux.tabs.buy.index)
    PanelTemplates_EnableTab(AuctionFrame, Aux.tabs.sell.index)
	PanelTemplates_EnableTab(AuctionFrame, Aux.tabs.buy.index)
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

function Aux_AddToSet(set, key)
    set[key] = true
end

function Aux_RemoveFromSet(set, key)
    set[key] = nil
end

function Aux_SetContains(set, key)
    return set[key] ~= nil
end

function Aux_SetSize(set)
    local size = 0
	for _,_ in pairs(set) do
		size = size + 1
	end
	return size
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

function Aux_BrowseButton_OnMouseDown()
	if arg1 == "RightButton" and AUCTIONATOR_INSTANT_BUYOUT then
		local index = this:GetID() + FauxScrollFrame_GetOffset(BrowseScrollFrame)
	
		SetSelectedAuctionItem("list", index)
		
		local _, _, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", index)
		if buyoutPrice > 0 then
			PlaceAuctionBid("list", index, buyoutPrice)
		end
		
		AuctionFrameBrowse_Update()
	end
end

-----------------------------------------

function Aux_ContainerFrameItemButton_OnClick(button)
	
	if button == "LeftButton"
			and IsShiftKeyDown()
			and not ChatFrameEditBox:IsVisible()
			and (PanelTemplates_GetSelectedTab(AuctionFrame) == 1 or PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index)
	then
		local itemLink = GetContainerItemLink(this:GetParent():GetID(), this:GetID())
		if itemLink then
		local itemName = string.gsub(itemLink, "^.-%[(.*)%].*", "%1")
			if PanelTemplates_GetSelectedTab(AuctionFrame) == 1 then
				BrowseName:SetText(itemName)
			elseif PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index then
				AuxBuySearchBox:SetText(itemName)
			end
		end
	else
		Aux.orig.ContainerFrameItemButton_OnClick(button)

		if AUCTIONATOR_ENABLE_ALT and AuctionFrame:IsShown() and IsAltKeyDown() and button == "LeftButton" then
		
			ClickAuctionSellItemButton()
			ClearCursor()
			
			if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Aux.tabs.sell.index then
				AuctionFrameTab_OnClick(Aux.tabs.sell.index)
			end
		end
	end
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