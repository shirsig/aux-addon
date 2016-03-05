local private, public = {}, {}
Aux.post_frame = public

local refresh
local existing_auctions = {}
local inventory_records
local selected_item

local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440
local BUYOUT_MODE, BID_MODE, FULL_MODE = 1, 2, 3

function private.load_settings(item_record)
    local item_record = item_record or selected_item
    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}
    dataset.post[item_record.key] = dataset.post[item_record.key] or {
        duration = DURATION_8,
        stack_size = 1,
        start_price = 0,
        buyout_price = 0,
        post_all = true,
        hidden = false,
        mode = FULL_MODE,
    }
    return dataset.post[item_record.key]
end

function private.get_unit_start_price()
    if UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == BUYOUT_MODE then
        return Aux.money.from_string(private.unit_buyout_price:GetText())
    else
        return Aux.money.from_string(private.unit_start_price:GetText())
    end
end

function private.set_unit_start_price(amount)
    if UIDropDownMenu_GetSelectedValue(private.mode_dropdown) ~= BUYOUT_MODE then
        private.unit_start_price:SetText(Aux.money.to_string(amount, true, nil, 3))
    end
end

function private.get_unit_buyout_price()
    if UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == BUYOUT_MODE or UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == FULL_MODE then
        return Aux.money.from_string(private.unit_buyout_price:GetText())
    else
        return 0
    end
end

function private.set_unit_buyout_price(amount)
    if UIDropDownMenu_GetSelectedValue(private.mode_dropdown) ~= BID_MODE then
        private.unit_buyout_price:SetText(Aux.money.to_string(amount, true, nil, 3))
    end
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
            local historical_value = Aux.history.value(auction_record.item_key)

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
                    { value=auction_record.count },
                    { value=auction_record.yours },
                    { value=Aux.auction_listing.time_left(auction_record.duration) },
                    { value=auction_record.stack_size == stack_size and GREEN_FONT_COLOR_CODE..auction_record.stack_size..FONT_COLOR_CODE_CLOSE or auction_record.stack_size },
                    { value=Aux.money.to_string(auction_record.unit_blizzard_bid, true, nil, 3, bid_color) },
                    { value=Aux.money.to_string(auction_record.unit_buyout_price, true, nil, 3, buyout_color) },
                    { value=historical_value and Aux.auction_listing.percentage_historical(Aux.round(auction_record.unit_buyout_price / historical_value * 100)) or '---' },
                },
                record = auction_record,
            })
        end
        sort(auction_rows, function(a, b) return Aux.sort.multi_lt(
            a.record.unit_buyout_price, b.record.unit_buyout_price,
            a.record.unit_blizzard_bid, b.record.unit_blizzard_bid,
            a.record.stack_size, b.record.stack_size,
            a.record.count - a.record.yours, b.record.count - b.record.yours,
            b.record.yours, a.record.yours,
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
        { name='Auctions', width=.12, align='CENTER' },
        { name='Yours', width=.12, align='CENTER' },
        { name='Left', width=.1, align='CENTER' },
        { name='Qty', width=.08, align='CENTER' },
        { name='Bid/ea', width=.23, align='RIGHT' },
        { name='Buy/ea', width=.23, align='RIGHT' },
        { name='Pct', width=.12, align='CENTER' }
    })
    private.auction_listing:DisableSelection(true)
    private.auction_listing:SetHandler('OnClick', function(table, row_data, column, button)
        local column_index = Aux.util.index_of(column, column.row.cols)
        local unit_start_price, unit_buyout_price = private.undercut(row_data.record, private.stack_size_slider:GetValue(), button == 'RightButton')
        if column_index == 5 then
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
        slider:SetPoint('TOPLEFT', 16, -74)
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
        local checkbox = CreateFrame('CheckButton', nil, AuxSellInventory, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPLEFT', private.stack_size_slider, 'BOTTOMLEFT', -3, -7)
        checkbox:SetScript('OnClick', function()
            local settings = private.load_settings()
            settings.post_all = this:GetChecked()
            private.update_recommendation()
            refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Post all')
        private.post_all_checkbox = checkbox
    end
    do
        local slider = Aux.gui.slider(AuxSellParameters)
        slider:SetValueStep(1)
        slider:SetPoint('TOPLEFT', private.stack_size_slider, 'BOTTOMLEFT', 0, -51)
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
        local dropdown = Aux.gui.dropdown(AuxSellParameters)
        dropdown:SetPoint('TOPRIGHT', -15, -42)
        dropdown:SetWidth(120)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Mode')
        UIDropDownMenu_Initialize(dropdown, private.initialize_mode_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_mode_dropdown)
        end)
        private.mode_dropdown = dropdown
    end
    do
        local editbox = Aux.gui.editbox(AuxSellParameters)
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            if selected_item then
                local settings = private.load_settings()
                settings.start_price = Aux.money.from_string(this:GetText())
                local historical_value = Aux.history.value(selected_item.key)
                private.start_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(settings.start_price / historical_value * 100)) or '---')
            end
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
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(Aux.money.from_string(this:GetText()), true, nil, 3))
        end)
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
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            if selected_item then
                local settings = private.load_settings()
                settings.buyout_price = Aux.money.from_string(this:GetText())
                local historical_value = Aux.history.value(selected_item.key)
                private.buyout_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(settings.buyout_price / historical_value * 100)) or '---')
            end
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
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this:SetText(Aux.money.to_string(Aux.money.from_string(this:GetText()), true, nil, 3))
        end)
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
        local btn = Aux.gui.button(AuxSellParameters, 16, '$parentPostButton')
        btn:SetPoint('TOPRIGHT', -15, -163)
        btn:SetWidth(150)
        btn:SetHeight(20)
        btn:GetFontString():SetTextHeight(15)
        btn:GetFontString():SetJustifyH('RIGHT')
        btn:GetFontString():SetPoint('RIGHT', 0, 0)
        btn:SetScript('OnClick', function()
            private.set_unit_start_price(this.amount or 0)
            private.set_unit_buyout_price(this.amount or 0)
        end)
        local label = Aux.gui.label(btn, 13)
        label:SetPoint('BOTTOMLEFT', btn, 'TOPLEFT', -2, 1)
        label:SetText('Historical Value')
        private.historical_value_button = btn
    end
end

function public.on_open()
    private.deposit:SetText('Deposit: '..Aux.money.to_string(0, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))

    private.set_unit_start_price(0)
    private.set_unit_buyout_price(0)

    private.update_inventory_records()

--    if selected_item then
--        public.select_item(selected_item.key)
--    end

    private.update_recommendation()
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
        if private.post_all_checkbox:GetChecked() and not selected_item.charges then
            stack_count = floor(selected_item.aux_quantity / stack_size)
        else
            stack_count = private.stack_count_slider:GetValue()
        end
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
            private.post_all_checkbox:GetChecked() and not selected_item.charges,
			function(posted, partial)
                local new_auction_record
				for i = 1, posted do
                    new_auction_record = private.record_auction(key, stack_size, unit_start_price, unit_buyout_price, duration_code, UnitName('player'))
                end
                if partial then
                    new_auction_record = private.record_auction(key, partial, unit_start_price, unit_buyout_price, duration_code, UnitName('player'))
                end

                private.update_inventory_records()
                selected_item = nil
                for _, record in ipairs(inventory_records) do
                    if record.key == key then
                        private.set_item(record)
                    end
                end

                private.update_recommendation()
                refresh = true
			end
		)
	end
end

--function private.select_auction()
--	if not existing_auctions[selected_item.key].selected and getn(existing_auctions[selected_item.key]) > 0 then
--		local cheapest_for_size = {}
--		local cheapest
--
--		for _, auction_entry in ipairs(existing_auctions[selected_item.key]) do
--			if not cheapest_for_size[auction_entry.stack_size] or cheapest_for_size[auction_entry.stack_size].unit_buyout_price >= auction_entry.unit_buyout_price then
--				cheapest_for_size[auction_entry.stack_size] = auction_entry
--			end
--
--			if not cheapest or cheapest.unit_buyout_price > auction_entry.unit_buyout_price then
--				cheapest = auction_entry
--			end
--		end
--
--        local auction = cheapest_for_size[private.stack_size_slider:GetValue()] or cheapest
--
--        existing_auctions[selected_item.key].selected = auction
--        refresh = true
--	end
--end

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

    if private.stack_count_slider:GetValue() == 0 and (selected_item.charges or not private.post_all_checkbox:GetChecked()) then
        private.post_button:Disable()
        return
    end

    private.post_button:Enable()
end

function private.update_recommendation()

	if not selected_item then
		private.refresh_button:Disable()

		AuxSellParametersItemIconTexture:SetTexture(nil)
        AuxSellParametersItemCount:SetText()
        AuxSellParametersItemName:SetTextColor(unpack(Aux.gui.config.label_color.enabled))
        AuxSellParametersItemName:SetText('No item selected')

        private.mode_dropdown:Hide()
        private.unit_start_price:Hide()
        private.unit_buyout_price:Hide()

        private.stack_size_slider:Hide()
        private.post_all_checkbox:Hide()
        private.stack_count_slider:Hide()
        private.deposit:Hide()
        private.duration_dropdown:Hide()
        private.historical_value_button:Hide()
        private.hide_checkbox:Hide()
    else
        private.mode_dropdown:Show()
        private.unit_start_price:Hide()
        private.unit_buyout_price:Hide()
        private.unit_start_price:ClearAllPoints()
        private.unit_buyout_price:ClearAllPoints()
        if UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == BUYOUT_MODE then
            private.unit_buyout_price:SetPoint('TOPRIGHT', -65, -100)
            private.unit_buyout_price:Show()
        elseif UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == BID_MODE then
            private.unit_start_price:SetPoint('TOPRIGHT', -65, -100)
            private.unit_start_price:Show()
        elseif UIDropDownMenu_GetSelectedValue(private.mode_dropdown) == FULL_MODE then
            private.unit_start_price:SetPoint('TOPRIGHT', -65, -89)
            private.unit_start_price:Show()
            private.unit_buyout_price:SetPoint('TOPRIGHT', private.unit_start_price, 'BOTTOMRIGHT', 0, -15)
            private.unit_buyout_price:Show()
        end

        private.stack_size_slider:Show()
        private.post_all_checkbox:Show()
        if private.post_all_checkbox:GetChecked() then
            private.stack_count_slider:Hide()
        else
            private.stack_count_slider:Show()
        end
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
            local deposit_factor = Aux.neutral and 0.25 or 0.05
            local stack_size = private.stack_size_slider:GetValue()
            local stack_count
            if private.post_all_checkbox:GetChecked() and not selected_item.charges then
                stack_count = floor(selected_item.aux_quantity / stack_size)
            else
                stack_count = private.stack_count_slider:GetValue()
            end
            local deposit = floor(selected_item.unit_vendor_price * deposit_factor * (selected_item.charges and 1 or stack_size)) * stack_count * UIDropDownMenu_GetSelectedValue(private.duration_dropdown) / 120
            if private.post_all_checkbox:GetChecked() and not selected_item.charges then
                local partial_stack = mod(selected_item.aux_quantity, stack_size)
                deposit = deposit + floor(selected_item.unit_vendor_price * deposit_factor * partial_stack) * UIDropDownMenu_GetSelectedValue(private.duration_dropdown) / 120
            end

            private.deposit:SetText('Deposit: '..Aux.money.to_string(deposit, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))
        end

        private.refresh_button:Enable()
	end
end

function private.undercut(record, stack_size, stack)
    local start_price = Aux.round(record.unit_blizzard_bid * (stack and record.stack_size or stack_size))
    local buyout_price = Aux.round(record.unit_buyout_price * (stack and record.stack_size or stack_size))

    if record.yours < record.count then
        start_price = max(0, start_price - 1)
        buyout_price = max(0, buyout_price - 1)
    end

    return start_price / stack_size, buyout_price / stack_size
end

function private.quantity_update()
    if selected_item then
        private.stack_count_slider:SetMinMaxValues(1, selected_item.charges and selected_item.availability[private.stack_size_slider:GetValue()] or floor(selected_item.availability[0] / private.stack_size_slider:GetValue()))
    end
	private.update_recommendation()
    refresh = true
end

function private.auctionable(item_info)
    local durability, max_durability = Aux.info.durability(item_info.tooltip)
    return Aux.static.item_info(item_info.item_id)
            and not Aux.info.tooltip_match('soulbound', item_info.tooltip)
            and not Aux.info.tooltip_match('conjured item', item_info.tooltip)
            and not item_info.lootable
            and not (durability and durability < max_durability)
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

            if private.auctionable(item_info) then
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

    Aux.scan.abort('list')

    selected_item = item
    refresh = true

    UIDropDownMenu_Initialize(private.duration_dropdown, private.initialize_duration_dropdown) -- TODO, wtf, why is this needed
    UIDropDownMenu_SetSelectedValue(private.duration_dropdown, settings.duration)

    UIDropDownMenu_Initialize(private.mode_dropdown, private.initialize_mode_dropdown)
    UIDropDownMenu_SetSelectedValue(private.mode_dropdown, settings.mode)

    private.hide_checkbox:SetChecked(settings.hidden)
    private.post_all_checkbox:SetChecked(settings.post_all)

    private.stack_size_slider:SetMinMaxValues(1, selected_item.charges and 5 or selected_item.max_stack)
    private.stack_size_slider:SetValue(settings.stack_size)
    private.quantity_update()
    private.stack_count_slider:SetValue(selected_item.aux_quantity) -- reduced to max possible

    private.set_unit_start_price(settings.start_price)
    private.set_unit_buyout_price(settings.buyout_price)

    local historical_value = Aux.history.value(selected_item.key)
    private.historical_value_button.amount = historical_value
    private.historical_value_button:SetText(Aux.money.to_string(historical_value or 0, true, nil, 3))

    if not existing_auctions[selected_item.key] then
        private.refresh_entries()
    end

    private.update_recommendation()
    refresh = true
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

            if private.auctionable(item_info) then
                if not auction_candidate_map[item_info.item_key] then

                    local availability = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0 }
                    availability[charge_class] = item_info.count

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

        local query = Aux.scan_util.create_item_query(item_id)

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		Aux.scan.start{
            type = 'list',
            no_wait_owner = true,
			queries = { query },
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 0) -- TODO
                private.status_bar:set_text(format('Scanning Page %d / %d', page + 1, total_pages))
			end,
			on_read_auction = function(auction_info)
				if auction_info.item_key == item_key then
                    private.record_auction(
                        auction_info.item_key,
                        auction_info.aux_quantity,
                        auction_info.unit_blizzard_bid,
                        auction_info.unit_buyout_price,
                        auction_info.duration,
                        auction_info.owner
                    )
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

function private.refresh()
	Aux.scan.abort('list')
    private.refresh_entries()
    private.update_recommendation()
    refresh = true
end

function private.record_auction(key, aux_quantity, unit_blizzard_bid, unit_buyout_price, duration, owner)
	if unit_buyout_price > 0 then
		existing_auctions[key] = existing_auctions[key] or {}
		local entry
		for _, existing_entry in ipairs(existing_auctions[key]) do
			if unit_blizzard_bid == existing_entry.unit_blizzard_bid and unit_buyout_price == existing_entry.unit_buyout_price and aux_quantity == existing_entry.stack_size and duration == existing_entry.duration then
				entry = existing_entry
			end
        end

        if not entry then
            entry = {
                item_key = key,
                stack_size = aux_quantity,
                unit_blizzard_bid = unit_blizzard_bid,
                unit_buyout_price = unit_buyout_price,
                duration = duration,
                count = 0,
                yours = 0,
            }
            tinsert(existing_auctions[key], entry)
        end

        entry.count = entry.count + 1
        entry.yours = entry.yours + (owner == UnitName('player') and 1 or 0)

        return entry
	end
end

function public.on_update()
    if refresh then
        refresh = false
        private.update_inventory_listing()
        private.update_auction_listing()
    end

    private.validate_parameters()
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

function private.initialize_mode_dropdown()
    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.mode_dropdown, this.value)
        local settings = private.load_settings()
        settings.mode = this.value
        private.update_recommendation()
        refresh = true
    end

    UIDropDownMenu_AddButton{
        text = 'Buyout',
        value = BUYOUT_MODE,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = 'Bid',
        value = BID_MODE,
        func = on_click,
    }

    UIDropDownMenu_AddButton{
        text = 'Full',
        value = FULL_MODE,
        func = on_click,
    }
end
