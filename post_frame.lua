local private, public = {}, {}
Aux.sell = public
Aux.post_frame = public

local existing_auctions = {}

local inventory_data

local update_auction_listing, undercut, refresh_entries, auction_candidates, charge_classes, get_stack_size_slider_value

--local LIVE, HISTORICAL, FIXED = {}, {}, {}

function private.update_inventory_listing()
    Aux.sheet.populate(private.listings.inventory, Aux.util.filter(inventory_data, function(item) return item.aux_quantity > 0 end))
end

function update_auction_listing()
    Aux.sheet.populate(private.listings.auctions, private.current_item() and existing_auctions[private.current_item().key] or {})
end

function private.current_item()
    return private.listings.inventory:get_selected()
end

function private.current_auction()
    return private.listings.auctions:get_selected()
end

function public.on_load()
    private.inventory_listing_config = {
        frame = AuxSellInventoryListing,
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.set_item(sheet.data[data_index])
        end,

        on_row_enter = function (sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, nil, this, 'ANCHOR_LEFT', 0, 0)
        end,

        on_row_leave = function (sheet, row_index)
            AuxTooltip:Hide()
        end,

        row_setter = function(row, datum)
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

    private.auction_listing_config = {
        frame = AuxSellAuctionsListing,
        on_row_click = function (sheet, row_index, column_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.set_auction(sheet.data[data_index])
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
            Aux.listing_util.percentage_market_column(function(entry) return entry.item_key end, function(entry) return entry.unit_buyout_price end),
        },
        sort_order = {{column = 5, order = 'ascending' }},
    }

    private.listings = {
        inventory = Aux.sheet.create(private.inventory_listing_config),
        auctions = Aux.sheet.create(private.auction_listing_config),
    }
    do
        local status_bar = Aux.gui.status_bar(AuxSellFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxSellFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 15, '$parentPostButton')
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Post')
        btn:SetScript('OnClick', private.post_auctions)
        private.post_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 15, '$parentRefreshButton')
        btn:SetPoint('TOPLEFT', private.post_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', private.refresh)
        private.refresh_button = btn
    end
end

function public.on_open()
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

    private.update_inventory_data()

    private.update_inventory_listing()
    update_auction_listing()

    private.update_recommendation()
end

function public.on_close()

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
    private.update_recommendation()
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

function private.post_auctions()
    local auction = private.current_item()
	if auction then
		local key, hyperlink, stack_size, buyout_price, stack_count = auction.key, auction.hyperlink, get_stack_size_slider_value(), MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice), AuxSellStackCountSlider:GetValue()
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
					private.record_auction(key, stack_size, buyout_price, duration, UnitName('player'))
				end
				if existing_auctions[key] then
					for _, entry in ipairs(existing_auctions[key]) do
						if entry.buyout_price == buyout_price and entry.stack_size == stack_size then
							existing_auctions[key].selected = entry
                            private.listings.auctions:select(entry)
						end
					end
				end
				Aux.sell.clear_auction()
                auction.aux_quantity = auction.aux_quantity - (posted * stack_size)
                local charge_class = auction.charges or 0
                auction.availability[charge_class] = auction.availability[charge_class] - (posted * (auction.charges and 1 or stack_size))

                private.update_inventory_listing()
			end
		)
	end
end

function private.select_auction()
	if not private.current_auction() and getn(existing_auctions[private.current_item().key]) > 0 then
		local cheapest_for_size = {}
		local cheapest

		for _, auction_entry in ipairs(existing_auctions[private.current_item().key]) do
			if not cheapest_for_size[auction_entry.stack_size] or cheapest_for_size[auction_entry.stack_size].unit_buyout_price >= auction_entry.unit_buyout_price then
				cheapest_for_size[auction_entry.stack_size] = auction_entry
			end

			if not cheapest or cheapest.unit_buyout_price > auction_entry.unit_buyout_price then
				cheapest = auction_entry
			end
		end

        local auction = cheapest_for_size[get_stack_size_slider_value()] or cheapest

        existing_auctions[private.current_item().key].selected = auction
        private.listings.auctions:clear_selection()
        private.listings.auctions:select(auction)
	end
end

function get_stack_size_slider_value()
    if private.current_item().charges then
        return AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()]
    else
        return AuxSellStackSizeSlider:GetValue()
    end
end

function Aux.sell.validate_parameters()
    private.post_button:Disable()
    AuxSellParametersBuyoutPriceErrorText:Hide()

    if not private.current_item() then
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) > 0 and MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) > MoneyInputFrame_GetCopper(AuxSellParametersBuyoutPrice) then
--        AuxSellParametersBuyoutPriceErrorText:Show()
        return
    end

    if MoneyInputFrame_GetCopper(AuxSellParametersStartPrice) < 1 then
        return
    end

    private.post_button:Enable()
end

function private.update_recommendation()

	if not private.current_item() then
		private.refresh_button:Disable()

		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetText()

		MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
		MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)

        AuxSellStackSizeSlider:SetMinMaxValues(0, 0)
        AuxSellStackSize:SetNumber(0)
        AuxSellStackCountSlider:SetMinMaxValues(0, 0)
        AuxSellStackCount:SetNumber(0)

        MoneyFrame_Update('AuxSellParametersDepositMoneyFrame', 0)
    else
        AuxSellStackSize:SetNumber(private.current_item().charges and AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()] or AuxSellStackSizeSlider:GetValue())
        AuxSellStackCount:SetNumber(AuxSellStackCountSlider:GetValue())

        AuxSellParametersItemIconTexture:SetTexture(private.current_item().texture)
        AuxSellParametersItemName:SetText(private.current_item().name)
        local color = ITEM_QUALITY_COLORS[private.current_item().quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if private.current_item().aux_quantity > 1 then
            AuxSellParametersItemCount:SetText(private.current_item().aux_quantity)
		else
            AuxSellParametersItemCount:SetText()
		end

        private.refresh_button:Enable()

        -- TODO neutral AH deposit formula
		MoneyFrame_Update('AuxSellParametersDepositMoneyFrame', floor(private.current_item().unit_vendor_price * 0.05 * (private.current_item().charges and 1 or get_stack_size_slider_value())) * AuxSellStackCountSlider:GetValue() * AuctionFrameAuctions.duration / 120)

        if existing_auctions[private.current_item().key] then
            private.select_auction()

            if private.current_auction() then

                local new_buyout_price = private.current_auction().unit_buyout_price * get_stack_size_slider_value()

                if private.current_auction().yours == 0 then
                    new_buyout_price = undercut(new_buyout_price)
                end

                MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, max(1, Aux.round(new_buyout_price * 0.95)))
                MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, max(1, Aux.round(new_buyout_price)))

            elseif existing_auctions[private.current_item().key] then -- unsuccessful search

                local market_value = Aux.history.market_value(private.current_item().key)
                if market_value then
                    MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, max(1, Aux.round(market_value * 0.95)))
                    MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, max(1, Aux.round(market_value)))
                else
                    MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, max(1, Aux.round(private.current_item().unit_vendor_price * (private.current_item().charges and 1 or get_stack_size_slider_value()) * 1.053)))
                    MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, max(1, Aux.round(private.current_item().unit_vendor_price * (private.current_item().charges and 1 or get_stack_size_slider_value()) * 4)))
                end
            end
        else -- no search yet
            MoneyInputFrame_SetCopper(AuxSellParametersStartPrice, 0)
            MoneyInputFrame_SetCopper(AuxSellParametersBuyoutPrice, 0)
        end
	end
end

function Aux.sell.quantity_update()
    if private.current_item() then
        AuxSellStackCountSlider:SetMinMaxValues(1, private.current_item().charges and private.current_item().availability[AuxSellStackSizeSlider.charge_classes[AuxSellStackSizeSlider:GetValue()]] or floor(private.current_item().availability[0] / get_stack_size_slider_value()))
    end
	private.update_recommendation()
    update_auction_listing()
end

function Aux.sell.clear_auction()
    private.listings.inventory:clear_selection()
	private.update_recommendation()
end

function private.set_item(item)

    private.listings.auctions:clear_selection()
    private.listings.inventory:clear_selection()
    private.listings.inventory:select(item)
    local new_auction = Aux.util.safe_index{existing_auctions, item.key, 'selected' }
    if new_auction then
        private.listings.auctions:select(new_auction)
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    Aux.scan.abort(function()

        private.update_inventory_listing()

        local charge_classes = charge_classes(private.current_item().availability)
        AuxSellStackSizeSlider.charge_classes = private.current_item().charges and charge_classes
        local stack_size_slider_max = private.current_item().charges and getn(charge_classes) or min(private.current_item().max_stack, private.current_item().availability[0])
        AuxSellStackSizeSlider:SetMinMaxValues(1, stack_size_slider_max)

        AuxSellStackSizeSlider:SetValue(stack_size_slider_max)
        Aux.sell.quantity_update()
        AuxSellStackCountSlider:SetValue(private.current_item().aux_quantity) -- reduced to max possible

        if not existing_auctions[private.current_item().key] then
            refresh_entries()
        end

        private.update_recommendation()
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

function private.update_inventory_data()
    inventory_data = {}
    private.update_inventory_listing()

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

                Aux.util.without_errors(function()
                    Aux.util.without_sound(function()

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
        private.update_inventory_listing()
    end)
end

function refresh_entries()
	if private.current_item() then
		local item_id, suffix_id = private.current_item().item_id, private.current_item().suffix_id
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

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		Aux.scan.start{
			query = search_query,
			page = 0,
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages) -- TODO
                private.status_bar:set_text(string.format('Scanning (Page %d / %d)', page + 1, total_pages))
			end,
			on_read_auction = function(auction_info)
				if auction_info.item_key == item_key then
                    private.record_auction(auction_info.item_key, auction_info.aux_quantity, auction_info.buyout_price, auction_info.duration, auction_info.owner)
				end
			end,
			on_abort = function()
				existing_auctions[item_key] = nil
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
			end,
			on_complete = function()
				existing_auctions[item_key] = existing_auctions[item_key] or { created = time() }
				private.update_recommendation()
                update_auction_listing()
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
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
	
function private.set_auction(entry)

    existing_auctions[private.current_item().key].selected = entry
    private.listings.auctions:clear_selection()
    private.listings.auctions:select(entry)

	private.update_recommendation()

	PlaySound('igMainMenuOptionCheckBoxOn')
end

function private.refresh()
	Aux.scan.abort(function()
		refresh_entries()
		private.update_recommendation()
        update_auction_listing()
	end)
end

function private.record_auction(key, aux_quantity, buyout_price, duration, owner)
	if buyout_price > 0 then
		existing_auctions[key] = existing_auctions[key] or { created = GetTime() }
		local entry
		for _, existing_entry in ipairs(existing_auctions[key]) do
			if buyout_price == existing_entry.buyout_price and aux_quantity == existing_entry.stack_size then
				entry = existing_entry
			end
		end
		if entry then
			entry.count = entry.count + 1
			entry.yours = entry.yours + (owner == UnitName('player') and 1 or 0)
			entry.max_time_left = max(entry.max_time_left, duration)
        else
			tinsert(existing_auctions[key], {
                item_key = key,
				stack_size = aux_quantity,
				buyout_price = buyout_price,
				unit_buyout_price = buyout_price / aux_quantity,
				max_time_left = duration,
				count = 1,
				yours = owner == UnitName('player') and 1 or 0,
			})
		end
	end
end

function undercut(price)
	return math.max(0, price - 1)
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
