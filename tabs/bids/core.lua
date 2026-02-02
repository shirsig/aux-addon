select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Bids'
local bought_count = 0

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
    bought_count = 0
    update_bought_count_display()
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
            local on_success = function()
                bought_count = bought_count + record.quantity
                update_bought_count_display()
            end
            if money >= amount then -- TODO maybe try to reset it after errors instead
                locked[i] = GetTime()
                aux.place_bid('bidder', i, amount, on_success)
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
        if not CanSendAuctionQuery() then
            bid_button:Disable()
            buyout_button:Disable()
            return
        end
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
        -- Update quantity label
        if quantity_label then
            quantity_label:SetText('+' .. selection.record.count)
        end
    end
end

function update_bought_count_display()
    if bought_count_label then
        bought_count_label:SetText(bought_count > 0 and (bought_count .. ' bought') or '')
    end
    DEFAULT_CHAT_FRAME:AddMessage('<aux> Gekauft: ' .. bought_count)
end
