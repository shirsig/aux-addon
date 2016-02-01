local private, public = {}, {}
Aux.filter_search_frame = public

aux_favorite_searches = {}
aux_recent_searches = {}

local tooltip_patterns = {}
local selected_auction

local RESULTS, SAVED, FILTER = {}, {}, {}

private.elements = {
    [RESULTS] = {},
    [SAVED] = {},
    [FILTER] = {},
}

function private.update_search_listings()
    local favorite_search_rows = {}
    for i, favorite_search in ipairs(aux_favorite_searches) do
        local name = Aux.test.prettify_search(favorite_search)
        tinsert(favorite_search_rows, {
            cols = {{value=name}},
            search = favorite_search,
            index = i,
            name = name,
        })
    end
    private.favorite_searches_listing:SetData(favorite_search_rows)

    local recent_search_rows = {}
    for i, recent_search in ipairs(aux_recent_searches) do
        local name = Aux.test.prettify_search(recent_search)
        tinsert(recent_search_rows, {
            cols = {{value=name}},
            search = recent_search,
            index = i,
            name = name,
        })
    end
    private.recent_searches_listing:SetData(recent_search_rows)
end

function private.update_tab(tab)

    private.search_results_button:UnlockHighlight()
    private.saved_searches_button:UnlockHighlight()
    private.new_filter_button:UnlockHighlight()
    AuxFilterSearchFrameResults:Hide()
    AuxFilterSearchFrameSaved:Hide()
    Aux.hide_elements(RESULTS)
    Aux.hide_elements(private.elements[FILTER])

    if tab == RESULTS then
        Aux.show_elements(RESULTS)
        AuxFilterSearchFrameResults:Show()
        private.search_results_button:LockHighlight()
    elseif tab == SAVED then
        AuxFilterSearchFrameSaved:Show()
        private.saved_searches_button:LockHighlight()
    elseif tab == FILTER then
        Aux.show_elements(private.elements[FILTER])
        private.new_filter_button:LockHighlight()
    end
end

function private.add_filter()
    local old_filter_string = private.search_box:GetText()
    old_filter_string = Aux.util.trim(old_filter_string)

    if strlen(old_filter_string) > 0 and not strfind(old_filter_string, ';$') then
        old_filter_string = old_filter_string..';'
    end

    private.search_box:SetText(old_filter_string..Aux.scan_util.filter_to_string(private.get_form_filter()))
end

function private.clear_filter()

end

function private.get_form_filter()
    return {
        name = AuxFilterSearchFrameFilterNameInputBox:GetText(),
        min_level = tonumber(AuxFilterSearchFrameFilterMinLevel:GetText()),
        max_level = tonumber(AuxFilterSearchFrameFilterMaxLevel:GetText()),
        class = UIDropDownMenu_GetSelectedValue(private.class_dropdown),
        subclass = UIDropDownMenu_GetSelectedValue(private.subclass_dropdown),
        slot = UIDropDownMenu_GetSelectedValue(private.slot_dropdown),
        quality = UIDropDownMenu_GetSelectedValue(private.quality_dropdown),
        usable = AuxFilterSearchFrameFilterUsableCheckButton:GetChecked(),
        exact = AuxFilterSearchFrameFilterExactCheckButton:GetChecked(),
    }
end

function private.select_auction(entry)
    selected_auction = entry
    RESULTS.buyout_button:Disable()
    private.bid_button:Disable()
end

function private.clear_selection(entry)
    selected_auction = nil
    RESULTS.buyout_button:Disable()
    private.bid_button:Disable()
end

function public.on_close()
    private.clear_selection()
end

function public.on_open()
    private.update_search_listings()
end

function public.on_load()
    do
        local panel = Aux.gui.panel(AuxFilterSearchFrame, '$parentFilters')
        panel:SetAllPoints(AuxFrameContent)
        private.elements[FILTER].filters = panel
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 22)
        btn:SetPoint('TOPRIGHT', -5, -8)
        btn:SetWidth(60)
        btn:SetHeight(25)
        btn:SetText('Search')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
        private.search_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 22)
        btn:SetPoint('TOPRIGHT', -5, -8)
        btn:SetWidth(60)
        btn:SetHeight(25)
        btn:SetText('Stop')
        btn:SetScript('OnClick', Aux.filter_search_frame.stop_search)
        btn:Hide()
        private.stop_button = btn
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrame)
        editbox:EnableMouse(1)
        editbox.complete = Aux.test.complete
        editbox:SetPoint('TOPLEFT', 5, -8)
        editbox:SetPoint('RIGHT', private.search_button, 'LEFT', -4, 0)
        editbox:SetWidth(400)
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
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:HighlightText(0, 0)
            this:ClearFocus()
        end)
        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)
        editbox:SetScript('OnReceiveDrag', function()
            local item_info = Aux.cursor_item() and Aux.static.item_info(Aux.cursor_item().item_id)
            if item_info then
                this:SetText(item_info.name..'/exact')
            end
            ClearCursor()
        end)
        private.search_box = editbox
    end
    do
        Aux.gui.horizontal_line(AuxFilterSearchFrame, -40)
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('BOTTOMLEFT', AuxFrameContent, 'TOPLEFT', 10, 8)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('Search Results')
        btn:SetScript('OnClick', function() private.update_tab(RESULTS) end)
        private.search_results_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.search_results_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('Saved Searches')
        btn:SetScript('OnClick', function() private.update_tab(SAVED) end)
        private.saved_searches_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.saved_searches_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(243)
        btn:SetHeight(22)
        btn:SetText('New Filter')
        btn:SetScript('OnClick', function() private.update_tab(FILTER) end)
        private.new_filter_button = btn
    end
    do
        local btn1 = Aux.gui.button(private.elements[FILTER].filters, 16)
        btn1:SetPoint('BOTTOMLEFT', 8, 15)
        btn1:SetWidth(80)
        btn1:SetHeight(24)
        btn1:SetText('Add Filter')
        btn1:SetScript('OnClick', private.add_filter)

        local btn2 = Aux.gui.button(private.elements[FILTER].filters, 16)
        btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
        btn2:SetWidth(80)
        btn2:SetHeight(24)
        btn2:SetText('Search Filter')
        btn2:SetScript('OnClick', function()
            private.search_box:SetText('')
            private.add_filter()
            public.start_search()
        end)

        local btn3 = Aux.gui.button(private.elements[FILTER].filters, 16)
        btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
        btn3:SetWidth(80)
        btn3:SetHeight(24)
        btn3:SetText('Clear Filter')
        btn3:SetScript('OnClick', function()
            private.clear_filter()
        end)
    end
    do
        local status_bar = Aux.gui.status_bar(AuxFilterSearchFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFilterSearchFrameResults, 'BOTTOMLEFT', 0, -3)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        RESULTS.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrameResults, 16)
        btn:SetPoint('TOPLEFT', RESULTS.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentNameInputBox')
        editbox:SetPoint('TOPLEFT', 14, -20)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Name')
    end
    do
        local dropdown = Aux.gui.dropdown(private.elements[FILTER].filters)
        dropdown:SetPoint('TOPLEFT', 14, -53)
        dropdown:SetWidth(250)
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
        local dropdown = Aux.gui.dropdown(private.elements[FILTER].filters)
        dropdown:SetPoint('TOPLEFT', 14, -100)
        dropdown:SetWidth(250)
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
        local dropdown = Aux.gui.dropdown(private.elements[FILTER].filters)
        dropdown:SetPoint('TOPLEFT', 14, -150)
        dropdown:SetWidth(250)
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
        local dropdown = Aux.gui.dropdown(private.elements[FILTER].filters)
        dropdown:SetPoint('TOPLEFT', 14, -200)
        dropdown:SetWidth(250)
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
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentMinLevel')
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetPoint('TOPLEFT', 14, -140)
        editbox:SetWidth(30)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Level Range')
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentMaxLevel')
        editbox:SetNumeric(true)
        editbox:SetMaxLetters(2)
        editbox:SetPoint('TOPLEFT', 54, -140)
        editbox:SetWidth(30)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('RIGHT', editbox, 'LEFT', -4, 0)
        label:SetText('-')
    end
    do
        local label = Aux.gui.label(AuxFilterSearchFrameFilterUsableCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxFilterSearchFrameFilterUsableCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('Usable')
    end

    -- Tooltip 1
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox1')
        editbox:SetPoint('TOPLEFT', 300, -20)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Tooltip')
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox2')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox1 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox3')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox2 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox4')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox3 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end

    -- Tooltip 2
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox1')
        editbox:SetPoint('TOPLEFT', 300, -200)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Tooltip')
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox2')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox1 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox3')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox2 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox4')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox3 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end

    -- Tooltip 3
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox1')
        editbox:SetPoint('TOPLEFT', 600, -20)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Tooltip')
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox2')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox1 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox3')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox2 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox4')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox3 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end

    -- Tooltip 4
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox1')
        editbox:SetPoint('TOPLEFT', 300, -300)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Tooltip')
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox2')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox1 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox3')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox2 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].filters, '$parentTooltipInputBox4')
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFilterTooltipInputBox3 , 'BOTTOMLEFT', 0, -3)
        editbox:SetWidth(250)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end

    private.testlisting = CreateAuctionResultsTable(AuxFilterSearchFrameResults)
    private.testlisting:Show()
    private.testlisting:SetSort(9)
    private.testlisting:Clear()
    private.testlisting:SetHandler('OnSelectionChanged', private.on_selection_changed)

    local handlers = {
        OnClick = function(st, data, _, button)
            if not data then return end
            if button == 'LeftButton' then
                if IsShiftKeyDown() then
--                    private.popupInfo.export = data.search
--                        TSMAPI.Util:ShowStaticPopupDialog('TSM_SHOPPING_SAVED_EXPORT_POPUP')
                elseif IsControlKeyDown() then
--                    private.popupInfo.renameInfo = data.searchInfo
--                    TSMAPI.Util:ShowStaticPopupDialog('TSM_SHOPPING_SAVED_RENAME_POPUP')
                else
                    private.search_box:SetText(data.search)
                    public.start_search()
                end
            elseif button == 'RightButton' then
                if st == private.recent_searches_listing then
                    if IsShiftKeyDown() then
                        tremove(TSM.db.global.savedSearches, data.index)
--                        TSM:Printf('Removed '%s' from your recent searches.', data.searchInfo.name)
                        private.UpdateSTData()
                    else
                        tinsert(aux_favorite_searches, data.search)
--                        data.searchInfo.isFavorite = true
----                        TSM:Printf('Added '%s' to your favorite searches.', data.searchInfo.name)
--                        private.UpdateSTData()
                    end
                elseif st == private.favorite_searches_listing then
                    tremove(aux_favorite_searches, data.index)
--                    data.searchInfo.isFavorite = nil
--                    TSM:Printf('Removed '%s' from your favorite searches.', data.searchInfo.name)
                end
                private.update_search_listings()
            end
        end,
        OnEnter = function(st, data, self)
            if not data then return end
                        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
                        GameTooltip:AddLine(gsub(data.name, ';', '\n'), 255/255, 254/255, 250/255)
                        GameTooltip:Show()
--            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
--            GameTooltip:AddLine(data.search, 1, 1, 1, true)
--            GameTooltip:AddLine("")
--            local color = TSMAPI.Design:GetInlineColor("link")
--            if st == private.frame.saved.recentST then
--                GameTooltip:AddLine(color..'Left-Click to run this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Shift-Left-Click to export this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Ctrl-Left-Click to rename this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Right-Click to favorite this recent search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Shift-Right-Click to remove this recent search.', 1, 1, 1, true)
--            elseif st == private.frame.saved.favoriteST then
--                GameTooltip:AddLine(color..'Left-Click to run this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Shift-Left-Click to export this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Ctrl-Left-Click to rename this search.', 1, 1, 1, true)
--                GameTooltip:AddLine(color..'Right-Click to remove from favorite searches.', 1, 1, 1, true)
--            end
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:ClearLines()
            GameTooltip:Hide()
        end
    }

    private.recent_searches_listing = CreateScrollingTable(AuxFilterSearchFrameSavedRecent)
    private.recent_searches_listing:SetColInfo({{name='Recent Searches', width=1}})
    private.recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
    private.recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)

    Aux.gui.vertical_line(AuxFilterSearchFrameSaved, 379)

    private.favorite_searches_listing = CreateScrollingTable(AuxFilterSearchFrameSavedFavorite)
    private.favorite_searches_listing:SetColInfo({{name='Favorite Searches', width=1}})
    private.favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
    private.favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)


    private.update_tab(SAVED)
end

function public.stop_search()
	Aux.scan.abort()
end

function public.start_search()

    Aux.scan.abort(function()

--        local tooltip_patterns = {}
--        for i=1,4 do
--            local tooltip_pattern = getglobal('AuxFilterSearchFrameFilterTooltipInputBox'..i):GetText()
--            if tooltip_pattern ~= '' then
--                tinsert(tooltip_patterns, tooltip_pattern)
--            end
--        end

        local queries

        local filters = Aux.scan_util.parse_filter_string(private.search_box:GetText())
        if filters then
            queries = Aux.util.map(filters, function(filter)
                return {
                    type = 'list',
                    start_page = 0,
                    blizzard_query = Aux.scan_util.blizzard_query(filter),
                    validator = Aux.scan_util.validator(filter),
                }
            end)
        else
            return
        end

        tinsert(aux_recent_searches, 1, private.search_box:GetText())
        while getn(aux_recent_searches) > 50 do
            tremove(aux_recent_searches)
        end
        private.update_search_listings()

        private.clear_selection()
        private.search_button:Hide()
        private.stop_button:Show()

        private.update_tab(RESULTS)

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

        local scanned_records = {}
        private.testlisting:SetDatabase(scanned_records)

        Aux.scan.start{
            queries = queries,
            on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages) -- TODO
                private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
            end,
            on_page_complete = function()
                private.testlisting:SetDatabase()
            end,
            on_start_query = function(query_index)
                private.status_bar:update_status(0, 100 * (query_index - 1) / getn(queries)) -- TODO
                private.status_bar:set_text(format('Processing query %d / %d', query_index, getn(queries)))
            end,
            on_read_auction = function(auction_info)
--                tinsert(scanned_records, private.create_auction_record(auction_info))
                tinsert(scanned_records, auction_info)
            end,
            on_complete = function()
                private.testlisting:SetDatabase()
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')

                private.stop_button:Hide()
                private.search_button:Show()
            end,
            on_abort = function()
                private.testlisting:SetDatabase()
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
                private.stop_button:Hide()
                private.search_button:Show()
            end,
        }
    end)
end

function private.process_request(entry, express_mode, buyout_mode)

    if entry.gone or (buyout_mode and not entry.buyout_price) or (express_mode and not buyout_mode and entry.high_bidder) or entry.owner == UnitName('player') then
        return
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        local auction_record = Aux.info.auction(index)
        return auction_record.signature == entry.signature and auction_record.bid_price == entry.bid_price and auction_record.duration == entry.duration and auction_record.owner ~= UnitName('player')
    end

    local function remove_entry()
        entry.gone = true
        private.clear_selection()
    end

    if express_mode then
        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)
            if not entry.gone then
                Aux.place_bid('list', index, buyout_mode and entry.buyout_price or entry.bid_price, remove_entry)
            end
        end)
    else
        private.select_auction(entry)

        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)

            if not entry.high_bidder then
                private.bid_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('list', index, entry.bid_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.bid_button:Enable()
            end

            if entry.buyout_price then
                RESULTS.buyout_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('list', index, entry.buyout_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                RESULTS.buyout_button:Enable()
            end
        end)
    end
end

function private.on_selection_changed(rt, datum)

    if not datum then
        return
    end

    local entry = datum.record

    if IsControlKeyDown() then
        DressUpItemLink(entry.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(entry.hyperlink)
        end
    else
        local express_mode = IsAltKeyDown()
        local buyout_mode = express_mode and arg1 == 'LeftButton'
        private.process_request(entry, express_mode, buyout_mode)
    end
end

--function private.create_auction_record(auction_info)
--
--	local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
--	local unit_buyout_price = buyout_price and auction_info.buyout_price / auction_info.aux_quantity
--    local status
--    if auction_info.current_bid == 0 then
--        status = 'No Bid'
--    elseif auction_info.high_bidder then
--        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
--    else
--        status = 'Other Bidder'
--    end
--
--    return {
--        query = auction_info.query,
--        page = auction_info.page,
--
--        item_id = auction_info.item_id,
--        suffix_id = auction_info.suffix_id,
--        unique_id = auction_info.unique_id,
--        enchant_id = auction_info.enchant_id,
--
--        item_key = auction_info.item_key,
--        signature = auction_info.signature,
--
--        name = auction_info.name,
--        level = auction_info.level,
--        tooltip = auction_info.tooltip,
--        aux_quantity = auction_info.aux_quantity,
--        buyout_price = buyout_price,
--        unit_buyout_price = unit_buyout_price,
--        quality = auction_info.quality,
--        hyperlink = auction_info.hyperlink,
--        itemstring = auction_info.itemstring,
--        bid_price = auction_info.bid_price,
--        unit_bid_price = auction_info.bid_price / auction_info.aux_quantity,
--        owner = auction_info.owner,
--        duration = auction_info.duration,
--        usable = auction_info.usable,
--        high_bidder = auction_info.high_bidder,
--        status = status,
--
--        EnhTooltip_info = auction_info.EnhTooltip_info,
--    }
--end

function private.initialize_class_dropdown()
    local function on_click()
        if this.value ~= UIDropDownMenu_GetSelectedValue(private.class_dropdown) then
            UIDropDownMenu_ClearAll(private.subclass_dropdown)
            UIDropDownMenu_ClearAll(private.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(private.class_dropdown, this.value)
    end

    UIDropDownMenu_AddButton{
        text = ALL,
        func = on_click,
    }

    for i, class in pairs({ GetAuctionItemClasses() }) do
        UIDropDownMenu_AddButton{
            text = class,
            value = i,
            func = on_click,
        }
    end
end

function private.initialize_subclass_dropdown()

    local function on_click()
        if this.value ~= UIDropDownMenu_GetSelectedValue(private.subclass_dropdown) then
            UIDropDownMenu_ClearAll(private.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(private.subclass_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(private.class_dropdown)

    if class_index and GetAuctionItemSubClasses(class_index) then
        UIDropDownMenu_AddButton{
            text = ALL,
            func = on_click,
        }

        for i, subclass in pairs({ GetAuctionItemSubClasses(class_index) }) do
            UIDropDownMenu_AddButton{
                text = subclass,
                value = i,
                func = on_click,
            }
        end
    end
end

function private.initialize_slot_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.slot_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(private.class_dropdown)
    local subclass_index = UIDropDownMenu_GetSelectedValue(private.subclass_dropdown)

    if class_index and subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
        UIDropDownMenu_AddButton{
            text = ALL,
            func = on_click,
        }

        for i, slot in pairs({ GetAuctionInvTypes(class_index, subclass_index) }) do
            local slot_name = getglobal(slot)
            UIDropDownMenu_AddButton{
                text = slot_name,
                value = slot,
                func = on_click,
            }
        end
    end
end

function private.initialize_quality_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.quality_dropdown, this.value)
    end

	UIDropDownMenu_AddButton{
		text = ALL,
		func = on_click,
	}
	for i=0,4 do
		UIDropDownMenu_AddButton{
			text = getglobal('ITEM_QUALITY'..i..'_DESC'),
			value = i,
			func = on_click,
		}
	end
end

