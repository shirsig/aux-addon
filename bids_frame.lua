local private, public = {}, {}
Aux.bids_frame = public

local auction_records

function public.on_load()
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxBidsFrameListing, Aux.auction_listing.bids_config)
    private.listing:Show()
    private.listing:SetSort(1,2,3,4,5,6,7,8)
    private.listing:Clear()
    private.listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and private.listing:GetSelection().record == cell.row.data.record then
            if button == 'LeftButton' and private.buyout_button:IsEnabled() then
                private.buyout_button:Click()
            elseif button == 'RightButton' and private.bid_button:IsEnabled() then
                private.bid_button:Click()
            end
        end
    end)
    private.listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        private.find_auction(datum.record)
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

    private.listing:SetDatabase(auction_records)
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
    private.update_listing()
    Aux.scan.start{
        type = 'bidder',
        queries = {{ blizzard_query = {} }},
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
        end,
        on_auction = function(auction_record)
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
        private.listing:RemoveAuctionRecord(record)
    end
end

do
    local scan_id
    local IDLE, SEARCHING, FOUND = {}, {}, {}
    local state = IDLE
    local found_index

    function private.find_auction(record)
        if not private.listing:ContainsRecord(record) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            private.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                private.record_remover(record)()
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    private.bid_button:SetScript('OnClick', function()
                        if private.test(record)(index) and private.listing:ContainsRecord(record) then
                            Aux.place_bid('bidder', index, record.bid_price, private.record_remover(record))
                        end
                    end)
                    private.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    private.buyout_button:SetScript('OnClick', function()
                        if private.test(record)(index) and private.listing:ContainsRecord(record) then
                            Aux.place_bid('bidder', index, record.buyout_price, private.record_remover(record))
                        end
                    end)
                    private.buyout_button:Enable()
                end
            end
        )
    end

    function public.on_update()
        if state == IDLE or state == SEARCHING then
            private.buyout_button:Disable()
            private.bid_button:Disable()
        end

        if state == SEARCHING then
            return
        end

        local selection = private.listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            private.find_auction(selection.record)
        elseif state == FOUND and not private.test(selection.record)(found_index) then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            if not Aux.bid_in_progress() then
                state = IDLE
            end
        end
    end
end