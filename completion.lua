Aux.completion = {}

local NUM_MATCHES = 5

local fuzzy, generate_suggestions

local items = {}

local potentially_auctionable_items = {}
function _process_batch(i)
    for j=i, i+1000 do
        local name = GetItemInfo('item:'..j)
        if name then
            local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink('item:'..j) end)
            if not Aux.info.tooltip_match({'binds when picked up'}, tooltip) and not Aux.info.tooltip_match({'quest item'}, tooltip) then
                Aux.log(name)
                tinsert(potentially_auctionable_items, { id=j, s=0 })
            end
        end
    end
    if i+1000 > 30000 then
        snipe.log(getn(potentially_auctionable_items))
    else
        local t0 = time()
        Aux.control.as_soon_as(function() return time() - t0 > 1 end, function()
            return _process_batch(i+1000)
        end)
    end
end

function find_auctionable_items()
    _process_batch(1)
end

find_auctionable_items()

for item_id=1,30000 do
	local name = GetItemInfo(item_id)
	if name then
		tinsert(items, { name=name, id=item_id })
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

function generate_suggestions(input)
	local matcher = fuzzy(input)
	function fuzzy_sort(array)
		sort(array, function(a, b) return strlen(a.name) < strlen(b.name) end)
		sort(array, function(a, b) return b.rating < a.rating end)
		return array
	end
	
	local best = {}
	for _, item in ipairs(items) do
		local rating = matcher(item.name)
		if rating then
			local candidate = { name=item.name, id=item.id, rating=rating }
			if getn(best) < NUM_MATCHES then
				tinsert(best, candidate)
				fuzzy_sort(best)
			else
				best[getn(best)] = fuzzy_sort({ best[getn(best)], candidate })[1]
				fuzzy_sort(best)
			end
		end
	end

	return Aux.util.map(best, function(match) return { text=match.name, display_text='|c'..Aux_QualityColor(({GetItemInfo(match.id)})[3])..'['..match.name..']'..'|r', value=match.id } end)
end

function Aux.completion.completor(edit_box)
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
--					self.set_quietly(text)
                    local info = { GetItemInfo(this.value) }
                    AuxBuyFiltersItemIconTexture:SetTexture(info[9])
                    AuxBuyFiltersItemName:SetText(text)
                    local color = ITEM_QUALITY_COLORS[info[3]]
                    AuxBuyFiltersItemName:SetTextColor(color.r, color.g, color.b)

                    Aux.browse_frame.set_item(this.value)
                    Aux.browse_frame.update_item()
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
