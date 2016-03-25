local private, public = {}, {}
Aux.auctions_frame = public

local auction_records

function public.on_load()
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxAuctionsFrameListing, Aux.auction_listing.auctions_config)
    private.listing:Show()
    private.listing:SetSort(7)
    private.listing:Clear()
    private.listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and private.listing:GetSelection().record == cell.row.data.record and private.cancel_button:IsEnabled() then
            private.cancel_button:Click()
        end
    end)
    private.listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        private.find_auction(datum.record)
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

    private.listing:SetDatabase(auction_records)
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
    private.update_listing()
    Aux.scan.start{
        type = 'owner',
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
        local auction_info = Aux.info.auction(index, 'owner')
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

function private.record_remover(record)
    return function()
        private.listing:RemoveAuctionRecord(record)
    end
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

                private.cancel_button:SetScript('OnClick', function()
                    if private.test(record)(index) and private.listing:ContainsRecord(record) then
                        CancelAuction(index)
                        private.record_remover(record)()
                    end
                end)
                private.cancel_button:Enable()
            end
        )
    end

    function public.on_update()
        if state == IDLE or state == SEARCHING then
            private.cancel_button:Disable()
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
            private.cancel_button:Disable()
--            if not Aux.bid_in_progress() then
                state = IDLE
--            end
        end
    end
end