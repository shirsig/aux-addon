local AuctionatorLoaded = false

local recommendationElements = {}
local defaultAuctionTabElements = {}
local defaultBrowseTabElements = {}

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

local timeOfLastUpdate = GetTime()

-----------------------------------------

local Auctionator_Orig_AuctionFrameBrowse_Update
local Auctionator_Orig_AuctionFrameBrowse_Scan
local Auctionator_Orig_AuctionFrameTab_OnClick
local Auctionator_Orig_ContainerFrameItemButton_OnClick
local Auctionator_Orig_AuctionFrameAuctions_Update
local Auctionator_Orig_AuctionsCreateAuctionButton_OnClick

local forceRefresh = false

-- local searchResults = {}
local selectedAuctionatorEntry

local currentAuctionItemName = nil
local currentAuctionItemTexture = nil
local currentAuctionStackSize = nil

local lastBuyoutPrice = 1
local lastItemPosted = nil

-----------------------------------------

local processScanResults, relevel, log, pluralizeIf, round, undercut, roundPriceDown
local val2gsc, priceToString, ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Auctionator_EventHandler()

	if event == "VARIABLES_LOADED"			then	Auctionator_OnLoad() 				end
	if event == "ADDON_LOADED"				then	Auctionator_OnAddonLoaded() 		end
	if event == "AUCTION_ITEM_LIST_UPDATE"	then	Auctionator_OnAuctionUpdate() 		end
	if event == "AUCTION_OWNED_LIST_UPDATE"	then	Auctionator_OnAuctionOwnedUpdate() 	end
	if event == "AUCTION_HOUSE_SHOW"		then	Auctionator_OnAuctionHouseShow() 	end
	if event == "AUCTION_HOUSE_CLOSED"		then	Auctionator_OnAuctionHouseClosed() 	end
	if event == "NEW_AUCTION_UPDATE"		then	Auctionator_OnNewAuctionUpdate()	end

end

-----------------------------------------

function Auctionator_OnLoad()

	log("Auctionator Loaded")

	AuctionatorLoaded = true

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
		
		defaultAuctionTabElements[1]  = AuctionsScrollFrame
		defaultAuctionTabElements[2]  = AuctionsButton1
		defaultAuctionTabElements[3]  = AuctionsButton2
		defaultAuctionTabElements[4]  = AuctionsButton3
		defaultAuctionTabElements[5]  = AuctionsButton4
		defaultAuctionTabElements[6]  = AuctionsButton5
		defaultAuctionTabElements[7]  = AuctionsButton6
		defaultAuctionTabElements[8]  = AuctionsButton7
		defaultAuctionTabElements[9]  = AuctionsButton8
		defaultAuctionTabElements[10] = AuctionsButton9
		defaultAuctionTabElements[11] = AuctionsQualitySort
		defaultAuctionTabElements[12] = AuctionsDurationSort
		defaultAuctionTabElements[13] = AuctionsHighBidderSort
		defaultAuctionTabElements[14] = AuctionsBidSort
		defaultAuctionTabElements[15] = AuctionsCancelAuctionButton
		--defaultAuctionTabElements[16] = AuctionFrameAuctions
		--defaultAuctionTabElements[16] = AuctionFrame
        
        defaultBrowseTabElements[1] = AuctionFrameBrowse

		recommendationElements[1] = getglobal("Auctionator_Recommend_Text")
		recommendationElements[2] = getglobal("Auctionator_RecommendPerItem_Text")
		recommendationElements[3] = getglobal("Auctionator_RecommendPerItem_Price")
		recommendationElements[4] = getglobal("Auctionator_RecommendPerStack_Text")
		recommendationElements[5] = getglobal("Auctionator_RecommendPerStack_Price")
		recommendationElements[6] = getglobal("Auctionator_Recommend_Basis_Text")
		recommendationElements[7] = getglobal("Auctionator_RecommendItem_Tex")
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
        AuctionFrameTab_OnClick(1)
		
		PanelTemplates_SetTab(AuctionFrame, Auctionator.tabs.buy.index)
		
		Auctionator_HideElems(defaultBrowseTabElements)
		
		Auctionator_Buy_Panel:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_OnNewAuctionUpdate()
    else
        Auctionator_Orig_AuctionFrameTab_OnClick(index)
		lastItemPosted = nil
	end
end

-----------------------------------------

function Auctionator_ContainerFrameItemButton_OnClick(button)
	
	if (not AUCTIONATOR_ENABLE_ALT
		or not AuctionFrame:IsShown()
		or not IsAltKeyDown())
	then
		return Auctionator_Orig_ContainerFrameItemButton_OnClick(button)
	end

	ClickAuctionSellItemButton()
	ClearCursor()
	
	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Auctionator.tabs.sell.index then
		AuctionFrameTab_OnClick(Auctionator.tabs.sell.index)
	end
	
	PickupContainerItem(this:GetParent():GetID(), this:GetID())
	ClickAuctionSellItemButton()

end

-----------------------------------------

function Auctionator_AuctionFrameAuctions_Update()
	
	Auctionator_Orig_AuctionFrameAuctions_Update()

	if PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.sell.index  and	AuctionFrame:IsShown() then
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

function Auctionator_BrowseButton_OnClick(button)
	if arg1 == "LeftButton" then
		Auctionator_Orig_BrowseButton_OnClick(button)
	end
end

function Auctionator_BrowseButton_OnMouseDown()
	if arg1 == "RightButton" and AUCTIONATOR_INSTANT_BUYOUT then
		local index = this:GetID() + FauxScrollFrame_GetOffset(BrowseScrollFrame)
	
		SetSelectedAuctionItem("list", index)
		
		local _, _, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", index)
		PlaceAuctionBid("list", index, buyoutPrice)
		
		AuctionFrameBrowse_Update()
	end
end

-----------------------------------------

function Auctionator_SetupHookFunctions()
	
	-- Auctionator_Orig_AuctionFrameBrowse_Update = AuctionFrameBrowse_Update
	-- AuctionFrameBrowse_Update = Auctionator_AuctionFrameBrowse_Update
	
	-- Auctionator_Orig_AuctionFrameBrowse_Scan = AuctionFrameBrowse_Scan
	-- AuctionFrameBrowse_Scan = Auctionator_AuctionFrameBrowse_Scan
	
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

	local sellFrameName = "AuctionFrameTab"..Auctionator.tabs.sell.index
    local buyFrameName = "AuctionFrameTab"..Auctionator.tabs.buy.index

	local sellFrame = CreateFrame("Button", sellFrameName, AuctionFrame, "AuctionTabTemplate")
    local buyFrame = CreateFrame("Button", buyFrameName, AuctionFrame, "AuctionTabTemplate")

	setglobal(sellFrameName, sellFrame)
    setglobal(buyFrameName, buyFrame)
    
	sellFrame:SetID(Auctionator.tabs.sell.index)
	sellFrame:SetText("Auctionator")
	sellFrame:SetPoint("LEFT", getglobal("AuctionFrameTab"..AuctionFrame.numTabs), "RIGHT", -8, 0)
	sellFrame:Show()
    
    buyFrame:SetID(Auctionator.tabs.buy.index)
	buyFrame:SetText("Buy")
	buyFrame:SetPoint("LEFT", getglobal("AuctionFrameTab"..Auctionator.tabs.sell.index), "RIGHT", -8, 0)
	buyFrame:Show()
	
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

function Auctionator_OnAuctionUpdate()
	if Auctionator_Scan_State_Postquery() then
		Auctionator_Scan_Process()
	end
end

-----------------------------------------

function Auctionator_SetMessage(msg)
	Auctionator_HideElems(recommendationElements)
	AuctionatorMessage:SetText(msg)
	AuctionatorMessage:Show()
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
	Auctionator_UpdateRecommendation()
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
			Auctionator_ShowElems(recommendationElements)
			
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
			
			MoneyFrame_Update("Auctionator_RecommendPerItem_Price",  round(newBuyoutPrice / currentAuctionItemStackSize))
			MoneyFrame_Update("Auctionator_RecommendPerStack_Price", round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(BuyoutPrice, newBuyoutPrice)
			MoneyInputFrame_SetCopper(StartPrice,  newStartPrice)
			
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
			Auctionator_HideElems(recommendationElements)
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
	
	if not Auctionator_Scan_State_Idle() then
		Auctionator_Scan_Abort()
	end
	
	currentAuctionItemName, currentAuctionItemTexture, currentAuctionItemStackSize = GetAuctionSellItemInfo()
	
	if currentAuctionItemName and (forceRefresh or not auctionatorEntries[currentAuctionItemName]) then

		forceRefresh = false

		auctionatorEntries[currentAuctionItemName] = nil
		selectedAuctionatorEntry = nil
		
		local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(currentAuctionItemName)
	
		local currentAuctionClass		= ItemType2AuctionClass(sType)
		local currentAuctionSubclass	= nil -- SubType2AuctionSubclass(currentAuctionClass, sSubType)
		
		Auctionator_Scan_Start(Auctionator_Scan_CreateQuery{
			name = currentAuctionItemName,
			exactMatch = true,
			classIndex = currentAuctionClass,
			subclassIndex = currentAuctionSubclass,
			onComplete = function(data)
				processScanResults(data, currentAuctionItemName)
				Auctionator_SelectAuctionatorEntry()
			end
		})		
	end
	
	Auctionator_SelectAuctionatorEntry()
end

-----------------------------------------

function Auctionator_OnUpdate()
	
	if not AuctionatorMessage then
		return
	end
	
	if Auctionator_Scan_State_Prequery() and GetTime() - timeOfLastUpdate > 0.5 then
	
		timeOfLastUpdate = GetTime()

		if CanSendAuctionQuery() then
			Auctionator_Scan_Query()
		end
	end
	
	if forceRefresh then
		Auctionator_OnNewAuctionUpdate()
	end
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
		
		if currentAuctionItemName and dataOffset <= numrows and auctionatorEntries[currentAuctionItemName][dataOffset] then
			
			local auctionatorEntry = auctionatorEntries[currentAuctionItemName][dataOffset]

			local lineEntry_avail	= getglobal("AuctionatorEntry"..line.."_Availability")
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

			-- if		auctionatorEntry.numYours == 0 then			lineEntry_comm:SetText("")
			-- elseif	auctionatorEntry.numYours == auctionatorEntry.count then	lineEntry_comm:SetText("yours")
			-- else										lineEntry_comm:SetText("yours: "..auctionatorEntry.numYours)
			-- end
						
			local tx = string.format("%i %s of %i", auctionatorEntry.count, pluralizeIf("stack", auctionatorEntry.count), auctionatorEntry.stackSize)

			MoneyFrame_Update("AuctionatorEntry"..line.."_PerItem_Price", round(auctionatorEntry.buyoutPrice/auctionatorEntry.stackSize))

			lineEntry_avail:SetText(tx)
			lineEntry_stack:SetText(priceToString(auctionatorEntry.buyoutPrice))

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
	forceRefresh = true
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

function pluralizeIf(word, count)

	if count and count == 1 then
		return word
	else
		return word.."s"
	end
end

-----------------------------------------

function round(v)
	return math.floor(v + 0.5)
end

-----------------------------------------

function log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
end

-----------------------------------------

function undercut(price)
	return math.max(0, price - 1)
end

-----------------------------------------

function val2gsc(v)
	local rv = round(v)
	
	local g = math.floor(rv/10000)
	
	rv = rv - g * 10000
	
	local s = math.floor(rv/100)
	
	rv = rv - s * 100
	
	local c = rv
			
	return g, s, c
end

-----------------------------------------

function priceToString(val)

	local gold, silver, copper  = val2gsc(val)

	local st = ""
	
	if gold ~= 0 then
		st = gold.."g "
	end

	if st ~= "" then
		st = st..format("%02is ", silver)
	elseif silver ~= 0 then
		st = st..silver.."s "
	end
		
	if st ~= "" then
		st = st..format("%02ic", copper)
	elseif copper ~= 0 then
		st = st..copper.."c"
	end
	
	return st
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
	else log("Can't GetAuctionItemClasses") end
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

-----------------------------------------

-- These functions were meant to be used for a search sorted by buyout price but that actually seems impossible to implement nicely with the vanilla interface

-- function Auctionator_AuctionFrameBrowse_Update()
	-- local numBatchAuctions = getn(searchResults)
	-- local totalAuctions = numBatchAuctions
	-- local button, buttonName, iconTexture, itemName, color, itemCount, moneyFrame, buyoutMoneyFrame, buyoutText, buttonHighlight
	-- local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame)
	-- local index
	-- local isLastSlotEmpty
	-- local name, texture, count, quality, canUse, minBid, minIncrement, buyoutPrice, duration, bidAmount, highBidder
	-- BrowseBidButton:Disable()
	-- BrowseBuyoutButton:Disable()
	-- -- Update sort arrows
	-- SortButton_UpdateArrow(BrowseQualitySort, "list", "quality")
	-- SortButton_UpdateArrow(BrowseLevelSort, "list", "level")
	-- SortButton_UpdateArrow(BrowseDurationSort, "list", "duration")
	-- SortButton_UpdateArrow(BrowseHighBidderSort, "list", "status")
	-- SortButton_UpdateArrow(BrowseCurrentBidSort, "list", "bid")

	-- -- Show the no results text if no items found
	-- if numBatchAuctions == 0 then
		-- BrowseNoResultsText:Show()
	-- else
		-- BrowseNoResultsText:Hide()
	-- end

	-- for i=1, NUM_BROWSE_TO_DISPLAY do
		-- index = offset + i
		-- button = getglobal("BrowseButton"..i)
		-- -- Show or hide auction buttons
		-- if index > numBatchAuctions then
			-- button:Hide()
			-- -- If the last button is empty then set isLastSlotEmpty var
			-- if i == NUM_BROWSE_TO_DISPLAY then
				-- isLastSlotEmpty = 1
			-- end
		-- else
			-- button:Show()

			-- buttonName = "BrowseButton"..i
			-- local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder =  GetAuctionItemInfo("list", index);
			-- -- duration = GetAuctionItemTimeLeft("list", offset + i)
			-- -- Resize button if there isn't a scrollbar
			-- buttonHighlight = getglobal("BrowseButton"..i.."Highlight")
			-- if numBatchAuctions < NUM_BROWSE_TO_DISPLAY then
				-- button:SetWidth(557)
				-- buttonHighlight:SetWidth(523)
				-- BrowseCurrentBidSort:SetWidth(173)
			-- else
				-- button:SetWidth(532)
				-- buttonHighlight:SetWidth(502)
				-- BrowseCurrentBidSort:SetWidth(157)
			-- end
			-- -- Set name and quality color
			-- color = ITEM_QUALITY_COLORS[searchResults[i].quality]
			-- itemName = getglobal(buttonName.."Name")
			-- itemName:SetText(searchResults[i].name)
			-- itemName:SetVertexColor(color.r, color.g, color.b)
			-- -- Set level
			-- if searchResults[i].level > UnitLevel("player") then
				-- getglobal(buttonName.."Level"):SetText(RED_FONT_COLOR_CODE..level..FONT_COLOR_CODE_CLOSE)
			-- else
				-- getglobal(buttonName.."Level"):SetText(searchResults[i].level)
			-- end
			-- -- Set high bidder
			-- getglobal(buttonName.."HighBidder"):SetText(searchResults[i].highBidder)
			-- -- Set closing time
			-- getglobal(buttonName.."ClosingTimeText"):SetText(AuctionFrame_GetTimeLeftText(searchResults[i].duration))
			-- getglobal(buttonName.."ClosingTime").tooltip = AuctionFrame_GetTimeLeftTooltipText(searchResults[i].duration)
			-- -- Set item texture, count, and usability
			-- iconTexture = getglobal(buttonName.."ItemIconTexture")
			-- iconTexture:SetTexture(searchResults[i].texture)
			-- if not searchResults[i].canUse then
				-- iconTexture:SetVertexColor(1.0, 0.1, 0.1)
			-- else
				-- iconTexture:SetVertexColor(1.0, 1.0, 1.0)
			-- end
			-- itemCount = getglobal(buttonName.."ItemCount")
			-- if searchResults[i].stackSize > 1 then
				-- itemCount:SetText(searchResults[i].stackSize)
				-- itemCount:Show()
			-- else
				-- itemCount:Hide()
			-- end
			-- -- Set high bid
			-- moneyFrame = getglobal(buttonName.."MoneyFrame")
			-- buyoutMoneyFrame = getglobal(buttonName.."BuyoutMoneyFrame")
			-- buyoutText = getglobal(buttonName.."BuyoutText")
			-- -- If not bidAmount set the bid amount to the min bid
			-- if searchResults[i].bidAmount == 0 then
				-- MoneyFrame_Update(moneyFrame:GetName(), searchResults[i].minBid)
			-- else
				-- MoneyFrame_Update(moneyFrame:GetName(), searchResults[i].bidAmount)
			-- end
			
			-- if searchResults[i].buyoutPrice > 0 then
				-- moneyFrame:SetPoint("RIGHT", buttonName, "RIGHT", 10, 10)
				-- MoneyFrame_Update(buyoutMoneyFrame:GetName(), searchResults[i].buyoutPrice)
				-- buyoutMoneyFrame:Show()
				-- buyoutText:Show()
			-- else
				-- moneyFrame:SetPoint("RIGHT", buttonName, "RIGHT", 10, 3)
				-- buyoutMoneyFrame:Hide()
				-- buyoutText:Hide()
			-- end
			-- -- Set high bidder
			-- local highBidder = searchResults[i].highBidder
			-- if not highBidder then
				-- highBidder = RED_FONT_COLOR_CODE..NO_BIDS..FONT_COLOR_CODE_CLOSE
			-- end
			-- getglobal(buttonName.."HighBidder"):SetText(highBidder)
			-- -- Set highlight
			-- if GetSelectedAuctionItem("list") and (offset + i) == GetSelectedAuctionItem("list") then
				-- button:LockHighlight()
				-- if highBidder ~= UnitName("player") then
					-- BrowseBidButton:Enable()
				-- end
				
				-- if searchResults[i].buyoutPrice > 0 and searchResults[i].buyoutPrice >= searchResults[i].minBid then
					-- BrowseBuyoutButton:Enable()
					-- AuctionFrame.buyoutPrice = searchResults[i].buyoutPrice
				-- else
					-- AuctionFrame.buyoutPrice = nil
				-- end
				-- -- Set bid
				-- local bidAmount = searchResults[i].bidAmount
				-- if bidAmount > 0 then
					-- bidAmount = bidAmount + searchResults[i].minIncrement
					-- MoneyInputFrame_SetCopper(BrowseBidPrice, bidAmount)
				-- else
					-- MoneyInputFrame_SetCopper(BrowseBidPrice, searchResults[i].minBid)
				-- end
				
			-- else
				-- button:UnlockHighlight()
			-- end
		-- end
	-- end
	
	-- BrowsePrevPageButton:Hide()
	-- BrowseNextPageButton:Hide()
	-- BrowseScanCountText:Hide()
	-- FauxScrollFrame_Update(BrowseScrollFrame, numBatchAuctions, NUM_BROWSE_TO_DISPLAY, AUCTIONS_BUTTON_HEIGHT)
-- end

-----------------------------------------

-- function Auctionator_AuctionFrameBrowse_Scan()
	
	-- Auctionator_Scan_Start(Auctionator_Scan_CreateQuery{
		-- name = BrowseName:GetText(),
		-- exactMatch = false,
		-- minLevel = BrowseMinLevel:GetText(),
		-- maxLevel = BrowseMaxLevel:GetText(),
		-- invTypeIndex = AuctionFrameBrowse.selectedInvtypeIndex,
		-- classIndex = AuctionFrameBrowse.selectedClassIndex,
		-- subclassIndex = AuctionFrameBrowse.selectedSubclassIndex,
		-- isUsable = IsUsableCheckButton:GetChecked(),
		-- qualityIndex = UIDropDownMenu_GetSelectedValue(BrowseDropDown),
		-- onComplete = function(data)
			-- table.sort(data, function(a,b) return a.buyoutPrice < b.buyoutPrice end)
			-- scanData = data
		-- end
	-- })
	
-- end