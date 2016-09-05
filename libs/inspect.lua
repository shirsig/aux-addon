local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(RED_FONT_COLOR_CODE .. msg)
end

local function format_key(k)
	return type(k) == 'string' and k or '[' .. tostring(k) .. ']'
end
local function format_value(v)
	return type(v) == 'string' and '"' .. v .. '"' or tostring(v)
end

function inspect(...)
	for i = 1, arg.n do
		print('arg' .. i..' = ' .. format_value(arg[i]))
		if type(arg[i]) == 'table' and next(arg[i]) then
			print('{')
			for k, v in arg[i] do
				print('    ' .. format_key(k) .. ' = ' .. format_value(v))
			end
			print('}')
		end
	end
	return unpack(arg)
end

p = setmetatable({}, {
	__metatable = false,
	__pow = function(self, v) self(v); return v end,
	__sub = function(self, v) self(v); return v end,
	__call = function(_, ...) return inspect(unpack(arg)) end,
})