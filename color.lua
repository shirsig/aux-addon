module 'aux'

local COLORS = {
	text = {enabled = {255, 254, 250, 1}, disabled = {147, 151, 139, 1}},
	label = {enabled = {216, 225, 211, 1}, disabled = {150, 148, 140, 1}},
	link = {153, 255, 255, 1},
	window = {background = {24, 24, 24, .93}, border = {30, 30, 30, 1}},
	panel = {background = {24, 24, 24, 1}, border = {255, 255, 255, .03}},
	content = {background = {42, 42, 42, 1}, border = {0, 0, 0, 0}},
	state = {enabled = {70, 180, 70, 1}, disabled = {190, 70, 70, 1}},

	blue = {41, 146, 255, 1},
	green = {22, 255, 22, 1},
	yellow = {255, 255, 0, 1},
	orange = {255, 146, 24, 1},
	red = {255, 0, 0, 1},
	gray = {187, 187, 187, 1},

	blizzard = {0, 180, 255, 1},
	aux = {255, 255, 154, 1},
}

do
	local function index_handler(self, key)
		self.private.table = self.private.table[key]
		if getn(self.private.table) == 0 then
			return self.public
		else
			local color = copy(self.private.table)
			self.private.table = COLORS
			return self.private.callback(color)
		end
	end
	function private.color_accessor(callback)
		return function()
			return index_function({ callback=callback, table=COLORS }, index_handler)
		end
	end
end

do
	local mt = {
		__call = function(self, text)
			local r, g, b, a = unpack(self)
			if text then
				return format('|c%02X%02X%02X%02X', a, r*255, g*255, b*255) .. text .. FONT_COLOR_CODE_CLOSE
			else
				return r, g, b, a
			end
		end
	}
	public.color.get = color_accessor(function(color)
		local r, g, b, a = unpack(color)
		return setmetatable(A(r/255, g/255, b/255, a), mt)
	end)
end

public.inline_color.get = color_accessor(function(color)
	local r, g, b, a = unpack(color)
	return format('|c%02X%02X%02X%02X', a, r, g, b)
end)
