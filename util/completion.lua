aux_completion = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

local filter_util = aux_filter_util

function public:complete_filter()
	if IsControlKeyDown() then -- TODO problem is ctrl-v, maybe find a better solution
		return
	end

	local filter_string = this:GetText()

	local completed_filter_string = select(3, strfind(filter_string, '([^;]*)/[^/;]*$'))
	local _, suggestions = filter_util.query(completed_filter_string)

	local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
	current_modifier = current_modifier or ''

	for _, suggestion in suggestions do
		if strsub(strupper(suggestion), 1, strlen(current_modifier)) == strupper(current_modifier) then
			this:SetText(strlower(strsub(filter_string, 1, start_index - 1) ..  suggestion))
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