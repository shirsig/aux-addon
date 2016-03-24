local private, public = {}, {}
Aux.bids_frame = public

local refresh
local auction_records
local selected_auction

function public.on_load()
--    private.listing:SetHandler('OnClick', function(table, row_data, column, button)
--        if button == 'LeftButton' then
--            private.on_row_click(row_data.record)
--        elseif button == 'RightButton' then
--            Aux.tab_group:set_tab(1)
--            Aux.search_frame.start_search(strlower(Aux.info.item(this.row.data.record.item_id).name)..'/exact')
--        end
--    end)
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxBidsFrameListing, Aux.auction_listing.bids_config)
    private.listing:Show()
    private.listing:SetSort(9)
    private.listing:Clear()
    private.listing:SetHandler('OnCellClick', function(cell, button)
--        if IsAltKeyDown() and private.listing:GetSelection().record == cell.row.data.record then
--            if button == 'LeftButton' and private.buyout_button:IsEnabled() then
--                private.buyout_button:Click()
--                return
--            elseif button == 'RightButton' and private.bid_button:IsEnabled() then
--                private.bid_button:Click()
--                return
--            end
--        end
    end)
    private.listing:SetHandler('OnSelectionChanged', function(rt, datum)
--        if not datum then return end
--        private.find_auction(datum.record)
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
    selected_auction = nil
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

    Aux.scan_util.find(record, private.status_bar, Aux.util.pass, private.record_remover(record), function(index)
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

        Aux.scan_util.find(record, private.status_bar, Aux.util.pass, private.record_remover(record), function(index)

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
        selected_auction = nil
        private.find_auction_and_bid(auction_record, buyout_mode)
    else
        selected_auction = auction_record
        private.find_auction(auction_record)
    end
--    end
end