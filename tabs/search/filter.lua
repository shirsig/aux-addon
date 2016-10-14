module 'aux.tabs.search'

local info = require 'aux.util.info'
local money = require 'aux.util.money'
local cache = require 'aux.core.cache'
local filter_util = require 'aux.util.filter'

function valid_level(str)
	local level = tonumber(str)
	return level and bounded(1, 60, level)
end

blizzard_query = setmetatable(t, {
	__index = function(_, key)
		if key == 'name' then
			return name_input:GetText()
		elseif key == 'exact' then
			return exact_checkbox:GetChecked()
		elseif key == 'min_level' then
			return tonumber(min_level_input:GetText())
		elseif key == 'max_level' then
			return tonumber(max_level_input:GetText())
		elseif key == 'usable' then
			return usable_checkbox:GetChecked()
		elseif key == 'class' then
			local class_index = UIDropDownMenu_GetSelectedValue(class_dropdown)
			return (class_index or 0) > 0 and class_index or nil
		elseif key == 'subclass' then
			local subclass_index = UIDropDownMenu_GetSelectedValue(subclass_dropdown)
			return (subclass_index or 0) > 0 and subclass_index or nil
		elseif key == 'slot' then
			local slot_index = UIDropDownMenu_GetSelectedValue(slot_dropdown)
			return (slot_index or 0) > 0 and slot_index or nil
		elseif key == 'quality' then
			local quality_code = UIDropDownMenu_GetSelectedValue(quality_dropdown)
			return (quality_code or -1) >= 0 and quality_code or nil
		end
	end,
	__newindex = function(_, key, value)
		if key == 'name' then
			name_input:SetText(value)
		elseif key == 'exact' then
			exact_checkbox:SetChecked(value)
		elseif key == 'min_level' then
			min_level_input:SetText(value)
		elseif key == 'max_level' then
			max_level_input:SetText(value)
		elseif key == 'usable' then
			usable_checkbox:SetChecked(value)
		elseif key == 'class' then
			UIDropDownMenu_Initialize(class_dropdown, initialize_class_dropdown)
			UIDropDownMenu_SetSelectedValue(class_dropdown, value)
		elseif key == 'subclass' then
			UIDropDownMenu_Initialize(subclass_dropdown, initialize_subclass_dropdown)
			UIDropDownMenu_SetSelectedValue(subclass_dropdown, value)
		elseif key == 'slot' then
			UIDropDownMenu_Initialize(slot_dropdown, initialize_slot_dropdown)
			UIDropDownMenu_SetSelectedValue(slot_dropdown, value)
		elseif key == 'quality' then
			UIDropDownMenu_Initialize(quality_dropdown, initialize_quality_dropdown)
			UIDropDownMenu_SetSelectedValue(quality_dropdown, value)
		end
	end,
})

function update_form()
	if blizzard_query.class and GetAuctionItemSubClasses(blizzard_query.class) then
		subclass_dropdown.button:Enable()
	else
		subclass_dropdown.button:Disable()
	end

	if blizzard_query.subclass and GetAuctionInvTypes(blizzard_query.class, blizzard_query.subclass) then
		slot_dropdown.button:Enable()
	else
		slot_dropdown.button:Disable()
	end

	if blizzard_query.exact then
		for key in temp-S('class', 'subclass', 'slot', 'quality') do
			_M[key .. '_dropdown'].button:Disable()
		end
	else
		class_dropdown.button:Enable()
		quality_dropdown.button:Enable()
	end
	for key in temp-S('min_level', 'max_level') do
		if blizzard_query.exact then
			_M[key .. '_input']:EnableMouse(false)
			_M[key .. '_input']:ClearFocus()
		else
			_M[key .. '_input']:EnableMouse(true)
		end
	end
	if blizzard_query.exact then
		usable_checkbox:Disable()
	else
		usable_checkbox:Enable()
	end

	if any(A('min_level', 'max_level', 'usable', 'class', 'subclass', 'slot', 'quality'), function(key) return blizzard_query[key] end) then
		exact_checkbox:Disable()
	else
		exact_checkbox:Enable()
	end
end

function get_filter_builder_query()
	local filter_string

	local function add(part)
		if part then
			filter_string = filter_string and filter_string .. '/' .. part or part
		end
	end

	local name = blizzard_query.name
	if not index(filter_util.parse_filter_string(name), 'blizzard', 'name') then
		name = filter_util.quote(name)
	end
	add((name ~= '' or blizzard_query.exact) and name)

	add(blizzard_query.exact and 'exact')
	add(blizzard_query.min_level or blizzard_query.max_level and 1)
	add(blizzard_query.max_level)
	add(blizzard_query.usable and 'usable')

	for class_index in present(blizzard_query.class) do
		local classes = temp-A(GetAuctionItemClasses())
		add(strlower(classes[class_index]))
		for subclass_index in present(blizzard_query.subclass) do
			local subclasses = temp-A(GetAuctionItemSubClasses(class_index))
			add(strlower(subclasses[subclass_index]))
			for slot_index in present(blizzard_query.slot) do
				local slots = temp-A(GetAuctionInvTypes(class_index, subclass_index))
				add(strlower(_G[slots[slot_index]]))
			end
		end
	end

	local quality = blizzard_query.quality
	if quality and quality >= 0 then
		add(strlower(_G['ITEM_QUALITY' .. quality .. '_DESC']))
	end

	local post_filter_string = filter_util.filter_string(post_filter)
	add(post_filter_string ~= '' and post_filter_string)

	return filter_string or ''
end

function set_form(filter)
	clear_form()
	for _, component in filter.components do
		if component[1] == 'blizzard' then
			blizzard_query[component[2]] = component[4]
		else
			add_component(component)
		end
	end
	update_filter_display()
end

function clear_form()
	blizzard_query.name = ''
	name_input:ClearFocus()
	blizzard_query.exact = false
	blizzard_query.min_level = ''
	min_level_input:ClearFocus()
	blizzard_query.max_level = ''
	max_level_input:ClearFocus()
	blizzard_query.usable = false
	UIDropDownMenu_ClearAll(class_dropdown)
	UIDropDownMenu_ClearAll(subclass_dropdown)
	UIDropDownMenu_ClearAll(slot_dropdown)
	UIDropDownMenu_ClearAll(quality_dropdown)
	filter_parameter_input:ClearFocus()
	wipe(post_filter)
	init[filter_builder_state] = temp-T('selected', 0)
	update_filter_display()
end

function import_filter_string()
	local filter, error = filter_util.parse_filter_string(select(3, strfind(search_box:GetText(), '^([^;]*)')))
	if filter or print(error) then
		set_form(filter)
	end
end

function export_filter_string()
	search_box:SetText(get_filter_builder_query())
	filter_parameter_input:ClearFocus()
end

function formatted_post_filter(components)
	local no_line_break
	local stack = tt
	local str = ''

	for i, component in components do
		if no_line_break then
			str = str .. ' '
		elseif i > 1 then
			str = str .. '</p><p>'
			for _ = 1, getn(stack) do
				str = str .. color.content.background('----')
			end
		end
		no_line_break = component[1] == 'operator' and component[2] == 'not'

		local filter_color = (filter_builder_state.selected == i and color.aux or color.orange)
		local component_text = filter_color(component[2])
		if component[1] == 'operator' and component[2] ~= 'not' then
			component_text = component_text .. filter_color(tonumber(component[3]) or '')
			tinsert(stack, component[3])
		elseif component[1] == 'filter' then
			for parameter in present(component[3]) do
				if component[2] == 'item' then
					parameter = info.display_name(cache.item_id(parameter)) or '[' .. parameter .. ']'
				elseif filter_util.filters[component[2]].input_type == 'money' then
					parameter = money.to_string(money.from_string(parameter), nil, true)
				end
				component_text = component_text .. filter_color(': ') .. parameter
			end
			while getn(stack) > 0 and stack[getn(stack)] do
				local top = tremove(stack)
				if tonumber(top) and top > 1 then
					tinsert(stack, top - 1)
					break
				end
			end
		end
		str = str .. data_link(i, component_text)
	end

	return '<html><body><p>' .. str .. '</p></body></html>'
end

function data_link(id, str)
	return '|H' .. id .. '|h' .. str .. '|h'
end

post_filter = t
filter_builder_state = T('selected', 0)

function data_link_click()
	local button = arg3
	local index = tonumber(arg1)
	if button == 'LeftButton' then
		filter_builder_state.selected = index
	elseif button == 'RightButton' then
		remove_component(index)
	end
	update_filter_display()
end

function remove_component(index)
	index = index or filter_builder_state.selected
	if filter_builder_state.selected >= index then
		filter_builder_state.selected = max(filter_builder_state.selected - 1, min(1, getn(post_filter)))
	end
	filter_builder_state[post_filter[index]] = nil
	tremove(post_filter, index)
end

function add_component(component)
	filter_builder_state.selected = filter_builder_state.selected + 1
	tinsert(post_filter, filter_builder_state.selected, component)
end

function add_post_filter()
	for str in present(filter_input:GetText()) do
		for filter in present(filter_util.filters[str]) do
			if filter.input_type ~= '' then
				str = str .. '/' .. filter_parameter_input:GetText()
			end
		end
		local components, error, suggestions = filter_util.parse_filter_string(str)
		if components and getn(components.blizzard) == 0 and getn(components.post) == 1 then
			add_component(components.post[1])
			update_filter_display()
			filter_parameter_input:SetText('')
			filter_input:HighlightText()
			filter_input:SetFocus()
		elseif error then
			print(error)
		end
	end
end

do
	local text = ''
	function update_filter_display()
		text = formatted_post_filter(post_filter)
		filter_display:SetWidth(filter_display_size())
		set_filter_display_offset()
		filter_display:SetText(text)
	end
	function filter_display_size()
		local font, font_size = filter_display:GetFont()
		filter_display.measure:SetFont(font, font_size)
		local lines = 0
		local width = 0
		for line in string.gfind(text, '<p>(.-)</p>') do
			lines = lines + 1
			filter_display.measure:SetText(line)
			width = max(width, filter_display.measure:GetStringWidth())
		end
		return width, lines * (font_size + .5)
	end
end

function set_filter_display_offset(x_offset, y_offset)
	local scroll_frame = filter_display:GetParent()
	x_offset, y_offset = x_offset or scroll_frame:GetHorizontalScroll(), y_offset or scroll_frame:GetVerticalScroll()
	local width, height = filter_display_size()
	local x_lower_bound = min(0, scroll_frame:GetWidth() - width - 10)
	local x_upper_bound = 0
	local y_lower_bound = 0
	local y_upper_bound = max(0, height - scroll_frame:GetHeight())
	scroll_frame:SetHorizontalScroll(bounded(x_lower_bound, x_upper_bound, x_offset))
	scroll_frame:SetVerticalScroll(bounded(y_lower_bound, y_upper_bound, y_offset))
end

function initialize_filter_dropdown()
	for filter in temp-S('and', 'or', 'not', 'min-unit-bid', 'min-unit-buy', 'max-unit-bid', 'max-unit-buy', 'bid-profit', 'buy-profit', 'bid-vend-profit', 'buy-vend-profit', 'bid-dis-profit', 'buy-dis-profit', 'bid-pct', 'buy-pct', 'item', 'tooltip', 'min-lvl', 'max-lvl', 'rarity', 'left', 'utilizable', 'discard') do
		UIDropDownMenu_AddButton(T(
			'text', filter,
			'value', filter,
			'func', function()
				filter_input:SetText(this.value)
				if index(filter_util.filters[this.value], 'input_type') == '' or this.value == 'not' then
					add_post_filter()
				elseif filter_util.filters[this.value] then
					filter_parameter_input:Show()
					filter_parameter_input:SetFocus()
				else
					filter_input:SetFocus()
				end
			end
		))
	end
end

function initialize_class_dropdown()
	local function on_click()
		if this.value ~= blizzard_query.class then
			UIDropDownMenu_SetSelectedValue(class_dropdown, this.value)
			UIDropDownMenu_ClearAll(subclass_dropdown)
			UIDropDownMenu_Initialize(subclass_dropdown, initialize_subclass_dropdown)
			UIDropDownMenu_ClearAll(slot_dropdown)
			UIDropDownMenu_Initialize(slot_dropdown, initialize_slot_dropdown)
			update_form()
		end
	end
	UIDropDownMenu_AddButton(T('text', ALL, 'value', 0, 'func', on_click))
	for i, class in temp-A(GetAuctionItemClasses()) do
		UIDropDownMenu_AddButton(T('text', class, 'value', i, 'func', on_click))
	end
end

function initialize_subclass_dropdown()
	local function on_click()
		if this.value ~= blizzard_query.subclass then
			UIDropDownMenu_SetSelectedValue(subclass_dropdown, this.value)
			UIDropDownMenu_ClearAll(slot_dropdown)
			UIDropDownMenu_Initialize(slot_dropdown, initialize_slot_dropdown)
			update_form()
		end
	end
	local class_index = UIDropDownMenu_GetSelectedValue(class_dropdown)
	if class_index and GetAuctionItemSubClasses(class_index) then
		UIDropDownMenu_AddButton(T('text', ALL, 'value', 0, 'func', on_click))
		for i, subclass in temp-A(GetAuctionItemSubClasses(class_index)) do
			UIDropDownMenu_AddButton(T('text', subclass, 'value', i, 'func', on_click))
		end
	end
end

function initialize_slot_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(slot_dropdown, this.value)
		update_form()
	end
	local class_index = UIDropDownMenu_GetSelectedValue(class_dropdown)
	local subclass_index = UIDropDownMenu_GetSelectedValue(subclass_dropdown)
	if subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
		UIDropDownMenu_AddButton(T('text', ALL, 'value', '', 'func', on_click))
		for i, slot in temp-A(GetAuctionInvTypes(class_index, subclass_index)) do
			UIDropDownMenu_AddButton(T('text', _G[slot], 'value', i, 'func', on_click))
		end
	end
end

function initialize_quality_dropdown()
	local function on_click()
		UIDropDownMenu_SetSelectedValue(quality_dropdown, this.value)
		update_form()
	end
	UIDropDownMenu_AddButton(T('text', ALL, 'value', -1, 'func', on_click))
	for i = 0, 4 do
		UIDropDownMenu_AddButton(T('text', _G['ITEM_QUALITY' .. i .. '_DESC'], 'value', i, 'func', on_click))
	end
end
