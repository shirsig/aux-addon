local private, public = {}, {}
Aux.post_frame = public

local refresh
local existing_auctions = {}
local inventory_records
local selected_item

local AUTO, UNDERCUT, MARKET, FIXED = 1, 2, 3, 4
local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440

function private.load_settings(item_record)
    local item_record = item_record or selected_item
    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}
    dataset.post[item_record.key] = dataset.post[item_record.key] or {
        duration = DURATION_24,
        stack_size = item_record.max_stack,
        start_price = 0,
        buyout_price = 0,
        hidden = false,
        pricing_model = AUTO,
    }
    return dataset.post[item_record.key]
end

function private.update_inventory_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    Aux.item_listing.populate(private.item_listing, Aux.util.filter(inventory_records, function(record)
        local settings = private.load_settings(record)
        return record.aux_quantity > 0 and (not settings.hidden or private.show_hidden_checkbox:GetChecked())
    end))
end

function private.update_auction_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    local auction_rows = {}
    if selected_item then
        for i, auction_record in ipairs(existing_auctions[selected_item.key] or {}) do
            local stack_size = auction_record.stack_size == private.stack_size_slider:GetValue() and GREEN_FONT_COLOR_CODE..auction_record.stack_size..FONT_COLOR_CODE_CLOSE or auction_record.stack_size
            local market_value = Aux.history.market_value(auction_record.item_key)
            tinsert(auction_rows, {
                cols = {
                    { value=auction_record.count },
                    { value=auction_record.yours },
                    { value=Aux.auction_listing.time_left(auction_record.duration) },
                    { value=stack_size },
                    { value=Aux.money.to_string(auction_record.unit_buyout_price, true, false) },
                    { value=Aux.auction_listing.percentage_market(market_value and Aux.round(auction_record.unit_buyout_price/market_value * 100) or '---') },
                },
                record = auction_record,
            })
        end
        sort(auction_rows, function(a, b) return Aux.sort.multi_lt(a.record.unit_buyout_price, b.record.unit_buyout_price, tostring(a.record), tostring(b.record)) end)
    end
    private.auction_listing:SetData(auction_rows)
    private.auction_listing:SetSelection(function(row) return row.record == private.selected_auction() end)
end

function private.selected_auction()
    return selected_item and existing_auctions[selected_item.key] and existing_auctions[selected_item.key].selected
end

function public.on_load()

    Aux.gui.vertical_line(AuxPostFrameContent, 219)

    AuxSellParametersItem:EnableMouse()
    AuxSellParametersItem:SetScript('OnReceiveDrag', function()
        local item_info = Aux.cursor_item()
        if item_info then
            for _, inventory_record in ipairs(Aux.util.filter(inventory_records, function(record) return record.aux_quantity > 0 end)) do
                if inventory_record.key == item_info.item_key then
                    private.set_item(inventory_record)
                    break
                end
            end
        end
        ClearCursor()
    end)

    do
        local checkbox = CreateFrame('CheckButton', nil, AuxSellInventory, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPLEFT', 45, -15)
        checkbox:SetScript('OnClick', function()
            refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Show hidden items')
        private.show_hidden_checkbox = checkbox
    end

    Aux.gui.horizontal_line(AuxSellInventory, -48)

    private.item_listing = Aux.item_listing.create(
        AuxSellInventory,
        function()
            private.set_item(this.item_record)
        end,
        function(item_record)
            return item_record == selected_item
        end
    )

--    private.inventory_listing:SetHandler('OnEnter', function(table, row_data, column)
--        Aux.info.set_tooltip(row_data.itemstring, nil, column.row, 'ANCHOR_LEFT', 0, 0)
--    end)
--    private.inventory_listing:SetHandler('OnLeave', function()
--        GameTooltip:Hide()
--    end)

    private.auction_listing = Aux.listing.CreateScrollingTable(AuxSellAuctions)
    private.auction_listing:SetColInfo({
        { name='Avail', width=.14, align='CENTER' },
        { name='Yours', width=.14, align='CENTER' },
        { name='Left', width=.14, align='CENTER' },
        { name='Qty', width=.08, align='CENTER' },
        { name='Buy/ea', width=.3, align='RIGHT' },
        { name='Pct', width=.2, align='CENTER' }
    })
    private.auction_listing:SetHandler('OnClick', function(table, row_data, column)
        private.set_auction(row_data.record)
    end)

    do
        local status_bar = Aux.gui.status_bar(AuxPostFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 100)
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
        slider:SetPoint('TOPLEFT', 16, -75)
        slider:SetWidth(190)
        slider:SetScript('OnValueChanged', function()
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            slider:SetValue(this:GetNumber())
            private.quantity_update()
            if selected_item then
                local settings = private.load_settings()
                settings.stack_size = this:GetNumber()
            end
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
        slider.editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.buyout_price:SetFocus()
            else
                private.stack_count_slider.editbox:SetFocus()
            end
        end)
        slider.editbox:SetWidth(50)
        slider.editbox:SetNumeric(true)
        slider.editbox:SetMaxLetters(3)
        slider.label:SetText('Stack Size')
        slider.label:SetTextHeight(13)
        private.stack_size_slider = slider
    end
    do
        local slider = Aux.gui.slider(AuxSellParameters)
        slider:SetValueStep(1)
        slider:SetPoint('TOPLEFT', private.stack_size_slider, 'BOTTOMLEFT', 0, -30)
        slider:SetWidth(190)
        slider:SetScript('OnValueChanged', function()
            private.quantity_update()
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            slider:SetValue(this:GetNumber())
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
        slider.editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.stack_size_slider.editbox:SetFocus()
            else
                private.start_price:SetFocus()
            end
        end)
        slider.editbox:SetWidth(50)
        slider.editbox:SetNumeric(true)
        slider.label:SetText('Stack Count')
        slider.label:SetTextHeight(13)
        private.stack_count_slider = slider
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSellParameters)
        dropdown:SetPoint('TOPLEFT', private.stack_count_slider, 'BOTTOMLEFT', 0, -25)
        dropdown:SetWidth(90)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Duration')
        UIDropDownMenu_Initialize(dropdown, private.initialize_duration_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_duration_dropdown)
        end)
        local label = Aux.gui.label(dropdown, 15)
        label:SetPoint('LEFT', dropdown, 'RIGHT', 25, 0)
        private.deposit = label
        private.duration_dropdown = dropdown
    end
    do
        local checkbox = CreateFrame('CheckButton', nil, AuxSellParameters, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPRIGHT', -85, -6)
        checkbox:SetScript('OnClick', function()
            local settings = private.load_settings()
            settings.hidden = this:GetChecked()
            refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Hide this item')
        private.hide_checkbox = checkbox
    end
--    do
--        local checkbox = CreateFrame('CheckButton', nil, AuxSellParameters, 'UICheckButtonTemplate')
--        checkbox:SetWidth(22)
--        checkbox:SetHeight(22)
--        checkbox:SetPoint('TOPRIGHT', -110, -25)
--        local label = Aux.gui.label(checkbox, 13)
--        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 2)
--        label:SetText('Enable batch posting')
--        private.batch_posting_checkbox = checkbox
--    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetPoint('TOPRIGHT', -30, -58)
        editbox:SetWidth(170)
        editbox:SetScript('OnTextChanged', function()
            if selected_item then
                local settings = private.load_settings()
                if settings.pricing_model == FIXED then
                    settings.start_price = Aux.money.from_string(this:GetText())
                end
            end
            private.validate_parameters()
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.stack_count_slider.editbox:SetFocus()
            else
                private.buyout_price:SetFocus()
            end
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
        editbox:SetPoint('TOP', private.start_price, 'BOTTOM', 0, -25)
        editbox:SetWidth(170)
        editbox:SetScript('OnTextChanged', function()
            if selected_item then
                local settings = private.load_settings()
                if settings.pricing_model == FIXED then
                    settings.buyout_price = Aux.money.from_string(this:GetText())
                end
            end
            private.validate_parameters()
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.start_price:SetFocus()
            else
                private.stack_size_slider.editbox:SetFocus()
            end
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
        label:SetText('Buyout Stack Price')
        private.buyout_price = editbox
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSellParameters)
        dropdown:SetPoint('TOPRIGHT', private.buyout_price, 'BOTTOMRIGHT', 0, -20)
        dropdown:SetWidth(120)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Pricing Model')
        UIDropDownMenu_Initialize(dropdown, private.initialize_pricing_model_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_pricing_model_dropdown)
        end)
        private.pricing_model_dropdown = dropdown
    end
end

function public.on_open()
    private.deposit:SetText('Deposit: '..Aux.money.to_string(0))

    private.start_price:SetText(Aux.money.to_string(0))
    private.buyout_price:SetText(Aux.money.to_string(0))

    private.validate_parameters()

    private.update_inventory_records()

    refresh = true

    private.update_recommendation()
end

function public.on_close()
    selected_item = nil
end

function private.post_auctions()
    local auction = selected_item
	if auction then
		local key, hyperlink, stack_size, buyout_price, stack_count = auction.key, auction.hyperlink, private.stack_size_slider:GetValue(), Aux.money.from_string(private.buyout_price:GetText()), private.stack_count_slider:GetValue()
		local duration
		if UIDropDownMenu_GetSelectedValue(private.duration_dropdown) == DURATION_4 then
			duration = 2
		elseif UIDropDownMenu_GetSelectedValue(private.duration_dropdown) == DURATION_8 then
			duration = 3
		elseif UIDropDownMenu_GetSelectedValue(private.duration_dropdown) == DURATION_24 then
			duration = 4
		end

		Aux.post.start(
			key,
			stack_size,
			UIDropDownMenu_GetSelectedValue(private.duration_dropdown),
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
		local cheapest_for_size = {}
		local cheapest

		for _, auction_entry in ipairs(existing_auctions[selected_item.key]) do
			if not cheapest_for_size[auction_entry.stack_size] or cheapest_for_size[auction_entry.stack_size].unit_buyout_price >= auction_entry.unit_buyout_price then
				cheapest_for_size[auction_entry.stack_size] = auction_entry
			end

			if not cheapest or cheapest.unit_buyout_price > auction_entry.unit_buyout_price then
				cheapest = auction_entry
			end
		end

        local auction = cheapest_for_size[private.stack_size_slider:GetValue()] or cheapest

        existing_auctions[selected_item.key].selected = auction
        refresh = true
	end
end

function private.validate_parameters()
    private.post_button:Disable()

    if not selected_item then
        return
    end

    if Aux.money.from_string(private.buyout_price:GetText()) > 0 and Aux.money.from_string(private.start_price:GetText()) > Aux.money.from_string(private.buyout_price:GetText()) then
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
        AuxSellParametersItemName:SetTextColor(1, 1, 1)
        AuxSellParametersItemName:SetText('No item selected')

        private.start_price:Hide()
		private.buyout_price:Hide()
        private.stack_size_slider:Hide()
        private.stack_count_slider:Hide()
        private.deposit:Hide()
        private.duration_dropdown:Hide()
        private.pricing_model_dropdown:Hide()
        private.hide_checkbox:Hide()
    else
        private.start_price:Show()
        private.buyout_price:Show()
        private.stack_size_slider:Show()
        private.stack_count_slider:Show()
        private.deposit:Show()
        private.duration_dropdown:Show()
        private.pricing_model_dropdown:Show()
        private.hide_checkbox:Show()

        AuxSellParametersItemIconTexture:SetTexture(selected_item.texture)
        AuxSellParametersItemName:SetText(selected_item.name)
        local color = ITEM_QUALITY_COLORS[selected_item.quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if selected_item.aux_quantity > 1 then
            AuxSellParametersItemCount:SetText(selected_item.aux_quantity)
		else
            AuxSellParametersItemCount:SetText()
        end

        private.stack_size_slider.editbox:SetNumber(private.stack_size_slider:GetValue())
        private.stack_count_slider.editbox:SetNumber(private.stack_count_slider:GetValue())

        -- TODO neutral AH deposit formula
        private.deposit:SetText('Deposit: '..Aux.money.to_string(floor(selected_item.unit_vendor_price * 0.05 * (selected_item.charges and 1 or private.stack_size_slider:GetValue())) * private.stack_count_slider:GetValue() * UIDropDownMenu_GetSelectedValue(private.duration_dropdown) / 120))

        private.refresh_button:Enable()

        local settings = private.load_settings()

        local start_price, buyout_price

        if settings.pricing_model == FIXED then
            start_price, buyout_price = settings.start_price, settings.buyout_price
        elseif settings.pricing_model == MARKET then
            start_price, buyout_price = private.market_value_suggestion()
        elseif settings.pricing_model == UNDERCUT then
            start_price, buyout_price = private.undercutting_suggestion()
        elseif settings.pricing_model == AUTO then
            start_price, buyout_price = private.undercutting_suggestion()
            if existing_auctions[selected_item.key] and not existing_auctions[selected_item.key].selected then
                start_price, buyout_price = private.market_value_suggestion()
            end
        end

        private.start_price:SetText(Aux.money.to_string(start_price))
        private.buyout_price:SetText(Aux.money.to_string(buyout_price))
	end
end

function private.undercutting_suggestion()
    if existing_auctions[selected_item.key] then
        private.select_auction()

        if existing_auctions[selected_item.key].selected then

            local price_suggestion = existing_auctions[selected_item.key].selected.unit_buyout_price * private.stack_size_slider:GetValue()

            if existing_auctions[selected_item.key].selected.yours == 0 then
                price_suggestion = private.undercut(price_suggestion)
            end

            return price_suggestion * 0.95, price_suggestion
        end
    end
    return 0, 0
end

function private.market_value_suggestion()
    local price_suggestion = Aux.history.market_value(selected_item.key) and 1.2 * Aux.history.market_value(selected_item.key) * private.stack_size_slider:GetValue()
    if not price_suggestion then
        return 0, 0
    end
    return price_suggestion * 0.95, price_suggestion
end

function private.quantity_update()
    if selected_item then
        private.stack_count_slider:SetMinMaxValues(1, selected_item.charges and selected_item.availability[private.stack_size_slider:GetValue()] or floor(selected_item.availability[0] / private.stack_size_slider:GetValue()))
    end
	private.update_recommendation()
    refresh = true
end

function private.unit_vendor_price(item_key)
    local inventory_iterator = Aux.util.inventory_iterator()

    while true do
        local slot = inventory_iterator()
        if not slot then
            break
        end

        local item_info = Aux.info.container_item(slot.bag, slot.bag_slot)
        if item_info and item_info.item_key == item_key then

            if Aux.static.item_info(item_info.item_id)
                    and not Aux.info.tooltip_match('soulbound', item_info.tooltip)
                    and not Aux.info.tooltip_match('conjured item', item_info.tooltip)
                    and not item_info.lootable
            then
                ClearCursor()
                PickupContainerItem(slot.bag, slot.bag_slot)
                ClickAuctionSellItemButton()
                local auction_sell_item = Aux.info.auction_sell_item()
                ClearCursor()
                ClickAuctionSellItemButton()
                ClearCursor()

                if auction_sell_item then
                    return auction_sell_item.unit_vendor_price
                end
            end
        end
    end
end

function private.set_item(item)
    local settings = private.load_settings(item)

    item.unit_vendor_price = private.unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = true
        refresh = true
        return
    end

    Aux.scan.abort(function()

        selected_item = item
        refresh = true

        UIDropDownMenu_Initialize(private.duration_dropdown, private.initialize_duration_dropdown) -- TODO, wtf, why is this needed
        UIDropDownMenu_SetSelectedValue(private.duration_dropdown, settings.duration)

        UIDropDownMenu_Initialize(private.pricing_model_dropdown, private.initialize_pricing_model_dropdown)
        UIDropDownMenu_SetSelectedValue(private.pricing_model_dropdown, settings.pricing_model)

        private.stack_size_slider:SetMinMaxValues(1, selected_item.charges and 5 or selected_item.max_stack)
        private.hide_checkbox:SetChecked(settings.hidden)

        private.stack_size_slider:SetValue(settings.stack_size)
        private.quantity_update()
        private.stack_count_slider:SetValue(selected_item.aux_quantity) -- reduced to max possible

        if not existing_auctions[selected_item.key] then
            private.refresh_entries()
        end

        private.update_recommendation()
        refresh = true
    end)

end

function private.update_inventory_records()
    inventory_records = {}
    refresh = true

    local auction_candidate_map = {}

    local inventory_iterator = Aux.util.inventory_iterator()
    while true do
        local slot = inventory_iterator()
        if not slot then
            break
        end

        local item_info = Aux.info.container_item(slot.bag, slot.bag_slot)
        if item_info then
            local charge_class = item_info.charges or 0

            if Aux.static.item_info(item_info.item_id)
                    and not Aux.info.tooltip_match('soulbound', item_info.tooltip)
                    and not Aux.info.tooltip_match('conjured item', item_info.tooltip)
                    and not item_info.lootable
            then
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
        end
    end

    inventory_records = {}
    for _, auction_candidate in pairs(auction_candidate_map) do
        tinsert(inventory_records, auction_candidate)
    end
    sort(inventory_records, function(a, b) return a.name < b.name end)
    refresh = true
end

function private.refresh_entries()
	if selected_item then
		local item_id, suffix_id = selected_item.item_id, selected_item.suffix_id
        local item_key = item_id..':'..suffix_id

        existing_auctions[item_key] = nil

        local query = Aux.scan_util.create_item_query(item_id)

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		Aux.scan.start{
            no_wait_owners = true,
			queries = { query },
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 0) -- TODO
                private.status_bar:set_text(format('Scanning Page %d / %d', page + 1, total_pages))
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
				existing_auctions[item_key] = existing_auctions[item_key] or {}
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
		existing_auctions[key] = existing_auctions[key] or {}
		local entry
		for _, existing_entry in ipairs(existing_auctions[key]) do
			if buyout_price == existing_entry.buyout_price and aux_quantity == existing_entry.stack_size and duration == existing_entry.duration then
				entry = existing_entry
			end
		end
		if entry then
			entry.count = entry.count + 1
			entry.yours = entry.yours + (owner == UnitName('player') and 1 or 0)
			entry.duration = max(entry.duration, duration)
        else
			tinsert(existing_auctions[key], {
                item_key = key,
				stack_size = aux_quantity,
				buyout_price = buyout_price,
                duration = duration,
				unit_buyout_price = buyout_price / aux_quantity,
				duration = duration,
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

function private.initialize_pricing_model_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.pricing_model_dropdown, this.value)
        local settings = private.load_settings()
        settings.pricing_model = this.value
        private.update_recommendation()
    end

    UIDropDownMenu_AddButton{
        text = 'Automatic',
        value = AUTO,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = 'Undercutting',
        value = UNDERCUT,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = 'Market Price',
        value = MARKET,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = 'Fixed',
        value = FIXED,
        func = on_click,
    }
end

function private.initialize_duration_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.duration_dropdown, this.value)
        local settings = private.load_settings()
        settings.duration = this.value
        private.update_recommendation()
    end

    UIDropDownMenu_AddButton{
        text = '2 Hours',
        value = DURATION_4,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = '8 Hours',
        value = DURATION_8,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = '24 Hours',
        value = DURATION_24,
        func = on_click,
    }
end
