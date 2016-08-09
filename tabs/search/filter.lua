local m, public, private = aux.module'search_tab'

function private.get_form()
	local query_string = ''

	local function add(part)
		query_string = query_string == '' and part or query_string..'/'..part
	end

	local name = m.name_input:GetText()
	name = name == '' and name or aux.filter.quote(name)
	add(name)

	if m.exact_checkbox:GetChecked() then
		add('exact')
	end

	local min_level = m.blizzard_level(m.min_level_input:GetText())
	if min_level then
		add(min_level)
	end

	local max_level = m.blizzard_level(m.max_level_input:GetText())
	if max_level then
		add(max_level)
	end

	if m.usable_checkbox:GetChecked() then
		add('usable')
	end

	local class = UIDropDownMenu_GetSelectedValue(m.class_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.class_dropdown)
	if class then
		local classes = { GetAuctionItemClasses() }
		add(strlower(classes[class]))
		local subclass = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)
		if subclass then
			local subclasses = {GetAuctionItemSubClasses(class)}
			add(strlower(subclasses[subclass]))
			local slot = UIDropDownMenu_GetSelectedValue(m.slot_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.slot_dropdown)
			if slot then
				add(strlower(getglobal(slot)))
			end
		end
	end

	local quality = UIDropDownMenu_GetSelectedValue(m.quality_dropdown)
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
			m.exact_checkbox:SetChecked(true)
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

	m.post_components = components.post
	m.update_filter_display()
end

function private.clear_form()
	m.name_input:SetText('')
	m.name_input:ClearFocus()
	m.exact_checkbox:SetChecked(nil)
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
	m.post_components = {}
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
	local components, error = aux.filter.parse_query_string(m.get_form())
	if components then
		m.search_box:SetText(aux.filter.query_string({blizzard=components.blizzard, post=m.post_components}))
		m.filter_input:ClearFocus()
		m.update_filter_display()
	else
		aux.log(error)
	end
end

private.post_components = {}

function private.add_post_component()
	local name = UIDropDownMenu_GetSelectedValue(m.filter_dropdown)
	if name then
		local filter = name
		if not aux.filter.filters[name] and filter == 'and' or filter == 'or' then
			local arity = m.filter_input:GetText()
			arity = tonumber(arity) and aux.util.round(tonumber(arity))
			if arity and arity < 2 then
				aux.log('Invalid operator suffix')
				return
			end
			filter = filter..(arity or '')
		end
		if aux.filter.filters[name] and aux.filter.filters[name].input_type ~= '' then
			filter = filter..'/'..m.filter_input:GetText()
		end

		local components, error, suggestions = aux.filter.parse_query_string(filter)

		if components then
			tinsert(m.post_components, components.post[1])
			m.update_filter_display()
			m.filter_input:SetText('')
			m.filter_input:ClearFocus()
		else
			aux.log(error)
		end
	end
end

function private.remove_post_filter()
	tremove(m.post_components)
	m.update_filter_display()
end

do
	local text

	function private.update_filter_display()
		text = aux.filter.indented_post_query_string(m.post_components)
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
		local old_value = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
		UIDropDownMenu_SetSelectedValue(m.class_dropdown, this.value)
		if this.value ~= old_value then
			UIDropDownMenu_ClearAll(m.subclass_dropdown)
			UIDropDownMenu_Initialize(m.subclass_dropdown, m.initialize_subclass_dropdown)
			UIDropDownMenu_ClearAll(m.slot_dropdown)
			UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
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
		local old_value = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)
		UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, this.value)
		if this.value ~= old_value then
			UIDropDownMenu_ClearAll(m.slot_dropdown)
			UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
		end
	end

	local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)

	if class_index and GetAuctionItemSubClasses(class_index) then
		m.subclass_dropdown.button:Enable()

		UIDropDownMenu_AddButton{
			text = ALL,
			value = 0,
			func = on_click,
		}

		for i, subclass in { GetAuctionItemSubClasses(class_index) } do
			UIDropDownMenu_AddButton{
				text = subclass,
				value = i,
				func = on_click,
			}
		end
	else
		m.subclass_dropdown.button:Disable()
	end
end

function private.initialize_slot_dropdown()

	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.slot_dropdown, this.value)
	end

	local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
	local subclass_index = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)

	if class_index and subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
		m.slot_dropdown.button:Enable()

		UIDropDownMenu_AddButton{
			text = ALL,
			value = 0,
			func = on_click,
		}

		for _, slot in { GetAuctionInvTypes(class_index, subclass_index) } do
			local slot_name = getglobal(slot)
			UIDropDownMenu_AddButton{
				text = slot_name,
				value = slot,
				func = on_click,
			}
		end
	else
		m.slot_dropdown.button:Disable()
	end
end

function private.initialize_quality_dropdown()

	local function on_click()
		UIDropDownMenu_SetSelectedValue(m.quality_dropdown, this.value)
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
