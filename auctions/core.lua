local private, public = {}, {}
Aux.auctions_frame = public

local auction_records

function public.on_load()
    public.create_frames(private, public)
end

function private.update_listing()
    if not AuxAuctionsFrame:IsVisible() then
        return
    end

    private.listing:SetDatabase(auction_records)
end

function public.on_open()
    public.scan_auctions()
end

function public.on_close()
end

function public.scan_auctions()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    auction_records = {}
    private.update_listing()
    Aux.scan.start{
        type = 'owner',
        queries = {{ blizzard_query = {} }},
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page - 1) / total_pages, 0)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
            private.update_listing()
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
        end,
    }
end

function private.test(record)
    return function(index)
        local auction_info = Aux.info.auction(index, 'owner')
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

function private.record_remover(record)
    return function()
        private.listing:RemoveAuctionRecord(record)
    end
end

do
    local scan_id
    local IDLE, SEARCHING, FOUND = {}, {}, {}
    local state = IDLE
    local found_index

    function private.find_auction(record)
        if not private.listing:ContainsRecord(record) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            private.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                private.record_remover(record)()
            end,
            function(index)
                state = FOUND
                found_index = index

                private.cancel_button:SetScript('OnClick', function()
                    if private.test(record)(index) and private.listing:ContainsRecord(record) then
                        Aux.cancel_auction(index, private.record_remover(record))
                    end
                end)
                private.cancel_button:Enable()
            end
        )
    end

    function public.on_update()
        if state == IDLE or state == SEARCHING then
            private.cancel_button:Disable()
        end

        if state == SEARCHING then
            return
        end

        local selection = private.listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            private.find_auction(selection.record)
        elseif state == FOUND and not private.test(selection.record)(found_index) then
            private.cancel_button:Disable()
--            if not Aux.bid_in_progress() then
                state = IDLE
--            end
        end
    end
end