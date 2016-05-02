local private, public = {}, {}
Aux.post_frame = public

local refresh
local existing_auctions = {}
local inventory_records
local selected_item
local scan_id

local settings_schema = {'record', '#', {stack_size='number'}, {duration='number'}, {start_price='number'}, {buyout_price='number'}, {hidden='boolean'}}

local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440

function private.default_settings()
    return {
        duration = DURATION_8,
        stack_size = 1,
        start_price = 0,
        buyout_price = 0,
        hidden = false,
    }
end

function private.read_settings(item_key)
    item_key = item_key or selected_item.key
    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    local settings
    if dataset.post[item_key] then
        settings = Aux.persistence.read(settings_schema, dataset.post[item_key])
    else
        settings = private.default_settings()
    end
    return settings
end

function private.write_settings(settings, item_key)
    item_key = item_key or selected_item.key

    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    dataset.post[item_key] = Aux.persistence.write(settings_schema, settings)
end

function private.get_unit_start_price()
    local money_text = private.unit_start_price:GetText()
    return Aux.money.from_string(money_text) or (tonumber(money_text) and tonumber(money_text) * 10000) or 0
end

function private.set_unit_start_price(amount)
    private.unit_start_price:SetText(Aux.money.to_string(amount, true, nil, 3))
end

function private.get_unit_buyout_price()
    local money_text = private.unit_buyout_price:GetText()
    return Aux.money.from_string(money_text) or (tonumber(money_text) and tonumber(money_text) * 10000) or 0
end

function private.set_unit_buyout_price(amount)
    private.unit_buyout_price:SetText(Aux.money.to_string(amount, true, nil, 3))
end

function private.update_inventory_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    Aux.item_listing.populate(private.item_listing, Aux.util.filter(inventory_records, function(record)
        local settings = private.read_settings(record.key)
        return record.aux_quantity > 0 and (not settings.hidden or private.show_hidden_checkbox:GetChecked())
    end))
end

function private.update_auction_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    local auction_rows = {}
    if selected_item then
        local unit_start_price = private.get_unit_start_price()
        local unit_buyout_price = private.get_unit_buyout_price()

        for i, auction_record in ipairs(existing_auctions[selected_item.key] or {}) do

            local blizzard_bid_undercut, buyout_price_undercut = private.undercut(auction_record, private.stack_size_slider:GetValue())
            blizzard_bid_undercut = Aux.money.from_string(Aux.money.to_string(blizzard_bid_undercut, true, nil, 3))
            buyout_price_undercut = Aux.money.from_string(Aux.money.to_string(buyout_price_undercut, true, nil, 3))

            local stack_blizzard_bid_undercut, stack_buyout_price_undercut = private.undercut(auction_record, private.stack_size_slider:GetValue(), true)
            stack_blizzard_bid_undercut = Aux.money.from_string(Aux.money.to_string(stack_blizzard_bid_undercut, true, nil, 3))
            stack_buyout_price_undercut = Aux.money.from_string(Aux.money.to_string(stack_buyout_price_undercut, true, nil, 3))

            local stack_size = private.stack_size_slider:GetValue()
            local historical_value = Aux.history.value(selected_item.key)

            local bid_color
            if blizzard_bid_undercut < unit_start_price and stack_blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffff0000'
            elseif blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffff9218'
            elseif stack_blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffffff00'
            end

            local buyout_color
            if buyout_price_undercut < unit_buyout_price and stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffff0000'
            elseif buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffff9218'
            elseif stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffffff00'
            end

            tinsert(auction_rows, {
                cols = {
                    { value=auction_record.own and GREEN_FONT_COLOR_CODE..auction_record.count..FONT_COLOR_CODE_CLOSE or auction_record.count },
                    { value=Aux.auction_listing.time_left(auction_record.duration) },
                    { value=auction_record.stack_size == stack_size and GREEN_FONT_COLOR_CODE..auction_record.stack_size..FONT_COLOR_CODE_CLOSE or auction_record.stack_size },
                    { value=Aux.money.to_string(auction_record.unit_blizzard_bid, true, nil, 3, bid_color) },
                    { value=historical_value and Aux.auction_listing.percentage_historical(Aux.round(auction_record.unit_blizzard_bid / historical_value * 100)) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and Aux.money.to_string(auction_record.unit_buyout_price, true, nil, 3, buyout_color) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and historical_value and Aux.auction_listing.percentage_historical(Aux.round(auction_record.unit_buyout_price / historical_value * 100)) or '---' },
                },
                record = auction_record,
            })
        end
        sort(auction_rows, function(a, b) return Aux.sort.multi_lt(
            a.record.unit_buyout_price == 0 and Aux.huge or a.record.unit_buyout_price, b.record.unit_buyout_price == 0 and Aux.huge or b.record.unit_buyout_price,
            a.record.unit_blizzard_bid, b.record.unit_blizzard_bid,
            a.record.stack_size, b.record.stack_size,
            b.record.own and 1 or 0, a.record.own and 1 or 0,
            a.record.duration, b.record.duration
        ) end)
    end
    private.auction_listing:SetData(auction_rows)
end

function public.select_item(item_key)
    for _, inventory_record in ipairs(Aux.util.filter(inventory_records, function(record) return record.aux_quantity > 0 end)) do
        if inventory_record.key == item_key then
            private.set_item(inventory_record)
            break
        end
    end
end

function public.on_load()

    Aux.gui.vertical_line(AuxPostFrameContent, 219)

    AuxSellParametersItem:EnableMouse()
    AuxSellParametersItem:SetScript('OnReceiveDrag', function()
        local item_info = Aux.cursor_item()
        if item_info then
            public.select_item(item_info.item_key)
        end
        ClearCursor()
    end)
--    AuxSellParametersItemIconTexture:SetScript('OnEnter', function()
--        if selected_item then
--            Aux.info.set_tooltip(selected_item.itemstring, this, 'ANCHOR_RIGHT')
--        end
--    end)
--    AuxSellParametersItemIconTexture:SetScript('OnLeave', function()
--        GameTooltip:Hide()
--    end)

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
            if arg1 == 'LeftButton' then
                private.set_item(this.item_record)
            elseif arg1 == 'RightButton' then
                Aux.tab_group:set_tab(1)
                Aux.search_frame.start_search(strlower(Aux.info.item(this.item_record.item_id).name)..'/exact')
            end
        end,
        function()
            Aux.info.set_tooltip(this.item_record.itemstring, this, 'ANCHOR_RIGHT')
        end,
        function()
            GameTooltip:Hide()
        end,
        function(item_record)
            return item_record == selected_item
        end
    )

    private.auction_listing = Aux.listing.CreateScrollingTable(AuxSellAuctions)
    private.auction_listing:SetColInfo({
        { name='Auctions', width=.12, align='CENTER' },
        { name='Left', width=.1, align='CENTER' },
        { name='Qty', width=.08, align='CENTER' },
        { name='Bid/ea', width=.23, align='RIGHT' },
        { name='Bid Pct', width=.12, align='CENTER' },
        { name='Buy/ea', width=.23, align='RIGHT' },
        { name='Buy Pct', width=.12, align='CENTER' }
    })
    private.auction_listing:DisableSelection(true)
    private.auction_listing:SetHandler('OnClick', function(table, row_data, column, button)
        local column_index = Aux.util.index_of(column, column.row.cols)
        local unit_start_price, unit_buyout_price = private.undercut(row_data.record, private.stack_size_slider:GetValue(), button == 'RightButton')
        if column_index == 3 then
            private.stack_size_slider:SetValue(row_data.record.stack_size)
        elseif column_index == 4 then
            private.set_unit_start_price(unit_start_price)
        elseif column_index == 6 then
            private.set_unit_buyout_price(unit_buyout_price)
        end
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
        local btn = Aux.gui.button(AuxSellParameters, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Post')
        btn:SetScript('OnClick', private.post_auctions)
        private.post_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 16)
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
            private.quantity_update(true)
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            slider:SetValue(this:GetNumber())
            private.quantity_update(true)
            if selected_item then
                local settings = private.read_settings()
                settings.stack_size = this:GetNumber()
                private.write_settings(settings)
            end
        end)
        slider.editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.unit_buyout_price:SetFocus()
            elseif private.stack_count_slider.editbox:IsVisible() then
                private.stack_count_slider.editbox:SetFocus()
            else
                private.unit_start_price:SetFocus()
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
        slider.editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.stack_size_slider.editbox:SetFocus()
            else
                private.unit_start_price:SetFocus()
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
        dropdown:SetPoint('TOPLEFT', private.stack_count_slider, 'BOTTOMLEFT', 0, -19)
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
            local settings = private.read_settings()
            settings.hidden = this:GetChecked()
            private.write_settings(settings)
            refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Hide this item')
        private.hide_checkbox = checkbox
    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetPoint('TOPRIGHT', -65, -66)
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            this.pretty:SetText(Aux.money.to_string(private.get_unit_start_price(), true, nil, 3))
            refresh = true
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() and private.stack_count_slider.editbox:IsVisible() then
                private.stack_count_slider.editbox:SetFocus()
            elseif IsShiftKeyDown() then
                private.stack_size_slider.editbox:SetFocus()
            else
                private.unit_buyout_price:SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this.pretty:Hide()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(private.get_unit_start_price(), true, nil, 3, nil, true))
            this.pretty:Show()
        end)
        editbox.pretty = Aux.gui.label(editbox, Aux.gui.config.normal_font_size)
        editbox.pretty:SetAllPoints()
        editbox.pretty:SetJustifyH('RIGHT')
        do
            local label = Aux.gui.label(editbox, 13)
            label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
            label:SetText('Unit Starting Price')
        end
        do
            local label = Aux.gui.label(editbox, 13)
            label:SetPoint('LEFT', editbox, 'RIGHT', 3, 0)
            label:SetWidth(50)
            label:SetJustifyH('CENTER')
            private.start_price_percentage = label
        end
        private.unit_start_price = editbox
    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetPoint('TOPRIGHT', private.unit_start_price, 'BOTTOMRIGHT', 0, -18)
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            this.pretty:SetText(Aux.money.to_string(private.get_unit_buyout_price(), true, nil, 3))
            refresh = true
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.unit_start_price:SetFocus()
            else
                private.stack_size_slider.editbox:SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this.pretty:Hide()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(private.get_unit_buyout_price(), true, nil, 3, nil, true))
            this.pretty:Show()
        end)
        editbox.pretty = Aux.gui.label(editbox, Aux.gui.config.normal_font_size)
        editbox.pretty:SetAllPoints()
        editbox.pretty:SetJustifyH('RIGHT')
        do
            local label = Aux.gui.label(editbox, 13)
            label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
            label:SetText('Unit Buyout Price')
        end
        do
            local label = Aux.gui.label(editbox, 13)
            label:SetPoint('LEFT', editbox, 'RIGHT', 3, 0)
            label:SetWidth(50)
            label:SetJustifyH('CENTER')
            private.buyout_price_percentage = label
        end
        private.unit_buyout_price = editbox
    end
    do
        local btn = Aux.gui.button(AuxSellParameters, 16)
        btn:SetPoint('TOPRIGHT', -15, -143)
        btn:SetWidth(150)
        btn:SetHeight(20)
        btn:GetFontString():SetTextHeight(15)
        btn:GetFontString():SetJustifyH('RIGHT')
        btn:GetFontString():SetPoint('RIGHT', 0, 0)
        btn:SetScript('OnClick', function()
            if this.amount then
                private.set_unit_start_price(this.amount)
                private.set_unit_buyout_price(this.amount)
            end
        end)
        local label = Aux.gui.label(btn, 13)
        label:SetPoint('BOTTOMLEFT', btn, 'TOPLEFT', -2, 1)
        label:SetText('Historical Value')
        private.historical_value_button = btn
    end
end

function private.price_update()
    if selected_item then
        local settings = private.read_settings()

        local start_price_input = private.get_unit_start_price()
        settings.start_price = start_price_input
        local historical_value = Aux.history.value(selected_item.key)
        private.start_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(start_price_input / historical_value * 100)) or '---')

        local buyout_price_input = private.get_unit_buyout_price()
        settings.buyout_price = buyout_price_input
        local historical_value = Aux.history.value(selected_item.key)
        private.buyout_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(buyout_price_input / historical_value * 100)) or '---')

        private.write_settings(settings)
    end
end

function public.on_open()
    private.deposit:SetText('Deposit: '..Aux.money.to_string(0, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))

    private.set_unit_start_price(0)
    private.set_unit_buyout_price(0)

    private.update_inventory_records()

    refresh = true
end

function public.on_close()
    selected_item = nil
end

function private.post_auctions()
	if selected_item then
        local unit_start_price = private.get_unit_start_price()
        local unit_buyout_price = private.get_unit_buyout_price()
        local stack_size = private.stack_size_slider:GetValue()
        local stack_count
        stack_count = private.stack_count_slider:GetValue()
        local duration = UIDropDownMenu_GetSelectedValue(private.duration_dropdown)
		local key = selected_item.key

        local duration_code
		if duration == DURATION_4 then
            duration_code = 2
		elseif duration == DURATION_8 then
            duration_code = 3
		elseif duration == DURATION_24 then
            duration_code = 4
		end

		Aux.post.start(
			key,
			stack_size,
			duration,
            unit_start_price,
            unit_buyout_price,
			stack_count,
			function(posted)
                local new_auction_record
				for i = 1, posted do
                    new_auction_record = private.record_auction(key, stack_size, unit_start_price, unit_buyout_price, duration_code, UnitName('player'))
                end

                private.update_inventory_records()
                selected_item = nil
                for _, record in ipairs(inventory_records) do
                    if record.key == key then
                        private.set_item(record)
                    end
                end

                refresh = true
			end
		)
	end
end

function private.validate_parameters()

    if not selected_item then
        private.post_button:Disable()
        return
    end

    if private.get_unit_buyout_price() > 0 and private.get_unit_start_price() > private.get_unit_buyout_price() then
        private.post_button:Disable()
        return
    end

    if private.get_unit_start_price() < 1 then
        private.post_button:Disable()
        return
    end

    if private.stack_count_slider:GetValue() == 0 then
        private.post_button:Disable()
        return
    end

    private.post_button:Enable()
end

function private.update_item_configuration()

	if not selected_item then
		private.refresh_button:Disable()

		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetTextColor(unpack(Aux.gui.config.label_color.enabled))
        AuxSellParametersItemName:SetText('No item selected')

        private.unit_start_price:Hide()
        private.unit_buyout_price:Hide()
        private.stack_size_slider:Hide()
        private.stack_count_slider:Hide()
        private.deposit:Hide()
        private.duration_dropdown:Hide()
        private.historical_value_button:Hide()
        private.hide_checkbox:Hide()
    else
        private.unit_start_price:Show()
        private.unit_buyout_price:Show()
        private.stack_size_slider:Show()
        private.stack_count_slider:Show()
        private.deposit:Show()
        private.duration_dropdown:Show()
        private.historical_value_button:Show()
        private.hide_checkbox:Show()

        AuxSellParametersItemIconTexture:SetTexture(selected_item.texture)
        AuxSellParametersItemName:SetText('['..selected_item.name..']')
        local color = ITEM_QUALITY_COLORS[selected_item.quality]
        AuxSellParametersItemName:SetTextColor(color.r, color.g, color.b)
		if selected_item.aux_quantity > 1 then
            AuxSellParametersItemCount:SetText(selected_item.aux_quantity)
		else
            AuxSellParametersItemCount:SetText()
        end

        private.stack_size_slider.editbox:SetNumber(private.stack_size_slider:GetValue())
        private.stack_count_slider.editbox:SetNumber(private.stack_count_slider:GetValue())

        do
            local deposit_factor = Aux.neutral_faction() and 0.25 or 0.05
            local stack_size = private.stack_size_slider:GetValue()
            local stack_count
            stack_count = private.stack_count_slider:GetValue()
            local deposit = floor(selected_item.unit_vendor_price * deposit_factor * (selected_item.max_charges and 1 or stack_size)) * stack_count * UIDropDownMenu_GetSelectedValue(private.duration_dropdown) / 120

            private.deposit:SetText('Deposit: '..Aux.money.to_string(deposit, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))
        end

        private.refresh_button:Enable()
	end
end

function private.undercut(record, stack_size, stack)
    local start_price = Aux.round(record.unit_blizzard_bid * (stack and record.stack_size or stack_size))
    local buyout_price = Aux.round(record.unit_buyout_price * (stack and record.stack_size or stack_size))

    if not record.own then
        start_price = max(0, start_price - 1)
        buyout_price = max(0, buyout_price - 1)
    end

    return start_price / stack_size, buyout_price / stack_size
end

function private.quantity_update(max_count)
    if selected_item then
        local max_stack_count = selected_item.max_charges and selected_item.availability[private.stack_size_slider:GetValue()] or floor(selected_item.availability[0] / private.stack_size_slider:GetValue())
        private.stack_count_slider:SetMinMaxValues(1, max_stack_count)
        if max_count then
            private.stack_count_slider:SetValue(max_stack_count)
        end
    end
    refresh = true
end

function private.unit_vendor_price(item_key)

    for slot in Aux.util.inventory() do

        local item_info = Aux.info.container_item(unpack(slot))
        if item_info and item_info.item_key == item_key then

            if Aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                ClearCursor()
                PickupContainerItem(unpack(slot))
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

function private.update_historical_value_button()
    if selected_item then
        local historical_value = Aux.history.value(selected_item.key)
        private.historical_value_button.amount = historical_value
        private.historical_value_button:SetText(historical_value and Aux.money.to_string(historical_value, true, nil, 3) or '---')
    end
end

function private.set_item(item)
    local settings = private.read_settings(item.key)

    item.unit_vendor_price = private.unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = 1
        private.write_settings(settings, item.key)
        refresh = true
        return
    end

    Aux.scan.abort(scan_id)

    selected_item = item

    UIDropDownMenu_Initialize(private.duration_dropdown, private.initialize_duration_dropdown) -- TODO, wtf, why is this needed
    UIDropDownMenu_SetSelectedValue(private.duration_dropdown, settings.duration)

    private.hide_checkbox:SetChecked(settings.hidden)

    private.stack_size_slider:SetMinMaxValues(1, selected_item.max_charges or selected_item.max_stack)
    private.stack_size_slider:SetValue(settings.stack_size)
    private.quantity_update(true)

    private.unit_start_price:SetText(Aux.money.to_string(settings.start_price, true, nil, 3, nil, true))
    private.unit_buyout_price:SetText(Aux.money.to_string(settings.buyout_price, true, nil, 3, nil, true))

    if not existing_auctions[selected_item.key] then
        private.refresh_entries()
    end

    private.write_settings(settings, item.key)
    refresh = true
end

function private.update_inventory_records()
    inventory_records = {}
    refresh = true

    local auction_candidate_map = {}

    for slot in Aux.util.inventory() do

        local item_info = Aux.info.container_item(unpack(slot))
        if item_info then
            local charge_class = item_info.charges or 0

            if Aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                if not auction_candidate_map[item_info.item_key] then

                    local availability = {}
                    for i=0,10 do
                        availability[i] = 0
                    end
                    availability[charge_class] = item_info.count

                    auction_candidate_map[item_info.item_key] = {
                        item_id = item_info.item_id,
                        suffix_id = item_info.suffix_id,

                        key = item_info.item_key,
                        itemstring = item_info.itemstring,

                        name = item_info.name,
                        texture = item_info.texture,
                        quality = item_info.quality,
                        aux_quantity = item_info.charges or item_info.count,
                        max_stack = item_info.max_stack,
                        max_charges = item_info.max_charges,
                        availability = availability,
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

        local query = Aux.scan_util.item_query(item_id)

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		scan_id = Aux.scan.start{
            type = 'list',
            ignore_owner = true,
			queries = { query },
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 0) -- TODO
                private.status_bar:set_text(format('Scanning Page %d / %d', page + 1, total_pages))
			end,
			on_auction = function(auction_record)
				if auction_record.item_key == item_key then
                    private.record_auction(
                        auction_record.item_key,
                        auction_record.aux_quantity,
                        auction_record.unit_blizzard_bid,
                        auction_record.unit_buyout_price,
                        auction_record.duration,
                        auction_record.owner
                    )
				end
			end,
			on_abort = function()
				existing_auctions[item_key] = nil
                private.update_historical_value_button()
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
			end,
			on_complete = function()
				existing_auctions[item_key] = existing_auctions[item_key] or {}
                refresh = true
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
            end,
		}
	end
end

function private.refresh()
	Aux.scan.abort(scan_id)
    private.refresh_entries()
    refresh = true
end

function private.record_auction(key, aux_quantity, unit_blizzard_bid, unit_buyout_price, duration, owner)
    existing_auctions[key] = existing_auctions[key] or {}
    local entry
    for _, existing_entry in ipairs(existing_auctions[key]) do
        if unit_blizzard_bid == existing_entry.unit_blizzard_bid and unit_buyout_price == existing_entry.unit_buyout_price and aux_quantity == existing_entry.stack_size and duration == existing_entry.duration and Aux.is_player(owner) == existing_entry.own then
            entry = existing_entry
        end
    end

    if not entry then
        entry = {
            stack_size = aux_quantity,
            unit_blizzard_bid = unit_blizzard_bid,
            unit_buyout_price = unit_buyout_price,
            duration = duration,
            own = Aux.is_player(owner),
            count = 0,
        }
        tinsert(existing_auctions[key], entry)
    end

    entry.count = entry.count + 1

    return entry
end

function public.on_update()
    if refresh then
        refresh = false
        private.price_update()
        private.update_historical_value_button()
        private.update_item_configuration()
        private.update_inventory_listing()
        private.update_auction_listing()
    end

    private.validate_parameters()
end

function private.initialize_duration_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.duration_dropdown, this.value)
        local settings = private.read_settings()
        settings.duration = this.value
        private.write_settings(settings)
        refresh = true
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
