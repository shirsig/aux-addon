aux.module 'util'

function public.present(...)
	local called
	return function()
		if not called then
			called = true
			return unpack(arg)
		end
	end
end

function public.expand(array, ...)
	local table = {}
	for i=1,arg.n do
		table[arg[i]] = array[i]
	end
	return table
end

function public.select(i, ...)
	while i > 1 do
		i = i - 1
		tremove(arg, i)
	end
	return tremove(arg, 1), unpack(arg)
end

function public.size(t)
	local size = 0
	for _ in t do
		size = size + 1
	end
	return size
end

function public.key(value, t)
	for k, v in t do
		if v == value then
			return k
		end
	end
end

function public.keys(t)
	local ks = {}
	for k in t do
		tinsert(ks, k)
	end
	return ks
end

function public.values(t)
	local vs = {}
	for _, v in t do
		tinsert(vs, v)
	end
	return vs
end

function public.eq(t1, t2)
	if not t1 or not t2 then
		return false
	end

	for key, value in t1 do
		if t2[key] ~= value then
			return false
		end
	end

	for key, value in t2 do
		if t1[key] ~= value then
			return false
		end
	end

	return true
end

function public.wipe(t)
	while getn(t) > 0 do
		tremove(t)
	end
	for k, _ in t do
		t[k] = nil
	end
end

function public.copy(t)
	local copy = {}
	for k, v in t do
		copy[k] = v
	end
	return copy
end

function public.any(xs, p)
	local holds = false
	for _, x in xs do
		if p then
			holds = holds or p(x)
		else
			holds = holds or x
		end
	end
	return holds
end

function public.all(xs, p)
	local holds = true
	for _, x in xs do
		if p then
			holds = holds and p(x)
		else
			holds = holds and x
		end
	end
	return holds
end

function public.replicate(count, value)
	local array = {}
	for i=1,count do
		tinsert(array, value)
	end
	return unpack(array)
end

function public.filter(xs, p)
	local ys = {}
	for k, x in xs do
		if p(x, k) then
			ys[k] = x
		end
	end
	return ys
end

function public.map(xs, f)
	local ys = {}
	for k, x in xs do
		ys[k] = f(x, k)
	end
	return ys
end

do
	local mt = {
		__call = function(self, key)
			return self[key]
		end,
	}

	function public.set(...)
		local self = {}
		for i=1,arg.n do
			self[arg[i]] = true
		end
		return setmetatable(self, mt)
	end
end

function public.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

function public.split(str, separator)
	local parts = {}
	while true do
		local start_index, _ = strfind(str, separator, 1, true)
		if start_index then
			local part = strsub(str, 1, start_index - 1)
			tinsert(parts, part)
			str = strsub(str, start_index + 1)
		else
			local part = strsub(str, 1)
			tinsert(parts, part)
			return parts
		end
	end
end

function public.tokenize(str)
	local tokens = {}
	for token in string.gfind(str, '%S+') do
		tinsert(tokens, token)
	end
	return tokens
end

function public.bound(lower_bound, upper_bound, number)
	return max(lower_bound, min(upper_bound, number))
end

function public.round(x)
	return floor(x + 0.5)
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
			return {bag, slot}, m.bag_type(bag)
		end
	end
end

function public.bag_type(bag)
	if bag == 0 then
		return 1
	end
	for link in present(GetInventoryItemLink('player', ContainerIDToInventoryID(bag))) do
		local item_id = aux.info.parse_link(link)
		local item_info = aux.info.item(item_id)
		return aux.info.item_subclass_index(3, item_info.subclass)
	end
end

function public.later(t0, t)
	return function()
		return GetTime() - t0 > t
	end
end

function public.signal()
	local params
	return function(...)
		params = arg
	end,
	function()
		return params
	end
end