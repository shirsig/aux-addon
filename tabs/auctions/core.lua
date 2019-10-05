select(2, ...) 'aux.tabs.auctions'

local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Auctions'

function aux.event.AUX_LOADED()
    aux.event_listener('AUCTION_OWNED_LIST_UPDATE', function()
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
    for _, auction in scan.owner_auctions() do
        tinsert(auctions, auction)
    end
    listing:SetDatabase(auctions)
end

function cancel_auction()
    local record = listing:GetSelection().record
    for i in scan.owner_auctions() do
        if GetTime() - (locked[i] or 0) > .5 and scan_util.test('owner', record, i) then
            CancelAuction(i)
            locked[i] = GetTime()
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
    if selection and selection.record.sale_status == 0 then
        cancel_button:Enable()
    else
        cancel_button:Disable()
    end
end