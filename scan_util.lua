local m = {}
Aux.scan_util = m

function m.find(test, query, page, status_bar, on_failure, on_success)

    Aux.scan.abort(function()

        status_bar:update_status(0, 0)
        status_bar:set_text('Searching auction...')

        local pages = page > 0 and { page, page - 1 } or { page }

        local new_query = {
            type = query.type,
            validator = function(auction_info) return test(auction_info.index) end,
            blizzard_query = query.blizzard_query,
            next_page = function()
                if getn(pages) == 1 then
                    status_bar:update_status(50, 50)
                end
                local page = pages[1]
                tremove(pages, 1)
                return page
            end,
        }

        Aux.scan.start{
            queries = { new_query },
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

function m.create_item_filter(item_id)
    local item_info = Aux.static.item_info(item_id)

    if item_info then
        local class_index = Aux.item_class_index(item_info.class)
        local subclass_index = class_index and Aux.item_subclass_index(class_index, item_info.subclass)

        return {
            name = item_info.name,
            min_level = item_info.level,
            min_level = item_info.level,
            slot = item_info.slot,
            class = class_index,
            subclass = subclass_index,
            subclass = item_info.subclass,
            quality = item_info.quality,
            usable = item_info.usable,
        }
    end
end

function m.create_item_query(item_id)
    local item_info = Aux.static.item_info(item_id)

    local filter = m.create_item_filter(item_id)

    return item_info and {
        type = 'list',
        start_page = 0,
        validator = m.validator(filter),
        blizzard_query = m.blizzard_query(filter),
    }
end

function m.parse_filter_string(filter_string)
    local parts = Aux.persistence.deserialize(filter_string, ';')

    local filters = {}
    for _, str in ipairs(parts) do
        str = Aux.util.trim(str)
        if tonumber(str) then
            local filter = m.create_item_filter(tonumber(str))
            if filter then
                tinsert(filters, filter)
            end
        else
            local filter, error = m.filter_from_string(str)

            if not filter then
                Aux.log('Invalid filter: '..error)
            elseif filter.name and strlen(filter.name) > 63 then

            else
                tinsert(filters, filter)
            end
        end
    end

    return filters
end

function m.filter_from_string(filter_term)
    local parts = Aux.persistence.deserialize(filter_term, '/')

    local filter = {}
    for i, str in ipairs(parts) do
        str = Aux.util.trim(str)

        if tonumber(str) then
            if not filter.min_level then
                filter.min_level = tonumber(str)
            elseif not filter.max_level then
                filter.max_level = tonumber(str)
            else
                return false, 'Invalid Min Level'
            end
        elseif not filter.class and Aux.item_class_index(str) then
            if not filter.class then
                filter.class = Aux.item_class_index(str)
            else
                return false, 'Invalid Item Type'
            end
        elseif filter.class and Aux.item_subclass_index(filter.class, str) then
            if not filter.subclass then
                filter.subclass = Aux.item_subclass_index(filter.class, str)
            else
                return false, 'Invalid Item SubType'
            end
        elseif Aux.item_quality_index(str) then
            if not filter.quality then
                filter.quality = Aux.item_quality_index(str)
            else
                return false, 'Invalid Item Rarity'
            end
        elseif strlower(str) == 'usable' then
            if not filter.usable_only then
                filter.usable_only = true
            else
                return false, 'Invalid Usable Only Filter'
            end
        elseif strlower(str) == 'exact' then
            if not filter.exact_only then
                filter.exact_only = true
            else
                return false, 'Invalid Exact Only Filter'
            end
        elseif strlower(str) == 'even' then
            if not filter.even_only then
                filter.even_only = true
            else
                return false, 'Invalid Even Only Filter'
            end
--        elseif Aux.money.from_string(str) then
--            filter.min_profit = Aux.money.from_string(str)
        elseif i == 1 then
            filter.name = str
        else
            return false, 'Unknown Filter'
        end
    end

    if filter.max_level then
        filter.min_level, filter.max_level = min(filter.min_level, filter.max_level), max(filter.min_level, filter.max_level)
    end

    return filter
end

function m.filter_to_string(filter)

    local filter_term = filter.name or ''

    if filter.max_level then
        filter_term = format('%s/%d/%d', filter_term, filter.min_level, filter.max_level)
    elseif filter.min_level then
        filter_term = format('%s/%d', filter_term, filter.min_level)
    end

    if filter.class then
        local classes = { GetAuctionItemClasses() }
        filter_term = format('%s/%s', filter_term, classes[filter.class])
        if filter.subclass then
            local subclasses = {GetAuctionItemSubClasses(filter.class)}
            filter_term = format('%s/%s', filter_term, subclasses[filter.subclass])
        end
    end

    if filter.quality then
        filter_term = format('%s/%s', filter_term,  _G["ITEM_QUALITY"..filter.quality.."_DESC"])
    end

    if filter.usable_only then
        filter_term = format('%s/usable', filter_term)
    end

    if filter.exact_only then
        filter_term = format('%s/exact', filter_term)
    end

    return filter_term
end

function m.blizzard_query(filter)
    return {
        name = filter.name,
        min_level = filter.min_level,
        max_level = filter.max_level,
        slot = filter.slot,
        class = filter.class,
        subclass = filter.subclass,
        usable = filter.usable_only and 1 or 0,
        quality = filter.quality,
    }
end

function m.validator(filter)

    return function(record)

        if filter.exact_only and record.name ~= filter.name then
            return
        end

        if filter.even_only and rem(record.aux_quantity, 5) ~= 0 then
            return
        end

        if filter.min_level and record.level < filter.min_level then
            return
        end

        if filter.max_level and record.level > filter.max_level then
            return
        end

        return true
    end
end