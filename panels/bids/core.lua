local m, private, public = Aux.tab(4, 'bids_frame')

local auction_records

function public.FRAMES(f)
    private.create_frames = f
end

function public.LOAD()
    m.create_frames(m, private, public)
end

function public.OPEN()
    m.scan_bids()
end

function public.CLOSE()
end

function private.update_listing()
    if not AuxBidsFrame:IsVisible() then
        return
    end

    m.listing:SetDatabase(auction_records)
end

function public.scan_bids()

    m.status_bar:update_status(0,0)
    m.status_bar:set_text('Scanning auctions...')

    auction_records = {}
    m.update_listing()
    Aux.scan.start{
        type = 'bidder',
        queries = {{ blizzard_query = {} }},
        on_page_loaded = function(page, total_pages)
            m.status_bar:update_status(100 * (page - 1) / total_pages, 0)
            m.status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Done Scanning')
            m.update_listing()
        end,
        on_abort = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Done Scanning')
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
        m.listing:RemoveAuctionRecord(record)
    end
end

do
    local scan_id = 0
    local IDLE, SEARCHING, FOUND = {}, {}, {}
    local state = IDLE
    local found_index

    function private.find_auction(record)
        if not m.listing:ContainsRecord(record) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            m.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                m.record_remover(record)()
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    m.bid_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.listing:ContainsRecord(record) then
                            Aux.place_bid('bidder', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                Aux.info.bid_update(record)
                                m.listing:SetDatabase()
                            end or m.record_remover(record))
                        end
                    end)
                    m.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    m.buyout_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.listing:ContainsRecord(record) then
                            Aux.place_bid('bidder', index, record.buyout_price, m.record_remover(record))
                        end
                    end)
                    m.buyout_button:Enable()
                end
            end
        )
    end

    function public.on_update()
        if state == IDLE or state == SEARCHING then
            m.buyout_button:Disable()
            m.bid_button:Disable()
        end

        if state == SEARCHING then
            return
        end

        local selection = m.listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            m.find_auction(selection.record)
        elseif state == FOUND and not m.test(selection.record)(found_index) then
            m.buyout_button:Disable()
            m.bid_button:Disable()
            if not Aux.bid_in_progress() then
                state = IDLE
            end
        end
    end
end