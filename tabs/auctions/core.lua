module 'aux.tabs.auctions'

include 'aux'

local T = require 'T'

local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

local tab = TAB 'Auctions'

auction_records = T.acquire()

function tab.OPEN()
    frame:Show()
    scan_auctions()
end

function tab.CLOSE()
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
        queries = {{blizzard_query = T.acquire()}},
        on_page_loaded = function(page, total_pages)
            status_bar:update_status(page / total_pages, 0)
            status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
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

do
    local scan_id = 0
    local IDLE, SEARCHING, FOUND = T.acquire(), T.acquire(), T.acquire()
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
            function() state = IDLE; listing:RemoveAuctionRecord(record) end,
            function(index)
                state = FOUND
                found_index = index

                cancel_button:SetScript('OnClick', function()
                    if scan_util.test(record, index) and listing:ContainsRecord(record) then
                        cancel_auction(index, function() listing:RemoveAuctionRecord(record) end)
                    end
                end)
                cancel_button:Enable()
            end
        )
    end

    function on_update()
        if state == IDLE or state == SEARCHING then
            cancel_button:Disable()
        end

        if state == SEARCHING then return end

        local selection = listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            find_auction(selection.record)
        elseif state == FOUND and not scan_util.test(selection.record, found_index) then
            cancel_button:Disable()
            if not cancel_in_progress() then state = IDLE end
        end
    end
end