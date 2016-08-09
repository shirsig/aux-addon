local m, public, private = aux.module'search_tab'

function private.valid_level_input(str)
	local number = tonumber(str)
	local bounded = number and aux.util.bound(1, 60, number)
	if number ~= bounded or strfind(str, '^0') then
		return false, bounded
	else
		return true
	end
end

private.blizzard_query = {}

private.blizzard_filter = setmetatable({}, {
	__newindex = function(_, key, value)
		m.update_form(key, value)
		m.blizzard_query[key] = value
	end,
})

function private.update_form(key, value)

	if key == 'class' and value ~= m.blizzard_query.class then
		m.blizzard_query.class = value
		UIDropDownMenu_ClearAll(m.subclass_dropdown)
		UIDropDownMenu_Initialize(m.subclass_dropdown, m.initialize_subclass_dropdown)
		m.blizzard_query.subclass = nil
		if value and GetAuctionItemSubClasses(value) then
			m.subclass_dropdown.button:Enable()
		else
			m.subclass_dropdown.button:Disable()
		end
		UIDropDownMenu_ClearAll(m.slot_dropdown)
		UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
		m.blizzard_query.slot = nil
		m.slot_dropdown.button:Disable()
	elseif key == 'subclass' and value ~= m.blizzard_query.subclass then
		m.blizzard_query.subclass = value
		UIDropDownMenu_ClearAll(m.slot_dropdown)
		UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
		m.blizzard_query.slot = nil
		if value and GetAuctionInvTypes(m.blizzard_query.class, value) then
			m.slot_dropdown.button:Enable()
		else
			m.slot_dropdown.button:Disable()
		end
	else
		m.blizzard_query[key] = value
	end

	if key == 'exact' then
		if value then
			for _, key in {'class', 'subclass', 'slot', 'quality'} do
				m[key..'_dropdown'].button:Disable()
			end
		else
			m.class_dropdown.button:Enable()
		end
		for _, key in {'min_level', 'max_level'} do
			if value then
				m[key..'_input']:Disable()
			else
				m[key..'_input']:Enable()
			end
		end
		if value then
			m.usable_checkbox:Disable()
		else
			m.usable_checkbox:Enable()
		end
	end

	if aux.util.set('min_level', 'max_level', 'usable', 'class', 'subclass', 'slot', 'quality')[key] then
		if value then
			m.exact_checkbox:Disable()
		elseif not aux.util.any({'min_level', 'max_level', 'usable', 'class', 'subclass', 'slot', 'quality'}, function(key) return m.blizzard_query[key] end) then
			m.exact_checkbox:Enable()
		end
	end
end

function private.get_form_query()
	local query_string

	local function add(part)
		if part then
			query_string = query_string and query_string..'/'..part or part
		end
	end

	local name = m.blizzard_query.name
	if aux.index(aux.filter.parse_query_string(name), 'blizzard', 1, 1) ~= 'name' then
		name = aux.filter.quote(name)
	end
	add(name)

	add(m.blizzard_query.exact and 'exact')
	add(m.blizzard_query.min_level)
	add(m.blizzard_query.max_level)
	add(m.blizzard_query.usable and 'usable')

	for _, class in {m.blizzard_query.class ~= 0 and m.blizzard_query.class} do
		local classes = {GetAuctionItemClasses()}
		add(strlower(classes[class]))
		for _, subclass in {m.blizzard_query.subclass ~= 0 and m.blizzard_query.subclass} do
			local subclasses = {GetAuctionItemSubClasses(class)}
			add(strlower(subclasses[subclass]))
			add(m.blizzard_query.slot ~= 0 and m.blizzard_query.slot and strlower(getglobal(m.blizzard_query.slot)))
		end
	end

	local quality = m.blizzard_query.quality
	if quality and quality >= 0 then
		add(strlower(getglobal('ITEM_QUALITY'..quality..'_DESC')))
	end

	return query_string
end

function private.set_form(components)
	m.clear_form()

	local class_index, subclass_index

	for _, filter in components.blizzard do
		if filter[1] == 'name' then
			local name = filter[2]
			if name and strsub(name, 1, 1) == '"' and strsub(name, -1, -1) == '"' then
				name = strsub(name, 2, -2)
			end
			m.name_input:SetText(aux.filter.unquote(filter[2]))
		elseif filter[1] == 'exact' then
			if not m.exact_checkbox:GetChecked() then
				m.exact_checkbox:Click()
			end
		elseif filter[1] == 'min_level' then
			m.min_level_input:SetText(tonumber(filter[2]))
		elseif filter[1] == 'max_level' then
			m.max_level_input:SetText(tonumber(filter[2]))
		elseif filter[1] == 'usable' then
			m.usable_checkbox:SetChecked(true)
		elseif filter[1] == 'class' then
			class_index = aux.info.item_class_index(filter[2])
			UIDropDownMenu_SetSelectedValue(m.class_dropdown, class_index)
		elseif filter[1] == 'subclass' then
			subclass_index = aux.info.item_subclass_index(class_index, filter[2])
			UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, subclass_index)
		elseif filter[1] == 'slot' then
			UIDropDownMenu_SetSelectedValue(m.slot_dropdown, ({GetAuctionInvTypes(class_index, subclass_index)})[aux.info.item_slot_index(class_index, subclass_index, filter[2])])
		elseif filter[1] == 'quality' then
			UIDropDownMenu_SetSelectedValue(m.quality_dropdown, aux.info.item_quality_index(filter[2]))
		end
	end

	for _, component in components.post do
		m.add_component(component)
	end
	m.update_filter_display()
end

function private.clear_form()
	m.name_input:SetText('')
	m.name_input:ClearFocus()
	if m.exact_checkbox:GetChecked() then
		m.exact_checkbox:Click()
	end
	m.min_level_input:SetText('')
	m.min_level_input:ClearFocus()
	m.max_level_input:SetText('')
	m.max_level_input:ClearFocus()
	m.usable_checkbox:SetChecked(nil)
	UIDropDownMenu_ClearAll(m.class_dropdown)
	UIDropDownMenu_ClearAll(m.subclass_dropdown)
	UIDropDownMenu_ClearAll(m.slot_dropdown)
	UIDropDownMenu_ClearAll(m.quality_dropdown)
	m.filter_input:ClearFocus()
	m.post_filter = {}
	m.filter_builder_state = {selected=0}
	m.update_filter_display()
end

function private.import_query_string()
	local components, error = aux.filter.parse_query_string(({strfind(m.search_box:GetText(), '^([^;]*)')})[3])
	if components then
		m.set_form(components)
	else
		aux.log(error)
	end
end

function private.export_query_string()
	local components, error = aux.filter.parse_query_string(m.get_form_query())
	if components then
		m.search_box:SetText(aux.filter.query_string({blizzard=components.blizzard, post=m.post_filter}))
		m.filter_input:ClearFocus()
		m.update_filter_display()
	else
		aux.log(error)
	end
end

function public.formatted_post_filter(components)
	local no_line_break
	local stack = {}
	local str = ''

	for i, component in components do
		if no_line_break then
			str = str..' '
		elseif i > 1 then
			str = str..'</p><p>'
			for _=1,getn(stack) do
				str = str..aux.gui.inline_color.content.backdrop..'----'..FONT_COLOR_CODE_CLOSE
			end
		end
		no_line_break = component[1] == 'operator' and component[2] == 'not'

		local component_text = component[2]
		if component[1] == 'operator' and component[2] ~= 'not' then
			component_text = component_text..(tonumber(component[3]) or '')
			tinsert(stack, component[3])
		elseif component[1] == 'filter' then
			for _, parameter in {component[3]} do
				if aux.filter.filters[component[2]].input_type == 'money' then
					parameter = aux.money.to_string(aux.money.from_string(parameter), nil, true, nil, nil, true)
				end
				component_text = component_text..': '..aux.auction_listing.colors.ORANGE..parameter..FONT_COLOR_CODE_CLOSE or component_text
			end
			while getn(stack) > 0 and stack[getn(stack)] do
				local top = tremove(stack)
				if tonumber(top) and top > 1 then
					tinsert(stack, top - 1)
					break
				end
			end
		end
		if m.filter_builder_state.selected == i then
			component_text = aux.auction_listing.colors.GREEN..component_text..FONT_COLOR_CODE_CLOSE
		else
			component_text = aux.auction_listing.colors.YELLOW..component_text..FONT_COLOR_CODE_CLOSE
		end
		str = str..m.data_link(i, component_text)
	end

	return '<html><body><p>'..str..'</p></body></html>'
end

function private.data_link(id, str)
	return '|H'..id..'|h'..str..'|h'
end

private.post_filter = {}
private.filter_builder_state = {selected = 0}

function private.data_link_click()
	local button = arg3
	local index = tonumber(arg1)
	if button == 'LeftButton' then
		m.filter_builder_state.selected = index
	elseif button == 'RightButton' then
		m.remove_component(index)
	end
	m.update_filter_display()
end

function private.remove_component(index)
	index = index or m.filter_builder_state.selected
	if m.filter_builder_state.selected >= index then
		m.filter_builder_state.selected = max(m.filter_builder_state.selected - 1, min(1, getn(m.post_filter)))
	end
	m.filter_builder_state[m.post_filter[index]] = nil
	tremove(m.post_filter, index)
end

function private.add_component(component)
	m.filter_builder_state.selected = m.filter_builder_state.selected + 1
	tinsert(m.post_filter, m.filter_builder_state.selected, component)
end

function private.add_dropdown_component()
	for _, str in {UIDropDownMenu_GetSelectedValue(m.filter_dropdown)} do
		if not aux.filter.filters[str] and str == 'and' or str == 'or' then
			local arity = m.filter_input:GetText()
			arity = tonumber(arity) and aux.util.round(tonumber(arity))
			if arity and arity < 2 then
				aux.log('Invalid operator suffix')
				return
			end
			str = str..(arity or '')
		end
		for _, filter in {aux.filter.filters[str]} do
			if filter.input_type ~= '' then
				str = str..'/'..m.filter_input:GetText()
			end
		end

		local components, error, suggestions = aux.filter.parse_query_string(str)

		if components then
			m.add_component(components.post[1])
			m.update_filter_display()
			m.filter_input:SetText('')
			m.filter_input:ClearFocus()
		else
			aux.log(error)
		end
	end
end

do
	local text

	function private.update_filter_display()
		text = m.formatted_post_filter(m.post_filter)
		m.filter_display:SetWidth(m.filter_display_size())
		m.set_filter_display_offset()
		m.filter_display:SetText(text)
	end

	function private.filter_display_size()
		local font, font_size = m.filter_display:GetFont()
		m.filter_display.measure:SetFont(font, font_size)
		local lines = 0
		local width = 0

		for line in string.gfind(text, '<p>(.-)</p>') do
			lines = lines + 1
			m.filter_display.measure:SetText(line)
			width = max(width, m.filter_display.measure:GetStringWidth())
		end

		return width, lines * (font_size + .5)
	end
end

function private.set_filter_display_offset(x_offset, y_offset)
	local scroll_frame = m.filter_display:GetParent()
	x_offset, y_offset = x_offset or scroll_frame:GetHorizontalScroll(), y_offset or scroll_frame:GetVerticalScroll()
	local width, height = m.filter_display_size()
	local x_lower_bound = min(0, scroll_frame:GetWidth() - width - 10)
	local x_upper_bound = 0
	local y_lower_bound = 0
	local y_upper_bound = max(0, height - scroll_frame:GetHeight())
	scroll_frame:SetHorizontalScroll(aux.util.bound(x_lower_bound, x_upper_bound, x_offset))
	scroll_frame:SetVerticalScroll(aux.util.bound(y_lower_bound, y_upper_bound, y_offset))
end

function private.initialize_filter_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.filter_dropdown, this.value)
		m.filter_button:SetText(this.value)
		if (not aux.filter.filters[this.value] or aux.filter.filters[this.value].input_type == '') and this.value ~= 'and' and this.value ~= 'or' then
			m.filter_input:Hide()
		else
			local _, _, suggestions = aux.filter.parse_query_string(UIDropDownMenu_GetSelectedValue(m.filter_dropdown)..'/')
			m.filter_input:SetNumeric(not aux.filter.filters[this.value] or aux.filter.filters[this.value].input_type == 'number')
			m.filter_input.complete = aux.completion.complete(function() return suggestions or {} end)
			m.filter_input:Show()
			m.filter_input:SetFocus()
		end
	end

	for _, filter in {'and', 'or', 'not', 'min-unit-buy', 'max-unit-bid', 'max-unit-bid', 'max-unit-buy', 'bid-profit', 'buy-profit', 'bid-vend-profit', 'buy-vend-profit', 'bid-dis-profit', 'buy-dis-profit', 'bid-pct', 'buy-pct', 'item', 'tooltip', 'min-lvl', 'max-lvl', 'rarity', 'left', 'utilizable', 'discard'} do
		UIDropDownMenu_AddButton{
			text = filter,
			value = filter,
			func = on_click,
		}
	end
end

function private.initialize_class_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.class_dropdown, this.value)
		m.blizzard_filter.class = this.value
	end

	if not m.exact_checkbox:GetChecked() then
		m.class_dropdown.button:Enable()

		UIDropDownMenu_AddButton{
			text = ALL,
			value = 0,
			func = on_click,
		}

		for i, class in { GetAuctionItemClasses() } do
			UIDropDownMenu_AddButton{
				text = class,
				value = i,
				func = on_click,
			}
		end
	else
		m.class_dropdown.button:Disable()
	end
end

function private.initialize_subclass_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, this.value)
		m.blizzard_filter.subclass = this.value
	end

	local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)

	if class_index and GetAuctionItemSubClasses(class_index) then
		UIDropDownMenu_AddButton{
			text = ALL,
			value = 0,
			func = on_click,
		}

		for i, subclass in {GetAuctionItemSubClasses(class_index)} do
			UIDropDownMenu_AddButton{
				text = subclass,
				value = i,
				func = on_click,
			}
		end
	end
end

function private.initialize_slot_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.slot_dropdown, this.value)
		m.blizzard_filter.slot = this.value
	end

	local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
	local subclass_index = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)

	if subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
		UIDropDownMenu_AddButton{
			text = ALL,
			value = 0,
			func = on_click,
		}

		for _, slot in {GetAuctionInvTypes(class_index, subclass_index)} do
			local slot_name = getglobal(slot)
			UIDropDownMenu_AddButton{
				text = slot_name,
				value = slot,
				func = on_click,
			}
		end
	end
end

function private.initialize_quality_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.quality_dropdown, this.value)
		m.blizzard_filter.quality = this.value
	end

	UIDropDownMenu_AddButton{
		text = ALL,
		value = -1,
		func = on_click,
	}
	for i=0,4 do
		UIDropDownMenu_AddButton{
			text = getglobal('ITEM_QUALITY'..i..'_DESC'),
			value = i,
			func = on_click,
		}
	end
end
