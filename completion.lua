Aux.completion = {}

local NUM_MATCHES = 5

local fuzzy, populate_dropdown, toggle_dropdown, suggestions, update_highlighting

local item_names = {}

for item_id=1,30000 do
	local name = GetItemInfo(item_id)
	if name then
		tinsert(item_names, name)
	end
end

function fuzzy(input)
	local uppercase_input = strupper(input)
	local pattern = '(.*)'
	for i=1,strlen(uppercase_input) do
		pattern = pattern .. string.sub(uppercase_input, i, i) .. '(.*)'
	end
	return function(item_name)
		local match = { string.find(strupper(item_name), pattern) }
		if match[1] then
			local rating = 0
			for i=4,getn(match)-1 do
				if strlen(match[i]) == 0 then
					rating = rating + 1
				end
			end
			return rating
		end
	end
end

function update_highlighting()
	for i=1,32 do
		local highlight = getglobal('DropDownList1Button' .. i .. 'Highlight')
		if i == selected_index then
			highlight:Show()
		else
			highlight:Hide()
		end
	end
end

function suggestions(input)
	local matcher = fuzzy(input)
	function fuzzy_sort(array)
		sort(array, function(a, b) return strlen(a.name) < strlen(b.name) end)
		sort(array, function(a, b) return b.rating < a.rating end)
		return array
	end
	
	local best = {}
	for _, name in ipairs(item_names) do
		local rating = matcher(name)
		if rating then
			local candidate = { name=name, rating=rating }
			if getn(best) < NUM_MATCHES then
				tinsert(best, candidate)
				fuzzy_sort(best)
			else
				best[getn(best)] = fuzzy_sort({ best[getn(best)], candidate })[1]
				fuzzy_sort(best)
			end
		end
	end

	return Aux.util.map(best, function(match) return match.name end)
end

function populate_dropdown(input_box, suggestions)
	for _, suggestion in ipairs(suggestions) do
		UIDropDownMenu_AddButton{
			text = suggestion,
			value = suggestion,
			notCheckable = true,
			func = function()
				Aux.completion.set_quietly(input_box, this.value)
			end,
		}
	end
end

function toggle_dropdown(input_box)
	ToggleDropDownMenu(1, nil, AuxCompletionDropDown, input_box, -12, 4)
end

function Aux.completion.completor()
	local self = {}
	
	local current_suggestions = {}
	local selected_index = 0
	local current_input
	local programmatically_set_input
	
	function self.close()
	CloseDropDownMenus(1)
	end

	function self.set_quietly(edit_box, text)
		programmatically_set_input = text
		edit_box:SetText(text)
	end
	
	function self.highlighted()
		return selected_index ~= 0 
	end
	
	function self.suggest(input_box)
		
		local input = input_box:GetText()
		if programmatically_set_input == input then
			programmatically_set_input = nil
			return
		end
		programmatically_set_input = nil
		
		current_input = input
		selected_index = 0
		update_highlighting()
		
		if current_input == '' then
			current_suggestions = {}
		else
			current_suggestions = suggestions(current_input)
			UIDropDownMenu_Initialize(AuxCompletionDropDown, function() populate_dropdown(input_box, current_suggestions) end)
		end
		
		if DropDownList1:IsVisible() then
			toggle_dropdown(input_box)
		end
		toggle_dropdown(input_box)
	end
	
	function self.next(input_box)
		if getn(current_suggestions) > 0 then
			selected_index = selected_index > 0 and math.mod(selected_index + 1, getn(current_suggestions) + 1) or 1
			update_highlighting()
			if selected_index == 0 then
				Aux.completion.set_quietly(input_box, current_input)
			else	
				Aux.completion.set_quietly(input_box, current_suggestions[selected_index])
			end
		end
	end
	
	function self.previous(input_box)
		if getn(current_suggestions) > 0 then
			selected_index = selected_index > 0 and math.mod(selected_index + 1, getn(current_suggestions) + 1) or 1
			update_highlighting()
			if selected_index == 0 then
				Aux.completion.set_quietly(input_box, current_input)
			else	
				Aux.completion.set_quietly(input_box, current_suggestions[selected_index])
			end
		end
	end
	
	return self
end