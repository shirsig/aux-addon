module 'aux'

local T = require 'T'

M.immutable = setmetatable(T.acquire(), {
	__metatable = false,
	__newindex = pass,
	__sub = function(_, t)
		return setmetatable(T.acquire(), T.map('__metatable', false, '__newindex', pass, '__index', t))
	end
})

function M.assign(t1, t2)
    for k, v in t2 do
        if t1[k] == nil then
            t1[k] = v
        end
    end
    return t1
end

function M.enum(n)
	if n > 0 then return immutable-{}, enum(n - 1) end
end

M.select = T.vararg-function(arg)
	for _ = 1, arg[1] do
		tremove(arg, 1)
	end
	if getn(arg) == 0 then
		return nil
	else
		return unpack(arg)
	end
end

M.join = table.concat

M.index = T.vararg-function(arg)
	local t = tremove(arg, 1)
	for _, v in ipairs(arg) do
		t = t and t[v]
	end
	return t
end

M.huge = 1/0

function M.modified()
	return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function M.copy(t)
	local copy = T.acquire()
	for k, v in t do
		copy[k] = v
	end
	table.setn(copy, getn(t))
	return setmetatable(copy, getmetatable(t))
end

function M.size(t)
	local size = 0
	for _ in t do
		size = size + 1
	end
	return size
end

function M.key(t, value)
	for k, v in t do
		if v == value then
			return k
		end
	end
end

function M.keys(t)
	local keys = T.acquire()
	for k in t do
		tinsert(keys, k)
	end
	return keys
end

function M.values(t)
	local values = T.acquire()
	for _, v in t do
		tinsert(values, v)
	end
	return values
end

function M.eq(t1, t2)
	if not t1 or not t2 then return false end
	for key, value in t1 do
		if t2[key] ~= value then return false end
	end
	for key, value in t2 do
		if t1[key] ~= value then return false end
	end
	return true
end

function M.any(t, predicate)
	for _, v in t do
		if predicate then
			if predicate(v) then return true end
		elseif v then
			return true
		end
	end
	return false
end

function M.all(t, predicate)
	for _, v in t do
		if predicate then
			if not predicate(v) then return false end
		elseif not v then
			return false
		end
	end
	return true
end

function M.filter(t, predicate)
	for k, v in t do
		if not predicate(v, k) then t[k] = nil end
	end
	return t
end

function M.map(t, f)
	for k, v in t do
		t[k] = f(v, k)
	end
	return t
end

function M.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

function M.split(str, separator)
	local parts = T.acquire()
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

function M.tokenize(str)
	local tokens = T.acquire()
	for token in string.gfind(str, '%S+') do tinsert(tokens, token) end
	return tokens
end

function M.bounded(lower_bound, upper_bound, number)
	return max(lower_bound, min(upper_bound, number))
end

function M.round(x)
	return floor(x + .5)
end

function M.later(t, t0)
	t0 = t0 or GetTime()
	return function() return GetTime() - t0 > t end
end

function M.signal()
	local params
	return T.vararg-function(arg)
		T.static(arg)
		params = arg
	end, function()
		return params
	end
end