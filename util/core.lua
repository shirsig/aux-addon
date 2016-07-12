local private, public = {}, {}
Aux.util = public

function Aux.util.pass()
end

function public.id(object)
	return object
end

function public.table_eq(t1, t2)
	if not t1 or not t2 then
		return false
	end

	for key, value in t1 do
		if t2[key] ~= value then
			return false
		end
	end

	return true
end

function public.wipe(table)
	while getn(table) > 0 do
		tremove(table)
	end
	for k, _ in pairs(table) do
		table[k] = nil
	end
end

function public.copy_table(table)
	local copy = {}
	for k, v in pairs(table) do
		copy[k] = v
	end
	return copy
end

function public.cons(element, list)
	local new_list = public.copy_table(list)
	tinsert(new_list, 1, element)
	return new_list
end

function public.trim(string)
	string = gsub(string, '^%s*', '')
	string = gsub(string, '%s*$', '')
	return string
end

function public.inventory()
	local bag, slot = 0, 0

	return function()
		if not GetBagName(bag) or slot >= GetContainerNumSlots(bag) then
			repeat
				bag = bag + 1
			until GetBagName(bag) or bag > 4
			slot = 1
		else
			slot = slot + 1
		end

		if bag <= 4 then
			return { bag, slot }, public.bag_type(bag)
		end
	end
end

do
	local bag_types = { GetAuctionItemSubClasses(3) }

	function public.bag_type(bag)
		if bag == 0 then
			return 1
		end

		local link = GetInventoryItemLink('player', ContainerIDToInventoryID(bag))
		if link then
			local item_id = Aux.info.parse_hyperlink(GetInventoryItemLink('player', ContainerIDToInventoryID(bag)))
			local item_info = Aux.info.item(item_id)
			return Aux.item_subclass_index(3, item_info.subclass)
		end
	end
end

function public.safe_index(...)
	local target = arg[1]

	for i=2,arg.n do
		if not target then
			return
		end
		target = target[arg[i]]
	end

	return target
end

function Aux_PluralizeIf(word, count)

    if count and count == 1 then
        return word
    else
        return word..'s'
    end
end

function Aux.util.without_errors(f)
    local orig = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = Aux.util.pass
    f()
    UIErrorsFrame.AddMessage = orig
end

function Aux.util.without_sound(f)
    local orig = GetCVar('MasterSoundEffects')
    SetCVar('MasterSoundEffects', 0)
    f()
    SetCVar('MasterSoundEffects', orig)
end

function Aux.util.iter(array)
	local with_index = ipairs(array)
	return function()
		local _, value = with_index
		return value
	end
end

function Aux.util.set_add(set, key)
    set[key] = true
end

function Aux.util.set_remove(set, key)
    set[key] = nil
end

function Aux.util.set_contains(set, key)
    return set[key] ~= nil
end

function Aux.util.set_size(set)
    local size = 0
	for _,_ in pairs(set) do
		size = size + 1
	end
	return size
end

function Aux.util.set_to_array(set)
	local array = {}
	for element, _ in pairs(set) do
		tinsert(array, element)
	end
	return array
end

function Aux.util.any(xs, p)
	holds = false
	for _, x in ipairs(xs) do
		holds = holds or p(x)
	end
	return holds
end

function Aux.util.all(xs, p)
	holds = true
	for _, x in ipairs(xs) do
		holds = holds and p(x)
	end
	return holds
end

function Aux.util.set_filter(xs, p)
	ys = {}
	for x, _ in pairs(xs) do
		if p(x) then
			Aux.util.set_add(ys, x)
		end
	end
	return ys
end

function Aux.util.filter(xs, p)
	ys = {}
	for _, x in ipairs(xs) do
		if p(x) then
			tinsert(ys, x)
		end
	end
	return ys
end

function Aux.util.map(xs, f)
	ys = {}
	for _, x in ipairs(xs) do
		tinsert(ys, f(x))
	end
	return ys
end

function Aux.util.take(n, xs)
	ys = {}
	for i=1,n do
		if xs[i] then
			tinsert(ys, xs[i])
		end
	end
	return ys
end

function Aux.util.index_of(value, array)
	for i, item in ipairs(array) do
		if item == value then
			return i
		end
	end
end

local GSC_GOLD = "ffd100"
local GSC_SILVER = "e6e6e6"
local GSC_COPPER = "c8602c"
local GSC_RED = "ff0000"

local GSC_3 = "|cff"..GSC_GOLD.."%d|cff000000.|cff"..GSC_SILVER.."%02d|cff000000.|cff"..GSC_COPPER.."%02d|r"
local GSC_2 = "|cff"..GSC_SILVER.."%d|cff000000.|cff"..GSC_COPPER.."%02d|r"
local GSC_1 = "|cff"..GSC_COPPER.."%d|r"

local GSC_3N = "|cff"..GSC_RED.."(|cff"..GSC_GOLD.."%d|cff000000.|cff"..GSC_SILVER.."%02d|cff000000.|cff"..GSC_COPPER.."%02d|cff"..GSC_RED..")|r"
local GSC_2N = "|cff"..GSC_RED.."(|cff"..GSC_SILVER.."%d|cff000000.|cff"..GSC_COPPER.."%02d|cff"..GSC_RED..")|r"
local GSC_1N = "|cff"..GSC_RED.."(|cff"..GSC_COPPER.."%d|cff"..GSC_RED..")|r"

function Aux.util.money_string(money)
	money = floor(tonumber(money) or 0)
	local negative = money < 0
	money = abs(money)

	local g = floor(money / 10000)
	money = money - g * 10000
	local s = floor(money / 100)
	money = money - s * 100
	local c = money

	if g > 0 then
		if negative then
			return format(GSC_3N, g, s, c)
		else
			return format(GSC_3, g, s, c)
		end
	elseif s > 0 then
		if negative then
			return format(GSC_2N, s, c)
		else
			return format(GSC_2, s, c)
		end
	else
		if negative then
			return format(GSC_1N, c)
		else
			return format(GSC_1, c)
		end
	end
end

function Aux.util.group_by(tables, equal)
	local groups = {}
	for _, table in ipairs(tables) do
        local found_group
		for _, group in ipairs(groups) do
			if equal(table, group[1]) then
				tinsert(group, table)
                found_group = true
			end
        end
        if not found_group then
		    tinsert(groups, { table })
        end
	end
	return groups
end

function Aux.util.set()
    local self = {}

    local data = {}

    function self:add(value)
        data[value] = true
    end

    function self:add_all(values)
        for _, value in ipairs(values) do
            self:add(value)
        end
    end

    function self:remove(value)
        data[value] = nil
    end

    function self:remove_all(values)
        for _, value in ipairs(values) do
            self:remove(value)
        end
    end

    function self:contains(value)
        return data[value] ~= nil
    end

    function self:values()
        local values = {}
        for value, _ in pairs(data) do
            tinsert(values, value)
        end
        return values
    end

    return self
end

function public.join(array, separator)
	local str = ''
	for i, element in ipairs(array) do
		if i > 1 then
			str = str..separator
		end
		str = str..element
	end
	return str
end

function public.tokenize(str)
	local tokens = {}
	for token in string.gfind(str, '%S+') do
		tinsert(tokens, token)
	end
	return tokens
end

function public.split(str, separator)

	local array = {}
	while true do
		local start_index, _ = strfind(str, separator, 1, true)

		if start_index then
			local part = strsub(str, 1, start_index - 1)
			tinsert(array, part)
			str = strsub(str, start_index + 1)
		else
			local part = strsub(str, 1)
			tinsert(array, part)
			return array
		end
	end
end

function public.format_money(money, exact, color)
	color = color or '|r'

	local TEXT_NONE = '0'

	local GSC_GOLD = 'ffd100'
	local GSC_SILVER = 'e6e6e6'
	local GSC_COPPER = 'c8602c'
	local GSC_START = '|cff%s%d|r'
	local GSC_PART = color..'.|cff%s%02d|r'
	local GSC_NONE = '|cffa0a0a0'..TEXT_NONE..'|r'

	if not exact and money >= 10000 then
		-- Round to nearest silver
		money = math.floor(money / 100 + 0.5) * 100
	end
	local g, s, c = Aux.money.to_GSC(money)

	local gsc = ''

	local fmt = GSC_START
	if g > 0 then
		gsc = gsc..string.format(fmt, GSC_GOLD, g)
		fmt = GSC_PART
	end
	if s > 0 or c > 0 then
		gsc = gsc..string.format(fmt, GSC_SILVER, s)
		fmt = GSC_PART
	end
	if c > 0 then
		gsc = gsc..string.format(fmt, GSC_COPPER, c)
	end
	if gsc == '' then
		gsc = GSC_NONE
	end
	return gsc
end