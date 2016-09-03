aux 'core' private()

public.join = _G.table.concat

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
		state = v; return f
	end
end

do
	local formal_parameters = t
	for i = 1, 9 do
		local key = '_'..i
		public[key] = t
		formal_parameters[M[key]] = i
	end
	local function helper(f, arg1, arg2)
		local params = t
		for i = 1, arg1.n do
			if formal_parameters[arg1[i]] then
				tinsert(params, arg2[formal_parameters[arg1[i]]])
			else
				tinsert(params, arg1[i])
			end
		end
		return f(unpack(params))
	end
	local a1b2 = {a=1, b=2}
	function public.L(body, ...)
		if type(body) == 'function' then
			local arg1 = arg
			return function(...) return helper(body, arg1, arg) end
		else
			error(debugstack(1, 10))
			body = gsub(body, '_([ab])', function(char) return '_'..a1b2[char] end)
			local lambda = loadstring 'return function(_1,_2,_3,_4,_5,_6,_7,_8,_9)'..f..' end'
			setfenv(lambda, getfenv(2))
			return lambda
		end
	end
end

function public.call(f, ...) temp=arg
	if f then
		return f(unpack(arg))
	end
end

function public.index(t, ...) temp=arg
	for i = 1, arg.n do
		t = t and t[arg[i]]
	end
	return t
end

public.huge = 1.8*10^308

function public.modified.get() return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() end

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
	local _state = setmetatable(t, T('__mode', 'kv'))
	local __index = function(self, key)
		return _state[self].handler({public=self, private=_state[self].state}, key)
	end
	function public.index_function(state, handler) -- TODO rename table-accessor, use predicate to stop
		local state, self = {handler=handler, state=state}, t
		_state[self] = state
		return setmetatable(self, {__metatable=false, __index=__index, state=state})
	end
end

function public.expand(array, ...) temp=arg
	local t = t
	for i = 1, arg.n do t[arg[i]] = array[i] end
	return t
end

function public.copy(t)
	local copy = M.t
	for k, v in t do copy[k] = v end
	table.setn(copy, getn(t))
	return setmetatable(copy, getmetatable(t))
end

function public.select(i, ...) temp=arg
	while i > 1 do i = i - 1; tremove(arg, i) end
	return tremove(arg, 1), unpack(arg)
end

function public.collect(indices, ...) temp=arg
	local t = M.t
	for _, v in indices do
		tinsert(t, arg[v])
	end
	return t
end

function public.hashset(t)
	local set = M.t
	for _, v in t do
		set[v] = true
	end
	return set
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
	local keys = M.t
	for k in t do tinsert(keys, k) end
	return keys
end

function public.values(t)
	local values = M.t
	for _, v in t do tinsert(values, v) end
	return values
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

function public.any(t, p)
	for _, v in t do
		if p then
			if p(v) then return true end
		elseif v then
			return true
		end
	end
	return false
end

function public.all(t, p)
	for _, v in t do
		if p then
			if not p(v) then
				return false
			end
		elseif not v then
			return false
		end
	end
	return true
end

function public.filter(t, p)
	for k, v in t do
		if not p(v, k) then
			t[k] = nil
		end
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

function public.signal()
	local params
	return function(...) params = arg end, function() return params end
end