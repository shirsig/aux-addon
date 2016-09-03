--__.green_t = function()

if module 'green_t' then return end

local wipe_chunk = [[
	for k in t do t[k] = nil end
	t.reset, t.reset = nil, 1
	setn(t, 0)
	setmetatable(t, nil)
]]

local recycle_chunk = wipe_chunk..[[
	if pool_size < 50 then
		pool_size = pool_size + 1
		pool[pool_size] = t
	else
		overflow_pool[t] = true
	end
]]

local acquire_chunk = [[
	local t
	if pool_size > 0 then
		t = pool[pool_size]
		pool_size = pool_size - 1
	else
		t = next(overflow_pool)
		if t then
			overflow_pool[t] = nil
		else
			t = {}
		end
	end
]]

pool, pool_size, overflow_pool, tmp = {}, 0, setmetatable({}, {__mode='k'}), {}

public.empty = setmetatable({}, {__metatable=false, __newindex=nop})

--select(1, 2, 3, END, kek()) -- TODO
do
	local f = loadstring([[
		local setmetatable, setn = setmetatable, table.setn
		return function(t)
	]]..wipe_chunk..'return t end')
	setfenv(f, M)
	public.wipe = f()
end

do
	local f = loadstring([[
		local setmetatable, setn, pool, pool_size, overflow_pool = setmetatable, table.setn, pool, pool_size, overflow_pool
		return function(t)
	]]..recycle_chunk..'end')
	setfenv(f, M)
	public.recycle = f()
end

do
	local f = loadstring(format([[
		local setmetatable, setn, pool, pool_size, overflow_pool, t = setmetatable, table.setn, pool, pool_size, overflow_pool, tmp
		return function() for t in t do %s end %s end
	]], recycle_chunk, wipe_chunk))
	setfenv(f, M)
	CreateFrame'Frame':SetScript('OnUpdate', f())
end

do
	local f = loadstring(format([[
		local next, pool, pool_size, overflow_pool, tmp = next, pool, pool_size, overflow_pool, tmp
		return function() %s; tmp[t] = true; return t end
	]], acquire_chunk))
	setfenv(f, M)
	public.tt.get = f()
end

do local next, pool, pool_size, overflow_pool = next, pool, pool_size, overflow_pool
	function public.t.get()
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
end

do local setmetatable, type, tmp = setmetatable, type, tmp
	do local f, mt
		f = function(_, v) if type(v) == 'table' then tmp[v] = true end return v end
		mt = {__call=f, __sub=f}
		public.temp {get=function() return setmetatable(tt, mt) end, set=function(t) tmp[t] = true end}
	end
	do local f, mt
		f = function(_, v) if type(v) == 'table' then tmp[v] = nil end return v end
		mt = {__call=f, __sub=f}
		public.perm {get=function() return setmetatable(tt, mt) end, set=function(t) tmp[t] = nil end}
	end
end

do
	local SET, ARRAY, ARRAY0, TABLE = 1, 2, 3, 4
	local function insert(type)
		local chunk = 'local setn, error = table.setn, error; return function('
		for i = 1, 99 do chunk = chunk..'a'..i..',' end
		chunk = chunk..'overflow)'..acquire_chunk
		if type == SET then
			for i = 1, 99 do
				chunk = chunk..format('if a%d == nil then return t end t[a%d] = true;', i, i)
			end
		elseif type == ARRAY then
			chunk = chunk..'setn(t, 99); if a1 == nil then return t end t[1] = a1;'
			for i = 2, 99 do
				chunk = chunk..format('if a%d == nil then setn(t, %d); return t end t[%d] = a%d;', i, i - 1, i, i)
			end
		elseif type == ARRAY0 then
			chunk = chunk..'setn(t, 99);'
			for i = 1, 99 do
				chunk = chunk..format('t[%d] = a%d;', i, i)
			end
		elseif type == TABLE then
			for i = 1, 97, 2 do
				chunk = chunk..format('if a%d == nil then return t end t[a%d] = a%d;', i, i, i + 1)
			end
		end
		chunk = chunk..'return overflow ~= nil and error("Overflow.") or t end'
		local f = loadstring(chunk)
		setfenv(f, M)
		return f()
	end
	public(); S, A, A0, T = insert(SET), insert(ARRAY), insert(ARRAY0), insert(TABLE)
end

--end