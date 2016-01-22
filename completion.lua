local private, public = {}, {}
Aux.completion = public

local NUM_MATCHES = 5

local fuzzy, generate_suggestions

function fuzzy(input)
	local uppercase_input = strupper(input)
	local pattern = '(.*)'
	for i=1,strlen(uppercase_input) do
		if strfind(string.sub(uppercase_input, i, i), '%w') or strfind(string.sub(uppercase_input, i, i), '%s') then
			pattern = pattern .. string.sub(uppercase_input, i, i) .. '(.*)'
		end
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

function generate_suggestions(input)
	local matcher = fuzzy(input)
	function fuzzy_sort(array)
		sort(array, function(a, b) return strlen(a.name) < strlen(b.name) end)
		sort(array, function(a, b) return b.rating < a.rating end)
		return array
	end
	
	local best = {}
	for _, id in ipairs(Aux.static.item_ids()) do
		local item_info = Aux.static.item_info(id)
		local rating = matcher(item_info.name)
		if rating then
			local candidate = { name=item_info.name, id=item_info.id, rating=rating }
			if getn(best) < NUM_MATCHES then
				tinsert(best, candidate)
				fuzzy_sort(best)
			else
				best[getn(best)] = fuzzy_sort({ best[getn(best)], candidate })[1]
				fuzzy_sort(best)
			end
		end
	end

	return Aux.util.map(best, function(match) return { text=match.name, display_text='|c'..Aux_QualityColor(Aux.static.item_info(match.id).quality)..'['..match.name..']'..'|r', value=match.id } end)
end

function public.completor(edit_box)
	local self = {}
	
	local suggestions = {}
	local index = 0
	local input
	local quietly_set_text
	
	local fill_dropdown, update_dropdown, update_highlighting

	function fill_dropdown()
		for _, suggestion in ipairs(suggestions) do
            local text = suggestion.text
			UIDropDownMenu_AddButton{
				text = suggestion.display_text,
				value = suggestion.value,
				notCheckable = true,
				func = function()
					self.set_quietly(text)
				end,
			}
		end
	end

	function update_dropdown()
		function toggle()
			ToggleDropDownMenu(1, nil, AuxCompletionDropDown, edit_box, -12, 4)
		end
		
		if DropDownList1:IsVisible() then
			toggle()
		end
		toggle()
	end
	
	function update_highlighting()
		for i=1,32 do
			local highlight = getglobal('DropDownList1Button' .. i .. 'Highlight')
			if i == index then
				highlight:Show()
			else
				highlight:Hide()
			end
		end
	end
	
	function self.close()
		CloseDropDownMenus(1)
	end

	function self.set_quietly(text)
		quietly_set_text = text
		edit_box:SetText(text)
	end
	
	function self.open()
		local _, owner = DropDownList1:GetPoint()
		return DropDownList1:IsVisible() and owner == edit_box
	end
	
	function self.suggest()
		local new_input = edit_box:GetText()
		if new_input == quietly_set_text then
			quietly_set_text = nil
			return
		end
		quietly_set_text = nil
		
		input = new_input
		index = 0
		update_highlighting()
		
		if input == '' then
			suggestions = {}
		else
			suggestions = generate_suggestions(input)
			UIDropDownMenu_Initialize(AuxCompletionDropDown, function() fill_dropdown() end)
		end
		
		update_dropdown()
	end
	
	function self.next()
		update_dropdown()
		if getn(suggestions) > 0 then
			index = index > 0 and math.mod(index + 1, getn(suggestions) + 1) or 1
			update_highlighting()
			if index == 0 then
				self.set_quietly(input)
			else	
				self.set_quietly(suggestions[index].text)
            end
		end
	end
	
	function self.previous()
		update_dropdown()
		if getn(suggestions) > 0 then
			index = index > 0 and index - 1 or getn(suggestions)
			update_highlighting()
			if index == 0 then
				self.set_quietly(input)
			else	
				self.set_quietly(suggestions[index].text)
			end
		end
	end
	
	return self
end

function public.selector(edit_box)
    local self = {}

    local suggestions = {}
    local index = 0
    local input

    local fill_dropdown, update_dropdown, update_highlighting

    function fill_dropdown()
        for i, suggestion in ipairs(suggestions) do
            local text = suggestion.text
            UIDropDownMenu_AddButton{
                text = suggestion.display_text,
                value = i,
                notCheckable = true,
                func = function()
                    index = this.value
                    AuxItemSearchFrameItemItemInputBox:ClearFocus()
                end,
            }
        end
    end

    function update_dropdown()
        function toggle()
            ToggleDropDownMenu(1, nil, AuxCompletionDropDown, edit_box, -12, 4)
        end

        if DropDownList1:IsVisible() then
            toggle()
        end
        toggle()
		DropDownList1.aux = true
		DropDownList1:SetScript('OnHide', function()
			DropDownList1.aux = false
		end)
    end

    function update_highlighting()
        for i=1,32 do
            local highlight = getglobal('DropDownList1Button' .. i .. 'Highlight')
            if i == index then
                highlight:Show()
            else
                highlight:Hide()
            end
        end
    end

    function self.close()
        CloseDropDownMenus(1)
    end

    function self.open()
        local _, owner = DropDownList1:GetPoint()
        return DropDownList1:IsVisible() and owner == edit_box
    end

    function self.suggest()
        local new_input = edit_box:GetText()

        input = new_input

        if input == '' then
            suggestions = {}
        else
            suggestions = generate_suggestions(input)
            UIDropDownMenu_Initialize(AuxCompletionDropDown, function() fill_dropdown() end)
        end

        index = 1
        update_highlighting()

        update_dropdown()
    end

    function self.next()
        update_dropdown()
        if getn(suggestions) > 0 then
            index = math.mod(index, getn(suggestions)) + 1
            update_highlighting()
        end
    end

    function self.previous()
        update_dropdown()
        if getn(suggestions) > 0 then
            index = index > 1 and index - 1 or getn(suggestions)
            update_highlighting()
        end
    end

    function self.selected_value()
        return suggestions[index] and suggestions[index].value
    end

    function self.clear()
        index = 1
        suggestions = {}
    end

    return self
end

function public.UIDropDownMenu_StartCounting(frame)
	if not frame.aux then
		return Aux.orig.UIDropDownMenu_StartCounting(frame)
	end
end