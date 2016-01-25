local m = {}
Aux.scan_util = m

function m.find_auction(type, test, search_query, page, status_bar, callback)

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
                    status_bar:update_status(100, 100)
                    status_bar:set_text('Auction found')
                    Aux.scan.abort(function()
                        callback(auction_info.index)
                    end)
                end
            end,
            on_complete = function()
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction not found')
                callback()
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