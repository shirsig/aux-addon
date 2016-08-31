if module 'green_t' then return end

local next, setn, setmetatable = next, table.setn, setmetatable
local wipe, recycle, table
local pool, pool_size = {}, 0
local overflow_pool = setmetatable({}, {__mode='k'})
local tmp = {}

CreateFrame('Frame'):SetScript('OnUpdate', function()
	for t in tmp do recycle(t) end
	wipe(tmp)
end)

do
	local t = setmetatable({}, {__metatable=false, __newindex=error})
	public.O.get = t
end

function wipe(t) -- like with a cloth or something
	for k in t do t[k] = nil end
	t.reset = 1
	t.reset = nil
	setn(t, 0)
	return setmetatable(t, nil)
end
public.wipe = wipe

function recycle(t)
	wipe(t)
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
	if t then
		overflow_pool[t] = nil
		return t
	end
	return {}
end
public.t.get = table

function public.tt.get()
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
	tmp[t] = true
	return t
end

do
	local function mt(f)
		local function apply(self, value)
			recycle(self)
			return type(value) == 'table' and f(value) or value
		end
		return {__call=apply, __sub=apply}
	end
	do
		local mt = mt(function(t) tmp[t] = true; return t end)
		public.temp
		{
			get = function() return setmetatable(table(), mt) end,
			set = function(t) tmp[t] = true end,
		}
	end
	do
		local mt = mt(function(t) tmp[t] = nil; return t end)
		public.perm
		{
			get = function() return setmetatable(table(), mt) end,
			set = function(t) tmp[t] = nil end,
		}
	end
end
do
	local KEYS, VALUES, RETURN_VALUES, PAIRS = 1, 2, 3, 4
	local function insert(type)
		local code = 'local setn = table.setn; return function('
		for i = 1, 99 do
			code = code..'a'..i..','
		end
		code = code..'overflow) local t = t;'
		if type == KEYS then
			for i = 1, 99 do
				code = code..format('if a%d == nil then return t end; t[a%d] = true;', i, i)
			end
		elseif type == VALUES then
			code = code..'setn(t, 99); if a1 == nil then return t end; t[1] = a1;'
			for i = 2, 99 do
				code = code..format('if a%d == nil then setn(t, %d); return t end; t[%d] = a%d;', i, i - 1, i, i)
			end
		elseif type == RETURN_VALUES then
			code = code..'setn(t, 99);'
			for i = 1, 99 do
				code = code..format('t[%d] = a%d;', i, i)
			end
		elseif type == PAIRS then
			for i = 1, 97, 2 do
				code = code..format('if a%d == nil then return t end; t[a%d] = a%d;', i, i, i + 1)
			end
		end
		code = code..'return overflow ~= nil and error("Overflow.") or t; end;'
		local f = loadstring(code)
		setfenv(f, M)
		return f
	end
	public.set.get = insert(KEYS)
	public.list.get = insert(VALUES)
	public.ret.get = insert(RETURN_VALUES)
	public.T.get = insert(PAIRS)
end
