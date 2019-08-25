select(2, ...) 'T'

local next, tremove, setmetatable = next, tremove, setmetatable

local wipe, acquire, release
local pool, pool_size, overflow_pool, auto_release = {}, 0, setmetatable({}, {__mode='k'}), {}

function wipe(t)
	setmetatable(t, nil)
	for k in pairs(t) do
		t[k] = nil
	end
	t.reset, t.reset = nil, 1
end
M.wipe = wipe

CreateFrame'Frame':SetScript('OnUpdate', function()
	for t in pairs(auto_release) do
		release(t)
	end
	wipe(auto_release)
end)

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
M.acquire = acquire

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
M.release = release

do
	local function f(_, v)
		if v then
			auto_release[v] = true
			return v
		end
	end
	M.temp = setmetatable({}, {__metatable=false, __newindex=pass, __call=f, __sub=f})
end
do
	local function f(_, v)
		if v then
			auto_release[v] = nil
			return v
		end
	end
	M.static = setmetatable({}, {__metatable=false, __newindex=pass, __call=f, __sub=f})
end

do
	local function unpack(t)
		if #t > 0 then
			return tremove(t, 1), unpack(t)
		else
			release(t)
		end
	end
	M.unpack = unpack
end

M.empty = setmetatable({}, {__metatable=false, __newindex=pass})

function M.list(...)
    local t = acquire()
    for i = 1, select('#', ...) do
        t[i] = select(i, ...)
    end
	return t
end
function M.set(...)
	local t = acquire()
    for i = 1, select('#', ...) do
        t[select(i, ...)] = true
    end
	return t
end
function M.map(...)
	local t = acquire()
	for i = 1, select('#', ...), 2 do
		t[select(i, ...)] = select(i + 1, ...)
	end
	return t
end