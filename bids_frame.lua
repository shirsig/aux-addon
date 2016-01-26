local private, public = {}, {}
Aux.bids_frame = public

local bid_records

function public.on_load()
    private.bid_listing_config = {
        frame = AuxBidsFrameListingBidListing,
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_bid_click(sheet.data[data_index])
        end,
        on_row_enter = function (sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function (sheet, row_index)
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
            row:SetAlpha(datum.gone and 0.3 or 1)
            row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, nil, datum.enchant_id)
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
                end,
            },
            {
                title = 'Qty',
                width = 25,
                comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.aux_quantity)
                end,
            },
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
            Aux.listing_util.money_column('Your Bid', function(entry) return entry.current_bid end),
            Aux.listing_util.money_column('Buy', function(entry) return entry.buyout_price end),
        },
        sort_order = {{ column = 1, order = 'ascending' }},
    }

    private.listing = Aux.sheet.create(private.bid_listing_config)
    do
        local status_bar = Aux.gui.status_bar(AuxBidsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxBidsFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 15)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 15)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
end

function public.on_open()
    public.update_bid_records()
    public.update_listing()
end

function public.on_close()
    private.listing:clear_selection()
    private.buyout_button:Disable()
    private.bid_button:Disable()
end

function public.update_bid_records()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    local current_page

    bid_records = {}
    Aux.scan.start{
        type = 'bidder',
        page = 0,
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
            current_page = page
        end,
        on_read_auction = function(auction_info)
            tinsert(bid_records, private.create_bid_record(auction_info, current_page))
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
            public.update_listing()
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
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
    AuxBidsFrameListingBidListing:Show()
    Aux.sheet.populate(private.listing, bid_records)
    AuxBidsFrameListing:SetWidth(AuxBidsFrameListingBidListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxBidsFrameListing:GetWidth() + 15)
end

function private.create_bid_record(auction_info, page)

    local aux_quantity = auction_info.charges or auction_info.count
    local bid = (auction_info.current_bid > 0 and auction_info.current_bid or auction_info.min_bid) + auction_info.min_increment
    local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
    local buyout_price_per_unit = buyout_price and Aux.round(auction_info.buyout_price / aux_quantity)

    local status
    if auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
    end

    return {
        page = page,

        item_id = auction_info.item_id,
        key = auction_info.item_signature,
        signature = Aux.auction_signature(auction_info.hyperlink, aux_quantity, bid, auction_info.buyout_price),

        name = auction_info.name,
        tooltip = auction_info.tooltip,
        aux_quantity = aux_quantity,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        bid = bid,
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        current_bid = auction_info.current_bid > 0 and auction_info.current_bid or nil,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function private.find_auction(entry, express_mode, buyout_mode)

    if buyout_mode and not entry.buyout_price then
        return
    end

    local amount
    if buyout_mode then
        amount = entry.buyout_price
    else
        amount = entry.bid
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        return private.create_bid_record(Aux.info.auction(index, 'bidder')).signature == entry.signature
    end

    Aux.scan_util.find_auction('bidder', test, {}, entry.page, private.status_bar, function(index)

        if not index then
            entry.gone = true
            private.listing:clear_selection()
            refresh = true
            return
        end

        if not test(index) then
            return private.find_auction(entry, express_mode, buyout_mode) -- try again
        end

        if express_mode then
            if Aux.bid_lock then
                return
            end

            if GetMoney() >= amount then
                entry.gone = true
            end
            Aux.place_bid('bidder', index, amount)

            private.listing:clear_selection()
            refresh = true
        else
            private.buyout_button:SetScript('OnClick', function()
                if Aux.bid_lock then
                    return
                end

                if not test(index) then
                    private.buyout_button:Disable()
                    private.bid_button:Disable()
                    return private.find_auction(entry, express_mode, buyout_mode) -- try again
                end

                if GetMoney() >= amount then
                    entry.gone = true
                end
                Aux.place_bid('bidder', index, entry.buyout_price)

                private.buyout_button:Disable()
                private.bid_button:Disable()
                private.listing:clear_selection()
                refresh = true
            end)
            private.buyout_button:Enable()
            private.bid_button:Enable()
        end
    end)
end

function public.on_bid_click(bid_record)

    local express_mode = IsAltKeyDown()
    local buyout_mode = express_mode and arg1 == 'LeftButton'

    if IsControlKeyDown() then
        DressUpItemLink(bid_record.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(bid_record.hyperlink)
        end
    elseif not bid_record.gone then
        if not express_mode then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            private.listing:clear_selection()
            private.listing:select(bid_record)
        end
        private.find_auction(bid_record, express_mode, buyout_mode)
    end
end