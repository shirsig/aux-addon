function Aux.post_frame.create_frames(private, public)
    Aux.gui.vertical_line(AuxPostFrameContent, 219)

    AuxPostParametersItem:EnableMouse()
    AuxPostParametersItem:SetScript('OnReceiveDrag', function()
        local item_info = Aux.cursor_item()
        if item_info then
            public.select_item(item_info.item_key)
        end
        ClearCursor()
    end)
    AuxPostParametersItem:SetScript('OnClick', function()
        local item_info = Aux.cursor_item()
        if item_info then
            public.select_item(item_info.item_key)
        end
        ClearCursor()
    end)
    local highlight = AuxPostParametersItem:CreateTexture()
    highlight:SetAllPoints(AuxPostParametersItem)
    highlight:Hide()
    highlight:SetTexture(1, .9, .9, .1)
    AuxPostParametersItem:SetScript('OnEnter', function()
        highlight:Show()
        if private.selected_item then
            Aux.info.set_tooltip(private.selected_item.itemstring, this, 'ANCHOR_RIGHT')
        end
    end)
    AuxPostParametersItem:SetScript('OnLeave', function()
        highlight:Hide()
        GameTooltip:Hide()
    end)

    do
        local checkbox = CreateFrame('CheckButton', nil, AuxPostInventory, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPLEFT', 45, -15)
        checkbox:SetScript('OnClick', function()
            private.refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Show hidden items')
        private.show_hidden_checkbox = checkbox
    end

    Aux.gui.horizontal_line(AuxPostInventory, -48)

    private.item_listing = Aux.item_listing.create(
        AuxPostInventory,
        function()
            if arg1 == 'LeftButton' then
                private.set_item(this.item_record)
            elseif arg1 == 'RightButton' then
                Aux.tab_group:set_tab(1)
                Aux.search_frame.set_filter(strlower(Aux.info.item(this.item_record.item_id).name)..'/exact')
                Aux.search_frame.execute()
            end
        end,
        function()
            Aux.info.set_tooltip(this.item_record.itemstring, this, 'ANCHOR_RIGHT')
        end,
        function()
            GameTooltip:Hide()
        end,
        function(item_record)
            return item_record == private.selected_item
        end
    )

    private.auction_listing = Aux.listing.CreateScrollingTable(AuxPostAuctions)
    private.auction_listing:SetColInfo({
        { name='Auctions', width=.12, align='CENTER' },
        { name='Left', width=.1, align='CENTER' },
        { name='Qty', width=.08, align='CENTER' },
        { name='Bid/ea', width=.23, align='RIGHT' },
        { name='Bid Pct', width=.12, align='CENTER' },
        { name='Buy/ea', width=.23, align='RIGHT' },
        { name='Buy Pct', width=.12, align='CENTER' }
    })
    private.auction_listing:EnableSorting(false)
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
        local btn = Aux.gui.button(AuxPostParameters, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Post')
        btn:SetScript('OnClick', private.post_auctions)
        private.post_button = btn
    end
    do
        local btn = Aux.gui.button(AuxPostParameters, 16)
        btn:SetPoint('TOPLEFT', private.post_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', private.refresh)
        private.refresh_button = btn
    end
    do
        local slider = Aux.gui.slider(AuxPostParameters)
        slider:SetValueStep(1)
        slider:SetPoint('TOPLEFT', 16, -75)
        slider:SetWidth(190)
        slider:SetScript('OnValueChanged', function()
            private.quantity_update(true)
        end)
        slider.editbox:SetScript('OnTextChanged', function()
            slider:SetValue(this:GetNumber())
            private.quantity_update(true)
            if private.selected_item then
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
        local slider = Aux.gui.slider(AuxPostParameters)
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
        local dropdown = Aux.gui.dropdown(AuxPostParameters)
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
        local checkbox = CreateFrame('CheckButton', nil, AuxPostParameters, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPRIGHT', -85, -6)
        checkbox:SetScript('OnClick', function()
            local settings = private.read_settings()
            settings.hidden = this:GetChecked()
            private.write_settings(settings)
            private.refresh = true
        end)
        local label = Aux.gui.label(checkbox, 13)
        label:SetPoint('LEFT', checkbox, 'RIGHT', 2, 1)
        label:SetText('Hide this item')
        private.hide_checkbox = checkbox
    end
    do
        local editbox = Aux.gui.editbox(AuxPostParameters)
        editbox:SetPoint('TOPRIGHT', -65, -66)
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            this.pretty:SetText(Aux.money.to_string(private.get_unit_start_price(), true, nil, 3))
            private.refresh = true
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
            this:HighlightText()
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
        local editbox = Aux.gui.editbox(AuxPostParameters)
        editbox:SetPoint('TOPRIGHT', private.unit_start_price, 'BOTTOMRIGHT', 0, -18)
        editbox:SetJustifyH('RIGHT')
        editbox:SetWidth(150)
        editbox:SetScript('OnTextChanged', function()
            this.pretty:SetText(Aux.money.to_string(private.get_unit_buyout_price(), true, nil, 3))
            private.refresh = true
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
            this:HighlightText()
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
        local btn = Aux.gui.button(AuxPostParameters, 16)
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