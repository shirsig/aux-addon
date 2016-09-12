aux 'core'

--do
--	local call_method, call_self
--	local function generic_call(...)
--		return call_method(call_self, unpack(arg))
--	end
--
--	local state = setmetatable({}, {__mode='k'})
--	local mt = {__metatable=false}
--	function mt:__index(self, key) self=state[self]
--	local getter = self.class.getters[key]
--	if getter then return getter(self.self) end
--	local method = self.class.methods[key]
--	if method then
--		call_method, call_self = method, self.self
--		return generic_call
--	end
--	end
--	function mt:__newindex(self, key, value) self=state[self]
--	local setter = self.class.setters[key]
--	if setter then return setter(self.self, value) end
--	end
--	--	function mt:__unm(self) self=state[self]
--	--		reclaim()
--	--	end
--	local function instantiate(methods, getters, setters, init, arg)
--		local interface = setmetatable({}, mt)
--		local self = {_I=interface}; init(self, unpack(arg))
--		state[interface] = {class={methods=methods, getters=getters, setters=setters}, self=self}
--		return interface
--	end
--	function public.class(methods, getters, setters, init)
--		return function(arg) instantiate(methods, getters, setters, init, arg) end
--	end
--end
--
--do
--	local state = {}
--	local mt = {__metatable=false, __newindex=error}
--	function mt:__index(key) return state[self][key] end
--	function public.immutable(t)
--		return class({}, t, {}, function() end, {})
--	end
--end

do
	local _state = setmetatable(t, T('__mode', 'kv'))
	local __index = function(self, key)
		return _state[self].handler({ public=self, private=_state[self].state }, key)
	end
	function public.index_function(state, handler) -- TODO rename table-accessor, use predicate to stop
	local state, self = {handler=handler, state=state}, t
	_state[self] = state
	return setmetatable(self, { __metatable=false, __index=__index, state=state })
	end
end

function public.vararg.select(arg)
	for _ = 1, arg[1] do
		tremove(arg, 1)
	end
	if getn(arg) == 0 then
		return nil
	else
		return unpack(arg)
	end
end

public.join = _G.table.concat

function public.range(arg1, arg2)
	local i, n = arg2 and arg1 or 1, arg2 or arg1
	if i <= n then return first, range(i + 1, n) end
end

function public.replicate(count, value)
	if count > 0 then return value, replicate(count - 1, value) end
end

do
	local state
	local function f()
		local temp = state
		state = nil
		return temp
	end
	function public.present(v)
		state = v
		return f
	end
end

function public.vararg.partial(arg)
	local f, arg1 = tremove(arg, 1), perm-arg
	return vararg(function(arg)
		for i = 1, getn(arg) do
			tinsert(arg1, arg[i])
		end
		return f(unpack(arg1))
	end)
end

function public.vararg.index(arg)
	local t = tremove(arg, 1)
	for i = 1, getn(arg) do t = t and t[arg[i]] end return t
end

public.huge = 1.8 * 10 ^ 308

function public.modified.get() return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() end

function public.copy(t)
	local copy = _E.t
	for k, v in t do copy[k] = v end
	table.setn(copy, getn(t))
	return setmetatable(copy, getmetatable(t))
end

function public.size(t)
	local size = 0
	for _ in t do size = size + 1 end
	return size
end

function public.key(value, t)
	for k, v in t do if v == value then return k end end
end

function public.keys(t)
	local keys = _E.t
	for k in t do tinsert(keys, k) end
	return keys
end

function public.values(t)
	local values = _E.t
	for _, v in t do tinsert(values, v) end
	return values
end

function public.eq(t1, t2)
	if not t1 or not t2 then return false end
	for key, value in t1 do
		if t2[key] ~= value then return false end
	end
	for key, value in t2 do
		if t1[key] ~= value then return false end
	end
	return true
end

function public.any(t, predicate)
	for _, v in t do
		if predicate then
			if predicate(v) then return true end
		elseif v then
			return true
		end
	end
	return false
end

function public.all(t, predicate)
	for _, v in t do
		if predicate then
			if not predicate(v) then return false end
		elseif not v then
			return false
		end
	end
	return true
end

function public.filter(t, predicate)
	for k, v in t do
		if not predicate(v, k) then t[k] = nil end
	end
	return t
end

function public.map(t, f)
	for k, v in t do t[k] = f(v, k) end
	return t
end

function public.trim(str) return gsub(str, '^%s*(.-)%s*$', '%1') end

function public.split(str, separator)
	local parts = t
	while true do
		local start_index = strfind(str, separator, 1, true)
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
	local tokens = t
	for token in string.gfind(str, '%S+') do tinsert(tokens, token) end
	return tokens
end

function public.bounded(lower_bound, upper_bound, number)
	return max(lower_bound, min(upper_bound, number))
end

function public.round(x) return floor(x + .5) end

function public.later(t0, t)
	return function() return GetTime() - t0 > t end
end

function public.signal() local params
	return function(...) params = arg end, function() return params end
end