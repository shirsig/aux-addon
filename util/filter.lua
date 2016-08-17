aux.module 'filter'

function private.default_filter(str)
    return {
        input_type = '',
        validator = function()
            return function(auction_record)
                return aux.util.any(auction_record.tooltip, function(entry)
                    return strfind(strlower(entry.left_text or ''), str, 1, true) or strfind(strlower(entry.right_text or ''), str, 1, true)
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
        validator = function(index)
            return function(auction_record)
                return auction_record.duration == index
            end
        end
    },

    ['rarity'] = {
        input_type = {'poor', 'common', 'uncommon', 'rare', 'epic'},
        validator = function(index)
            return function(auction_record)
                return auction_record.quality == index - 1
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
    local operator = str == 'not' and {'operator', 'not', 1}
    for _, name in {'and', 'or'} do
	    for arity in aux.util.present(aux.util.select(3, strfind(str, '^'..name..'(%d*)$'))) do
		    arity = tonumber(arity)
		    operator = not (arity and arity < 2) and {'operator', name, arity}
	    end
    end
    return operator or nil
end

do
	local mt = {
		__call = function(self, str, i)
			if not str then
				self.max_level = self.max_level or self.min_level
				return self
			end
			if self.exact then
				return
			end
			for number in aux.util.present(tonumber(aux.util.select(3, strfind(str, '^(%d+)$')))) do
				if number >= 1 and number <= 60 then
					for _, filter in {'min_level', 'max_level'} do
						if not self[filter] then
							self[filter] = {str, number}
							return true
						end
					end
				end
			end
			for _, parser in {
				{'class', aux.info.item_class_index},
				{'subclass', aux._(aux.info.item_subclass_index, aux.index(self.class, 2) or 0, aux.arg1)},
				{'slot', aux._(aux.info.item_slot_index, aux.index(self.class, 2) or 0, aux.index(self.subclass, 2) or 0, aux.arg1)},
				{'quality', aux.info.item_quality_index},
			} do
				if not self[parser[1]] then
					tinsert(parser, str)
					for index, label in aux.util.present(parser[2](aux.util.select(3, unpack(parser)))) do
						self[parser[1]] = {label, index}
						return true
					end
				end
			end
			if not self[str] and (str == 'usable' or str == 'exact' and self.name and aux.util.size(self) == 1) then
				self[str] = {str, 1}
			elseif i == 1 and strlen(str) <= 63 then
				self.name = {str, m.unquote(str)}
--				return nil, 'The name filter must not be longer than 63 characters'
			else
				return
			end
			return true
		end,
	}

	function private.blizzard_filter_parser()
	    return setmetatable({}, mt)
	end
end

function private.parse_parameter(input_type, str)
    if input_type == 'money' then
        local money = aux.money.from_string(str)
        return money and money > 0 and money or nil
    elseif input_type == 'number' then
        local number = tonumber(str)
        return number and number > 0 and mod(number, 1) == 0 and number or nil
    elseif input_type == 'string' then
        return str ~= '' and str or nil
    elseif type(input_type) == 'table' then
        return aux.util.key(str, input_type)
    end
end

function public.parse_query_string(str)
    local post_filter = {}
    local blizzard_filter_parser = m.blizzard_filter_parser()
    local parts = aux.util.map(aux.util.split(str, '/'), function(part) return strlower(aux.util.trim(part)) end)

    local i = 1
    while parts[i] do
        if aux.temp(m.operator(parts[i])) then
            tinsert(post_filter, __.operator)
        elseif __(m.filters[parts[i]]) then
            local input_type = __.filter.input_type
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
                tinsert(post_filter, {'filter', parts[i], parts[i + 1]})
                i = i + 1
            else
                tinsert(post_filter, {'filter', parts[i]})
            end
        elseif not blizzard_filter_parser(parts[i], i) then
	        if parts[i] ~= '' then
		        tinsert(post_filter, {'filter', 'tooltip', parts[i]})
	        else
	            return nil, 'Empty modifier'
	        end
        end
        i = i + 1
    end

    return {blizzard=blizzard_filter_parser(), post=post_filter}
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
    for _, str in parts do
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
    local suggestions = {}

    if components.blizzard.name and aux.util.size(components.blizzard) == 1 then
        tinsert(suggestions, 'exact')
    end

    tinsert(suggestions, 'and')
    tinsert(suggestions, 'or')
    tinsert(suggestions, 'not')
    tinsert(suggestions, 'tt')

    for filter, _ in m.filters do
        tinsert(suggestions, filter)
    end

    -- classes
    if not components.blizzard.class then
        for _, class in {GetAuctionItemClasses()} do
            tinsert(suggestions, class)
        end
    end

    -- subclasses
    if not components.blizzard.subclass then
        for _, subclass in {GetAuctionItemSubClasses(aux.index(components.blizzard.class, 2) or 0)} do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    if not components.blizzard.slot then
        for _, invtype in {GetAuctionInvTypes(aux.index(components.blizzard.class, 2) or 0, aux.index(components.blizzard.subclass, 2) or 0)} do
            tinsert(suggestions, getglobal(invtype))
        end
    end

    -- usable
    if not components.blizzard.usable then
        tinsert(suggestions, 'usable')
    end

    -- rarities
    if not components.blizzard.quality then
        for i=0,4 do
            tinsert(suggestions, getglobal('ITEM_QUALITY'..i..'_DESC'))
        end
    end

    -- item names
    if aux.util.size(components.blizzard) + getn(components.post) == 1 and components.blizzard.name == '' then
        for _, name in aux_auctionable_items do
            tinsert(suggestions, name..'/exact')
        end
    end

    return suggestions
end

function public.query_string(components)
    local query_builder = m.query_builder()

    for _, filter in components.blizzard do
        query_builder.append((filter[2] or filter[1]))
    end

    for _, component in components.post do
        if component[1] == 'operator' then
            query_builder.append(component[2]..(component[2] ~= 'not' and tonumber(component[3]) or ''))
        elseif component[1] == 'filter' then
            query_builder.append(component[2])
            for _, parameter in {component[3]} do
	            if aux.filter.filters[component[2]].input_type == 'money' then
		            parameter = aux.money.to_string(aux.money.from_string(parameter), nil, true, nil, nil, true)
	            end
                query_builder.append(parameter)
            end
        end
    end

    return query_builder.get()
end

function private.prettified_query_string(components)
    local prettified = m.query_builder()

    for key, filter in components.blizzard do
        if key == 'exact' then
            prettified.prepend(aux.info.display_name(aux.cache.item_id(components.blizzard.name[2])) or aux.gui.color.blizzard('['..components.blizzard.name[2]..']'))
        elseif key ~= 'name' then
            prettified.append(aux.gui.color.blizzard(filter[1]))
        end
    end

    if components.blizzard.name and not components.blizzard.exact and components.blizzard.name[2] ~= '' then
        prettified.prepend(aux.gui.color.blizzard(components.blizzard.name[2]))
    end

    for _, component in components.post do
        if component[1] == 'operator' then
			prettified.append(aux.gui.color.aux(component[2]..(component[2] ~= 'not' and tonumber(component[3]) or '')))
        elseif component[1] == 'filter' then
            if component[2] ~= 'tooltip' then
                prettified.append(aux.gui.color.aux(component[2]))
            end
            for parameter in aux.util.present(component[3]) do
	            if component[2] == 'item' then
		            prettified.append(aux.info.display_name(aux.cache.item_id(parameter)) or aux.gui.color.label.enabled('['..parameter..']'))
	            else
		            if m.filters[component[2]].input_type == 'money' then
			            prettified.append(aux.money.to_string(aux.money.from_string(parameter), nil, true, nil, aux.gui.inline_color.label.enabled))
		            else
			            prettified.append(aux.gui.color.label.enabled(parameter))
		            end
	            end
            end
        end
    end
    if prettified.get() == '' then
        return aux.gui.color.blizzard'<>'
    else
        return prettified.get()
    end
end

function public.quote(name)
    return '<'..name..'>'
end

function public.unquote(name)
    return aux.util.select(3, strfind(name, '^<(.*)>$')) or name
end

function private.blizzard_query(components)
    local filters = components.blizzard

    local query = {name=filters.name and filters.name[2]}

    local item_info, class_index, subclass_index, slot_index
    if filters.exact and aux.temp(aux.cache.item_id(filters.name[2])) and __(aux.info.item(__.item_id)) then
	    item_info = __.item_info
        class_index = aux.info.item_class_index(item_info.class)
        subclass_index = aux.info.item_subclass_index(class_index or 0, item_info.subclass)
        slot_index = aux.info.item_slot_index(class_index or 0, subclass_index or 0, item_info.slot)
    end

    if item_info then
        query.min_level = item_info.level
        query.max_level = item_info.level
        query.usable = item_info.usable
        query.class = class_index
        query.subclass = subclass_index
        query.slot = slot_index
        query.quality = item_info.quality
    else
	    for _, key in {'min_level', 'max_level', 'class', 'subclass', 'slot', 'usable', 'quality'} do
            query[key] = aux.index(filters[key], 2)
	    end
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
        if components.blizzard.exact and strlower(aux.info.item(record.item_id).name) ~= components.blizzard.name[2] then
            return false
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
                    tinsert(stack, aux.util.all(args))
                elseif name == 'or' then
                    tinsert(stack, aux.util.any(args))
                end
            elseif type == 'filter' then
                tinsert(stack, validators[i](record) and true or false)
            end
        end
        return aux.util.all(stack)
    end
end

function public.query_builder()
    local filter
    return {
        appended = function(part)
            return m.query_builder(not filter and part or filter..'/'..part)
        end,
        prepended = function(part)
            return m.query_builder(not filter and part or part..'/'..filter)
        end,
        append = function(part)
            filter = not filter and part or filter..'/'..part
        end,
        prepend = function(part)
            filter = not filter and part or part..'/'..filter
        end,
        get = function()
            return filter or ''
        end
    }
end