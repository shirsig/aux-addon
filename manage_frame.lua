local private, public = {}, {}
Aux.manage_frame = public

local update_bid_records, update_auction_records, wait_for_bids, wait_for_auctions

local bid_records, auction_records

local BIDS, AUCTIONS = 1, 2

public.bid_listing_config = {
    on_row_click = function(sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxBuyEntry_OnClick(sheet.data[data_index])
    end,

    on_row_enter = function(sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_row_leave = function(sheet, row_index, column_index)
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
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Auction Item',
            width = 157,
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
                icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_CURSOR', cell.EnhTooltip_info) end)
                icon:SetScript('OnLeave', function() AuxTooltip:Hide() end)
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
                private.auction_alpha_setter(cell, datum)
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
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Owner',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.owner)
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid))
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                private.auction_alpha_setter(cell, datum)
            end,
        },
    },
    sort_order = {},
}

public.auction_listing_config = {
    on_row_click = function (sheet, row_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxBuyEntry_OnClick(sheet.data[data_index])
    end,

    on_row_enter = function (sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_row_leave = function (sheet, row_index)
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
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Auction Item',
            width = 157,
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
                icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_CURSOR', cell.EnhTooltip_info) end)
                icon:SetScript('OnLeave', function() AuxTooltip:Hide() end)
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
                private.auction_alpha_setter(cell, datum)
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
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Bid',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.bid))
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                private.auction_alpha_setter(cell, datum)
            end,
        },
    },
    sort_order = {},
}

function public.on_open()
    public.listing = public.listing or BIDS

    if public.listing == BIDS then
        public.update_bid_records()
    elseif public.listing == AUCTIONS then
        public.update_auction_records()
    end

    public.update_listing()
end

function public.on_close()
end

function private.auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function public.update_bid_records()
    bid_records = {}
    Aux.scan.start{
        type = 'bidder',
        page = 0,
        on_page_loaded = function(page, total_pages)
			Aux.log('Scanning bid page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(i)
            private.create_bid_record(i)
        end,
        on_complete = function()
            Aux.log('Scan complete: '..getn(bid_records)..' bids found')
            public.update_listing()
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

function public.update_auction_records()
    auction_records = {}
    Aux.scan.start{
        type = 'owner',
        page = 0,
        on_page_loaded = function(page, total_pages)
			Aux.log('Scanning auction page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(i)
            private.create_auction_record(i)
        end,
        on_complete = function()
            Aux.log('Scan complete: '..getn(auction_records)..' auctions found')
            public.update_listing()
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

function public.update_listing()
    AuxManageFrameListingBidListing:Hide()
    AuxManageFrameListingAuctionListing:Hide()

    for i=1,2 do
        getglobal('AuxManageFrameListingTab'..i):SetAlpha(i == public.listing and 1 or 0.5)
    end

    if public.listing == BIDS then
        AuxManageFrameListingBidListing:Show()
        Aux.list.populate(AuxManageFrameListingBidListing.sheet, bid_records)
        AuxManageFrameListing:SetWidth(AuxManageFrameListingBidListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxManageFrameListing:GetWidth() + 15)
    elseif public.listing == AUCTIONS then
        AuxManageFrameListingAuctionListing:Show()
        Aux.list.populate(AuxManageFrameListingAuctionListing.sheet, auction_records)
        AuxManageFrameListing:SetWidth(AuxManageFrameListingAuctionListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxManageFrameListing:GetWidth() + 15)
    end
end

function private.create_record(auction_item)

    local stack_size = auction_item.charges or auction_item.count
    local bid = (auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid) + auction_item.min_increment
    local buyout_price = auction_item.buyout_price > 0 and auction_item.buyout_price or nil
    local buyout_price_per_unit = buyout_price and Aux_Round(auction_item.buyout_price / stack_size)
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

function private.create_auction_record(index)
    local auction_item = Aux.info.auction_item(index, 'owner')
    if auction_item then
        tinsert(auction_records, private.create_record(auction_item))
    end
end

function private.create_bid_record(index)
    local auction_item = Aux.info.auction_item(index, 'bidder')
    if auction_item then
        tinsert(bid_records, private.create_record(auction_item))
    end
end


