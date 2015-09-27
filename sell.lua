Aux.sell = {}

auxSellEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize

local currentAuction

-----------------------------------------

local record_auction, undercut, ItemType2AuctionClass, SubType2AuctionSubclass

-----------------------------------------

function Aux.sell.on_open()
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

function Aux.sell.AuctionsCreateAuctionButton_OnClick()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index then	
		local name, stack_size, buyout_price = currentAuction.name, currentAuction.stackSize, MoneyInputFrame_GetCopper(BuyoutPrice)
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
				for i = 1, posted do
					record_auction(name, stack_size, buyout_price, duration, UnitName("player"))
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

function Aux.sell.AuctionSellItemButton_OnEvent()
	Aux.orig.AuctionSellItemButton_OnEvent()
	Aux_OnNewAuctionUpdate()
end

-----------------------------------------

function Aux.sell.set_message(msg)
	Aux_HideElems(Aux.tabs.sell.recommendationElements)
	AuxMessage:SetText(msg)
	AuxMessage:Show()
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
		Aux.sell.set_message("Drag an item to the Auction Item area\n\nto see recommended pricing information")
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

			if auxSellEntries[currentAuction.name].selected.numYours == 0 then
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
			Aux.sell.set_message("No auctions were found for \n\n"..currentAuction.name)
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
	
	if not Aux.scan.idle() then
		Aux.scan.abort()
	end
	
	local auctionItemName, auctionItemTexture, auctionItemStackSize = GetAuctionSellItemInfo()
	local auction_sell_item = Aux.info.auction_sell_item()

	currentAuction = auction_sell_item.name and {
		name = auction_sell_item.name,
		texture = auction_sell_item.texture,
		stackSize = auction_sell_item.charges or auction_sell_item.count,
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
		local name = currentAuction.name
		
		auxSellEntries[name] = nil
		
		local _, _, _, _, _, sType, sSubType = GetItemInfo(name)

		local currentAuctionClass		= ItemType2AuctionClass(sType)
		local currentAuctionSubclass	= nil -- SubType2AuctionSubclass(currentAuctionClass, sSubType)

		Aux.sell.set_message('Scanning auctions ...')
		Aux.scan.start{
				query = Aux.scan.create_query{
						name = name,
						classIndex = currentAuctionClass,
						subclassIndex = currentAuctionSubclass
				},
				on_start_page = function(i)
					Aux.sell.set_message('Scanning auctions: page ' .. i .. ' ...')
				end,
				on_read_auction = function(i)
					local auction_item = Aux.info.auction_item(i)
					if auction_item.name == name then
						local stack_size = auction_item.charges or auction_item.count
						record_auction(auction_item.name, stack_size, auction_item.buyout_price, auction_item.duration, auction_item.owner)
					end
				end,
				on_abort = function()
					auxSellEntries[name] = nil
				end,
				on_complete = function()
					auxSellEntries[name] = auxSellEntries[name] or { created = GetTime() }
					Aux_SelectAuxEntry()
					Aux_UpdateRecommendation()
				end,
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
	if not Aux.scan.idle() then
		Aux.scan.abort()
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

function record_auction(name, stack_size, buyout_price, duration, owner)
	if buyout_price > 0 then
		auxSellEntries[name] = auxSellEntries[name] or { created = GetTime() }
		local entry
		for _, existingEntry in ipairs(auxSellEntries[name]) do
			if existingEntry.buyoutPrice == buyout_price and existingEntry.stackSize == stack_size then
				entry = existingEntry
			end
		end
		if entry then
			entry.count = entry.count + 1
			entry.numYours = entry.numYours + (owner == UnitName("player") and 1 or 0)
			entry.maxTimeLeft = max(entry.maxTimeLeft, duration)
		else
			entry = {
				stackSize 	= stack_size,
				buyoutPrice	= buyout_price,
				itemPrice	= buyout_price / stack_size,
				maxTimeLeft	= duration,
				count		= 1,
				numYours	= owner == UnitName("player") and 1 or 0,
			}
			tinsert(auxSellEntries[name], entry)
			table.sort(auxSellEntries[name], function(a,b) return a.itemPrice < b.itemPrice end)
		end
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
