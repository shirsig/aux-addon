local m, public, private = aux.tab(4, 'Bids', 'bids_tab')

private.auction_records = nil

function m.OPEN()
    m.frame:Show()
    m.scan_bids()
end

function m.CLOSE()
    m.frame:Hide()
end

function private.update_listing()
    if not m:ACTIVE() then
        return
    end

    m.listing:SetDatabase(m.auction_records)
end

function public.scan_bids()

    m.status_bar:update_status(0,0)
    m.status_bar:set_text('Scanning auctions...')

    m.auction_records = {}
    m.update_listing()
    aux.scan.start{
        type = 'bidder',
        queries = {{ blizzard_query = {} }},
        on_page_loaded = function(page, total_pages)
            m.status_bar:update_status(100 * (page - 1) / total_pages, 0)
            m.status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(m.auction_records, auction_record)
        end,
        on_complete = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Scan complete')
            m.update_listing()
        end,
        on_abort = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Scan aborted')
        end,
    }
end

function private.test(record)
    return function(index)
        local auction_info = aux.info.auction(index, 'bidder')
        return auction_info and auction_info.search_signature == record.search_signature
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

        aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = aux.scan_util.find(
            record,
            m.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                m.listing:RemoveAuctionRecord(record)
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    m.bid_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.listing:ContainsRecord(record) then
                            aux.place_bid('bidder', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                aux.info.bid_update(record)
                                m.listing:SetDatabase()
                            end or aux._(m.listing.RemoveAuctionRecord, m.listing, record))
                        end
                    end)
                    m.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    m.buyout_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.listing:ContainsRecord(record) then
                            aux.place_bid('bidder', index, record.buyout_price, aux._(m.listing.RemoveAuctionRecord, m.listing, record))
                        end
                    end)
                    m.buyout_button:Enable()
                end
            end
        )
    end

    function private.on_update()
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
            if not aux.bid_in_progress() then
                state = IDLE
            end
        end
    end
end