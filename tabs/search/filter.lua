aux.module 'search_tab'

function private.valid_level(str)
	local level = tonumber(str)
	return level and aux.util.bound(1, 60, level)
end

private.blizzard_query = setmetatable({}, {
	__newindex = function(_, key, value)
		if key == 'name' then
			m.name_input:SetText(value)
		elseif key == 'exact' then
			m.exact_checkbox:SetChecked(value)
		elseif key == 'min_level' then
			m.min_level_input:SetText(value)
		elseif key == 'max_level' then
			m.max_level_input:SetText(value)
		elseif key == 'usable' then
			m.usable_checkbox:SetChecked(value)
		elseif key == 'class' then
			UIDropDownMenu_Initialize(m.class_dropdown, m.initialize_class_dropdown)
			UIDropDownMenu_SetSelectedValue(m.class_dropdown, value)
		elseif key == 'subclass' then
			UIDropDownMenu_Initialize(m.subclass_dropdown, m.initialize_subclass_dropdown)
			UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, value)
		elseif key == 'slot' then
			UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
			UIDropDownMenu_SetSelectedValue(m.slot_dropdown, value)
		elseif key == 'quality' then
			UIDropDownMenu_Initialize(m.quality_dropdown, m.initialize_quality_dropdown)
			UIDropDownMenu_SetSelectedValue(m.quality_dropdown, value)
		end
	end,
	__index = function(_, key)
		if key == 'name' then
			return m.name_input:GetText()
		elseif key == 'exact' then
			return m.exact_checkbox:GetChecked()
		elseif key == 'min_level' then
			return tonumber(m.min_level_input:GetText())
		elseif key == 'max_level' then
			return tonumber(m.max_level_input:GetText())
		elseif key == 'usable' then
			return m.usable_checkbox:GetChecked()
		elseif key == 'class' then
			local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
			return (class_index or 0) > 0 and class_index or nil
		elseif key == 'subclass' then
			local subclass_index = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)
			return (subclass_index or 0) > 0 and subclass_index or nil
		elseif key == 'slot' then
			local slot_index = UIDropDownMenu_GetSelectedValue(m.slot_dropdown)
			return (slot_index or 0) > 0 and slot_index or nil
		elseif key == 'quality' then
			local quality_code = UIDropDownMenu_GetSelectedValue(m.quality_dropdown)
			return (quality_code or -1) >= 0 and quality_code or nil
		end
	end,
})

function private.update_form()
	if m.blizzard_query.class and GetAuctionItemSubClasses(m.blizzard_query.class) then
		m.subclass_dropdown.button:Enable()
	else
		m.subclass_dropdown.button:Disable()
	end

	if m.blizzard_query.subclass and GetAuctionInvTypes(m.blizzard_query.class, m.blizzard_query.subclass) then
		m.slot_dropdown.button:Enable()
	else
		m.slot_dropdown.button:Disable()
	end

	if m.blizzard_query.exact then
		for _, key in {'class', 'subclass', 'slot', 'quality'} do
			m[key..'_dropdown'].button:Disable()
		end
	else
		m.class_dropdown.button:Enable()
		m.quality_dropdown.button:Enable()
	end
	for _, key in {'min_level', 'max_level'} do
		if m.blizzard_query.exact then
			m[key..'_input']:Disable()
		else
			m[key..'_input']:Enable()
		end
	end
	if m.blizzard_query.exact then
		m.usable_checkbox:Disable()
	else
		m.usable_checkbox:Enable()
	end

	if aux.util.any({'min_level', 'max_level', 'usable', 'class', 'subclass', 'slot', 'quality'}, function(key) return m.blizzard_query[key] end) then
		m.exact_checkbox:Disable()
	else
		m.exact_checkbox:Enable()
	end
end

function private.get_filter_builder_query()
	local query_string

	local function add(part)
		if part then
			query_string = query_string and query_string..'/'..part or part
		end
	end

	local name = m.blizzard_query.name
	if not aux.index(aux.filter.parse_query_string(name), 'blizzard', 'name') then
		name = aux.filter.quote(name)
	end
	add((name ~= '' or m.blizzard_query.exact) and name)

	add(m.blizzard_query.exact and 'exact')
	add(m.blizzard_query.min_level or m.blizzard_query.max_level and 1)
	add(m.blizzard_query.max_level)
	add(m.blizzard_query.usable and 'usable')

	for _, class in {m.blizzard_query.class} do
		local classes = {GetAuctionItemClasses()}
		add(strlower(classes[class]))
		for _, subclass in {m.blizzard_query.subclass} do
			local subclasses = {GetAuctionItemSubClasses(class)}
			add(strlower(subclasses[subclass]))
			add(m.blizzard_query.slot and strlower(getglobal(m.blizzard_query.slot)))
		end
	end

	local quality = m.blizzard_query.quality
	if quality and quality >= 0 then
		add(strlower(getglobal('ITEM_QUALITY'..quality..'_DESC')))
	end

	local post_filter_string = aux.filter.query_string{blizzard={}, post=m.post_filter}
	add(post_filter_string ~= '' and post_filter_string)

	return query_string or ''
end

function private.set_form(components)
	m.clear_form()
	for key, filter in components.blizzard do
		m.blizzard_query[key] = filter[2]
	end
	for _, component in components.post do
		m.add_component(component)
	end
	m.update_filter_display()
end

function private.clear_form()
	m.blizzard_query.name = ''
	m.name_input:ClearFocus()
	m.blizzard_query.exact = false
	m.blizzard_query.min_level = ''
	m.min_level_input:ClearFocus()
	m.blizzard_query.max_level = ''
	m.max_level_input:ClearFocus()
	m.blizzard_query.usable = false
	UIDropDownMenu_ClearAll(m.class_dropdown)
	UIDropDownMenu_ClearAll(m.subclass_dropdown)
	UIDropDownMenu_ClearAll(m.slot_dropdown)
	UIDropDownMenu_ClearAll(m.quality_dropdown)
	m.filter_parameter_input:ClearFocus()
	m.post_filter = {}
	m.filter_builder_state = {selected=0}
	m.update_filter_display()
end

function private.import_query_string()
	local components, error = aux.filter.parse_query_string(aux.util.select(3, strfind(m.search_box:GetText(), '^([^;]*)')))
	if components then
		m.set_form(components)
	else
		aux.log(error)
	end
end

function private.export_query_string()
	m.search_box:SetText(m.get_filter_builder_query())
	m.filter_parameter_input:ClearFocus()
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
				str = str..aux.gui.color.content.background('----')
			end
		end
		no_line_break = component[1] == 'operator' and component[2] == 'not'

		local filter_color = (m.filter_builder_state.selected == i and aux.gui.color.orange or aux.gui.color.aux)
		local component_text = filter_color(component[2])
		if component[1] == 'operator' and component[2] ~= 'not' then
			component_text = component_text..filter_color(tonumber(component[3]) or '')
			tinsert(stack, component[3])
		elseif component[1] == 'filter' then
			for parameter in aux.util.present(component[3]) do
				if component[2] == 'item' then
					parameter = aux.info.display_name(aux.cache.item_id(parameter)) or '['..parameter..']'
				elseif aux.filter.filters[component[2]].input_type == 'money' then
					parameter = aux.money.to_string(aux.money.from_string(parameter), nil, true)
				end
				component_text = component_text..filter_color(': ')..parameter
			end
			while getn(stack) > 0 and stack[getn(stack)] do
				local top = tremove(stack)
				if tonumber(top) and top > 1 then
					tinsert(stack, top - 1)
					break
				end
			end
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

function private.add_post_filter()
	for str in aux.util.present(m.filter_input:GetText()) do
		for filter in aux.util.present(aux.filter.filters[str]) do
			if filter.input_type ~= '' then
				str = str..'/'..m.filter_parameter_input:GetText()
			end
		end

		local components, error, suggestions = aux.filter.parse_query_string(str)

		if components and getn(components.blizzard) == 0 and getn(components.post) == 1 then
			m.add_component(components.post[1])
			m.update_filter_display()
			m.filter_parameter_input:SetText('')
			m.filter_input:HighlightText()
			m.filter_input:SetFocus()
		elseif error then
			aux.log(error)
		end
	end
end

do
	local text = ''

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
	for _, filter in {'and', 'or', 'not', 'min-unit-bid', 'min-unit-buy', 'max-unit-bid', 'max-unit-buy', 'bid-profit', 'buy-profit', 'bid-vend-profit', 'buy-vend-profit', 'bid-dis-profit', 'buy-dis-profit', 'bid-pct', 'buy-pct', 'item', 'tooltip', 'min-lvl', 'max-lvl', 'rarity', 'left', 'utilizable', 'discard'} do
		UIDropDownMenu_AddButton{
			text = filter,
			value = filter,
			func = function()
				m.filter_input:SetText(this.value)
				if aux.index(aux.filter.filters[this.value], 'input_type') == '' or this.value == 'not' then
					m.add_post_filter()
				elseif aux.filter.filters[this.value] then
					m.filter_parameter_input:Show()
					m.filter_parameter_input:SetFocus()
				else
					m.filter_input:SetFocus()
				end
			end,
		}
	end
end

function private.initialize_class_dropdown()
	local function on_click()
		if this.value ~= m.blizzard_query.class then
			UIDropDownMenu_SetSelectedValue(m.class_dropdown, this.value)
			UIDropDownMenu_ClearAll(m.subclass_dropdown)
			UIDropDownMenu_Initialize(m.subclass_dropdown, m.initialize_subclass_dropdown)
			UIDropDownMenu_ClearAll(m.slot_dropdown)
			UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
			m.update_form()
		end
	end

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
end

function private.initialize_subclass_dropdown()
	local function on_click()
		if this.value ~= m.blizzard_query.subclass then
			UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, this.value)
			UIDropDownMenu_ClearAll(m.slot_dropdown)
			UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
			m.update_form()
		end
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
		m.update_form()
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
		m.update_form()
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
