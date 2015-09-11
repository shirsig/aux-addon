auxSellEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize
local selectedAuxEntry

local currentAuctionItemName = nil
local currentAuctionItemTexture = nil
local currentAuctionStackSize = nil

local lastBuyoutPrice = 1
local lastItemPosted = nil

-----------------------------------------

local processScanResults, undercut, ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Aux_Sell_OnEvent()
	if event == "AUCTION_OWNED_LIST_UPDATE" then
		Aux_OnAuctionOwnedUpdate()
	end
end

-----------------------------------------

function Aux_AuctionFrameAuctions_Update()
	Aux.orig.AuctionFrameAuctions_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.sell.hiddenElements)
	end	
end

-----------------------------------------
-- Intercept the Create Auction click so
-- that we can note the auction values
-----------------------------------------

function Aux_AuctionsCreateAuctionButton_OnClick()	
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index  and AuctionFrame:IsShown() then	
		lastBuyoutPrice = MoneyInputFrame_GetCopper(BuyoutPrice)
		lastItemPosted = currentAuctionItemName
	end
	Aux.orig.AuctionsCreateAuctionButton_OnClick()
end

-----------------------------------------

function Aux_OnAuctionOwnedUpdate()
	if lastItemPosted then	
		Aux_Recommend_Text:SetText("Auction Created for "..lastItemPosted)

		MoneyFrame_Update("Aux_RecommendPerStack_Price", lastBuyoutPrice)

		Aux_RecommendPerStack_Price:Show()
		Aux_RecommendPerItem_Price:Hide()
		Aux_RecommendPerItem_Text:Hide()
		Aux_Recommend_Basis_Text:Hide()
	end
	
end

-----------------------------------------

function Aux_AuctionSellItemButton_OnEvent()
	Aux.orig.AuctionSellItemButton_OnEvent()
	Aux_OnNewAuctionUpdate()
end

-----------------------------------------

function Aux_SetMessage(msg)
	Aux_HideElems(Aux.tabs.sell.recommendationElements)
	AuxMessage:SetText(msg)
	AuxMessage:Show()
	AuxBuyMessage:SetText(msg) -- TODO doesn't belong here
	AuxBuyMessage:Show()
end

-----------------------------------------

function Aux_SelectAuxEntry()
	
	if not currentAuctionItemName or not auxSellEntries[currentAuctionItemName] then
		selectedAuxEntry = nil
	else
		local bestPrice	= {} -- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,auxEntry in ipairs(auxSellEntries[currentAuctionItemName]) do
			if not bestPrice[auxEntry.stackSize] or bestPrice[auxEntry.stackSize].itemPrice >= auxEntry.itemPrice then
				bestPrice[auxEntry.stackSize] = auxEntry
			end
		
			if not absoluteBest or absoluteBest.itemPrice > auxEntry.itemPrice then
				absoluteBest = auxEntry
			end	
		end
		
		selectedAuxEntry = absoluteBest

		if bestPrice[currentAuctionItemStackSize] then
			selectedAuxEntry = bestPrice[currentAuctionItemStackSize]
			bestPriceOurStackSize = bestPrice[currentAuctionItemStackSize]
		end
	end
end

-----------------------------------------

function Aux_UpdateRecommendation()

	if not currentAuctionItemName then
		AuxSellRefreshButton:Disable()
		Aux_SetMessage("Drag an item to the Auction Item area\n\nto see recommended pricing information")
	else
		AuxSellRefreshButton:Enable()	
		
		if selectedAuxEntry then
			local newBuyoutPrice = selectedAuxEntry.itemPrice * currentAuctionItemStackSize

			if selectedAuxEntry.numYours < selectedAuxEntry.count then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95 
			
			AuxMessage:Hide()	
			Aux_ShowElems(Aux.tabs.sell.recommendationElements)
			
			Aux_Recommend_Text:SetText("Recommended Buyout Price")
			Aux_RecommendPerStack_Text:SetText("for your stack of "..currentAuctionItemStackSize)
			
			if currentAuctionItemTexture then
				Aux_RecommendItem_Tex:SetNormalTexture(currentAuctionItemTexture)
				if currentAuctionItemStackSize > 1 then
					Aux_RecommendItem_TexCount:SetText(currentAuctionItemStackSize)
					Aux_RecommendItem_TexCount:Show()
				else
					Aux_RecommendItem_TexCount:Hide()
				end
			else
				Aux_RecommendItem_Tex:Hide()
			end
			
			MoneyFrame_Update("Aux_RecommendPerItem_Price",  Aux_Round(newBuyoutPrice / currentAuctionItemStackSize))
			MoneyFrame_Update("Aux_RecommendPerStack_Price", Aux_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(BuyoutPrice, newBuyoutPrice)
			MoneyInputFrame_SetCopper(StartPrice, newStartPrice)
			
			if selectedAuxEntry.stackSize == auxSellEntries[currentAuctionItemName][1].stackSize and selectedAuxEntry.buyoutPrice == auxSellEntries[currentAuctionItemName][1].buyoutPrice then
				Aux_Recommend_Basis_Text:SetText("(based on cheapest)")
			elseif bestPriceOurStackSize and selectedAuxEntry.stackSize == bestPriceOurStackSize.stackSize and selectedAuxEntry.buyoutPrice == bestPriceOurStackSize.buyoutPrice then
				Aux_Recommend_Basis_Text:SetText("(based on cheapest stack of the same size)")
			else
				Aux_Recommend_Basis_Text:SetText("(based on auction selected below)")
			end
		elseif auxSellEntries[currentAuctionItemName] then
			Aux_SetMessage("No auctions were found for \n\n"..currentAuctionItemName)
		else 
			Aux_HideElems(Aux.tabs.sell.shownElements)
		end
	end
	
	Aux_ScrollbarUpdate()
end

-----------------------------------------

function Aux_OnNewAuctionUpdate()

	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Aux.tabs.sell.index then
		return
	end
	
	if not Aux_Scan_IsIdle() then
		Aux_Scan_Abort()
	end
	
	currentAuctionItemName, currentAuctionItemTexture, currentAuctionItemStackSize = GetAuctionSellItemInfo()

	AuxScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	AuxScanTooltip:SetAuctionSellItem()
	AuxScanTooltip:Show()
	local tooltip = Aux_Scan_ExtractTooltip()
	currentAuctionItemStackSize = Aux_Scan_ItemCharges(tooltip) or currentAuctionItemStackSize
	
	if currentAuctionItemName and not auxSellEntries[currentAuctionItemName] then
		Aux_RefreshEntries()
	end
	
	Aux_SelectAuxEntry()
	Aux_UpdateRecommendation()
end

-----------------------------------------

function Aux_RefreshEntries()
	auxSellEntries[currentAuctionItemName] = nil
	selectedAuxEntry = nil
	
	local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount = GetItemInfo(currentAuctionItemName)

	local currentAuctionClass		= ItemType2AuctionClass(sType)
	local currentAuctionSubclass	= nil -- SubType2AuctionSubclass(currentAuctionClass, sSubType)
	
	Aux_Scan_Start{
			query = Aux_Scan_CreateQuery{
					name = currentAuctionItemName,
					classIndex = currentAuctionClass,
					subclassIndex = currentAuctionSubclass
			},
			onComplete = function(data)
				processScanResults(data, currentAuctionItemName)
				Aux_SelectAuxEntry()
				Aux_UpdateRecommendation()
			end
	}	
end
	
-----------------------------------------

function Aux_ScrollbarUpdate()

	local numrows
	if not currentAuctionItemName or not auxSellEntries[currentAuctionItemName] then
		numrows = 0
	else
		numrows = getn(auxSellEntries[currentAuctionItemName])
	end
	
	FauxScrollFrame_Update(AuxScrollFrame, numrows, 12, 16);

	for line = 1,12 do

		local dataOffset = line + FauxScrollFrame_GetOffset(AuxScrollFrame)	
		local lineEntry = getglobal("AuxSellEntry"..line)
		
		if numrows <= 12 then
			lineEntry:SetWidth(603)
		else
			lineEntry:SetWidth(585)
		end
		
		lineEntry:SetID(dataOffset)
		
		if currentAuctionItemName and dataOffset <= numrows and auxSellEntries[currentAuctionItemName] then
			
			local entry = auxSellEntries[currentAuctionItemName][dataOffset]

			if selectedAuxEntry and entry.itemPrice == selectedAuxEntry.itemPrice and entry.stackSize == selectedAuxEntry.stackSize then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			local lineEntry_stacks	= getglobal("AuxSellEntry"..line.."_Stacks")
			local lineEntry_time	= getglobal("AuxSellEntry"..line.."_Time")
			
			if entry.maxTimeLeft == 1 then
				lineEntry_time:SetText("Short")
			elseif entry.maxTimeLeft == 2 then
				lineEntry_time:SetText("Medium")			
			elseif entry.maxTimeLeft == 3 then
				lineEntry_time:SetText("Long")
			elseif entry.maxTimeLeft == 4 then
				lineEntry_time:SetText("Very Long")
			end
			
			if entry.stackSize == currentAuctionItemStackSize then
				lineEntry_stacks:SetTextColor(0.2, 0.9, 0.2)
			else
				lineEntry_stacks:SetTextColor(1.0, 1.0, 1.0)
			end

			local own
			if entry.numYours == 0 then
				own = ""
			elseif
				entry.numYours == entry.count then
				own = "(yours)"
			else
				own = "(yours: "..entry.numYours..")"
			end
						
			local tx = string.format("%i %s of %i %s", entry.count, Aux_PluralizeIf("stack", entry.count), entry.stackSize, own)
			lineEntry_stacks:SetText(tx)

			MoneyFrame_Update("AuxSellEntry"..line.."_UnitPrice", Aux_Round(entry.buyoutPrice/entry.stackSize))
			MoneyFrame_Update("AuxSellEntry"..line.."_TotalPrice", Aux_Round(entry.buyoutPrice))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
end

-----------------------------------------

function AuxSellEntry_OnClick()
	local entryIndex = this:GetID()

	selectedAuxEntry = auxSellEntries[currentAuctionItemName][entryIndex]

	Aux_UpdateRecommendation()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

-----------------------------------------

function AuxSellRefreshButton_OnClick()
	if not Aux_Scan_IsIdle() then
		Aux_Scan_Abort()
	end
	Aux_RefreshEntries()
	Aux_SelectAuxEntry()
	Aux_UpdateRecommendation()
end

-----------------------------------------

function AuxMoneyFrame_OnLoad()
	this.small = 1
	SmallMoneyFrame_OnLoad()
	MoneyFrame_SetType("AUCTION")
end

--[[***************************************************************

	All function below here are local utility functions.
	These should be declared local at the top of this file.

--*****************************************************************]]

function processScanResults(rawData, auctionItemName)

	auxSellEntries[auctionItemName] = {}
	
	----- Condense the scan rawData into a table that has only a single entry per stacksize/price combo
	
	local condData = {}

	for _,rawDatum in ipairs(rawData) do
		if auctionItemName == rawDatum.name and rawDatum.buyoutPrice > 0 then
			local key = "_"..rawDatum.count.."_"..rawDatum.buyoutPrice
			
			if not condData[key] then
				condData[key] = {
					stackSize 	= rawDatum.count,
					buyoutPrice	= rawDatum.buyoutPrice,
					itemPrice	= rawDatum.buyoutPrice / rawDatum.count,
					maxTimeLeft	= rawDatum.duration,
					count		= 1,
					numYours	= rawDatum.owner == UnitName("player") and 1 or 0
			}
			else
				condData[key].maxTimeLeft = math.max(condData[key].maxTimeLeft, rawDatum.duration)
				condData[key].count = condData[key].count + 1
				if rawDatum.owner == UnitName("player") then
					condData[key].numYours = condData[key].numYours + 1
				end
			end
		end
	end

	----- create a table of these entries sorted by itemPrice
	
	local n = 1
	for _,condDatum in pairs(condData) do
		auxSellEntries[auctionItemName][n] = condDatum
		n = n + 1
	end
	
	table.sort(auxSellEntries[auctionItemName], function(a,b) return a.itemPrice < b.itemPrice end)
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
		Aux_Log("Can't GetAuctionItemClasses")
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
