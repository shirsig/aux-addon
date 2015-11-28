local private, public = {}, {}
Aux.sell = public

local existing_auctions = {}

local inventory_data

local bestPriceOurStackSize

local current_auction

local set_auction, update_auction_listing, update_inventory_listing, record_auction, undercut, item_class_index, item_subclass_index, report, select_entry, update_recommendation, refresh_entries, auction_candidates, charge_classes, get_stack_size_slider_value

local LIVE, HISTORICAL, FIXED = 1, 2, 3

Aux.sell.inventory_listing_config = {
    on_row_click = function (sheet, row_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        set_auction(sheet.data[data_index])
    end,

    on_row_enter = function (sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
        Aux.info.set_tooltip(sheet.rows[row_index].itemstring, nil, this, 'ANCHOR_CURSOR', 0, 30)
    end,

    on_row_leave = function (sheet, row_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        if not (current_auction and sheet.data[data_index] == current_auction) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
        AuxTooltip:Hide()
    end,

    row_setter = function(row, datum)
        if current_auction and datum == current_auction then
            row.highlight:SetAlpha(.5)
        else
            row.highlight:SetAlpha(0)
        end
        row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id)
    end,

    columns = {
        {
            title = 'Qty',
            width = 25,
            comparator = function(datum1, datum2) return Aux.util.compare(datum1.aux_quantity, datum2.aux_quantity, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.aux_quantity)
            end,
        },
        {
            title = 'Item',
            width = 186,
            comparator = function(row1, row2) return Aux.util.compare(row1.name, row2.name, Aux.util.GT) end,
            cell_initializer = function(cell)
                local icon = CreateFrame('Button', nil, cell)
                icon:EnableMouse(false)
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
                local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                text:SetPoint('LEFT', icon, 'RIGHT', 1, 0)
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
    },
    sort_order = {{column = 2, order = 'ascending' }},
}

Aux.sell.auction_listing_config = {
    on_row_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxSellEntry_OnClick(sheet.data[data_index])
    end,

    on_row_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_row_leave = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        local datum = sheet.data[data_index]
        if not (datum and current_auction and Aux.util.safe_index{existing_auctions, current_auction.key, 'selected', 'key'} == datum.key) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
    end,

    row_setter = function(row, datum)
        if datum and current_auction and Aux.util.safe_index{existing_auctions, current_auction.key, 'selected', 'key'} == datum.key then
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
            title = 'Qty',
            width = 25,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.stack_size == get_stack_size_slider_value() and GREEN_FONT_COLOR_CODE..row.stack_size..FONT_COLOR_CODE_CLOSE or row.stack_size)
            end,
        },
        {
            title = 'Buy/ea',
            width = 80,
            comparator = function(row1, row2) return Aux.util.compare(row1.unit_buyout_price, row2.unit_buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(Aux.util.money_string(row.unit_buyout_price))
            end,
        },
    },
    sort_order = {{column = 4, order = 'ascending' }, {column = 4, order = 'ascending'}},
}

function update_inventory_listing()
    Aux.sheet.populate(AuxSellInventoryListing.sheet, inventory_data)
end

function update_auction_listing()
    Aux.sheet.populate(AuxSellAuctionsListing.sheet, current_auction and existing_auctions[current_auction.key] or {})
end

function Aux.sell.on_open()
    MoneyFrame_Update('AuxSellParametersDepositMoneyFrame', 0)
    AuxSellInventory:SetWidth(AuxSellInventoryListing:GetWidth() + 40)
    AuxSellAuctions:SetWidth(AuxSellAuctionsListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxSellInventory:GetWidth() + AuxSellParameters:GetWidth() + AuxSellAuctions:GetWidth() + 15)

    --    UIDropDownMenu_SetSelectedValue(AuxSellParametersStrategyDropDown, LIVE)
    Aux_Sell_SetAuctionDuration(AUX_AUCTION_DURATION)

    AuxSellStackSizeSlider:SetValueStep(1)
    AuxSellStackSizeSliderText:SetText('Stack Size')

    AuxSellStackCountSlider:SetValueStep(1)
    AuxSellStackCountSliderText:SetText('Stack Count')

    -- so that it's initialized with zeroes, not sometimes zero, sometimes empty
    MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 100000)
    MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 100000)
    MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 1000)
    MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 1000)
    MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 1)
    MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 1)

    Aux.sell.validate_parameters()

    update_inventory_data()

    update_inventory_listing()
    update_auction_listing()
end

function Aux.sell.on_close()

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

function Aux_Sell_SetAuctionDuration(duration)
	if duration == 'short' then
        Aux.sell.duration_radio_button_on_click(1)
	elseif duration == 'medium' then
        Aux.sell.duration_radio_button_on_click(2)
	elseif duration == 'long' then
        Aux.sell.duration_radio_button_on_click(3)
	end
end

function Aux.sell.post_auctions()
	if current_auction then
		local key, hyperlink, stack_size, buyout_price, stack_count = current_auction.key, current_auction.hyperlink, get_stack_size_slider_value(), MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice), AuxSellStackCountSlider:GetValue()
		local duration
		if AuctionFrameAuctions.duration == 120 then
			duration = 2
		elseif AuctionFrameAuctions.duration == 480 then
			duration = 3
		elseif AuctionFrameAuctions.duration == 1440 then
			duration = 4
		end
		
		Aux.post.start(
			key,
			stack_size,
			AuctionFrameAuctions.duration,
			MoneyInputFrame_GetCopper(AuxSellParametersStartPrice),
			buyout_price,
			stack_count,
			function(posted)
				for i = 1, posted do
					record_auction(key, stack_size, buyout_price, duration, UnitName("player"))
				end
				if existing_auctions[key] then
					for _, entry in ipairs(existing_auctions[key]) do
						if entry.buyout_price == buyout_price and entry.stack_size == stack_size then
							existing_auctions[key].selected = entry
						end
					end
				end
				Aux.sell.clear_auction()
                update_inventory_data()
                update_inventory_listing()
				report(hyperlink, stack_size, buyout_price, posted)
			end
		)
	end
end

function select_entry()
	if current_auction and existing_auctions[current_auction.key] and not existing_auctions[current_auction.key].selected then
		local bestPrice	= {} -- a table with one entry per stack_size that is the cheapest auction for that particular stack_size
		local absoluteBest -- the overall cheapest auction

		----- find the best price per stacksize and overall -----
		
		for _, auction_datum in ipairs(existing_auctions[current_auction.key]) do
			if not bestPrice[auction_datum.stack_size] or bestPrice[auction_datum.stack_size].unit_buyout_price >= auction_datum.unit_buyout_price then
				bestPrice[auction_datum.stack_size] = auction_datum
			end
		
			if not absoluteBest or absoluteBest.unit_buyout_price > auction_datum.unit_buyout_price then
				absoluteBest = auction_datum
			end	
		end
		
		existing_auctions[current_auction.key].selected = absoluteBest

		if bestPrice[get_stack_size_slider_value()] then
			existing_auctions[current_auction.key].selected = bestPrice[get_stack_size_slider_value()]
			bestPriceOurStackSize = bestPrice[get_stack_size_slider_value()]
		end
	end
end

function get_stack_size_slider_value()
    if current_auction.charges then
        return AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()]
    else
        return AuxSellStackSizeSlider:GetValue()
    end
end

function Aux.sell.validate_parameters()
    AuxSellParametersPostButton:Disable()
    AuxSellParametersBuyoutPriceErrorText:Hide()

    if not current_auction then
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) > 0 and MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) > MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) then
--        AuxSellParametersBuyoutPriceErrorText:Show()
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) < 1 then
        return
    end

    AuxSellParametersPostButton:Enable()
end

function update_recommendation()
--    AuxSellParametersStrategyDropDownStaleWarning:SetText()

	if not current_auction then
		AuxSellParametersRefreshButton:Disable()
		
		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetText()

		MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
		MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)

        AuxSellStackSizeSlider:SetMinMaxValues(0,0)
        AuxSellStackSize:SetNumber(0)
        AuxSellStackCountSlider:SetMinMaxValues(0,0)
        AuxSellStackCount:SetNumber(0)

        MoneyFrame_Update('AuxSellParametersDepositMoneyFrame', 0)
    else
        AuxSellStackSize:SetNumber(current_auction.charges and AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()] or AuxSellStackSizeSlider:GetValue())
        AuxSellStackCount:SetNumber(AuxSellStackCountSlider:GetValue())

        AuxSellParametersItemIconTexture:SetTexture(current_auction.texture)
        AuxSellParametersItemName:SetText(current_auction.name)
        local color = ITEM_QUALITY_COLORS[current_auction.quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if current_auction.aux_quantity > 1 then
            AuxSellParametersItemCount:SetText(current_auction.aux_quantity)
		else
            AuxSellParametersItemCount:SetText()
		end

        AuxSellParametersRefreshButton:Enable()

        -- TODO neutral AH deposit formula
		MoneyFrame_Update('AuxSellParametersDepositMoneyFrame', floor(current_auction.unit_vendor_price * 0.05 * (current_auction.charges and 1 or get_stack_size_slider_value())) * AuxSellStackCountSlider:GetValue() * AuctionFrameAuctions.duration / 120)
		
		if existing_auctions[current_auction.key] and existing_auctions[current_auction.key].selected then
			if not existing_auctions[current_auction.key].created or GetTime() - existing_auctions[current_auction.key].created > 1800 then
                AuxSellParametersStrategyDropDownStaleWarning:SetText('Stale data!') -- data older than half an hour marked as stale
			end
		
			local new_buyout_price = existing_auctions[current_auction.key].selected.unit_buyout_price * get_stack_size_slider_value()

			if existing_auctions[current_auction.key].selected.yours == 0 then
				new_buyout_price = undercut(new_buyout_price)
			end
			
			local new_start_price = new_buyout_price * 0.95

            MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, max(1, Aux_Round(new_start_price)))
            MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, max(1, Aux_Round(new_buyout_price)))
--        elseif UIDropDownMenu_GetSelectedValue(AuxSellParametersStrategyDropDown) == HISTORICAL then
--            local market_price = Aux.history.get_price_suggestion(current_auction.key, current_auction.aux_quantity)
--            MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, Aux_Round(market_price * 0.95))
--            MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, market_price)
        elseif existing_auctions[current_auction.key] then
            MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, max(1, Aux_Round(current_auction.unit_vendor_price * (current_auction.charges and 1 or get_stack_size_slider_value()) * 1.053)))
            MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, max(1, Aux_Round(current_auction.unit_vendor_price * (current_auction.charges and 1 or get_stack_size_slider_value()) * 4)))
        else
            MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)
            MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
        end
	end
end

function Aux.sell.quantity_update()
    if current_auction then
        AuxSellStackCountSlider:SetMinMaxValues(1, current_auction.charges and current_auction.availability[AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()]] or floor(current_auction.availability[0] / get_stack_size_slider_value()))
    end
    select_entry()
	update_recommendation()
    update_auction_listing()
end

function Aux.sell.clear_auction()
	current_auction = nil
	select_entry()
	update_recommendation()
end

function set_auction(auction_candidate)

    PlaySound('igMainMenuOptionCheckBoxOn')

    Aux.scan.abort(function()

        current_auction = auction_candidate
        update_inventory_listing()

        local charge_classes = charge_classes(current_auction.availability)
        AuxSellStackSizeSlider.charge_classes = current_auction.charges and charge_classes
        local stack_size_slider_max = current_auction.charges and getn(charge_classes) or min(current_auction.max_stack, current_auction.availability[0])
        AuxSellStackSizeSlider:SetMinMaxValues(1, stack_size_slider_max)

        AuxSellStackSizeSlider:SetValue(stack_size_slider_max)
        Aux.sell.quantity_update()
        AuxSellStackCountSlider:SetValue(current_auction.aux_quantity) -- reduced to max possible

        if not existing_auctions[current_auction.key] then
            refresh_entries()
        end

        select_entry()
        update_recommendation()
        update_auction_listing()

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

function update_inventory_data()
    inventory_data = {}
    update_inventory_listing()

    local auction_candidate_map = {}

    local function process_inventory(inventory_iterator, k)
        local slot = inventory_iterator()

        if not slot then
            return k()
        end

        local item_info = Aux.info.container_item(slot.bag, slot.bag_slot)

        if item_info then

            return Aux.control.on_next_update(function()

                local charge_class = item_info.charges or 0

                local auction_sell_item

                Aux.util.without_sound(function()
                    Aux.util.without_errors(function()

                        ClearCursor()
                        PickupContainerItem(slot.bag, slot.bag_slot)
                        ClickAuctionSellItemButton()
                        auction_sell_item = Aux.info.auction_sell_item()
                        ClearCursor()
                        ClickAuctionSellItemButton()
                        ClearCursor()

                    end)
                end)

                if auction_sell_item then
                    if not auction_candidate_map[item_info.item_key] then

                        auction_candidate_map[item_info.item_key] = {
                            item_id = item_info.item_id,
                            suffix_id = item_info.suffix_id,

                            key = item_info.item_key,
                            hyperlink = item_info.hyperlink,
                            
                            name = item_info.name,
                            texture = item_info.texture,
                            quality = item_info.quality,
                            class = item_info.type,
                            subclass = item_info.subtype,
                            unit_vendor_price = auction_sell_item.unit_vendor_price,
                            charges = item_info.charges,
                            aux_quantity = item_info.charges or item_info.count,
                            max_stack = item_info.max_stack,
                            availability = { [charge_class]=item_info.count },
                        }
                    else
                        local candidate = auction_candidate_map[item_info.item_key]
                        candidate.availability[charge_class] = (candidate.availability[charge_class] or 0) + item_info.count
                        candidate.aux_quantity = candidate.aux_quantity + (item_info.charges or item_info.count)
                    end
                end

                return process_inventory(inventory_iterator, k)
            end)
        end

        return process_inventory(inventory_iterator, k)
    end

    process_inventory(Aux.util.inventory_iterator(), function()
        local auction_candidates = {}
        for _, auction_candidate in pairs(auction_candidate_map) do
            tinsert(auction_candidates, auction_candidate)
        end
        inventory_data = auction_candidates
        update_inventory_listing()
    end)
end

function refresh_entries()
	if current_auction then
		local item_id, suffix_id = current_auction.item_id, current_auction.suffix_id
        local item_key = item_id..':'..suffix_id
        local item_info = Aux.info.item(item_id, suffix_id)

        existing_auctions[item_key] = nil


        local class_index = Aux.item_class_index(item_info.class)
        local subclass_index = class_index and Aux.item_subclass_index(class_index, item_info.subclass)

        local search_query = {
            name = Aux.info.item(item_id).name, -- blizzard doesn't support queries with name suffixes
            min_level = item_info.level,
            min_level = item_info.level,
            slot = item_info.slot,
            class = class_index,
            subclass = subclass_index,
            quality = item_info.quality,
            usable = item_info.usable,
        }

		Aux.log('Scanning auctions ...')
		Aux.scan.start{
			query = search_query,
			page = 0,
			on_page_loaded = function(page, total_pages)
				Aux.log('Scanning page '..(page + 1)..' out of '..total_pages..' ...')
			end,
			on_read_auction = function(auction_info)
				if auction_info.name == item_info.name then
					local aux_quantity = auction_info.charges or auction_info.count
					record_auction(auction_info.item_key, aux_quantity, auction_info.buyout_price, auction_info.duration, auction_info.owner)
				end
			end,
			on_abort = function()
				existing_auctions[item_key] = nil
                Aux.log('Scan aborted.')
			end,
			on_complete = function()
				existing_auctions[item_key] = existing_auctions[item_key] or { created = GetTime() }
				select_entry()
				update_recommendation()
                update_auction_listing()
                Aux.log('Scan complete: '..getn(existing_auctions[item_key])..' '..Aux_PluralizeIf('auction', getn(existing_auctions[item_key]))..' of '..current_auction.hyperlink..' found.')
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
	
function AuxSellEntry_OnClick(entry)

	existing_auctions[current_auction.key].selected = entry

    update_auction_listing()
	update_recommendation()

	PlaySound('igMainMenuOptionCheckBoxOn')
end

function AuxSellParametersRefreshButton_OnClick()
	Aux.scan.abort(function()
		refresh_entries()
		select_entry()
		update_recommendation()
        update_auction_listing()
	end)
end

function record_auction(key, aux_quantity, buyout_price, duration, owner)
	if buyout_price > 0 then
		existing_auctions[key] = existing_auctions[key] or { created = GetTime() }
		local entry
		for _, existingEntry in ipairs(existing_auctions[key]) do
			if existingEntry.buyout_price == buyout_price and existingEntry.stack_size == aux_quantity then
				entry = existingEntry
			end
		end
		if entry then
			entry.count = entry.count + 1
			entry.yours = entry.yours + (owner == UnitName("player") and 1 or 0)
			entry.max_time_left = max(entry.max_time_left, duration)
		else
			entry = {
                key = aux_quantity..':'..buyout_price,

				stack_size = aux_quantity,
				buyout_price = buyout_price,
				unit_buyout_price = buyout_price / aux_quantity,
				max_time_left = duration,
				count = 1,
				yours = owner == UnitName("player") and 1 or 0,
			}
			tinsert(existing_auctions[key], entry)
			table.sort(existing_auctions[key], function(a,b) return a.unit_buyout_price < b.unit_buyout_price end)
		end
	end
end

function undercut(price)
	return math.max(0, price - 1)
end

function report(hyperlink, aux_quantity, buyout_price, posted)
	Aux.log(string.format(
        '%i %s of %s x %i posted at %s.',
        posted,
        Aux_PluralizeIf('auction', posted),
        hyperlink,
        aux_quantity,
        Aux.util.money_string(buyout_price)
	))
end

--function Aux.sell.initialize_strategy_dropdown()
--
--    local function on_click()
--        UIDropDownMenu_SetSelectedValue(AuxSellParametersStrategyDropDown, this.value)
--    end
--
--    UIDropDownMenu_AddButton{
--        text = 'Live scan',
--        value = LIVE,
--        func = on_click,
--    }
--
--    UIDropDownMenu_AddButton{
--        text = 'Historical price',
--        value = HISTORICAL,
--        func = on_click,
--    }
--
----    UIDropDownMenu_AddButton{
----        text = 'Fixed',
----        value = FIXED,
----        func = on_click,
----    }
--end
