local m, public, private = aux.module'filter'

function private.default_filter(str)
    return {
        input_type = '',
        validator = function()
            return function(auction_record)
                return aux.util.any(auction_record.tooltip, function(entry)
                    return strfind(strupper(entry.left_text or ''), strupper(str or ''), 1, true) or strfind(strupper(entry.right_text or ''), strupper(str or ''), 1, true)
                end)
            end
        end,
    }
end

public.filters = {

    ['utilizable'] = {
        input_type = '',
        validator = function()
            return function(auction_record)
                return auction_record.usable and not aux.info.tooltip_match(ITEM_SPELL_KNOWN, auction_record.tooltip)
            end
        end,
    },

    ['tooltip'] = {
        input_type = 'string',
        validator = function(str)
            return m.default_filter(str).validator()
        end,
    },

    ['item'] = {
        input_type = 'string',
        validator = function(name)
            return function(auction_record)
                return strlower(aux.info.item(auction_record.item_id).name) == name
            end
        end
    },

    ['left'] = {
        input_type = {'30m', '2h', '8h', '24h'},
        validator = function(duration)
            local code = aux.util.key(duration, {'30m', '2h', '8h', '24h'})
            return function(auction_record)
                return auction_record.duration == code
            end
        end
    },

    ['rarity'] = {
        input_type = {'poor', 'common', 'uncommon', 'rare', 'epic'},
        validator = function(rarity)
            local code = aux.util.key(rarity, {'poor', 'common', 'uncommon', 'rare', 'epic'}) - 1
            return function(auction_record)
                return auction_record.quality == code
            end
        end
    },

    ['min-lvl'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level >= level
            end
        end
    },

    ['max-lvl'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level <= level
            end
        end
    },

    ['min-unit-bid'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_bid_price >= amount
            end
        end
    },

    ['min-unit-buy'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_buyout_price >= amount
            end
        end
    },

    ['max-unit-bid'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_bid_price <= amount
            end
        end
    },

    ['max-unit-buy'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and auction_record.unit_buyout_price <= amount
            end
        end
    },

    ['bid-pct'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return auction_record.unit_buyout_price > 0
                        and aux.history.value(auction_record.item_key)
                        and auction_record.unit_buyout_price / aux.history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['buy-pct'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return auction_record.unit_buyout_price > 0
                        and aux.history.value(auction_record.item_key)
                        and auction_record.unit_buyout_price / aux.history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['bid-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return aux.history.value(auction_record.item_key) and aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and aux.history.value(auction_record.item_key) and aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = aux.disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return disenchant_value and disenchant_value - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = aux.disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return auction_record.buyout_price > 0 and disenchant_value and disenchant_value - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = aux.cache.merchant_info(auction_record.item_id)
                return vendor_price and vendor_price * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = aux.cache.merchant_info(auction_record.item_id)
                return auction_record.buyout_price > 0 and vendor_price and vendor_price * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['discard'] = {
        input_type = '',
        validator = function()
            return function()
                return false
            end
        end
    },
}

function private.operator(str)
    if str == 'not' then
        return 'not', 1
    end

    local _, _, and_op, and_arity = strfind(str, '^(and)(%d*)$')
    local _, _, or_op, or_arity = strfind(str, '^(or)(%d*)$')

    local op = and_op or or_op
    local arity = and_arity or or_arity

    if op then
        if arity == '' then
            return op
        elseif tonumber(arity) and tonumber(arity) >= 2 then
            return op, tonumber(arity)
        end
    end
end

function private.blizzard_filter_parser()
    local class_index, subclass_index
    local filters = {}
    return function(str, first)
        local filter
        if tonumber(str) then
            if tonumber(str) < 1 or tonumber(str) > 60 then
                return nil, 'Erroneous level range modifier'
            end
            if not filters.min_level then
                filter = {'min_level', str}
            elseif not filters.max_level and tonumber(str) >= tonumber(filters.min_level) then
                filter = {'max_level', str}
            else
                return nil, 'Erroneous level range modifier'
            end
        elseif aux.info.item_class_index(str) and not (filters.class and not filters.subclass and str == strlower(({ GetAuctionItemClasses() })[10])) then
            class_index = aux.info.item_class_index(str)
            if not filters.class then
                filter = {'class', str}
            else
                return nil, 'Erroneous item class modifier'
            end
        elseif class_index and aux.info.item_subclass_index(class_index, str) then
            subclass_index = aux.info.item_subclass_index(class_index, str)
            if not filters.subclass then
                filter = {'subclass', str}
            else
                return nil, 'Erroneous item subclass modifier'
            end
        elseif subclass_index and aux.info.item_slot_index(class_index, subclass_index, str) then
            if not filters.slot then
                filter = {'slot', str}
            else
                return nil, 'Erroneous item slot modifier'
            end
        elseif aux.info.item_quality_index(str) then
            if not filters.quality then
                filter = {'quality', str}
            else
                return nil, 'Erroneous rarity modifier'
            end
        elseif str == 'usable' then
            if not filters.usable then
                filter = {'usable'}
            else
                return nil, 'Erroneous usable only modifier'
            end
        elseif str == 'exact' then
            if filters.name and not filters.exact then
                filter = {'exact'}
            else
                return nil, 'Erroneous exact only modifier'
            end
        elseif first then
            if strlen(str) <= 63 then
                filter = {'name', str }
            else
                return nil, 'The name must not be longer than 63 characters'
            end
        end

        if filter then
            filters[filter[1]] = filter[2] or true
        end

        if filters.exact and
            (
                filters.min_level
                    or filters.max_level
                    or filters.class
                    or filters.subclass
                    or filters.slot
                    or filters.quality
                    or filters.usable
            )
        then
            return false, 'Erroneous exact only modifier'
        end

        return filter
    end
end

function private.parse_parameter(input_type, str)
    if input_type == 'money' then
        local money = aux.money.from_string(str)
        if money and money > 0 then
            return money
        end
    elseif input_type == 'number' then
        local number = tonumber(str)
        if number then
            return number
        end
    elseif input_type == 'string' then
        if str ~= '' then
            return str
        end
    elseif type(input_type) == 'table' then
        local choice = aux.util.key(str, input_type)
        if choice then
            return choice
        end
    end
end

function public.parse_query_string(str)
    local components = { blizzard = {}, post = {} }
    local blizzard_filter_parser = m.blizzard_filter_parser()
    local parts = aux.util.map(aux.util.split(str, '/'), function(part) return strlower(aux.util.trim(part)) end)

    local i = 1
    while parts[i] do
        local op, arity = m.operator(parts[i])
        if op then
            tinsert(components.post, {'operator', op, arity})
        elseif m.filters[parts[i]] then
            local input_type = m.filters[parts[i]].input_type
            if input_type ~= '' then
                if not parts[i + 1] or not m.parse_parameter(input_type, parts[i + 1]) then
                    if parts[i] == 'item' then
                        return nil, 'Invalid item name', aux_auctionable_items
                    elseif type(input_type) == 'table' then
                        return nil, 'Invalid choice for '..parts[i], input_type
                    else
                        return nil, 'Invalid input for '..parts[i]..'. Expecting: '..input_type
                    end
                end
                tinsert(components.post, {'filter', parts[i], parts[i + 1]})
                i = i + 1
            else
                tinsert(components.post, {'filter', parts[i]})
            end
        else
            local component, error = blizzard_filter_parser(parts[i], i == 1)
            if component then
                tinsert(components.blizzard, component)
            elseif error then
                return nil, error
            elseif parts[i] ~= '' then
                tinsert(components.post, {'filter', 'tooltip', parts[i]})
            else
                return nil, 'Empty modifier'
            end
        end
        i = i + 1
    end

    return components
end

function public.query(query_string)
    local components, error, suggestions = m.parse_query_string(query_string)

    if not components then
        return nil, suggestions or {}, error
    end

    local polish_notation_counter = 0
    for _, component in components.post do
        if component[1] == 'operator' then
            polish_notation_counter = max(polish_notation_counter, 1)
            polish_notation_counter = polish_notation_counter + (tonumber(component[2]) or 1) - 1
        elseif component[1] == 'filter' then
            polish_notation_counter = polish_notation_counter - 1
        end
    end

    if polish_notation_counter > 0 then
        local suggestions = {}
        for filter, _ in m.filters do
            tinsert(suggestions, strlower(filter))
        end
        tinsert(suggestions, 'and')
        tinsert(suggestions, 'or')
        tinsert(suggestions, 'not')
        return nil, suggestions, 'Malformed expression'
    end

    return {
        blizzard_query = m.blizzard_query(components),
        validator = m.validator(components),
        prettified = m.prettified_query_string(components),
    }, m.suggestions(components)
end

function public.queries(query_string)
    local parts = aux.util.split(query_string, ';')

    local queries = {}
    for _, str in ipairs(parts) do
        str = aux.util.trim(str)

        local query, _, error = m.query(str)

        if not query then
            aux.log('Invalid filter:', error)
            return
        else
            tinsert(queries, query)
        end
    end

    return queries
end

function private.suggestions(components)

    local blizzard_filters = {}
    for _, filter in components.blizzard do
        blizzard_filters[filter[1]] = filter[2] or true
    end

    local suggestions = {}

    if blizzard_filters.name
            and not blizzard_filters.min_level
            and not blizzard_filters.max_level
            and not blizzard_filters.class
            and not blizzard_filters.subclass
            and not blizzard_filters.slot
            and not blizzard_filters.quality
            and not blizzard_filters.usable
    then
        tinsert(suggestions, 'exact')
    end

    tinsert(suggestions, 'and')
    tinsert(suggestions, 'or')
    tinsert(suggestions, 'not')
    tinsert(suggestions, 'tt')

    for filter, _ in m.filters do
        tinsert(suggestions, strlower(filter))
    end

    -- classes
    if not blizzard_filters.class then
        for _, class in ipairs({ GetAuctionItemClasses() }) do
            tinsert(suggestions, class)
        end
    end

    -- subclasses
    local class_index = blizzard_filters.class and aux.info.item_class_index(blizzard_filters.class)
    if class_index and not blizzard_filters.subclass then
        for _, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    local subclass_index = class_index and blizzard_filters.subclass and aux.info.item_subclass_index(class_index, blizzard_filters.subclass)
    if subclass_index and not blizzard_filters.slot then
        for _, invtype in ipairs({ GetAuctionInvTypes(class_index, aux.info.item_subclass_index(class_index, blizzard_filters.subclass)) }) do
            tinsert(suggestions, getglobal(invtype))
        end
    end

    -- usable
    if not blizzard_filters.usable then
        tinsert(suggestions, 'usable')
    end

    -- rarities
    if not blizzard_filters.quality then
        for i=0,4 do
            tinsert(suggestions, getglobal('ITEM_QUALITY'..i..'_DESC'))
        end
    end

    -- item names
    if getn(components.blizzard) + getn(components.post) == 1 and blizzard_filters.name == '' then
        for _, name in aux_auctionable_items do
            tinsert(suggestions, name..'/exact')
        end
    end

    return suggestions
end

function public.query_string(components)
    local prettified = m.query_builder()

    local blizzard_filters = {}
    for _, filter in components.blizzard do
        prettified.append((filter[2] or filter[1]))
    end

    for _, component in components.post do
        if component[1] == 'operator' then
            prettified.append(component[2]..(tonumber(component[3]) or ''))
        elseif component[1] == 'filter' then
            prettified.append(component[2])
            if component[3] then
                prettified.append(component[3])
            end
        end
    end

    return prettified.get()
end

function public.indented_post_query_string(components)
    local no_line_break
    local stack = {}
    local str = ''

    for i, component in components do
        if no_line_break then
            str = str..' '
        elseif i > 1 then
            str = str..'|n'
            for _=1,getn(stack) do
                str = str..'    '
            end
        end

        if component[1] == 'operator' and component[2] then
            no_line_break = component[2] == 'not'
            str = str..'|cffffff00'..component[2]..(tonumber(component[3]) or '')..'|r'
            tinsert(stack, component[3] or '*')
        elseif component[1] == 'filter' then
            str = str..'|cffffff00'..component[2]..'|r'
            if component[3] then
                str = str..': '..'|cffff9218'..component[3]..'|r'
            end
            while getn(stack) > 0 and stack[getn(stack)] ~= '*' do
                local top = tremove(stack)
                if tonumber(top) and top > 1 then
                    tinsert(stack, top - 1)
                    break
                end
            end
        end
    end

    return str
end

function private.prettified_query_string(components)
    local prettified = m.query_builder()

    local blizzard_filters = {}
    for _, filter in components.blizzard do
        blizzard_filters[filter[1]] = filter[2] or true
        if filter[1] == 'exact' then
            prettified.prepend(aux.info.display_name(aux.cache.item_id(m.unquote(blizzard_filters.name))) or aux.gui.inline_color({216, 225, 211, 1})..'['..m.unquote(blizzard_filters.name)..']|r')
        elseif filter[1] ~= 'name' then
            prettified.append(aux.gui.inline_color({216, 225, 211, 1})..(filter[2] or filter[1])..'|r')
        end
    end

    if blizzard_filters.name and not blizzard_filters.exact then
        if m.unquote(blizzard_filters.name) == '' then
            prettified.prepend('|cffff0000'..'No Filter'..'|r')
        else
            prettified.prepend(aux.gui.inline_color({216, 225, 211, 1})..m.unquote(blizzard_filters.name)..'|r')
        end
    end

    for _, component in components.post do
        if component[1] == 'operator' then
            prettified.append('|cffffff00'..component[2]..(tonumber(component[3]) or '')..'|r')
        elseif component[1] == 'filter' then
            if component[2] ~= 'tooltip' then
                prettified.append('|cffffff00'..component[2]..'|r')
            end
            if component[3] then
                prettified.append('|cffff9218'..component[3]..'|r')
            end
        end
    end

    return prettified.get()
end

function public.quote(name)
    return '<'..name..'>'
end

function public.unquote(name)
    if name and strsub(name, 1, 1) == '<' and strsub(name, -1, -1) == '>' then
        name = strsub(name, 2, -2)
    end
    return name
end

function private.blizzard_query(components)
    local filters = {}
    for _, filter in components.blizzard do
        filters[filter[1]] = filter[2] or true
    end

    local query = { name = filters.name and m.unquote(filters.name) }

    local item_info, class_index, subclass_index, slot_index
    if filters.exact then
        local item_id = aux.cache.item_id(filters.name)
        item_info = aux.info.item(item_id)
        class_index = item_info and aux.info.item_class_index(item_info.class)
        subclass_index = class_index and item_info.subclass and aux.info.item_subclass_index(class_index, item_info.subclass)
        slot_index = subclass_index and item_info.slot and aux.info.item_slot_index(class_index, subclass_index, item_info.slot)
    end

    if item_info then
        query.min_level = item_info.level
        query.max_level = item_info.level
        query.class = class_index
        query.subclass = subclass_index
        query.slot = item_info.class
        query.usable = item_info.usable
        query.quality = item_info.quality
    else
        query.min_level = tonumber(filters.min_level)
        query.max_level = tonumber(filters.max_level)
        query.class = filters.class and filters.class and aux.info.item_class_index(filters.class)
        query.subclass = query.class and filters.subclass and aux.info.item_subclass_index(query.class, filters.subclass)
        query.slot = query.subclass and filters.slot and aux.info.item_slot_index(query.class, query.subclass, filters.slot)
        query.usable = filters.usable and 1
        query.quality = filters.quality and aux.info.item_quality_index(filters.quality)
    end

    return query
end

function private.validator(components)

    local validators = {}
    for i, component in components.post do
        if component[1] == 'filter' then
            validators[i] = m.filters[component[2]].validator(m.parse_parameter(m.filters[component[2]].input_type, component[3]))
        end
    end

    return function(record)
        for _, filter in components.blizzard do
            if filter[1] == 'exact' and strlower(aux.info.item(record.item_id).name) ~= components.blizzard[1][2] then
                return false
            end
        end
        local stack = {}
        for i=getn(components.post),1,-1 do
            local type, name, param = unpack(components.post[i])
            if type == 'operator' then
                local args = {}
                while (not param or param > 0) and getn(stack) > 0 do
                    tinsert(args, tremove(stack))
                    param = param and param - 1
                end
                if name == 'not' then
                    tinsert(stack, not args[1])
                elseif name == 'and' then
                    tinsert(stack, aux.util.all(args, aux.util.id))
                elseif name == 'or' then
                    tinsert(stack, aux.util.any(args, aux.util.id))
                end
            elseif type == 'filter' then
                tinsert(stack, validators[i](record) and true or false)
            end
        end
        return aux.util.all(stack, aux.util.id)
    end
end

function public.query_builder(str)
    local filter = str or ''
    return {
        appended = function(part)
            return m.query_builder(filter == '' and part or filter..'/'..part)
        end,
        prepended = function(part)
            return m.query_builder(filter == '' and part or part..'/'..filter)
        end,
        append = function(part)
            filter = filter == '' and part or filter..'/'..part
        end,
        prepend = function(part)
            filter = filter == '' and part or part..'/'..filter
        end,
        get = function()
            return filter
        end
    }
end