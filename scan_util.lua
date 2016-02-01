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

function m.create_item_query(item_id)

    local item_info = Aux.static.item_info(item_id)

    if item_info then
        local filter = m.filter_from_string(item_info.name..'/exact')
        return {
            type = 'list',
            start_page = 0,
            validator = m.validator(filter),
            blizzard_query = m.blizzard_query(filter),
        }
    end
end

function m.parse_filter_string(filter_string)
    local parts = Aux.util.split(filter_string, ';')

    local filters = {}
    for _, str in ipairs(parts) do
        str = Aux.util.trim(str)

        local filter, error = m.filter_from_string(str)

        if not filter then
            Aux.log('Invalid filter: '..error)
            return
        elseif filter.name and strlen(filter.name) > 63 then

        else
            tinsert(filters, filter)
        end
    end

    return filters
end

function m.filter_from_string(filter_term)
    local parts = Aux.util.split(filter_term, '/')

    local filter = {}
    for i, str in ipairs(parts) do
        str = Aux.util.trim(str)

        if tonumber(str) then
            if not filter.min_level then
                filter.min_level = tonumber(str)
            elseif not filter.max_level and tonumber(str) >= filter.min_level then
                filter.max_level = tonumber(str)
            else
                return false, 'Invalid Level Range'
            end
        elseif not filter.class and Aux.item_class_index(str) then
            if not filter.class then
                filter.class = Aux.item_class_index(str)
            else
                return false, 'Invalid Item Class'
            end
        elseif filter.class and Aux.item_subclass_index(filter.class, str) then
            if not filter.subclass then
                filter.subclass = Aux.item_subclass_index(filter.class, str)
            else
                return false, 'Invalid Item Subclass'
            end
        elseif filter.subclass and Aux.item_slot(filter.class, filter.class, str) then
            if not filter.slot then
                filter.slot = Aux.item_slot(filter.class, filter.class, str)
            else
                return false, 'Invalid Item Slot'
            end
        elseif Aux.item_quality_index(str) then
            if not filter.quality then
                filter.quality = Aux.item_quality_index(str)
            else
                return false, 'Invalid Item Rarity'
            end
        elseif strlower(str) == 'usable' then
            if not filter.usable then
                filter.usable = true
            else
                return false, 'Invalid Usable Only Filter'
            end
        elseif strlower(str) == 'exact' then
            if not filter.exact then
                filter.exact = true
            else
                return false, 'Invalid Exact Only Filter'
            end
        elseif strlower(str) == 'discard' then
            if not filter.discard then
                filter.discard = true
            else
                return false, 'Invalid Discard Filter'
            end
        elseif Aux.money.from_string(str) > 0 then
            if not filter.max_price then
                filter.max_price = Aux.money.from_string(str)
            else
                return false, 'Invalid Max Price Filter'
            end
        elseif strfind(str, '^%d+%%$') then
            if not filter.max_percent then
                filter.max_percent = tonumber(({strfind(str, '(%d+)%%')})[3])
            else
                return false, 'Invalid Max Percent Filter'
            end
        elseif i == 1 then
            filter.name = str
        else
            return false, 'Unknown Filter'
        end
    end

    if filter.exact then
        if filter.min_level or filter.max_level or filter.class or filter.subclass or filter.slot or filter.quality or filter.usable or not Aux.static.auctionable_items[strupper(filter.name)] then
            return false, 'Invalid Exact Only Filter'
        end
    end

    return filter
end

function m.filter_to_string(filter)

    local filter_term = filter.name or ''

    local function add(part)
        filter_term = filter_term == '' and part or filter_term..'/'..part
    end

    if filter.exact then
        add('/exact')
    end

    if filter.min_level then
        add(filter.min_level)
    end

    if filter.max_level then
        add(filter.max_level)
    end

    if filter.usable then
        add('/usable')
    end

    if filter.class then
        local classes = { GetAuctionItemClasses() }
        add(classes[filter.class])
        if filter.subclass then
            local subclasses = {GetAuctionItemSubClasses(filter.class)}
            add(subclasses[filter.subclass])
            if filter.slot then
                add(getglobal(filter.slot))
            end
        end
    end

    if filter.quality then
        add(getglobal('ITEM_QUALITY'..filter.quality..'_DESC'))
    end

    if filter.max_price then
        add(Aux.money.to_string(filter.max_price, nil, true, nil, true))
    end

    if filter.max_percent then
        add(filter.max_percent..'%')
    end

    if filter.discard then
        add('/discard')
    end

    return filter_term
end

function m.blizzard_query(filter)

    local item_info
    if filter.exact then
        local item_id = Aux.static.auctionable_items[strupper(filter.name)]
        item_info = Aux.static.auctionable_items[item_id]
    end

    return {
        name = filter.name,
        min_level = filter.exact and item_info.level or filter.min_level,
        max_level = filter.exact and item_info.level or filter.max_level,
        slot = filter.exact and item_info.slot or filter.slot,
        class = filter.exact and item_info.class or filter.class,
        subclass = filter.exact and item_info.subclass or filter.subclass,
        usable = filter.exact and item_info.usable or filter.usable and 1 or 0,
        quality = filter.exact and item_info.quality or filter.quality,
    }
end

function m.validator(filter)

    return function(record)
        if filter.discard then
            return
        end
        if filter.exact and strupper(Aux.static.item_info(record.item_id).name) ~= strupper(filter.name) then
            return
        end
        if filter.min_level and record.level < filter.min_level then
            return
        end
        if filter.max_level and record.level > filter.max_level then
            return
        end
        if filter.max_price and record.buyout_price > filter.max_price then
            return
        end
        if filter.max_percent and (record.unit_buyout_price == 0
            or not Aux.history.market_value(record.item_key)
            or record.unit_buyout_price / Aux.history.market_value(record.item_key) * 100 > filter.max_percent)
        then
            return
        end
        return true
    end
end