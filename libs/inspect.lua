local format_key, format_value, print, print_pair, print_table

function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 0, 0)
end

function format_key(k)
	return type(k) == 'string' and k or '[' .. tostring(k) .. ']'
end

function format_value(v)
	return type(v) == 'string' and '"' .. v .. '"' or tostring(v)
end

function print_table(t, depth)
	for i = 1, getn(t) do
		print_pair(i, t[i], depth)
	end
	for k, v in t do
		if type(k) ~= 'number' or k < 1 or k > getn(t) then
			print_pair(k, v, depth)
		end
	end
end

local max_depth

function print_pair(k, v, depth)
	local padding = strrep(' ', depth * 4)
	print(padding .. format_key(k) .. ' = ' .. format_value(v))
	if type(v) == 'table' then
		if next(v) then
			print(padding .. '{')
			if depth == max_depth then
				print(padding .. '    ...')
			else
				print_table(v, depth + 1)
			end
			print(padding .. '}')
		end
	end
end

function inspect(_, ...)
	local n = arg.n
	arg.n = nil
	table.setn(arg, n)
	max_depth = max_depth or 2
	print_table(arg, 0)
	max_depth = nil
	return unpack(arg)
end

local function setting(v)
	if type(v) == 'number' then
		max_depth = v
	elseif type(v) == 'function' then
		print('#' .. v())
	else
		print('#' .. v)
	end
end

local mt = {__metatable=false, __call=inspect, __div=inspect}

function mt:__index(key)
	setting(key)
	return self
end

function mt:__newindex(key, value)
	setting(key)
	self(value)
	return self
end

p = setmetatable({}, mt)