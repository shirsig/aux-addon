module 'aux.util.filter'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'
local history = require 'aux.core.history'
local disenchant = require 'aux.core.disenchant'

function default_filter(str)
    return {
        input_type = '',
        validator = function()
            return function(auction_record)
                return aux.any(auction_record.tooltip, function(entry)
                    return strfind(strlower(entry.left_text or ''), str, 1, true) or strfind(strlower(entry.right_text or ''), str, 1, true)
                end)
            end
        end,
    }
end

M.filters = {

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
        input_type = T.list('30m', '2h', '8h', '24h'),
        validator = function(index)
            return function(auction_record)
                return auction_record.duration == index
            end
        end
    },

    ['rarity'] = {
        input_type = T.list('poor', 'common', 'uncommon', 'rare', 'epic'),
        validator = function(index)
            return function(auction_record)
                return auction_record.quality == index - 1
            end
        end
    },

    ['min-level'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level >= level
            end
        end
    },

    ['max-level'] = {
        input_type = 'number',
        validator = function(level)
            return function(auction_record)
                return auction_record.level <= level
            end
        end
    },

    ['bid-price'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.unit_bid_price <= amount
            end
        end
    },

    ['price'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and auction_record.unit_buyout_price <= amount
            end
        end
    },

    ['bid-percent'] = {
        input_type = 'number',
        validator = function(pct)
            return function(auction_record)
                return history.value(auction_record.item_key) and auction_record.unit_bid_price / history.value(auction_record.item_key) * 100 <= pct
            end
        end
    },

    ['percent'] = {
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

    ['profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                return auction_record.buyout_price > 0 and history.value(auction_record.item_key) and history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-disenchant-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return disenchant_value and disenchant_value - auction_record.bid_price >= amount
            end
        end
    },

    ['disenchant-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local disenchant_value = disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                return auction_record.buyout_price > 0 and disenchant_value and disenchant_value - auction_record.buyout_price >= amount
            end
        end
    },

    ['bid-vendor-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = info.merchant_info(auction_record.item_id)
                return vendor_price and vendor_price * auction_record.aux_quantity - auction_record.bid_price >= amount
            end
        end
    },

    ['vendor-profit'] = {
        input_type = 'money',
        validator = function(amount)
            return function(auction_record)
                local vendor_price = info.merchant_info(auction_record.item_id)
                return auction_record.buyout_price > 0 and vendor_price and vendor_price * auction_record.aux_quantity - auction_record.buyout_price >= amount
            end
        end
    },

    ['seller'] = {
        input_type = 'string',
        validator = function(name)
            return function(auction_record)
                return auction_record.owner and strupper(name) == strupper(auction_record.owner)
            end
        end
    },
}

function operator(str)
    local operator = str == 'not' and T.list('operator', 'not', 1)
    for name in pairs(T.temp-T.set('and', 'or')) do
	    local arity = aux.select(3, strfind(str, '^' .. name .. '(%d*)$'))
	    if arity then
		    arity = tonumber(arity)
		    operator = not (arity and arity < 2) and T.list('operator', name, arity)
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
			local number = tonumber(aux.select(3, strfind(str, '^(%d+)$')))
			if number then
				if number >= 1 and number <= 60 then
					for _, key in ipairs(T.temp-T.list('min_level', 'max_level')) do
						if not self[key] then
							self[key] = T.list(str, number)
							return T.list('blizzard', key, str, number)
						end
					end
				end
			end
			for _, parser in pairs(T.temp-T.list(
				T.temp-T.list('class', info.item_class_index),
				T.temp-T.list('subclass', T.vararg-function(arg) return info.item_subclass_index(aux.index(self.class, 2) or 0, unpack(arg)) end),
				T.temp-T.list('slot', T.vararg-function(arg) return info.item_slot_index(aux.index(self.class, 2) == 2 and 2 or 0, aux.index(self.subclass, 2) or 0, unpack(arg)) end),
				T.temp-T.list('quality', info.item_quality_index)
			)) do
				if not self[parser[1]] then
					tinsert(parser, str)
					local index, label = parser[2](aux.select(3, unpack(parser)))
					if index then
						self[parser[1]] = T.list(label, index)
						return T.list('blizzard', parser[1], label, index)
					end
				end
			end
			if not self[str] and (str == 'usable' or str == 'exact' and self.name and aux.size(self) == 1) then
				self[str] = T.list(str, 1)
				return T.list('blizzard', str, str, 1)
			elseif i == 1 and strlen(str) <= 63 then
				self.name = unquote(str)
				return T.list('blizzard', 'name', unquote(str), str)
--				return nil, 'The name filter must not be longer than 63 characters' TODO
			end
		end,
	}
	function blizzard_filter_parser()
	    return setmetatable(T.acquire(), mt)
	end
end

function parse_parameter(input_type, str)
    if input_type == 'money' then
        local money = money.from_string(str)
        return money and money > 0 and money or nil
    elseif input_type == 'number' then
        local number = tonumber(str)
        return number and number > 0 and mod(number, 1) == 0 and number or nil
    elseif input_type == 'string' then
        return str ~= '' and str or nil
    elseif type(input_type) == 'table' then
        return aux.key(input_type, str)
    end
end

function M.parse_filter_string(str)
    local filter, post_filter = T.acquire(), T.acquire()
    local blizzard_filter_parser = blizzard_filter_parser()

    local parts = str and aux.map(aux.split(str, '/'), function(part) return strlower(aux.trim(part)) end) or T.acquire()

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
                        return nil, 'Invalid item name', aux.account_data.auctionable_items
                    elseif type(input_type) == 'table' then
                        return nil, 'Invalid choice for ' .. parts[i], input_type
                    else
                        return nil, 'Invalid input for ' .. parts[i] .. '. Expecting: ' .. input_type
                    end
                end
                tinsert(post_filter, T.list('filter', parts[i], parts[i + 1]))
                i = i + 1
            else
                tinsert(post_filter, T.list('filter', parts[i]))
            end
            tinsert(filter, post_filter[getn(post_filter)])
        else
	        local part = blizzard_filter_parser(parts[i], i)
	        if part then
		        tinsert(filter, part)
	        elseif parts[i] ~= '' then
		        tinsert(post_filter, T.list('filter', 'tooltip', parts[i]))
		        tinsert(filter, post_filter[getn(post_filter)])
	        else
	            return nil, 'Empty modifier'
	        end
        end
        i = i + 1
    end

    return T.map('components', filter, 'blizzard', blizzard_filter_parser(), 'post', post_filter)
end

function M.query(filter_string)
    local filter, error, suggestions = parse_filter_string(filter_string)

    if not filter then
        return nil, suggestions or T.acquire(), error
    end

    local polish_notation_counter = 0
    for _, component in ipairs(filter.post) do
        if component[1] == 'operator' then
            polish_notation_counter = max(polish_notation_counter, 1)
            polish_notation_counter = polish_notation_counter + (tonumber(component[2]) or 1) - 1
        elseif component[1] == 'filter' then
            polish_notation_counter = polish_notation_counter - 1
        end
    end

    if polish_notation_counter > 0 then
        local suggestions = T.acquire()
        for key in ipairs(filters) do
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

function M.queries(filter_string)
    local parts = aux.split(filter_string, ';')
    local queries = T.acquire()
    for _, str in ipairs(parts) do
        local query, _, error = query(str)
        if not query then
	        return nil, error
        else
            tinsert(queries, query)
        end
    end
    return queries
end

function suggestions(filter)
    local suggestions = T.acquire()

    if filter.blizzard.name and aux.size(filter.blizzard) == 1 then tinsert(suggestions, 'exact') end

    tinsert(suggestions, 'and'); tinsert(suggestions, 'or'); tinsert(suggestions, 'not'); tinsert(suggestions, 'tooltip')

    for key in ipairs(filters) do tinsert(suggestions, key) end

    -- classes
    if not filter.blizzard.class then
        for i = 1, 19 do tinsert(suggestions, GetItemClassInfo(i)) end
    end

    -- subclasses
    if not filter.blizzard.subclass then
        for _, subclass in ipairs(T.temp-T.list(GetAuctionItemSubClasses(aux.index(filter.blizzard.class, 2) or 0))) do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    if not filter.blizzard.slot then
        for _, invtype in ipairs(T.temp-T.list(GetAuctionInvTypes(aux.index(filter.blizzard.class, 2) == 2 and 2 or 0, aux.index(filter.blizzard.subclass, 2) or 0))) do
            tinsert(suggestions, _G[invtype])
        end
    end

    -- usable
    if not filter.blizzard.usable then tinsert(suggestions, 'usable') end

    -- rarities
    if not filter.blizzard.quality then
        for i = 0, 4 do tinsert(suggestions, _G['ITEM_QUALITY' .. i .. '_DESC']) end
    end

    -- item names
    if getn(filter.components) == 0 then
	    for _, name in ipairs(aux.account_data.auctionable_items) do
            tinsert(suggestions, name .. '/exact')
        end
    end

    return suggestions
end

function M.filter_string(components)
    local query_builder = query_builder()
    for _, component in ipairs(components) do
	    if component[1] == 'blizzard' then
		    query_builder.append(component[4] or component[3])
        elseif component[1] == 'operator' then
            query_builder.append(component[2] .. (component[2] ~= 'not' and tonumber(component[3]) or ''))
        elseif component[1] == 'filter' then
            query_builder.append(component[2])
            local parameter = component[3]
            if parameter then
	            if filter_util.filters[component[2]].input_type == 'money' then
		            parameter = money.to_string(money.from_string(parameter), nil, true, nil, true)
	            end
                query_builder.append(parameter)
            end
        end
    end
    return query_builder.get()
end

function prettified_filter_string(filter)
    local prettified = query_builder()
    for i, component in ipairs(filter.components) do
	    if component[1] == 'blizzard' then
		    if component[2] == 'name' then
			    if filter.blizzard.exact then
			        prettified.append(info.display_name(info.item_id(component[3])) or aux.color.orange('[' .. component[3] .. ']'))
			    elseif component[3] ~= '' then
				    prettified.append(aux.color.label.enabled(component[3]))
			    end
		    elseif component[2] ~= 'exact' then
			    prettified.append(aux.color.orange(component[3]))
		    end
        elseif component[1] == 'operator' then
			prettified.append(aux.color.orange(component[2] .. (component[2] ~= 'not' and tonumber(component[3]) or '')))
        elseif component[1] == 'filter' then
            if i == 1 or component[2] ~= 'tooltip' then
                prettified.append(aux.color.orange(component[2]))
            end
            local parameter = component[3]
            if parameter then
	            if component[2] == 'item' then
		            prettified.append(info.display_name(info.item_id(parameter)) or aux.color.label.enabled('[' .. parameter .. ']'))
	            else
		            if filters[component[2]].input_type == 'money' then
			            prettified.append(money.to_string(money.from_string(parameter), nil, true, aux.color.label.enabled))
		            else
			            prettified.append(aux.color.label.enabled(parameter))
		            end
	            end
            end
        end
    end
    if prettified.get() == '' then
        return aux.color.orange'<>'
    else
        return prettified.get()
    end
end

function M.quote(name)
    return '<' .. name .. '>'
end

function M.unquote(name)
	return aux.select(3, strfind(name, '^<(.*)>$')) or name
end

function blizzard_query(filter)
    local filters = filter.blizzard
    local query = T.map('name', filters.name)
    local item_info, class_index, subclass_index, slot_index
    local item_id = filters.name and info.item_id(filters.name)
    item_info = item_id and info.item(item_id)
    if filters.exact and item_info then
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
	    for key in ipairs(T.temp-T.set('min_level', 'max_level', 'class', 'subclass', 'slot', 'usable', 'quality')) do
            query[key] = aux.index(filters[key], 2)
	    end
    end
    return query
end

function validator(filter)
    local validators = T.acquire()
    for i, component in pairs(filter.post) do
	    local type, name, param = unpack(component)
        if type == 'filter' then
            validators[i] = filters[name].validator(parse_parameter(filters[name].input_type, param))
        end
    end
    return function(record)
        if filter.blizzard.exact and strlower(info.item(record.item_id).name) ~= filter.blizzard.name then
            return false
        end
        local stack = T.temp-T.acquire()
        for i = getn(filter.post), 1, -1 do
            local type, name, param = unpack(filter.post[i])
            if type == 'operator' then
                local args = T.temp-T.acquire()
                while (not param or param > 0) and getn(stack) > 0 do
                    tinsert(args, tremove(stack))
                    param = param and param - 1
                end
                if name == 'not' then
                    tinsert(stack, not args[1])
                elseif name == 'and' then
                    tinsert(stack, aux.all(args))
                elseif name == 'or' then
                    tinsert(stack, aux.any(args))
                end
            elseif type == 'filter' then
                tinsert(stack, not not validators[i](record))
            end
        end
        return aux.all(stack)
    end
end

function M.query_builder()
    local filter
    return T.map(
		'append', function(part)
            filter = not filter and part or filter .. '/' .. part
        end,
		'get', function()
            return filter or ''
        end
    )
end