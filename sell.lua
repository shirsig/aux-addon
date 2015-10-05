Aux.sell = {}

auxSellEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize

local current_auction

-----------------------------------------

local record_auction, undercut, item_class_index, item_subclass_index, set_message, report, select_entry, update_recommendation, refresh_entries

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
	
	Aux.orig.AuctionsRadioButton_OnClick(index)
	update_recommendation()
end

-----------------------------------------

function Aux_AuctionFrameAuctions_Update()
	Aux.orig.AuctionFrameAuctions_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.sell.hiddenElements)
	end
end

-----------------------------------------

function Aux.sell.post_auctions()
	if current_auction and PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index then
		local name, stack_size, buyout_price, stack_count = current_auction.name, current_auction.stackSize, MoneyInputFrame_GetCopper(BuyoutPrice), current_auction.stackCount
		local duration
		if AuctionFrameAuctions.duration == 120 then
			duration = 2
		elseif AuctionFrameAuctions.duration == 480 then
			duration = 3
		elseif AuctionFrameAuctions.duration == 1440 then
			duration = 4
		end
		
		Aux.post.start(
			name,
			stack_size,
			AuctionFrameAuctions.duration,
			MoneyInputFrame_GetCopper(StartPrice),
			buyout_price,
			stack_count,
			function(posted)
				for i = 1, posted do
					record_auction(name, stack_size, buyout_price, duration, UnitName("player"))
				end
				if auxSellEntries[name] then
					for _, entry in ipairs(auxSellEntries[name]) do
						if entry.buyout_price == buyout_price and entry.stack_size == stack_size then
							auxSellEntries[name].selected = entry
						end
					end
				end
				Aux.sell.clear_auction()
				report(name, stack_size, buyout_price, posted)
			end
		)
	else
		Aux.orig.AuctionsCreateAuctionButton_OnClick()
	end
end

-----------------------------------------

function Aux.sell.AuctionSellItemButton_OnEvent()
	Aux.orig.AuctionSellItemButton_OnEvent()
end

-----------------------------------------

function set_message(msg)
	Aux_HideElems(Aux.tabs.sell.recommendationElements)
	AuxMessage:SetText(msg)
	AuxMessage:Show()
end

-----------------------------------------

function select_entry()
	
	if current_auction and auxSellEntries[current_auction.name] and not auxSellEntries[current_auction.name].selected then
		local bestPrice	= {} -- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,auxEntry in ipairs(auxSellEntries[current_auction.name]) do
			if not bestPrice[auxEntry.stackSize] or bestPrice[auxEntry.stackSize].itemPrice >= auxEntry.itemPrice then
				bestPrice[auxEntry.stackSize] = auxEntry
			end
		
			if not absoluteBest or absoluteBest.itemPrice > auxEntry.itemPrice then
				absoluteBest = auxEntry
			end	
		end
		
		auxSellEntries[current_auction.name].selected = absoluteBest

		if bestPrice[current_auction.stackSize] then
			auxSellEntries[current_auction.name].selected = bestPrice[current_auction.stackSize]
			bestPriceOurStackSize = bestPrice[current_auction.stackSize]
		end
	end
end

-----------------------------------------

function update_recommendation()
	AuxRecommendStaleText:Hide()

	if not current_auction then
		AuxSellRefreshButton:Disable()
		
		AuxSellItem:SetNormalTexture(nil)
		AuxSellItemName:SetText()
		AuxSellItemCount:SetText()

		MoneyInputFrame_SetCopper(BuyoutPrice, 0)
		MoneyInputFrame_SetCopper(StartPrice, 0)
		
		Aux_Sell_SetStackSize(0)
		Aux_Sell_SetStackCount(0)
		
		set_message("Drag an item to the Auction Item area\n\nto see recommended pricing information")
	else
		AuxSellItem:SetNormalTexture(current_auction.texture)
		AuxSellItemName:SetText(current_auction.name)
		if current_auction.stackSize > 1 then
			AuxSellItemCount:SetText(current_auction.stackSize)
			AuxSellItemCount:Show()
		else
			AuxSellItemCount:Hide()
		end
		
		AuxSellRefreshButton:Enable()	
		
		Aux_Sell_SetStackSize(current_auction.stackSize)
		Aux_Sell_SetStackCount(current_auction.stackCount)
		
		MoneyFrame_Update("AuctionsDepositMoneyFrame", current_auction.base_deposit * current_auction.stackCount * (current_auction.has_charges and 1 or current_auction.stackSize) * AuctionFrameAuctions.duration / 120)
		
		if auxSellEntries[current_auction.name] and auxSellEntries[current_auction.name].selected then
			if not auxSellEntries[current_auction.name].created or GetTime() - auxSellEntries[current_auction.name].created > 1800 then
				AuxRecommendStaleText:SetText("STALE DATA") -- data older than half an hour marked as stale
				AuxRecommendStaleText:Show()
			end
		
			local newBuyoutPrice = auxSellEntries[current_auction.name].selected.itemPrice * current_auction.stackSize

			if auxSellEntries[current_auction.name].selected.numYours == 0 then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95
			
			AuxMessage:Hide()	
			Aux_ShowElems(Aux.tabs.sell.recommendationElements)
			
			AuxRecommendText:SetText("Recommended Buyout Price")
			AuxRecommendPerStackText:SetText("for a stack of "..current_auction.stackSize)
			

			AuxRecommendItemTex:SetNormalTexture(current_auction.texture)
			if current_auction.stackSize > 1 then
				AuxRecommendItemTexCount:SetText(current_auction.stackSize)
				AuxRecommendItemTexCount:Show()
			else
				AuxRecommendItemTexCount:Hide()
			end

			MoneyFrame_Update("AuxRecommendPerItemPrice",  Aux_Round(current_auction.stackSize > 0 and newBuyoutPrice / current_auction.stackSize or 0))
			MoneyFrame_Update("AuxRecommendPerStackPrice", Aux_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(BuyoutPrice, Aux_Round(newBuyoutPrice))
			MoneyInputFrame_SetCopper(StartPrice, Aux_Round(newStartPrice))
			
			if auxSellEntries[current_auction.name].selected.stackSize == auxSellEntries[current_auction.name][1].stackSize and auxSellEntries[current_auction.name].selected.buyoutPrice == auxSellEntries[current_auction.name][1].buyoutPrice then
				AuxRecommendBasisText:SetText("(based on cheapest)")
			elseif bestPriceOurStackSize and auxSellEntries[current_auction.name].selected.stackSize == bestPriceOurStackSize.stackSize and auxSellEntries[current_auction.name].selected.buyoutPrice == bestPriceOurStackSize.buyoutPrice then
				AuxRecommendBasisText:SetText("(based on cheapest stack of the same size)")
			else
				AuxRecommendBasisText:SetText("(based on auction selected below)")
			end
		elseif auxSellEntries[current_auction.name] then
			set_message("No auctions were found for \n\n"..current_auction.name)
			auxSellEntries[current_auction.name] = nil
		else 
			Aux_HideElems(Aux.tabs.sell.shownElements)
		end
	end
	
	Aux.sell.scrollbar_update()
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
	if current_auction then
		current_auction.stackSize = Aux_Sell_GetStackSize()
		current_auction.stackCount = Aux_Sell_GetStackCount()
	end
	
	select_entry()
	update_recommendation()
end

-----------------------------------------

function Aux.sell.clear_auction()
	current_auction = nil
	select_entry()
	update_recommendation()
end

-----------------------------------------

function Aux.sell.set_auction(bag, slot)

	local container_item = Aux.info.container_item(bag, slot)
	
	if container_item then

		ClearCursor()
		PickupContainerItem(bag,slot)
		ClickAuctionSellItemButton()
		local auction_sell_item = Aux.info.auction_sell_item() -- TODO
		ClickAuctionSellItemButton()
		ClearCursor()

		if auction_sell_item then
		
			Aux.scan.abort()
		
			current_auction = {
				name = container_item.name,
				texture = container_item.texture,
				stackSize = container_item.charges or container_item.count,
				stackCount = 1,
				class = container_item.type,
				subclass = container_item.subtype,
				base_deposit = auction_sell_item.base_deposit,
				has_charges = container_item.charges ~= nil,
			}
			
			if current_auction and not auxSellEntries[current_auction.name] then
				refresh_entries()
			end
				
			select_entry()
			update_recommendation()
		end
	end
end

-----------------------------------------

function refresh_entries()
	if current_auction then
		local name, class, subclass = current_auction.name, current_auction.class, current_auction.subclass
		
		auxSellEntries[name] = nil
		
		class, subclass = GetItemInfo(name)

		local class_index = item_class_index(current_auction.class)
		local subclass_index = item_subclass_index(class_index, current_auction.subclass)

		set_message('Scanning auctions ...')
		Aux.scan.start{
			query = {
				name = name,
				class = class_index,
				subclass = subclass_index,
			},
			page = 0,
			on_start_page = function(k, i)
				set_message('Scanning auctions: page ' .. i + 1 .. (total_pages and ' out of ' .. total_pages or '') .. ' ...')
				return k()
			end,
			on_read_auction = function(k, i)
				local auction_item = Aux.info.auction_item(i)
				if auction_item and auction_item.name == name then
					local stack_size = auction_item.charges or auction_item.count
					record_auction(auction_item.name, stack_size, auction_item.buyout_price, auction_item.duration, auction_item.owner)
				end
				return k()
			end,
			on_abort = function()
				auxSellEntries[name] = nil
			end,
			on_complete = function()
				auxSellEntries[name] = auxSellEntries[name] or { created = GetTime() }
				select_entry()
				update_recommendation()
			end,
			next_page = function(page, total_pages)
				local last_page = max(total_pages - 1, 0)
				if page < last_page then
					return page + 1
				end
			end,
		}
	end
end
	
-----------------------------------------

function Aux.sell.scrollbar_update()

	local numrows
	if not current_auction or not auxSellEntries[current_auction.name] then
		numrows = 0
	else
		numrows = getn(auxSellEntries[current_auction.name])
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
		
		if current_auction and dataOffset <= numrows and auxSellEntries[current_auction.name] then
			
			local entry = auxSellEntries[current_auction.name][dataOffset]

			if auxSellEntries[current_auction.name].selected and entry.itemPrice == auxSellEntries[current_auction.name].selected.itemPrice and entry.stackSize == auxSellEntries[current_auction.name].selected.stackSize then
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
			
			if entry.stackSize == current_auction.stackSize then
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

	auxSellEntries[current_auction.name].selected = auxSellEntries[current_auction.name][entryIndex]

	update_recommendation()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

-----------------------------------------

function AuxSellRefreshButton_OnClick()
	Aux.scan.abort()
	refresh_entries()
	select_entry()
	update_recommendation()
end

-----------------------------------------

function AuxMoneyFrame_OnLoad()
	this.small = 1
	SmallMoneyFrame_OnLoad()
	MoneyFrame_SetType("AUCTION")
end

-----------------------------------------

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

function item_class_index(item_class)
	for i, class in ipairs({ GetAuctionItemClasses() }) do
		if class == item_class then
			return i
		end
	end
end

-----------------------------------------

function item_subclass_index(class_index, item_subclass)
	for i, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
		if subclass == item_subclass then
			return i
		end
	end
end

-----------------------------------------

function report(item_name, stack_size, buyout_price, posted)
	AuxSellReportHTML:SetText(string.format(
			[[
			<html>
			<body>
				<h1>Aux Sell Report</h1>
				<br/>
				<p>
					%i auctions of %s posted
					<br/><br/>
					Stack size: %i
					<br/>
					Stack price: %s
				</p>
			</body>
			</html>
			]],
			posted,
			item_name,
			stack_size,
			Aux.util.format_money(buyout_price)
	))
		
	AuxSellReportHTML:SetSpacing(3)
	
	AuxSellReport:Show()
end
