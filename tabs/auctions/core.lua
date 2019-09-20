select(2, ...) 'aux.tabs.auctions'

local T = require 'T'
local aux = require 'aux'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Auctions'

auction_records = T.acquire()

function aux.handle.LOAD()
    aux.event_listener('AUCTION_OWNED_LIST_UPDATE', function()
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

    T.wipe(auction_records)
    update_listing()
    scan.start{
        type = 'owner',
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

function cancel_auction()
    local record = listing:GetSelection().record
    if scan_util.test(record, record.index) then
        aux.cancel_auction(record.index)
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