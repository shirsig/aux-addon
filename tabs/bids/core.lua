select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Bids'

auction_records = {}

function aux.handle.LOAD()
    aux.event_listener('AUCTION_BIDDER_LIST_UPDATE', function()
        refresh = true
    end)
end

function tab.OPEN()
    frame:Show()
end

function tab.CLOSE()
    listing:SetSelectedRecord()
    frame:Hide()
end

function update_listing()
    listing:SetDatabase(auction_records)
end

function M.scan_auctions()

    status_bar:update_status(0, 0)
    status_bar:set_text('Scanning auctions...')

    aux.wipe(auction_records)
    update_listing()
    scan.start{
        type = 'bidder',
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            status_bar:update_status(1, 1)
            status_bar:set_text('Scan complete')
            update_listing()
        end,
        on_abort = function()
            status_bar:update_status(1, 1)
            status_bar:set_text('Scan aborted')
        end,
    }
end

function perform_bid()
    local record = listing:GetSelection().record
    if scan_util.test(record, record.index) and listing:ContainsRecord(record) then
        aux.place_bid('bidder', record.index, record.bid_price)
    end
end

function perform_buyout()
    local record = listing:GetSelection().record
    if scan_util.test(record, record.index) and listing:ContainsRecord(record) then
        aux.place_bid('bidder', record.index, record.buyout_price)
    end
end

function on_update()
    if refresh then
        refresh = false
        scan_auctions()
    end

    local selection = listing:GetSelection()
    if selection and not selection.record.high_bidder then
        bid_button:Enable()
    else
        bid_button:Disable()
    end
    if selection and selection.record.buyout_price > 0 then
        buyout_button:Enable()
    else
        buyout_button:Disable()
    end
end