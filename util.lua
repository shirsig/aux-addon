module 'aux'

do
	local mt = {__metatable=false, __newindex=nop, __mode='k'}
	function mt:__sub(table)
		local proxy = setmetatable(T, O('__metatable', false, '__newindex', nop, '__index', table))
		self[proxy] = table
		return proxy
	end
	function M.get_wrapper()
		return setmetatable(T, mt)
	end
end

M.select = vararg-function(arg)
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

function M.range(arg1, arg2)
	local i, n = arg2 and arg1 or 1, arg2 or arg1
	if i <= n then return first, range(i + 1, n) end
end

function M.replicate(count, value)
	if count > 0 then return value, replicate(count - 1, value) end
end

M.index = vararg-function(arg)
	local t = tremove(arg, 1)
	for i = 1, getn(arg) do t = t and t[arg[i]] end return t
end

M.huge = 1.8 * 10 ^ 308

function M.get_modified()
	return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function M.copy(t)
	local copy = T
	for k, v in t do copy[k] = v end
	table.setn(copy, getn(t))
	return setmetatable(copy, getmetatable(t))
end

function M.size(t)
	local size = 0
	for _ in t do size = size + 1 end
	return size
end

function M.key(value, t)
	for k, v in t do if v == value then return k end end
end

function M.keys(t)
	local keys = T
	for k in t do tinsert(keys, k) end
	return keys
end

function M.values(t)
	local values = T
	for _, v in t do tinsert(values, v) end
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
	for k, v in t do t[k] = f(v, k) end
	return t
end

function M.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

function M.split(str, separator)
	local parts = T
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
	local tokens = T
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
	return vararg-function(arg)
		static(arg)
		params = arg
	end, function()
		return params
	end
end