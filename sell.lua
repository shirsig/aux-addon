Aux.sell = {}

auxSellEntries = {} -- persisted

-----------------------------------------

local bestPriceOurStackSize

local current_auction

-----------------------------------------

local record_auction, undercut, item_class_index, item_subclass_index, set_message, report, select_entry, update_recommendation, refresh_entries, availability, charge_classes, get_stack_size_slider_value

function Aux.sell.on_open()
    AuxSellStackSizeSlider:SetValueStep(1)
    AuxSellStackSizeSliderText:SetText('Stack Size')

    AuxSellStackCountSlider:SetValueStep(1)
    AuxSellStackCountSliderText:SetText('Stack Count')

    Aux.sell.validate_parameters()
end

function Aux.sell.duration_radio_button_on_click(index)
    AuxSellParametersShortDurationRadio:SetChecked(false)
    AuxSellParametersMediumDurationRadio:SetChecked(false)
    AuxSellParametersLongDurationRadio:SetChecked(false)
    if index == 1 then
        AuxSellParametersShortDurationRadio:SetChecked(true)
        AuctionFrameAuctions.duration = 120
        AUX_AUCTION_DURATION = 'short'
    elseif index == 2 then
        AuxSellParametersMediumDurationRadio:SetChecked(true)
        AuctionFrameAuctions.duration = 480
        AUX_AUCTION_DURATION = 'medium'
    else
        AuxSellParametersLongDurationRadio:SetChecked(true)
        AuctionFrameAuctions.duration = 1440
        AUX_AUCTION_DURATION = 'long'
    end
    update_recommendation()
end

function Aux_Sell_AuctionFrameAuctions_OnShow()
	Aux.orig.AuctionFrameAuctions_OnShow()
	Aux_Sell_SetAuctionDuration(AUX_AUCTION_DURATION)
end

-----------------------------------------

function Aux_Sell_SetAuctionDuration(duration)
	if duration == 'short' then
        Aux.sell.duration_radio_button_on_click(1)
	elseif duration == 'medium' then
        Aux.sell.duration_radio_button_on_click(2)
	elseif duration == 'long' then
        Aux.sell.duration_radio_button_on_click(3)
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

function Aux.sell.post_auctions()
	if current_auction and PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.sell.index then
		local name, stack_size, buyout_price, stack_count = current_auction.name, get_stack_size_slider_value(), MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice), AuxSellStackCountSlider:GetValue()
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
			MoneyInputFrame_GetCopper(AuxSellParametersStartPrice),
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

		if bestPrice[get_stack_size_slider_value()] then
			auxSellEntries[current_auction.name].selected = bestPrice[get_stack_size_slider_value()]
			bestPriceOurStackSize = bestPrice[get_stack_size_slider_value()]
		end
	end
end

-----------------------------------------

function get_stack_size_slider_value()
    if current_auction.has_charges then
        return AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()]
    else
        return AuxSellStackSizeSlider:GetValue()
    end
end

function Aux.sell.validate_parameters()
    AuxSellPostButton:Disable()
    AuxSellParametersBuyoutPriceErrorText:Hide()

    if not current_auction then
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) > 0 and MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) > MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) then
        AuxSellParametersBuyoutPriceErrorText:Show()
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) < 1 then
        return
    end

    AuxSellPostButton:Enable()
end

function update_recommendation()
	AuxRecommendStaleText:Hide()

	if not current_auction then
		AuxSellRefreshButton:Disable()
		
		AuxSellItem:SetNormalTexture(nil)
		AuxSellItemName:SetText()
		AuxSellItemCount:SetText()

		MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
		MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)

        AuxSellStackSizeSlider:SetMinMaxValues(0,0)
        AuxSellStackSize:SetNumber(0)
        AuxSellStackCountSlider:SetMinMaxValues(0,0)
        AuxSellStackCount:SetNumber(0)
		
		set_message("Drag an item to the Auction Item area\n\nto see recommended pricing information")
    else
        AuxSellStackSize:SetNumber(AuxSellStackSizeSlider:GetValue())
        AuxSellStackCount:SetNumber(AuxSellStackCountSlider:GetValue())

		AuxSellItem:SetNormalTexture(current_auction.texture)
		AuxSellItemName:SetText(current_auction.name)
		if get_stack_size_slider_value() > 1 then
			AuxSellItemCount:SetText(get_stack_size_slider_value())
			AuxSellItemCount:Show()
		else
			AuxSellItemCount:Hide()
		end
		
		AuxSellRefreshButton:Enable()
		
		MoneyFrame_Update("AuctionsDepositMoneyFrame", floor(current_auction.vendor_price_per_unit * current_auction.deposit_factor * (current_auction.has_charges and 1 or get_stack_size_slider_value())) * AuxSellStackCountSlider:GetValue() * AuctionFrameAuctions.duration / 120)
		
		if auxSellEntries[current_auction.name] and auxSellEntries[current_auction.name].selected then
			if not auxSellEntries[current_auction.name].created or GetTime() - auxSellEntries[current_auction.name].created > 1800 then
				AuxRecommendStaleText:SetText("STALE DATA") -- data older than half an hour marked as stale
				AuxRecommendStaleText:Show()
			end
		
			local newBuyoutPrice = auxSellEntries[current_auction.name].selected.itemPrice * get_stack_size_slider_value()

			if auxSellEntries[current_auction.name].selected.numYours == 0 then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95
			
			AuxMessage:Hide()	
			Aux_ShowElems(Aux.tabs.sell.recommendationElements)
			
			AuxRecommendText:SetText("Recommended Buyout Price")
			AuxRecommendPerStackText:SetText("for a stack of "..get_stack_size_slider_value())
			

			AuxRecommendItemTex:SetNormalTexture(current_auction.texture)
			if AuxSellStackSize:GetNumber() > 1 then
				AuxRecommendItemTexCount:SetText(get_stack_size_slider_value())
				AuxRecommendItemTexCount:Show()
			else
				AuxRecommendItemTexCount:Hide()
			end

			MoneyFrame_Update("AuxRecommendPerItemPrice",  Aux_Round(get_stack_size_slider_value() > 0 and newBuyoutPrice / get_stack_size_slider_value() or 0))
			MoneyFrame_Update("AuxRecommendPerStackPrice", Aux_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, Aux_Round(newBuyoutPrice))
			MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, Aux_Round(newStartPrice))
			
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

function Aux.sell.quantity_update()
    if current_auction then
        AuxSellStackCountSlider:SetMinMaxValues(1, current_auction.has_charges and current_auction.availability[AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider.GetValue()]] or floor(current_auction.availability[0] / get_stack_size_slider_value()))
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
		local auction_sell_item = Aux.info.auction_sell_item()
		ClearCursor()
		ClickAuctionSellItemButton()
		ClearCursor()

		if auction_sell_item then
		
			Aux.scan.abort(function()
		
				current_auction = {
					name = container_item.name,
					texture = container_item.texture,
					class = container_item.type,
					subclass = container_item.subtype,
					deposit_factor = auction_sell_item.deposit_factor,
					vendor_price_per_unit = auction_sell_item.vendor_price_per_unit,
					has_charges = container_item.charges ~= nil,
                    availability = availability(container_item.name)
                }

				AuxSellStackSizeSlider.charge_classes = charge_classes(current_auction.availability)
                AuxSellStackSizeSlider:SetMinMaxValues(1, current_auction.has_charges and getn(charge_classes(current_auction.availability)) or min(container_item.max_stack, current_auction.availability[0]))
                AuxSellStackSizeSlider:SetValue(current_auction.has_charges and Aux.util.index_of(container_item.charges, charge_classes(current_auction.availability)) or container_item.count)
                AuxSellStackCountSlider:SetValue(1)
                Aux.sell.quantity_update()
				
				if not auxSellEntries[current_auction.name] then
					refresh_entries()
				end
					
				select_entry()
				update_recommendation()
				
			end)
		end
	end
end

function charge_classes(availability)
	local charge_classes = {}
	for charge_class, _ in availability do
		tinsert(charge_classes, charge_class)
	end
	sort(charge_classes, function(c1, c2) return c1 < c2 end)
	return charge_classes
end

function availability(name)
    local availability = {}
    for bag = 0, 4 do
        if GetBagName(bag) then
            for slot = 1, GetContainerNumSlots(bag) do
                local item_info = Aux.info.container_item(bag, slot)
                if item_info and item_info.name == name then
                    local charge_class = item_info.charges or 0
                    availability[charge_class] = (availability[charge_class] or 0) + item_info.count
                end
            end
        end
    end
    return availability
end

function refresh_entries()
	if current_auction then
		local name, class, subclass = current_auction.name, current_auction.class, current_auction.subclass
		
		auxSellEntries[name] = nil
		
		class, subclass = GetItemInfo(name)

		-- local class_index = item_class_index(current_auction.class)
		-- local subclass_index = item_subclass_index(class_index, current_auction.subclass)

		set_message('Scanning auctions ...')
		Aux.scan.start{
			query = {
				name = name,
				class = class_index,
				subclass = subclass_index,
			},
			page = 0,
			on_start_page = function(page, total_pages)
				set_message('Scanning auctions: page ' .. page + 1 .. (total_pages > 0 and ' out of ' .. total_pages or '') .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)
				if auction_item and auction_item.name == name then
					local stack_size = auction_item.charges or auction_item.count
					record_auction(auction_item.name, stack_size, auction_item.buyout_price, auction_item.duration, auction_item.owner)
				end
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
			
			if entry.stackSize == get_stack_size_slider_value() then
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
	Aux.scan.abort(function()
		refresh_entries()
		select_entry()
		update_recommendation()
	end)
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

-- function item_class_index(item_class)
	-- for i, class in ipairs({ GetAuctionItemClasses() }) do
		-- if class == item_class then
			-- return i
		-- end
	-- end
-- end

-- -----------------------------------------

-- function item_subclass_index(class_index, item_subclass)
	-- for i, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
		-- if subclass == item_subclass then
			-- return i
		-- end
	-- end
-- end

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
