local m = {}
Aux.scan_util = m

function m.find(type, test, search_query, page, status_bar, on_failure, on_success)

    Aux.scan.abort(function()

        status_bar:update_status(0, 0)
        status_bar:set_text('Searching auction...')

        local pages = page > 0 and { page, page - 1 } or { page }

        Aux.scan.start{
            type = type,
            query = search_query,
            on_read_auction = function(auction_info, ctrl)
                if test(auction_info.index) then
                    ctrl.suspend()
                    Aux.scan.abort(function()
                        if not test(auction_info.index) then
                            return on_failure()
                        else
                            status_bar:update_status(100, 100)
                            status_bar:set_text('Auction found')
                            return on_success(auction_info.index)
                        end
                    end)
                end
            end,
            on_complete = function()
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction not found')
                on_failure()
            end,
            next_page = function()
                if getn(pages) == 1 then
                    status_bar:update_status(50, 50)
                end
                local page = pages[1]
                tremove(pages, 1)
                return page
            end,
        }
    end)
end