select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'

local post_filter = {}
local post_filter_index = 0

function aux.event.AUCTION_HOUSE_LOADED()
    initialize_class_dropdown()
    initialize_quality_dropdown()
end

function valid_level(str)
	local level = tonumber(str)
	return level and aux.bounded(1, 60, level)
end

blizzard_query = setmetatable({}, {
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
			local class_index = (class_dropdown:GetIndex() or 0) - 1
			return class_index ~= 0 and class_index or nil
		elseif key == 'subclass' then
			local subclass_index = (subclass_dropdown:GetIndex() or 0) - 1
			return subclass_index ~= 0 and subclass_index or nil
		elseif key == 'slot' then
			local slot_index = (slot_dropdown:GetIndex() or 0) - 1
			return (slot_index or 0) > 0 and slot_index or nil
		elseif key == 'quality' then
			local quality_code = quality_dropdown:GetIndex() - 2
			return (quality_code or -1) >= 0 and quality_code or nil
		end
	end,
	__newindex = function(_, key, value)
		if key == 'name' then
			name_input:SetText(value)
		elseif key == 'exact' then
			exact_checkbox:SetChecked(value)
            exact_update()
		elseif key == 'min_level' then
			min_level_input:SetText(value)
		elseif key == 'max_level' then
			max_level_input:SetText(value)
		elseif key == 'usable' then
			usable_checkbox:SetChecked(value)
		elseif key == 'class' then
            class_dropdown:SetIndex(value + 1)
		elseif key == 'subclass' then
			subclass_dropdown:SetIndex(value + 1)
		elseif key == 'slot' then
			slot_dropdown:SetIndex(value + 1)
		elseif key == 'quality' then
			quality_dropdown:SetIndex(value + 2)
		end
	end,
})

function get_filter_builder_query()
	local filter_string

	local function add(part)
		if part then
			filter_string = filter_string and filter_string .. '/' .. part or part
		end
	end

	local name = blizzard_query.name
	if not aux.index(filter_util.parse_filter_string(name), 'blizzard', 'name') then
		name = filter_util.quote(name)
	end
	add((name ~= '' or blizzard_query.exact) and name)

	add(blizzard_query.exact and 'exact')

    if not blizzard_query.exact then
        add(blizzard_query.min_level or blizzard_query.max_level and 1)
        add(blizzard_query.max_level)
        add(blizzard_query.usable and 'usable')

        if (blizzard_query.class or 0) > 0 then
            local category = AuctionCategories[blizzard_query.class]
            add(strlower(category.name))
            if (blizzard_query.subclass or 0) > 0 then
                local subcategory = category.subCategories[blizzard_query.subclass]
                add(strlower(subcategory.name))
                if (blizzard_query.slot or 0) > 0 then -- TODO retail is it still possible to query for slot without subclass?
                    local subsubcategory = subcategory.subCategories[blizzard_query.slot]
                    add(strlower(subsubcategory.name))
                end
            end
        end

        local quality = blizzard_query.quality
        if quality and quality >= 0 then
            add(strlower(_G['ITEM_QUALITY' .. quality .. '_DESC']))
        end
    end

	local post_filter_string = filter_util.filter_string(post_filter)
	add(post_filter_string ~= '' and post_filter_string)

	return filter_string or ''
end

function set_form(filter)
	clear_form()
	for _, component in ipairs(filter.components) do
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
    initialize_class_dropdown()
    initialize_subclass_dropdown()
    initialize_slot_dropdown()
    initialize_quality_dropdown()
	filter_parameter_input:ClearFocus()
    aux.wipe(post_filter)
	post_filter_index = 0
	update_filter_display()
end

function import_filter_string()
	local filter, error = filter_util.parse_filter_string(select(3, strfind(search_box:GetText(), '^([^;]*)')))
	if filter or aux.print(error) then
		set_form(filter)
	end
end

function export_filter_string()
	set_filter(get_filter_builder_query())
end

function formatted_post_filter(components)
	local no_line_break
	local stack = {}
	local str = ''

	for i, component in ipairs(components) do
		local component = components[i]
		if no_line_break then
			str = str .. ' '
		end
		str = str .. '</p><p>'
		for _ = 1, #stack + 1 do
			str = str .. aux.color.content.background'----'
		end
		no_line_break = component[1] == 'operator' and component[2] == 'not'

		local filter_color = (post_filter_index == i and aux.color.gold or aux.color.orange)
		local component_text = filter_color(component[2])
		if component[1] == 'operator' and component[2] ~= 'not' then
			component_text = component_text .. filter_color(tonumber(component[3]) or '')
			tinsert(stack, component[3] or '*')
		elseif component[1] == 'filter' then
			local parameter = component[3]
			if parameter then
				if component[2] == 'item' then
					parameter = info.display_name(info.item_id(parameter)) or '[' .. parameter .. ']'
				elseif filter_util.filters[component[2]].input_type == 'money' then
					parameter = money.to_string(money.from_string(parameter), nil, true)
				end
				component_text = component_text .. filter_color(': ') .. parameter
			end
			while #stack > 0 and stack[#stack] and stack[#stack] ~= '*' do
				local top = tremove(stack)
				if tonumber(top) and top > 1 then
					tinsert(stack, top - 1)
					break
				end
			end
		end
		str = str .. data_link(i, component_text)
	end

	return '<html><body><p>' .. data_link(0, 'Post Filter:') .. '</p><p>' .. str .. '</p></body></html>'
end

function data_link(id, str)
	return format('<a href="%s">%s</a>', id, str)
end

function data_link_click(_, link, _, button)
	local index = tonumber(link)
	if button == 'LeftButton' then
		post_filter_index = index
	elseif button == 'RightButton' and index > 0 then
		remove_component(index)
	end
	update_filter_display()
end

function remove_component(index)
	tremove(post_filter, index)
	if post_filter_index >= index then
		post_filter_index = max(post_filter_index - 1, min(1, #post_filter))
	end
end

function add_component(component)
	post_filter_index = post_filter_index + 1
	tinsert(post_filter, post_filter_index, component)
end

function add_form_component()
	local str = filter_dropdown:GetText()
	if str then
		local filter = filter_util.filters[str]
		if filter then
			if filter.input_type ~= '' then
				str = str .. '/' .. filter_parameter_input:GetText()
			end
		end
		local components, error = filter_util.parse_filter_string(str)
		if components and #components.blizzard == 0 and #components.post == 1 then
			add_component(components.post[1])
			update_filter_display()
			filter_parameter_input:SetText('')
			filter_dropdown:HighlightText()
			filter_dropdown:SetFocus()
		elseif error then
			aux.print(error)
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
		for line in string.gmatch(text, '<p>(.-)</p>') do
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
	scroll_frame:SetHorizontalScroll(aux.bounded(x_lower_bound, x_upper_bound, x_offset))
	scroll_frame:SetVerticalScroll(aux.bounded(y_lower_bound, y_upper_bound, y_offset))
end

function exact_update()
    for name in aux.iter('min_level_input', 'max_level_input', 'usable_checkbox', 'class_dropdown', 'subclass_dropdown', 'slot_dropdown', 'quality_dropdown') do
        if blizzard_query.exact then
            _M[name]:Hide()
        else
            _M[name]:Show()
        end
    end
end

function initialize_class_dropdown()
    local options = {ALL}
    for _, category in ipairs(AuctionCategories) do
        tinsert(options, category.name)
    end
    class_dropdown:SetOptions(options)
    class_dropdown:SetIndex(1)
end

function class_selection_change()
    initialize_subclass_dropdown()
end

function initialize_subclass_dropdown()
    local options = {}
    if (blizzard_query.class or 0) > 0 then
        for _, subcategory in ipairs(AuctionCategories[blizzard_query.class].subCategories or empty) do
            tinsert(options, subcategory.name)
        end
    end
    if #options > 0 then
        tinsert(options, 1, ALL)
    end
    subclass_dropdown:SetOptions(options)
    subclass_dropdown:SetIndex(#options > 0 and 1 or nil)
end

function subclass_selection_change()
    initialize_slot_dropdown()
end

function initialize_slot_dropdown()
    local options = {}
    if (blizzard_query.class or 0) > 0 and (blizzard_query.subclass or 0) > 0 then -- TODO retail is it still possible to query for slot without subclass?
        for _, subsubcategory in ipairs(AuctionCategories[blizzard_query.class].subCategories[blizzard_query.subclass].subCategories or empty) do
            tinsert(options, subsubcategory.name)
        end
    end
    if #options > 0 then
        tinsert(options, 1, ALL)
    end
    slot_dropdown:SetOptions(options)
    slot_dropdown:SetIndex(#options > 0 and 1 or nil)
end

function initialize_quality_dropdown()
    local options = {ALL}
    for i = 0, 4 do
        tinsert(options, _G['ITEM_QUALITY' .. i .. '_DESC'])
    end
    quality_dropdown:SetOptions(options)
    quality_dropdown:SetIndex(1)
end
