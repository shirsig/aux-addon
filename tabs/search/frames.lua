aux.module 'search_tab'

FILTER_SPACING = 28.5

function create_frames()
	frame = CreateFrame('Frame', nil, aux.frame)
	frame:SetAllPoints()
	frame:SetScript('OnUpdate', on_update)
	frame:Hide()

	frame.filter = aux.gui.panel(frame)
	frame.filter:SetAllPoints(aux.frame.content)

	frame.results = aux.gui.panel(frame)
	frame.results:SetAllPoints(aux.frame.content)

	frame.saved = CreateFrame('Frame', nil, frame)
	frame.saved:SetAllPoints(aux.frame.content)

	frame.saved.favorite = aux.gui.panel(frame.saved)
	frame.saved.favorite:SetWidth(378.5)
	frame.saved.favorite:SetPoint('TOPLEFT', 0, 0)
	frame.saved.favorite:SetPoint('BOTTOMLEFT', 0, 0)

	frame.saved.recent = aux.gui.panel(frame.saved)
	frame.saved.recent:SetWidth(378.5)
	frame.saved.recent:SetPoint('TOPRIGHT', 0, 0)
	frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)
	do
	    local btn = aux.gui.button(frame)
	    btn:SetPoint('TOPLEFT', 0, 0)
	    btn:SetWidth(42)
	    btn:SetHeight(42)
	    btn:SetScript('OnClick', function()
	        if this.open then
	            settings:Hide()
	            controls:Show()
	        else
	            settings:Show()
	            controls:Hide()
	        end
	        this.open = not this.open
	    end)

	    for _, offset in {14, 10, 6} do
	        local fake_icon_part = btn:CreateFontString()
	        fake_icon_part:SetFont([[Fonts\FRIZQT__.TTF]], 23)
	        fake_icon_part:SetPoint('CENTER', 0, offset)
	        fake_icon_part:SetText('_')
	    end

	    settings_button = btn
	end
	do
	    local panel = CreateFrame('Frame', nil, frame)
	    panel:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]]}
	    panel:SetBackdropColor(unpack(aux.gui.color.content.background))
	    panel:SetPoint('LEFT', settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 0)
	    panel:SetHeight(42)
	    panel:Hide()
	    settings = panel
	end
	do
	    local panel = CreateFrame('Frame', nil, frame)
	    panel:SetPoint('LEFT', settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 1)
	    panel:SetHeight(40)
	    controls = panel
	end
	do
	    local editbox = aux.gui.editbox(settings)
	    editbox:SetPoint('LEFT', 75, 0)
	    editbox:SetWidth(50)
	    editbox:SetNumeric(true)
	    editbox:SetMaxLetters(nil)
	    editbox:SetScript('OnTabPressed', function()
	        last_page_input:SetFocus()
	    end)
	    editbox:SetScript('OnEnterPressed', function()
	        this:ClearFocus()
	        execute()
	    end)
	    editbox:SetScript('OnTextChanged', function()
		    local page = tonumber(this:GetText())
		    local valid_input = page and tostring(max(1, page)) or ''
		    if this:GetText() ~= valid_input then
			    this:SetText(valid_input)
		    end
	        if blizzard_page_index(this:GetText()) and not real_time_button:GetChecked() then
	            this:SetBackdropColor(unpack(aux.gui.color.state.enabled))
	        else
	            this:SetBackdropColor(unpack(aux.gui.color.state.disabled))
	        end
	    end)
	    local label = aux.gui.label(editbox, 16)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -6, 0)
	    label:SetText('Pages')
	    label:SetTextColor(unpack(aux.gui.color.text.enabled))
	    first_page_input = editbox
	end
	do
	    local editbox = aux.gui.editbox(settings)
	    editbox:SetPoint('LEFT', first_page_input, 'RIGHT', 10, 0)
	    editbox:SetWidth(50)
	    editbox:SetNumeric(true)
	    editbox:SetMaxLetters(nil)
	    editbox:SetScript('OnTabPressed', function()
	        first_page_input:SetFocus()
	    end)
	    editbox:SetScript('OnEnterPressed', function()
	        this:ClearFocus()
	        execute()
	    end)
	    editbox:SetScript('OnTextChanged', function()
		    local page = tonumber(this:GetText())
		    local valid_input = page and tostring(max(1, page)) or ''
		    if this:GetText() ~= valid_input then
			    this:SetText(valid_input)
		    end
	        if blizzard_page_index(this:GetText()) and not real_time_button:GetChecked() then
	            this:SetBackdropColor(unpack(aux.gui.color.state.enabled))
	        else
	            this:SetBackdropColor(unpack(aux.gui.color.state.disabled))
	        end
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -3.5, 0)
	    label:SetText('-')
	    label:SetTextColor(unpack(aux.gui.color.text.enabled))
	    last_page_input = editbox
	end
	do
	    local btn = aux.gui.checkbutton(settings)
	    btn:SetPoint('LEFT', 230, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Real Time Mode')
	    btn:SetScript('OnClick', function()
	        this:SetChecked(not this:GetChecked())
	        this = first_page_input
	        first_page_input:GetScript('OnTextChanged')()
	        this = last_page_input
	        last_page_input:GetScript('OnTextChanged')()
	    end)
	    public.real_time_button = btn
	end
	do
	    local btn = aux.gui.checkbutton(settings)
	    btn:SetPoint('LEFT', real_time_button, 'RIGHT', 15, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Auto Buyout Mode')
	    btn:SetScript('OnClick', function()
	        if this:GetChecked() then
	            this:SetChecked(false)
	        else
	            StaticPopup_Show('AUX_SEARCH_AUTO_BUY')
	        end
	    end)
	    auto_buy_button = btn
	end
	do
	    local btn = aux.gui.checkbutton(settings)
	    btn:SetPoint('LEFT', auto_buy_button, 'RIGHT', 15, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Auto Buyout Filter')
	    btn:SetScript('OnClick', function()
	        if this:GetChecked() then
	            this:SetChecked(false)
	            g.aux_auto_buy_filter = nil
	            this.prettified = nil
	            auto_buy_validator = nil
	        else
	            StaticPopup_Show('AUX_SEARCH_AUTO_BUY_FILTER')
	        end
	    end)
	    btn:SetScript('OnEnter', function()
	        if this.prettified then
	            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	            GameTooltip:AddLine(gsub(this.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
	            GameTooltip:Show()
	        end
	    end)
	    btn:SetScript('OnLeave', function()
	        GameTooltip:Hide()
	    end)
	    auto_buy_filter_button = btn
	end
	do
	    local btn = aux.gui.button(controls, 25)
	    btn:SetPoint('LEFT', 5, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('<')
	    btn:SetScript('OnClick', previous_search)
	    previous_button = btn
	end
	do
	    local btn = aux.gui.button(controls, 25)
	    btn:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('>')
	    btn:SetScript('OnClick', next_search)
	    next_button = btn
	end
	do
	    local btn = aux.gui.button(controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Start')
	    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	    btn:SetScript('OnClick', function()
	        if arg1 == 'RightButton' then
	            set_filter(current_search().filter_string)
	        end
	        execute()
	    end)
	    start_button = btn
	end
	do
	    local btn = aux.gui.button(controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Stop')
	    btn:SetScript('OnClick', function()
	        aux.scan.abort(search_scan_id)
	    end)
	    stop_button = btn
	end
	do
	    local btn = aux.gui.button(controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText(aux.gui.color.green 'Resume')
	    btn:SetScript('OnClick', function()
	        execute(true)
	    end)
	    resume_button = btn
	end
	do
	    local editbox = aux.gui.editbox(controls)
	    editbox:SetMaxLetters(nil)
	    editbox:EnableMouse(1)
	    editbox.complete = aux.completion.complete_filter
	    editbox:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	    editbox:SetHeight(25)
	    editbox:SetScript('OnChar', function()
	        this:complete()
	    end)
	    editbox:SetScript('OnTabPressed', function()
	        this:HighlightText(0, 0)
	    end)
	    editbox:SetScript('OnEnterPressed', execute)
	    search_box = editbox
	end
	do
	    aux.gui.horizontal_line(frame, -40)
	end
	do
	    local btn = aux.gui.button(frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('BOTTOMLEFT', aux.frame.content, 'TOPLEFT', 10, 8)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Search Results')
	    btn:SetScript('OnClick', function() update_tab(RESULTS) end)
	    search_results_button = btn
	end
	do
	    local btn = aux.gui.button(frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('TOPLEFT', search_results_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Saved Searches')
	    btn:SetScript('OnClick', function() update_tab(SAVED) end)
	    saved_searches_button = btn
	end
	do
	    local btn = aux.gui.button(frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('TOPLEFT', saved_searches_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Filter Builder')
	    btn:SetScript('OnClick', function() update_tab(FILTER) end)
	    new_filter_button = btn
	end
	do
	    local frame = CreateFrame('Frame', nil, frame)
	    frame:SetWidth(265)
	    frame:SetHeight(25)
	    frame:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
	    status_bar_frame = frame
	end
	do
	    local btn = aux.gui.button(frame.results, 16)
	    btn:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Bid')
	    btn:Disable()
	    bid_button = btn
	end
	do
	    local btn = aux.gui.button(frame.results, 16)
	    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Buyout')
	    btn:Disable()
	    buyout_button = btn
	end
	do
	    local btn = aux.gui.button(frame.results, 16)
	    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Clear')
	    btn:SetScript('OnClick', function()
	        while tremove(current_search().records) do end
	        current_search().table:SetDatabase()
	    end)
	end
	do
	    local btn = aux.gui.button(frame.saved, 16)
	    btn:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Favorite')
	    btn:SetScript('OnClick', function()
	        local filters = aux.filter.queries(search_box:GetText())
	        if filters then
	            tinsert(g.aux_favorite_searches, 1, {
	                filter_string = search_box:GetText(),
	                prettified = table.concat(aux.util.map(filters, function(filter) return filter.prettified end), ';'),
	            })
	        end
	        update_search_listings()
	    end)
	end
	do
	    local btn1 = aux.gui.button(frame.filter, 16)
	    btn1:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn1:SetWidth(80)
	    btn1:SetHeight(24)
	    btn1:SetText('Search')
	    btn1:SetScript('OnClick', function()
	        export_query_string()
	        execute()
	    end)

	    local btn2 = aux.gui.button(frame.filter, 16)
	    btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
	    btn2:SetWidth(80)
	    btn2:SetHeight(24)
	    btn2:SetText('Export')
	    btn2:SetScript('OnClick', export_query_string)

	    local btn3 = aux.gui.button(frame.filter, 16)
	    btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
	    btn3:SetWidth(80)
	    btn3:SetHeight(24)
	    btn3:SetText('Import')
	    btn3:SetScript('OnClick', import_query_string)
	end
	do
	    local editbox = aux.gui.editbox(frame.filter)
	    editbox.complete_item = aux.completion.complete(function() return g.aux_auctionable_items end)
	    editbox:SetPoint('TOPLEFT', 14, -FILTER_SPACING)
	    editbox:SetWidth(260)
	    editbox:SetScript('OnChar', function()
	        if blizzard_query.exact then
	            this:complete_item()
	        end
	    end)
	    editbox:SetScript('OnTabPressed', function()
		    if blizzard_query.exact then
			    return
		    end
	        if IsShiftKeyDown() then
	            max_level_input:SetFocus()
	        else
	            min_level_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnTextChanged',  update_form)
	    editbox:SetScript('OnEnterPressed', aux.C(editbox.ClearFocus, editbox))
	    local label = aux.gui.label(editbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Name')
	    name_input = editbox
	end
	do
	    local checkbox = aux.gui.checkbox(frame.filter)
	    checkbox:SetPoint('TOPLEFT', name_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', update_form)
	    local label = aux.gui.label(checkbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Exact')
	    exact_checkbox = checkbox
	end
	do
	    local editbox = aux.gui.editbox(frame.filter)
	    editbox:SetPoint('TOPLEFT', name_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            name_input:SetFocus()
	        else
	            max_level_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnEnterPressed', aux.C(editbox.ClearFocus, editbox))
	    editbox:SetScript('OnTextChanged', function()
		    local valid_level = valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    update_form()
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Level Range')
	    min_level_input = editbox
	end
	do
	    local editbox = aux.gui.editbox(frame.filter)
	    editbox:SetPoint('TOPLEFT', min_level_input, 'TOPRIGHT', 10, 0)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            min_level_input:SetFocus()
	        else
	            name_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnEnterPressed', aux.C(editbox.ClearFocus, editbox))
	    editbox:SetScript('OnTextChanged', function()
		    local valid_level = valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    update_form()
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
	    label:SetText('-')
	    max_level_input = editbox
	end
	do
	    local checkbox = aux.gui.checkbox(frame.filter)
	    checkbox:SetPoint('TOPLEFT', max_level_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', update_form)
	    local label = aux.gui.label(checkbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Usable')
	    usable_checkbox = checkbox
	end
	do
	    local dropdown = aux.gui.dropdown(frame.filter)
	    class_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', min_level_input, 'BOTTOMLEFT', 0, 5 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Class')
	    UIDropDownMenu_Initialize(dropdown, initialize_class_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, initialize_class_dropdown)
	    end)
	end
	do
	    local dropdown = aux.gui.dropdown(frame.filter)
	    subclass_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Subclass')
	    UIDropDownMenu_Initialize(dropdown, initialize_subclass_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, initialize_subclass_dropdown)
	    end)
	end
	do
	    local dropdown = aux.gui.dropdown(frame.filter)
	    slot_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Slot')
	    UIDropDownMenu_Initialize(dropdown, initialize_slot_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, initialize_slot_dropdown)
	    end)
	end
	do
	    local dropdown = aux.gui.dropdown(frame.filter)
	    quality_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Min Quality')
	    UIDropDownMenu_Initialize(dropdown, initialize_quality_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, initialize_quality_dropdown)
	    end)
	end
	aux.gui.vertical_line(frame.filter, 332)
	do
	    local dropdown = aux.gui.dropdown(frame.filter)
	    dropdown:SetPoint('TOPRIGHT', -174.5, -10)
	    dropdown:SetWidth(150)
	    UIDropDownMenu_Initialize(dropdown, initialize_filter_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, initialize_filter_dropdown)
	    end)
	    getglobal(dropdown:GetName()..'Text'):Hide()
	    local label = aux.gui.label(dropdown, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', dropdown, 'LEFT', -15, 0)
	    label:SetText('Post Filter')
	    filter_dropdown = dropdown
	end
	do
		local input = aux.gui.editbox(frame.filter)
		input:SetPoint('CENTER', filter_dropdown, 'CENTER', 0, 0)
		input:SetWidth(150)
		input:SetScript('OnTabPressed', function()
			filter_parameter_input:SetFocus()
		end)
		input.complete = aux.completion.complete(function() return {'and', 'or', 'not', unpack(aux.util.keys(aux.filter.filters))} end)
		input:SetScript('OnChar', function()
			this:complete()
		end)
		input:SetScript('OnTextChanged', function()
			local filter = this:GetText()
			if aux.filter.filters[filter] and aux.filter.filters[filter].input_type ~= '' then
				local _, _, suggestions = aux.filter.parse_query_string(filter..'/')
				filter_parameter_input:SetNumeric(aux.filter.filters[filter].input_type == 'number')
				filter_parameter_input.complete = aux.completion.complete(function() return suggestions or {} end)
				filter_parameter_input:Show()
			else
				filter_parameter_input:Hide()
			end
		end)
		input:SetScript('OnEnterPressed', function()
			if filter_parameter_input:IsVisible() then
				filter_parameter_input:SetFocus()
			else
				add_post_filter()
			end
		end)
		filter_input = input
	end
	do
	    local input = aux.gui.editbox(frame.filter)
	    input:SetPoint('LEFT', filter_dropdown, 'RIGHT', 10, 0)
	    input:SetWidth(150)
	    input:SetScript('OnTabPressed', function()
		    filter_input:SetFocus()
	    end)
	    input:SetScript('OnChar', function()
	        this:complete()
	    end)
	    input:SetScript('OnEnterPressed', add_post_filter)
	    input:Hide()
	    filter_parameter_input = input
	end
	do
	    local scroll_frame = CreateFrame('ScrollFrame', nil, frame.filter)
	    scroll_frame:SetWidth(395)
	    scroll_frame:SetHeight(270)
	    scroll_frame:SetPoint('TOPLEFT', 348.5, -50)
	    scroll_frame:EnableMouse(true)
	    scroll_frame:EnableMouseWheel(true)
	    scroll_frame:SetScript('OnMouseWheel', function()
		    local child = this:GetScrollChild()
		    child:SetFont('p', [[Fonts\ARIALN.TTF]], aux.util.bound(11, 23, aux.util.select(2, child:GetFont()) + arg1*2))
		    update_filter_display()
	    end)
	    scroll_frame:RegisterForDrag('LeftButton')
	    scroll_frame:SetScript('OnDragStart', function()
		    this.x, this.y = GetCursorPosition()
		    this.x_offset, this.y_offset = this:GetHorizontalScroll(), this:GetVerticalScroll()
			this.x_extra, this.y_extra = 0, 0
		    this:SetScript('OnUpdate', function()
			    local x, y = GetCursorPosition()
			    local new_x_offset = this.x_offset + x - this.x
			    local new_y_offset = this.y_offset + y - this.y

			    set_filter_display_offset(new_x_offset - this.x_extra, new_y_offset - this.y_extra)

			    this.x_extra = max(this.x_extra, new_x_offset)
			    this.y_extra = min(this.y_extra, new_y_offset)
		    end)
	    end)
	    scroll_frame:SetScript('OnDragStop', function()
		    this:SetScript('OnUpdate', nil)
	    end)
	    aux.gui.set_content_style(scroll_frame, -2, -2, -2, -2)
	    local scroll_child = CreateFrame('SimpleHTML', nil, scroll_frame)
	    scroll_frame:SetScrollChild(scroll_child)
	    scroll_child:SetFont('p', [[Fonts\ARIALN.TTF]], 23)
	    scroll_child:SetTextColor('p', aux.gui.color.label.enabled())
	    scroll_child:SetWidth(1)
	    scroll_child:SetHeight(1)
	    scroll_child:SetScript('OnHyperlinkClick', data_link_click)
--	    scroll_child:SetHyperlinkFormat("format")
	    scroll_child.measure = scroll_child:CreateFontString()
	    filter_display = scroll_child
	end

	status_bars = {}
	tables = {}
	for _=1,5  do
	    local status_bar = aux.gui.status_bar(frame)
	    status_bar:SetAllPoints(status_bar_frame)
	    status_bar:Hide()
	    tinsert(status_bars, status_bar)

	    local table = aux.auction_listing.CreateAuctionResultsTable(frame.results, aux.auction_listing.search_config)
	    table:SetHandler('OnCellClick', function(cell, button)
	        if IsAltKeyDown() and current_search().table:GetSelection().record == cell.row.data.record then
	            if button == 'LeftButton' and buyout_button:IsEnabled() then
	                buyout_button:Click()
	            elseif button == 'RightButton' and bid_button:IsEnabled() then
	                bid_button:Click()
	            end
	        end
	    end)
	    table:SetHandler('OnSelectionChanged', function(rt, datum)
	        if not datum then return end
	        find_auction(datum.record)
	    end)
	    table:Hide()
	    tinsert(tables, table)
	end

	local handlers = {
	    OnClick = function(st, data, _, button)
	        if not data then return end
	        if button == 'LeftButton' and IsShiftKeyDown() then
	            search_box:SetText(data.search.filter_string)
	        elseif button == 'RightButton' and IsShiftKeyDown() then
	            add_filter(data.search.filter_string)
	        elseif button == 'LeftButton' and IsControlKeyDown() then
	            if st == favorite_searches_listing and data.index > 1 then
	                local temp = g.aux_favorite_searches[data.index - 1]
	                g.aux_favorite_searches[data.index - 1] = data.search
	                g.aux_favorite_searches[data.index] = temp
	                update_search_listings()
	            end
	        elseif button == 'RightButton' and IsControlKeyDown() then
	            if st == favorite_searches_listing and data.index < getn(g.aux_favorite_searches) then
	                local temp = g.aux_favorite_searches[data.index + 1]
	                g.aux_favorite_searches[data.index + 1] = data.search
	                g.aux_favorite_searches[data.index] = temp
	                update_search_listings()
	            end
	        elseif button == 'LeftButton' then
	            search_box:SetText(data.search.filter_string)
	            execute()
	        elseif button == 'RightButton' then
	            if st == recent_searches_listing then
	                tinsert(g.aux_favorite_searches, 1, data.search)
	            elseif st == favorite_searches_listing then
	                tremove(g.aux_favorite_searches, data.index)
	            end
	            update_search_listings()
	        end
	    end,
	    OnEnter = function(st, data, self)
	        if not data then return end
	        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	        GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
	        GameTooltip:Show()
	    end,
	    OnLeave = function()
	        GameTooltip:ClearLines()
	        GameTooltip:Hide()
	    end
	}

	recent_searches_listing = aux.listing.CreateScrollingTable(frame.saved.recent)
	recent_searches_listing:SetColInfo{{name='Recent Searches', width=1}}
	recent_searches_listing:EnableSorting(false)
	recent_searches_listing:DisableSelection(true)
	recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
	recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	recent_searches_listing:SetHandler('OnLeave', handlers.OnLeave)

	favorite_searches_listing = aux.listing.CreateScrollingTable(frame.saved.favorite)
	favorite_searches_listing:SetColInfo{{name='Favorite Searches', width=1}}
	favorite_searches_listing:EnableSorting(false)
	favorite_searches_listing:DisableSelection(true)
	favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
	favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	favorite_searches_listing:SetHandler('OnLeave', handlers.OnLeave)
end