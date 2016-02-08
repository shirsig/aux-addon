local private, public = {}, {}
Aux.bids_frame = public

local refresh
local auction_records
local selected_auction

function public.on_load()
    private.listing = Aux.listing.CreateScrollingTable(AuxBidsFrameListing)
    private.listing:SetColInfo({
        { name='Item', width=.275 },
        { name='Qty', width=.05, align='CENTER' },
        { name='Status', width=.125, align='CENTER' },
        { name='Left', width=.05, align='CENTER' },
        { name='Seller', width=.125, align='CENTER' },
        { name='Your Bid', width=.125, align='RIGHT' },
        { name='Bid', width=.125, align='RIGHT' },
        { name='Buy', width=.125, align='RIGHT' },
    })
    private.listing:SetHandler('OnClick', function(table, row_data, column)
        private.on_row_click(row_data.record)
    end)

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
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.bid_button, 'TOPRIGHT', 5, 0)
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
    for i, auction_record in auction_records or {} do
        local status
        if auction_record.high_bidder then
            status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
        else
            status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
        end
        local market_value = Aux.history.value(auction_record.item_key)
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
    sort(auction_rows, function(a, b) return Aux.sort.multi_lt(a.record.name, b.record.name, a.record.search_signature, b.record.search_signature, tostring(a.record), tostring(b.record)) end)

    private.listing:SetData(auction_rows)
    private.listing:SetSelection(function(row) return row.record == selected_auction end)
end

function public.on_open()
    public.scan_bids()
end

function public.on_close()
end

function public.scan_bids()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    auction_records = {}
    selected_auction = nil
    private.update_listing()
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
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
            private.update_listing()
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
        end,
    }
end

function private.test(record)
    return function(index)
        local auction_info = Aux.info.auction(index, 'bidder')
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

function private.record_remover(record)
    return function()
        local index = Aux.util.index_of(record, auction_records)
        if index then
            tremove(auction_records, index)
        end
        private.update_listing()
    end
end

function private.find_auction_and_bid(record, buyout_mode)
    if not Aux.util.index_of(record, auction_records) or (buyout_mode and not record.buyout_price) or (not buyout_mode and record.high_bidder) or Aux.is_player(record.owner) then
        return
    end

    Aux.scan_util.find(private.test(record), record.query, record.page, private.status_bar, private.record_remover(record), function(index)
        if Aux.util.index_of(record, auction_records) then
            Aux.place_bid('bidder', index, buyout_mode and record.buyout_price or record.bid_price, private.record_remover(record))
        end
    end)
end

do
    local found_index

    function private.find_auction(record)
        if not Aux.util.index_of(record, auction_records) or Aux.is_player(record.owner) then
            return
        end

        found_index = nil

        Aux.scan_util.find(private.test(record), record.query, record.page, private.status_bar, private.record_remover(record), function(index)

            found_index = index

            if not record.high_bidder then
                private.bid_button:SetScript('OnClick', function()
                    if private.test(record)(index) and Aux.util.index_of(record, auction_records) then
                        Aux.place_bid('bidder', index, record.bid_price, private.record_remover(record))
                    end
                end)
                private.bid_button:Enable()
            end

            if record.buyout_price > 0 then
                private.buyout_button:SetScript('OnClick', function()
                    if private.test(record)(index) and Aux.util.index_of(record, auction_records) then
                        Aux.place_bid('bidder', index, record.buyout_price, private.record_remover(record))
                    end
                end)
                private.buyout_button:Enable()
            end
        end)
    end

    function public.on_update()
        if not (private.buyout_button:IsEnabled() or private.bid_button:IsEnabled()) then
            return
        end

        if not found_index then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            return
        end

        if not selected_auction then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            return
        end

        if found_index and not private.test(selected_auction)(found_index) then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            private.find_auction(selected_auction)
        end
    end
end

function private.on_row_click(auction_record)

--    if IsControlKeyDown() then
--        DressUpItemLink(datum.hyperlink)
--    elseif IsShiftKeyDown() then
--        if ChatFrameEditBox:IsVisible() then
--            ChatFrameEditBox:Insert(datum.hyperlink)
--        end
--    else
    local express_mode = IsAltKeyDown()
    local buyout_mode = express_mode and arg1 == 'LeftButton'
    if express_mode then
        private.find_auction_and_bid(auction_record, buyout_mode)
    else
        selected_auction = auction_record
        private.find_auction(auction_record)
    end
--    end
end