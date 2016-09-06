green_t = module
--setglobal('green_t', green_t and error(nil) or module)

local next, getn, setn, type, setmetatable = next, getn, table.setn, type, setmetatable
local wipe, release, acquire, acquire_auto

-- TODO mandatory operation table mandate + comply/fulfill functions
local pool, pool_size, overflow_pool, auto_release = {}, 0, setmetatable({}, { __mode='k' }), {}

CreateFrame('Frame'):SetScript('OnUpdate', function()
	for t in auto_release do release(t) end
	wipe(auto_release)
end)

function wipe(t)
	setmetatable(t, nil)
	for k in t do t[k] = nil end
	t.reset, t.reset = nil, 1
	setn(t, 0)
end
public.wipe = wipe

public.init = setmetatable({}, {
	__metatable = false,
	__newindex = function(_, t, init)
		wipe(t)
		for k, v in init do
			t[k] = v
			setn(t, getn(init))
		end
	end
})

function release(t)
	wipe(t)
	auto_release[t] = nil
	if pool_size < 50 then
		pool_size = pool_size + 1
		pool[pool_size] = t
	else
		overflow_pool[t] = true
	end
end
public.release = release

function public.ret(t)
	if getn(t) > 0 then
		return tremove(t, 1), ret(t)
	else
		release(t)
	end
end

function acquire()
	if pool_size > 0 then
		pool_size = pool_size - 1
		return pool[pool_size + 1]
	end
	local t = next(overflow_pool)
	if t then
		overflow_pool[t] = nil
		return t
	end
	return {}
end
public.t.get = acquire

function acquire_auto()
	local t = acquire()
	auto_release[t] = true
	return t
end
public.tt.get = acquire_auto

public.empty = setmetatable({}, { __newindex=nop })

do
	local function set_auto_release(v, enable)
		if type(v) ~= 'table' then return end
		auto_release[v] = enable and true or nil
	end
	public.auto = setmetatable({}, {
		__metatable = false,
		__newindex=function(_, k, v) set_auto_release(k, v) end,
	})
	public.temp = setmetatable({}, {
		__metatable=false,
		__sub=function(_, v) set_auto_release(v, false); return v end,
	})
	public.perm = setmetatable({}, {
		__metatable=false,
		__sub=function(_, v) set_auto_release(v, true); return v end,
	})
end

local function arg_chunk(k, n)
	k = k or 1
	n = n or 100
	local str = k > n and '' or 'a' .. k
	for i = k + 1, n do str = str .. ',a' .. i end
	return str
end

function public.pseudo_vararg_function(body, upvals)
	local upval_chunk = ''
	for k in upvals or empty do
		upval_chunk = upval_chunk .. format('local %1$s = %1$s;', k)
	end
	local f = loadstring(format('%s return function(%s) %s end', upval_chunk, arg_chunk(), body)) or error()
	setfenv(f, upvals or empty)
	return f()
end

do
	local body = [[
		if arg100 ~= nil then error("Vararg overflow.") end
		local n
		repeat
	]]
	for i = 99, 1, -1 do
		body = body .. format('if a%1$d ~= nil then n = %1$d; break end;', i)
	end
	body = body .. [[
		until true
		local t = acquire_auto()
		setn(t, n)
		repeat
	]]
	for i = 1, 99 do
		body = body .. format('if %1$d > n then break end; t[%1$d] = a%1$d;', i)
	end
	body = body .. [[
		until true
		return f(t)
	]]
	function public.vararg(f)
		return pseudo_vararg_function(body, {f=f, error=error, setn=setn, acquire=acquire_auto, release=release})
	end
end

local function insert_chunk(mode)
	local body = 'repeat '
	if mode == 'k' then
		for i = 2, 99 do
			body = body .. format('if a%1$d == nil then break end; a1[a%1$d] = true;', i)
		end
	elseif mode == 'v' then
		body = body .. 'if a2 == nil then break end; a1[1] = a2;'
		for i = 3, 99 do
			body = body .. format('if a%1$d == nil then setn(a1, %d); break end; a1[%d] = a%1$d;', i, i-2, i-1)
		end
	elseif mode == 'v0' then
		body = body .. 'setn(a1, 98);'
		for i = 2, 99 do
			body = body .. format('a1[%d] = a%d;', i-1, i)
		end
	elseif mode == 'kv' then
		for i = 2, 98, 2 do
			body = body .. format('if a%1$d == nil then break end; a1[a%1$d] = a%d;', i, i+1)
		end
	end
	return body .. 'if a100 ~= nil then error("Vararg overflow.") end until true;'
end

do
	local function pseudo_table_literal(mode)
		local upvals = {setmetatable=setmetatable, setn=setn, error=error}
		local mt = {__call = pseudo_vararg_function(insert_chunk(mode) .. 'setmetatable(a1, nil); return a1', upvals)}
		return function() return setmetatable(acquire(), mt) end
	end
	public.S.get = pseudo_table_literal('k')
	public.A.get = pseudo_table_literal('v')
	public.A0.get = pseudo_table_literal('v0')
	public.T.get = pseudo_table_literal('kv')
end

do
	local body = ''
	for i = 1, 99 do
		body = body .. format('if a1 == %d then return %s end;', i, arg_chunk(i+1, 100))
	end
	public.select = pseudo_vararg_function(body)
end

