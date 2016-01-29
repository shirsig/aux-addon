local private, public = {}, {}
Aux.post_frame = public

local refresh
local existing_auctions = {}
local inventory_data
local selected_item

--local LIVE, HISTORICAL, FIXED = {}, {}, {}

function private.update_inventory_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    Aux.sheet.populate(private.listings.inventory, Aux.util.filter(inventory_data, function(item) return item.aux_quantity > 0 end))
end

function private.update_auction_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    Aux.sheet.populate(private.listings.auctions, selected_item and existing_auctions[selected_item.key] or {})
end

function private.selected_auction()
    return selected_item and existing_auctions[selected_item.key] and existing_auctions[selected_item.key].selected
end

function public.on_load()
    private.inventory_listing_config = {
        frame = AuxSellInventoryListing,
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.set_item(sheet.data[data_index])
        end,

        on_row_enter = function(sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, nil, this, 'ANCHOR_LEFT', 0, 0)
        end,

        on_row_leave = function(sheet, row_index)
            AuxTooltip:Hide()
        end,
        selected = function(datum)
            return datum == selected_item
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
        selected = function(datum)
            return datum == private.selected_auction()
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
                    cell.text:SetText(row.stack_size == private.get_stack_size_slider_value() and GREEN_FONT_COLOR_CODE..row.stack_size..FONT_COLOR_CODE_CLOSE or row.stack_size)
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
        local status_bar = Aux.gui.status_bar(AuxPostFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxPostFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 16, '$parentPostButton')
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Post')
        btn:SetScript('OnClick', private.post_auctions)
        private.post_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 16, '$parentRefreshButton')
        btn:SetPoint('TOPLEFT', private.post_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', private.refresh)
        private.refresh_button = btn
    end
    do
        local slider = Aux.gui.slider(AuxSellParameters)
        slider:SetValueStep(1)
        slider:SetPoint('TOPLEFT', 16, -70)
        slider:SetWidth(170)
        slider:SetScript('OnValueChanged', function()
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            if slider.charge_classes then
                local charge_slider_value = Aux.util.index_of(this:GetNumber(), slider.charge_classes)
                if charge_slider_value then
                    slider:SetValue(charge_slider_value)
                end
            else
                slider:SetValue(this:GetNumber())
            end
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        slider.editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        slider.editbox:SetScript('OnEditFocusLost', function()
            this:HighlightText(0, 0)
        end)
        slider.editbox:SetWidth(50)
        slider.editbox:SetNumeric(true)
        slider.editbox:SetMaxLetters(3)
        slider.label:SetText('Stack Size')
        private.stack_size_slider = slider
    end
    do
        local slider = Aux.gui.slider(AuxSellParameters)
        slider:SetValueStep(1)
        slider:SetPoint('TOPLEFT', 16, -120)
        slider:SetWidth(170)
        slider:SetScript('OnValueChanged', function()
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            if slider.charge_classes then
                local index = Aux.util.index_of(this:GetNumber(), slider.charge_classes)
                if index then
                    slider:SetValue(index)
                end
            else
                slider:SetValue(this:GetNumber())
            end
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        slider.editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        slider.editbox:SetScript('OnEditFocusLost', function()
            this:HighlightText(0, 0)
        end)
        slider.editbox:SetWidth(50)
        slider.editbox:SetNumeric(true)
        slider.label:SetText('Stack Count')
        private.stack_count_slider = slider
    end
    do
        local label = Aux.gui.label(AuxSellParametersShortDurationRadio, 13)
        label:SetPoint('BOTTOMLEFT', AuxSellParametersShortDurationRadio, 'TOPLEFT', 1, -2)
        label:SetText('Duration')
    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetPoint('TOPLEFT', 16, -215)
        editbox:SetWidth(170)
        editbox:SetScript('OnTextChanged', function()
            private.validate_parameters()
        end)
        editbox:SetScript('OnTabPressed', function()
            private.buyout_price:SetFocus()
            private.buyout_price:HighlightText()
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(Aux.money.from_string(this:GetText())))
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Starting Stack Price')
        private.start_price = editbox
    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetPoint('TOPLEFT', 16, -255)
        editbox:SetWidth(170)
        editbox:SetScript('OnTextChanged', function()
            private.validate_parameters()
        end)
        editbox:SetScript('OnTabPressed', function()
            private.start_price:SetFocus()
            private.start_price:HighlightText()
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(Aux.money.from_string(this:GetText())))
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Buyout Stack Price |cff808080(optional)|r')
        private.buyout_price = editbox
    end
    do
        local label = Aux.gui.label(AuxSellParameters, 15)
        label:SetPoint('TOPLEFT', AuxSellParameters, 'TOPLEFT', 16, -290)
        private.deposit = label
    end
end

function public.on_open()
    private.deposit:SetText('Deposit: '..Aux.money.to_string(0))
    AuxSellInventory:SetWidth(AuxSellInventoryListing:GetWidth() + 40)
    AuxSellAuctions:SetWidth(AuxSellAuctionsListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxSellInventory:GetWidth() + AuxSellParameters:GetWidth() + AuxSellAuctions:GetWidth() + 15)

    --    UIDropDownMenu_SetSelectedValue(AuxSellParametersStrategyDropDown, LIVE)
    private.set_auction_duration(AUX_AUCTION_DURATION)

    -- so that it's initialized with zeroes, not sometimes zero, sometimes empty
    private.start_price:SetText(Aux.money.to_string(0))
    private.buyout_price:SetText(Aux.money.to_string(0))

    private.validate_parameters()

    private.update_inventory_data()

    refresh = true

    private.update_recommendation()
end

function public.on_close()
    selected_item = nil
end

function public.duration_radio_button_on_click(index)
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

function private.set_auction_duration(duration)
	if duration == 'short' then
        public.duration_radio_button_on_click(1)
	elseif duration == 'medium' then
        public.duration_radio_button_on_click(2)
	elseif duration == 'long' then
        public.duration_radio_button_on_click(3)
	end
end

function private.post_auctions()
    local auction = selected_item
	if auction then
		local key, hyperlink, stack_size, buyout_price, stack_count = auction.key, auction.hyperlink, private.get_stack_size_slider_value(), Aux.money.from_string(private.buyout_price:GetText()), private.stack_count_slider:GetValue()
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
            Aux.money.from_string(private.start_price:GetText()),
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
                            refresh = true
						end
					end
				end
                auction.aux_quantity = auction.aux_quantity - (posted * stack_size)
                local charge_class = auction.charges or 0
                auction.availability[charge_class] = auction.availability[charge_class] - (posted * (auction.charges and 1 or stack_size))

                if selected_item == auction then
                    if auction.aux_quantity > 0 then
                    private.set_item(auction)
                    else
                        selected_item = nil
                    end
                end
                private.update_recommendation()
                refresh = true
			end
		)
	end
end

function private.select_auction()
	if not existing_auctions[selected_item.key].selected and getn(existing_auctions[selected_item.key]) > 0 then
--		local cheapest_for_size = {}
		local cheapest

		for _, auction_entry in ipairs(existing_auctions[selected_item.key]) do
--			if not cheapest_for_size[auction_entry.stack_size] or cheapest_for_size[auction_entry.stack_size].unit_buyout_price >= auction_entry.unit_buyout_price then
--				cheapest_for_size[auction_entry.stack_size] = auction_entry
--			end

			if not cheapest or cheapest.unit_buyout_price > auction_entry.unit_buyout_price then
				cheapest = auction_entry
			end
		end

--        local auction = cheapest_for_size[private.get_stack_size_slider_value()] or cheapest

        existing_auctions[selected_item.key].selected = cheapest
	end
end

function private.get_stack_size_slider_value()
    if selected_item.charges then
        return private.stack_size_slider.charge_classes[private.stack_size_slider:GetValue()]
    else
        return private.stack_size_slider:GetValue()
    end
end

function private.validate_parameters()
    private.post_button:Disable()

    if not selected_item then
        return
    end

    if Aux.money.from_string(private.buyout_price:GetText()) > 0 and Aux.money.from_string(private.start_price:GetText()) > Aux.money.from_string(private.buyout_price:GetText()) then
--        AuxSellParametersBuyoutPriceErrorText:Show()
        return
    end

    if Aux.money.from_string(private.start_price:GetText()) < 1 then
        return
    end

    private.post_button:Enable()
end

function private.update_recommendation()

	if not selected_item then
		private.refresh_button:Disable()

		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetText()

        private.start_price:SetText(Aux.money.to_string(0))
		private.buyout_price:SetText(Aux.money.to_string(0))

        private.stack_size_slider:SetMinMaxValues(0, 0)
        private.stack_size_slider.editbox:SetNumber(0)
        private.stack_count_slider:SetMinMaxValues(0, 0)
        private.stack_count_slider.editbox:SetNumber(0)

        private.deposit:SetText('Deposit: '..Aux.money.to_string(0))
    else
        private.stack_size_slider.editbox:SetNumber(selected_item.charges and private.stack_size_slider.charge_classes[private.stack_size_slider:GetValue()] or private.stack_size_slider:GetValue())
        private.stack_count_slider.editbox:SetNumber(private.stack_count_slider:GetValue())

        AuxSellParametersItemIconTexture:SetTexture(selected_item.texture)
        AuxSellParametersItemName:SetText(selected_item.name)
        local color = ITEM_QUALITY_COLORS[selected_item.quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if selected_item.aux_quantity > 1 then
            AuxSellParametersItemCount:SetText(selected_item.aux_quantity)
		else
            AuxSellParametersItemCount:SetText()
		end

        private.refresh_button:Enable()

        -- TODO neutral AH deposit formula
        private.deposit:SetText('Deposit: '..Aux.money.to_string(floor(selected_item.unit_vendor_price * 0.05 * (selected_item.charges and 1 or private.get_stack_size_slider_value())) * private.stack_count_slider:GetValue() * AuctionFrameAuctions.duration / 120))

        if existing_auctions[selected_item.key] then
            private.select_auction()

            if existing_auctions[selected_item.key].selected then

                local new_buyout_price = existing_auctions[selected_item.key].selected.unit_buyout_price * private.get_stack_size_slider_value()

                if existing_auctions[selected_item.key].selected.yours == 0 then
                    new_buyout_price = private.undercut(new_buyout_price)
                end

                private.start_price:SetText(Aux.money.to_string(max(1, new_buyout_price * 0.95)))
                private.buyout_price:SetText(Aux.money.to_string(max(1, new_buyout_price)))

            elseif existing_auctions[selected_item.key] then -- unsuccessful search

                local price_suggestion = Aux.history.market_value(selected_item.key) and 1.2 * Aux.history.market_value(selected_item.key) * private.get_stack_size_slider_value()

                if price_suggestion then
                    private.start_price:SetText(Aux.money.to_string(max(1, price_suggestion * 0.95)))
                    private.buyout_price:SetText(Aux.money.to_string(max(1, price_suggestion)))
                else
                    private.start_price:SetText(Aux.money.to_string(max(1, selected_item.unit_vendor_price * (selected_item.charges and 1 or private.get_stack_size_slider_value()) * 1.053)))
                    private.buyout_price:SetText(Aux.money.to_string(max(1, selected_item.unit_vendor_price * (selected_item.charges and 1 or private.get_stack_size_slider_value()) * 4)))
                end
            end
        else -- no search yet
        private.start_price:SetText(Aux.money.to_string(0))
        private.buyout_price:SetText(Aux.money.to_string(0))
        end
	end
end

function private.quantity_update()
    if selected_item then
        private.stack_count_slider:SetMinMaxValues(1, selected_item.charges and selected_item.availability[private.stack_size_slider.charge_classes[private.stack_size_slider:GetValue()]] or floor(selected_item.availability[0] / private.get_stack_size_slider_value()))
    end
	private.update_recommendation()
    refresh = true
end

function private.set_item(item)

    selected_item = item
    refresh = true

    PlaySound('igMainMenuOptionCheckBoxOn')

    Aux.scan.abort(function()

        local charge_classes = private.charge_classes(selected_item.availability)
        private.stack_size_slider.charge_classes = selected_item.charges and charge_classes
        local stack_size_slider_max = selected_item.charges and getn(charge_classes) or min(selected_item.max_stack, selected_item.availability[0])
        private.stack_size_slider:SetMinMaxValues(1, stack_size_slider_max)

        private.stack_size_slider:SetValue(stack_size_slider_max)
        private.quantity_update()
        private.stack_count_slider:SetValue(selected_item.aux_quantity) -- reduced to max possible

        if not existing_auctions[selected_item.key] then
            private.refresh_entries()
        end

        private.update_recommendation()
        refresh = true
    end)

end

function private.charge_classes(availability)
	local charge_classes = {}
	for charge_class, _ in availability do
		tinsert(charge_classes, charge_class)
	end
	sort(charge_classes, function(c1, c2) return c1 < c2 end)
	return charge_classes
end

function private.update_inventory_data()
    inventory_data = {}
    refresh = true

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
        refresh = true
    end)
end

function private.refresh_entries()
	if selected_item then
		local item_id, suffix_id = selected_item.item_id, selected_item.suffix_id
        local item_key = item_id..':'..suffix_id

        existing_auctions[item_key] = nil

        local query = Aux.scan_util.create_item_query(
            item_id,
            'list',
            0
        )

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		Aux.scan.start{
			queries = { query },
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages) -- TODO
                private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
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
                refresh = true
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
            end,
		}
	end
end
	
function private.set_auction(entry)

    existing_auctions[selected_item.key].selected = entry
    refresh = true
	private.update_recommendation()

	PlaySound('igMainMenuOptionCheckBoxOn')
end

function private.refresh()
	Aux.scan.abort(function()
		private.refresh_entries()
		private.update_recommendation()
        refresh = true
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

function private.undercut(price)
	return math.max(0, price - 1)
end

function public.on_update()
    if refresh then
        refresh = false
        private.update_inventory_listing()
        private.update_auction_listing()
    end
end

--function public.initialize_strategy_dropdown()
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
--    UIDropDownMenu_AddButton{
--        text = 'Fixed',
--        value = FIXED,
--        func = on_click,
--    }
--end
