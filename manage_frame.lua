local on_open, on_close

local bid_records, auction_records, create_bid_record, create_auction_record, update_bid_records, update_auction_records, wait_for_bids, wait_for_auctions, create_record

local position

local bid_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxBuyEntry_OnClick(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(0)
    end,
    columns = {
        {
            title = 'Qty',
            width = 23,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.stack_size)
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Auction Item',
            width = 157,
            comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
            cell_initializer = function(cell)
                local icon = CreateFrame('Button', nil, cell)
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
                icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_RIGHT', cell.EnhTooltip_info) end)
                icon:SetScript('OnLeave', function() GameTooltip:Hide() end)
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
                cell.tooltip = datum.tooltip
                cell.EnhTooltip_info = datum.EnhTooltip_info
                cell.icon.icon_texture:SetTexture(datum.texture)
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
            width = 23,
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
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.owner)
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price_per_unit))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                auction_alpha_setter(cell, datum)
            end,
        },
    },
    sort_order = {},
}

local auction_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxBuyEntry_OnClick(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(0)
    end,
    columns = {
        {
            title = 'Qty',
            width = 23,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.stack_size)
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Auction Item',
            width = 157,
            comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
            cell_initializer = function(cell)
                local icon = CreateFrame('Button', nil, cell)
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
                icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_RIGHT', cell.EnhTooltip_info) end)
                icon:SetScript('OnLeave', function() GameTooltip:Hide() end)
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
                cell.tooltip = datum.tooltip
                cell.EnhTooltip_info = datum.EnhTooltip_info
                cell.icon.icon_texture:SetTexture(datum.texture)
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
            width = 23,
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
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.owner)
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price_per_unit))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid))
                auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                auction_alpha_setter(cell, datum)
            end,
        },
    },
    sort_order = {},
}

function on_open()
--    update_bid_records(function()
        update_auction_records(function()
        end)
--    end)
end

function on_close()
end

function update_bid_records(k)
    bid_records = {}
    Aux.scan.start{
        type = 'bidder',
        page = 0,
        on_submit_query = function()
            position = nil
        end,
        on_page_loaded = function(page, total_pages)
            Aux.log('Scanning bid page '..(page+1)..' out of '..total_pages..' ...')
            position = 'bids#'..page
        end,
        on_read_auction = function(i)
            snipe.log('bids#'..i)
        end,
        on_complete = function()
--            Aux.list.populate(AuxManageBidsListing.sheet, bid_records)
            return k()
        end,
        on_abort = function()
        end,
        next_page = function(page, total_pages)
            local last_page = max(total_pages - 1, 0)
            if page < last_page then
                return page + 1
            end
        end,
    }
end

function update_auction_records(k)
    auction_records = {}
    Aux.scan.start{
        type = 'owner',
        page = 0,
        on_submit_query = function()
            position = nil
        end,
        on_page_loaded = function(page, total_pages)
            Aux.log('Scanning auction page '..(page+1)..' out of '..total_pages..' ...')
            position = 'auctions#'..page
        end,
        on_read_auction = function(i)
            snipe.log('auctions#'..i)
        end,
        on_complete = function()
--            Aux.list.populate(AuxManageAuctionsListing.sheet, auction_records)
            return k()
        end,
        on_abort = function()
        end,
        next_page = function(page, total_pages)
            local last_page = max(total_pages - 1, 0)
            if page < last_page then
                return page + 1
            end
        end,
    }
end

function create_record(auction_item, current_page)

    local stack_size = auction_item.charges or auction_item.count
    local bid = (auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid) + auction_item.min_increment
    local buyout_price = auction_item.buyout_price > 0 and auction_item.buyout_price or nil
    local buyout_price_per_unit = buyout_price and Aux_Round(auction_item.buyout_price/stack_size)
    local status
    if auction_item.current_bid == 0 then
        status = 'No Bid'
    elseif auction_item.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE..'Other Bidder'..FONT_COLOR_CODE_CLOSE
    end

    return {
        key = auction_item.item_signature,
        signature = Aux.auction_signature(auction_item.hyperlink, stack_size, bid, auction_item.buyout_price),

        name = auction_item.name,
        level = auction_item.level,
        texture = auction_item.texture,
        tooltip = auction_item.tooltip,
        stack_size = stack_size,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_item.quality,
        hyperlink = auction_item.hyperlink,
        itemstring = auction_item.itemstring,
        page = current_page,
        bid = bid,
        bid_per_unit = Aux_Round(bid/stack_size),
        owner = auction_item.owner,
        duration = auction_item.duration,
        usable = auction_item.usable,
        high_bidder = auction_item.high_bidder,
        status = status,

        EnhTooltip_info = auction_item.EnhTooltip_info,
    }
end

function create_auction_record(index)
    local auction_item = Aux.info.auction_item(i, 'owner')
    if auction_item then
        tinsert(auction_records, create_record(auction_item, i))
    end
end

function create_bid_record(index)
    local auction_item = Aux.info.auction_item(i, 'bidder')
    if auction_item then
        tinsert(auction_records, create_record(auction_item, i))
    end
end

Aux.manage_frame = {
    on_open = on_open,
    on_close = on_close,
    bid_listing_config = bid_listing_config,
    auction_listing_config = auction_listing_config,
}


