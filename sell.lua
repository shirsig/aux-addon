Aux.sell = {}

auxSellEntries = {} -- persisted

local inventory_data

local bestPriceOurStackSize

local current_auction

local set_auction, update_auction_listing, update_inventory_listing, record_auction, undercut, item_class_index, item_subclass_index, report, select_entry, update_recommendation, refresh_entries, auction_candidates, charge_classes, get_stack_size_slider_value

Aux.sell.inventory_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        set_auction(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        if not (current_auction and sheet.data[data_index] == current_auction) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
    end,

    row_setter = function(row, datum)
        if current_auction and datum == current_auction then
            row.highlight:SetAlpha(.5)
        else
            row.highlight:SetAlpha(0)
        end
    end,

    columns = {
        {
            title = 'Item',
            width = 175,
            comparator = function(row1, row2) return Aux.util.compare(row1.name, row2.name, Aux.util.GT) end,
            cell_initializer = function(cell)
                local icon = CreateFrame('Button', nil, cell)
                local icon_texture = icon:CreateTexture(nil, 'BORDER')
                icon_texture:SetAllPoints(icon)
                icon.icon_texture = icon_texture
                local normal_texture = icon:CreateTexture(nil)
                normal_texture:SetPoint('CENTER', 0, 0)
                normal_texture:SetWidth(22)
                normal_texture:SetHeight(22)
                normal_texture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
                icon:SetNormalTexture(normal_texture)
                icon:SetPoint('LEFT', cell)
                icon:SetWidth(12)
                icon:SetHeight(12)
                icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                text:SetPoint('TOPRIGHT', cell)
                text:SetPoint('BOTTOMRIGHT', cell)
                text:SetJustifyV('TOP')
                text:SetJustifyH('LEFT')
                text:SetTextColor(0.8, 0.8, 0.8)
                cell.text = text
                cell.icon = icon
            end,
            cell_setter = function(cell, datum)
                cell.icon.icon_texture:SetTexture(datum.texture)
                cell.text:SetText('['..datum.name..']')
                local color = ITEM_QUALITY_COLORS[datum.quality]
                cell.text:SetTextColor(color.r, color.g, color.b)
            end,
        },
        {
            title = 'Qty',
            width = 23,
            comparator = function(datum1, datum2) return Aux.util.compare(datum1.aux_quantity, datum2.aux_quantity, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.aux_quantity)
            end,
        },
    },
    sort_order = {{column = 1, order = 'ascending' }},
}

Aux.sell.auction_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxSellEntry_OnClick(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        if not (current_auction and auxSellEntries[current_auction.name] and sheet.data[data_index] == auxSellEntries[current_auction.name].selected) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
    end,

    row_setter = function(row, datum)
        if datum and current_auction and auxSellEntries[current_auction.name] and auxSellEntries[current_auction.name].selected == datum then
            row.highlight:SetAlpha(.5)
        else
            row.highlight:SetAlpha(0)
        end
    end,

    columns = {
        {
            title = 'Avail',
            width = 40,
            comparator = function(row1, row2) return Aux.util.compare(row1.count, row2.count, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.count)
            end,
        },
        {
            title = 'Yours',
            width = 40,
            comparator = function(row1, row2) return Aux.util.compare(row1.yours, row2.yours, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.yours)
            end,
        },
        {
            title = 'Max Left',
            width = 55,
            comparator = function(row1, row2) return Aux.util.compare(row1.max_time_left, row2.max_time_left, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
            cell_setter = function(cell, datum)
                local text
                if datum.max_time_left == 1 then
                    text = '30m'
                elseif datum.max_time_left == 2 then
                    text = '2h'
                elseif datum.max_time_left == 3 then
                    text = '8h'
                elseif datum.max_time_left == 4 then
                    text = '24h'
                end
                cell.text:SetText(text)
            end,
        },
        {
            title = 'Buy/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.unit_buyout_price, row2.unit_buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(Aux.util.money_string(row.unit_buyout_price))
            end,
        },
        {
            title = 'Qty',
            width = 23,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.stack_size)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(Aux.util.money_string(row.buyout_price))
            end,
        },
    },
    sort_order = {{column = 2, order = 'ascending' }, {column = 4, order = 'ascending'}},
}

function update_inventory_listing()
    Aux.list.populate(AuxSellInventoryListing.sheet, inventory_data)
end

function update_auction_listing()
    Aux.list.populate(AuxSellAuctionsListing.sheet, current_auction and auxSellEntries[current_auction.name] or {})
end

function Aux.sell.on_open()
    AuxSellStackSizeSlider:SetValueStep(1)
    AuxSellStackSizeSliderText:SetText('Stack Size')

    AuxSellStackCountSlider:SetValueStep(1)
    AuxSellStackCountSliderText:SetText('Stack Count')

    Aux.sell.validate_parameters()

    inventory_data = auction_candidates()

    update_inventory_listing()
    update_auction_listing()
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
	if current_auction then
		local name, hyperlink, stack_size, buyout_price, stack_count = current_auction.name, current_auction.hyperlink, get_stack_size_slider_value(), MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice), AuxSellStackCountSlider:GetValue()
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
				report(hyperlink, stack_size, buyout_price, posted)
			end
		)
	end
end

-----------------------------------------

function Aux.sell.AuctionSellItemButton_OnEvent()
	Aux.orig.AuctionSellItemButton_OnEvent()
end

function select_entry()
	
	if current_auction and auxSellEntries[current_auction.name] and not auxSellEntries[current_auction.name].selected then
		local bestPrice	= {} -- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _,auxEntry in ipairs(auxSellEntries[current_auction.name]) do
			if not bestPrice[auxEntry.stack_size] or bestPrice[auxEntry.stack_size].unit_buyout_price >= auxEntry.unit_buyout_price then
				bestPrice[auxEntry.stack_size] = auxEntry
			end
		
			if not absoluteBest or absoluteBest.unit_buyout_price > auxEntry.unit_buyout_price then
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
    if current_auction.charges then
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
		
		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetText()

		MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
		MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)

        AuxSellStackSizeSlider:SetMinMaxValues(0,0)
        AuxSellStackSize:SetNumber(0)
        AuxSellStackCountSlider:SetMinMaxValues(0,0)
        AuxSellStackCount:SetNumber(0)
    else
        AuxSellStackSize:SetNumber(AuxSellStackSizeSlider:GetValue())
        AuxSellStackCount:SetNumber(AuxSellStackCountSlider:GetValue())

        AuxSellParametersItemIconTexture:SetTexture(current_auction.texture)
        AuxSellParametersItemName:SetText(current_auction.name)
        local color = ITEM_QUALITY_COLORS[current_auction.quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if get_stack_size_slider_value() > 1 then
            AuxSellParametersItemCount:SetText(get_stack_size_slider_value())
            AuxSellParametersItemCount:Show()
		else
            AuxSellParametersItemCount:Hide()
		end
		
		AuxSellRefreshButton:Enable()
		
		MoneyFrame_Update("AuctionsDepositMoneyFrame", floor(current_auction.vendor_price_per_unit * current_auction.deposit_factor * (current_auction.charges and 1 or get_stack_size_slider_value())) * AuxSellStackCountSlider:GetValue() * AuctionFrameAuctions.duration / 120)
		
		if auxSellEntries[current_auction.name] and auxSellEntries[current_auction.name].selected then
			if not auxSellEntries[current_auction.name].created or GetTime() - auxSellEntries[current_auction.name].created > 1800 then
				AuxRecommendStaleText:SetText("STALE DATA") -- data older than half an hour marked as stale
				AuxRecommendStaleText:Show()
			end
		
			local newBuyoutPrice = auxSellEntries[current_auction.name].selected.unit_buyout_price * get_stack_size_slider_value()

			if auxSellEntries[current_auction.name].selected.yours == 0 then
				newBuyoutPrice = undercut(newBuyoutPrice)
			end
			
			local newStartPrice = newBuyoutPrice * 0.95
			
			Aux_ShowElems(Aux.tabs.sell.recommendationElements)
			
--			AuxRecommendText:SetText("Recommended Buyout Price")
--			AuxRecommendPerStackText:SetText("for a stack of "..get_stack_size_slider_value())
			

--			AuxRecommendItemTex:SetNormalTexture(current_auction.texture)
--			if AuxSellStackSize:GetNumber() > 1 then
--				AuxRecommendItemTexCount:SetText(get_stack_size_slider_value())
--				AuxRecommendItemTexCount:Show()
--			else
--				AuxRecommendItemTexCount:Hide()
--			end

--			MoneyFrame_Update("AuxRecommendPerItemPrice",  Aux_Round(get_stack_size_slider_value() > 0 and newBuyoutPrice / get_stack_size_slider_value() or 0))
--			MoneyFrame_Update("AuxRecommendPerStackPrice", Aux_Round(newBuyoutPrice))
			
			MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, Aux_Round(newBuyoutPrice))
			MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, Aux_Round(newStartPrice))
			
--			if auxSellEntries[current_auction.name].selected.stack_size == auxSellEntries[current_auction.name][1].stack_size and auxSellEntries[current_auction.name].selected.buyout_price == auxSellEntries[current_auction.name][1].buyout_price then
--				AuxRecommendBasisText:SetText("(based on cheapest)")
--			elseif bestPriceOurStackSize and auxSellEntries[current_auction.name].selected.stack_size == bestPriceOurStackSize.stack_size and auxSellEntries[current_auction.name].selected.buyout_price == bestPriceOurStackSize.buyout_price then
--				AuxRecommendBasisText:SetText("(based on cheapest stack of the same size)")
--			else
--				AuxRecommendBasisText:SetText("(based on auction selected below)")
--			end
		elseif auxSellEntries[current_auction.name] then
			Aux.log("No auctions were found for "..current_auction.name)
			auxSellEntries[current_auction.name] = nil
		else 
			-- Aux_HideElems(Aux.tabs.sell.shownElements)
		end
	end
	
	Aux.sell.scrollbar_update()
end

function Aux.sell.quantity_update()
    if current_auction then
        AuxSellStackCountSlider:SetMinMaxValues(1, current_auction.charges and current_auction.availability[AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider.GetValue()]] or floor(current_auction.availability[0] / get_stack_size_slider_value()))
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

function set_auction(auction_candidate)
		
    Aux.scan.abort(function()

        current_auction = auction_candidate

        local charge_classes = charge_classes(current_auction.availability)
        AuxSellStackSizeSlider.charge_classes = charge_classes
        local stack_size_slider_max = current_auction.charges and getn(charge_classes) or min(current_auction.max_stack, current_auction.availability[0])
        AuxSellStackSizeSlider:SetMinMaxValues(1, stack_size_slider_max)

        AuxSellStackSizeSlider:SetValue(stack_size_slider_max)
        AuxSellStackCountSlider:SetValue(1)

        Aux.sell.quantity_update()

        if not auxSellEntries[current_auction.name] then
            refresh_entries()
        end

        select_entry()
        update_recommendation()
        update_auction_listing()
        update_inventory_listing()

    end)

end

function charge_classes(availability)
	local charge_classes = {}
	for charge_class, _ in availability do
		tinsert(charge_classes, charge_class)
	end
	sort(charge_classes, function(c1, c2) return c1 < c2 end)
	return charge_classes
end

function auction_candidates()

    local auction_candidate_map = {}

    Aux.util.without_sound(function()
        Aux.util.without_errors(function()

            for bag = 0, 4 do
                if GetBagName(bag) then
                    for slot = 1, GetContainerNumSlots(bag) do
                        local item_info = Aux.info.container_item(bag, slot)

                        if item_info then

                            local charge_class = item_info.charges or 0

                            ClearCursor()
                            PickupContainerItem(bag,slot)
                            ClickAuctionSellItemButton()
                            local auction_sell_item = Aux.info.auction_sell_item()
                            ClearCursor()
                            ClickAuctionSellItemButton()
                            ClearCursor()

                            if auction_sell_item then
                                if not auction_candidate_map[item_info.item_signature] then

                                    auction_candidate_map[item_info.item_signature] = {
                                        hyperlink = item_info.hyperlink,
                                        name = item_info.name,
                                        texture = item_info.texture,
                                        quality = item_info.quality,
                                        class = item_info.type,
                                        subclass = item_info.subtype,
                                        deposit_factor = auction_sell_item.deposit_factor,
                                        vendor_price_per_unit = auction_sell_item.vendor_price_per_unit,
                                        charges = item_info.charges,
                                        aux_quantity = item_info.charges or item_info.count,
                                        max_stack = item_info.max_stack,
                                        availability = { [charge_class]=item_info.count },
                                    }
                                else
                                    local candidate = auction_candidate_map[item_info.item_signature]
                                    candidate.availability[charge_class] = (candidate.availability[charge_class] or 0) + item_info.count
                                    candidate.aux_quantity = candidate.aux_quantity + (item_info.charges or item_info.count)
                                end
                            end
                        end
                    end
                end
            end

        end)
    end)

    local auction_candidates = {}
    for _, auction_candidate in pairs(auction_candidate_map) do
        tinsert(auction_candidates, auction_candidate)
    end
    return auction_candidates
end

function refresh_entries()
	if current_auction then
		local name, class, subclass = current_auction.name, current_auction.class, current_auction.subclass
		
		auxSellEntries[name] = nil
		
		class, subclass = GetItemInfo(name)

		-- local class_index = item_class_index(current_auction.class)
		-- local subclass_index = item_subclass_index(class_index, current_auction.subclass)

		Aux.log('Scanning auctions ...')
		Aux.scan.start{
			query = {
				name = name,
				class = class_index,
				subclass = subclass_index,
			},
			page = 0,
			on_start_page = function(page, total_pages)
				Aux.log('Scanning page ' .. page + 1 .. (total_pages > 0 and ' out of ' .. total_pages or '') .. ' ...')
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
	
function Aux.sell.scrollbar_update()

--	local numrows
--	if not current_auction or not auxSellEntries[current_auction.name] then
--		numrows = 0
--	else
--		numrows = getn(auxSellEntries[current_auction.name])
--	end
	
	-- FauxScrollFrame_Update(AuxScrollFrame, numrows, 12, 16)

--	for line = 1, 12 do

--		local dataOffset = 1 -- line + FauxScrollFrame_GetOffset(AuxScrollFrame)
--		local lineEntry = getglobal("AuxSellEntry"..line)
--
--		if numrows <= 12 then
--			lineEntry:SetWidth(603)
--		else
--			lineEntry:SetWidth(585)
--		end
--
--		lineEntry:SetID(dataOffset)
		
--		if current_auction and dataOffset <= numrows and auxSellEntries[current_auction.name] then
--
--			local entry = auxSellEntries[current_auction.name][dataOffset]
--
--			if auxSellEntries[current_auction.name].selected and entry.unit_buyout_price == auxSellEntries[current_auction.name].selected.unit_buyout_price and entry.stack_size == auxSellEntries[current_auction.name].selected.stack_size then
--				lineEntry:LockHighlight()
--			else
--				lineEntry:UnlockHighlight()
--			end
--
--			local lineEntry_stacks	= getglobal("AuxSellEntry"..line.."_Stacks")
--			local lineEntry_time	= getglobal("AuxSellEntry"..line.."_Time")
--
--			if entry.max_time_left == 1 then
--				lineEntry_time:SetText("Short")
--			elseif entry.max_time_left == 2 then
--				lineEntry_time:SetText("Medium")
--			elseif entry.max_time_left == 3 then
--				lineEntry_time:SetText("Long")
--			elseif entry.max_time_left == 4 then
--				lineEntry_time:SetText("Very Long")
--			end
--
--			if entry.stack_size == get_stack_size_slider_value() then
--				lineEntry_stacks:SetTextColor(0.2, 0.9, 0.2)
--			else
--				lineEntry_stacks:SetTextColor(1.0, 1.0, 1.0)
--			end
--
--			local own
--			if entry.yours == 0 then
--				own = ""
--			elseif
--				entry.yours == entry.count then
--				own = "(yours)"
--			else
--				own = "(yours: "..entry.yours..")"
--			end
--
--			local tx = string.format("%i %s of %i %s", entry.count, Aux_PluralizeIf("stack", entry.count), entry.stack_size, own)
--			lineEntry_stacks:SetText(tx)
--
--			MoneyFrame_Update("AuxSellEntry"..line.."_UnitPrice", Aux_Round(entry.buyout_price/entry.stack_size))
--			MoneyFrame_Update("AuxSellEntry"..line.."_TotalPrice", Aux_Round(entry.buyout_price))
--
--			lineEntry:Show()
--		else
--			lineEntry:Hide()
--		end
--	end
end

function AuxSellEntry_OnClick(entry)

	auxSellEntries[current_auction.name].selected = entry

    update_auction_listing()
	update_recommendation()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

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
			if existingEntry.buyout_price == buyout_price and existingEntry.stack_size == stack_size then
				entry = existingEntry
			end
		end
		if entry then
			entry.count = entry.count + 1
			entry.yours = entry.yours + (owner == UnitName("player") and 1 or 0)
			entry.max_time_left = max(entry.max_time_left, duration)
		else
			entry = {
				stack_size = stack_size,
				buyout_price = buyout_price,
				unit_buyout_price = buyout_price / stack_size,
				max_time_left = duration,
				count = 1,
				yours = owner == UnitName("player") and 1 or 0,
			}
			tinsert(auxSellEntries[name], entry)
			table.sort(auxSellEntries[name], function(a,b) return a.unit_buyout_price < b.unit_buyout_price end)
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

function report(hyperlink, stack_size, buyout_price, posted)
	Aux.log(string.format(
        '%i auctions of %s x %i posted for %s each)',
        posted,
        hyperlink,
        stack_size,
        Aux.util.money_string(buyout_price)
	))
end
