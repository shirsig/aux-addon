auctionatorEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize
local selectedAuctionatorEntry

local currentAuctionItemName = nil
local currentAuctionItemTexture = nil
local currentAuctionStackSize = nil

local lastBuyoutPrice = 1
local lastItemPosted = nil

-----------------------------------------

local processScanResults, undercut, ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Auctionator_Sell_OnEvent()
	if event == "AUCTION_OWNED_LIST_UPDATE" then
		Auctionator_OnAuctionOwnedUpdate()
	end
end

-----------------------------------------

function Auctionator_AuctionFrameAuctions_Update()
	Auctionator.orig.AuctionFrameAuctions_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Auctionator.tabs.sell.index and AuctionFrame:IsShown() then
		Auctionator_HideElems(Auctionator.tabs.sell.hiddenElements)
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
	Auctionator.orig.AuctionsCreateAuctionButton_OnClick()
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
	Auctionator.orig.AuctionSellItemButton_OnEvent()
	Auctionator_OnNewAuctionUpdate()
end

-----------------------------------------

function Auctionator_SetupHookFunctions()
	
	Auctionator.orig.BrowseButton_OnClick = BrowseButton_OnClick
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

	Auctionator.orig.AuctionSellItemButton_OnEvent = AuctionSellItemButton_OnEvent
	AuctionSellItemButton_OnEvent = Auctionator_AuctionSellItemButton_OnEvent
	
	Auctionator.orig.AuctionFrameTab_OnClick = AuctionFrameTab_OnClick
	AuctionFrameTab_OnClick = Auctionator_AuctionFrameTab_OnClick
	
	Auctionator.orig.ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
	ContainerFrameItemButton_OnClick = Auctionator_ContainerFrameItemButton_OnClick
	
	Auctionator.orig.AuctionFrameAuctions_Update = AuctionFrameAuctions_Update
	AuctionFrameAuctions_Update = Auctionator_AuctionFrameAuctions_Update
	
	Auctionator.orig.AuctionsCreateAuctionButton_OnClick = AuctionsCreateAuctionButton_OnClick
	AuctionsCreateAuctionButton_OnClick = Auctionator_AuctionsCreateAuctionButton_OnClick
	
end

-----------------------------------------

function Auctionator_SetMessage(msg)
	Auctionator_HideElems(Auctionator.tabs.sell.shownElements)
	AuctionatorMessage:SetText(msg)
	AuctionatorMessage:Show()
	AuctionatorBuyMessage:SetText(msg) -- TODO doesn't belong here
	AuctionatorBuyMessage:Show()
end

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
		AuctionatorSellRefreshButton:Disable()
		Auctionator_SetMessage("Drag an item to the Auction Item area\n\nto see recommended pricing information")
	else
		AuctionatorSellRefreshButton:Enable()	
		
		if selectedAuctionatorEntry then
			local newBuyoutPrice = selectedAuctionatorEntry.itemPrice * currentAuctionItemStackSize

			if selectedAuctionatorEntry.numYours < selectedAuctionatorEntry.count then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95 
			
			AuctionatorMessage:Hide()	
			Auctionator_ShowElems(Auctionator.tabs.sell.shownElements)
			
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
			Auctionator_HideElems(Auctionator.tabs.sell.shownElements)
		end
	end
	
	Auctionator_ScrollbarUpdate()
end

-----------------------------------------

function Auctionator_OnNewAuctionUpdate()

	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Auctionator.tabs.sell.index then
		return
	end
	
	if not Auctionator_Scan_IsIdle() then
		Auctionator_Scan_Abort()
	end
	
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

	local numrows
	if not currentAuctionItemName or not auctionatorEntries[currentAuctionItemName] then
		numrows = 0
	else
		numrows = getn(auctionatorEntries[currentAuctionItemName])
	end
	
	FauxScrollFrame_Update(AuctionatorScrollFrame, numrows, 12, 16);

	for line = 1,12 do

		local dataOffset = line + FauxScrollFrame_GetOffset(AuctionatorScrollFrame)	
		local lineEntry = getglobal("AuctionatorSellEntry"..line)
		
		if numrows <= 12 then
			lineEntry:SetWidth(603)
		else
			lineEntry:SetWidth(585)
		end
		
		lineEntry:SetID(dataOffset)
		
		if currentAuctionItemName and dataOffset <= numrows and auctionatorEntries[currentAuctionItemName] then
			
			local entry = auctionatorEntries[currentAuctionItemName][dataOffset]

			local lineEntry_avail	= getglobal("AuctionatorSellEntry"..line.."_Availability")
			local lineEntry_comm	= getglobal("AuctionatorSellEntry"..line.."_Comment")
			local lineEntry_stack	= getglobal("AuctionatorSellEntry"..line.."_StackPrice")

			if selectedAuctionatorEntry and entry.itemPrice == selectedAuctionatorEntry.itemPrice and entry.stackSize == selectedAuctionatorEntry.stackSize then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			if entry.stackSize == currentAuctionItemStackSize then
				lineEntry_avail:SetTextColor(0.2, 0.9, 0.2)
			else
				lineEntry_avail:SetTextColor(1.0, 1.0, 1.0)
			end

			if entry.numYours == 0 then
				lineEntry_comm:SetText("")
			elseif
				entry.numYours == entry.count then
				lineEntry_comm:SetText("yours")
			else
				lineEntry_comm:SetText("yours: "..entry.numYours)
			end
						
			local tx = string.format("%i %s of %i", entry.count, Auctionator_PluralizeIf("stack", entry.count), entry.stackSize)
			lineEntry_avail:SetText(tx)

			MoneyFrame_Update("AuctionatorSellEntry"..line.."_UnitPrice", Auctionator_Round(entry.buyoutPrice/entry.stackSize))
			MoneyFrame_Update("AuctionatorSellEntry"..line.."_TotalPrice", Auctionator_Round(entry.buyoutPrice))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
end

-----------------------------------------

function AuctionatorSellEntry_OnClick()
	local entryIndex = this:GetID()

	selectedAuctionatorEntry = auctionatorEntries[currentAuctionItemName][entryIndex]

	Auctionator_UpdateRecommendation()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

-----------------------------------------

function AuctionatorSellRefreshButton_OnClick()
	if not Auctionator_Scan_IsIdle() then
		Auctionator_Scan_Abort()
	end
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
	else
		Auctionator_Log("Can't GetAuctionItemClasses")
	end
end

-----------------------------------------

function SubType2AuctionSubclass(auctionClass, itemSubtype)
	local itemClasses = { GetAuctionItemSubClasses(auctionClass.number) }
	if itemClasses.n > 0 then
	local itemClass
		for x, itemClass in pairs(itemClasses) do
			if itemClass == itemSubtype then
				return x
			end
		end
	end
end