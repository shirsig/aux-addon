select(2, ...) 'aux'

function C(r, g, b, a)
	local mt = { __metatable = false, __newindex = pass, color = {r, g, b, a} }
	function mt:__call(text)
		local r, g, b, a = unpack(mt.color)
		if text then
			return format('|c%02X%02X%02X%02X', a, r, g, b) .. text .. FONT_COLOR_CODE_CLOSE
		else
			return r/255, g/255, b/255, a
		end
	end
	function mt:__concat(text)
		local r, g, b, a = unpack(mt.color)
		return format('|c%02X%02X%02X%02X', a, r, g, b) .. text
	end
	return setmetatable({}, mt)
end

M.color = immutable-{
	none = setmetatable({}, {__metatable=false, __newindex=pass, __call=function(_, v) return v end, __concat=function(_, v) return v end}),
	text = immutable-{enabled = C(255, 254, 250, 1), disabled = C(147, 151, 139, 1)},
	label = immutable-{enabled = C(216, 225, 211, 1), disabled = C(150, 148, 140, 1)},
	link = C(153, 255, 255, 1),
	window = immutable-{background = C(24, 24, 24, .93), border = C(30, 30, 30, 1)},
	panel = immutable-{background = C(24, 24, 24, 1), border = C(255, 255, 255, .03)},
	content = immutable-{background = C(42, 42, 42, 1), border = C(0, 0, 0, 0)},
	state = immutable-{enabled = C(70, 140, 70, 1), disabled = C(140, 70, 70, 1)},

	tooltip = immutable-{
		value = C(255, 255, 154, 1),
		merchant = C(204, 127, 25, 1),
		disenchant = immutable-{
			value = C(25, 153, 153, 1),
			distribution = C(204, 204, 51, 1),
			source = C(178, 178, 178, 1),
		}
	},

	blue = C(41, 146, 255, 1),
	green = C(22, 255, 22, 1),
	yellow = C(255, 255, 0, 1),
	orange = C(255, 146, 24, 1),
	red = C(255, 0, 0, 1),
	gray = C(187, 187, 187, 1),
	gold = C(255, 255, 154, 1),

	blizzard = C(0, 180, 255, 1),
}
