local private, public = {}, {}
Aux.auctions_frame = public

local auction_records
local selected_auction

function public.on_load()
    private.listing = Aux.listing.CreateScrollingTable(AuxAuctionsFrameListing)
    private.listing:SetColInfo({
        { name='Item', width=.4 },
        { name='Qty', width=.075, align='CENTER' },
        { name='Left', width=.075, align='CENTER' },
        { name='High Bid', width=.15, align='RIGHT' },
        { name='Start Price', width=.15, align='RIGHT' },
        { name='Buy', width=.15, align='RIGHT' },
    })
    private.listing:SetHandler('OnClick', function(table, row_data, column)
        private.on_row_click(row_data.record)
    end)
    private.listing:SetHandler('OnEnter', function(table, row_data, column)
        Aux.info.set_tooltip(row_data.record.itemstring, row_data.record.EnhTooltip_info, column.row, 'ANCHOR_RIGHT', 0, 0)
    end)
    private.listing:SetHandler('OnLeave', function(table, row_data, column)
        GameTooltip:Hide()
    end)

    do
        local status_bar = Aux.gui.status_bar(AuxAuctionsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 100)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Cancel')
        btn:Disable()
        private.cancel_button = btn
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 16)
        btn:SetPoint('TOPLEFT', private.cancel_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            public.scan_auctions()
        end)
    end
end

function private.update_listing()
    if not AuxAuctionsFrame:IsVisible() then
        return
    end

    local auction_rows = {}
    for i, auction_record in auction_records or {} do
        local historical_value = Aux.history.value(auction_record.item_key)
        tinsert(auction_rows, {
            cols = {
                { value='|c'..Aux.quality_color(auction_record.quality)..'['..auction_record.name..']'..'|r' },
                { value=auction_record.aux_quantity },
                { value=Aux.auction_listing.time_left(auction_record.duration) },
                { value=auction_record.high_bid > 0 and Aux.money.to_string(auction_record.high_bid, true, false) or RED_FONT_COLOR_CODE..'No Bids'..FONT_COLOR_CODE_CLOSE },
                { value=Aux.money.to_string(auction_record.start_price, true, false) },
                { value=auction_record.buyout_price > 0 and Aux.money.to_string(auction_record.buyout_price, true, false) or '---' },
                --                { value=Aux.auction_listing.percentage_historical(market_value and Aux.round(auction_record.unit_buyout_price/market_value * 100) or '---') },
            },
            record = auction_record,
        })
    end
    sort(auction_rows, function(a, b) return Aux.sort.multi_lt(a.record.name, b.record.name, a.record.search_signature, b.record.search_signature, tostring(a.record), tostring(b.record)) end)

    private.listing:SetData(auction_rows)
    private.listing:SetSelection(function(row) return row.record == selected_auction end)
end

function public.on_open()
    public.scan_auctions()
end

function public.on_close()
end

function public.scan_auctions()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    auction_records = {}
    selected_auction = nil
    private.update_listing()
    Aux.scan.start{
        type = 'owner',
        queries = {
            {
                start_page = 0,
            }
        },
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
        end,
        on_read_auction = function(auction_info)
            tinsert(auction_records, auction_info)
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
        local auction_info = Aux.info.auction(index, 'owner')
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

function private.find_auction_and_cancel(record)
    if not Aux.util.index_of(record, auction_records) then
        return
    end

    Aux.scan_util.find(record, private.status_bar, Aux.util.pass, private.record_remover(record), function(index)
        if Aux.util.index_of(record, auction_records) then
            CancelAuction(index)
            private.record_remover(record)()
        end
    end)
end

do
    local found_index

    function private.find_auction(record)
        if not Aux.util.index_of(record, auction_records) then
            return
        end

        found_index = nil

        Aux.scan_util.find(record, private.status_bar, Aux.util.pass, private.record_remover(record), function(index)

            found_index = index

            private.cancel_button:SetScript('OnClick', function()
                if private.test(record)(index) and Aux.util.index_of(record, auction_records) then
                    CancelAuction(index)
                    private.record_remover(record)()
                end
            end)
            private.cancel_button:Enable()

        end)
    end

    function public.on_update()
        if not private.cancel_button:IsEnabled() then
            return
        end

        if not found_index then
            private.cancel_button:Disable()
            return
        end

        if not selected_auction then
            private.cancel_button:Disable()
            return
        end

        if found_index and not private.test(selected_auction)(found_index) then
            private.cancel_button:Disable()
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
    if express_mode then
        selected_auction = nil
        private.find_auction_and_cancel(auction_record)
    else
        selected_auction = auction_record
        private.find_auction(auction_record)
    end
--    end
end


