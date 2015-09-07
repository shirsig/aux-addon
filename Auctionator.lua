local AuctionatorVersion = "1.1.0-Vanilla"
local AuctionatorAuthor  = "Zirco; Vanilla adaptation by Nimeral; Fixed, Cleaned up and extended by Simon Hirsig"

local AuctionatorLoaded = false

local recommendationElements = {}
local auctionsTabElements = {}

AUCTIONATOR_ENABLE_ALT	= 1
AUCTIONATOR_OPEN_FIRST	= 0

local AUCTIONATOR_TAB_INDEX = 4

-----------------------------------------

local Auctionator_Orig_AuctionFrameBrowse_Update
local Auctionator_Orig_AuctionFrameBrowse_Scan
local Auctionator_Orig_AuctionFrameTab_OnClick
local Auctionator_Orig_ContainerFrameItemButton_OnClick
local Auctionator_Orig_AuctionFrameAuctions_Update
local Auctionator_Orig_AuctionsCreateAuctionButton_OnClick

local KM_NULL_STATE	= 0
local KM_PREQUERY	= 1
local KM_POSTQUERY	= 2

local processingState = KM_NULL_STATE
local currentQuery
local currentPage
local forceRefresh = false

local scanData
local auctionatorEntries = {}
-- local searchResults = {}
local selectedAuctionatorEntry

local currentAuctionItemName = nil
local currentAuctionItemTexture = nil
local currentAuctionStackSize = nil

local lastBuyoutPrice = 1
local lastItemPosted = nil

-----------------------------------------

local log, BoolToString, BoolToNum, NumToBool, pluralizeIf, round, calcNewPrice, roundPriceDown
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

function Auctionator_OnAddonLoaded()

	if string.lower(arg1) == "blizzard_auctionui" then			
		Auctionator_AddSellTab()
		
		Auctionator_SetupHookFunctions()
		
		auctionsTabElements[1]  = AuctionsScrollFrame
		auctionsTabElements[2]  = AuctionsButton1
		auctionsTabElements[3]  = AuctionsButton2
		auctionsTabElements[4]  = AuctionsButton3
		auctionsTabElements[5]  = AuctionsButton4
		auctionsTabElements[6]  = AuctionsButton5
		auctionsTabElements[7]  = AuctionsButton6
		auctionsTabElements[8]  = AuctionsButton7
		auctionsTabElements[9]  = AuctionsButton8
		auctionsTabElements[10] = AuctionsButton9
		auctionsTabElements[11] = AuctionsQualitySort
		auctionsTabElements[12] = AuctionsDurationSort
		auctionsTabElements[13] = AuctionsHighBidderSort
		auctionsTabElements[14] = AuctionsBidSort
		auctionsTabElements[15] = AuctionsCancelAuctionButton
		--auctionsTabElements[16] = AuctionFrameAuctions
		--auctionsTabElements[16] = AuctionFrame

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
	Auctionator_Sell_Template:Hide()
	
	if index == 3 then		
		Auctionator_ShowElems(auctionsTabElements)
	end
	
	if index ~= AUCTIONATOR_TAB_INDEX then	
		Auctionator_Orig_AuctionFrameTab_OnClick(index)
		lastItemPosted = nil		
	elseif index == AUCTIONATOR_TAB_INDEX then
		AuctionFrameTab_OnClick(3)
		
		PanelTemplates_SetTab(AuctionFrame, AUCTIONATOR_TAB_INDEX)
		
		Auctionator_HideElems(auctionsTabElements)
		
		Auctionator_Sell_Template:Show()
		AuctionFrame:EnableMouse(false)
		
		Auctionator_OnNewAuctionUpdate()
	end
end

-----------------------------------------

function Auctionator_ContainerFrameItemButton_OnClick(button)
	
	if (AUCTIONATOR_ENABLE_ALT == 0
		or not AuctionFrame:IsShown()
		or not IsAltKeyDown())
	then
		return Auctionator_Orig_ContainerFrameItemButton_OnClick(button)
	end

	ClickAuctionSellItemButton()
	ClearCursor()
	
	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= AUCTIONATOR_TAB_INDEX then
		AuctionFrameTab_OnClick(AUCTIONATOR_TAB_INDEX)
	end
	
	PickupContainerItem(this:GetParent():GetID(), this:GetID())
	ClickAuctionSellItemButton()

end

-----------------------------------------

function Auctionator_AuctionFrameAuctions_Update()
	
	Auctionator_Orig_AuctionFrameAuctions_Update()

	if PanelTemplates_GetSelectedTab(AuctionFrame) == AUCTIONATOR_TAB_INDEX  and	AuctionFrame:IsShown() then
		Auctionator_HideElems(auctionsTabElements)
	end	
end

-----------------------------------------
-- Intercept the Create Auction click so
-- that we can note the auction values
-----------------------------------------

function Auctionator_AuctionsCreateAuctionButton_OnClick()
	
	if PanelTemplates_GetSelectedTab(AuctionFrame) == AUCTIONATOR_TAB_INDEX  and AuctionFrame:IsShown() then
		
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

function Auctionator_SetupHookFunctions()
	
	-- Auctionator_Orig_AuctionFrameBrowse_Update = AuctionFrameBrowse_Update
	-- AuctionFrameBrowse_Update = Auctionator_AuctionFrameBrowse_Update
	
	-- Auctionator_Orig_AuctionFrameBrowse_Scan = AuctionFrameBrowse_Scan
	-- AuctionFrameBrowse_Scan = Auctionator_AuctionFrameBrowse_Scan
	
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

function Auctionator_AddSellTab()
		
	local n = AuctionFrame.numTabs + 1
	
	AUCTIONATOR_TAB_INDEX = n

	local framename = "AuctionFrameTab"..n

	local frame = CreateFrame("Button", framename, AuctionFrame, "AuctionTabTemplate")

	setglobal("AuctionFrameTab4", frame)
	frame:SetID(n)
	--frame:SetParent("FriendsFrameTabTemplate")
	frame:SetText("Auctionator")
	frame:SetPoint("LEFT", getglobal("AuctionFrameTab"..n-1), "RIGHT", -8, 0)
	frame:Show()

	--Attempting to index local 'frame' now
	
	-- Configure the tab button.
	--setglobal(AuctionFrameTab4, AuctionFrameTab4)
	
	--tabButton:SetPoint("TOPLEFT", getglobal("AuctionFrameTab"..(tabIndex - 1)):GetName(), "TOPRIGHT", -8, 0)
	--tabButton:SetID(tabIndex)
	
	PanelTemplates_SetNumTabs(AuctionFrame, n)
	PanelTemplates_EnableTab(AuctionFrame, n)
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
	if processingState == KM_POSTQUERY then
		Auctionator_Scan_Process()
	end
end

-----------------------------------------

function Auctionator_Scan_Complete()
	
	if getn(scanData) == 0 then
		Auctionator_SetMessage("No auctions were found for \n\n"..currentAuctionItemName)
	end
	
	if currentQuery.onComplete then
		currentQuery.onComplete(scanData, currentQuery.name);
	end
	
	currentQuery = nil
	currentPage = nil
	scanData = nil
	processingState = KM_NULL_STATE
end

-----------------------------------------

function Auctionator_Scan_Abort()

	if currentQuery and currentQuery.onAbort then
		currentQuery.onAbort();
	end
	
	currentQuery = nil
	currentPage = nil
	scanData = nil
	processingState = KM_NULL_STATE
end

-----------------------------------------

function Auctionator_Scan_Query()
	if processingState == KM_PREQUERY then
		
		QueryAuctionItems(
			currentQuery.name,
			currentQuery.minLevel,
			currentQuery.maxLevel,
			currentQuery.invTypeIndex,
			currentQuery.classIndex,
			currentQuery.subclassIndex,
			currentPage,
			currentQuery.isUsable,
			currentQuery.qualityIndex
		)
		processingState = KM_POSTQUERY
		currentPage = currentPage + 1
	end
end

-----------------------------------------

function Auctionator_Scan_Process()
	
	if processingState == KM_POSTQUERY then
	
		-- SortAuctionItems("list", "buyout")
		-- if IsAuctionSortReversed("list", "buyout") then
			-- SortAuctionItems("list", "buyout")
		-- end
		
		local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

		if totalAuctions >= NUM_AUCTION_ITEMS_PER_PAGE then
			Auctionator_SetMessage("Scanning auctions: page "..currentPage)
		end
				
		for i = 1, numBatchAuctions do
		
			local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)
			local duration = GetAuctionItemTimeLeft("list", i);

			local sd = {		
				name			= name,
				texture			= texture,
				stackSize		= count,
				quality			= quality,
				canUse			= canUse,
				level			= level,
				minBid			= minBid,
				minIncrement	= minIncrement,
				buyoutPrice		= buyoutPrice,
				bidAmount		= bidAmount,
				highBidder		= highBidder,
				owner			= owner,
				duration		= duration
			}
			
			if not currentQuery.exactMatch or (currentQuery.name == sd.name and sd.buyoutPrice > 0) then -- TODO separate option for buyout price
				tinsert(scanData, sd)
			end
		end

		if numBatchAuctions == NUM_AUCTION_ITEMS_PER_PAGE then			
			processingState = KM_PREQUERY	
		else
			Auctionator_Scan_Complete()
		end
	end
end

-----------------------------------------

function Auctionator_Scan_Start(query)

	Auctionator_SetMessage("Scanning")

	if processingState ~= KM_NULL_STATE then
		Auctionator_Scan_Abort()
	end
	
	currentQuery = query
	currentPage = 0
	scanData = {}
	processingState = KM_PREQUERY
end

-----------------------------------------

function Auctionator_SetMessage(msg)
	Auctionator_HideElems(recommendationElements)
	AuctionatorMessage:SetText(msg)
	AuctionatorMessage:Show()
end

-----------------------------------------

function Auctionator_Process_ScanResults(rawData, auctionItemName)

	auctionatorEntries[auctionItemName] = {}
	
	if rawData then
	
		----- Condense the scan rawData into a table that has only a single entry per stacksize/price combo
		local condData = {}

		for i,sd in ipairs(rawData) do
		
			local key = "_"..sd.stackSize.."_"..sd.buyoutPrice
					
			if condData[key] then
				condData[key].count = condData[key].count + 1
			else
				local rawData = {}
				
				rawData.stackSize 		= sd.stackSize
				rawData.buyoutPrice	= sd.buyoutPrice
				rawData.itemPrice		= sd.buyoutPrice / sd.stackSize
				rawData.count			= 1
				rawData.numYours		= 0
				
				condData[key] = rawData;
			end

			if sd.owner == UnitName("player") then
				condData[key].numYours = condData[key].numYours + 1
			end
		
		end

		----- create a table of these entries sorted by itemPrice
		
		local n = 1
		for i,v in pairs(condData) do
			auctionatorEntries[auctionItemName][n] = v
			n = n + 1
		end
		
		table.sort(auctionatorEntries[auctionItemName], function(a,b) return a.itemPrice < b.itemPrice end)
	end
end

-----------------------------------------

local bestPriceOurStackSize;

-----------------------------------------

function Auctionator_CalcBaseData()
	
	if not currentAuctionItemName or not auctionatorEntries[currentAuctionItemName] then
		selectedAuctionatorEntry = nil
	else
		local bestPrice	= {}		-- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest			-- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,sd in ipairs(auctionatorEntries[currentAuctionItemName]) do
		
			if not bestPrice[sd.stackSize] or bestPrice[sd.stackSize].itemPrice >= sd.itemPrice then
				bestPrice[sd.stackSize] = sd
			end
		
			if not absoluteBest or absoluteBest.itemPrice > sd.itemPrice then
				absoluteBest = sd
			end	
		end
		
		selectedAuctionatorEntry = absoluteBest

		if bestPrice[currentAuctionItemStackSize] then
			selectedAuctionatorEntry				= bestPrice[currentAuctionItemStackSize]
			bestPriceOurStackSize	= bestPrice[currentAuctionItemStackSize]
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
				newBuyoutPrice = calcNewPrice(newBuyoutPrice)
			end
			
			local newStartPrice = calcNewPrice(round(newBuyoutPrice * 0.95)) 
			
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
		else 
			Auctionator_HideElems(recommendationElements)
		end
	end
	
	Auctionator_ScrollbarUpdate()
end

-----------------------------------------

function Auctionator_OnAuctionHouseShow()

	AuctionatorOptionsButtonFrame:Show()

	if AUCTIONATOR_OPEN_FIRST ~= 0 then
		AuctionFrameTab_OnClick(AUCTIONATOR_TAB_INDEX)
	end

end

-----------------------------------------

function Auctionator_OnAuctionHouseClosed()

	AuctionatorOptionsButtonFrame:Hide()
	
	AuctionatorOptionsFrame:Hide()
	AuctionatorDescriptionFrame:Hide()
	Auctionator_Sell_Template:Hide()
	
end

-----------------------------------------

function Auctionator_CreateQuery(parameterMap)
	local query = {
		name = nil,
		exactMatch = false,
		minLevel = "",
		maxLevel = "",
		invTypeIndex = nil,
		classIndex = nil,
		subclassIndex = nil,
		isUsable = nil,
		qualityIndex = nil
	}
	
	for k,v in pairs(parameterMap) do
		query[k] = v
	end
	
	return query
end

-----------------------------------------

function Auctionator_OnNewAuctionUpdate()

	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= AUCTIONATOR_TAB_INDEX then
		return
	end
	
	if processingState ~= KM_NULL_STATE then
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
		
		Auctionator_Scan_Start(Auctionator_CreateQuery{
			name = currentAuctionItemName,
			exactMatch = true,
			classIndex = currentAuctionClass,
			subclassIndex = currentAuctionSubclass,
			onComplete = function(data, auctionItemName)
				Auctionator_Process_ScanResults(data, auctionItemName)
				Auctionator_CalcBaseData()
			end
		})		
	end
	
	Auctionator_CalcBaseData()
end

-----------------------------------------

function Auctionator_OnUpdate(self)
	
	if not AuctionatorMessage then
		return
	end
	
	if processingState == KM_PREQUERY and GetTime() - self.TimeOfLastUpdate > 0.5 then
	
		self.TimeOfLastUpdate = GetTime()

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

	local line				-- 1 through 12 of our window to scroll
	local dataOffset		-- an index into our data calculated from the scroll offset


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
		
		lineEntry:SetID(dataOffset)
		
		if currentAuctionItemName and dataOffset <= numrows and auctionatorEntries[currentAuctionItemName][dataOffset] then
			
			local data = auctionatorEntries[currentAuctionItemName][dataOffset]

			local lineEntry_avail	= getglobal("AuctionatorEntry"..line.."_Availability")
			local lineEntry_stack	= getglobal("AuctionatorEntry"..line.."_StackPrice")

			if selectedAuctionatorEntry and data.itemPrice == selectedAuctionatorEntry.itemPrice and data.stackSize == selectedAuctionatorEntry.stackSize then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			if data.stackSize == currentAuctionItemStackSize then
				lineEntry_avail:SetTextColor(0.2, 0.9, 0.2)
			else
				lineEntry_avail:SetTextColor(1.0, 1.0, 1.0)
			end

			-- if		data.numYours == 0 then			lineEntry_comm:SetText("")
			-- elseif	data.numYours == data.count then	lineEntry_comm:SetText("yours")
			-- else										lineEntry_comm:SetText("yours: "..data.numYours)
			-- end
						
			local tx = string.format("%i %s of %i", data.count, pluralizeIf("stack", data.count), data.stackSize)

			MoneyFrame_Update("AuctionatorEntry"..line.."_PerItem_Price", round(data.buyoutPrice/data.stackSize))

			lineEntry_avail:SetText(tx)
			lineEntry_stack:SetText(priceToString(data.buyoutPrice))

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

-----------------------------------------

function Auctionator_ShowDescriptionFrame()
	AuctionatorDescriptionFrame:Show()
	AuctionatorAuthorText:SetText("Author: "..AuctionatorAuthor)
end

-----------------------------------------

function Auctionator_ShowOptionsFrame()

	AuctionatorOptionsFrame:Show()
	AuctionatorOptionsFrame:SetBackdropColor(0,0,0,100)
	
	AuctionatorConfigFrameTitle:SetText("Auctionator Options for "..UnitName("player"))
	
	local expText = "<html><body>"
					.."<h1>What is Auctionator?</h1><br/>"
					.."<p>"
					.."Figuring out a good buyout price when posting auctions can be tedious and time-consuming.  If you're like most people, you first browse the current "
					.."auctions to get a sense of how much your item is currently selling for.  Then you undercut the lowest price by a bit.  If you're creating multiple auctions "
					.."you're bouncing back and forth between the Browse tab and the Auctions tab, doing lots of division in "
					.."your head, and doing lots of clicking and typing."
					.."</p><br/><h1>How it works</h1><br/><p>"
					.."Auctionator makes this whole process easy and streamlined.  When you select an item to auction, Auctionator displays a summary of all the current auctions for "
					.."that item sorted by per-item price.  Auctionator also calculates a recommended buyout price based on the cheapest per-item price for your item.  If you're "
					.."selling a stack rather than a single item, Auctionator bases its recommended buyout price on the cheapest stack of the same size."
					.."</p><br/><p>"
					.."If you don't like Auctionator's recommendation, you can click on any line in the summary and Auctionator will recalculate the recommended buyout price based "
					.."on that auction.  Of course, you can always override Auctionator's recommendation by just typing in your own buyout price."
					.."</p><br/><p>"
					.."With Auctionator, creating an auction is usually just a matter of picking an item to auction and clicking the Create Auction button."
					.."</p>"
					.."</body></html>"

	AuctionatorExplanation:SetText("Auctionator is an addon designed to make it easier and faster to setup your auctions at the auction house.")
	AuctionatorDescriptionHTML:SetText(expText)
	AuctionatorDescriptionHTML:SetSpacing(3)

	AuctionatorVersionText:SetText("Version: "..AuctionatorVersion)
	
	AuctionatorOption_Enable_Alt:SetChecked(NumToBool(AUCTIONATOR_ENABLE_ALT))
	AuctionatorOption_Open_First:SetChecked(NumToBool(AUCTIONATOR_OPEN_FIRST))
end

-----------------------------------------

function AuctionatorOptionsSave()

	AUCTIONATOR_ENABLE_ALT = BoolToNum(AuctionatorOption_Enable_Alt:GetChecked ())
	AUCTIONATOR_OPEN_FIRST = BoolToNum(AuctionatorOption_Open_First:GetChecked ())
	
end

-----------------------------------------

function Auctionator_ShowTooltip_EnableAlt()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Enable alt-key shortcut", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, holding the Alt key down while clicking an item in your bags will switch to the Auctionator panel, place the item in the Auction Item area, and start the scan.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

-----------------------------------------

function Auctionator_ShowTooltip_OpenFirst()

	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Automatically open Auctionator panel", 0.9, 1.0, 1.0)
	GameTooltip:AddLine("If this option is checked, the Auctionator panel will display first whenever you open the Auction House window.", 0.5, 0.5, 1.0, 1)
	GameTooltip:Show()

end

--[[***************************************************************

	All function below here are local utility functions.
	These should be declared local at the top of this file.

--*****************************************************************]]

function BoolToString(b)
	if b then
		return "true"
	end
	
	return "false"
end

-----------------------------------------

function BoolToNum(b)
	if b then
		return 1
	end
	
	return 0
end

-----------------------------------------

function NumToBool(n)
	if n == 0 then
		return false
	end
	
	return true
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

function calcNewPrice(price)

	if price > 2000000 then
		return roundPriceDown(price, 10000, 10000)
	elseif price > 1000000 then
		return roundPriceDown(price, 2500, 2500)
	elseif price > 500000 then
		return roundPriceDown(price, 1000, 1000)
	elseif price > 50000 then
		return roundPriceDown(price, 500, 500)
	elseif price > 10000 then
		return roundPriceDown(price, 500, 200)
	elseif price > 2000 then
		return roundPriceDown(price, 100, 50)
	elseif price > 100 then
		return roundPriceDown(price, 10, 5)
	elseif price > 0 then
		return math.floor(price - 1)
	else
		return 0
	end
end

-----------------------------------------
-- roundPriceDown - rounds a price down to the next lowest multiple of a.
--				  - if the result is not at least b lower, rounds down by a again.
--
--	examples:  	(128790, 500, 250)  ->  128500 
--				(128700, 500, 250)  ->  128000 
--				(128400, 500, 250)  ->  128000
-----------------------------------------

function roundPriceDown(price, a, b)
	
	local newprice = math.floor(price / a) * a
	
	if (price - newprice) < b then
		newprice = newprice - a
	end
	
	return newprice
	
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
	
	-- Auctionator_Scan_Start(Auctionator_CreateQuery{
		-- name = BrowseName:GetText(),
		-- exactMatch = false,
		-- minLevel = BrowseMinLevel:GetText(),
		-- maxLevel = BrowseMaxLevel:GetText(),
		-- invTypeIndex = AuctionFrameBrowse.selectedInvtypeIndex,
		-- classIndex = AuctionFrameBrowse.selectedClassIndex,
		-- subclassIndex = AuctionFrameBrowse.selectedSubclassIndex,
		-- isUsable = IsUsableCheckButton:GetChecked(),
		-- qualityIndex = UIDropDownMenu_GetSelectedValue(BrowseDropDown),
		-- onComplete = function(data, auctionItemName)
			-- table.sort(data, function(a,b) return a.buyoutPrice < b.buyoutPrice end)
			-- scanData = data
		-- end
	-- })
	
-- end