local m = {}
Aux.scan_util = m

function m.find(test, query, page, status_bar, on_failure, on_success)

    Aux.scan.abort(function()

        status_bar:update_status(0, 0)
        status_bar:set_text('Searching auction...')

        local pages = page > 0 and { page, page - 1 } or { page }

        local new_query = {
            type = query.type,
            validator = test,
            blizzard_query = query.blizzard_query,
            next_page = function()
                if getn(pages) == 1 then
                    status_bar:update_status(50, 50)
                end
                local page = pages[1]
                tremove(pages, 1)
                return page
            end
        }

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

    local function validator(auction_info)
        return auction_info.item_id == item_id
    end
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

function m.parse_filter_string(filter_string)
    local parts = {Aux.persistence.deserialize(filter_string, ';')}

    local filters = {}
    for _, str in ipairs(parts) do
        str = Aux.util.trim(str)
        if tonumber(str) then
            local filter = Aux.scan_util.create_item_query(tonumber(str))
            if filter then
                tinsert(filters, filter)
            end
        else
            local filter, error = m.filter(str)

            if not filter then
                Aux.log('Invalid filter: '..error)
            elseif strlen(filter.query_string) > 63 then

            else
                tinsert(filters, filter)
            end
        end
    end

    return filters
end

function m.filter(filter_term)
    local parts = {Aux.persistence.deserialize(filter_term, '/')}
    local query_string, class, subclass, min_level, max_level, quality, usable_only, exact_only, even_only, min_profit, max_percentage

    if getn(parts) == 0 then
        return false, 'Invalid Filter'
    end

    for i, str in ipairs(parts) do
        str = Aux.util.trim(str)

        if tonumber(str) then
            if not min_level then
                min_level = tonumber(str)
            elseif not max_level then
                max_level = tonumber(str)
            else
                return false, 'Invalid Min Level'
            end
        elseif not class and Aux.item_class_index(str) then
            if not class then
                class = Aux.item_class_index(str)
            else
                return false, 'Invalid Item Type'
            end
        elseif Aux.item_subclass_index(class, str) then
            if not subclass then
                subclass = Aux.item_subclass_index(class, str)
            else
                return false, 'Invalid Item SubType'
            end
        elseif Aux.item_quality_index(str) then
            if not quality then
                quality = Aux.item_quality_index(str)
            else
                return false, 'Invalid Item Rarity'
            end
        elseif strlower(str) == 'usable' then
            if not usable_only then
                usable_only = true
            else
                return false, 'Invalid Usable Only Filter'
            end
        elseif strlower(str) == 'exact' then
            if not exact_only then
                exact_only = true
            else
                return false, 'Invalid Exact Only Filter'
            end
        elseif strlower(str) == 'even' then
            if not even_only then
                even_only = true
            else
                return false, 'Invalid Even Only Filter'
            end
        elseif Aux.money.from_string(str) then
            min_profit = Aux.money.from_string(str)
        elseif i == 1 then
            query_string = str
        else
            return false, 'Unknown Filter'
        end
    end

    min_level, max_level = min(min_level, max_level), max(min_level, max_level)

    return { query_string or '', class or 0, subclass or 0, min_level or 0, max_level or 0, quality or 0, usable_only or 0, exact_only or nil, even_only or nil, min_profit }
end

function m.blizzard_query(filter)
    return {
        name = filter.query_string,
        min_level = filter.min_level,
        max_level = filter.max_level,
        slot = filter.slot,
        class = filter.class,
        subclass = filter.subclass,
        usable = filter.usable_only,
        quality = filter.quality,
    }
end

function m.validator(filter)

    return function(record)

        if filter.exact_only and record.name ~= record.name then
            return
        end

        if filter.even_only and rem(record.aux_quantity, 5) ~= 0 then
            return
        end

        if filter.min_level > 0 and record.level < record.min_level then
            return
        end

        if filter.max_level > 0 and record.level > record.max_level then
            return
        end

        return true
    end
end