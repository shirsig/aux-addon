local private, public = {}, {}
Aux.item_search_frame = public

aux_recently_searched = {}

local create_auction_record, show_dialog, find_auction, hide_sheet, update_listing, auction_alpha_setter, group_alpha_setter, create_auction_record
local auctions
local search_query
local current_page
local refresh

function auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function group_alpha_setter(cell, group)
    cell:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
end

public.recently_searched_config = {
    on_row_click = function (sheet, row_index)
        PlaySound('igMainMenuOptionCheckBoxOn')
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxItemSearchFrameItemItemInputBox:Hide()
        public.set_item(sheet.data[data_index].item_id)
    end,
    on_row_enter = function(sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,
    on_row_leave = function(sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(0)
    end,
    columns = {
        {
            title = 'Item',
            width = 163,
            comparator = function(datum1, datum2)
                return Aux.util.compare(datum1.time, datum2.time, Aux.util.GT)
            end,
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
                text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                text:SetPoint('TOPRIGHT', cell)
                text:SetPoint('BOTTOMRIGHT', cell)
                text:SetJustifyV('TOP')
                text:SetJustifyH('LEFT')
                text:SetTextColor(0.8, 0.8, 0.8)
                cell.text = text
                cell.icon = icon
            end,
            cell_setter = function(cell, datum)
                local item_info = Aux.static.item_info(datum.item_id)
                cell.icon.icon_texture:SetTexture(item_info.texture)
                cell.text:SetText('['..item_info.name..']')
                local color = ITEM_QUALITY_COLORS[item_info.quality]
                cell.text:SetTextColor(color.r, color.g, color.b)
            end,
        },
    },
    sort_order = {},
}
public.views = {
	[Aux.view.BUYOUT] = {
		name = 'Buyout',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(Aux.util.filter(sheet.data[data_index], function(auction) return not auction.gone end)[1] or sheet.data[data_index][1])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
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
        row_setter = function(row, group)
            row.itemstring = Aux.info.itemstring(group[1].item_id, group[1].suffix_id, nil, group[1].enchant_id)
            row.EnhTooltip_info = group[1].EnhTooltip_info
        end,
        columns = {
            {
                title = 'Qty',
                width = 25,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].aux_quantity, group2[1].aux_quantity, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].aux_quantity)
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Buy',
                width = 80,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price, group2[1].buyout_price, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Buy/ea',
                width = 80,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price_per_unit, group2[1].buyout_price_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price_per_unit))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Avail',
                width = 40,
                comparator = function(group1, group2) return Aux.util.compare(getn(Aux.util.filter(group1, function(auction) return not auction.gone end)), getn(Aux.util.filter(group2, function(auction) return not auction.gone end)), Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(getn(Aux.util.filter(group, function(auction) return not auction.gone end)))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Pct',
                width = 40,
                comparator = function(group1, group2)
                    local market_price1 = Aux.history.market_value(group1[1].item_key)
                    local market_price2 = Aux.history.market_value(group2[1].item_key)
                    local factor1 = market_price1 > 0 and group1[1].buyout_price_per_unit / market_price1
                    local factor2 = market_price2 > 0 and group2[1].buyout_price_per_unit / market_price2
                    return Aux.util.compare(factor1, factor2, Aux.util.GT)
                end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    local market_price = Aux.history.market_value(group[1].item_key)

                    local pct = market_price > 0 and ceil(100 / market_price * group[1].buyout_price_per_unit)
                    if not pct then
                        cell.text:SetText('N/A')
                    elseif pct > 999 then
                        cell.text:SetText('>999%')
                    else
                        cell.text:SetText(pct..'%')
                    end
                    if pct then
                        cell.text:SetTextColor(Aux.price_level_color(pct))
                    end
                    group_alpha_setter(cell, group)
                end,
            },
        },
        sort_order = {{column = 3, order = 'ascending' }},
	},
	[Aux.view.BID] = {
		name = 'Bid',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
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
        row_setter = function(row, datum)
            row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, datum.unique_id, datum.enchant_id)
            row.EnhTooltip_info = datum.EnhTooltip_info
        end,
        columns = {
            {
                title = 'Qty',
                width = 25,
                comparator = function(row1, row2) return Aux.util.compare(row1.aux_quantity, row2.aux_quantity, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.aux_quantity)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid/ea',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Status',
                width = 70,
                comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, auction)
                    cell.text:SetText(auction.status)
                    auction_alpha_setter(cell, auction)
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
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Page',
                width = 40,
                comparator = function(row1, row2) return Aux.util.compare(row1.page, row2.page, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.page)
                    auction_alpha_setter(cell, datum)
                end,
            },
        },
        sort_order = {{column = 3, order = 'ascending'}, {column = 5, order = 'ascending'}},
	},
	[Aux.view.FULL] = {
		name = 'Full',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
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
        row_setter = function(row, datum)
            row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, datum.unique_id, datum.enchant_id)
            row.EnhTooltip_info = datum.EnhTooltip_info
        end,
		columns = {
            {
                title = 'Qty',
                width = 25,
                comparator = function(row1, row2) return Aux.util.compare(row1.aux_quantity, row2.aux_quantity, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.aux_quantity)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Buy',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid/ea',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Buy/ea',
                width = 80,
                comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.buyout_price_per_unit))
                    auction_alpha_setter(cell, datum)
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
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Status',
                width = 70,
                comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, auction)
                    cell.text:SetText(auction.status)
                    auction_alpha_setter(cell, auction)
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
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Owner',
                width = 90,
                comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.owner)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Page',
                width = 40,
                comparator = function(row1, row2) return Aux.util.compare(row1.page, row2.page, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.page)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Pct',
                width = 40,
                comparator = function(row1, row2)
                    local market_price1 = Aux.history.market_value(row1.item_key)
                    local market_price2 = Aux.history.market_value(row2.item_key)
                    local factor1 = market_price1 > 0 and row1.buyout_price_per_unit and row1.buyout_price_per_unit / market_price1
                    local factor2 = market_price2 > 0 and row2.buyout_price_per_unit and row2.buyout_price_per_unit / market_price2
                    return Aux.util.compare(factor1, factor2, Aux.util.GT)
                end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    local market_price = Aux.history.market_value(datum.item_key)

                    local pct = market_price > 0 and datum.buyout_price_per_unit and ceil(100 / market_price * datum.buyout_price_per_unit)
                    if not pct then
                        cell.text:SetText('N/A')
                    elseif pct > 999 then
                        cell.text:SetText('>999%')
                    else
                        cell.text:SetText(pct..'%')
                    end
                    if pct then
                        cell.text:SetTextColor(Aux.price_level_color(pct))
                    end
                    auction_alpha_setter(cell, datum)
                end,
            },
        },
        sort_order = {{column = 5, order = 'ascending'}},
	},
}

function public.on_close()
    if AuxItemSearchFrameAuctionsConfirmation:IsVisible() then
	    public.dialog_cancel()
    end
	current_page = nil
end

function public.on_open()
    public.update_item()
    private.update_recently_searched()
	update_listing()
    if not private.item_id then
        AuxItemSearchFrameItemRefreshButton:Disable()
    end
end

function public.on_load()
    do
        local btn = Aux.gui.button(AuxItemSearchFrameItem, 15, '$parentRefreshButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(75)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', Aux.item_search_frame.start_search)
    end
    do
        local btn = Aux.gui.button(AuxItemSearchFrameItem, 15, '$parentStopButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(75)
        btn:SetHeight(24)
        btn:SetText('Stop')
        btn:SetScript('OnClick', Aux.item_search_frame.stop_search)
        btn:Hide()
    end
    do
        local tab_group = Aux.gui.tab_group(AuxItemSearchFrameAuctions, 'TOP')
        tab_group:create_tab('Buy')
        tab_group:create_tab('Bid')
        tab_group:create_tab('Full')
        tab_group.on_select = Aux.item_search_frame.set_view
        tab_group:set_tab(aux_view)
    end
    do
        local editbox = Aux.gui.editbox(AuxItemSearchFrameItem, '$parentItemInputBox')
        editbox.selector = Aux.completion.selector(editbox)
        editbox:SetPoint('TOP', 0, -28)
        editbox:SetWidth(185)
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
            if this.selector.selected_value() then
                this:ClearFocus()
            end
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this.selector.close()
            if this.selector.selected_value() then
                Aux.item_search_frame.set_item(this.selector.selected_value())
            end
            if Aux.item_search_frame.item_set() then
                this:Hide()
                this.selector.clear()
                Aux.item_search_frame.update_item()
            end
        end)
        editbox:SetScript('OnEscapePressed', function()
            this.selector.clear()
            this:ClearFocus()
        end)
    end
    do
        local status_bar = Aux.gui.status_bar(AuxItemSearchFrame, 15, 'kekbar')
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxItemSearchFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(0,0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
end

function public.dialog_cancel()
	Aux.scan.abort()
    AuxItemSearchFrameAuctionsConfirmation:Hide()
	update_listing()
    AuxItemSearchFrameItemRefreshButton:Enable()
end

function public.stop_search()
	Aux.scan.abort()
end

function update_listing()

    if not AuxItemSearchFrame:IsVisible() then
        return
    end

	AuxItemSearchFrameAuctionsBuyListing:Hide()
    AuxItemSearchFrameAuctionsBidListing:Hide()
    AuxItemSearchFrameAuctionsFullListing:Hide()

    if aux_view == Aux.view.BUYOUT then
		AuxItemSearchFrameAuctionsBuyListing:Show()
        local buy_records = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
        Aux.sheet.populate(AuxItemSearchFrameAuctionsBuyListing.sheet, auctions and Aux.util.group_by(buy_records, function(a1, a2) return a1.item_id == a2.item_id and a1.suffix_id == a2.suffix_id and a1.enchant_id == a2.enchant_id and a1.aux_quantity == a2.aux_quantity and a1.buyout_price == a2.buyout_price end) or {})
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsBuyListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 15)
	elseif aux_view == Aux.view.BID then
		AuxItemSearchFrameAuctionsBidListing:Show()
        local bid_records = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') end) or {}
        Aux.sheet.populate(AuxItemSearchFrameAuctionsBidListing.sheet, bid_records)
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsBidListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 15)
	elseif aux_view == Aux.view.FULL then
		AuxItemSearchFrameAuctionsFullListing:Show()
        Aux.sheet.populate(AuxItemSearchFrameAuctionsFullListing.sheet, auctions or {})
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsFullListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 15)
	end
end

function hide_sheet()
	AuxItemSearchFrameAuctionsBuyListing:Hide()
	AuxItemSearchFrameAuctionsBidListing:Hide()
	AuxItemSearchFrameAuctionsFullListing:Hide()
end

function public.set_view(view)
    aux_view = view
    update_listing()
end

function private.update_recently_searched()
    Aux.sheet.populate(AuxItemSearchFrameRecentlySearchedListing.sheet, aux_recently_searched)
end

function public.set_item(item_id)
    if item_id ~= private.item_id and Aux.static.item_info(item_id) then
        AuxItemSearchFrameItemRefreshButton:Enable()
        private.item_id = item_id
        public.update_item()

        local updated_recently_searched = Aux.util.filter(aux_recently_searched, function(item_entry)
            return item_entry.item_id ~= item_id
        end)
        tinsert(updated_recently_searched, 1, { item_id=item_id, time=time() })
        while getn(updated_recently_searched) > 50 do
            tremove(updated_recently_searched, getn(updated_recently_searched))
        end
        aux_recently_searched = updated_recently_searched

        private.update_recently_searched()
        public.start_search()
    elseif not private.item_id then
        AuxItemSearchFrameItemItemInputBox:Show()
    end
end

function public.item_set()
    return private.item_id ~= nil
end

function public.update_item()
    if private.item_id and not AuxItemSearchFrameItemItemInputBox:IsVisible() then
        local info = Aux.static.item_info(private.item_id)
        AuxItemSearchFrameItemItemIconTexture:SetTexture(info.texture)
        AuxItemSearchFrameItemItemName:SetText(info.name)
        local color = ITEM_QUALITY_COLORS[info.quality]
        AuxItemSearchFrameItemItemName:SetTextColor(color.r, color.g, color.b)
        AuxItemSearchFrameItemItem:Show()
    else
        AuxItemSearchFrameItemItem:Hide()
    end
end

function public.start_search()

    Aux.scan.abort(function()

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

        AuxItemSearchFrameItemRefreshButton:Hide()
        AuxItemSearchFrameItemStopButton:Show()

        auctions = nil

        refresh = true

        local item_id = private.item_id
        local item_info = Aux.static.item_info(item_id)

--        local class_index = Aux.item_class_index(item_info.class)
--        local subclass_index = class_index and Aux.item_subclass_index(class_index, item_info.subclass)

        search_query = {
            name = item_info.name,
            min_level = item_info.level,
            min_level = item_info.level,
            slot = item_info.slot,
            class = Aux.item_class_index(item_info.class),
            subclass = item_info.subclass,
            quality = item_info.quality,
            usable = item_info.usable,
        }

--        Aux.log('Scanning auctions ...')
        Aux.scan.start{
            query = search_query,
            page = AuxItemSearchFrameItemAllPagesCheckButton:GetChecked() and 0 or AuxItemSearchFrameItemPageEditBox:GetNumber(),
            on_submit_query = function()
                current_page = nil
            end,
            on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 0)
                private.status_bar:set_text(string.format('Scanning (Page %d / %d)', page + 1, total_pages))
--                Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
                current_page = page
            end,
            on_read_auction = function(auction_info)
                if auction_info.item_id == item_id then
                    auctions = auctions or {}
                    tinsert(auctions, create_auction_record(auction_info, current_page))
                end
            end,
            on_complete = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
--                Aux.log('Scan complete: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')

                AuxItemSearchFrameItemStopButton:Hide()
                AuxItemSearchFrameItemRefreshButton:Show()
                refresh = true
            end,
            on_abort = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
--                Aux.log('Scan aborted: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')
                AuxItemSearchFrameItemStopButton:Hide()
                AuxItemSearchFrameItemRefreshButton:Show()
                refresh = true
            end,
            next_page = function(page, total_pages)
                if AuxItemSearchFrameItemAllPagesCheckButton:GetChecked() then
                    local last_page = max(total_pages - 1, 0)
                    if page < last_page then
                        return page + 1
                    end
                end
            end,
        }
    end)
end

function show_dialog(buyout_mode, entry, amount)
	AuxItemSearchFrameAuctionsConfirmationContentItem.itemstring = Aux.info.itemstring(entry.item_id, entry.suffix_id, entry.unique_id, entry.enchant_id)
    AuxItemSearchFrameAuctionsConfirmationContentItem.EnhTooltip_info = entry.EnhTooltip_info

    AuxItemSearchFrameAuctionsConfirmationContentActionButton:Disable()
    AuxItemSearchFrameAuctionsConfirmationContentItemIconTexture:SetTexture(Aux.info.item(entry.item_id).texture)
    AuxItemSearchFrameAuctionsConfirmationContentItemName:SetText(entry.name)
	local color = ITEM_QUALITY_COLORS[entry.quality]
    AuxItemSearchFrameAuctionsConfirmationContentItemName:SetTextColor(color.r, color.g, color.b)

	if entry.aux_quantity > 1 then
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:SetText(entry.aux_quantity);
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:Show()
	else
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:Hide()
	end
	if buyout_mode then
        AuxItemSearchFrameAuctionsConfirmationContentActionButton:SetText('Buy')
		MoneyFrame_Update('AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice', amount)
        AuxItemSearchFrameAuctionsConfirmationContentBid:Hide()
        AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice:Show()
	else
        AuxItemSearchFrameAuctionsConfirmationContentActionButton:SetText('Bid')
		MoneyInputFrame_SetCopper(AuxItemSearchFrameAuctionsConfirmationContentBid, amount)
        AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice:Hide()
        AuxItemSearchFrameAuctionsConfirmationContentBid:Show()
	end
    AuxItemSearchFrameAuctionsConfirmation:Show()
end

function find_auction(entry, buyout_mode, express_mode)

	if entry.gone then
        Aux.log('Auction not available.')
		return
	end
	
	if buyout_mode and not entry.buyout_price then
        Aux.log('Auction has no buyout price.')
		return
	end

    local amount
    if buyout_mode then
        amount = entry.buyout_price
    else
        amount = entry.bid
    end

    Aux.log('Searching auction ...')
	AuxItemSearchFrameItemRefreshButton:Disable()
	
	if not express_mode then
		show_dialog(buyout_mode, entry, amount)
	end

	PlaySound('igMainMenuOptionCheckBoxOn')
	
	local found
	
	Aux.scan.start{
		query = search_query,
		page = entry.page ~= current_page and entry.page,
		on_submit_query = function()
			current_page = nil
		end,
		on_page_loaded = function(page)
			current_page = page
		end,
		on_read_auction = function(auction_info, ctrl)
			local auction_record = create_auction_record(auction_info)
			if entry.signature == auction_record.signature then
				ctrl.suspend()
				found = true
                Aux.log('Matching auction found.')

				if express_mode then
					if GetMoney() >= amount then
						PlaceAuctionBid('list', auction_info.index, amount)
                        Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' ('..auction_record.aux_quantity..').')
						entry.gone = true
						refresh = true
					else
						Aux.log((buyout_mode and 'Purchase' or 'Bid')..' failed: Not enough money.')
					end
					Aux.scan.abort()
				else
					public.dialog_action = function()
                        if create_auction_record(Aux.info.auction(auction_info.index)).signature == entry.signature then
                            if GetMoney() >= amount then
                                PlaceAuctionBid('list', auction_info.index, buyout_mode and amount or MoneyInputFrame_GetCopper(AuxItemSearchFrameAuctionsConfirmationContentBid))
                                Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' ('..auction_record.aux_quantity..').')
                                entry.gone = true
                                refresh = true
                            else
                                Aux.log('Not enough money.')
                            end
                            Aux.scan.abort()
                            AuxItemSearchFrameItemRefreshButton:Enable()
                            AuxItemSearchFrameAuctionsConfirmation:Hide()
                            update_listing()
                        end
					end
					AuxItemSearchFrameAuctionsConfirmationContentActionButton:Enable()
				end
			end
		end,
		on_complete = function()
			if not found then
                Aux.log('No matching auction found. Removing entry from the cache.')
				entry.gone = true
				refresh = true
				public.dialog_cancel()
			end
			if express_mode then
				AuxItemSearchFrameItemRefreshButton:Enable()
			end
		end,
		on_abort = function()
			if express_mode then
				AuxItemSearchFrameItemRefreshButton:Enable()
			end
		end,
		next_page = function(page, total_pages)
			if not page or page == entry.page then
				return entry.page - 1
			end
		end,
	}
end

function public.on_row_click(entry)

	local express_mode = IsAltKeyDown()
	local buyout_mode = arg1 == 'LeftButton'
	
	if IsControlKeyDown() then 
		DressUpItemLink(entry.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(entry.hyperlink)
        end
	else
		find_auction(entry, buyout_mode, express_mode)
	end	
end

function create_auction_record(auction_info, current_page)
	
	local aux_quantity = auction_info.charges or auction_info.count
	local bid = (auction_info.current_bid > 0 and auction_info.current_bid or auction_info.min_bid) + auction_info.min_increment
	local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
	local buyout_price_per_unit = buyout_price and Aux.round(auction_info.buyout_price / aux_quantity)
    local status
    if auction_info.current_bid == 0 then
        status = 'No Bid'
    elseif auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
    else
        status = 'Other Bidder'
    end

    return {
        item_id = auction_info.item_id,
        suffix_id = auction_info.suffix_id,
        unique_id = auction_info.unique_id,
        enchant_id = auction_info.enchant_id,

        item_key = auction_info.item_key,

        signature = Aux.auction_signature(auction_info.hyperlink, aux_quantity, bid, auction_info.buyout_price),

        name = auction_info.name,
        level = auction_info.level,
        aux_quantity = aux_quantity,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        page = current_page,
        bid = bid,
        bid_per_unit = Aux.round(bid / aux_quantity),
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
		update_listing()
	end
end