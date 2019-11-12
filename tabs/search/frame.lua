select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local completion = require 'aux.util.completion'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local auction_listing = require 'aux.gui.auction_listing'

local FILTER_SPACING = 27

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints()
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.filter = gui.panel(frame)
frame.filter:SetAllPoints(aux.frame.content)

frame.results = gui.panel(frame)
frame.results:SetAllPoints(aux.frame.content)

frame.saved = CreateFrame('Frame', nil, frame)
frame.saved:SetAllPoints(aux.frame.content)
frame.saved:SetScript('OnUpdate', function()
    if not IsAltKeyDown() then
        dragged_search = nil
    end
end)

frame.saved.favorite = gui.panel(frame.saved)
frame.saved.favorite:SetWidth(393)
frame.saved.favorite:SetPoint('TOPLEFT', 0, 0)
frame.saved.favorite:SetPoint('BOTTOMLEFT', 0, 0)

frame.saved.recent = gui.panel(frame.saved)
frame.saved.recent:SetWidth(364.5)
frame.saved.recent:SetPoint('TOPRIGHT', 0, 0)
frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)

do
    local btn = gui.button(frame, 25)
    btn:SetPoint('TOPLEFT', 5, -8)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('<')
    btn:SetScript('OnClick', previous_search)
    previous_button = btn
end
do
    local btn = gui.button(frame, 25)
    btn:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('>')
    btn:SetScript('OnClick', next_search)
    next_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetHeight(25)
	btn:SetWidth(60)
	btn:SetScript('OnClick', function(self)
		update_mode(mode == NORMAL_MODE and FRESH_MODE or NORMAL_MODE)
	end)
	mode_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Search')
    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    btn:SetScript('OnClick', function(_, button)
        if button == 'RightButton' then
            set_filter(current_search().filter_string)
        end
        execute()
    end)
    start_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Pause')
    btn:SetScript('OnClick', function()
        scan.abort()
    end)
    stop_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
    btn:SetBackdropColor(aux.color.state.enabled())
    btn:SetText('Resume')
    btn:SetScript('OnClick', function()
        execute(nil, true)
    end)
    resume_button = btn
end
do
	local editbox = gui.editbox(frame)
    editbox:SetPoint('LEFT', mode_button, 'RIGHT', 4, 0)
	editbox.formatter = function(str)
		local queries = filter_util.queries(str)
		return queries and aux.join(aux.map(aux.copy(queries), function(query) return query.prettified end), ';') or aux.color.red(str)
	end
	editbox.complete = completion.complete_filter
    editbox.escape = function(self) self:SetText(current_search().filter_string or '') end
	editbox:SetHeight(25)
	editbox.char = function(self)
        self:complete()
	end
	editbox:SetScript('OnTabPressed', function(self)
        self:HighlightText(0, 0) -- TODO more edit features, shift backspace or something
	end)
	editbox.enter = execute
    local function search_cursor_item()
        local type, item_id = GetCursorInfo()
        if type == 'item' then
            set_filter(strlower(info.item(item_id).name) .. '/exact')
            execute(nil, false)
            ClearCursor()
        end
    end
    editbox:HookScript('OnReceiveDrag', search_cursor_item)
    editbox:HookScript('OnMouseDown', search_cursor_item)
	search_box = editbox
end
do
    gui.horizontal_line(frame, -40)
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('BOTTOMLEFT', aux.frame.content, 'TOPLEFT', 10, 8)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Search Results')
    btn:SetScript('OnClick', function() set_subtab(RESULTS) end)
    search_results_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('TOPLEFT', search_results_button, 'TOPRIGHT', 5, 0)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Saved Searches')
    btn:SetScript('OnClick', function() set_subtab(SAVED) end)
    saved_searches_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('TOPLEFT', saved_searches_button, 'TOPRIGHT', 5, 0)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Filter Builder')
    btn:SetScript('OnClick', function() set_subtab(FILTER) end)
    new_filter_button = btn
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Bid')
    btn:Disable()
    bid_button = btn
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Buyout')
    btn:Disable()
    buyout_button = btn
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Clear')
    btn:SetScript('OnClick', function()
        while tremove(current_search().records) do end
        current_search().table:SetDatabase()
    end)
end
do
    local btn = gui.button(frame.saved)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Favorite')
    btn:SetScript('OnClick', function()
        add_favorite(search_box:GetText())
    end)
end
do
    local btn1 = gui.button(frame.filter)
    btn1:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn1:SetText('Search')
    btn1:SetScript('OnClick', function()
	    export_filter_string()
        execute()
    end)

    local btn2 = gui.button(frame.filter)
    btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
    btn2:SetText('Export')
    btn2:SetScript('OnClick', export_filter_string)

    local btn3 = gui.button(frame.filter)
    btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
    btn3:SetText('Import')
    btn3:SetScript('OnClick', import_filter_string)
end
do
    local editbox = gui.editbox(frame.filter)
    editbox.complete_item = completion.complete(function() return aux.account_data.auctionable_items end)
    editbox:SetPoint('TOPLEFT', 14, -FILTER_SPACING)
    editbox:SetWidth(260)
    editbox.char = function(self)
        if blizzard_query.exact then
            self:complete_item()
        end
    end
    editbox:SetScript('OnTabPressed', function()
        if not IsShiftKeyDown() then
            if blizzard_query.exact then
                filter_dropdown:SetFocus()
            else
                min_level_input:SetFocus()
            end
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Name')
    name_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('TOPLEFT', name_input, 'TOPRIGHT', 16, 0)
    checkbox:SetScript('OnClick', exact_update)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('Exact')
    exact_checkbox = checkbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', name_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    editbox:SetWidth(125)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            name_input:SetFocus()
        else
            max_level_input:SetFocus()
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    editbox.change = function(self)
	    local valid_level = valid_level(self:GetText())
	    if tostring(valid_level) ~= self:GetText() then
            self:SetText(valid_level or '')
	    end
    end
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Level Range')
    min_level_input = editbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', min_level_input, 'TOPRIGHT', 10, 0)
    editbox:SetWidth(125)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            min_level_input:SetFocus()
        else
            class_dropdown:SetFocus()
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    editbox.change = function(self)
	    local valid_level = valid_level(self:GetText())
	    if tostring(valid_level) ~= self:GetText() then
            self:SetText(valid_level or '')
	    end
    end
    local label = gui.label(editbox, gui.font_size.medium)
    label:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
    label:SetText('-')
    max_level_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('TOPLEFT', max_level_input, 'TOPRIGHT', 16, 0)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('Usable')
    usable_checkbox = checkbox
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() class_selection_change() end
    dropdown:SetPoint('TOPLEFT', min_level_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(300)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            max_level_input:SetFocus()
        else
            subclass_dropdown:SetFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Item Class')
    class_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() subclass_selection_change() end
    dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(300)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            class_dropdown:SetFocus()
        else
            slot_dropdown:SetFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Item Subclass')
    subclass_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(300)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            subclass_dropdown:SetFocus()
        else
            quality_dropdown:SetFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Item Slot')
    slot_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(300)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            slot_dropdown:SetFocus()
        else
            filter_dropdown:SetFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Min Quality')
    quality_dropdown = dropdown
end
gui.vertical_line(frame.filter, 332)
do
	local input = gui.dropdown(frame.filter)
    input:SetPoint('TOPRIGHT', -205, -10)
	input:SetWidth(150)
    input:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            if blizzard_query.exact then
                name_input:SetFocus()
            else
                quality_dropdown:SetFocus()
            end
        else
            filter_parameter_input:SetFocus()
        end
    end)
	input.change = function(self)
		local text = self:GetText()
		if filter_util.filters[text] and filter_util.filters[text].input_type ~= '' then
			local _, _, suggestions = filter_util.parse_filter_string(text .. '/')
			filter_parameter_input:SetNumeric(filter_util.filters[text].input_type == 'number')
			filter_parameter_input.complete = completion.complete(function() return suggestions or empty end)
			filter_parameter_input:Show()
		else
			filter_parameter_input:Hide()
		end
	end
	input.enter = function()
		if filter_parameter_input:IsVisible() then
			filter_parameter_input:SetFocus()
		else
			add_form_component()
		end
    end
    input:SetOptions({'and', 'or', 'not', unpack(aux.keys(filter_util.filters))})
    local label = gui.label(input, gui.font_size.medium)
    label:SetPoint('RIGHT', input, 'LEFT', -8, 0)
    label:SetText('Operator')
	filter_dropdown = input
end
do
    local input = gui.editbox(frame.filter)
    input:SetPoint('LEFT', filter_dropdown, 'RIGHT', 10, 0)
    input:SetWidth(150)
    input:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            filter_dropdown:SetFocus()
        end
    end)
    input.char = function(self) self:complete() end
    input.enter = add_form_component
    input:Hide()
    filter_parameter_input = input
end
do
    local button = gui.button(frame.filter)
    button:SetPoint('LEFT', filter_parameter_input, 'RIGHT', 10, 0)
    button:SetWidth(button:GetHeight())
    button:SetText('+')
    button:SetScript('OnClick', add_form_component)
end
do
    local scroll_frame = CreateFrame('ScrollFrame', nil, frame.filter)
    scroll_frame:SetWidth(395)
    scroll_frame:SetHeight(270)
    scroll_frame:SetPoint('TOPLEFT', 348.5, -47)
    scroll_frame:EnableMouse(true)
    scroll_frame:EnableMouseWheel(true)
    scroll_frame:SetScript('OnMouseWheel', function(self, arg1)
	    local child = self:GetScrollChild()
	    child:SetFont('p', gui.font, aux.bounded(gui.font_size.small, gui.font_size.large, select(2, child:GetFont()) + arg1 * 2))
	    update_filter_display()
    end)
    scroll_frame:RegisterForDrag('LeftButton')
    scroll_frame:SetScript('OnDragStart', function(self)
        self.x, self.y = GetCursorPosition()
        self.x_offset, self.y_offset = self:GetHorizontalScroll(), self:GetVerticalScroll()
        self.x_extra, self.y_extra = 0, 0
        self:SetScript('OnUpdate', function()
		    local x, y = GetCursorPosition()
		    local new_x_offset = self.x_offset + x - self.x
		    local new_y_offset = self.y_offset + y - self.y

		    set_filter_display_offset(new_x_offset - self.x_extra, new_y_offset - self.y_extra)

            self.x_extra = max(self.x_extra, new_x_offset)
            self.y_extra = min(self.y_extra, new_y_offset)
	    end)
    end)
    scroll_frame:SetScript('OnDragStop', function(self)
        self:SetScript('OnUpdate', nil)
    end)
    gui.set_content_style(scroll_frame, -2, -2, -2, -2)
    local scroll_child = CreateFrame('SimpleHTML', nil, scroll_frame)
    scroll_frame:SetScrollChild(scroll_child)
    scroll_child:SetFont('p', gui.font, gui.font_size.large)
    scroll_child:SetTextColor('p', aux.color.label.enabled())
    scroll_child:SetWidth(1)
    scroll_child:SetHeight(1)
    scroll_child:SetScript('OnHyperlinkClick', data_link_click)
    scroll_child.measure = scroll_child:CreateFontString()
    filter_display = scroll_child
end

tables = {}
for _ = 1, 5 do
    local table = auction_listing.new(frame.results, 16, auction_listing.search_columns)
    table:SetHandler('OnClick', function(row, button)
	    if IsAltKeyDown() and aux.account_data.action_shortcuts then
		    if current_search().table:GetSelection().record == row.record then
			    if button == 'LeftButton' then
	                buyout_button:Click()
	            elseif button == 'RightButton' then
	                bid_button:Click()
			    end
		    end
	    elseif button == 'RightButton' then
		    set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
		    execute(nil, false)
	    end
    end)
    table:SetHandler('OnSelectionChanged', function(rt, datum)
	    bid_button:Disable()
        buyout_button:Disable()
        if not datum then return end
        find_auction(datum.record)
    end)
    table:Hide()
    tinsert(tables, table)
end

favorite_searches_listing = listing.new(frame.saved.favorite)
favorite_searches_listing:SetColInfo{{name='Alert', width=.07, align='CENTER'}, {name='Favorite Searches', width=.93}}

recent_searches_listing = listing.new(frame.saved.recent)
recent_searches_listing:SetColInfo{{name='Recent Searches', width=1}}

for listing in aux.iter(favorite_searches_listing, recent_searches_listing) do
	for k, v in pairs(handlers) do
		listing:SetHandler(k, v)
	end
end

