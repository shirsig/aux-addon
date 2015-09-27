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
	for item_id=1,40000 do
		name = GetItemInfo(item_id)
		if name and strfind(strupper(name), '^' .. strupper(text)) then
			this:SetText(name)
			this:HighlightText(textlen, -1)
			return
		end
	end
end