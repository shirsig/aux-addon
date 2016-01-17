local private, public = {}, {}
Aux.history_frame = public

function public.on_close()

end

function public.on_open()

end

function public.start_scan()

--    if not AuxHistoryScanButton:IsVisible() then
--        return
--    end

--    AuxHistoryScanButton:Hide()
--    AuxHistoryStopButton:Show()

    private.scanned_signatures = Aux.util.set()

    Aux.log('Scanning auctions ...')
    Aux.scan.start{
        query = {},
        page = 0,
        on_page_loaded = function(page, total_pages)
            Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(auction_info)
            private.process_auction(auction_info)
        end,
        on_complete = function()
            Aux.log('Scan complete: Old auctions were removed from the snapshot.')
--            AuxHistoryStopButton:Hide()
--            AuxHistoryScanButton:Show()
        end,
        on_abort = function()
            Aux.log('Scanning aborted.')
--            AuxHistoryStopButton:Hide()
--            AuxHistoryScanButton:Show()
        end,
        next_page = function(page, total_pages)
            local last_page = max(total_pages - 1, 0)
            if page < last_page then
                return page + 1
            end
        end,
    }
end

function public.stop_scan()
    Aux.scan.abort()
end

function private.process_auction(auction_info)
    private.scanned_signatures.add(auction_info.signature)
end
