function Aux.search_frame.create_frames(private, public)
    do
        local btn = Aux.gui.button(AuxSearchFrame, 26)
        btn:SetPoint('TOPLEFT', 5, -8)
        btn:SetWidth(30)
        btn:SetHeight(25)
        btn:SetText('<')
        btn:SetScript('OnClick', private.previous_search)
        private.previous_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 26)
        btn:SetPoint('LEFT', private.previous_button, 'RIGHT', 4, 0)
        btn:SetWidth(30)
        btn:SetHeight(25)
        btn:SetText('>')
        btn:SetScript('OnClick', private.next_search)
        private.next_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 22)
        btn:SetPoint('TOPRIGHT', -5, -8)
        btn:SetWidth(69)
        btn:SetHeight(25)
        btn:SetText('Resume')
        btn:SetScript('OnClick', function()
            private.search_box:ClearFocus()
            public.execute('resume')
        end)
        private.resume_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 22)
        btn:SetPoint('RIGHT', private.resume_button, 'LEFT', -4, 0)
        btn:SetWidth(72)
        btn:SetHeight(25)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            public.execute('refresh')
        end)
        btn:Disable()
        private.refresh_button = btn
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrame)
        editbox:SetMaxLetters(nil)
        editbox:EnableMouse(1)
        editbox.complete = Aux.completion.complete
        editbox:SetPoint('RIGHT', private.refresh_button, 'LEFT', -4, 0)
        editbox:SetHeight(25)
        editbox:SetScript('OnChar', function()
            this:complete()
        end)
        editbox:SetScript('OnTabPressed', function()
            this:HighlightText(0, 0)
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:HighlightText(0, 0)
            this:ClearFocus()
            public.execute('search')
        end)
        editbox:SetScript('OnReceiveDrag', function()
            local item_info = Aux.cursor_item() and Aux.info.item(Aux.cursor_item().item_id)
            if item_info then
                public.execute('search', strlower(item_info.name)..'/exact')
            end
            ClearCursor()
        end)
        private.search_box = editbox
    end
    do
        Aux.gui.horizontal_line(AuxSearchFrame, -40)
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 18)
        btn:SetPoint('BOTTOMLEFT', AuxFrameContent, 'TOPLEFT', 10, 8)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('Search Results')
        btn:SetScript('OnClick', function() private.update_tab(private.RESULTS) end)
        private.search_results_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.search_results_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('Saved Searches')
        btn:SetScript('OnClick', function() private.update_tab(private.SAVED) end)
        private.saved_searches_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.saved_searches_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('New Filter')
        btn:SetScript('OnClick', function() private.update_tab(private.FILTER) end)
        private.new_filter_button = btn
    end
    do
        local status_bar = Aux.gui.status_bar(AuxSearchFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 100)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameResults, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameResults, 16)
        btn:SetPoint('TOPLEFT', private.bid_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameResults, 16)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Clear')
        btn:SetScript('OnClick', function()
            while tremove(private:current_search().records) do end
            private.results_listing:SetDatabase()
        end)
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameSaved, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Favorite')
        btn:SetScript('OnClick', function()
            local filters = Aux.scan_util.parse_filter_string(private.search_box:GetText())
            if filters then
                tinsert(aux_favorite_searches, 1, {
                    filter_string = private.search_box:GetText(),
                    prettified = Aux.util.join(Aux.util.map(filters, function(filter) return filter.prettified end), ';'),
                })
            end
            private.update_search_listings()
        end)
    end
    do
        local btn1 = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn1:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn1:SetWidth(80)
        btn1:SetHeight(24)
        btn1:SetText('Search')
        btn1:SetScript('OnClick', function()
            private.search_box:SetText('')
            private.add_filter()
            private.clear_form()
            public.execute('search')
        end)

        local btn2 = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
        btn2:SetWidth(80)
        btn2:SetHeight(24)
        btn2:SetText('Add')
        btn2:SetScript('OnClick', function()
            private.add_filter()
            private.clear_form()
        end)

        local btn3 = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
        btn3:SetWidth(80)
        btn3:SetHeight(24)
        btn3:SetText('Replace')
        btn3:SetScript('OnClick', function()
            private.add_filter(nil, true)
            private.clear_form()
        end)
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrameFilter, '$parentNameInputBox')
        editbox.complete_item = Aux.completion.completor(function() return aux_auctionable_items end)
        editbox:SetPoint('TOPLEFT', 14, -20)
        editbox:SetWidth(260)
        editbox:SetScript('OnChar', function()
            if AuxSearchFrameFilterExactCheckButton:GetChecked() then
                this:complete_item()
            end
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.last_page_editbox:SetFocus()
            else
                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.execute('search')
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Name')
    end
    do
        local checkbox = CreateFrame('CheckButton', '$parentExactCheckButton', AuxSearchFrameFilter, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPLEFT', AuxSearchFrameFilterNameInputBox, 'TOPRIGHT', 10, 0)
        local label = Aux.gui.label(AuxSearchFrameFilterExactCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxSearchFrameFilterExactCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('Exact')
        private.show_hidden_checkbox = checkbox
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrameFilter, '$parentMinLevel')
        editbox:SetPoint('TOPLEFT', AuxSearchFrameFilterNameInputBox, 'BOTTOMLEFT', 0, -22)
        editbox:SetWidth(125)
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.execute('search')
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Level Range')
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrameFilter, '$parentMaxLevel')
        editbox:SetPoint('TOPLEFT', AuxSearchFrameFilterMinLevel, 'TOPRIGHT', 10, 0)
        editbox:SetWidth(125)
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
            else
                private.first_page_editbox:SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.execute('search')
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('RIGHT', editbox, 'LEFT', -4, 0)
        label:SetText('-')
    end
    do
        local checkbox = CreateFrame('CheckButton', '$parentUsableCheckButton', AuxSearchFrameFilter, 'UICheckButtonTemplate')
        checkbox:SetWidth(22)
        checkbox:SetHeight(22)
        checkbox:SetPoint('TOPLEFT', AuxSearchFrameFilterMaxLevel, 'TOPRIGHT', 10, 0)
        local label = Aux.gui.label(AuxSearchFrameFilterUsableCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxSearchFrameFilterUsableCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('Usable')
        private.show_hidden_checkbox = checkbox
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSearchFrameFilter)
        dropdown:SetPoint('TOPLEFT', AuxSearchFrameFilterMinLevel, 'BOTTOMLEFT', 0, -18)
        dropdown:SetWidth(300)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Item Class')
        UIDropDownMenu_Initialize(dropdown, private.initialize_class_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_class_dropdown)
        end)
        private.class_dropdown = dropdown
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSearchFrameFilter)
        dropdown:SetPoint('TOPLEFT', private.class_dropdown, 'BOTTOMLEFT', 0, -18)
        dropdown:SetWidth(300)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Item Subclass')
        UIDropDownMenu_Initialize(dropdown, private.initialize_subclass_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_subclass_dropdown)
        end)
        private.subclass_dropdown = dropdown
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSearchFrameFilter)
        dropdown:SetPoint('TOPLEFT', private.subclass_dropdown, 'BOTTOMLEFT', 0, -18)
        dropdown:SetWidth(300)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Item Slot')
        UIDropDownMenu_Initialize(dropdown, private.initialize_slot_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_slot_dropdown)
        end)
        private.slot_dropdown = dropdown
    end
    do
        local dropdown = Aux.gui.dropdown(AuxSearchFrameFilter)
        dropdown:SetPoint('TOPLEFT', private.slot_dropdown, 'BOTTOMLEFT', 0, -18)
        dropdown:SetWidth(300)
        dropdown:SetHeight(10)
        local label = Aux.gui.label(dropdown, 13)
        label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -4)
        label:SetText('Min Rarity')
        UIDropDownMenu_Initialize(dropdown, private.initialize_quality_dropdown)
        dropdown:SetScript('OnShow', function()
            UIDropDownMenu_Initialize(this, private.initialize_quality_dropdown)
        end)
        private.quality_dropdown = dropdown
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrameFilter)
        editbox:SetPoint('TOPLEFT', private.quality_dropdown, 'BOTTOMLEFT', 0, -18)
        editbox:SetWidth(145)
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                private.last_page_editbox:SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.execute('search')
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Page Range')
        private.first_page_editbox = editbox
    end
    do
        local editbox = Aux.gui.editbox(AuxSearchFrameFilter)
        editbox:SetPoint('TOPLEFT', private.first_page_editbox, 'TOPRIGHT', 10, 0)
        editbox:SetWidth(145)
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                private.first_page_editbox:SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.execute('search')
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('RIGHT', editbox, 'LEFT', -4, 0)
        label:SetText('-')
        private.last_page_editbox = editbox
    end
    Aux.gui.vertical_line(AuxSearchFrameFilter, 332)
    do
        local label = Aux.gui.label(AuxSearchFrameFilterUsableCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxSearchFrameFilterUsableCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('Usable')
    end
    local function add_modifier(...)
        local current_filter_string = private.search_box:GetText()
        for i=1,arg.n do
            if current_filter_string ~= '' and strsub(current_filter_string, -1) ~= '/' then
                current_filter_string = current_filter_string..'/'
            end
            current_filter_string = current_filter_string..arg[i]
        end
        private.search_box:SetText(current_filter_string)
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPRIGHT', -362, -10)
        btn:SetWidth(50)
        btn:SetHeight(19)
        btn:SetText('and')
        btn:SetScript('OnClick', function()
            add_modifier('and')
        end)
        private.and_operator_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('LEFT', private.and_operator_button, 'RIGHT', 10, 0)
        btn:SetWidth(50)
        btn:SetHeight(19)
        btn:SetText('or')
        btn:SetScript('OnClick', function()
            add_modifier('or')
        end)
        private.or_operator_button = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('LEFT', private.or_operator_button, 'RIGHT', 10, 0)
        btn:SetWidth(50)
        btn:SetHeight(19)
        btn:SetText('not')
        btn:SetScript('OnClick', function()
            add_modifier('not')
        end)
        private.not_operator_button = btn
    end
    private.modifier_buttons = {}
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.and_operator_button, 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['min-unit-bid'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['min-unit-bid'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['min-unit-buy'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['min-unit-buy'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['max-unit-bid'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['max-unit-bid'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['max-unit-buy'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['max-unit-buy'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['bid-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['bid-profit'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['buy-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['buy-profit'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['bid-vend-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['bid-vend-profit'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['buy-vend-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['buy-vend-profit'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['bid-dis-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['bid-dis-profit'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['buy-dis-profit'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.and_operator_button, 'BOTTOMLEFT', 205, -10)
        private.modifier_buttons['bid-pct'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['bid-pct'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['buy-pct'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['buy-pct'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['item'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['item'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['tooltip'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['tooltip'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['min-lvl'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['min-lvl'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['max-lvl'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['max-lvl'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['rarity'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['rarity'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['left'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['left'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['utilizable'] = btn
    end
    do
        local btn = Aux.gui.button(AuxSearchFrameFilter, 16)
        btn:SetPoint('TOPLEFT', private.modifier_buttons['utilizable'], 'BOTTOMLEFT', 0, -10)
        private.modifier_buttons['discard'] = btn
    end
    for modifier_name, btn in private.modifier_buttons do
        local modifier_name = modifier_name
        local btn = btn

        local filter = Aux.scan_util.filters[modifier_name]

        btn:SetWidth(100)
        btn:SetHeight(19)
        btn:SetText(modifier_name)
        btn:SetScript('OnClick', function()
            local args = Aux.util.map(btn.inputs, function(input) return input:GetText() end)
            if filter.test(unpack(args)) then
                add_modifier(modifier_name, unpack(args))
                for _, input in btn.inputs do
                    input:SetText('')
                    input:ClearFocus()
                end
            end
        end)
        btn.inputs = {}
        if filter.arity > 0 then
            local editbox = Aux.gui.editbox(AuxSearchFrameFilter)
            editbox.complete = Aux.completion.completor(function() return ({filter.test()})[2] end)
            editbox:SetPoint('LEFT', btn, 'RIGHT', 10, 0)
            editbox:SetWidth(80)
            --            editbox:SetNumeric(true)
            --            editbox:SetMaxLetters(2)
            editbox:SetScript('OnChar', function()
                this:complete()
            end)
            local on_click = btn:GetScript('OnClick')
            editbox:SetScript('OnEnterPressed', function()
                on_click()
            end)
            tinsert(btn.inputs, editbox)
        end
    end

    private.results_listing = Aux.auction_listing.CreateAuctionResultsTable(AuxSearchFrameResults, Aux.auction_listing.search_config)
    private.results_listing:SetSort(1,2,3,4,5,6,7,8,9)
    private.results_listing:Reset()
    private.results_listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and private.results_listing:GetSelection().record == cell.row.data.record then
            if button == 'LeftButton' and private.buyout_button:IsEnabled() then
                private.buyout_button:Click()
            elseif button == 'RightButton' and private.bid_button:IsEnabled() then
                private.bid_button:Click()
            end
        end
    end)
    private.results_listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        private.find_auction(datum.record)
    end)

    local handlers = {
        OnClick = function(st, data, _, button)
            if not data then return end
            if button == 'LeftButton' and IsShiftKeyDown() then
                private.search_box:SetText(data.search.filter_string)
            elseif button == 'RightButton' and IsShiftKeyDown() then
                private.add_filter(data.search.filter_string)
            elseif button == 'LeftButton' and IsAltKeyDown() then
                private.popup_info.rename = data.search
                StaticPopup_Show('AUX_SEARCH_SAVED_RENAME')
            elseif button == 'RightButton' and IsAltKeyDown() then
                -- unused
            elseif button == 'LeftButton' and IsControlKeyDown() then
                if st == private.favorite_searches_listing and data.index > 1 then
                    local temp = aux_favorite_searches[data.index - 1]
                    aux_favorite_searches[data.index - 1] = data.search
                    aux_favorite_searches[data.index] = temp
                    private.update_search_listings()
                end
            elseif button == 'RightButton' and IsControlKeyDown() then
                if st == private.favorite_searches_listing and data.index < getn(aux_favorite_searches) then
                    local temp = aux_favorite_searches[data.index + 1]
                    aux_favorite_searches[data.index + 1] = data.search
                    aux_favorite_searches[data.index] = temp
                    private.update_search_listings()
                end
            elseif button == 'LeftButton' then
                private.search_box:SetText(data.search.filter_string)
                public.execute('search')
            elseif button == 'RightButton' then
                if st == private.recent_searches_listing then
                    tinsert(aux_favorite_searches, 1, data.search)
                elseif st == private.favorite_searches_listing then
                    tremove(aux_favorite_searches, data.index)
                end
                private.update_search_listings()
            end
        end,
        OnEnter = function(st, data, self)
            if not data then return end
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
            GameTooltip:Show()
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:ClearLines()
            GameTooltip:Hide()
        end
    }

    private.recent_searches_listing = Aux.listing.CreateScrollingTable(AuxSearchFrameSavedRecent)
    private.recent_searches_listing:DisableSelection(true)
    private.recent_searches_listing:SetColInfo({{name='Recent Searches', width=1}})
    private.recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
    private.recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
    private.recent_searches_listing:SetHandler('OnLeave', handlers.OnLeave)

    Aux.gui.vertical_line(AuxSearchFrameSaved, 379)

    private.favorite_searches_listing = Aux.listing.CreateScrollingTable(AuxSearchFrameSavedFavorite)
    private.favorite_searches_listing:DisableSelection(true)
    private.favorite_searches_listing:SetColInfo({{name='Favorite Searches', width=1}})
    private.favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
    private.favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
    private.favorite_searches_listing:SetHandler('OnLeave', handlers.OnLeave)
end