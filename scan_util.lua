local m = {}
Aux.scan_util = m

function m.find(test, query, page, status_bar, on_abort, on_failure, on_success)

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

        local found
        Aux.scan.start{
            queries = { new_query },
            on_read_auction = function(auction_info, ctrl)
                if test(auction_info.index) then
                    found = true
                    ctrl.suspend()
                    status_bar:update_status(100, 100)
                    status_bar:set_text('Auction found')
                    return on_success(auction_info.index)
                end
            end,
            on_abort = function()
                if not found then
                    status_bar:update_status(100, 100)
                    status_bar:set_text('Auction not found')
                    return on_abort()
                end
            end,
            on_complete = function()
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction not found')
                return on_failure()
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
    local tooltip_counter = 0
    for i, str in ipairs(parts) do
        str = Aux.util.trim(str)

        if tooltip_counter > 0 or strupper(str) == 'AND' or strupper(str) == 'OR' or strupper(str) == 'NOT' or strupper(str) == 'TT' then
            filter.tooltip = filter.tooltip or {}
            tinsert(filter.tooltip, str)
            tooltip_counter = tooltip_counter == 0 and tooltip_counter + 1 or tooltip_counter
            if strupper(str) == 'AND' or strupper(str) == 'OR' then
                tooltip_counter = tooltip_counter + 1
            elseif not (strupper(str) == 'NOT' or strupper(str) == 'TT' or str == '') then
                tooltip_counter = tooltip_counter - 1
            end
        elseif tonumber(str) then
            if not filter.min_level then
                filter.min_level = tonumber(str)
            elseif not filter.max_level and tonumber(str) >= filter.min_level then
                filter.max_level = tonumber(str)
            else
                return false, 'Erroneous Level Range Modifier'
            end
        elseif Aux.item_class_index(str) and not (filter.class and not filter.subclass and strlower(str) == 'miscellaneous')then
            if not filter.class then
                filter.class = Aux.item_class_index(str)
            else
                return false, 'Erroneous Item Class Modifier'
            end
        elseif filter.class and Aux.item_subclass_index(filter.class, str) then
            if not filter.subclass then
                filter.subclass = Aux.item_subclass_index(filter.class, str)
            else
                return false, 'Erroneous Item Subclass Modifier'
            end
        elseif filter.subclass and Aux.item_slot_index(filter.class, filter.subclass, str) then
            if not filter.slot then
                filter.slot = Aux.item_slot_index(filter.class, filter.subclass, str)
            else
                return false, 'Erroneous Item Slot Modifier'
            end
        elseif Aux.item_quality_index(str) then
            if not filter.quality then
                filter.quality = Aux.item_quality_index(str)
            else
                return false, 'Erroneous Rarity Modifier'
            end
        elseif strlower(str) == 'usable' then
            if not filter.usable then
                filter.usable = true
            else
                return false, 'Erroneous Usable Only Modifier'
            end
        elseif strlower(str) == 'exact' then
            if not filter.exact then
                filter.exact = true
            else
                return false, 'Erroneous Exact Only Modifier'
            end
        elseif strlower(str) == 'discard' then
            if not filter.discard then
                filter.discard = true
            else
                return false, 'Erroneous Discard Modifier'
            end
        elseif Aux.money.from_string(str) > 0 then
            if not filter.max_price then
                filter.max_price = Aux.money.from_string(str)
            else
                return false, 'Erroneous Max Price Modifier'
            end
        elseif strfind(str, '^%d+%%$') then
            if not filter.max_percent then
                filter.max_percent = tonumber(({strfind(str, '(%d+)%%')})[3])
            else
                return false, 'Erroneous Max Percent Modifier'
            end
        elseif i == 1 then
            filter.name = str
        else
            return false, 'Unknown Modifier'
        end
    end

    if tooltip_counter > 0 then
        return false, 'Erroneous Tooltip Modifier'
    end

    if filter.exact then
        if filter.min_level
                or filter.max_level
                or filter.class
                or filter.subclass
                or filter.slot
                or filter.quality
                or filter.usable
                or not filter.name
                or not Aux.static.auctionable_items[strupper(filter.name)]
        then
            return false, 'Erroneous Exact Only Modifier'
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
        add('exact')
    end

    if filter.min_level then
        add(filter.min_level)
    end

    if filter.max_level then
        add(filter.max_level)
    end

    if filter.usable then
        add('usable')
    end

    if filter.class then
        local classes = { GetAuctionItemClasses() }
        add(strlower(classes[filter.class]))
        if filter.subclass then
            local subclasses = {GetAuctionItemSubClasses(filter.class)}
            add(strlower(subclasses[filter.subclass]))
            if filter.slot then
                add(strlower(getglobal(filter.slot)))
            end
        end
    end

    if filter.quality then
        add(strlower(getglobal('ITEM_QUALITY'..filter.quality..'_DESC')))
    end

    if filter.max_price then
        add(Aux.money.to_string(filter.max_price, nil, true, nil, nil, true))
    end

    if filter.max_percent then
        add(filter.max_percent..'%')
    end

    if filter.discard then
        add('discard')
    end

    if filter.tooltip then
        for _, part in ipairs(filter.tooltip) do
            add(part)
        end
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
        class = filter.exact and item_info.class or filter.class,
        subclass = filter.exact and item_info.subclass or filter.subclass,
        slot = filter.exact and (item_info.class and item_info.subclass and Aux.item_slot_index(item_info.class, item_info.subclass, item_info.slot)) or filter.slot,
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
            or not Aux.history.value(record.item_key)
            or record.unit_buyout_price / Aux.history.value(record.item_key) * 100 > filter.max_percent)
        then
            return
        end
        if filter.tooltip then
            local stack = {}
            for i=getn(filter.tooltip),1,-1 do
                local op = strupper(filter.tooltip[i])
                if op == 'AND' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a and b)
                elseif op == 'OR' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a or b)
                elseif op == 'NOT' then
                    tinsert(stack, not tremove(stack))
                elseif op ~= 'TT' then
                    tinsert(stack, Aux.util.any(record.tooltip, function(entry)
                        return strfind(strupper(entry.left_text or ''), strupper(op), 1, true) or strfind(strupper(entry.right_text or ''), strupper(op), 1, true)
                    end) and true or false)
                end
            end
            return Aux.util.all(stack, Aux.util.id)
        end
        return true
    end
end