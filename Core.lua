AuctionatorVersion = "1.2.0-Vanilla"
AuctionatorAuthors = "Zirco (Original); Nimeral (Backport); shirsig, Zerf (Update)"

AUCTIONATOR_ENABLE_ALT = true
AUCTIONATOR_OPEN_FIRST = false
AUCTIONATOR_INSTANT_BUYOUT = false

-- global settings
Auctionator = {
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
    },
	qualityColor = function(code)
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
}

local relevel

function Auctionator_OnLoad()
	Auctionator_Log("Auctionator v"..AuctionatorVersion.." loaded")
	Auctionator.loaded = true
end

-----------------------------------------

function Auctionator_OnEvent()
	if event == "VARIABLES_LOADED" then
		Auctionator_OnLoad()
	elseif event == "ADDON_LOADED" then
		Auctionator_OnAddonLoaded()
	elseif event == "AUCTION_HOUSE_SHOW" then
		Auctionator_OnAuctionHouseShow()
	elseif event == "AUCTION_HOUSE_CLOSED" then
		Auctionator_OnAuctionHouseClosed()
	end
end

-----------------------------------------

function Auctionator_OnAddonLoaded()

	if string.lower(arg1) == "blizzard_auctionui" then
		Auctionator_AddTabs()
		Auctionator_AddPanels()
		
		Auctionator_SetupHookFunctions()
		
		Auctionator.tabs.sell.hiddenElements = {
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
        
		Auctionator.tabs.buy.hiddenElements = {
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

		Auctionator.tabs.sell.shownElements = {
				getglobal("Auctionator_Recommend_Text"),
				getglobal("Auctionator_RecommendPerItem_Text"),
				getglobal("Auctionator_RecommendPerItem_Price"),
				getglobal("Auctionator_RecommendPerStack_Text"),
				getglobal("Auctionator_RecommendPerStack_Price"),
				getglobal("Auctionator_Recommend_Basis_Text"),
				getglobal("Auctionator_RecommendItem_Tex")
		}
	end
end

-----------------------------------------

function Auctionator_OnAuctionHouseShow()

	AuctionatorOptionsButtonPanel:Show()

	if AUCTIONATOR_OPEN_FIRST then
		AuctionFrameTab_OnClick(Auctionator.tabs.sell.index)
	end

end

-----------------------------------------

function Auctionator_OnAuctionHouseClosed()

	if not Auctionator_Scan_IsIdle() then
		Auctionator_Scan_Abort()
	end
	
	AuctionatorOptionsButtonPanel:Hide()
	AuctionatorOptionsFrame:Hide()
	AuctionatorDescriptionFrame:Hide()
	AuctionatorSellPanel:Hide()
    AuctionatorBuyPanel:Hide()
	
end

-----------------------------------------

function Auctionator_AuctionFrameTab_OnClick(index)
	
	if not index then
		index = this:GetID()
	end
	
	if not Auctionator_Scan_IsIdle() then
		Auctionator_Scan_Abort()
	end
	AuctionatorSellPanel:Hide()
    AuctionatorBuyPanel:Hide()

	if index == 2 then		
		Auctionator_ShowElems(Auctionator.tabs.buy.hiddenElements)
	end
	
	if index == 3 then		
		Auctionator_ShowElems(Auctionator.tabs.sell.hiddenElements)
	end
	
	if index == Auctionator.tabs.sell.index then
		AuctionFrameTab_OnClick(3)
		
		PanelTemplates_SetTab(AuctionFrame, Auctionator.tabs.sell.index)
		
		Auctionator_HideElems(Auctionator.tabs.sell.hiddenElements)
		
		AuctionatorSellPanel:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_OnNewAuctionUpdate()
    elseif index == Auctionator.tabs.buy.index then
        AuctionFrameTab_OnClick(2)
		
		PanelTemplates_SetTab(AuctionFrame, Auctionator.tabs.buy.index)
		
		Auctionator_HideElems(Auctionator.tabs.buy.hiddenElements)
		
		AuctionatorBuyPanel:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_Buy_ScrollbarUpdate()
    else
        Auctionator.orig.AuctionFrameTab_OnClick(index)
		lastItemPosted = nil
	end
end

-----------------------------------------

function Auctionator_Log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
	end
end

-----------------------------------------

function Auctionator_AddPanels()
	
	local sellFrame = CreateFrame("Frame", "AuctionatorSellPanel", AuctionFrame, "AuctionatorSellTemplate")
	sellFrame:SetParent("AuctionFrame")
	sellFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(sellFrame)
	sellFrame:Hide()
    
    local buyFrame = CreateFrame("Frame", "AuctionatorBuyPanel", AuctionFrame, "AuctionatorBuyTemplate")
	buyFrame:SetParent("AuctionFrame")
	buyFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(buyFrame)
	buyFrame:Hide()
	
	local optionsFrame = CreateFrame("Frame", "AuctionatorOptionsButtonPanel", AuctionFrame, "AuctionatorOptionsButtonTemplate")
	optionsFrame:SetParent("AuctionFrame")
	optionsFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT")
	relevel(optionsFrame)
	optionsFrame:Hide()
end

-----------------------------------------

function Auctionator_AddTabs()
	
	Auctionator.tabs.sell.index = AuctionFrame.numTabs + 1
    Auctionator.tabs.buy.index = AuctionFrame.numTabs + 2

	local sellTabName = "AuctionFrameTab"..Auctionator.tabs.sell.index
    local buyTabName = "AuctionFrameTab"..Auctionator.tabs.buy.index

	local sellTab = CreateFrame("Button", sellTabName, AuctionFrame, "AuctionTabTemplate")
    local buyTab = CreateFrame("Button", buyTabName, AuctionFrame, "AuctionTabTemplate")

	setglobal(sellTabName, sellTab)
    setglobal(buyTabName, buyTab)
    
	sellTab:SetID(Auctionator.tabs.sell.index)
	sellTab:SetText("Sell")
	sellTab:SetPoint("LEFT", getglobal("AuctionFrameTab"..AuctionFrame.numTabs), "RIGHT", -8, 0)
    
    buyTab:SetID(Auctionator.tabs.buy.index)
	buyTab:SetText("Buy")
	buyTab:SetPoint("LEFT", getglobal("AuctionFrameTab"..Auctionator.tabs.sell.index), "RIGHT", -8, 0)
	
	PanelTemplates_SetNumTabs(AuctionFrame, Auctionator.tabs.buy.index)
    PanelTemplates_EnableTab(AuctionFrame, Auctionator.tabs.sell.index)
	PanelTemplates_EnableTab(AuctionFrame, Auctionator.tabs.buy.index)
end

-----------------------------------------

function Auctionator_HideElems(tt)

	if not tt then
		return;
	end
	
	for i,x in ipairs(tt) do
		x:Hide()
	end
end

-----------------------------------------

function Auctionator_ShowElems(tt)

	for i,x in ipairs(tt) do
		x:Show()
	end
end

-----------------------------------------

function Auctionator_PluralizeIf(word, count)

	if count and count == 1 then
		return word
	else
		return word.."s"
	end
end

-----------------------------------------

function Auctionator_Round(v)
	return math.floor(v + 0.5)
end

-----------------------------------------

function Auctionator_AddToSet(set, key)
    set[key] = true
end

function Auctionator_RemoveFromSet(set, key)
    set[key] = nil
end

function Auctionator_SetContains(set, key)
    return set[key] ~= nil
end

function Auctionator_SetSize(set)
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

function Auctionator_BrowseButton_OnClick(button)
	if arg1 == "LeftButton" then -- because we additionally registered right clicks we only let left ones pass here
		Auctionator.orig.BrowseButton_OnClick(button)
	end
end

-----------------------------------------

function Auctionator_BrowseButton_OnMouseDown()
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

function Auctionator_ContainerFrameItemButton_OnClick(button)
	
	if button == "LeftButton"
			and IsShiftKeyDown()
			and not ChatFrameEditBox:IsVisible()
			and (PanelTemplates_GetSelectedTab(AuctionFrame) == 1 or PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.buy.index)
	then
		local itemLink = GetContainerItemLink(this:GetParent():GetID(), this:GetID())
		if itemLink then
		local itemName = string.gsub(itemLink, "^.-%[(.*)%].*", "%1")
			if PanelTemplates_GetSelectedTab(AuctionFrame) == 1 then
				BrowseName:SetText(itemName)
			elseif PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.buy.index then
				AuctionatorBuySearchBox:SetText(itemName)
			end
		end
	else
		Auctionator.orig.ContainerFrameItemButton_OnClick(button)

		if AUCTIONATOR_ENABLE_ALT and AuctionFrame:IsShown() and IsAltKeyDown() and button == "LeftButton" then
		
			ClickAuctionSellItemButton()
			ClearCursor()
			
			if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Auctionator.tabs.sell.index then
				AuctionFrameTab_OnClick(Auctionator.tabs.sell.index)
			end
		end
	end
end