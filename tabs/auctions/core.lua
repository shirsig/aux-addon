local m, public, private = aux.tab(3, 'Auctions', 'auctions_tab')

private.auction_records = nil

function m.OPEN()
    m.frame:Show()
    m.scan_auctions()
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

function public.scan_auctions()

    m.status_bar:update_status(0,0)
    m.status_bar:set_text('Scanning auctions...')

    m.auction_records = {}
    m.update_listing()
    aux.scan.start{
        type = 'owner',
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
        local auction_info = aux.info.auction(index, 'owner')
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

                m.cancel_button:SetScript('OnClick', function()
                    if m.test(record)(index) and m.listing:ContainsRecord(record) then
                        aux.cancel_auction(index, aux._(m.listing.RemoveAuctionRecord, m.listing, record))
                    end
                end)
                m.cancel_button:Enable()
            end
        )
    end

    function private.on_update()
        if state == IDLE or state == SEARCHING then
            m.cancel_button:Disable()
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
            m.cancel_button:Disable()
            if not aux.cancel_in_progress() then
                state = IDLE
            end
        end
    end
end