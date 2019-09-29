select(2, ...) 'aux'

M.immutable = setmetatable({}, {
	__metatable = false,
	__newindex = pass,
	__sub = function(_, t)
		return setmetatable({}, { __metatable = false, __newindex = pass, __index = t })
	end
})

function M.pluralize(text)
    local text = gsub(text, '(-?%d+)(.-)|4([^;]-);', function(number_string, gap, number_forms)
        local singular, dual, plural
        _, _, singular, dual, plural = strfind(number_forms, '(.+):(.+):(.+)');
        if not singular then
            _, _, singular, plural = strfind(number_forms, '(.+):(.+)')
        end
        local i = abs(tonumber(number_string))
        local number_form
        if i == 1 then
            number_form = singular
        elseif i == 2 then
            number_form = dual or plural
        else
            number_form = plural
        end
        return number_string .. gap .. number_form
    end)
    return text
end

function M.wipe(t)
    setmetatable(t, nil)
    for k in pairs(t) do
        t[k] = nil
    end
end

function M.set(...)
    local t = {}
    for i = 1, select('#', ...) do
        t[select(i, ...)] = true
    end
    return t
end

function M.iter(...)
    local t = {}
    for i = 1, select('#', ...) do
        t[select(i, ...)] = true
    end
    return pairs(t)
end

function M.assign(t1, t2)
    for k, v in pairs(t2) do
        if t1[k] == nil then
            t1[k] = v
        end
    end
    return t1
end

function M.enum(n)
	if n > 0 then return immutable-{}, enum(n - 1) end
end

M.join = table.concat

M.index = function(t, ...)
	for _, v in ipairs{...} do
		t = t and t[v]
	end
	return t
end

function M.modified()
	return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function M.copy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return setmetatable(copy, getmetatable(t))
end

function M.size(t)
	local size = 0
	for _ in pairs(t) do
		size = size + 1
	end
	return size
end

function M.key(t, value)
	for k, v in pairs(t) do
		if v == value then
			return k
		end
	end
end

function M.keys(t)
	local keys = {}
	for k in pairs(t) do
		tinsert(keys, k)
	end
	return keys
end

function M.values(t)
	local values = {}
	for _, v in pairs(t) do
		tinsert(values, v)
	end
	return values
end

function M.eq(t1, t2)
	if not t1 or not t2 then return false end
	for key, value in pairs(t1) do
		if t2[key] ~= value then return false end
	end
	for key, value in pairs(t2) do
		if t1[key] ~= value then return false end
	end
	return true
end

function M.any(t, predicate)
	for _, v in pairs(t) do
		if predicate then
			if predicate(v) then return true end
		elseif v then
			return true
		end
	end
	return false
end

function M.all(t, predicate)
	for _, v in pairs(t) do
		if predicate then
			if not predicate(v) then return false end
		elseif not v then
			return false
		end
	end
	return true
end

function M.filter(t, predicate)
	for k, v in pairs(t) do
		if not predicate(v, k) then t[k] = nil end
	end
	return t
end

function M.map(t, f)
	for k, v in pairs(t) do
		t[k] = f(v, k)
	end
	return t
end

function M.trim(str)
	return gsub(str, '^%s*(.-)%s*$', '%1')
end

function M.split(str, separator)
	local parts = {}
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
	local tokens = {}
	for token in string.gmatch(str, '%S+') do tinsert(tokens, token) end
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
	local arg
	return function(...)
        arg = {...}
	end, function()
		return arg
	end
end