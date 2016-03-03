local m = {}
Aux.scan_util = m

function m.find(auction_record, status_bar, on_abort, on_failure, on_success)

    local function test(index)
        local auction_info = Aux.info.auction(index, auction_record.query_type)
        return auction_info and auction_info.search_signature == auction_record.search_signature
    end

    Aux.scan.abort(auction_record.query_type)

    status_bar:update_status(0, 0)
    status_bar:set_text('Searching auction...')

    local pages = auction_record.page > 0 and { auction_record.page, auction_record.page - 1 } or { auction_record.page }

    local query = {
        validator = function(auction_info) return test(auction_info.index) end,
        blizzard_query = auction_record.query.blizzard_query,
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
        type = auction_record.query_type,
        queries = { query },
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
end

function m.create_item_query(item_id)

    local item_info = Aux.static.item_info(item_id)

    if item_info then
        local filter = m.filter_from_string(item_info.name..'/exact')
        return {
            start_page = 0,
            validator = filter.validator,
            blizzard_query = filter.blizzard_query,
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

function m.predicate(parts, i)

    if strlower(parts[i]) == 'left' then
        local max_index = ({
            ['30m'] = 1,
            ['2h'] = 2,
            ['8h'] = 3,
            ['24h'] = 4
        })[strlower(parts[i + 1] or '')]
        if max_index then
            return function(auction_record)
                return auction_record.duration <= max_index
            end, 2
        else
            return false, 'Erroneous Time Left Modifier'
        end
    elseif strlower(parts[i]) == 'min-lvl' then
        local level = tonumber(parts[i + 1] or '')
        if level then
            return function(auction_record)
                return auction_record.level >= level
            end, 2
        else
            return false, 'Erroneous Bid Profit Modifier'
        end
    elseif strlower(parts[i]) == 'max-lvl' then
        local level = tonumber(parts[i + 1] or '')
        if level then
            return function(auction_record)
                return auction_record.level <= level
            end, 2
        else
            return false, 'Erroneous Bid Profit Modifier'
        end
    elseif Aux.money.from_string(parts[i]) > 0 then
        return function(auction_record)
            return auction_record.buyout_price > 0 and auction_record.buyout_price <= Aux.money.from_string(parts[i])
        end, 1
--            return false, 'Erroneous Max Price Modifier'
    elseif strfind(parts[i], '^%d+%%$') then
        return function(auction_record)
            return auction_record.unit_buyout_price > 0
                    and Aux.history.value(auction_record.item_key)
                    and auction_record.unit_buyout_price / Aux.history.value(auction_record.item_key) * 100 <= tonumber(({strfind(parts[i], '(%d+)%%')})[3])
        end, 1
--            return false, 'Erroneous Max Percent Modifier'
    elseif strlower(parts[i]) == 'bid-profit' then
        local amount = Aux.money.from_string(parts[i + 1] or '')
        if amount > 0 then
            return function(auction_record)
                return Aux.history.value(auction_record.item_key) and Aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.bid_price >= amount
            end, 2
        else
            return false, 'Erroneous Bid Profit Modifier'
        end
    elseif strlower(parts[i]) == 'buyout-profit' then
        local amount = Aux.money.from_string(parts[i + 1] or '')
        if amount > 0 then
            return function(auction_record)
                return Aux.history.value(auction_record.item_key) and Aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end, 2
        else
            return false, 'Erroneous Buyout Profit Modifier'
        end
    elseif strlower(parts[i]) == 'discard' then
        return function()
            return false
        end, 1
    else
        return function(auction_record)
            return Aux.util.any(auction_record.tooltip, function(entry)
                return strfind(strupper(entry.left_text or ''), strupper(parts[i] or ''), 1, true) or strfind(strupper(entry.right_text or ''), strupper(parts[i] or ''), 1, true)
            end)
        end, 1
    end
end

function m.filter_from_string(filter_term)
    local parts = Aux.util.split(filter_term, '/')

    local blizzard_query = {}
    local validator = {}
    local tooltip_counter = 0
    local i = 1
    while i <= getn(parts) do
        local str = Aux.util.trim(parts[i])
        i = i + 1

        if tooltip_counter > 0 or strupper(str) == 'AND' or strupper(str) == 'OR' or strupper(str) == 'NOT' or strupper(str) == 'TT' then
            tooltip_counter = tooltip_counter == 0 and tooltip_counter + 1 or tooltip_counter
            if strupper(str) == 'AND' or strupper(str) == 'OR' then
                tooltip_counter = tooltip_counter + 1
                tinsert(validator, str)
            elseif strupper(str) == 'NOT' or strupper(str) == 'TT' then
                tinsert(validator, str)
            elseif str ~= '' then
                tooltip_counter = tooltip_counter - 1

                local pred, consumed = m.predicate(parts, i - 1)
                if not pred then
                    return false, consumed
                else
                    tinsert(validator, pred)
                    i = i + consumed - 1
                end
            end
        elseif tonumber(str) then
            if not blizzard_query.min_level then
                blizzard_query.min_level = tonumber(str)
            elseif not blizzard_query.max_level and tonumber(str) >= blizzard_query.min_level then
                blizzard_query.max_level = tonumber(str)
            else
                return false, 'Erroneous Level Range Modifier'
            end
        elseif Aux.item_class_index(str) and not (blizzard_query.class and not blizzard_query.subclass and strlower(str) == 'miscellaneous')then
            if not blizzard_query.class then
                blizzard_query.class = Aux.item_class_index(str)
            else
                return false, 'Erroneous Item Class Modifier'
            end
        elseif blizzard_query.class and Aux.item_subclass_index(blizzard_query.class, str) then
            if not blizzard_query.subclass then
                blizzard_query.subclass = Aux.item_subclass_index(blizzard_query.class, str)
            else
                return false, 'Erroneous Item Subclass Modifier'
            end
        elseif blizzard_query.subclass and Aux.item_slot_index(blizzard_query.class, blizzard_query.subclass, str) then
            if not blizzard_query.slot then
                blizzard_query.slot = Aux.item_slot_index(blizzard_query.class, blizzard_query.subclass, str)
            else
                return false, 'Erroneous Item Slot Modifier'
            end
        elseif Aux.item_quality_index(str) then
            if not blizzard_query.quality then
                blizzard_query.quality = Aux.item_quality_index(str)
            else
                return false, 'Erroneous Rarity Modifier'
            end
        elseif strlower(str) == 'usable' then
            if not blizzard_query.usable then
                blizzard_query.usable = true
            else
                return false, 'Erroneous Usable Only Modifier'
            end
        elseif strlower(str) == 'exact' then
            if not blizzard_query.exact then
                blizzard_query.exact = true
            else
                return false, 'Erroneous Exact Only Modifier'
            end
        elseif i == 2 then
            blizzard_query.name = str
        elseif str ~= '' then
            local pred, consumed = m.predicate(parts, i - 1)
            if not pred then
                return false, consumed
            else
                tinsert(validator, pred)
                i = i + consumed - 1
            end
        else
            return false, 'Unknown Modifier'
        end
    end

    if tooltip_counter ~= 0 then
        return false, 'Erroneous Tooltip Modifier'
    end

    if blizzard_query.exact then
        if blizzard_query.min_level
                or blizzard_query.max_level
                or blizzard_query.class
                or blizzard_query.subclass
                or blizzard_query.slot
                or blizzard_query.quality
                or blizzard_query.usable
                or not blizzard_query.name
                or not Aux.static.item_id(strupper(blizzard_query.name))
        then
            return false, 'Erroneous Exact Only Modifier'
        end
    end

    return { blizzard_query = m.blizzard_query(blizzard_query), validator = m.validator(blizzard_query, validator) }
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
        local item_id = Aux.static.item_id(strupper(filter.name))
        item_info = Aux.static.item_info(item_id)
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

function m.validator(blizzard_filter, validator)

    return function(record)
        if blizzard_filter.exact and strupper(Aux.static.item_info(record.item_id).name) ~= strupper(blizzard_filter.name) then
            return
        end
        if blizzard_filter.min_level and record.level < blizzard_filter.min_level then
            return
        end
        if blizzard_filter.max_level and record.level > blizzard_filter.max_level then
            return
        end
        if getn(validator) > 0 then
            local stack = {}
            for i=getn(validator),1,-1 do
                local op = validator[i]
                local op = type(op) == 'string' and strupper(op) or op
                if op == 'AND' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a and b)
                elseif op == 'OR' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a or b)
                elseif op == 'NOT' then
                    tinsert(stack, not tremove(stack))
                elseif op ~= 'TT' then
                    tinsert(stack, op(record) and true or false)
                end
            end
            return Aux.util.all(stack, Aux.util.id)
        end
        return true
    end
end