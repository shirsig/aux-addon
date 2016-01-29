local private, public = {}, {}
Aux.filter_search_frame = public

local auctions
local tooltip_patterns = {}
local refresh
local selected_auction

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
    private.tab_group:set_tab(aux_view)
end

function public.on_load()
    private.views = {
        [Aux.view.BUYOUT] = {
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
                Aux.listing_util.money_column('Buy', function(group) return group[1].buyout_price end),
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
                Aux.listing_util.percentage_market_column(function(group) return group[1].item_key end, function(group) return group[1].unit_buyout_price end),
            },
            sort_order = {{column = 1, order = 'ascending' }, {column = 4, order = 'ascending'}},
        },
        [Aux.view.BID] = {
            frame = AuxFilterSearchFrameResultsBidListing,
            on_row_click = function(sheet, row_index)
                local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
                private.on_row_click(sheet.data[data_index])
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
                return datum == selected_auction
            end,
            row_setter = function(row, datum)
                row:SetAlpha(datum.gone and 0.3 or 1)
                row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, datum.unique_id, datum.enchant_id)
                row.EnhTooltip_info = datum.EnhTooltip_info
            end,
            columns = {
                {
                    title = 'Auction Item',
                    width = 280,
                    comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
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
                        cell.icon.icon_texture:SetTexture(Aux.info.item(datum.item_id).texture)
                        if not datum.usable then
                            cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                        else
                            cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                        end
                        cell.text:SetText('['..datum.tooltip[1][1].text..']')
                        local color = ITEM_QUALITY_COLORS[datum.quality]
                        cell.text:SetTextColor(color.r, color.g, color.b)
                    end,
                },
                {
                    title = 'Qty',
                    width = 25,
                    comparator = function(row1, row2) return Aux.util.compare(row1.aux_quantity, row2.aux_quantity, Aux.util.LT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                    cell_setter = function(cell, datum)
                        cell.text:SetText(datum.aux_quantity)
                    end,
                },
                Aux.listing_util.money_column('Bid', function(entry) return entry.bid_price end),
                Aux.listing_util.money_column('Bid/ea', function(entry) return entry.unit_bid_price end),
                {
                    title = 'Status',
                    width = 70,
                    comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                    cell_setter = function(cell, auction)
                        cell.text:SetText(auction.status)
                    end,
                },
                {
                    title = 'Left',
                    width = 30,
                    comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                    cell_setter = function(cell, datum)
                        local text
                        if datum.duration == 1 then
                            text = '30m'
                        elseif datum.duration == 2 then
                            text = '2h'
                        elseif datum.duration == 3 then
                            text = '8h'
                        elseif datum.duration == 4 then
                            text = '24h'
                        end
                        cell.text:SetText(text)
                    end,
                },
                {
                    title = 'Page',
                    width = 40,
                    comparator = function(row1, row2) return Aux.util.compare(row1.page, row2.page, Aux.util.LT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                    cell_setter = function(cell, datum)
                        cell.text:SetText(datum.page)
                    end,
                },
            },
            sort_order = {{column = 1, order = 'ascending' }, {column = 4, order = 'ascending' }, {column = 6, order = 'ascending'}},
        },
        [Aux.view.FULL] = {
            frame = AuxFilterSearchFrameResultsFullListing,
            on_row_click = function(sheet, row_index)
                local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
                private.on_row_click(sheet.data[data_index])
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
                return datum == selected_auction
            end,
            row_setter = function(row, datum)
                row:SetAlpha(datum.gone and 0.3 or 1)
                row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, datum.unique_id, datum.enchant_id)
                row.EnhTooltip_info = datum.EnhTooltip_info
            end,
            columns = {
                {
                    title = 'Auction Item',
                    width = 280,
                    comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
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
                        text:SetPoint('LEFT', icon, "RIGHT", 1, 0)
                        text:SetPoint('TOPRIGHT', cell)
                        text:SetPoint('BOTTOMRIGHT', cell)
                        text:SetJustifyV('TOP')
                        text:SetJustifyH('LEFT')
                        text:SetTextColor(0.8, 0.8, 0.8)
                        cell.text = text
                        cell.icon = icon
                    end,
                    cell_setter = function(cell, datum)
                        cell.icon.icon_texture:SetTexture(Aux.info.item(datum.item_id).texture)
                        if not datum.usable then
                            cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                        else
                            cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                        end
                        cell.text:SetText('['..datum.tooltip[1][1].text..']')
                        local color = ITEM_QUALITY_COLORS[datum.quality]
                        cell.text:SetTextColor(color.r, color.g, color.b)
                    end,
                },
                {
                    title = 'Lvl',
                    width = 25,
                    comparator = function(row1, row2) return Aux.util.compare(row1.level, row2.level, Aux.util.GT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                    cell_setter = function(cell, datum)
                        local level = max(1, datum.level)
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
                    title = 'Qty',
                    width = 25,
                    comparator = function(row1, row2) return Aux.util.compare(row1.aux_quantity, row2.aux_quantity, Aux.util.LT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                    cell_setter = function(cell, datum)
                        cell.text:SetText(datum.aux_quantity)
                    end,
                },
                Aux.listing_util.money_column('Bid', function(entry) return entry.bid_price end),
                Aux.listing_util.money_column('Buy', function(entry) return entry.buyout_price end),
                Aux.listing_util.money_column('Bid/ea', function(entry) return entry.unit_bid_price end),
                Aux.listing_util.money_column('Buy/ea', function(entry) return entry.unit_buyout_price end),
                {
                    title = 'Status',
                    width = 70,
                    comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                    cell_setter = function(cell, auction)
                        cell.text:SetText(auction.status)
                    end,
                },
                {
                    title = 'Left',
                    width = 30,
                    comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
                    cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                    cell_setter = function(cell, datum)
                        local text
                        if datum.duration == 1 then
                            text = '30m'
                        elseif datum.duration == 2 then
                            text = '2h'
                        elseif datum.duration == 3 then
                            text = '8h'
                        elseif datum.duration == 4 then
                            text = '24h'
                        end
                        cell.text:SetText(text)
                    end,
                },
                Aux.listing_util.owner_column(function(datum) return datum.owner end),
                Aux.listing_util.percentage_market_column(function(entry) return entry.item_key end, function(entry) return entry.unit_buyout_price end),
            },
            sort_order = {{column = 1, order = 'ascending' }, {column = 7, order = 'ascending' }},
        },
    }

    private.listings = {
        [Aux.view.BUYOUT] = Aux.sheet.create(private.views[Aux.view.BUYOUT]),
        [Aux.view.BID] = Aux.sheet.create(private.views[Aux.view.BID]),
        [Aux.view.FULL] = Aux.sheet.create(private.views[Aux.view.FULL]),
    }
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
        local editbox = Aux.gui.editbox(AuxFilterSearchFrame)
        editbox:SetPoint('TOPLEFT', 5, -3)
        editbox:SetPoint('TOPRIGHT', private.search_button, 'TOPLEFT', -4, 0)
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
            Aux.filter_search_frame.start_search()
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
        btn:SetWidth(220)
        btn:SetHeight(24)
        btn:SetText('Search Results')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
        private.search_results_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.search_results_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(220)
        btn:SetHeight(24)
        btn:SetText('Saved Searches')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
        private.saved_searches_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrame, 18)
        btn:SetPoint('TOPLEFT', private.saved_searches_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(220)
        btn:SetHeight(24)
        btn:SetText('New Filter')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
        private.new_filter_button = btn
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrameFilters, 16, '$parentSearchButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Search')
        btn:SetScript('OnClick', Aux.filter_search_frame.start_search)
    end
    do
        local btn = Aux.gui.button(AuxFilterSearchFrameFilters, 16, '$parentStopButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Stop')
        btn:SetScript('OnClick', Aux.filter_search_frame.stop_search)
        btn:Hide()
    end
    do
        local tab_group = Aux.gui.tab_group(AuxFilterSearchFrameResults, 'TOP')
        tab_group:create_tab('Buy')
        tab_group:create_tab('Bid')
        tab_group:create_tab('Full')
        tab_group.on_select = Aux.filter_search_frame.set_view
        private.tab_group = tab_group
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
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentNameInputBox')
        editbox:SetPoint('TOPLEFT', 14, -20)
        editbox:SetWidth(150)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'MinLevel'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
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
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentMinLevel')
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
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Level Range')
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentMaxLevel')
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
            Aux.filter_search_frame.start_search()
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
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentTooltipInputBox1')
        editbox:SetPoint('TOPLEFT', 14, -177)
        editbox:SetWidth(150)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'MaxLevel'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Tooltip')
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentTooltipInputBox2')
        editbox:SetPoint('TOPLEFT', 14, -198)
        editbox:SetWidth(150)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox1'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentTooltipInputBox3')
        editbox:SetPoint('TOPLEFT', 14, -219)
        editbox:SetWidth(150)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox2'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'TooltipInputBox4'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentTooltipInputBox4')
        editbox:SetPoint('TOPLEFT', 14, -240)
        editbox:SetWidth(150)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                getglobal(this:GetParent():GetName()..'TooltipInputBox3'):SetFocus()
            else
                getglobal(this:GetParent():GetName()..'NameInputBox'):SetFocus()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
    end
    do
        local editbox = Aux.gui.editbox(AuxFilterSearchFrameFilters, '$parentPageEditBox')
        editbox:SetNumeric(true)
        editbox:EnableMouse(false)
        editbox:SetAlpha(0.5)
        editbox:SetPoint('BOTTOMLEFT', 111, 15)
        editbox:SetWidth(30)
        editbox:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            Aux.filter_search_frame.start_search()
        end)
        editbox:SetScript('OnEscapePressed', function()
            this:ClearFocus()
        end)
        local label = Aux.gui.label(editbox, 13)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Page')
    end
    do
        local label = Aux.gui.label(AuxFilterSearchFrameFiltersAllPagesCheckButton, 13)
        label:SetPoint('BOTTOMLEFT', AuxFilterSearchFrameFiltersAllPagesCheckButton, 'TOPLEFT', 1, -3)
        label:SetText('All')
    end

    -- TODO replace with real gui dropdown
--    CreateFrame('Frame', '$parentCategoryDropDown', AuxFilterSearchFrameFilters, 'UIDropDownMenuTemplate')
--    local dropdown = CreateFrame('Frame', '$parentQualityDropDown', AuxFilterSearchFrameFilters, 'UIDropDownMenuTemplate')
    for _, dropdown in ipairs({AuxFilterSearchFrameFiltersCategoryDropDown, AuxFilterSearchFrameFiltersQualityDropDown}) do
        dropdown:SetWidth(150)
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

    if aux_view == Aux.view.BUYOUT then
        AuxFilterSearchFrameResultsBuyListing:Show()
        local buyout_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
        Aux.sheet.populate(private.listings[Aux.view.BUYOUT], auctions and Aux.util.group_by(buyout_auctions, function(a1, a2) return a1.item_id == a2.item_id and a1.suffix_id == a2.suffix_id and a1.enchant_id == a2.enchant_id and a1.aux_quantity == a2.aux_quantity and a1.buyout_price == a2.buyout_price end) or {})
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsBuyListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	elseif aux_view == Aux.view.BID then
        AuxFilterSearchFrameResultsBidListing:Show()
        local bid_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') end) or {}
        Aux.sheet.populate(private.listings[Aux.view.BID], bid_auctions)
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsBidListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	elseif aux_view == Aux.view.FULL then
        AuxFilterSearchFrameResultsFullListing:Show()
        Aux.sheet.populate(private.listings[Aux.view.FULL], auctions or {})
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsFullListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	end
end

function public.set_view(view)
    private.clear_selection()
    aux_view = view
    refresh = true
end

function private.create_filter_query()
    local category = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersCategoryDropDown)

    return {
        type = 'list',
        start_page = AuxFilterSearchFrameFiltersAllPagesCheckButton:GetChecked() and 0 or AuxFilterSearchFrameFiltersPageEditBox:GetNumber(),
        name = AuxFilterSearchFrameFiltersNameInputBox:GetText(),
        min_level = AuxFilterSearchFrameFiltersMinLevel:GetText(),
        max_level = AuxFilterSearchFrameFiltersMaxLevel:GetText(),
        slot = category and category.slot,
        class = category and category.class,
        subclass = category and category.subclass,
        quality = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersQualityDropDown),
        usable = AuxFilterSearchFrameFiltersUsableCheckButton:GetChecked()
    }
end

function public.start_search()

    Aux.scan.abort(function()

        private.clear_selection()

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

        AuxFilterSearchFrameFiltersSearchButton:Hide()
        AuxFilterSearchFrameFiltersStopButton:Show()

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
            on_start_query = function(query_index)
                private.status_bar:update_status(0, 100 * query_index / getn(queries)) -- TODO
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

                AuxFilterSearchFrameFiltersStopButton:Hide()
                AuxFilterSearchFrameFiltersSearchButton:Show()
                refresh = true
            end,
            on_abort = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
                AuxFilterSearchFrameFiltersStopButton:Hide()
                AuxFilterSearchFrameFiltersSearchButton:Show()
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

