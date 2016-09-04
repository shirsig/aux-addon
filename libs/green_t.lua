green_t = module

local next, setn, type, setmetatable = next, table.setn, type, setmetatable
local wipe, release, acquire, acquire_temp

local pool, pool_size, overflow_pool, auto_release = {}, 0, setmetatable({}, {__mode='k'}), {}

CreateFrame('Frame'):SetScript('OnUpdate', function()
	for t in auto_release do release(t) end; wipe(auto_release)
end)

function wipe(t)
	setmetatable(t, nil); setn(t, 0)
	for k in t do t[k] = nil end
	t.reset, t.reset = nil, 1
	return t
end
public.wipe = wipe

function release(t)
	wipe(t); auto_release[t] = nil
	if pool_size < 50 then
		pool_size = pool_size + 1
		pool[pool_size] = t
	else
		overflow_pool[t] = true
	end
	return
end
public.release = release

function public.strip(t)
	if getn(t) > 0 then return tremove(t, 1), strip(t) else release(t) end
end

function acquire()
	if pool_size > 0 then
		pool_size = pool_size - 1
		return pool[pool_size + 1]
	end
	local t = next(overflow_pool)
	if t then overflow_pool[t] = nil; return t end
	return {}
end
public.t.get = acquire

function acquire_temp() local t = acquire(); auto_release[t] = true; return t end
public.tt.get = acquire_temp

do local mt = {__newindex=nop}
	function public.empty.get() return setmetatable(acquire_temp(), mt) end
end

do local f, mt
	f = function(_, v) if type(v) == 'table' then auto_release[v] = true end return v end
	mt = {__call=f, __sub=f}
	public.temp {get=function() return setmetatable(acquire_temp(), mt) end, set=function(t) auto_release[t] = true end}
end
do local f, mt
	f = function(_, v) if type(v) == 'table' then auto_release[v] = nil end return v end
	mt = {__call=f, __sub=f}
	public.perm {get=function() return setmetatable(acquire_temp(), mt) end, set=function(t) auto_release[t] = nil end}
end

do local mt, key = {}, nil
	function mt:__unm() local temp = mt.__index; mt.__index = nil; return temp end
	function mt:__index(k) key = k; return self end
	function mt:__call(v) self[key] = v; key = nil return self end
	function public.__(t) mt.__newindex = wipe(t); return setmetatable(acquire_temp(), mt) end
end

do local function constructor(type)
		local chunk = 'local setn, error = table.setn, error; return function('
		for i = 1, 99 do chunk = chunk .. 'a' .. i..',' end
		chunk = chunk .. 'overflow) local t = t'
		if type == 'set' then
			for i = 1, 99 do chunk = format('%s; if a%d == nil then return t end; t[a%d] = true', chunk, i, i) end
		elseif type == 'array' then
			chunk = chunk .. '; setn(t, 99); if a1 == nil then return t end; t[1] = a1'
			for i = 2, 99 do chunk = format('%s; if a%d == nil then setn(t, %d); return t end; t[%d] = a%d', chunk, i, i - 1, i, i) end
		elseif type == 'array0' then
			chunk = chunk .. '; setn(t, 99)'
			for i = 1, 99 do chunk = format('%s; t[%d] = a%d', chunk, i, i) end
		elseif type == 'table' then
			for i = 1, 97, 2 do chunk = format('%s; if a%d == nil then return t end; t[a%d] = a%d', chunk, i, i, i + 1) end
		end
		chunk = chunk .. '; return (overflow == nil or error "Overflow.") and t end'
		local f = loadstring(chunk); setfenv(f, M); return f()
	end
	public(); S, A, A0, T = constructor'set', constructor'array', constructor 'array0', constructor 'table'
end

do local chunk = 'return function(i'
	for i = 1, 99 do chunk = chunk .. ',a' .. i end
	chunk = chunk .. ')'
	for i = 1, 99 do
		chunk = format('%s if i == %d then return a%i', chunk, i, i)
		for j = i + 1, 99 do chunk = chunk .. ',a' .. j end
		chunk = chunk .. ' end'
	end
	chunk = chunk .. ' end'
	public.select = loadstring(chunk)()
end