green_t = module

local next, setn, type, setmetatable = next, table.setn, type, setmetatable
local wipe, recycle, table, temp_table

local pool, pool_size, overflow_pool, tmp = {}, 0, setmetatable({}, {__mode='k'}), {}

CreateFrame('Frame'):SetScript('OnUpdate', function()
	for t in tmp do recycle(t) end; wipe(tmp)
end)

function wipe(t)
	setmetatable(t, nil); setn(t, 0)
	for k in t do t[k] = nil end
	t.reset, t.reset = nil, 1
end
public.wipe = wipe

function recycle(t)
	wipe(t); tmp[wipe(t)] = nil
	if pool_size < 50 then
		pool_size = pool_size + 1
		pool[pool_size] = t
	else
		overflow_pool[t] = true
	end
end
public.recycle = recycle

function table()
	if pool_size > 0 then
		pool_size = pool_size - 1
		return pool[pool_size + 1]
	end
	local t = next(overflow_pool)
	if t then overflow_pool[t] = nil; return t end
	return {}
end
public.t.get = table

function temp_table() local t = table(); tmp[t] = true; return t end
public.tt.get = temp_table

do local mt = {__metatable=false, __newindex=error}
	function public.empty.get() return setmetatable(temp_table, mt) end
end

do local f, mt
	f = function(_, v) if type(v) == 'table' then tmp[v] = true end return v end
	mt = {__metatable=false, __call=f, __sub=f}
	public.temp {get=function() return setmetatable(temp_table(), mt) end, set=function(t) tmp[t] = true end}
end
do local f, mt
	f = function(_, v) if type(v) == 'table' then tmp[v] = nil end return v end
	mt = {__metatable=false, __call=f, __sub=f}
	public.perm {get=function() return setmetatable(temp_table(), mt) end, set=function(t) tmp[t] = nil end}
end

do
	local SET, ARRAY, ARRAY0, TABLE = 1, 2, 3, 4
	local function insert(type)
		local chunk = 'setmetatable(t, nil); local setn, error = table.setn, error; return function(t'
		for i = 1, 98 do chunk = chunk..',a'..i end
		chunk = chunk..',overflow)'
		if type == SET then
			for i = 1, 98 do
				chunk = chunk..format('if a%d == nil then return t end t[a%d] = true;', i, i)
			end
		elseif type == ARRAY then
			chunk = chunk..'setn(t, 99); if a1 == nil then return t end t[1] = a1;'
			for i = 2, 98 do
				chunk = chunk..format('if a%d == nil then setn(t, %d); return t end t[%d] = a%d;', i, i - 1, i, i)
			end
		elseif type == ARRAY0 then
			chunk = chunk..'setn(t, 99);'
			for i = 1, 98 do chunk = chunk..format('t[%d] = a%d;', i, i) end
		elseif type == TABLE then
			for i = 1, 97, 2 do
				chunk = chunk..format('if a%d == nil then return t end t[a%d] = a%d;', i, i, i + 1)
			end
		end
		chunk = chunk..'return overflow ~= nil and error("Overflow.") or t end'
		local f = loadstring(chunk); setfenv(f, M); return f()
	end
	local function getter(type)
		local mt = {__metatable=false, __newindex=error, __call=insert(type)}
		function mt:__index(t) recycle(self); return setmetatable(mt, t) end
		return function() return setmetatable(t, mt) end
	end
	public(); S, A, A0, T = {get=getter(SET)}, {get=getter(ARRAY)}, {get=getter(ARRAY0)}, {get=getter(TABLE)}
end