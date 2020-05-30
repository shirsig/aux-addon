select(2, ...) 'aux.gui'

local aux = require 'aux'
local completion = require 'aux.util.completion'

M.font = (function()
    local font = CreateFrame'Frame':CreateFontString()
    font:SetFontObject(NumberFont_Normal_Med)
    return font:GetFont()
end)()

M.font_size = aux.immutable-{
	small = 13,
	medium = 15,
	large = 18,
}

do
	local id = 1
	function M.unique_name()
		id = id + 1
		return 'aux.frame' .. id
	end
end

function M.set_size(frame, width, height)
	frame:SetWidth(width)
	frame:SetHeight(height or width)
end

function M.set_frame_style(frame, backdrop_color, border_color, left, right, top, bottom)
	frame:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=1.5, tile=true, insets={left=left, right=right, top=top, bottom=bottom}}
	frame:SetBackdropColor(backdrop_color())
	frame:SetBackdropBorderColor(border_color())
end

function M.set_window_style(frame, left, right, top, bottom)
    set_frame_style(frame, aux.color.window.background, aux.color.window.border, left, right, top, bottom)
end

function M.set_panel_style(frame, left, right, top, bottom)
    set_frame_style(frame, aux.color.panel.background, aux.color.panel.border, left, right, top, bottom)
end

function M.set_content_style(frame, left, right, top, bottom)
    set_frame_style(frame, aux.color.content.background, aux.color.content.border, left, right, top, bottom)
end

function M.panel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    set_panel_style(panel)
    return panel
end

function M.checkbutton(parent, text_height)
    local button = button(parent, text_height)
    button.state = false
    button:SetBackdropColor(aux.color.state.disabled())
    function button:SetChecked(state)
        if state then
            self:SetBackdropColor(aux.color.state.enabled())
            self.state = true
        else
            self:SetBackdropColor(aux.color.state.disabled())
            self.state = false
        end
    end
    function button:GetChecked()
        return self.state
    end
    return button
end

function M.button(parent, text_height)
    text_height = text_height or font_size.large
    local button = CreateFrame('Button', nil, parent)
    set_size(button, 80, 24)
    set_content_style(button)
    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, .2)
    button.highlight = highlight
    do
        local label = button:CreateFontString()
        label:SetFont(font, text_height)
        label:SetAllPoints(button)
        label:SetJustifyH('CENTER')
        label:SetJustifyV('CENTER')
        label:SetTextColor(aux.color.text.enabled())
        button:SetFontString(label)
    end
    button.default_Enable = button.Enable
    function button:Enable()
	    if self:IsEnabled() == 1 then return end
        self:GetFontString():SetTextColor(aux.color.text.enabled())
        return self:default_Enable()
    end
    button.default_Disable = button.Disable
    function button:Disable()
	    if self:IsEnabled() == 0 then return end
        self:GetFontString():SetTextColor(aux.color.text.disabled())
        return self:default_Disable()
    end

    return button
end

do
	local mt = {__index={}}
	function mt.__index:create_tab(text)
		local id = #self._tabs + 1

		local tab = CreateFrame('Button', unique_name(), self._frame)
		tab.id = id
		tab.group = self
		tab:SetHeight(24)
		set_panel_style(tab)
		local dock = tab:CreateTexture(nil, 'OVERLAY')
		dock:SetHeight(3)
		if self._orientation == 'UP' then
			dock:SetPoint('BOTTOMLEFT', 1, -1)
			dock:SetPoint('BOTTOMRIGHT', -1, -1)
		elseif self._orientation == 'DOWN' then
			dock:SetPoint('TOPLEFT', 1, 1)
			dock:SetPoint('TOPRIGHT', -1, 1)
		end
		dock:SetColorTexture(aux.color.panel.background())
		tab.dock = dock
		local highlight = tab:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, .2)
		tab.highlight = highlight

		tab.text = tab:CreateFontString()
		tab.text:SetAllPoints()
		tab.text:SetJustifyH('CENTER')
		tab.text:SetJustifyV('CENTER')
		tab.text:SetFont(font, font_size.large)
		tab:SetFontString(tab.text)

		tab:SetText(text)

		tab:SetScript('OnClick', function(self)
			if self.id ~= self.group.selected then
				PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                self.group:select(self.id)
			end
		end)

		if #self._tabs == 0 then
			if self._orientation == 'UP' then
				tab:SetPoint('BOTTOMLEFT', self._frame, 'TOPLEFT', 4, -1)
			elseif self._orientation == 'DOWN' then
				tab:SetPoint('TOPLEFT', self._frame, 'BOTTOMLEFT', 4, 1)
			end
		else
			if self._orientation == 'UP' then
				tab:SetPoint('BOTTOMLEFT', self._tabs[#self._tabs], 'BOTTOMRIGHT', 4, 0)
			elseif self._orientation == 'DOWN' then
				tab:SetPoint('TOPLEFT', self._tabs[#self._tabs], 'TOPRIGHT', 4, 0)
			end
		end

		tab:SetWidth(tab:GetFontString():GetStringWidth() + 14)

		tinsert(self._tabs, tab)
	end
	function mt.__index:select(id)
		self._selected = id
		self:update()
		do (self._on_select or pass)(id) end
	end
	function mt.__index:update()
		for _, tab in pairs(self._tabs) do
			if tab.group._selected == tab.id then
				tab.text:SetTextColor(aux.color.label.enabled())
				tab:Disable()
				tab:SetBackdropColor(aux.color.panel.background())
				tab.dock:Show()
				tab:SetHeight(29)
			else
				tab.text:SetTextColor(aux.color.text.enabled())
				tab:Enable()
				tab:SetBackdropColor(aux.color.content.background())
				tab.dock:Hide()
				tab:SetHeight(24)
			end
		end
	end
	function M.tabs(parent, orientation)
		local self = {
			_frame = parent,
			_orientation = orientation,
			_tabs = {},
		}
	    return setmetatable(self, mt)
	end
end

function M.editbox(parent)
    local editbox = CreateFrame('EditBox', nil, parent)
    editbox:SetAutoFocus(false)
    editbox:SetTextInsets(1.5, 1.5, 3, 3)
    editbox:SetMaxLetters(nil)
    editbox:SetHeight(24)
    editbox:SetTextColor(0, 0, 0, 0)
    set_content_style(editbox)
    editbox:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
	    do (self.escape or pass)(self) end
    end)
    editbox:SetScript('OnEnterPressed', function(self) (self.enter or pass)(self) end)
    editbox:SetScript('OnEditFocusGained', function(self)
	    if self.block_focus then
            self.block_focus = false
            self:ClearFocus()
		    return
	    end
        self.overlay:Hide()
        self:SetTextColor(aux.color.text.enabled())
        self.focused = true
        self:HighlightText()
	    do (self.focus_gain or pass)(self) end
    end)
    editbox:SetScript('OnEditFocusLost', function(self)
        self.overlay:Show()
        self:SetTextColor(0, 0, 0, 0)
        self.focused = false
        self:HighlightText(0, 0)
        self:SetScript('OnUpdate', nil)
	    do (self.focus_loss or pass)(self) end
    end)
    editbox:SetScript('OnTextChanged', function(self, is_user_input)
	    do (self.change or pass)(self, is_user_input) end
        self.overlay:SetText(self.formatter and self.formatter(self:GetText()) or self:GetText())
    end)
    editbox:SetScript('OnChar', function(self) (self.char or pass)(self) end)
    do
        local last_click = { t = 0 }
        editbox:SetScript('OnMouseDown', function(self, button)
	        if button == 'RightButton' then
                self:SetText(self.reset_text or '')
                self:ClearFocus()
                self.block_focus = true
	        else
	            local x, y = GetCursorPosition()
	            -- local offset = x - editbox:GetLeft()*editbox:GetEffectiveScale() TODO use a fontstring to measure getstringwidth for structural highlighting
	            -- or use an overlay with itemlinks
	            if GetTime() - last_click.t < .5 and x == last_click.x and y == last_click.y then
	                aux.coro_thread(function()
                        aux.coro_wait()
                        editbox:HighlightText()
                    end)
	            end
                aux.wipe(last_click)
	            last_click.t = GetTime()
	            last_click.x = x
	            last_click.y = y
	        end
        end)
    end
    function editbox:SetAlignment(alignment)
	    self:SetJustifyH(alignment)
	    self.overlay:SetJustifyH(alignment)
    end
    function editbox:SetFontSize(size)
	    self:SetFont(font, size)
	    self.overlay:SetFont(font, size)
    end
    local overlay = label(editbox)
    overlay:SetPoint('LEFT', 1.5, 0)
    overlay:SetPoint('RIGHT', -1.5, 0)
    overlay:SetTextColor(aux.color.text.enabled())
    editbox.overlay = overlay
    editbox:SetAlignment('LEFT')
    editbox:SetFontSize(font_size.medium)
    return editbox
end

do
	local function update_alpha(self)
		self:SetAlpha(1 - (sin(GetTime() * 180) + 1) / 4)
    end

	function M.status_bar(parent)
	    local self = CreateFrame('Frame', nil, parent)
        set_window_style(self)
	    do
	        local status_bar = CreateFrame('StatusBar', nil, self, 'TextStatusBar')
	        status_bar:SetOrientation('HORIZONTAL')
	        status_bar:SetMinMaxValues(0, 1)
	        status_bar:SetPoint('TOPLEFT', 1.5, -1.5)
            status_bar:SetPoint('BOTTOMRIGHT', -1.5, 1.5)
            status_bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	        status_bar:SetStatusBarColor(.42, .42, .42, .7)
	        self.secondary_status_bar = status_bar
	    end
	    do
	        local status_bar = CreateFrame('StatusBar', nil, self.secondary_status_bar, 'TextStatusBar')
	        status_bar:SetOrientation('HORIZONTAL')
	        status_bar:SetMinMaxValues(0, 1)
	        status_bar:SetAllPoints()
	        status_bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	        status_bar:SetStatusBarColor(.19, .22, .33, .9)
	        self.primary_status_bar = status_bar
	    end
	    function self:update_status(primary_status, secondary_status)
            if min(primary_status or 0, secondary_status or 0) < 1 then
                self:SetScript('OnUpdate', update_alpha)
            else
                self:SetScript('OnUpdate', nil)
                self:SetAlpha(1)
            end
	        if primary_status then
	            self.primary_status_bar:SetValue(primary_status)
	        end
	        if secondary_status then
	            self.secondary_status_bar:SetValue(secondary_status)
	        end
	    end
	    return self
	end
end

function M.item(parent)
    local item = CreateFrame('Frame', nil, parent)
    set_size(item, 260, 40)
    local btn = CreateFrame('CheckButton', unique_name(), item, 'ActionButtonTemplate')
    item.button = btn
    btn:SetPoint('LEFT', 2, .5)
    btn:SetHighlightTexture(nil)
    btn:RegisterForClicks()
    item.texture = _G[btn:GetName() .. 'Icon']
    item.texture:SetTexCoord(.06, .94, .06, .94)
    item.name = label(btn, font_size.medium)
    item.name:SetJustifyH('LEFT')
    item.name:SetPoint('LEFT', btn, 'RIGHT', 10, 0)
    item.name:SetPoint('RIGHT', item, 'RIGHT', -10, .5)
    item.count = _G[btn:GetName() .. 'Count']
    item.count:SetTextHeight(17)
    return item
end

function M.label(parent, size)
    local label = parent:CreateFontString()
    label:SetFont(font, size or font_size.small)
    label:SetTextColor(aux.color.label.enabled())
    label:SetWordWrap(false)
    return label
end

function M.horizontal_line(parent, y_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, y_offset)
    texture:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -2, y_offset)
    texture:SetHeight(2)
    if inverted_color then
        texture:SetColorTexture(aux.color.panel.background())
    else
        texture:SetColorTexture(aux.color.content.background())
    end
    return texture
end

function M.vertical_line(parent, x_offset, top_offset, bottom_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', x_offset, top_offset or -2)
    texture:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', x_offset, bottom_offset or 2)
    texture:SetWidth(2)
    if inverted_color then
        texture:SetColorTexture(aux.color.panel.background())
    else
        texture:SetColorTexture(aux.color.content.background())
    end
    return texture
end

do
    local dropdown_frame = panel()
    dropdown_frame:SetFrameStrata('FULLSCREEN_DIALOG')
    dropdown_frame:SetHeight(1)
    local dropdown_item_buttons = {}

    function M.dropdown(parent, text_height)
        text_height = text_height or font_size.medium

        local index, set_index, update_dropdown
        local options = {}

        local editbox = editbox(parent)

        editbox.complete = completion.complete(function() return options end)

        function editbox:char()
            self:complete()
            for i, choice in pairs(options) do
                if editbox:GetText() == choice then
                    set_index(i)
                end
            end
        end

        function set_index(new_index)
            if new_index then
                new_index = max(1, min(#options, new_index))
                if editbox:GetText() ~= options[new_index] then
                    editbox:SetText(options[new_index])
                end
            else
                editbox:SetText('')
            end
            if new_index ~= index then
                index = new_index
                do (editbox.selection_change or pass)() end
            end
        end

        local function update_dropdown()
            if #options == 0 then
                dropdown_frame:Hide()
                return
            end

            dropdown_frame:SetScale(editbox:GetEffectiveScale())
            dropdown_frame:ClearAllPoints()
            local width = editbox:GetWidth() + 4
            dropdown_frame:SetWidth(width)
            dropdown_frame:SetPoint('TOP', editbox, 'BOTTOM', 0, 0)
            for i = 1, max(#options, #dropdown_item_buttons) do
                local item_button = dropdown_item_buttons[i]
                if not item_button then
                    item_button = button(dropdown_frame, text_height)
                    item_button:GetFontString():SetJustifyH('LEFT')
                    dropdown_item_buttons[i] = item_button
                end
                if i > #options then
                    item_button:Hide()
                else
                    item_button:ClearAllPoints()
                    item_button:SetWidth(width - 4)
                    item_button:SetText(' ' .. options[i])
                    if i == 1 then
                        item_button:SetPoint('TOP', editbox, 'BOTTOM', 0, -2)
                    else
                        item_button:SetPoint('TOP', dropdown_item_buttons[i - 1], 'BOTTOM', 0, -2)
                    end
                    item_button:SetScript('OnClick', function()
                        set_index(i)
                        editbox:ClearFocus()
                    end)
                    if index == i then
                        item_button:LockHighlight()
                    else
                        item_button:UnlockHighlight()
                    end
                    item_button:Show()
                end
                if i == #options then
                    dropdown_frame:SetPoint('BOTTOM', item_button, 'BOTTOM', 0, -2)
                end
                dropdown_frame:Show()
            end
        end

        editbox.focus_gain = function()
            update_dropdown()
        end

        editbox.focus_loss = function()
            set_index(index)
            dropdown_frame:Hide()
        end

        function editbox:SetOptions(new_options)
            options = new_options
            set_index(nil)
            if editbox:HasFocus() then
                update_dropdown()
            end
        end

        function editbox:GetIndex()
            return index
        end

        function editbox:SetIndex(new_index)
            set_index(new_index)
        end

        return editbox
    end
end

function M.slider(parent)

    local slider = CreateFrame('Slider', nil, parent)
    slider:SetOrientation('HORIZONTAL')
    slider:SetHeight(6)
    slider:SetHitRectInsets(0, 0, -12, -12)
    slider:SetStepsPerPage(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(0)

    set_panel_style(slider)
    local thumb_texture = slider:CreateTexture(nil, 'ARTWORK')
    thumb_texture:SetPoint('CENTER', 0, 0)
    thumb_texture:SetColorTexture(aux.color.content.background())
    thumb_texture:SetHeight(18)
    thumb_texture:SetWidth(8)
    set_size(thumb_texture, 8, 18)
    slider:SetThumbTexture(thumb_texture)

    local label = slider:CreateFontString(nil, 'OVERLAY')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT', -3, 8)
    label:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT', 6, 8)
    label:SetJustifyH('LEFT')
    label:SetHeight(13)
    label:SetFont(font, font_size.small)
    label:SetTextColor(aux.color.label.enabled())

    local editbox = editbox(slider)
    editbox:SetPoint('LEFT', slider, 'RIGHT', 5, 0)
    set_size(editbox, 45, 18)
    editbox:SetAlignment('CENTER')
    editbox:SetFontSize(17)

    slider.label = label
    slider.editbox = editbox
    return slider
end

function M.checkbox(parent)
    local checkbox = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
    checkbox:SetWidth(16)
    checkbox:SetHeight(16)
	set_content_style(checkbox)
    checkbox:SetNormalTexture(nil)
    checkbox:SetPushedTexture(nil)
    checkbox:GetHighlightTexture():SetAllPoints()
    checkbox:GetHighlightTexture():SetColorTexture(1, 1, 1, .2)
    checkbox:GetCheckedTexture():SetTexCoord(.12, .88, .12, .88)
    checkbox:GetHighlightTexture('BLEND')
    return checkbox
end

do
	local editbox = CreateFrame('EditBox')
	editbox:SetAutoFocus(false)
	function M.clear_focus()
		editbox:SetFocus()
		editbox:ClearFocus()
	end
end

function M.percentage_historical(pct, bid)
	local text = (pct > 10000 and '>10000' or pct) .. '%'
	if bid then
		return aux.color.gray(text)
	elseif pct < 50 then
		return aux.color.blue(text)
	elseif pct < 80 then
		return aux.color.green(text)
	elseif pct < 110 then
		return aux.color.yellow(text)
	elseif pct < 135 then
		return aux.color.orange(text)
	else
		return aux.color.red(text)
	end
end