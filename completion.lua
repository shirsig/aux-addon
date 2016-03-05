local m = {}
Aux.completion = m

do
	local sorted_item_names
	function m.sorted_item_names()
		if not sorted_item_names then
			sorted_item_names = {}
			for _, item_info in ipairs(Aux.static.items()) do
				tinsert(sorted_item_names, item_info.name)
			end
			sort(sorted_item_names, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
		end
		return sorted_item_names
	end
end

function m:complete()
	if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
		return
	end

	local filter_string = this:GetText()

	local completed_filter_string = ({strfind(filter_string, '([^;]*)/[^/;]*$')})[3]
	local _, suggestions = Aux.scan_util.filter_from_string(completed_filter_string or '')

	local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
	current_modifier = current_modifier or ''

	for _, suggestion in ipairs(suggestions) do
		if string.sub(strupper(suggestion), 1, strlen(current_modifier)) == strupper(current_modifier) then
			this:SetText(strlower(string.sub(filter_string, 1, start_index - 1).. suggestion))
			this:HighlightText(strlen(filter_string), -1)
			return
		end
	end
end

function m.completor(options)
	return function(self)
		if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
			return
		end

		local text = self:GetText()

		for _, item_name in ipairs(options) do
			if string.sub(strupper(item_name), 1, strlen(text)) == strupper(text) then
				self:SetText(strlower(item_name))
				self:HighlightText(strlen(text), -1)
				return
			end
		end
	end
end