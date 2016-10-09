module 'aux.util.filter'

include 'green_t'
include 'aux'
include 'aux.util'
include 'aux.control'
include 'aux.util.color'

local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'
local cache = require 'aux.core.cache'
local history = require 'aux.core.history'
local disenchant = require 'aux.core.disenchant'

function private.default_filter(str)
    return {
        input_type = '',
        validator = function()
            return function(auction_record)
                return any(auction_record.tooltip, function(entry)
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
                return auction_record.usable and not info.tooltip_match(ITEM_SPELL_KNOWN, auction_record.tooltip)
            end
        end,
    },

    ['tooltip'] = {
        input_type = 'string',
        validator = function(str)
            return default_filter(str).validator()
        end,
    },

    ['item'] = {
        input_type = 'string',
        validator = function(name)
            return function(auction_record)
                return strlower(info.item(auction_record.item_id).name) == name
            end
        end
    },

    ['left'] = {
        input_type = A('30m', '2h', '8h', '24h'),
        validator = function(index)
            return function(auction_record)
                return auction_record.duration == index
            end
        end
    },

    ['rarity'] = {
        input_type = A('poor', 'common', 'uncommon', 'rare', 'epic'),
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
                return history.value(auction_record.item_key) and auction_record.unit_bid_price / history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['buy-pct'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return auction_record.unit_buyout_price > 0
                        and history.value(auction_record.item_key)
                        and auction_record.unit_buyout_price / history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['bid-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return history.value(auction_record.item_key) and history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and history.value(auction_record.item_key) and history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return disenchant_value and disenchant_value - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-dis-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return auction_record.buyout_price > 0 and disenchant_value and disenchant_value - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = cache.merchant_info(auction_record.item_id)
                return vendor_price and vendor_price * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['buy-vend-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = cache.merchant_info(auction_record.item_id)
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
    local operator = str == 'not' and A('operator', 'not', 1)
    for name in temp-S('and', 'or') do
	    for arity in present(select(3, strfind(str, '^' .. name .. '(%d*)$'))) do
		    arity = tonumber(arity)
		    operator = not (arity and arity < 2) and A('operator', name, arity)
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
			if self.exact then return end
			for number in present(tonumber(select(3, strfind(str, '^(%d+)$')))) do
				if number >= 1 and number <= 60 then
					for _, key in temp-A('min_level', 'max_level') do
						if not self[key] then
							self[key] = A(str, number)
							return A('blizzard', key, str, number)
						end
					end
				end
			end
			for _, parser in temp-A(
				temp-A('class', info.item_class_index),
				temp-A('subclass', papply(info.item_subclass_index, index(self.class, 2) or 0)),
				temp-A('slot', papply(info.item_slot_index, index(self.class, 2) or 0, index(self.subclass, 2) or 0)),
				temp-A('quality', info.item_quality_index)
			) do
				if not self[parser[1]] then
					tinsert(parser, str)
					local index, label = parser[2](select(3, unpack(parser)))
					if index then
						self[parser[1]] = A(label, index)
						return A('blizzard', parser[1], label, index)
					end
				end
			end
			if not self[str] and (str == 'usable' or str == 'exact' and self.name and size(self) == 1) then
				self[str] = A(str, 1)
				return A('blizzard', str, str, 1)
			elseif i == 1 and strlen(str) <= 63 then
				self.name = A(str, unquote(str))
				return A('blizzard', 'name', str, unquote(str))
--				return nil, 'The name filter must not be longer than 63 characters' TODO
			end
		end,
	}
	function private.blizzard_filter_parser()
	    return setmetatable(t, mt)
	end
end

function private.parse_parameter(input_type, str)
    if input_type == 'money' then
        local money = money.from_string(str)
        return money and money > 0 and money or nil
    elseif input_type == 'number' then
        local number = tonumber(str)
        return number and number > 0 and mod(number, 1) == 0 and number or nil
    elseif input_type == 'string' then
        return str ~= '' and str or nil
    elseif type(input_type) == 'table' then
        return key(str, input_type)
    end
end

function public.parse_filter_string(str)
    local filter, post_filter = t, t
    local blizzard_filter_parser = blizzard_filter_parser()

    local parts = str and map(split(str, '/'), function(part) return strlower(trim(part)) end) or t

    local i = 1
    while parts[i] do
	    local operator = operator(parts[i])
        if operator then
            tinsert(post_filter, operator)
	        tinsert(filter, operator)
        elseif filters[parts[i]] then
            local input_type = filters[parts[i]].input_type
            if input_type ~= '' then
                if not parts[i + 1] or not parse_parameter(input_type, parts[i + 1]) then
                    if parts[i] == 'item' then
                        return nil, 'Invalid item name', aux_auctionable_items
                    elseif type(input_type) == 'table' then
                        return nil, 'Invalid choice for ' .. parts[i], input_type
                    else
                        return nil, 'Invalid input for ' .. parts[i] .. '. Expecting: ' .. input_type
                    end
                end
                tinsert(post_filter, A('filter', parts[i], parts[i + 1]))
                i = i + 1
            else
                tinsert(post_filter, A('filter', parts[i]))
            end
            tinsert(filter, post_filter[getn(post_filter)])
        else
	        local part = blizzard_filter_parser(parts[i], i)
	        if part then
		        tinsert(filter, part)
	        elseif parts[i] ~= '' then
		        tinsert(post_filter, A('filter', 'tooltip', parts[i]))
		        tinsert(filter, post_filter[getn(post_filter)])
	        else
	            return nil, 'Empty modifier'
	        end
        end
        i = i + 1
    end

    return T('components', filter, 'blizzard', blizzard_filter_parser(), 'post', post_filter)
end

function public.query(filter_string)
    local filter, error, suggestions = parse_filter_string(filter_string)

    if not filter then
        return nil, suggestions or t, error
    end

    local polish_notation_counter = 0
    for _, component in filter.post do
        if component[1] == 'operator' then
            polish_notation_counter = max(polish_notation_counter, 1)
            polish_notation_counter = polish_notation_counter + (tonumber(component[2]) or 1) - 1
        elseif component[1] == 'filter' then
            polish_notation_counter = polish_notation_counter - 1
        end
    end

    if polish_notation_counter > 0 then
        local suggestions = t
        for key in filters do
            tinsert(suggestions, strlower(key))
        end
        tinsert(suggestions, 'and')
        tinsert(suggestions, 'or')
        tinsert(suggestions, 'not')
        return nil, suggestions, 'Malformed expression'
    end

    return {
        blizzard_query = blizzard_query(filter),
        validator = validator(filter),
        prettified = prettified_filter_string(filter),
    }, _M.suggestions(filter)
end

function public.queries(filter_string)
    local parts = split(filter_string, ';')
    local queries = t
    for _, str in parts do
        str = trim(str)
        local query, _, error = query(str)
        if not query then
	        return nil, error
        else
            tinsert(queries, query)
        end
    end
    return queries
end

function private.suggestions(filter)
    local suggestions = t

    if filter.blizzard.name and size(filter.blizzard) == 1 then tinsert(suggestions, 'exact') end

    tinsert(suggestions, 'and'); tinsert(suggestions, 'or'); tinsert(suggestions, 'not'); tinsert(suggestions, 'tooltip')

    for key in filters do tinsert(suggestions, key) end

    -- classes
    if not filter.blizzard.class then
        for _, class in temp-A(GetAuctionItemClasses()) do tinsert(suggestions, class) end
    end

    -- subclasses
    if not filter.blizzard.subclass then
        for _, subclass in temp-A(GetAuctionItemSubClasses(index(filter.blizzard.class, 2) or 0)) do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    if not filter.blizzard.slot then
        for _, invtype in temp-A(GetAuctionInvTypes(index(filter.blizzard.class, 2) or 0, index(filter.blizzard.subclass, 2) or 0)) do
            tinsert(suggestions, _G[invtype])
        end
    end

    -- usable
    if not filter.blizzard.usable then tinsert(suggestions, 'usable') end

    -- rarities
    if not filter.blizzard.quality then
        for i = 0, 4 do tinsert(suggestions, _G['ITEM_QUALITY' .. i..'_DESC']) end
    end

    -- item names
    if getn(filter.components) == 0 then
        for _, name in aux_auctionable_items do
            tinsert(suggestions, name .. '/exact')
        end
    end

    return suggestions
end

function public.filter_string(components)
    local query_builder = query_builder()

    for _, component in components do
	    if component[1] == 'blizzard' then
		    query_builder.append(filter[4] or filter[3])
        elseif component[1] == 'operator' then
            query_builder.append(component[2] .. (component[2] ~= 'not' and tonumber(component[3]) or ''))
        elseif component[1] == 'filter' then
            query_builder.append(component[2])
            for parameter in present(component[3]) do
	            if filter_util.filters[component[2]].input_type == 'money' then
		            parameter = money.to_string(money.from_string(parameter), nil, true, nil, nil, true)
	            end
                query_builder.append(parameter)
            end
        end
    end

    return query_builder.get()
end

function private.prettified_filter_string(filter)
    local prettified = query_builder()

    for _, component in filter.components do
	    if component[1] == 'blizzard' then
		    if component[2] == 'name' then
			    if filter.blizzard.exact then
			        prettified.append(info.display_name(cache.item_id(component[4])) or color.orange('[' .. component[4] .. ']'))
			    elseif component[4] ~= '' then
				    prettified.append(color.orange(component[4]))
			    end
		    elseif component[2] ~= 'exact' then
			    prettified.append(color.orange(component[3]))
		    end
        elseif component[1] == 'operator' then
			prettified.append(color.orange(component[2] .. (component[2] ~= 'not' and tonumber(component[3]) or '')))
        elseif component[1] == 'filter' then
            if component[2] ~= 'tooltip' then
                prettified.append(color.orange(component[2]))
            end
            for parameter in present(component[3]) do
	            if component[2] == 'item' then
		            prettified.append(info.display_name(cache.item_id(parameter)) or color.label.enabled('[' .. parameter .. ']'))
	            else
		            if filters[component[2]].input_type == 'money' then
			            prettified.append(money.to_string(money.from_string(parameter), nil, true, nil, inline_color.label.enabled))
		            else
			            prettified.append(color.label.enabled(parameter))
		            end
	            end
            end
        end
    end
    if prettified.get() == '' then
        return color.orange'<>'
    else
        return prettified.get()
    end
end

function public.quote(name)
    return '<' .. name .. '>'
end

function public.unquote(name)
    return select(3, strfind(name, '^<(.*)>$')) or name
end

function private.blizzard_query(filter)
    local filters = filter.blizzard
    local query = T('name', filters.name and filters.name[2])
    local item_info, class_index, subclass_index, slot_index
    local item_id = filters.name and cache.item_id(filters.name[2])
    item_info = item_id and info.item(item_id)
    if filters.exact and item_info then
	    item_info = info.item(item_id)
        class_index = info.item_class_index(item_info.class)
        subclass_index = info.item_subclass_index(class_index or 0, item_info.subclass)
        slot_index = info.item_slot_index(class_index or 0, subclass_index or 0, item_info.slot)
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
	    for key in temp-S('min_level', 'max_level', 'class', 'subclass', 'slot', 'usable', 'quality') do
            query[key] = index(filters[key], 2)
	    end
    end
    return query
end

function private.validator(filter)

    local validators = t
    for i, component in filter.post do
	    local type, name, param = unpack(component)
        if type == 'filter' then
            validators[i] = filters[name].validator(parse_parameter(filters[name].input_type, param))
        end
    end

    return function(record)
        if filter.blizzard.exact and strlower(info.item(record.item_id).name) ~= filter.blizzard.name[2] then
            return false
        end
        local stack = tt
        for i = getn(filter.post), 1, -1 do
            local type, name, param = unpack(filter.post[i])
            if type == 'operator' then
                local args = tt
                while (not param or param > 0) and getn(stack) > 0 do
                    tinsert(args, tremove(stack))
                    param = param and param - 1
                end
                if name == 'not' then
                    tinsert(stack, not args[1])
                elseif name == 'and' then
                    tinsert(stack, all(args))
                elseif name == 'or' then
                    tinsert(stack, any(args))
                end
            elseif type == 'filter' then
                tinsert(stack, validators[i](record) and true or false)
            end
        end
        return all(stack)
    end
end

function public.query_builder()
    local filter
    return T(
		'append', function(part)
            filter = not filter and part or filter .. '/' .. part
        end,
		'get', function()
            return filter or ''
        end
    )
end