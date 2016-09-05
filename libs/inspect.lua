local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 0, 0)
end

local function format_key(k)
	return type(k) == 'string' and k or '[' .. tostring(k) .. ']'
end

local function format_value(v)
	return type(v) == 'string' and '"' .. v .. '"' or tostring(v)
end

local function print_table(t, max_depth, depth)
	local padding = strrep(' ', depth * 4)
	for k, v in t do
		if depth == max_depth then
			print(padding .. '...')
			return
		end
		print(padding .. format_key(k) .. ' = ' .. format_value(v))
		if type(v) == 'table' then
			print(padding .. '{')
			print_table(v, max_depth, depth + 1)
			print(padding .. '}')
		end
	end
end

local depth

function inspect(_, ...)
	arg.n = nil
	print_table(arg, depth or 2, 0)
	depth = nil
	return unpack(arg)
end

local mt = { __metatable=false, __call=inspect, __div=inspect }

function mt:__index(key)
	if type(key) == 'number' then
		depth = key
	elseif type(key) == 'function' then
		print('#' .. key())
	else
		print('#' .. key)
	end
	return self
end

p = setmetatable({}, mt)