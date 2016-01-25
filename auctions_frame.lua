local private, public = {}, {}
Aux.auctions_frame = public

local auction_records


function public.on_load()
    private.auction_listing_config = {
        frame = AuxAuctionsFrameListingAuctionListing,
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_auction_click(sheet, sheet.data[data_index])
        end,
        on_row_update = function(sheet, row_index)
            if IsControlKeyDown() then
                ShowInspectCursor()
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
                    private.auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Qty',
                width = 25,
                comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.aux_quantity)
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
                title = 'Current Bid',
                width = 80,
                comparator = function(auction1, auction2) return Aux.util.compare(auction1.current_bid, auction2.current_bid, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, auction)
                    cell.text:SetText(auction.current_bid and Aux.util.money_string(auction.current_bid) or RED_FONT_COLOR_CODE..'No Bids'..FONT_COLOR_CODE_CLOSE)
                    private.auction_alpha_setter(cell, auction)
                end,
            },
            Aux.listing_util.money_column('Min Bid', function(entry) return entry.min_bid end),
            Aux.listing_util.money_column('Buy', function(entry) return entry.buyout_price end),
        },
        sort_order = {{ column = 1, order = 'ascending' }},
    }

    private.listing =  Aux.sheet.create(private.auction_listing_config)
    do
        local status_bar = Aux.gui.status_bar(AuxAuctionsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxAuctionsFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 15)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Cancel')
        btn:Disable()
        private.cancel_button = btn
    end
end

function public.on_open()
    public.update_auction_records()
    public.update_listing()
end

function public.on_close()
end

function private.auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function public.update_auction_records()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    local current_page

    auction_records = {}
    Aux.scan.start{
        type = 'owner',
        page = 0,
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(string.format('Scanning (Page %d / %d)', page + 1, total_pages))
            current_page = page
        end,
        on_read_auction = function(auction_info)
            tinsert(auction_records, private.create_auction_record(auction_info, current_page))
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
    AuxAuctionsFrameListingAuctionListing:Show()
    Aux.sheet.populate(private.listing, auction_records)
    AuxAuctionsFrameListing:SetWidth(AuxAuctionsFrameListingAuctionListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxAuctionsFrameListing:GetWidth() + 15)
end

function private.create_auction_record(auction_info, page)

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
        signature = Aux.auction_signature(auction_info.hyperlink, aux_quantity, bid, auction_info.buyout_price, auction_info.duration),

        name = auction_info.name,
        tooltip = auction_info.tooltip,
        aux_quantity = aux_quantity,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        bid = bid,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        current_bid = auction_info.current_bid > 0 and auction_info.current_bid or nil,
        min_bid = auction_info.min_bid,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function private.find_auction(entry, express_mode)

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        return private.create_auction_record(Aux.info.auction(index, 'owner')).signature == entry.signature
    end

    Aux.scan_util.find_auction('owner', test, {}, entry.page, private.status_bar, function(index)

        if not index then
            entry.gone = true
            private.listing:clear_selection()
            refresh = true
            return
        end

        if not test(index) then
            return private.find_auction(entry, express_mode) -- try again
        end

        if express_mode then
            CancelAuction(index)
            entry.gone = true

            private.listing:clear_selection()
            refresh = true
        else
            private.cancel_button:SetScript('OnClick', function()

                if not test(index) then
                    private.cancel_button:Disable()
                    return private.find_auction(entry, express_mode) -- try again
                end

                CancelAuction(index)
                entry.gone = true

                private.cancel_button:Disable()
                private.listing:clear_selection()
                refresh = true -- TODO
            end)
            private.cancel_button:Enable()
        end
    end)
end

--function private.find_auction(entry, express_mode)
--
--
--        next_page = function(page, total_pages)
--            if not page or page == entry.page then -- TODO
--                return entry.page - 1
--            end
--        end
--
--end

function public.on_auction_click(listing, auction_record)

    local express_mode = IsAltKeyDown()

    if IsControlKeyDown() then
        DressUpItemLink(auction_record.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(auction_record.hyperlink)
        end
    elseif not auction_record.gone then
        if not express_mode then
            private.cancel_button:Disable()
            listing:clear_selection()
            listing:select(auction_record)
        end
        private.find_auction(auction_record, express_mode)
    end
end


