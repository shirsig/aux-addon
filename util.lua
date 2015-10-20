Aux.util = {}

Aux.util.LT = {}
Aux.util.EQ = {}
Aux.util.GT = {}

local merge, copy_array

function Aux.util.pass()
end

function Aux.util.iter(array)
	local with_index = ipairs(array)
	return function()
		local _, value = with_index
		return value
	end
end

function Aux.util.format_money(val)

	local g = math.floor(val / 10000)
	
	val = val - g * 10000
	
	local s = math.floor(val / 100)
	
	val = val - s * 100
	
	local c = math.floor(val)
	
	local g_string = g ~= 0 and g .. 'g' or ''
	local s_string = s ~= 0 and s .. 's' or ''
	local c_string = (c ~= 0 or g == 0 and s == 0) and c .. 'c' or ''
			
	return g_string .. s_string .. c_string
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

function Aux.util.merge_sort(A, comp)
	local n = getn(A)
	local B = {}
	
	local width = 1
	while width <= n do

		for i=1, n, 2 * width do
			merge(A, i, min(i + width, n), min(i + 2 * width - 1, n), B, comp)
        end
	  
		copy_array(B, A, n)
  
		width = 2 * width
    end
end

function merge(A, start1, start2, last, B, comp)
	local i1 = start1
	local i2 = start2

	for i=start1,last do
		if i1 < start2 and (i2 > last or comp(A[i1], A[i2]) == Aux.util.LT or comp(A[i1], A[i2]) == Aux.util.EQ) then
			B[i] = A[i1]
			i1 = i1 + 1
		else
			B[i] = A[i2]
			i2 = i2 + 1
		end
	end
end

function copy_array(A, B, n)
    for i=1,n do
        B[i] = A[i]
	end
end

function Aux.util.invert_order(ordering)
	if ordering == Aux.util.LT then
		return Aux.util.GT
	elseif ordering == Aux.util.GT then
		return Aux.util.LT
	else
		return Aux.util.EQ
	end
end

function Aux.util.compare(a, b, nil_ordering)
	nil_ordering = nil_ordering or Aux.util.EQ
	if not a and b then
		return nil_ordering
	elseif a and not b then
		return Aux.util.invert_order(nil_ordering)
	elseif not a and not b then
		return Aux.util.EQ
	elseif a < b then
		return Aux.util.LT
	elseif a > b then
		return Aux.util.GT
	else
		return Aux.util.EQ
	end
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
