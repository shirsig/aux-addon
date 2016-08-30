if module 'green_t' then return end

local next, getn, setn, setmetatable, rawget = next, getn, table.setn, setmetatable, rawget
local wipe, recycle, table
local pool, pool_size = {}, 0
local overflow_pool = setmetatable({}, {__mode='k'})
local tmp = {}

CreateFrame('Frame'):SetScript('OnUpdate', function()
	for t in tmp do recycle(t) end
	wipe(tmp)
end)

--do
--	local t = setmetatable({}, {__metatable=false, newindex=error})
--	public.O.get = t
--end

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
	local function insert_keys(t,k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,k17,k18,k19,k20,overflow)
		if k1 == nil then return end; t[k1] = true
		if k2 == nil then return end; t[k2] = true
		if k3 == nil then return end; t[k3] = true
		if k4 == nil then return end; t[k4] = true
		if k5 == nil then return end; t[k5] = true
		if k6 == nil then return end; t[k6] = true
		if k7 == nil then return end; t[k7] = true
		if k8 == nil then return end; t[k8] = true
		if k9 == nil then return end; t[k9] = true
		if k10 == nil then return end; t[k10] = true
		if k11 == nil then return end; t[k11] = true
		if k12 == nil then return end; t[k12] = true
		if k13 == nil then return end; t[k13] = true
		if k14 == nil then return end; t[k14] = true
		if k15 == nil then return end; t[k15] = true
		if k16 == nil then return end; t[k16] = true
		if k17 == nil then return end; t[k17] = true
		if k18 == nil then return end; t[k18] = true
		if k19 == nil then return end; t[k19] = true
		if k20 == nil then return end; t[k20] = true
		if overflow ~= nil then error('Overflow.') end
	end
	local function insert_values(t,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,overflow)
		local n = getn(t)
		if v1 == nil then return t end; t[n + 1] = v1
		if v2 == nil then setn(t, n + 1); return end; t[n + 2] = v2
		if v3 == nil then setn(t, n + 2); return end; t[n + 3] = v3
		if v4 == nil then setn(t, n + 3); return end; t[n + 4] = v4
		if v5 == nil then setn(t, n + 4); return end; t[n + 5] = v5
		if v6 == nil then setn(t, n + 5); return end; t[n + 6] = v6
		if v7 == nil then setn(t, n + 6); return end; t[n + 7] = v7
		if v8 == nil then setn(t, n + 7); return end; t[n + 8] = v8
		if v9 == nil then setn(t, n + 8); return end; t[n + 9] = v9
		if v10 == nil then setn(t, n + 9); return end; t[n + 10] = v10
		if v11 == nil then setn(t, n + 10); return end; t[n + 11] = v11
		if v12 == nil then setn(t, n + 11); return end; t[n + 12] = v12
		if v13 == nil then setn(t, n + 12); return end; t[n + 13] = v13
		if v14 == nil then setn(t, n + 13); return end; t[n + 14] = v14
		if v15 == nil then setn(t, n + 14); return end; t[n + 15] = v15
		if v16 == nil then setn(t, n + 15); return end; t[n + 16] = v16
		if v17 == nil then setn(t, n + 16); return end; t[n + 17] = v17
		if v18 == nil then setn(t, n + 17); return end; t[n + 18] = v18
		if v19 == nil then setn(t, n + 18); return end; t[n + 19] = v19
		if v20 == nil then setn(t, n + 19); return end; t[n + 20] = v20; setn(t, n + 20)
		if overflow ~= nil then error('Overflow.') end
	end
	local function insert_pairs(t,k1,v1,k2,v2,k3,v3,k4,v4,k5,v5,k6,v6,k7,v7,k8,v8,k9,v9,k10,v10,overflow)
		if k1 == nil then return end t[k1] = v1
		if k2 == nil then return end t[k2] = v2
		if k3 == nil then return end t[k3] = v3
		if k4 == nil then return end t[k4] = v4
		if k5 == nil then return end t[k5] = v5
		if k6 == nil then return end t[k6] = v6
		if k7 == nil then return end t[k7] = v7
		if k8 == nil then return end t[k8] = v8
		if k9 == nil then return end t[k9] = v9
		if k10 == nil then return end t[k10] = v10
		if overflow ~= nil then error('Overflow.') end
	end
	local function constructor_mt(insert)
		return {
			__call=function(self,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,overflow)
				local t, n = rawget(self, 't') or table(), rawget(self, 'n') or 1
				insert(t,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,overflow)
				if n > 1 then
					self.t, self.n = t, n - 1
					return self
				end
				recycle(self)
				return t
			end,
			__index=function(self, key) self.n = key; return self end,
		}
	end
	local set_mt, list_mt, table_mt = constructor_mt(insert_keys), constructor_mt(insert_values), constructor_mt(insert_pairs)
	function public.set.get() return setmetatable(table(), set_mt) end
	function public.list.get() return setmetatable(table(), list_mt) end
	function public.T.get() return setmetatable(table(), table_mt) end
end
