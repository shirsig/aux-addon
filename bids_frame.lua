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

    private.listing = Aux.listing.CreateScrollingTable(AuxBidsFrameListing)
    private.listing:SetColInfo({
        { name='Item', width=.3 },
        { name='Qty', width=.1, align='CENTER' },
        { name='Status', width=.1, align='CENTER' },
        { name='Left', width=.1, align='CENTER' },
        { name='Seller', width=.1, align='CENTER' },
        { name='Your Bid', width=.1, align='RIGHT' },
        { name='Bid', width=.1, align='RIGHT' },
        { name='Buy', width=.1, align='RIGHT' },
    })
    private.listing:SetHandler('OnClick', function(table, row_data, column)
        private.on_row_click(row_data.record)
    end)

    private.bid_listing_config = {
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function(sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function(sheet, row_index)
            GameTooltip:Hide()
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
    }

    do
        local status_bar = Aux.gui.status_bar(AuxBidsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
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

function private.update_listing()
    if not AuxBidsFrame:IsVisible() then
        return
    end

    local auction_rows = {}
    for i, auction_record in bid_records or {} do
        local status
        if auction_record.high_bidder then
            status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
        else
            status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
        end
        local market_value = Aux.history.market_value(auction_record.item_key)
        tinsert(auction_rows, {
            cols = {
                { value='|c'..Aux.quality_color(auction_record.quality)..'['..auction_record.name..']'..'|r' },
                { value=auction_record.aux_quantity },
                { value=status },
                { value=Aux.auction_listing.time_left(auction_record.duration) },
                { value=auction_record.owner },
                { value=auction_record.high_bidder and Aux.money.to_string(auction_record.high_bid, true, false) or '---' },
                { value=Aux.money.to_string(auction_record.bid_price, true, false) },
                { value=auction_record.buyout_price > 0 and Aux.money.to_string(auction_record.buyout_price, true, false) or '---' },
                --                { value=Aux.auction_listing.percentage_market(market_value and Aux.round(auction_record.unit_buyout_price/market_value * 100) or '---') },
            },
            record = auction_record,
        })
    end
    sort(auction_rows, function(a, b) return a.record.unit_buyout_price < b.record.unit_buyout_price end)

    private.listing:SetData(auction_rows)
    private.listing:SetSelection(function(row) return row.record == selected_auction end)
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
        on_read_auction = function(auction_record)
            tinsert(bid_records, auction_record)
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

function private.process_request(entry, express_mode, buyout_mode)

    if entry.gone or (buyout_mode and not entry.buyout_price) or (express_mode and not buyout_mode and entry.high_bidder) or entry.owner == UnitName('player') then
        return
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        local auction_record = Aux.info.auction(index, 'bidder')
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