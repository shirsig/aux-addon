select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Bids'

function aux.event.AUX_LOADED()
    aux.event_listener('AUCTION_BIDDER_LIST_UPDATE', function()
        locked = {}
        refresh = true
    end)
    aux.coro_thread(function()
        while true do
            local timestamp = GetTime()
            while GetTime() - timestamp < 1 do
                aux.coro_wait()
            end
            refresh = true
        end
    end)
end

function tab.OPEN()
    frame:Show()
end

function tab.CLOSE()
    listing:SetSelectedRecord()
    frame:Hide()
end

function M.scan_auctions()
    local auctions = {}
    for _, auction in scan.bidder_auctions() do
        tinsert(auctions, auction)
    end
    listing:SetDatabase(auctions)
end

function place_bid(buyout)
    local record = listing:GetSelection().record
    for i in scan.bidder_auctions() do
        if GetTime() - (locked[i] or 0) > .5 and scan_util.test('bidder', record, i) then
            local money = GetMoney()
            local amount = buyout and record.buyout_price or record.bid_price
            PlaceAuctionBid('bidder', i, amount)
            if money >= amount then -- TODO maybe try to reset it after errors instead
                locked[i] = GetTime()
            end
            return
        end
    end
end

function on_update()
    if refresh then
        refresh = false
        scan_auctions()
    end

    local selection = listing:GetSelection()
    if selection then
        if not selection.record.high_bidder then
            bid_button:Enable()
        else
            bid_button:Disable()
        end
        if selection.record.buyout_price > 0 then
            buyout_button:Enable()
        else
            buyout_button:Disable()
        end
    end
end