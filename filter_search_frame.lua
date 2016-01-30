local private, public = {}, {}
Aux.filter_search_frame = public

aux_favorite_searches = {}
aux_recent_searches = {}

local auctions
local tooltip_patterns = {}
local refresh
local selected_auction

local RESULTS, SAVED, FILTER = {}, {}, {}

private.elements = {
    [RESULTS] = {},
    [SAVED] = {},
    [FILTER] = {},
}

function private.update_search_listings()
    Aux.sheet.populate(private.listings.favorite_searches, aux_favorite_searches)
    Aux.sheet.populate(private.listings.recent_searches, aux_recent_searches)
end

function private.update_tab(tab)

    private.search_results_button:UnlockHighlight()
    private.saved_searches_button:UnlockHighlight()
    private.new_filter_button:UnlockHighlight()
    AuxFilterSearchFrameResults:Hide()
    AuxFilterSearchFrameSaved:Hide()
    Aux.hide_elements(private.elements[FILTER])

    if tab == RESULTS then
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
    local category = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersCategoryDropDown)

    return {
        name = AuxFilterSearchFrameFiltersNameInputBox:GetText(),
        min_level = tonumber(AuxFilterSearchFrameFiltersMinLevel:GetText()),
        max_level = tonumber(AuxFilterSearchFrameFiltersMaxLevel:GetText()),
        slot = category and category.slot,
        class = category and category.class,
        subclass = category and category.subclass,
        quality = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersQualityDropDown),
        usable_only = AuxFilterSearchFrameFiltersUsableCheckButton:GetChecked(),
        exact_only = AuxFilterSearchFrameFiltersExactCheckButton:GetChecked(),
    }
end

function private.select_auction(entry)
    selected_auction = entry
    refresh = true
    private.buyout_button:Disable()
    private.bid_button:Disable()
end

function private.clear_selection(entry)
    selected_auction = nil
    refresh = true
    private.buyout_button:Disable()
    private.bid_button:Disable()
end

function public.on_close()
    private.clear_selection()
end

function public.on_open()
    private.update_search_listings()
    private.update_tab(SAVED)
end

function public.on_load()
    private.recent_searches_config = {
        plain = true,
        frame = AuxFilterSearchFrameSavedRecentListing,
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            PlaySound('igMainMenuOptionCheckBoxOn')
            if arg1 == 'LeftButton' then
                private.search_box:SetText(sheet.data[data_index])
                if not IsShiftKeyDown() then
                    public.start_search()
                end
            elseif arg1 == 'RightButton' then
                tinsert(aux_favorite_searches, sheet.data[data_index])
                private.update_search_listings()
            end
        end,
        columns = {
            {
                width = 900,
                comparator = function(filter_string1, filter_string2) return Aux.util.compare(filter_string1, filter_string2, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
                cell_setter = function(cell, filter_string)
                    cell.text:SetText(filter_string)
                end,
            },
        },
        sort_order = {},
    }
    private.favorite_searches_config = {
        plain = true,
        frame = AuxFilterSearchFrameSavedFavoriteListing,
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            PlaySound('igMainMenuOptionCheckBoxOn')
            if arg1 == 'LeftButton' then
                private.search_box:SetText(sheet.data[data_index])
                if not IsShiftKeyDown() then
                    public.start_search()
                end
            elseif arg1 == 'RightButton' then
                tremove(aux_favorite_searches, Aux.util.index_of(sheet.data[data_index], aux_favorite_searches))
                private.update_search_listings()
            end
        end,
        columns = {
            {
                width = 900,
                comparator = function(filter_string1, filter_string2) return Aux.util.compare(filter_string1, filter_string2, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
                cell_setter = function(cell, filter_string)
                    cell.text:SetText(filter_string)
                end,
            },
        },
        sort_order = {{ column = 1, order = 'ascending' }},
    }
    private.results_config = {
        frame = AuxFilterSearchFrameResultsBuyListing,
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index], true)
        end,
        on_row_enter = function(sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function(sheet, row_index)
            AuxTooltip:Hide()
            ResetCursor()
        end,
        on_row_update = function(sheet, row_index)
            if IsControlKeyDown() then
                ShowInspectCursor()
            elseif IsAltKeyDown() then
                SetCursor('BUY_CURSOR')
            else
                ResetCursor()
            end
        end,
        selected = function(datum)
            return Aux.util.any(datum, function(entry) return entry == selected_auction end)
        end,
        row_setter = function(row, group)
            row:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
            row.itemstring = Aux.info.itemstring(group[1].item_id, group[1].suffix_id, nil, group[1].enchant_id)
            row.EnhTooltip_info = group[1].EnhTooltip_info
        end,
        columns = {
            {
                title = 'Auction Item',
                width = 280,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].name, group2[1].name, Aux.util.GT) end,
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
                cell_setter = function(cell, group)
                    cell.icon.icon_texture:SetTexture(Aux.info.item(group[1].item_id).texture)
                    if not group[1].usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..group[1].tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[group[1].quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                end,
            },
            {
                title = 'Qty',
                width = 25,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].aux_quantity, group2[1].aux_quantity, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].aux_quantity)
                end,
            },
            Aux.listing_util.money_column('Bid', function(group) return group[1].bid_price end),
            Aux.listing_util.money_column('Buy', function(group) return group[1].buyout_price end),
            Aux.listing_util.money_column('Bid/ea', function(group) return group[1].unit_bid_price end),
            Aux.listing_util.money_column('Buy/ea', function(group) return group[1].unit_buyout_price end),
            {
                title = 'Avail',
                width = 40,
                comparator = function(group1, group2) return Aux.util.compare(getn(Aux.util.filter(group1, function(auction) return not auction.gone end)), getn(Aux.util.filter(group2, function(auction) return not auction.gone end)), Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(getn(Aux.util.filter(group, function(auction) return not auction.gone end)))
                end,
            },
            {
                title = 'Lvl',
                width = 25,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].level, group2[1].level, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    local level = max(1, group[1].level)
                    local text
                    if level > UnitLevel('player') then
                        text = RED_FONT_COLOR_CODE..level..FONT_COLOR_CODE_CLOSE
                    else
                        text = level
                    end
                    cell.text:SetText(text)
                end,
            },
            {
                title = 'Status',
                width = 70,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].status, group2[1].status, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].status)
                end,
            },
            Aux.listing_util.duration_column(function(group) return group[1].duration end),
            Aux.listing_util.owner_column(function(group) return group[1].owner end),
            Aux.listing_util.percentage_market_column(function(group) return group[1].item_key end, function(group) return group[1].unit_buyout_price end),
        },
        sort_order = {{ column = 1, order = 'ascending' }, { column = 4, order = 'ascending' }},
    }

    private.listings = {
        favorite_searches = Aux.sheet.create(private.favorite_searches_config),
        recent_searches = Aux.sheet.create(private.recent_searches_config),
        results = Aux.sheet.create(private.results_config),
    }
    do
        local panel = Aux.gui.panel(AuxFilterSearchFrame, '$parentFilters')
        panel:SetWidth(600)
        panel:SetHeight(290)
        panel:SetPoint('TOPLEFT', 5, -70)
        private.elements[FILTER].filters = panel
    end
    do
        local panel = Aux.gui.panel(AuxFilterSearchFrame)
        panel:SetWidth(300)
        panel:SetHeight(290)
        panel:SetPoint('TOPLEFT', private.elements[FILTER].filters, 'TOPRIGHT', 5, 0)
        private.elements[FILTER].item_filter = panel
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 22)
        btn:SetPoint('TOPRIGHT', -5, -3)
        btn:SetWidth(60)
        btn:SetHeight(25)
        btn:SetText('Search')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
        private.search_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 22)
        btn:SetPoint('TOPRIGHT', -5, -3)
        btn:SetWidth(60)
        btn:SetHeight(25)
        btn:SetText('Stop')
        btn:SetScript('OnClick', Aux.filter_search_frame.stop_search)
        btn:Hide()
        private.stop_button = btn
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrame)
        editbox:SetPoint('TOPLEFT', 5, -3)
        editbox:SetPoint('TOPRIGHT', private.search_button, 'TOPLEFT', -4, -5)
        editbox:SetWidth(400)
        editbox:SetHeight(25)
--        editbox:SetScript('OnTabPressed', function()
--            if IsShiftKeyDown() then
--                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
--            else
--                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
--            end
--        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            public.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        private.search_box = editbox
    end
    do
        Aux.gui.horizontal_line(AuxFilterSearchFrame, -35)
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', 10, -40)
        btn:SetWidth(330)
        btn:SetHeight(24)
        btn:SetText('Search Results')
        btn:SetScript('OnClick', function() private.update_tab(RESULTS) end)
        private.search_results_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.search_results_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(330)
        btn:SetHeight(24)
        btn:SetText('Saved Searches')
        btn:SetScript('OnClick', function() private.update_tab(SAVED) end)
        private.saved_searches_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.saved_searches_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(330)
        btn:SetHeight(24)
        btn:SetText('New Filter')
        btn:SetScript('OnClick', function() private.update_tab(FILTER) end)
        private.new_filter_button = btn
    end
    do
        local editbox = Aux.gui.editbox(private.elements[FILTER].item_filter)
        local function add_item_filter(item_id)
            local old_filter_string = private.search_box:GetText()
            old_filter_string = Aux.util.trim(old_filter_string)

            if strlen(old_filter_string) > 0 and not strfind(old_filter_string, ';$') then
                old_filter_string = old_filter_string..';'
            end

            local item_info = Aux.static.item_info(item_id)
            private.search_box:SetText(old_filter_string..item_info.name..'/exact')
            editbox:SetText('')
        end
        editbox.selector = Aux.completion.selector(editbox, function()
            add_item_filter(editbox.selector.selected_value())
        end)
        editbox:SetPoint('TOPLEFT', 5, -28)
        editbox:SetWidth(250)
        editbox:SetScript('OnTextChanged', function()
            this.selector.suggest()
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                this.selector.previous()
            else
                this.selector.next()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this.selector.close()
            if this.selector.selected_value() then
                add_item_filter(this.selector.selected_value())
--                this:ClearFocus()
            end
        end)
        editbox:SetScript('OnEscapePressed', function()
            this.selector.clear()
            this:ClearFocus()
        end)
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
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxFilterSearchFrame, 'BOTTOMLEFT', 6, 6)
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
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 16)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
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
        local label = Aux.gui.label(AuxFilterSearchFrameFiltersCategoryDropDown, 13)
        label:SetPoint('BOTTOMLEFT', AuxFilterSearchFrameFiltersCategoryDropDown, 'TOPLEFT', -2, -4)
        label:SetText('Category')
    end
    do
        local label = Aux.gui.label(AuxFilterSearchFrameFiltersQualityDropDown, 13)
        label:SetPoint('BOTTOMLEFT', AuxFilterSearchFrameFiltersQualityDropDown, 'TOPLEFT', -2, -4)
        label:SetText('Rarity')
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
        local label = Aux.gui.label(AuxFilterSearchFrameFiltersUsableCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxFilterSearchFrameFiltersUsableCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('Usable')
    end
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
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFiltersTooltipInputBox1 , 'BOTTOMLEFT', 0, -3)
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
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFiltersTooltipInputBox2 , 'BOTTOMLEFT', 0, -3)
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
        editbox:SetPoint('TOPLEFT', AuxFilterSearchFrameFiltersTooltipInputBox3 , 'BOTTOMLEFT', 0, -3)
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

    -- TODO replace with real gui dropdown
--    CreateFrame('Frame', '$parentCategoryDropDown', AuxFilterSearchFrameFilters, 'UIDropDownMenuTemplate')
--    local dropdown = CreateFrame('Frame', '$parentQualityDropDown', AuxFilterSearchFrameFilters, 'UIDropDownMenuTemplate')
    for _, dropdown in ipairs({AuxFilterSearchFrameFiltersCategoryDropDown, AuxFilterSearchFrameFiltersQualityDropDown}) do
        dropdown:SetWidth(250)
        dropdown:SetHeight(10)
        dropdown:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=Aux.gui.config.edge_size, insets={top=5,bottom=5}})
        dropdown:SetBackdropColor(unpack(Aux.gui.config.content_color))
        dropdown:SetBackdropBorderColor(unpack(Aux.gui.config.content_border_color))
        local left = getglobal(dropdown:GetName()..'Left'):Hide()
        local middle = getglobal(dropdown:GetName()..'Middle'):Hide()
        local right = getglobal(dropdown:GetName()..'Right'):Hide()

        local button = getglobal(dropdown:GetName()..'Button')
--        button:RegisterForClicks('AnyUp')
        button:ClearAllPoints()
        button:SetPoint('RIGHT', dropdown, 0, 0)

        local text = getglobal(dropdown:GetName()..'Text')
        text:ClearAllPoints()
        text:SetPoint('RIGHT', button, 'LEFT', -2, 0)
        text:SetPoint('LEFT', dropdown, 'LEFT', 8, 0)
        text:SetFont(Aux.gui.config.content_font, 13)
        text:SetShadowColor(0, 0, 0, 0)
    end
end

function public.stop_search()
	Aux.scan.abort()
end

function private.update_listing()

    if not AuxFilterSearchFrame:IsVisible() then
        return
    end

	AuxFilterSearchFrameResultsBuyListing:Hide()
    AuxFilterSearchFrameResultsBidListing:Hide()
    AuxFilterSearchFrameResultsFullListing:Hide()

    AuxFilterSearchFrameResultsBuyListing:Show()
    local buyout_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
    Aux.sheet.populate(private.listings.results, auctions and Aux.util.group_by(buyout_auctions, function(a1, a2)
        return a1.item_id == a2.item_id
                and a1.suffix_id == a2.suffix_id
                and a1.enchant_id == a2.enchant_id
                and a1.aux_quantity == a2.aux_quantity
                and a1.buyout_price == a2.buyout_price
                and a1.bid_price == a2.bid_price
                and a1.owner == a2.owner
    end) or {})
    AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsBuyListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxFilterSearchFrameResults:GetWidth() + 15)
end

function public.start_search()

    tinsert(aux_recent_searches, 1, private.search_box:GetText())
    while getn(aux_recent_searches) > 50 do
        tremove(aux_recent_searches)
    end
    private.update_search_listings()

    Aux.scan.abort(function()

        private.update_tab(RESULTS)

        private.clear_selection()

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

        private.search_button:Hide()
        private.stop_button:Show()

        auctions = nil

        refresh = true

        local tooltip_patterns = {}
        for i=1,4 do
            local tooltip_pattern = getglobal('AuxFilterSearchFrameFiltersTooltipInputBox'..i):GetText()
            if tooltip_pattern ~= '' then
                tinsert(tooltip_patterns, tooltip_pattern)
            end
        end

        local group = Aux.groups.parse_group(Aux.groups.test_group)

        local queries

--            queries = { private.create_filter_query() }
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


        Aux.scan.start{
            queries = queries,
            on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages) -- TODO
                private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
            end,
            on_page_complete = function()
                refresh = true
            end,
            on_start_query = function(query_index)
                private.status_bar:update_status(0, 100 * (query_index - 1) / getn(queries)) -- TODO
                private.status_bar:set_text(format('Processing query %d / %d', query_index, getn(queries)))
            end,
            on_read_auction = function(auction_info)
                auctions = auctions or {}
--                if Aux.info.tooltip_match(tooltip_patterns, auction_info.tooltip) then
                tinsert(auctions, private.create_auction_record(auction_info))
--                end
            end,
            on_complete = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')

                private.stop_button:Hide()
                private.search_button:Show()
                refresh = true
            end,
            on_abort = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
                private.stop_button:Hide()
                private.search_button:Show()
                refresh = true
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
        local auction_record = private.create_auction_record(Aux.info.auction(index))
        return auction_record.signature == entry.signature and auction_record.bid_price == entry.bid_price and auction_record.duration == entry.duration and auction_record.owner ~= UnitName('player')
    end

    local function remove_entry()
        entry.gone = true
        refresh = true
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
                private.buyout_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('list', index, entry.buyout_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.buyout_button:Enable()
            end
        end)
    end
end

function private.on_row_click(datum, grouped)

    local entry
    if grouped then
        entry = Aux.util.filter(datum, function(auction) return not auction.gone end)[1] or datum[1]
    else
        entry = datum
    end

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

function private.create_auction_record(auction_info)

	local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
	local unit_buyout_price = buyout_price and Aux.round(auction_info.buyout_price / auction_info.aux_quantity)
    local status
    if auction_info.current_bid == 0 then
        status = 'No Bid'
    elseif auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
    else
        status = 'Other Bidder'
    end

    return {
        query = auction_info.query,
        page = auction_info.page,

        item_id = auction_info.item_id,
        suffix_id = auction_info.suffix_id,
        unique_id = auction_info.unique_id,
        enchant_id = auction_info.enchant_id,

        item_key = auction_info.item_key,
        signature = auction_info.signature,

        name = auction_info.name,
        level = auction_info.level,
        tooltip = auction_info.tooltip,
        aux_quantity = auction_info.aux_quantity,
        buyout_price = buyout_price,
        unit_buyout_price = unit_buyout_price,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        bid_price = auction_info.bid_price,
        unit_bid_price = Aux.round(auction_info.bid_price / auction_info.aux_quantity),
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function public.on_update()
	if refresh then
		refresh = false
		private.update_listing()
	end
end

function AuxFilterSearchFrameFiltersCategoryDropDown_Initialize(arg1)
	local level = arg1 or 1

	if level == 1 then
		local value = {}
		UIDropDownMenu_AddButton({
			text = ALL,
			value = value,
			func = AuxFilterSearchFrameFiltersCategoryDropDown_OnClick,
		}, 1)

		for i, class in pairs({ GetAuctionItemClasses() }) do
			local value = { class = i }
			UIDropDownMenu_AddButton({
				hasArrow = GetAuctionItemSubClasses(value.class),
				text = class,
				value = value,
				func = AuxFilterSearchFrameFiltersCategoryDropDown_OnClick,
			}, 1)
		end
	end

	if level == 2 then
		local menu_value = UIDROPDOWNMENU_MENU_VALUE
		for i, subclass in pairs({ GetAuctionItemSubClasses(menu_value.class) }) do
			local value = { class = menu_value.class, subclass = i }
			UIDropDownMenu_AddButton({
				hasArrow = GetAuctionInvTypes(value.class, value.subclass),
				text = subclass,
				value = value,
				func = AuxFilterSearchFrameFiltersCategoryDropDown_OnClick,
			}, 2)
		end
	end

	if level == 3 then
		local menu_value = UIDROPDOWNMENU_MENU_VALUE
		for i, slot in pairs({ GetAuctionInvTypes(menu_value.class, menu_value.subclass) }) do
			local slot_name = getglobal(slot)
			local value = { class = menu_value.class, subclass = menu_value.subclass, slot = i }
			UIDropDownMenu_AddButton({
				text = slot_name,
				value = value,
				func = AuxFilterSearchFrameFiltersCategoryDropDown_OnClick,
			}, 3)
		end
	end
end

function AuxFilterSearchFrameFiltersCategoryDropDown_OnClick()
	local qualified_name = ({ GetAuctionItemClasses() })[this.value.class] or 'All'
	if this.value.subclass then
		local subclass_name = ({ GetAuctionItemSubClasses(this.value.class) })[this.value.subclass]
		qualified_name = qualified_name .. ' - ' .. subclass_name
		if this.value.slot then
			local slot_name = getglobal(({ GetAuctionInvTypes(this.value.class, this.value.subclass) })[this.value.slot])
			qualified_name = qualified_name .. ' - ' .. slot_name
		end
	end

	UIDropDownMenu_SetSelectedValue(AuxFilterSearchFrameFiltersCategoryDropDown, this.value)
	UIDropDownMenu_SetText(qualified_name, AuxFilterSearchFrameFiltersCategoryDropDown)
	CloseDropDownMenus(1)
end

function AuxFilterSearchFrameFiltersQualityDropDown_Initialize()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(AuxFilterSearchFrameFiltersQualityDropDown, this.value)
    end

	UIDropDownMenu_AddButton{
		text = 'All',
		value = -1,
		func = on_click,
	}
	for i=0,getn(ITEM_QUALITY_COLORS)-2 do
		UIDropDownMenu_AddButton{
			text = getglobal('ITEM_QUALITY'..i..'_DESC'),
			value = i,
			func = on_click,
		}
	end
end

