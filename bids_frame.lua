local private, public = {}, {}
Aux.bids_frame = public

local refresh
local bid_records
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

function public.on_load()
    private.bid_listing_config = {
        frame = AuxBidsFrameListingBidListing,
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
            Aux.listing_util.duration_column(function(entry) return entry.duration end),
            Aux.listing_util.owner_column(function(datum) return datum.owner end),
            Aux.listing_util.money_column('Your Bid', function(entry) return entry.your_bid end),
            Aux.listing_util.money_column('Bid', function(entry) return entry.bid_price end),
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
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.bid_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            public.scan_bids()
        end)
    end
end

function public.on_open()
    public.scan_bids()
    refresh = true
end

function public.on_close()
    private.clear_selection()
end

function public.scan_bids()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    bid_records = {}
    Aux.scan.start{
        queries = {
            {
                type = 'bidder',
                start_page = 0,
            }
        },
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
        end,
        on_read_auction = function(auction_info)
            tinsert(bid_records, private.create_auction_record(auction_info))
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
            refresh = true
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
        end,
    }
end

function private.update_listing()
    if not AuxBidsFrame:IsVisible() then
        return
    end

    AuxBidsFrameListingBidListing:Show()
    Aux.sheet.populate(private.listing, bid_records)
    AuxBidsFrameListing:SetWidth(AuxBidsFrameListingBidListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxBidsFrameListing:GetWidth() + 15)
end

function private.create_auction_record(auction_info)

    local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil

    local status
    if auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
    end

    return {
        query = auction_info.query,
        page = auction_info.page,

        item_id = auction_info.item_id,
        suffix_id = auction_info.suffix_id,
        unique_id = auction_info.unique_id,
        enchant_id = auction_info.enchant_id,

        item_id = auction_info.item_id,
        item_key = auction_info.item_key,
        signature = auction_info.signature,

        name = auction_info.name,
        tooltip = auction_info.tooltip,
        aux_quantity = auction_info.aux_quantity,
        buyout_price = buyout_price,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        bid_price = auction_info.bid_price,
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        your_bid = auction_info.high_bidder and auction_info.high_bid,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function private.process_request(entry, express_mode, buyout_mode)

    if entry.gone or (buyout_mode and not entry.buyout_price) or (express_mode and not buyout_mode and entry.high_bidder) or entry.owner == UnitName('player') then
        return
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        local auction_record = private.create_auction_record(Aux.info.auction(index, 'bidder'))
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
                Aux.place_bid('bidder', index, buyout_mode and entry.buyout_price or entry.bid_price, remove_entry)
            end
        end)
    else
        private.select_auction(entry)

        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)

            if not entry.high_bidder then
                private.bid_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('bidder', index, entry.bid_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.bid_button:Enable()
            end

            if entry.buyout_price then
                private.buyout_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('bidder', index, entry.buyout_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.buyout_button:Enable()
            end
        end)
    end
end

function private.on_row_click(datum)

    if IsControlKeyDown() then
        DressUpItemLink(datum.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(datum.hyperlink)
        end
    else
        local express_mode = IsAltKeyDown()
        local buyout_mode = express_mode and arg1 == 'LeftButton'
        private.process_request(datum, express_mode, buyout_mode)
    end
end

function public.on_update()
    if refresh then
        refresh = false
        private.update_listing()
    end
end