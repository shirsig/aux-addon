aux.module 'completion'

function public:complete_filter()
	if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
		return
	end

	local filter_string = this:GetText()

	local completed_filter_string = ({strfind(filter_string, '([^;]*)/[^/;]*$')})[3]
	local _, suggestions = filter.query(completed_filter_string or '')

	local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
	current_modifier = current_modifier or ''

	for _, suggestion in suggestions do
		if strsub(strupper(suggestion), 1, strlen(current_modifier)) == strupper(current_modifier) then
			this:SetText(strlower(strsub(filter_string, 1, start_index - 1).. suggestion))
			this:HighlightText(strlen(filter_string), -1)
			return
		end
	end
end

function public.complete(options)
	return function(self)
		if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
			return
		end

		local text = self:GetText()

		for _, item_name in options() do
			if strsub(strupper(item_name), 1, strlen(text)) == strupper(text) then
				self:SetText(strlower(item_name))
				self:HighlightText(strlen(text), -1)
				return
			end
		end
	end
end