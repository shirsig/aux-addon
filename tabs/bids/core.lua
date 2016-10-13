module 'aux.tabs.bids'

include 'green_t'
include 'aux'

local info = require 'aux.util.info'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

TAB 'Bids'

auction_records = t

function OPEN()
    frame:Show()
    scan_bids()
end

function CLOSE()
    frame:Hide()
end

function update_listing()
	if not ACTIVE then return end
    listing:SetDatabase(auction_records)
end

function public.scan_bids()

    status_bar:update_status(0,0)
    status_bar:set_text'Scanning auctions...'

    wipe(auction_records)
    update_listing()
    scan.start{
        type = 'bidder',
        queries = {{ blizzard_query=t }},
        on_page_loaded = function(page, total_pages)
            status_bar:update_status(100 * (page - 1) / total_pages, 0)
            status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            status_bar:update_status(100, 100)
            status_bar:set_text'Scan complete'
            update_listing()
        end,
        on_abort = function()
            status_bar:update_status(100, 100)
            status_bar:set_text'Scan aborted'
        end,
    }
end

function test(record)
    return function(index)
        local auction_info = info.auction(index, 'bidder')
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

do
    local scan_id = 0
    local IDLE, SEARCHING, FOUND = 1, 2, 3
    local state = IDLE
    local found_index

    function find_auction(record)
        if not listing:ContainsRecord(record) then return end

        scan.abort(scan_id)
        state = SEARCHING
        scan_id = scan_util.find(
            record,
            status_bar,
            function() state = IDLE end,
            function()
                state = IDLE
                listing:RemoveAuctionRecord(record)
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    bid_button:SetScript('OnClick', function()
                        if test(record)(index) and listing:ContainsRecord(record) then
                            place_bid('bidder', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                info.bid_update(record)
                                listing:SetDatabase()
                            end or papply(listing.RemoveAuctionRecord, listing, record))
                        end
                    end)
                    bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    buyout_button:SetScript('OnClick', function()
                        if test(record)(index) and listing:ContainsRecord(record) then
                            place_bid('bidder', index, record.buyout_price, papply(listing.RemoveAuctionRecord, listing, record))
                        end
                    end)
                    buyout_button:Enable()
                end
            end
        )
    end

    function on_update()
        if state == IDLE or state == SEARCHING then
            buyout_button:Disable()
            bid_button:Disable()
        end

        if state == SEARCHING then return end

        local selection = listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            find_auction(selection.record)
        elseif state == FOUND and not test(selection.record)(found_index) then
            buyout_button:Disable()
            bid_button:Disable()
            if not bid_in_progress then state = IDLE end
        end
    end
end