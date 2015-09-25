auxSellEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize

local currentAuction

-----------------------------------------

local processScanResults, undercut, ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Aux_Sell_OnOpen()
end

-----------------------------------------

function Aux_Sell_AuctionFrameAuctions_OnShow()
	Aux.orig.AuctionFrameAuctions_OnShow()
	Aux_Sell_SetAuctionDuration(AUX_AUCTION_DURATION)
end

-----------------------------------------

function Aux_Sell_SetAuctionDuration(duration)
	if duration == 'short' then
		Aux_Sell_AuctionsRadioButton_OnClick(1)
	elseif duration == 'medium' then
		Aux_Sell_AuctionsRadioButton_OnClick(2)
	elseif duration == 'long' then
		Aux_Sell_AuctionsRadioButton_OnClick(3)
	end
end

-----------------------------------------

function Aux_Sell_AuctionsRadioButton_OnClick(index)
	if index == 1 then
		AUX_AUCTION_DURATION = 'short'
	elseif index == 2 then
		AUX_AUCTION_DURATION = 'medium'
	elseif index == 3 then
		AUX_AUCTION_DURATION = 'long'
	end
	
	return Aux.orig.AuctionsRadioButton_OnClick(index)
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
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index then	
		local name, stackSize, buyoutPrice = currentAuction.name, currentAuction.stackSize, MoneyInputFrame_GetCopper(BuyoutPrice)
		local duration
		if AuctionFrameAuctions.duration == 120 then
			duration = 2
		elseif AuctionFrameAuctions.duration == 480 then
			duration = 3
		elseif AuctionFrameAuctions.duration == 1440 then
			duration = 4
		end
		
		Aux.post.start(
			currentAuction.name,
			currentAuction.stackSize,
			AuctionFrameAuctions.duration,
			MoneyInputFrame_GetCopper(StartPrice),
			MoneyInputFrame_GetCopper(BuyoutPrice),
			currentAuction.stackCount,
			function(posted)
				local entry
				for _, existingEntry in ipairs(auxSellEntries[name]) do
					if existingEntry.buyoutPrice == buyoutPrice and existingEntry.stackSize == stackSize then
						existingEntry.count = existingEntry.count + posted
						existingEntry.numYours = existingEntry.numYours + posted
						existingEntry.duration = max(existingEntry.duration, duration)
						newEntry = existingEntry
					end
				end
				if not entry then
					entry = {
						stackSize 	= stackSize,
						buyoutPrice	= buyoutPrice,
						itemPrice	= buyoutPrice / stackSize,
						maxTimeLeft	= duration,
						count		= posted,
						numYours	= posted,
					}
					tinsert(auxSellEntries[name], entry)
				end
				auxSellEntries[name].selected = entry
				Aux_UpdateRecommendation()
			end
		)
	else
		Aux.orig.AuctionsCreateAuctionButton_OnClick()
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
	
	if currentAuction and auxSellEntries[currentAuction.name] and not auxSellEntries[currentAuction.name].selected then
		local bestPrice	= {} -- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,auxEntry in ipairs(auxSellEntries[currentAuction.name]) do
			if not bestPrice[auxEntry.stackSize] or bestPrice[auxEntry.stackSize].itemPrice >= auxEntry.itemPrice then
				bestPrice[auxEntry.stackSize] = auxEntry
			end
		
			if not absoluteBest or absoluteBest.itemPrice > auxEntry.itemPrice then
				absoluteBest = auxEntry
			end	
		end
		
		auxSellEntries[currentAuction.name].selected = absoluteBest

		if bestPrice[currentAuction.stackSize] then
			auxSellEntries[currentAuction.name].selected = bestPrice[currentAuction.stackSize]
			bestPriceOurStackSize = bestPrice[currentAuction.stackSize]
		end
	end
end

-----------------------------------------

function Aux_UpdateRecommendation()
	AuxRecommendStaleText:Hide()

	if not currentAuction then
		AuxSellRefreshButton:Disable()
		
		Aux_Sell_SetStackSize(0)
		Aux_Sell_SetStackCount(0)
		Aux_SetMessage("Drag an item to the Auction Item area\n\nto see recommended pricing information")
	else
		AuxSellRefreshButton:Enable()	
		
		Aux_Sell_SetStackSize(currentAuction.stackSize)
		Aux_Sell_SetStackCount(currentAuction.stackCount)
		
		if auxSellEntries[currentAuction.name] and auxSellEntries[currentAuction.name].selected then
			if not auxSellEntries[currentAuction.name].created or GetTime() - auxSellEntries[currentAuction.name].created > 1800 then
				AuxRecommendStaleText:SetText("STALE DATA") -- data older than half an hour marked as stale
				AuxRecommendStaleText:Show()
			end
		
			local newBuyoutPrice = auxSellEntries[currentAuction.name].selected.itemPrice * currentAuction.stackSize

			if auxSellEntries[currentAuction.name].selected.numYours < auxSellEntries[currentAuction.name].selected.count then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95 
			
			AuxMessage:Hide()	
			Aux_ShowElems(Aux.tabs.sell.recommendationElements)
			
			AuxRecommendText:SetText("Recommended Buyout Price")
			AuxRecommendPerStackText:SetText("for your stack of "..currentAuction.stackSize)
			
			if currentAuction.texture then
				AuxRecommendItemTex:SetNormalTexture(currentAuction.texture)
				if currentAuction.stackSize > 1 then
					AuxRecommendItemTexCount:SetText(currentAuction.stackSize)
					AuxRecommendItemTexCount:Show()
				else
					AuxRecommendItemTexCount:Hide()
				end
			else
				AuxRecommendItemTex:Hide()
			end
			
			MoneyFrame_Update("AuxRecommendPerItemPrice",  Aux_Round(newBuyoutPrice / currentAuction.stackSize))
			MoneyFrame_Update("AuxRecommendPerStackPrice", Aux_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(BuyoutPrice, newBuyoutPrice)
			MoneyInputFrame_SetCopper(StartPrice, newStartPrice)
			
			if auxSellEntries[currentAuction.name].selected.stackSize == auxSellEntries[currentAuction.name][1].stackSize and auxSellEntries[currentAuction.name].selected.buyoutPrice == auxSellEntries[currentAuction.name][1].buyoutPrice then
				AuxRecommendBasisText:SetText("(based on cheapest)")
			elseif bestPriceOurStackSize and auxSellEntries[currentAuction.name].selected.stackSize == bestPriceOurStackSize.stackSize and auxSellEntries[currentAuction.name].selected.buyoutPrice == bestPriceOurStackSize.buyoutPrice then
				AuxRecommendBasisText:SetText("(based on cheapest stack of the same size)")
			else
				AuxRecommendBasisText:SetText("(based on auction selected below)")
			end
		elseif auxSellEntries[currentAuction.name] then
			Aux_SetMessage("No auctions were found for \n\n"..currentAuction.name)
			auxSellEntries[currentAuction.name] = nil
		else 
			Aux_HideElems(Aux.tabs.sell.shownElements)
		end
	end
	
	Aux_ScrollbarUpdate()
end

-----------------------------------------

function Aux_Sell_GetStackSize()
	return AuxSellStackSize:GetNumber()
end

-----------------------------------------

function Aux_Sell_SetStackSize(stackSize)
	return AuxSellStackSize:SetNumber(stackSize)
end

-----------------------------------------

function Aux_Sell_GetStackCount()
	return AuxSellStackCount:GetNumber()
end

-----------------------------------------

function Aux_Sell_SetStackCount(stackCount)
	return AuxSellStackCount:SetNumber(stackCount)
end

-----------------------------------------

function Aux_Sell_QuantityUpdate()
	if currentAuction then
		currentAuction.stackSize = Aux_Sell_GetStackSize()
		currentAuction.stackCount = Aux_Sell_GetStackCount()
	end
	
	Aux_SelectAuxEntry()
	Aux_UpdateRecommendation()
end

-----------------------------------------

function Aux_OnNewAuctionUpdate()

	if PanelTemplates_GetSelectedTab(AuctionFrame) ~= Aux.tabs.sell.index then
		return
	end
	
	if not Aux_Scan_IsIdle() then
		Aux_Scan_Abort()
	end
	
	local auctionItemName, auctionItemTexture, auctionItemStackSize = GetAuctionSellItemInfo()
	
	Aux_Scan_ClearTooltip()
	AuxScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	AuxScanTooltip:SetAuctionSellItem()
	AuxScanTooltip:Show()
	local tooltip = Aux_Scan_ExtractTooltip()

	currentAuction = auctionItemName and {
		name = auctionItemName,
		texture = auctionItemTexture,
		stackSize = Aux_Scan_ItemCharges(tooltip) or auctionItemStackSize,
		stackCount = 1,
	}
	
	if currentAuction and not auxSellEntries[currentAuction.name] then
		Aux_RefreshEntries()
	end
		
	Aux_SelectAuxEntry()
	Aux_UpdateRecommendation()
end

-----------------------------------------

function Aux_RefreshEntries()
	if currentAuction then
		auxSellEntries[currentAuction.name] = nil
		
		local _, _, _, _, _, sType, sSubType = GetItemInfo(currentAuction.name)

		local currentAuctionClass		= ItemType2AuctionClass(sType)
		local currentAuctionSubclass	= nil -- SubType2AuctionSubclass(currentAuctionClass, sSubType)
		
		Aux_Scan_Start{
				query = Aux_Scan_CreateQuery{
						name = currentAuction.name,
						classIndex = currentAuctionClass,
						subclassIndex = currentAuctionSubclass
				},
				onComplete = function(data)
					processScanResults(data, currentAuction.name)
					Aux_SelectAuxEntry()
					Aux_UpdateRecommendation()
				end
		}
	end
end
	
-----------------------------------------

function Aux_ScrollbarUpdate()

	local numrows
	if not currentAuction or not auxSellEntries[currentAuction.name] then
		numrows = 0
	else
		numrows = getn(auxSellEntries[currentAuction.name])
	end
	
	FauxScrollFrame_Update(AuxScrollFrame, numrows, 12, 16)

	for line = 1, 12 do

		local dataOffset = line + FauxScrollFrame_GetOffset(AuxScrollFrame)	
		local lineEntry = getglobal("AuxSellEntry"..line)
		
		if numrows <= 12 then
			lineEntry:SetWidth(603)
		else
			lineEntry:SetWidth(585)
		end
		
		lineEntry:SetID(dataOffset)
		
		if currentAuction and dataOffset <= numrows and auxSellEntries[currentAuction.name] then
			
			local entry = auxSellEntries[currentAuction.name][dataOffset]

			if auxSellEntries[currentAuction.name].selected and entry.itemPrice == auxSellEntries[currentAuction.name].selected.itemPrice and entry.stackSize == auxSellEntries[currentAuction.name].selected.stackSize then
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
			
			if entry.stackSize == currentAuction.stackSize then
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

	auxSellEntries[currentAuction.name].selected = auxSellEntries[currentAuction.name][entryIndex]

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

	auxSellEntries[auctionItemName] = { created=GetTime() }
	
	----- Condense the scan rawData into a table that has only a single entry per stacksize/price combo
	
	local condData = {}

	for _, rawDatum in ipairs(rawData) do
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
	for _, condDatum in pairs(condData) do
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
