Aux.buy = {}

local private, public = {}, {}
Aux.filter_search_frame = public

local create_auction_record, show_dialog, find_auction, hide_sheet, update_sheet, auction_alpha_setter, group_alpha_setter, create_auction_record
local auctions
local search_query
local tooltip_patterns = {}
local current_page
local refresh

function auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function group_alpha_setter(cell, group)
    cell:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
end

public.views = {
	[Aux.view.BUYOUT] = {
		name = 'Buyout',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(Aux.util.filter(sheet.data[data_index], function(auction) return not auction.gone end)[1] or sheet.data[data_index][1])
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
                    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
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
                    group_alpha_setter(cell, group)
                end,
            },
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
        sort_order = {{column = 1, order = 'ascending' }, {column = 4, order = 'ascending'}},
	},
	[Aux.view.BID] = {
		name = 'Bid',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index])
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
                    cell.icon.icon_texture:SetTexture(Aux.info.item(datum.item_id).texture)
                    if not datum.usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..datum.tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[datum.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                    auction_alpha_setter(cell, datum)
                end,
            },
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
        sort_order = {{column = 1, order = 'ascending' }, {column = 4, order = 'ascending' }, {column = 6, order = 'ascending'}},
	},
	[Aux.view.FULL] = {
		name = 'Full',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index])
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
                    cell.icon.icon_texture:SetTexture(Aux.info.item(datum.item_id).texture)
                    if not datum.usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..datum.tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[datum.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
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
        sort_order = {{column = 1, order = 'ascending' }},
	},
}

function public.on_close()
    if AuxFilterSearchFrameResultsConfirmation:IsVisible() then
	    public.dialog_cancel()
    end
	current_page = nil
end

function public.on_open()
    public.set_view(aux_view)
	update_sheet()
end

function public.dialog_cancel()
    Aux.log('Aborted.')
	Aux.scan.abort()
    AuxFilterSearchFrameResultsConfirmation:Hide()
	update_sheet()
    AuxFilterSearchFrameFiltersSearchButton:Enable()
end

function public.stop_search()
	Aux.scan.abort()
end

function update_sheet()

    if not AuxFilterSearchFrame:IsVisible() then
        return
    end

	AuxFilterSearchFrameResultsBuyListing:Hide()
    AuxFilterSearchFrameResultsBidListing:Hide()
    AuxFilterSearchFrameResultsFullListing:Hide()

    if aux_view == Aux.view.BUYOUT then
        AuxFilterSearchFrameResultsBuyListing:Show()
        local buyout_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
        Aux.sheet.populate(AuxFilterSearchFrameResultsBuyListing.sheet, auctions and Aux.util.group_by(buyout_auctions, function(a1, a2) return a1.item_id == a2.item_id and a1.suffix_id == a2.suffix_id and a1.enchant_id == a2.enchant_id and a1.aux_quantity == a2.aux_quantity and a1.buyout_price == a2.buyout_price end) or {})
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsBuyListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	elseif aux_view == Aux.view.BID then
        AuxFilterSearchFrameResultsBidListing:Show()
        local bid_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') end) or {}
        Aux.sheet.populate(AuxFilterSearchFrameResultsBidListing.sheet, bid_auctions)
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsBidListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	elseif aux_view == Aux.view.FULL then
        AuxFilterSearchFrameResultsFullListing:Show()
        Aux.sheet.populate(AuxFilterSearchFrameResultsFullListing.sheet, auctions or {})
        AuxFilterSearchFrameResults:SetWidth(AuxFilterSearchFrameResultsFullListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxFilterSearchFrameFilters:GetWidth() + AuxFilterSearchFrameResults:GetWidth() + 15)
	end
end

function hide_sheet()
    AuxFilterSearchFrameResultsBuyListing:Hide()
    AuxFilterSearchFrameResultsBidListing:Hide()
    AuxFilterSearchFrameResultsFullListing:Hide()
end

function public.set_view(view)
    for i=1,3 do
        getglobal('AuxFilterSearchFrameResultsTab'..i):SetAlpha(i == view and 1 or 0.5)
    end
    aux_view = view
    update_sheet()
end

function public.set_item(item_id)
    private.item_id = item_id
end

function public.start_search()

    Aux.scan.abort(function()

        AuxFilterSearchFrameFiltersSearchButton:Hide()
        AuxFilterSearchFrameFiltersStopButton:Show()

        auctions = nil

        refresh = true

        local category = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersCategoryDropDown)
        local tooltip_patterns = {}
        for i=1,4 do
            local tooltip_pattern = getglobal('AuxFilterSearchFrameFiltersTooltipInputBox'..i):GetText()
            if tooltip_pattern ~= '' then
                tinsert(tooltip_patterns, tooltip_pattern)
            end
        end

        search_query = {
            name = AuxFilterSearchFrameFiltersNameInputBox:GetText(),
            min_level = AuxFilterSearchFrameFiltersMinLevel:GetText(),
            max_level = AuxFilterSearchFrameFiltersMaxLevel:GetText(),
            slot = category and category.slot,
            class = category and category.class,
            subclass = category and category.subclass,
            quality = UIDropDownMenu_GetSelectedValue(AuxFilterSearchFrameFiltersQualityDropDown),
            usable = AuxFilterSearchFrameFiltersUsableCheckButton:GetChecked()
        }

        Aux.log('Scanning auctions ...')
        Aux.scan.start{
            query = search_query,
            page = AuxFilterSearchFrameFiltersAllPagesCheckButton:GetChecked() and 0 or AuxFilterSearchFrameFiltersPageEditBox:GetNumber(),
            on_submit_query = function()
                current_page = nil
            end,
            on_page_loaded = function(page, total_pages)
                Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
                current_page = page
            end,
            on_read_auction = function(auction_info)
                if Aux.info.tooltip_match(tooltip_patterns, auction_info.tooltip) then
                    auctions = auctions or {}
                    tinsert(auctions, create_auction_record(auction_info, current_page))
                end
            end,
            on_complete = function()
                auctions = auctions or {}
                Aux.log('Scan complete: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')

                AuxFilterSearchFrameFiltersStopButton:Hide()
                AuxFilterSearchFrameFiltersSearchButton:Show()
                refresh = true
            end,
            on_abort = function()
                auctions = auctions or {}
                Aux.log('Scan aborted: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')
                AuxFilterSearchFrameFiltersStopButton:Hide()
                AuxFilterSearchFrameFiltersSearchButton:Show()
                refresh = true
            end,
            next_page = function(page, total_pages)
                if AuxFilterSearchFrameFiltersAllPagesCheckButton:GetChecked() then
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
    AuxFilterSearchFrameResultsConfirmationContentItem.itemstring = Aux.info.itemstring(entry.item_id, entry.suffix_id, entry.unique_id, entry.enchant_id)
    AuxFilterSearchFrameResultsConfirmationContentItem.EnhTooltip_info = entry.EnhTooltip_info

    AuxFilterSearchFrameResultsConfirmationContentActionButton:Disable()
    AuxFilterSearchFrameResultsConfirmationContentItemIconTexture:SetTexture(Aux.info.item(entry.item_id).texture)

    AuxFilterSearchFrameResultsConfirmationContentItemName:SetText(entry.tooltip[1][1].text)
	local color = ITEM_QUALITY_COLORS[entry.quality]
    AuxFilterSearchFrameResultsConfirmationContentItemName:SetTextColor(color.r, color.g, color.b)

	if entry.aux_quantity > 1 then
        AuxFilterSearchFrameResultsConfirmationContentItemCount:SetText(entry.aux_quantity);
        AuxFilterSearchFrameResultsConfirmationContentItemCount:Show()
	else
        AuxFilterSearchFrameResultsConfirmationContentItemCount:Hide()
	end
	if buyout_mode then
        AuxFilterSearchFrameResultsConfirmationContentActionButton:SetText('Buy')
		MoneyFrame_Update('AuxFilterSearchFrameResultsConfirmationContentBuyoutPrice', amount)
        AuxFilterSearchFrameResultsConfirmationContentBid:Hide()
        AuxFilterSearchFrameResultsConfirmationContentBuyoutPrice:Show()
	else
        AuxFilterSearchFrameResultsConfirmationContentActionButton:SetText('Bid')
		MoneyInputFrame_SetCopper(AuxFilterSearchFrameResultsConfirmationContentBid, amount)
        AuxFilterSearchFrameResultsConfirmationContentBuyoutPrice:Hide()
        AuxFilterSearchFrameResultsConfirmationContentBid:Show()
	end
    AuxFilterSearchFrameResultsConfirmation:Show()
end

function find_auction(entry, buyout_mode, express_mode)

	if entry.gone then
        Aux.log('Auction not available')
		return
	end
	
	if buyout_mode and not entry.buyout_price then
        Aux.log('Auction has no buyout price')
		return
	end

    local amount
    if buyout_mode then
        amount = entry.buyout_price
    else
        amount = entry.bid
    end

    Aux.log('Processing '..(buyout_mode and 'buyout' or 'bid')..' request for '..entry.hyperlink..' x '..entry.aux_quantity..' at '..Aux.util.money_string(amount)..' ...')
    AuxFilterSearchFrameFiltersSearchButton:Disable()
	
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
                Aux.log('Matching auction found.'..(express_mode and '' or ' Awaiting confirmation ...'))
				
				if express_mode then
					if GetMoney() >= amount then
						PlaceAuctionBid('list', auction_info.index, amount)
                        Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' x '..auction_record.aux_quantity..' at '..Aux.util.money_string(amount)..'.')
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
                                PlaceAuctionBid('list', auction_info.index, buyout_mode and amount or MoneyInputFrame_GetCopper(AuxFilterSearchFrameResultsConfirmationContentBid))
                                Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' x '..auction_record.aux_quantity..' at '..Aux.util.money_string(buyout_mode and amount or MoneyInputFrame_GetCopper(AuxFilterSearchFrameResultsConfirmationContentBid))..'.')
                                entry.gone = true
                                refresh = true
                            else
                                Aux.log('Not enough money.')
                            end
                            Aux.scan.abort()
                            AuxFilterSearchFrameFiltersSearchButton:Enable()
                            AuxFilterSearchFrameResultsConfirmation:Hide()
                            update_sheet()
                        end
					end
                    AuxFilterSearchFrameResultsConfirmationContentActionButton:Enable()
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
                AuxFilterSearchFrameFiltersSearchButton:Enable()
			end
		end,
		on_abort = function()
			if express_mode then
                AuxFilterSearchFrameFiltersSearchButton:Enable()
			end
		end,
		next_page = function(page, total_pages)
			if not page or page == entry.page then
				return entry.page - 1
			end
		end,
	}
end

function private.on_row_click(entry)

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
	local buyout_price_per_unit = buyout_price and Aux_Round(auction_info.buyout_price / aux_quantity)
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
        key = auction_info.item_signature,
        signature = Aux.auction_signature(auction_info.hyperlink, aux_quantity, bid, auction_info.buyout_price),

        name = auction_info.name,
        level = auction_info.level,
        tooltip = auction_info.tooltip,
        aux_quantity = aux_quantity,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        page = current_page,
        bid = bid,
        bid_per_unit = Aux_Round(bid / aux_quantity),
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function Aux.buy.onupdate()
	if refresh then
		refresh = false
		update_sheet()
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
			text = getglobal("ITEM_QUALITY"..i.."_DESC"),
			value = i,
			func = on_click,
		}
	end
end

