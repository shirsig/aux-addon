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

function Aux.util.set_add(set, key)
    set[key] = true
end

function Aux.util.set_remove(set, key)
    set[key] = nil
end

function Aux.util.set_contains(set, key)
    return set[key] ~= nil
end

function Aux.util.set_size(set)
    local size = 0
	for _,_ in pairs(set) do
		size = size + 1
	end
	return size
end

function Aux.util.set_to_array(set)
	local array = {}
	for element, _ in pairs(set) do
		tinsert(array, element)
	end
	return array
end

function Aux.util.any(xs, p)
	holds = false
	for _, x in ipairs(xs) do
		holds = holds or p(x)
	end
	return holds
end

function Aux.util.all(xs, p)
	holds = true
	for _, x in ipairs(xs) do
		holds = holds and p(x)
	end
	return holds
end