local m = {}
Aux.scan_util = m

function m.find(test, query, page, status_bar, on_failure, on_success)

    Aux.scan.abort(function()

        status_bar:update_status(0, 0)
        status_bar:set_text('Searching auction...')

        local pages = page > 0 and { page, page - 1 } or { page }

        query = Aux.util.copy_table(query)
        query.next_page = function()
            if getn(pages) == 1 then
                status_bar:update_status(50, 50)
            end
            local page = pages[1]
            tremove(pages, 1)
            return page
        end

        Aux.scan.start{
            queries = { query },
            on_read_auction = function(auction_info, ctrl)
                if test(auction_info.index) then
                    ctrl.suspend()
                    if not test(auction_info.index) then
                        return on_failure()
                    else
                        status_bar:update_status(100, 100)
                        status_bar:set_text('Auction found')
                        return on_success(auction_info.index)
                    end
                end
            end,
            on_complete = function()
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction not found')
                on_failure()
            end,
        }
    end)
end

function m.create_item_query(item_id, type, start_page, next_page)
    local item_info = Aux.static.item_info(item_id)

--    local class_index = Aux.item_class_index(item_info.class)
--    local subclass_index = class_index and Aux.item_subclass_index(class_index, item_info.subclass) -- TODO test if needed

    return item_info and {
        type = type,
        start_page = start_page,
        next_page = next_page,
        name = item_info.name,
        min_level = item_info.level,
        min_level = item_info.level,
        slot = item_info.slot,
--        class = class_index,
--        subclass = subclass_index,
--        class = Aux.item_class_index(item_info.class),
--        subclass = item_info.subclass,
        quality = item_info.quality,
        usable = item_info.usable,
    }
end