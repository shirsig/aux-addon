local sellTabElements = {}
local defaultAuctionTabElements = {}
local defaultBidsTabElements = {}

AUCTIONATOR_ENABLE_ALT = true
AUCTIONATOR_OPEN_FIRST = false
AUCTIONATOR_INSTANT_BUYOUT = false

auctionatorEntries = {}

-- global settings
Auctionator = {
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

local Auctionator_Orig_AuctionFrameBrowse_Update
local Auctionator_Orig_AuctionFrameBrowse_Scan
local Auctionator_Orig_AuctionFrameTab_OnClick
local Auctionator_Orig_ContainerFrameItemButton_OnClick
local Auctionator_Orig_AuctionFrameAuctions_Update
local Auctionator_Orig_AuctionsCreateAuctionButton_OnClick

local selectedAuctionatorEntry

local currentAuctionItemName = nil
local currentAuctionItemTexture = nil
local currentAuctionStackSize = nil

local lastBuyoutPrice = 1
local lastItemPosted = nil

-----------------------------------------

local processScanResults, relevel, undercut
local ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Auctionator_EventHandler()

	if event == "ADDON_LOADED"				then	Auctionator_OnAddonLoaded() 		end
	if event == "AUCTION_OWNED_LIST_UPDATE"	then	Auctionator_OnAuctionOwnedUpdate() 	end
	if event == "AUCTION_HOUSE_SHOW"		then	Auctionator_OnAuctionHouseShow() 	end
	if event == "AUCTION_HOUSE_CLOSED"		then	Auctionator_OnAuctionHouseClosed() 	end

end

-----------------------------------------

function Auctionator_AddPanels()
	
	local sellFrame = CreateFrame("Frame", "Auctionator_Sell_Panel", AuctionFrame, "Auctionator_Sell_Template")
	sellFrame:SetParent("AuctionFrame")
	sellFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT", 210, 0)
	relevel(sellFrame)
	sellFrame:Hide()
    
    local buyFrame = CreateFrame("Frame", "Auctionator_Buy_Panel", AuctionFrame, "Auctionator_Buy_Template")
	buyFrame:SetParent("AuctionFrame")
	buyFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT", 210, 0)
	relevel(buyFrame)
	buyFrame:Hide()
	
	local optionsFrame = CreateFrame("Frame", "AuctionatorOptionsButtonPanel", AuctionFrame, "AuctionatorOptionsButtonTemplate")
	optionsFrame:SetParent("AuctionFrame")
	optionsFrame:SetPoint("TOPLEFT", "AuctionFrame", "TOPLEFT", 210, 0)
	relevel(optionsFrame)
	optionsFrame:Hide()
end

-----------------------------------------

function Auctionator_OnAddonLoaded()

	if string.lower(arg1) == "blizzard_auctionui" then
		Auctionator_AddTabs()
		Auctionator_AddPanels()
		
		Auctionator_SetupHookFunctions()
		
		defaultAuctionTabElements[1] = AuctionsTitle
		defaultAuctionTabElements[2] = AuctionsScrollFrame
		defaultAuctionTabElements[3] = AuctionsButton1
		defaultAuctionTabElements[4] = AuctionsButton2
		defaultAuctionTabElements[5] = AuctionsButton3
		defaultAuctionTabElements[6] = AuctionsButton4
		defaultAuctionTabElements[7] = AuctionsButton5
		defaultAuctionTabElements[8] = AuctionsButton6
		defaultAuctionTabElements[9] = AuctionsButton7
		defaultAuctionTabElements[10] = AuctionsButton8
		defaultAuctionTabElements[11] = AuctionsButton9
		defaultAuctionTabElements[12] = AuctionsQualitySort
		defaultAuctionTabElements[13] = AuctionsDurationSort
		defaultAuctionTabElements[14] = AuctionsHighBidderSort
		defaultAuctionTabElements[15] = AuctionsBidSort
		defaultAuctionTabElements[16] = AuctionsCancelAuctionButton
		--defaultAuctionTabElements[17] = AuctionFrameAuctions
		--defaultAuctionTabElements[18] = AuctionFrame
        
		defaultBidsTabElements[1] = BidTitle
		defaultBidsTabElements[2] = BidScrollFrame
        defaultBidsTabElements[3] = BidQualitySort
		defaultBidsTabElements[4] = BidLevelSort
		defaultBidsTabElements[5] = BidDurationSort
		defaultBidsTabElements[6] = BidBuyoutSort
		defaultBidsTabElements[7] = BidStatusSort
		defaultBidsTabElements[8] = BidBidSort
		defaultBidsTabElements[9] = BidBidButton
		defaultBidsTabElements[10] = BidBuyoutButton
		defaultBidsTabElements[11] = BidBidPrice
		defaultBidsTabElements[12] = BidBidText

		sellTabElements[1] = getglobal("Auctionator_Recommend_Text")
		sellTabElements[2] = getglobal("Auctionator_RecommendPerItem_Text")
		sellTabElements[3] = getglobal("Auctionator_RecommendPerItem_Price")
		sellTabElements[4] = getglobal("Auctionator_RecommendPerStack_Text")
		sellTabElements[5] = getglobal("Auctionator_RecommendPerStack_Price")
		sellTabElements[6] = getglobal("Auctionator_Recommend_Basis_Text")
		sellTabElements[7] = getglobal("Auctionator_RecommendItem_Tex")
	end
end

-----------------------------------------

function Auctionator_AuctionFrameTab_OnClick(index)
	
	if not index then
		index = this:GetID()
	end
	
	Auctionator_Scan_Abort()
	Auctionator_Sell_Panel:Hide()
    Auctionator_Buy_Panel:Hide()
	
	if index == 3 then		
		Auctionator_ShowElems(defaultAuctionTabElements)
	end
	
	if index == Auctionator.tabs.sell.index then
		AuctionFrameTab_OnClick(3)
		
		PanelTemplates_SetTab(AuctionFrame, Auctionator.tabs.sell.index)
		
		Auctionator_HideElems(defaultAuctionTabElements)
		
		Auctionator_Sell_Panel:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_OnNewAuctionUpdate()
    elseif index == Auctionator.tabs.buy.index then
        AuctionFrameTab_OnClick(2)
		
		PanelTemplates_SetTab(AuctionFrame, Auctionator.tabs.buy.index)
		
		Auctionator_HideElems(defaultBidsTabElements)
		
		Auctionator_Buy_Panel:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_Buy_ScrollbarUpdate()
    else
        Auctionator_Orig_AuctionFrameTab_OnClick(index)
		lastItemPosted = nil
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
		Auctionator_Orig_ContainerFrameItemButton_OnClick(button)

		if AUCTIONATOR_ENABLE_ALT and AuctionFrame:IsShown() and IsAltKeyDown() and button == "LeftButton" then
		
			ClickAuctionSellItemButton()
			ClearCursor()
			
			if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Auctionator.tabs.sell.index then
				AuctionFrameTab_OnClick(Auctionator.tabs.sell.index)
			end
		end
	end
end

-----------------------------------------

function Auctionator_AuctionFrameAuctions_Update()
	
	Auctionator_Orig_AuctionFrameAuctions_Update()

	if PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.sell.index and AuctionFrame:IsShown() then
		Auctionator_HideElems(defaultAuctionTabElements)
	end	
end

-----------------------------------------
-- Intercept the Create Auction click so
-- that we can note the auction values
-----------------------------------------

function Auctionator_AuctionsCreateAuctionButton_OnClick()
	
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.sell.index  and AuctionFrame:IsShown() then
		
		lastBuyoutPrice = MoneyInputFrame_GetCopper(BuyoutPrice)
		lastItemPosted = currentAuctionItemName

	end
	
	Auctionator_Orig_AuctionsCreateAuctionButton_OnClick()

end

-----------------------------------------

function Auctionator_OnAuctionOwnedUpdate()

	if lastItemPosted then
	
		Auctionator_Recommend_Text:SetText("Auction Created for "..lastItemPosted)

		MoneyFrame_Update("Auctionator_RecommendPerStack_Price", lastBuyoutPrice)

		Auctionator_RecommendPerStack_Price:Show()
		Auctionator_RecommendPerItem_Price:Hide()
		Auctionator_RecommendPerItem_Text:Hide()
		Auctionator_Recommend_Basis_Text:Hide()
	end
	
end

-----------------------------------------

function Auctionator_AuctionSellItemButton_OnEvent()
	Auctionator_Orig_AuctionSellItemButton_OnEvent()
	Auctionator_OnNewAuctionUpdate()
end

-----------------------------------------

function Auctionator_BrowseButton_OnClick(button)
	if arg1 == "LeftButton" then
		Auctionator_Orig_BrowseButton_OnClick(button)
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

function Auctionator_SetupHookFunctions()
	
	Auctionator_Orig_BrowseButton_OnClick = BrowseButton_OnClick
	BrowseButton_OnClick = Auctionator_BrowseButton_OnClick
	
	BrowseButton1:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton1:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton2:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton2:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton3:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton3:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton4:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton4:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton5:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton5:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton6:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton6:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton7:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton7:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)
	BrowseButton8:RegisterForClicks("LeftButtonUp", "RightButtonDown")
	BrowseButton8:SetScript("OnMouseDown", Auctionator_BrowseButton_OnMouseDown)

	Auctionator_Orig_AuctionSellItemButton_OnEvent = AuctionSellItemButton_OnEvent
	AuctionSellItemButton_OnEvent = Auctionator_AuctionSellItemButton_OnEvent
	
	Auctionator_Orig_AuctionFrameTab_OnClick = AuctionFrameTab_OnClick
	AuctionFrameTab_OnClick = Auctionator_AuctionFrameTab_OnClick
	
	Auctionator_Orig_ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
	ContainerFrameItemButton_OnClick = Auctionator_ContainerFrameItemButton_OnClick
	
	Auctionator_Orig_AuctionFrameAuctions_Update = AuctionFrameAuctions_Update
	AuctionFrameAuctions_Update = Auctionator_AuctionFrameAuctions_Update
	
	Auctionator_Orig_AuctionsCreateAuctionButton_OnClick = AuctionsCreateAuctionButton_OnClick
	AuctionsCreateAuctionButton_OnClick = Auctionator_AuctionsCreateAuctionButton_OnClick
	
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

function Auctionator_SetMessage(msg)
	Auctionator_HideElems(sellTabElements)
	AuctionatorMessage:SetText(msg)
	AuctionatorMessage:Show()
	AuctionatorBuyMessage:SetText(msg) -- TODO doesn't belong here
	AuctionatorBuyMessage:Show()
end

-----------------------------------------

local bestPriceOurStackSize;

-----------------------------------------

function Auctionator_SelectAuctionatorEntry()
	
	if not currentAuctionItemName or not auctionatorEntries[currentAuctionItemName] then
		selectedAuctionatorEntry = nil
	else
		local bestPrice	= {} -- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,auctionatorEntry in ipairs(auctionatorEntries[currentAuctionItemName]) do
			if not bestPrice[auctionatorEntry.stackSize] or bestPrice[auctionatorEntry.stackSize].itemPrice >= auctionatorEntry.itemPrice then
				bestPrice[auctionatorEntry.stackSize] = auctionatorEntry
			end
		
			if not absoluteBest or absoluteBest.itemPrice > auctionatorEntry.itemPrice then
				absoluteBest = auctionatorEntry
			end	
		end
		
		selectedAuctionatorEntry = absoluteBest

		if bestPrice[currentAuctionItemStackSize] then
			selectedAuctionatorEntry = bestPrice[currentAuctionItemStackSize]
			bestPriceOurStackSize = bestPrice[currentAuctionItemStackSize]
		end
	end
end

-----------------------------------------

function Auctionator_UpdateRecommendation()

	if not currentAuctionItemName then
		AuctionatorRefreshButton:Disable()
		Auctionator_SetMessage("Drag an item to the Auction Item area\n\nto see recommended pricing information")
	else
		AuctionatorRefreshButton:Enable()	
		
		if selectedAuctionatorEntry then
			local newBuyoutPrice = selectedAuctionatorEntry.itemPrice * currentAuctionItemStackSize

			if selectedAuctionatorEntry.numYours < selectedAuctionatorEntry.count then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95 
			
			AuctionatorMessage:Hide()	
			Auctionator_ShowElems(sellTabElements)
			
			Auctionator_Recommend_Text:SetText("Recommended Buyout Price")
			Auctionator_RecommendPerStack_Text:SetText("for your stack of "..currentAuctionItemStackSize)
			
			if currentAuctionItemTexture then
				Auctionator_RecommendItem_Tex:SetNormalTexture(currentAuctionItemTexture)
				if currentAuctionItemStackSize > 1 then
					Auctionator_RecommendItem_TexCount:SetText(currentAuctionItemStackSize)
					Auctionator_RecommendItem_TexCount:Show()
				else
					Auctionator_RecommendItem_TexCount:Hide()
				end
			else
				Auctionator_RecommendItem_Tex:Hide()
			end
			
			MoneyFrame_Update("Auctionator_RecommendPerItem_Price",  Auctionator_Round(newBuyoutPrice / currentAuctionItemStackSize))
			MoneyFrame_Update("Auctionator_RecommendPerStack_Price", Auctionator_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(BuyoutPrice, newBuyoutPrice)
			MoneyInputFrame_SetCopper(StartPrice, newStartPrice)
			
			if selectedAuctionatorEntry.stackSize == auctionatorEntries[currentAuctionItemName][1].stackSize and selectedAuctionatorEntry.buyoutPrice == auctionatorEntries[currentAuctionItemName][1].buyoutPrice then
				Auctionator_Recommend_Basis_Text:SetText("(based on cheapest)")
			elseif bestPriceOurStackSize and selectedAuctionatorEntry.stackSize == bestPriceOurStackSize.stackSize and selectedAuctionatorEntry.buyoutPrice == bestPriceOurStackSize.buyoutPrice then
				Auctionator_Recommend_Basis_Text:SetText("(based on cheapest stack of the same size)")
			else
				Auctionator_Recommend_Basis_Text:SetText("(based on auction selected below)")
			end
		elseif auctionatorEntries[currentAuctionItemName] then
			Auctionator_SetMessage("No auctions were found for \n\n"..currentAuctionItemName)
		else 
			Auctionator_HideElems(sellTabElements)
		end
	end
	
	Auctionator_ScrollbarUpdate()
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

	AuctionatorOptionsButtonPanel:Hide()
	AuctionatorOptionsFrame:Hide()
	AuctionatorDescriptionFrame:Hide()
	Auctionator_Sell_Panel:Hide()
    Auctionator_Buy_Panel:Hide()
	
end

-----------------------------------------

function Auctionator_OnNewAuctionUpdate()

	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Auctionator.tabs.sell.index then
		return
	end
	
	Auctionator_Scan_Abort()
	
	currentAuctionItemName, currentAuctionItemTexture, currentAuctionItemStackSize = GetAuctionSellItemInfo()
	
	if currentAuctionItemName and not auctionatorEntries[currentAuctionItemName] then
		Auctionator_RefreshEntries()
	end
	
	Auctionator_SelectAuctionatorEntry()
	Auctionator_UpdateRecommendation()
end

-----------------------------------------

function Auctionator_RefreshEntries()
	auctionatorEntries[currentAuctionItemName] = nil
	selectedAuctionatorEntry = nil
	
	local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(currentAuctionItemName)

	local currentAuctionClass		= ItemType2AuctionClass(sType)
	local currentAuctionSubclass	= nil -- SubType2AuctionSubclass(currentAuctionClass, sSubType)
	
	Auctionator_Scan_Start{
			query = Auctionator_Scan_CreateQuery{
					name = currentAuctionItemName,
					classIndex = currentAuctionClass,
					subclassIndex = currentAuctionSubclass
			},
			onComplete = function(data)
				processScanResults(data, currentAuctionItemName)
				Auctionator_SelectAuctionatorEntry()
				Auctionator_UpdateRecommendation()
			end
	}	
end
	
-----------------------------------------

function Auctionator_ScrollbarUpdate()

	local line -- 1 through 12 of our window to scroll
	local dataOffset -- an index into our data calculated from the scroll offset
	
	local numrows
	if not currentAuctionItemName or not auctionatorEntries[currentAuctionItemName] then
		numrows = 0
	else
		numrows = getn(auctionatorEntries[currentAuctionItemName])
	end
	
	FauxScrollFrame_Update(AuctionatorScrollFrame, numrows, 12, 16);

	for line = 1,12 do

		dataOffset = line + FauxScrollFrame_GetOffset(AuctionatorScrollFrame)
		
		local lineEntry = getglobal("AuctionatorEntry"..line)
		
		if numrows <= 12 then
			lineEntry:SetWidth(603)
		else
			lineEntry:SetWidth(585)
		end
		
		lineEntry:SetID(dataOffset)
		
		if currentAuctionItemName and dataOffset <= numrows and auctionatorEntries[currentAuctionItemName] then
			
			local auctionatorEntry = auctionatorEntries[currentAuctionItemName][dataOffset]

			local lineEntry_avail	= getglobal("AuctionatorEntry"..line.."_Availability")
			local lineEntry_comm	= getglobal("AuctionatorEntry"..line.."_Comment")
			local lineEntry_stack	= getglobal("AuctionatorEntry"..line.."_StackPrice")

			if selectedAuctionatorEntry and auctionatorEntry.itemPrice == selectedAuctionatorEntry.itemPrice and auctionatorEntry.stackSize == selectedAuctionatorEntry.stackSize then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			if auctionatorEntry.stackSize == currentAuctionItemStackSize then
				lineEntry_avail:SetTextColor(0.2, 0.9, 0.2)
			else
				lineEntry_avail:SetTextColor(1.0, 1.0, 1.0)
			end

			if auctionatorEntry.numYours == 0 then
				lineEntry_comm:SetText("")
			elseif
				auctionatorEntry.numYours == auctionatorEntry.count then
				lineEntry_comm:SetText("yours")
			else
				lineEntry_comm:SetText("yours: "..auctionatorEntry.numYours)
			end
						
			local tx = string.format("%i %s of %i", auctionatorEntry.count, Auctionator_PluralizeIf("stack", auctionatorEntry.count), auctionatorEntry.stackSize)
			lineEntry_avail:SetText(tx)

			MoneyFrame_Update("AuctionatorEntry"..line.."_UnitPrice", Auctionator_Round(auctionatorEntry.buyoutPrice/auctionatorEntry.stackSize))
			MoneyFrame_Update("AuctionatorEntry"..line.."_TotalPrice", Auctionator_Round(auctionatorEntry.buyoutPrice))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
end

-----------------------------------------

function Auctionator_EntryOnClick()
	local entryIndex = this:GetID()

	selectedAuctionatorEntry = auctionatorEntries[currentAuctionItemName][entryIndex]

	Auctionator_UpdateRecommendation()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

function Auctionator_RefreshButtonOnClick()
	Auctionator_Scan_Abort()
	Auctionator_RefreshEntries()
	Auctionator_SelectAuctionatorEntry()
	Auctionator_UpdateRecommendation()
end

-----------------------------------------

function AuctionatorMoneyFrame_OnLoad()
	this.small = 1
	SmallMoneyFrame_OnLoad()
	MoneyFrame_SetType("AUCTION")
end

--[[***************************************************************

	All function below here are local utility functions.
	These should be declared local at the top of this file.

--*****************************************************************]]

function processScanResults(rawData, auctionItemName)

	auctionatorEntries[auctionItemName] = {}
	
	----- Condense the scan rawData into a table that has only a single entry per stacksize/price combo
	
	local condData = {}

	for _,rawDatum in ipairs(rawData) do
		if auctionItemName == rawDatum.name and rawDatum.buyoutPrice > 0 then
			local key = "_"..rawDatum.stackSize.."_"..rawDatum.buyoutPrice
					
			if condData[key] then
				condData[key].count = condData[key].count + 1
			else			
				condData[key] = {
						stackSize 	= rawDatum.stackSize,
						buyoutPrice	= rawDatum.buyoutPrice,
						itemPrice		= rawDatum.buyoutPrice / rawDatum.stackSize,
						count			= 1,
						numYours		= rawDatum.owner == UnitName("player") and 1 or 0
				}
			end
		end
	end

	----- create a table of these entries sorted by itemPrice
	
	local n = 1
	for _,condDatum in pairs(condData) do
		auctionatorEntries[auctionItemName][n] = condDatum
		n = n + 1
	end
	
	table.sort(auctionatorEntries[auctionItemName], function(a,b) return a.itemPrice < b.itemPrice end)
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

function undercut(price)
	return math.max(0, price - 1)
end

-----------------------------------------

function ItemType2AuctionClass(itemType)
	local itemClasses = { GetAuctionItemClasses() }
	if itemClasses then
		if getn(itemClasses) > 0 then
		local itemClass
			for x, itemClass in pairs(itemClasses) do
				if itemClass == itemType then
					return x
				end
			end
		end
	else Auctionator_Log("Can't GetAuctionItemClasses") end
end

-----------------------------------------

function SubType2AuctionSubclass(auctionClass, itemSubtype)
	local itemClasses = { GetAuctionItemSubClasses(auctionClass.number) };
	if itemClasses.n > 0 then
	local itemClass
		for x, itemClass in pairs(itemClasses) do
			if itemClass == itemSubtype then
				return x
			end
		end
	end
end