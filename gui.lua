local m, public, private = aux.module'gui'

public.config = {
	color = {
		text = {enabled = {255, 254, 250, 1}, disabled = {147, 151, 139, 1}},
		label = {enabled = {216, 225, 211, 1}, disabled = {150, 148, 140, 1}},
		link = {153, 255, 255, 1},
		window = {backdrop = {24, 24, 24, .93}, border = {30, 30, 30, 1}},
		panel = {backdrop = {24, 24, 24, 1}, border = {255, 255, 255, .03}},
		content = {backdrop = {42, 42, 42, 1}, border = {0, 0, 0, 0}},
		state = {enabled = {60, 180, 60}, disabled = {180, 60, 60}},
	},
    edge_size = 1.5,
    font = [[Fonts\ARIALN.TTF]],
    tiny_font_size = 12,
    small_font_size = 13,
    medium_font_size = 15,
    large_font_size = 18,
    huge_font_size = 23,
}

public.color = aux.index_function(function(self, key)
	self._t = (rawget(self, '_t') or m.config.color)[key]
	if getn(self._t) == 0 then
		return self
	end
	local color = aux.util.copy(self._t)
	self._t = nil
	for i=1,3 do
		color[i] = color[i]/255
	end
	return color
end)

public.inline_color = aux.index_function(function(self, key)
	self._t = (rawget(self, '_t') or m.config.color)[key]
	if getn(self._t) == 0 then
		return self
	end
	local color = aux.util.copy(self._t)
	self._t = nil
	tinsert(color, 1, tremove(color))
	return format('|c%02X%02X%02X%02X', unpack(color))
end)

function m.LOAD()

	aux.hook('ToggleDropDownMenu', function(...)
		local ret = {aux.orig.ToggleDropDownMenu(unpack(arg))}
		local dropdown = getglobal(arg[4] or '') or this:GetParent()
		if strfind(dropdown:GetName() or '', 'aux_frame') then
			m.set_content_style(DropDownList1Backdrop)
			DropDownList1:SetWidth(dropdown:GetWidth() * 0.9)
			DropDownList1:SetHeight(DropDownList1:GetHeight() - 8)
			DropDownList1:SetPoint('TOPLEFT', dropdown, 'BOTTOMLEFT', -2, 0)
			for i=1,UIDROPDOWNMENU_MAXBUTTONS do
				local button = getglobal('DropDownList1Button'..i)
				button:SetPoint('TOPLEFT', 0, -((button:GetID() - 1) * UIDROPDOWNMENU_BUTTON_HEIGHT) - 8)
				button:SetWidth(dropdown:GetWidth() - 30)
				local text = button:GetFontString()
				text:SetFont(m.config.font, m.config.medium_font_size)
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
			while getn(arg) < 4 do
				tinsert(arg, nil)
			end
			tinsert(arg, 0)
			tinsert(arg, 10)

		end
		return unpack(ret)
	end)

end

function public.set_frame_style(frame, backdrop_color, border_color)
	frame:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=m.config.edge_size, tile=true}
	frame:SetBackdropColor(unpack(backdrop_color))
	frame:SetBackdropBorderColor(unpack(border_color))
end

function public.set_window_style(frame)
    m.set_frame_style(frame, m.color.window.backdrop, m.color.window.border)
end

function public.set_panel_style(frame)
    m.set_frame_style(frame, m.color.panel.backdrop, m.color.panel.border)
end

function public.set_content_style(frame)
    m.set_frame_style(frame, m.color.content.backdrop, m.color.content.border)
end

function public.panel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    m.set_panel_style(panel)
    return panel
end

function public.checkbutton(parent, text_height)
    local button = m.button(parent, text_height)
    button.state = false
    button:SetBackdropColor(unpack(m.color.state.disabled))
    function button:SetChecked(state)
        if state then
            self:SetBackdropColor(unpack(m.color.state.enabled))
            self.state = true
        else
            self:SetBackdropColor(unpack(m.color.state.disabled))
            self.state = false
        end
    end
    function button:GetChecked()
        return self.state
    end
    return button
end

function public.button(parent, text_height)
    text_height = text_height or m.config.medium_font_size
    local button = CreateFrame('Button', nil, parent)
    m.set_content_style(button)
    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetAllPoints()
    highlight:SetTexture(1, 1, 1, .2)
    highlight:SetBlendMode('BLEND')
    button.highlight = highlight
    do
        local label = button:CreateFontString()
        label:SetFont(m.config.font, text_height)
        label:SetPoint('CENTER', 0, 0)
        label:SetJustifyH('CENTER')
        label:SetJustifyV('CENTER')
        label:SetHeight(text_height)
        label:SetTextColor(unpack(m.color.text.enabled))
        button:SetFontString(label)
    end
    button.default_Enable = button.Enable
    function button:Enable()
        self:GetFontString():SetTextColor(unpack(m.color.text.enabled))
        return self:default_Enable()
    end
    button.default_Disable = button.Disable
    function button:Disable()
        self:GetFontString():SetTextColor(unpack(m.color.text.disabled))
        return self:default_Disable()
    end

    return button
end


function public.resize_tab(tab, width, padding)
    tab:SetWidth(width + padding + 10)
end

function public.update_tab(tab)

end

do
    local id = 0
    function public.tab_group(parent, orientation)
        id = id + 1

        local frame = CreateFrame('Frame', nil, parent)
        frame:SetHeight(100)
        frame:SetWidth(100)

        local self = {
            id = id,
            frame = parent,
            tabs = {},
        }

        function self:create_tab(text)
            local id = getn(self.tabs) + 1

            local tab = CreateFrame('Button', 'aux_tab_group'..self.id..'_tab'..id, self.frame)
            tab.id = id
            tab.group = self
            tab:SetHeight(24)
            tab:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=m.config.edge_size}
            tab:SetBackdropBorderColor(unpack(m.color.panel.border))
            local dock = tab:CreateTexture(nil, 'OVERLAY')
            dock:SetHeight(3)
            if orientation == 'UP' then
                dock:SetPoint('BOTTOMLEFT', 1, -1)
                dock:SetPoint('BOTTOMRIGHT', -1, -1)
            elseif orientation == 'DOWN' then
                dock:SetPoint('TOPLEFT', 1, 1)
                dock:SetPoint('TOPRIGHT', -1, 1)
            end
            dock:SetTexture(unpack(m.color.panel.backdrop))
            tab.dock = dock
            local highlight = tab:CreateTexture(nil, 'HIGHLIGHT')
            highlight:SetAllPoints()
            highlight:SetTexture(1, 1, 1, .2)
            highlight:SetBlendMode('BLEND')
            tab.highlight = highlight

            tab.text = tab:CreateFontString()
            tab.text:SetPoint('LEFT', 3, -1)
            tab.text:SetPoint('RIGHT', -3, -1)
            tab.text:SetJustifyH('CENTER')
            tab.text:SetJustifyV('CENTER')
            tab.text:SetFont(m.config.font, m.config.large_font_size)
            tab:SetFontString(tab.text)

            tab:SetText(text)

            tab:SetScript('OnClick', function()
                if this.id ~= this.group.selected then
--                    PlaySound('igCharacterInfoTab')
                    this.group:set_tab(this.id)
                end
            end)

            if getn(self.tabs) == 0 then
                if orientation == 'UP' then
                    tab:SetPoint('BOTTOMLEFT', self.frame, 'TOPLEFT', 4, -1)
                elseif orientation == 'DOWN' then
                    tab:SetPoint('TOPLEFT', self.frame, 'BOTTOMLEFT', 4, 1)
                end
            else
                if orientation == 'UP' then
                    tab:SetPoint('BOTTOMLEFT', self.tabs[getn(self.tabs)], 'BOTTOMRIGHT', 4, 0)
                elseif orientation == 'DOWN' then
                    tab:SetPoint('TOPLEFT', self.tabs[getn(self.tabs)], 'TOPRIGHT', 4, 0)
                end
            end

            m.resize_tab(tab, tab:GetFontString():GetStringWidth(), 4)

            tinsert(self.tabs, tab)
        end

        function self:set_tab(id)
            self.selected = id
            self.update_tabs()
            aux.call(self.on_select, id)
        end

        function self.update_tabs()
            for _, tab in self.tabs do
                if tab.group.selected == tab.id then
                    tab.text:SetTextColor(unpack(m.color.label.enabled))
                    tab:Disable()
                    tab:SetBackdropColor(unpack(m.color.panel.backdrop))
                    tab.dock:Show()
                    tab:SetHeight(29)
                else
                    tab.text:SetTextColor(unpack(m.color.text.enabled))
                    tab:Enable()
                    tab:SetBackdropColor(unpack(m.color.content.backdrop))
                    tab.dock:Hide()
                    tab:SetHeight(24)
                end
            end
        end

        return self
    end
end

function public.editbox(parent)

    local editbox = CreateFrame('EditBox', nil, parent)
    editbox:SetAutoFocus(false)
    editbox:SetTextInsets(0, 0, 3, 3)
    editbox:SetMaxLetters(256)
    editbox:SetHeight(19)
    editbox:SetFont(m.config.font, m.config.medium_font_size)
    editbox:SetShadowColor(0, 0, 0, 0)
    m.set_content_style(editbox)
    editbox:SetScript('OnEditFocusGained', aux._(editbox.HighlightText, editbox))
    editbox:SetScript('OnEditFocusLost', aux._(editbox.HighlightText, editbox, 0, 0))
    editbox:SetScript('OnEscapePressed', aux._(editbox.ClearFocus, editbox))
    do
        local last_time, last_x, last_y
        editbox:SetScript('OnMouseUp', function()
            local x, y = GetCursorPosition()
            if last_time and GetTime() - last_time < .5 and x == last_x and y == last_y then
	            last_time = nil
                this:HighlightText()
            else
                last_time = GetTime()
                last_x, last_y = x, y
            end
        end)
    end

    return editbox
end

function public.status_bar(parent)
    local self = CreateFrame('Frame', nil, parent)

    local level = parent:GetFrameLevel()

    self:SetFrameLevel(level + 1)

    do
        -- minor status bar (gray one)
        local status_bar = CreateFrame('STATUSBAR', nil, self, 'TextStatusBar')
        status_bar:SetOrientation('HORIZONTAL')
        status_bar:SetMinMaxValues(0, 100)
        status_bar:SetAllPoints()
        status_bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
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
        status_bar:SetOrientation('HORIZONTAL')
        status_bar:SetMinMaxValues(0, 100)
        status_bar:SetAllPoints()
        status_bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
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
        local text = m.label(text_frame)
        text:SetTextColor(unpack(m.color.text.enabled))
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
    local item = CreateFrame('Button', nil, parent)
    item:SetWidth(193)
    item:SetHeight(40)
    local icon = CreateFrame('CheckButton', 'aux_frame'..aux.id(), item, 'ActionButtonTemplate')
    icon:SetPoint('LEFT', 2, 0.5)
    icon:SetHighlightTexture(nil)
    icon:RegisterForClicks()
    icon:EnableMouse(nil)
    item.texture = getglobal(icon:GetName()..'Icon')
    item.texture:SetTexCoord(0.06,0.94,0.06,0.94)
    item.name = aux.gui.label(icon)
    item.name:SetJustifyH('LEFT')
    item.name:SetPoint('LEFT', icon, 'RIGHT', 10, 0)
    item.name:SetPoint('RIGHT', item, 'RIGHT', -10, 0.5)
    item.name:SetPoint('TOP', item, 'TOP', -5, 0)
    item.name:SetPoint('BOTTOM', item, 'BOTTOM', 5, 0)
    item.count = getglobal(icon:GetName()..'Count')
    return item
end

function public.label(parent, size)
    local label = parent:CreateFontString()
    label:SetFont(m.config.font, size or m.config.medium_font_size)
    label:SetTextColor(unpack(m.color.label.enabled))
    return label
end

function public.horizontal_line(parent, y_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, y_offset)
    texture:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -2, y_offset)
    texture:SetHeight(2)
    if inverted_color then
        texture:SetTexture(unpack(m.color.panel.backdrop))
    else
        texture:SetTexture(unpack(m.color.content.backdrop))
    end
    return texture
end

function public.vertical_line(parent, x_offset, top_offset, bottom_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', x_offset, top_offset or -2)
    texture:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', x_offset, bottom_offset or 2)
    texture:SetWidth(2)
    if inverted_color then
        texture:SetTexture(unpack(m.color.panel.backdrop))
    else
        texture:SetTexture(unpack(m.color.content.backdrop))
    end
    return texture
end


function public.dropdown(parent)
    local dropdown = CreateFrame('Frame', 'aux_frame'..aux.id(), parent, 'UIDropDownMenuTemplate')

    dropdown:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=m.config.edge_size, insets={top=5,bottom=5}}
    dropdown:SetBackdropColor(unpack(m.color.content.backdrop))
    dropdown:SetBackdropBorderColor(unpack(m.color.content.border))
    local left = getglobal(dropdown:GetName()..'Left'):Hide()
    local middle = getglobal(dropdown:GetName()..'Middle'):Hide()
    local right = getglobal(dropdown:GetName()..'Right'):Hide()

    local button = getglobal(dropdown:GetName()..'Button')
    button:ClearAllPoints()
    button:SetPoint('RIGHT', dropdown, 0, 0)

    local text = getglobal(dropdown:GetName()..'Text')
    text:ClearAllPoints()
    text:SetPoint('RIGHT', button, 'LEFT', -2, 0)
    text:SetPoint('LEFT', dropdown, 'LEFT', 8, 0)
    text:SetFont(m.config.font, m.config.medium_font_size)
    text:SetShadowColor(0, 0, 0, 0)

--
--    dropdown:ClearAllPoints()
--    dropdown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 0)
--    dropdown:SetScript("OnHide", nil)
--    dropdown:SetScript("OnEnter", Control_OnEnter)
--    dropdown:SetScript("OnLeave", Control_OnLeave)
--    dropdown:SetScript("OnMouseUp", function(self, button) Dropdown_TogglePullout(self.obj.button, button) end)
--    TSMAPI.Design:SetContentColor(dropdown)
--
--    middle:ClearAllPoints()
--    right:ClearAllPoints()
--
--    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
--    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
--    right:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 17)
--
--    local button = _G[dropdown:GetName().."Button"]
--    button:RegisterForClicks("AnyUp")
--    button:SetScript("OnEnter", Control_OnEnter)
--    button:SetScript("OnLeave", Control_OnLeave)
--    button:SetScript("OnClick", Dropdown_TogglePullout)
--    button:ClearAllPoints()
--    button:SetPoint("RIGHT", dropdown, 0, 0)

    return dropdown
end

function public.slider(parent)

    local slider = CreateFrame('Slider', nil, parent)
    slider:SetOrientation('HORIZONTAL')
    slider:SetHeight(6)
    slider:SetHitRectInsets(0, 0, -8, -8)
    slider:SetValue(0)
    m.set_panel_style(slider)
    local thumb_texture = slider:CreateTexture(nil, 'ARTWORK')
    thumb_texture:SetPoint('CENTER', 0, 0)
    thumb_texture:SetTexture(unpack(m.color.content.backdrop))
    thumb_texture:SetHeight(15)
    thumb_texture:SetWidth(8)
    slider:SetThumbTexture(thumb_texture)

    local label = slider:CreateFontString(nil, 'OVERLAY')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT', -3, 6)
    label:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT', 6, 6)
    label:SetJustifyH('LEFT')
    label:SetHeight(13)
    label:SetFont(m.config.font, m.config.small_font_size)
    label:SetTextColor(unpack(m.color.label.enabled))

    local editbox = m.editbox(slider)
    editbox:SetPoint('LEFT', slider, 'RIGHT', 5, 0)
    editbox:SetWidth(50)
    editbox:SetJustifyH('CENTER')

    slider.label = label
    slider.editbox = editbox
    return slider
end

function public.checkbox(parent)
    local checkbox = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
    checkbox:SetWidth(16)
    checkbox:SetHeight(16)
	m.set_content_style(checkbox)
    checkbox:SetNormalTexture(nil)
    checkbox:SetPushedTexture(nil)
    checkbox:GetHighlightTexture():SetAllPoints()
    checkbox:GetHighlightTexture():SetTexture(1, 1, 1, .2)
    checkbox:GetCheckedTexture():SetTexCoord(.12, .88, .12, .88)
    checkbox:GetHighlightTexture('BLEND')
    return checkbox
end