Aux.completion = {}

local NUM_MATCHES = 5

local leven, fuzzy, populate_dropdown, toggle_dropdown, suggestions, highlight

local item_names = {}

local current_suggestions = {}
local selected_index


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
			local rating = 1
			for i=3,getn(match) do
				rating = rating * (strlen(match[i]) + 1)
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
	
	local best = {}
	for _, name in ipairs(item_names) do
		local rating = matcher(name)
		if rating then
			if getn(best) < NUM_MATCHES then
				tinsert(best, { name=name, rating=rating })
				sort(best, function(a, b) return a.rating < b.rating end)
			else
				if best[1].rating > rating then
					best[1] = { name=name, rating=rating }
					sort(best, function(a, b) return a.rating < b.rating end)
				end
			end
		end
	end
	
	return Aux.util.map(best, function(match) return match.name end)
end

function Aux.completion.make_suggestions(input_box)
	selected_index = nil
	update_highlighting()
	local input = input_box:GetText()
	if input == '' then
		current_suggestions = {}
	else
		current_suggestions = suggestions(input)
		UIDropDownMenu_Initialize(AuxCompletionDropDown, function() populate_dropdown(input_box, current_suggestions) end)
	end
	
	if DropDownList1:IsVisible() then
		toggle_dropdown(input_box)
	end
	toggle_dropdown(input_box)
end

function Aux.completion.highlight_next(input_box)
	if getn(current_suggestions) > 0 then
		selected_index = selected_index and math.mod(selected_index, getn(current_suggestions)) + 1 or 1
	end
	update_highlighting()
end

function Aux.completion.highlighted()
	return selected_index ~= nil 
end

function Aux.completion.select(input_box)
	Aux.completion.set_quietly(input_box, current_suggestions[selected_index])
	selected_index = nil
	update_highlighting()
	CloseDropDownMenus(1)
end

function Aux.completion.set_quietly(edit_box, text)
	local orig = edit_box:GetScript('OnTextChanged')
	edit_box:SetScript('OnTextChanged', function() edit_box:SetScript('OnTextChanged', orig) end)
	edit_box:SetText(text)
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