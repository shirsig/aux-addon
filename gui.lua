aux.module 'gui'

public.config = {
	colors = {
		text = {enabled = {255, 254, 250, 1}, disabled = {147, 151, 139, 1}},
		label = {enabled = {216, 225, 211, 1}, disabled = {150, 148, 140, 1}},
		link = {153, 255, 255, 1},
		window = {background = {24, 24, 24, .93}, border = {30, 30, 30, 1}},
		panel = {background = {24, 24, 24, 1}, border = {255, 255, 255, .03}},
		content = {background = {42, 42, 42, 1}, border = {0, 0, 0, 0}},
		state = {enabled = {70, 180, 70, 1}, disabled = {190, 70, 70, 1}},

		blue = {41, 146, 255, 1},
		green = {22, 255, 22, 1},
		yellow = {255, 255, 0, 1},
		orange = {255, 146, 24, 1},
		red = {255, 0, 0, 1},
		gray = {187, 187, 187, 1},

		blizzard = {0, 180, 255, 1},
		aux = {255, 255, 154, 1},
	},
    edge_size = 1.5,
    font = [[Fonts\ARIALN.TTF]],
    small_font_size = 13,
	small_font_size2 = 14,
    medium_font_size = 15,
	medium_font_size2 = 16,
	large_font_size = 17,
	large_font_size2 = 18,
    huge_font_size = 23,
}

do
	local function index_handler(self, key)
		self.private.table = self.private.table[key]
		if getn(self.private.table) == 0 then
			return self.public
		else
			local color = copy(self.private.table)
			self.private.table = config.colors
			return self.private.callback(color)
		end
	end
	function color_accessor(callback)
		return function()
			return aux.index_function({callback=callback, table=config.colors}, index_handler)
		end
	end
end

do
	local mt = {
		__call = function(self, text)
			local r, g, b, a = unpack(self)
			if text then
				return format('|c%02X%02X%02X%02X', a, r*255, g*255, b*255)..text..FONT_COLOR_CODE_CLOSE
			else
				return r, g, b, a
			end
		end
	}
	public.accessor.color = color_accessor(function(color)
		local r, g, b, a = unpack(color)
		return setmetatable({r/255, g/255, b/255, a}, mt)
	end)
end

public.accessor.inline_color = color_accessor(function(color)
	local r, g, b, a = unpack(color)
	return format('|c%02X%02X%02X%02X', a, r, g, b)
end)

do
	local id = 0
	function public.accessor.name()
		id = id + 1
		return 'aux_frame'..id
	end
end

do
	local menu, structure

	function public.menu(menu_structure)
		structure = menu_structure
		menu:SetPoint('BOTTOMLEFT', GetCursorPosition())
		menu:Show()
	end

	function initialize_menu()
		menu = CreateFrame('Frame', name, UIParent, 'UIMenuTemplate')
		local orig = menu:GetScript 'OnShow'
		menu:SetScript('OnShow', function()
			UIMenu_Initialize()
			for i=1,getn(structure) do
				UIMenu_AddButton(
					structure[i][1],
					structure[i],
					type(structure[i]) == 'string' and structure[element[3]] or element[3]
				)
			end
			return orig()
		end)
	end
end

function LOAD()
	initialize_menu()
	initialize_dropdown()
end

do
	local blizzard_backdrop, aux_background, aux_border

	function initialize_dropdown()
		aux_border = DropDownList1:CreateTexture()
		aux_border:SetTexture(1, 1, 1, .02)
		aux_border:SetPoint('TOPLEFT', DropDownList1Backdrop, 'TOPLEFT', -2, 2)
		aux_border:SetPoint('BOTTOMRIGHT', DropDownList1Backdrop, 'BOTTOMRIGHT', 1.5, -1.5)
		aux_border:SetBlendMode 'ADD'
		aux_background = DropDownList1:CreateTexture(nil, 'OVERLAY')
		aux_background:SetTexture(color.content.background())
		aux_background:SetAllPoints(DropDownList1Backdrop)
		blizzard_backdrop = DropDownList1Backdrop:GetBackdrop()
		aux.hook('ToggleDropDownMenu', function(...)
			local ret = {aux.orig.ToggleDropDownMenu(unpack(arg))}
			local dropdown = getglobal(arg[4] or '') or this:GetParent()
			if strfind(dropdown:GetName() or '', '^aux_frame%d+$') then
				set_aux_dropdown_style(dropdown)
			else
				set_blizzard_dropdown_style()
			end
			return unpack(ret)
		end)
	end

	function set_aux_dropdown_style(dropdown)
		DropDownList1Backdrop:SetBackdrop{}
		aux_border:Show()
		aux_background:Show()
		DropDownList1:SetWidth(dropdown:GetWidth() * 0.9)
		DropDownList1:SetHeight(DropDownList1:GetHeight() - 10)
		DropDownList1:ClearAllPoints()
		DropDownList1:SetPoint('TOPLEFT', dropdown, 'BOTTOMLEFT', -2, -2)
		for i=1,UIDROPDOWNMENU_MAXBUTTONS do
			local button = getglobal('DropDownList1Button'..i)
			button:SetPoint('TOPLEFT', 0, -((button:GetID() - 1) * UIDROPDOWNMENU_BUTTON_HEIGHT) - 7)
			button:SetPoint('TOPRIGHT', 0, -((button:GetID() - 1) * UIDROPDOWNMENU_BUTTON_HEIGHT) - 7)
			local text = button:GetFontString()
			text:SetFont(config.font, config.small_font_size2)
			text:SetPoint('TOPLEFT', 18, 0)
			text:SetPoint('BOTTOMRIGHT', -8, 0)
			local highlight = getglobal('DropDownList1Button'..i..'Highlight')
			highlight:ClearAllPoints()
			highlight:SetDrawLayer('OVERLAY')
			highlight:SetHeight(14)
			highlight:SetPoint('LEFT', 5, 0)
			highlight:SetPoint('RIGHT', -3, 0)
			local check = getglobal('DropDownList1Button'..i..'Check')
			check:SetWidth(16)
			check:SetHeight(16)
			check:SetPoint('LEFT', 3, -1)
		end
	end

	function set_blizzard_dropdown_style()
		DropDownList1Backdrop:SetBackdrop(blizzard_backdrop)
		aux_border:Hide()
		aux_background:Hide()
		for i=1,UIDROPDOWNMENU_MAXBUTTONS do
			local button = getglobal('DropDownList1Button'..i)
			local text = button:GetFontString()
			text:SetFont([[Fonts\FRIZQT__.ttf]], 10)
			text:SetShadowOffset(1, -1)
			local highlight = getglobal('DropDownList1Button'..i..'Highlight')
			highlight:SetAllPoints()
			highlight:SetDrawLayer('BACKGROUND')
			local check = getglobal('DropDownList1Button'..i..'Check')
			check:SetWidth(24)
			check:SetHeight(24)
			check:SetPoint('LEFT', 0, 0)
		end
	end
end

function public.set_size(frame, width, height)
	frame:SetWidth(width)
	frame:SetHeight(height or width)
end

function public.set_frame_style(frame, backdrop_color, border_color, left, right, top, bottom)
	frame:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=config.edge_size, tile=true, insets={left=left, right=right, top=top, bottom=bottom}}
	frame:SetBackdropColor(backdrop_color())
	frame:SetBackdropBorderColor(border_color())
end

function public.set_window_style(frame, left, right, top, bottom)
    set_frame_style(frame, color.window.background, color.window.border, left, right, top, bottom)
end

function public.set_panel_style(frame, left, right, top, bottom)
    set_frame_style(frame, color.panel.background, color.panel.border, left, right, top, bottom)
end

function public.set_content_style(frame, left, right, top, bottom)
    set_frame_style(frame, color.content.background, color.content.border, left, right, top, bottom)
end

function public.panel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    set_panel_style(panel)
    return panel
end

function public.checkbutton(parent, text_height)
    local button = button(parent, text_height)
    button.state = false
    button:SetBackdropColor(color.state.disabled())
    function button:SetChecked(state)
        if state then
            self:SetBackdropColor(color.state.enabled())
            self.state = true
        else
            self:SetBackdropColor(color.state.disabled())
            self.state = false
        end
    end
    function button:GetChecked()
        return self.state
    end
    return button
end

function public.button(parent, text_height)
    text_height = text_height or 16
    local button = CreateFrame('Button', nil, parent)
    set_content_style(button)
    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetAllPoints()
    highlight:SetTexture(1, 1, 1, .2)
    highlight:SetBlendMode('BLEND')
    button.highlight = highlight
    do
        local label = button:CreateFontString()
        label:SetFont(config.font, text_height)
        label:SetPoint('CENTER', 0, 0)
        label:SetJustifyH('CENTER')
        label:SetJustifyV('CENTER')
        label:SetHeight(text_height)
        label:SetTextColor(color.text.enabled())
        button:SetFontString(label)
    end
    button.default_Enable = button.Enable
    function button:Enable()
        self:GetFontString():SetTextColor(color.text.enabled())
        return self:default_Enable()
    end
    button.default_Disable = button.Disable
    function button:Disable()
        self:GetFontString():SetTextColor(color.text.disabled())
        return self:default_Disable()
    end

    return button
end


function public.resize_tab(tab, width, padding)
    tab:SetWidth(width + padding + 10)
end

do
	local mt = {__index={}}
	function mt.__index:create_tab(text)
		local id = getn(self._tabs) + 1

		local tab = CreateFrame('Button', name, self._frame)
		tab.id = id
		tab.group = self
		tab:SetHeight(24)
		tab:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=config.edge_size}
		tab:SetBackdropBorderColor(color.panel.border())
		local dock = tab:CreateTexture(nil, 'OVERLAY')
		dock:SetHeight(3)
		if self._orientation == 'UP' then
			dock:SetPoint('BOTTOMLEFT', 1, -1)
			dock:SetPoint('BOTTOMRIGHT', -1, -1)
		elseif self._orientation == 'DOWN' then
			dock:SetPoint('TOPLEFT', 1, 1)
			dock:SetPoint('TOPRIGHT', -1, 1)
		end
		dock:SetTexture(color.panel.background())
		tab.dock = dock
		local highlight = tab:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		highlight:SetTexture(1, 1, 1, .2)
		highlight:SetBlendMode 'BLEND'
		tab.highlight = highlight

		tab.text = tab:CreateFontString()
		tab.text:SetPoint('LEFT', 3, -1)
		tab.text:SetPoint('RIGHT', -3, -1)
		tab.text:SetJustifyH 'CENTER'
		tab.text:SetJustifyV 'CENTER'
		tab.text:SetFont(config.font, config.large_font_size2)
		tab:SetFontString(tab.text)

		tab:SetText(text)

		tab:SetScript('OnClick', function()
			if this.id ~= this.group.selected then
				PlaySound 'igCharacterInfoTab'
				this.group:select(this.id)
			end
		end)

		if getn(self._tabs) == 0 then
			if self._orientation == 'UP' then
				tab:SetPoint('BOTTOMLEFT', self._frame, 'TOPLEFT', 4, -1)
			elseif self._orientation == 'DOWN' then
				tab:SetPoint('TOPLEFT', self._frame, 'BOTTOMLEFT', 4, 1)
			end
		else
			if self._orientation == 'UP' then
				tab:SetPoint('BOTTOMLEFT', self._tabs[getn(self._tabs)], 'BOTTOMRIGHT', 4, 0)
			elseif self._orientation == 'DOWN' then
				tab:SetPoint('TOPLEFT', self._tabs[getn(self._tabs)], 'TOPRIGHT', 4, 0)
			end
		end

		resize_tab(tab, tab:GetFontString():GetStringWidth(), 4)

		tinsert(self._tabs, tab)
	end
	function mt.__index:select(id)
		self._selected = id
		self:update()
		aux.call(self._on_select, id)
	end
	function mt.__index:update()
		for _, tab in self._tabs do
			if tab.group._selected == tab.id then
				tab.text:SetTextColor(color.label.enabled())
				tab:Disable()
				tab:SetBackdropColor(color.panel.background())
				tab.dock:Show()
				tab:SetHeight(29)
			else
				tab.text:SetTextColor(color.text.enabled())
				tab:Enable()
				tab:SetBackdropColor(color.content.background())
				tab.dock:Hide()
				tab:SetHeight(24)
			end
		end
	end
	function public.tabs(parent, orientation)
		local self = {
			_frame = parent,
			_orientation = orientation,
			_tabs = {},
		}
	    return setmetatable(self, mt)
	end
end

function public.editbox(parent)
    local editbox = CreateFrame('EditBox', nil, parent)
    editbox:SetAutoFocus(false)
    editbox:SetTextInsets(1, 2, 3, 3)
    editbox:SetMaxLetters(256)
    editbox:SetHeight(24)
    editbox:SetFont(config.font, config.medium_font_size)
    editbox:SetTextColor(0, 0, 0, 0)
    set_content_style(editbox)
    editbox:SetScript('OnEscapePressed', aux.C(editbox.ClearFocus, aux._this))
    editbox:SetScript('OnEditFocusGained', function()
	    this.last_change = GetTime()
	    this:HighlightText()
	    this:SetScript('OnUpdate', function()
			this.cursor:SetAlpha(mod(floor((GetTime()-this.last_change) * 2 + 1), 2))
	    end)
    end)
    editbox:SetScript('OnEditFocusLost', function()
	    this.cursor:SetAlpha(0)
	    this:HighlightText(0, 0)
	    this:SetScript('OnUpdate', nil)
    end)
    editbox:SetScript('OnTextChanged', function()
	    this.last_change = GetTime()
	    this.text:SetText(aux.call(this.formatter, this:GetText()) or this:GetText())
	    this.cursor:SetPoint('LEFT', this.text, 'LEFT', max(0, this.text:GetStringWidth() - 2), 1)
    end)
    do
        local last_click
        editbox:SetScript('OnMouseDown', function()
            local x, y = GetCursorPosition()
            -- local offset = x - editbox:GetLeft()*editbox:GetEffectiveScale() TODO use a fontstring to measure getstringwidth for structural highlighting
            -- editbox:Insert'<ksejfkj>' TODO use insert with special tags to determine cursor position
            -- or use an overlay with itemlinks
            if last_click and GetTime() - last_click.t < .5 and x == last_click.x and y == last_click.y then
                aux.control.thread(function() editbox:HighlightText() end)
            end
            last_click = {t=GetTime(), x=x, y=y}
        end)
    end
    function editbox:Enable()
	    editbox:EnableMouse(true)
	    editbox:SetTextColor(color.text.enabled())
    end
    function editbox:Disable()
	    editbox:EnableMouse(false)
	    editbox:SetTextColor(color.text.disabled())
	    editbox:ClearFocus()
    end
    local text = aux.gui.label(editbox, config.medium_font_size)
    text:SetPoint('LEFT', 1, 0)
    text:SetPoint('RIGHT', -2, 0)
    text:SetJustifyH 'LEFT'
    text:SetTextColor(color.text.enabled())
    editbox.text = text
    local cursor = aux.gui.label(editbox, config.large_font_size)
    cursor:SetJustifyH 'LEFT'
    cursor:SetText '|'
    cursor:SetTextColor(color.text.enabled())
    cursor:SetAlpha(0)
    editbox.cursor = cursor
    return editbox
end

function public.status_bar(parent)
    local self = CreateFrame('Frame', nil, parent)

    local level = parent:GetFrameLevel()

    self:SetFrameLevel(level + 1)

    do
        -- minor status bar (gray one)
        local status_bar = CreateFrame('STATUSBAR', nil, self, 'TextStatusBar')
        status_bar:SetOrientation 'HORIZONTAL'
        status_bar:SetMinMaxValues(0, 100)
        status_bar:SetAllPoints()
        status_bar:SetStatusBarTexture [[Interface\Buttons\WHITE8X8]]
        status_bar:SetStatusBarColor(.42, .42, .42, .7)
        status_bar:SetFrameLevel(level + 2)
        status_bar:SetScript('OnUpdate', function()
            if this:GetValue() < 100 then
                this:SetAlpha(1 - ((math.sin(GetTime()*math.pi)+1)/2)/2)
            else
                this:SetAlpha(1)
            end
        end)
        self.minor_status_bar = status_bar
    end

    do
        -- major status bar (main blue one)
        local status_bar = CreateFrame('STATUSBAR', nil, self, 'TextStatusBar')
        status_bar:SetOrientation 'HORIZONTAL'
        status_bar:SetMinMaxValues(0, 100)
        status_bar:SetAllPoints()
        status_bar:SetStatusBarTexture [[Interface\Buttons\WHITE8X8]]
        status_bar:SetStatusBarColor(.19, .22, .33, .9)
        status_bar:SetFrameLevel(level + 3)
        status_bar:SetScript('OnUpdate', function()
            if this:GetValue() < 100 then
                this:SetAlpha(1 - ((math.sin(GetTime()*math.pi)+1)/2)/2)
            else
                this:SetAlpha(1)
            end
        end)
        self.major_status_bar = status_bar
    end

    do
        local text_frame = CreateFrame('Frame', nil, self)
        text_frame:SetFrameLevel(level + 4)
        text_frame:SetAllPoints(self)
        local text = label(text_frame, 15)
        text:SetTextColor(color.text.enabled())
        text:SetPoint('CENTER', 0, 0)
        self.text = text
    end

    function self:update_status(major_status, minor_status)
        if major_status then
            self.major_status_bar:SetValue(major_status)
        end
        if minor_status then
            self.minor_status_bar:SetValue(minor_status)
        end
    end

    function self:set_text(text)
        self.text:SetText(text)
    end

    return self
end

function public.item(parent)
    local item = CreateFrame('Frame', nil, parent)
    item:SetWidth(260)
    item:SetHeight(40)
    local btn = CreateFrame('CheckButton', name, item, 'ActionButtonTemplate')
    item.button = btn
    btn:SetPoint('LEFT', 2, .5)
    btn:SetHighlightTexture(nil)
    btn:RegisterForClicks()
    item.texture = getglobal(btn:GetName()..'Icon')
    item.texture:SetTexCoord(.06, .94, .06, .94)
    item.name = aux.gui.label(btn, 15)
    item.name:SetJustifyH('LEFT')
    item.name:SetPoint('LEFT', btn, 'RIGHT', 10, 0)
    item.name:SetPoint('RIGHT', item, 'RIGHT', -10, .5)
    item.count = getglobal(btn:GetName()..'Count')
    item.count:SetTextHeight(17)
    return item
end

function public.label(parent, size)
    local label = parent:CreateFontString()
    label:SetFont(config.font, size or config.small_font_size)
    label:SetTextColor(color.label.enabled())
    return label
end

function public.horizontal_line(parent, y_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, y_offset)
    texture:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -2, y_offset)
    texture:SetHeight(2)
    if inverted_color then
        texture:SetTexture(color.panel.background())
    else
        texture:SetTexture(color.content.background())
    end
    return texture
end

function public.vertical_line(parent, x_offset, top_offset, bottom_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', x_offset, top_offset or -2)
    texture:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', x_offset, bottom_offset or 2)
    texture:SetWidth(2)
    if inverted_color then
        texture:SetTexture(color.panel.background())
    else
        texture:SetTexture(color.content.background())
    end
    return texture
end

function public.dropdown(parent)
    local dropdown = CreateFrame('Frame', name, parent, 'UIDropDownMenuTemplate')
	set_content_style(dropdown, 0, 0, 4, 4)

    getglobal(dropdown:GetName()..'Left'):Hide()
    getglobal(dropdown:GetName()..'Middle'):Hide()
    getglobal(dropdown:GetName()..'Right'):Hide()

    local button = getglobal(dropdown:GetName()..'Button')
    button:ClearAllPoints()
    button:SetScale(0.9)
    button:SetPoint('RIGHT', dropdown, 0, 0)
    dropdown.button = button

    local text = getglobal(dropdown:GetName()..'Text')
    text:ClearAllPoints()
    text:SetPoint('RIGHT', button, 'LEFT', -2, 0)
    text:SetPoint('LEFT', 8, 0)
    text:SetFont(config.font, config.medium_font_size)
    text:SetShadowColor(0, 0, 0, 0)

    return dropdown
end

function public.slider(parent)

    local slider = CreateFrame('Slider', nil, parent)
    slider:SetOrientation 'HORIZONTAL'
    slider:SetHeight(6)
    slider:SetHitRectInsets(0, 0, -12, -12)
    slider:SetValue(0)

    set_panel_style(slider)
    local thumb_texture = slider:CreateTexture(nil, 'ARTWORK')
    thumb_texture:SetPoint('CENTER', 0, 0)
    thumb_texture:SetTexture(color.content.background())
    thumb_texture:SetHeight(18)
    thumb_texture:SetWidth(8)
    slider:SetThumbTexture(thumb_texture)

    local label = slider:CreateFontString(nil, 'OVERLAY')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT', -3, 8)
    label:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT', 6, 8)
    label:SetJustifyH 'LEFT'
    label:SetHeight(13)
    label:SetFont(config.font, config.small_font_size)
    label:SetTextColor(color.label.enabled())

    local editbox = editbox(slider)
    editbox:SetPoint('LEFT', slider, 'RIGHT', 5, 0)
    editbox:SetWidth(45)
    editbox:SetHeight(18)
    editbox:SetJustifyH 'CENTER'
    editbox:SetFont(config.font, 17)

    slider.label = label
    slider.editbox = editbox
    return slider
end

function public.checkbox(parent)
    local checkbox = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
    checkbox:SetWidth(16)
    checkbox:SetHeight(16)
	set_content_style(checkbox)
    checkbox:SetNormalTexture(nil)
    checkbox:SetPushedTexture(nil)
    checkbox:GetHighlightTexture():SetAllPoints()
    checkbox:GetHighlightTexture():SetTexture(1, 1, 1, .2)
    checkbox:GetCheckedTexture():SetTexCoord(.12, .88, .12, .88)
    checkbox:GetHighlightTexture 'BLEND'
    return checkbox
end