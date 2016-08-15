local m, public, private = aux.module'search_tab'

private.FILTER_SPACING = 28.5

function private.create_frames()
	private.frame = CreateFrame('Frame', nil, aux.frame)
	m.frame:SetAllPoints()
	m.frame:SetScript('OnUpdate', m.on_update)
	m.frame:Hide()

	m.frame.filter = aux.gui.panel(m.frame)
	m.frame.filter:SetAllPoints(aux.frame.content)

	m.frame.results = aux.gui.panel(m.frame)
	m.frame.results:SetAllPoints(aux.frame.content)

	m.frame.saved = CreateFrame('Frame', nil, m.frame)
	m.frame.saved:SetAllPoints(aux.frame.content)

	m.frame.saved.favorite = aux.gui.panel(m.frame.saved)
	m.frame.saved.favorite:SetWidth(378.5)
	m.frame.saved.favorite:SetPoint('TOPLEFT', 0, 0)
	m.frame.saved.favorite:SetPoint('BOTTOMLEFT', 0, 0)

	m.frame.saved.recent = aux.gui.panel(m.frame.saved)
	m.frame.saved.recent:SetWidth(378.5)
	m.frame.saved.recent:SetPoint('TOPRIGHT', 0, 0)
	m.frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)
	do
	    local btn = aux.gui.button(m.frame)
	    btn:SetPoint('TOPLEFT', 0, 0)
	    btn:SetWidth(42)
	    btn:SetHeight(42)
	    btn:SetScript('OnClick', function()
	        if this.open then
	            m.settings:Hide()
	            m.controls:Show()
	        else
	            m.settings:Show()
	            m.controls:Hide()
	        end
	        this.open = not this.open
	    end)

	    for _, offset in {14, 10, 6} do
	        local fake_icon_part = btn:CreateFontString()
	        fake_icon_part:SetFont([[Fonts\FRIZQT__.TTF]], 23)
	        fake_icon_part:SetPoint('CENTER', 0, offset)
	        fake_icon_part:SetText('_')
	    end

	    private.settings_button = btn
	end
	do
	    local panel = CreateFrame('Frame', nil, m.frame)
	    panel:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]]}
	    panel:SetBackdropColor(unpack(aux.gui.color.content.backdrop))
	    panel:SetPoint('LEFT', m.settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 0)
	    panel:SetHeight(42)
	    panel:Hide()
	    private.settings = panel
	end
	do
	    local panel = CreateFrame('Frame', nil, m.frame)
	    panel:SetPoint('LEFT', m.settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 1)
	    panel:SetHeight(40)
	    private.controls = panel
	end
	do
	    local editbox = aux.gui.editbox(m.settings)
	    editbox:SetPoint('LEFT', 75, 0)
	    editbox:SetWidth(50)
	    editbox:SetNumeric(true)
	    editbox:SetMaxLetters(nil)
	    editbox:SetScript('OnTabPressed', function()
	        m.last_page_input:SetFocus()
	    end)
	    editbox:SetScript('OnEnterPressed', function()
	        this:ClearFocus()
	        m.execute()
	    end)
	    editbox:SetScript('OnTextChanged', function()
		    local page = tonumber(this:GetText())
		    local valid_input = page and tostring(max(1, page)) or ''
		    if this:GetText() ~= valid_input then
			    this:SetText(valid_input)
		    end
	        if m.blizzard_page_index(this:GetText()) and not m.real_time_button:GetChecked() then
	            this:SetBackdropColor(unpack(aux.gui.color.state.enabled))
	        else
	            this:SetBackdropColor(unpack(aux.gui.color.state.disabled))
	        end
	    end)
	    local label = aux.gui.label(editbox, 16)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -6, 0)
	    label:SetText('Pages')
	    label:SetTextColor(unpack(aux.gui.color.text.enabled))
	    private.first_page_input = editbox
	end
	do
	    local editbox = aux.gui.editbox(m.settings)
	    editbox:SetPoint('LEFT', m.first_page_input, 'RIGHT', 10, 0)
	    editbox:SetWidth(50)
	    editbox:SetNumeric(true)
	    editbox:SetMaxLetters(nil)
	    editbox:SetScript('OnTabPressed', function()
	        m.first_page_input:SetFocus()
	    end)
	    editbox:SetScript('OnEnterPressed', function()
	        this:ClearFocus()
	        m.execute()
	    end)
	    editbox:SetScript('OnTextChanged', function()
		    local page = tonumber(this:GetText())
		    local valid_input = page and tostring(max(1, page)) or ''
		    if this:GetText() ~= valid_input then
			    this:SetText(valid_input)
		    end
	        if m.blizzard_page_index(this:GetText()) and not m.real_time_button:GetChecked() then
	            this:SetBackdropColor(unpack(aux.gui.color.state.enabled))
	        else
	            this:SetBackdropColor(unpack(aux.gui.color.state.disabled))
	        end
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -3.5, 0)
	    label:SetText('-')
	    label:SetTextColor(unpack(aux.gui.color.text.enabled))
	    private.last_page_input = editbox
	end
	do
	    local btn = aux.gui.checkbutton(m.settings)
	    btn:SetPoint('LEFT', 230, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Real Time Mode')
	    btn:SetScript('OnClick', function()
	        this:SetChecked(not this:GetChecked())
	        this = m.first_page_input
	        m.first_page_input:GetScript('OnTextChanged')()
	        this = m.last_page_input
	        m.last_page_input:GetScript('OnTextChanged')()
	    end)
	    public.real_time_button = btn
	end
	do
	    local btn = aux.gui.checkbutton(m.settings)
	    btn:SetPoint('LEFT', m.real_time_button, 'RIGHT', 15, 0)
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
	    private.auto_buy_button = btn
	end
	do
	    local btn = aux.gui.checkbutton(m.settings)
	    btn:SetPoint('LEFT', m.auto_buy_button, 'RIGHT', 15, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Auto Buyout Filter')
	    btn:SetScript('OnClick', function()
	        if this:GetChecked() then
	            this:SetChecked(false)
	            aux_auto_buy_filter = nil
	            this.prettified = nil
	            m.auto_buy_validator = nil
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
	    private.auto_buy_filter_button = btn
	end
	do
	    local btn = aux.gui.button(m.controls, 25)
	    btn:SetPoint('LEFT', 5, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('<')
	    btn:SetScript('OnClick', m.previous_search)
	    private.previous_button = btn
	end
	do
	    local btn = aux.gui.button(m.controls, 25)
	    btn:SetPoint('LEFT', m.previous_button, 'RIGHT', 4, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('>')
	    btn:SetScript('OnClick', m.next_search)
	    private.next_button = btn
	end
	do
	    local btn = aux.gui.button(m.controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Start')
	    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	    btn:SetScript('OnClick', function()
	        if arg1 == 'RightButton' then
	            m.set_filter(m.current_search().filter_string)
	        end
	        m.execute()
	    end)
	    private.start_button = btn
	end
	do
	    local btn = aux.gui.button(m.controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Stop')
	    btn:SetScript('OnClick', function()
	        aux.scan.abort(m.search_scan_id)
	    end)
	    private.stop_button = btn
	end
	do
	    local btn = aux.gui.button(m.controls, aux.gui.config.huge_font_size)
	    btn:SetPoint('RIGHT', m.start_button, 'LEFT', -4, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText(aux.auction_listing.colors.GREEN..'Resume'..FONT_COLOR_CODE_CLOSE)
	    btn:SetScript('OnClick', function()
	        m.execute(true)
	    end)
	    private.resume_button = btn
	end
	do
	    local editbox = aux.gui.editbox(m.controls)
	    editbox:SetMaxLetters(nil)
	    editbox:EnableMouse(1)
	    editbox.complete = aux.completion.complete_filter
	    editbox:SetPoint('RIGHT', m.start_button, 'LEFT', -4, 0)
	    editbox:SetHeight(25)
	    editbox:SetScript('OnChar', function()
	        this:complete()
	    end)
	    editbox:SetScript('OnTabPressed', function()
	        this:HighlightText(0, 0)
	    end)
	    editbox:SetScript('OnEnterPressed', m.execute)
	    private.search_box = editbox
	end
	do
	    aux.gui.horizontal_line(m.frame, -40)
	end
	do
	    local btn = aux.gui.button(m.frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('BOTTOMLEFT', aux.frame.content, 'TOPLEFT', 10, 8)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Search Results')
	    btn:SetScript('OnClick', function() m.update_tab(m.RESULTS) end)
	    private.search_results_button = btn
	end
	do
	    local btn = aux.gui.button(m.frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('TOPLEFT', m.search_results_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Saved Searches')
	    btn:SetScript('OnClick', function() m.update_tab(m.SAVED) end)
	    private.saved_searches_button = btn
	end
	do
	    local btn = aux.gui.button(m.frame, aux.gui.config.large_font_size2)
	    btn:SetPoint('TOPLEFT', m.saved_searches_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Filter Builder')
	    btn:SetScript('OnClick', function() m.update_tab(m.FILTER) end)
	    private.new_filter_button = btn
	end
	do
	    local frame = CreateFrame('Frame', nil, m.frame)
	    frame:SetWidth(265)
	    frame:SetHeight(25)
	    frame:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
	    private.status_bar_frame = frame
	end
	do
	    local btn = aux.gui.button(m.frame.results, 16)
	    btn:SetPoint('TOPLEFT', m.status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Bid')
	    btn:Disable()
	    private.bid_button = btn
	end
	do
	    local btn = aux.gui.button(m.frame.results, 16)
	    btn:SetPoint('TOPLEFT', m.bid_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Buyout')
	    btn:Disable()
	    private.buyout_button = btn
	end
	do
	    local btn = aux.gui.button(m.frame.results, 16)
	    btn:SetPoint('TOPLEFT', m.buyout_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Clear')
	    btn:SetScript('OnClick', function()
	        while tremove(m.current_search().records) do end
	        m.current_search().table:SetDatabase()
	    end)
	end
	do
	    local btn = aux.gui.button(m.frame.saved, 16)
	    btn:SetPoint('TOPLEFT', m.status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Favorite')
	    btn:SetScript('OnClick', function()
	        local filters = aux.filter.queries(m.search_box:GetText())
	        if filters then
	            tinsert(aux_favorite_searches, 1, {
	                filter_string = m.search_box:GetText(),
	                prettified = table.concat(aux.util.map(filters, function(filter) return filter.prettified end), ';'),
	            })
	        end
	        m.update_search_listings()
	    end)
	end
	do
	    local btn1 = aux.gui.button(m.frame.filter, 16)
	    btn1:SetPoint('TOPLEFT', m.status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn1:SetWidth(80)
	    btn1:SetHeight(24)
	    btn1:SetText('Search')
	    btn1:SetScript('OnClick', function()
	        m.export_query_string()
	        m.execute()
	    end)

	    local btn2 = aux.gui.button(m.frame.filter, 16)
	    btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
	    btn2:SetWidth(80)
	    btn2:SetHeight(24)
	    btn2:SetText('Export')
	    btn2:SetScript('OnClick', m.export_query_string)

	    local btn3 = aux.gui.button(m.frame.filter, 16)
	    btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
	    btn3:SetWidth(80)
	    btn3:SetHeight(24)
	    btn3:SetText('Import')
	    btn3:SetScript('OnClick', m.import_query_string)
	end
	do
	    local editbox = aux.gui.editbox(m.frame.filter)
	    editbox.complete_item = aux.completion.complete(function() return aux_auctionable_items end)
	    editbox:SetPoint('TOPLEFT', 14, -m.FILTER_SPACING)
	    editbox:SetWidth(260)
	    editbox:SetScript('OnChar', function()
	        if m.blizzard_query.exact then
	            this:complete_item()
	        end
	    end)
	    editbox:SetScript('OnTabPressed', function()
		    if m.blizzard_query.exact then
			    return
		    end
	        if IsShiftKeyDown() then
	            m.max_level_input:SetFocus()
	        else
	            m.min_level_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnTextChanged',  m.update_form)
	    editbox:SetScript('OnEnterPressed', aux._(editbox.ClearFocus, editbox))
	    local label = aux.gui.label(editbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Name')
	    private.name_input = editbox
	end
	do
	    local checkbox = aux.gui.checkbox(m.frame.filter)
	    checkbox:SetPoint('TOPLEFT', m.name_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', m.update_form)
	    local label = aux.gui.label(checkbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Exact')
	    private.exact_checkbox = checkbox
	end
	do
	    local editbox = aux.gui.editbox(m.frame.filter)
	    editbox:SetPoint('TOPLEFT', m.name_input, 'BOTTOMLEFT', 0, -m.FILTER_SPACING)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            m.name_input:SetFocus()
	        else
	            m.max_level_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnEnterPressed', aux._(editbox.ClearFocus, editbox))
	    editbox:SetScript('OnTextChanged', function()
		    local valid_level = m.valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    m.update_form()
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Level Range')
	    private.min_level_input = editbox
	end
	do
	    local editbox = aux.gui.editbox(m.frame.filter)
	    editbox:SetPoint('TOPLEFT', m.min_level_input, 'TOPRIGHT', 10, 0)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            m.min_level_input:SetFocus()
	        else
	            m.name_input:SetFocus()
	        end
	    end)
	    editbox:SetScript('OnEnterPressed', aux._(editbox.ClearFocus, editbox))
	    editbox:SetScript('OnTextChanged', function()
		    local valid_level = m.valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    m.update_form()
	    end)
	    local label = aux.gui.label(editbox, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
	    label:SetText('-')
	    private.max_level_input = editbox
	end
	do
	    local checkbox = aux.gui.checkbox(m.frame.filter)
	    checkbox:SetPoint('TOPLEFT', m.max_level_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', m.update_form)
	    local label = aux.gui.label(checkbox, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Usable')
	    private.usable_checkbox = checkbox
	end
	do
	    local dropdown = aux.gui.dropdown(m.frame.filter)
	    private.class_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', m.min_level_input, 'BOTTOMLEFT', 0, 5 - m.FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Class')
	    UIDropDownMenu_Initialize(dropdown, m.initialize_class_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, m.initialize_class_dropdown)
	    end)
	end
	do
	    local dropdown = aux.gui.dropdown(m.frame.filter)
	    private.subclass_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', m.class_dropdown, 'BOTTOMLEFT', 0, 10 - m.FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Subclass')
	    UIDropDownMenu_Initialize(dropdown, m.initialize_subclass_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, m.initialize_subclass_dropdown)
	    end)
	end
	do
	    local dropdown = aux.gui.dropdown(m.frame.filter)
	    private.slot_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', m.subclass_dropdown, 'BOTTOMLEFT', 0, 10 - m.FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Slot')
	    UIDropDownMenu_Initialize(dropdown, m.initialize_slot_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, m.initialize_slot_dropdown)
	    end)

	end
	do
	    local dropdown = aux.gui.dropdown(m.frame.filter)
	    private.quality_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', m.slot_dropdown, 'BOTTOMLEFT', 0, 10 - m.FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = aux.gui.label(dropdown, aux.gui.config.small_font_size)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Min Quality')
	    UIDropDownMenu_Initialize(dropdown, m.initialize_quality_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, m.initialize_quality_dropdown)
	    end)
	end
	aux.gui.vertical_line(m.frame.filter, 332)
	do
	    local dropdown = aux.gui.dropdown(m.frame.filter)
	    dropdown:SetPoint('TOPRIGHT', -174.5, -10)
	    dropdown:SetWidth(150)
	    UIDropDownMenu_Initialize(dropdown, m.initialize_filter_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, m.initialize_filter_dropdown)
	    end)
	    getglobal(dropdown:GetName()..'Text'):Hide()
	    local label = aux.gui.label(dropdown, aux.gui.config.medium_font_size)
	    label:SetPoint('RIGHT', dropdown, 'LEFT', -15, 0)
	    label:SetText('Post Filter')
	    private.filter_dropdown = dropdown
	end
	do
	    local btn = aux.gui.button(m.frame.filter, 16)
	    btn:SetWidth(150)
	    btn:SetHeight(25)
	    btn:SetPoint('CENTER', m.filter_dropdown, 'CENTER', 0, 0)
	    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	    btn:SetScript('OnClick', function()
	        if arg1 == 'LeftButton' then
	            m.add_dropdown_component()
	        elseif arg1 == 'RightButton' then
	            m.remove_component()
	        end
	    end)
	    private.filter_button = btn
	end
	do
	    local input = aux.gui.editbox(m.frame.filter)
	    input:SetPoint('LEFT', m.filter_dropdown, 'RIGHT', 10, 0)
	    input:SetWidth(150)
	    input:SetHeight(25)
	    input:SetScript('OnChar', function()
	        this:complete()
	    end)
	    input:SetScript('OnEnterPressed', m.add_dropdown_component)
	    input:Hide()
	    private.filter_input = input
	end
	do
	    local scroll_frame = CreateFrame('ScrollFrame', nil, m.frame.filter)
	    scroll_frame:SetWidth(395)
	    scroll_frame:SetHeight(270)
	    scroll_frame:SetPoint('TOPLEFT', 348.5, -50)
	    scroll_frame:EnableMouse(true)
	    scroll_frame:EnableMouseWheel(true)
	    scroll_frame:SetScript('OnMouseWheel', function()
		    local child = this:GetScrollChild()
		    child:SetFont('p', [[Fonts\ARIALN.TTF]], aux.util.bound(11, 23, aux.util.select(2, child:GetFont()) + arg1*2))
		    m.update_filter_display()
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

			    m.set_filter_display_offset(new_x_offset - this.x_extra, new_y_offset - this.y_extra)

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
	    scroll_child:SetWidth(1)
	    scroll_child:SetHeight(1)
	    scroll_child:SetScript('OnHyperlinkClick', m.data_link_click)
--	    scroll_child:SetHyperlinkFormat("format")
	    scroll_child.measure = scroll_child:CreateFontString()
	    private.filter_display = scroll_child
	end

	private.status_bars = {}
	private.tables = {}
	for _=1,5  do
	    local status_bar = aux.gui.status_bar(m.frame)
	    status_bar:SetAllPoints(m.status_bar_frame)
	    status_bar:Hide()
	    tinsert(m.status_bars, status_bar)

	    local table = aux.auction_listing.CreateAuctionResultsTable(m.frame.results, aux.auction_listing.search_config)
	    table:SetHandler('OnCellClick', function(cell, button)
	        if IsAltKeyDown() and m.current_search().table:GetSelection().record == cell.row.data.record then
	            if button == 'LeftButton' and m.buyout_button:IsEnabled() then
	                m.buyout_button:Click()
	            elseif button == 'RightButton' and m.bid_button:IsEnabled() then
	                m.bid_button:Click()
	            end
	        end
	    end)
	    table:SetHandler('OnSelectionChanged', function(rt, datum)
	        if not datum then return end
	        m.find_auction(datum.record)
	    end)
	    table:Hide()
	    tinsert(m.tables, table)
	end

	local handlers = {
	    OnClick = function(st, data, _, button)
	        if not data then return end
	        if button == 'LeftButton' and IsShiftKeyDown() then
	            m.search_box:SetText(data.search.filter_string)
	        elseif button == 'RightButton' and IsShiftKeyDown() then
	            m.add_filter(data.search.filter_string)
	        elseif button == 'LeftButton' and IsControlKeyDown() then
	            if st == m.favorite_searches_listing and data.index > 1 then
	                local temp = aux_favorite_searches[data.index - 1]
	                aux_favorite_searches[data.index - 1] = data.search
	                aux_favorite_searches[data.index] = temp
	                m.update_search_listings()
	            end
	        elseif button == 'RightButton' and IsControlKeyDown() then
	            if st == m.favorite_searches_listing and data.index < getn(aux_favorite_searches) then
	                local temp = aux_favorite_searches[data.index + 1]
	                aux_favorite_searches[data.index + 1] = data.search
	                aux_favorite_searches[data.index] = temp
	                m.update_search_listings()
	            end
	        elseif button == 'LeftButton' then
	            m.search_box:SetText(data.search.filter_string)
	            m.execute()
	        elseif button == 'RightButton' then
	            if st == m.recent_searches_listing then
	                tinsert(aux_favorite_searches, 1, data.search)
	            elseif st == m.favorite_searches_listing then
	                tremove(aux_favorite_searches, data.index)
	            end
	            m.update_search_listings()
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

	private.recent_searches_listing = aux.listing.CreateScrollingTable(m.frame.saved.recent)
	m.recent_searches_listing:SetColInfo({{name='Recent Searches', width=1}})
	m.recent_searches_listing:EnableSorting(false)
	m.recent_searches_listing:DisableSelection(true)
	m.recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
	m.recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	m.recent_searches_listing:SetHandler('OnLeave', handlers.OnLeave)

	private.favorite_searches_listing = aux.listing.CreateScrollingTable(m.frame.saved.favorite)
	m.favorite_searches_listing:SetColInfo({{name='Favorite Searches', width=1}})
	m.favorite_searches_listing:EnableSorting(false)
	m.favorite_searches_listing:DisableSelection(true)
	m.favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
	m.favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	m.favorite_searches_listing:SetHandler('OnLeave', handlers.OnLeave)
end