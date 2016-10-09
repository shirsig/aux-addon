module 'aux'

do
	local classes, interfaces, objects = {}, {}, setmetatable({}, { __mode='k' })
	local private_mt = { __metatable=false }
	function private_mt:__newindex(k, v)
		classes[self][k] = v
	end
	local public_mt = { __metatable=false }
	function public_mt:__newindex(k, v)
		classes[self][k] = v
		interfaces[self][k] = function(self, ...)
			return classes[self][k](objects[self][k], unpack(arg))
		end
	end
	local proxy_mt = { __metatable=false }
	function proxy_mt:__call()
		local proxy = setmetatable({}, { __metatable=false, __index=interfaces[self] })
		objects[proxy] = setmetatable({}, { __index=classes[self] })
		return proxy
	end
	function public.class()
		local class, interface = {}, {}
		local private, public, proxy = setmetatable({}, private_mt), setmetatable({}, public_mt), setmetatable({}, proxy_mt)
		classes[private], classes[public], classes[proxy] = class, class, class
		interfaces[public], interfaces[proxy] = interface, interface
		return private, public, proxy
	end
end

do
	local _state = setmetatable(t, T('__mode', 'kv'))
	local __index = function(self, k)
		return _state[self].handler({ public=self, private=_state[self].state }, k)
	end
	function public.index_function(state, handler) -- TODO rename table-accessor, use predicate to stop
		local state, self = { handler=handler, state=state }, t
		_state[self] = state
		return setmetatable(self, { __metatable=false, __index=__index, state=state })
	end
end

public.select = vararg-function(arg)
	for _ = 1, arg[1] do
		tremove(arg, 1)
	end
	if getn(arg) == 0 then
		return nil
	else
		return unpack(arg)
	end
end

public.join = table.concat

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

public.papply = vararg-function(arg)
	local f, arg1 = tremove(arg, 1), perm-arg
	return vararg-function(arg)
		for i = 1, getn(arg) do
			tinsert(arg1, arg[i])
		end
		return f(unpack(arg1))
	end
end

public.index = vararg-function(arg)
	local t = tremove(arg, 1)
	for i = 1, getn(arg) do t = t and t[arg[i]] end return t
end

public.huge = 1.8 * 10 ^ 308

function public.modified.get()
	return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function public.copy(t)
	local copy = _M.t
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
	local keys = _M.t
	for k in t do tinsert(keys, k) end
	return keys
end

function public.values(t)
	local values = _M.t
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

function public.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

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

function public.round(x)
	return floor(x + .5)
end

function public.later(t0, t)
	return function() return GetTime() - t0 > t end
end

function public.signal() local params
	return function(...) params = arg end, function() return params end
end