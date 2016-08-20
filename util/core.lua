aux.module 'util'

local temp, getn = g.aux.temp, g.getn

function public.copy(t)
	local copy = {}
	for k, v in t do copy[k] = v end
	setn(getn(t))
	return copy
end

do
	local value, charges
	local function setter(n)
		return function(v)
			assert(charges == 0)
			value, charges = v, n
			return v
		end
	end
	for i=1,9 do public[join(replicate(i, 'x'))] = setter(i) end
	function public.accessor.__()
		assert(charges > 0)
		charges = charges - 1
		return value
	end
end

do
	local state
	local function f()
		local tmp = state
		state = nil
		return tmp
	end
	function public.present(v)
		state = v
		return f
	end
end

do
	local formal_parameters = {}
	for i=1,9 do
		local key = '_'..i
		public[key] = {}
		formal_parameters[m[key]] = i
	end
	local function helper(f, arg1, arg2)
		local params = {}
		for i=1,arg1.n do
			if formal_parameters[arg1[i]] then
				tinsert(params, arg2[formal_parameters[arg1[i]]])
			else
				tinsert(params, arg1[i])
			end
		end
		return f(unpack(params))
	end
	function public.L(f, ...)
		if type(f) == 'function' then
			local arg1 = arg
			return function(...) return helper(f, arg1, arg) end
		else
			return loadstring 'function(_1,_2,_3,_4,_5,_6,_7,_8,_9)'
		end
	end
end

function public.call(f, ...)
	if f then return f(unpack(arg)) end
end

function public.index(t, ...)
	for i=1,arg.n do t = t and t[arg[i]] end
	return t
end

public.huge = 1.8*10^308

function public.accessor.modified()
	return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

--do TODO
--	local _state = setmetatable({}, {__mode='kv'})
--	local __index = function(self, key)
--		return _state[self].handler({public=self, private=_state[self].state}, key)
--	end
--	function public.class(state, handler)
--		local state, self = {handler=handler, state=state}, {}
--		_state[self] = state
--		return setmetatable(self, {__metatable=false, __index=__index, state=state})
--	end
--end

do
	local _state = setmetatable({}, {__mode='kv'})
	local __index = function(self, key)
		return _state[self].handler({public=self, private=_state[self].state}, key)
	end
	function public.index_function(state, handler)
		local state, self = {handler=handler, state=state}, {}
		_state[self] = state
		return setmetatable(self, {__metatable=false, __index=__index, state=state})
	end
end

function public.expand(array, ...)
	local table = {}
	for i=1,arg.n do table[arg[i]] = array[i] end
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
	for _ in t do size = size + 1 end
	return size
end

function public.key(value, t)
	for k, v in t do
		if v == value then return k end
	end
end

function public.keys(t)
	local ks = {}
	for k in t do tinsert(ks, k) end
	return ks
end

function public.values(t)
	local vs = {}
	for _, v in t do tinsert(vs, v) end
	return vs
end

function public.eq(t1, t2)
	if not t1 or not t2 then return false end
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

function public.any(xs, p)
	for _, x in xs do
		if p then
			if p(x) then return true end
		elseif x then
			return true
		end
	end
	return false
end

function public.all(xs, p)
	for _, x in xs do
		if p then
			if not p(x) then
				return false
			end
		elseif not x then
			return false
		end
	end
	return true
end

function public.replicate(count, value)
	return value, replicate(count - 1, value)
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
	for k, x in xs do ys[k] = f(x, k) end
	return ys
end

do
	local mt = {__call = function(self, key) return self[key] end}
	function public.hashset(...) -- TODO rename/remove?
		local self = {}
		for i=1,arg.n do self[arg[i]] = true end
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

public.join = g.table.concat

function public.tokenize(str)
	local tokens = {}
	for token in string.gfind(str, '%S+') do tinsert(tokens, token) end
	return tokens
end

function public.bound(lower_bound, upper_bound, number)
	return max(lower_bound, min(upper_bound, number))
end

function public.round(x) return floor(x + 0.5) end

function public.accessor.inventory()
	local bag, slot = 0, 0
	return function()
		if not GetBagName(bag) or slot >= GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until GetBagName(bag) or bag > 4
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= 4 then return {bag, slot}, bag_type(bag) end
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
	return function() return GetTime() - t0 > t end
end

function public.signal()
	local params
	return function(...) params = arg end, function() return params end
end