Aux.util = {}

function Aux.util.iter(array)
	local with_index = ipairs(array)
	return function()
		local _, value = with_index
		return value
	end
end

function Aux.util.item_name_autocomplete()
	local text = this:GetText()
	local textlen = strlen(text)
	local name
	for item_id=1,30000 do
		name = GetItemInfo(item_id)
		if name and strfind(strupper(name), '^' .. strupper(text)) then
			this:SetText(name)
			this:HighlightText(textlen, -1)
			return
		end
	end
end

function Aux.util.format_money(val)

	local g = math.floor(val / 10000)
	
	val = val - g * 10000
	
	local s = math.floor(val / 100)
	
	val = val - s * 100
	
	local c = math.floor(val)
	
	local g_string = g ~= 0 and g .. 'g' or ''
	local s_string = s ~= 0 and s .. 's' or ''
	local c_string = (c ~= 0 or g == 0 and s == 0) and c .. 'c' or ''
			
	return g_string .. s_string .. c_string
end