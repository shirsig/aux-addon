local m, public, private = Aux.module'gui'

--TSM.designDefaults = {
--    frameColors = {
--        frameBG = { backdrop = { 24, 24, 24, .93 }, border = { 30, 30, 30, 1 } },
--        frame = { backdrop = { 24, 24, 24, 1 }, border = { 255, 255, 255, 0.03 } },
--        content = { backdrop = { 42, 42, 42, 1 }, border = { 0, 0, 0, 0 } },
--    },
--    textColors = {
--        iconRegion = { enabled = { 249, 255, 247, 1 } },
--        text = { enabled = { 255, 254, 250, 1 }, disabled = { 147, 151, 139, 1 } },
--        label = { enabled = { 216, 225, 211, 1 }, disabled = { 150, 148, 140, 1 } },
--        title = { enabled = { 132, 219, 9, 1 } },
--        link = { enabled = { 49, 56, 133, 1 } },
--    },
--    inlineColors = {
--        link = { 153, 255, 255, 1 },
--        link2 = { 153, 255, 255, 1 },
--        category = { 36, 106, 36, 1 },
--        category2 = { 85, 180, 8, 1 },
--        tooltip = { 130, 130, 250, 1 },
--    },
--    edgeSize = 1.5,
--    fonts = {
--        content = "Fonts\\ARIALN.TTF",
--        bold = "Interface\\Addons\\TradeSkillMaster\\Media\\DroidSans-Bold.ttf",
--    },
--    fontSizes = {
--        normal = 15,
--        medium = 13,
--        small = 12,
--    },
--}

public.config = {
    link_color = { 153, 255, 255, 1 },
    link_color2 = { 153, 255, 255, 1 }, -- TODO inline color needs 255, others need /255
    edge_size = 1.5,
    frame_color = {24/255, 24/255, 24/255, 1},
    frame_border_color = {1, 1, 1, .03},
    content_color = {42/255, 42/255, 42/255, 1},
    content_border_color = {0, 0, 0, 0},
    content_font = [[Fonts\ARIALN.TTF]],
--    content_font = [[Interface\AddOns\Aux-Addon\ARIALN.TTF]],
    normal_font_size = 15,
    normal_button_font_size = 16, -- 15 not working for some clients
    text_color = { enabled = { 255/255, 254/255, 250/255, 1 }, disabled = { 147/255, 151/255, 139/255, 1 } },
    label_color = { enabled = { 216/255, 225/255, 211/255, 1 }, disabled = { 150/255, 148/255, 140/255, 1 } },

}

function public.inline_color(color)
    local r, g, b, a = unpack(color)
    return format("|c%02X%02X%02X%02X", a, r, g, b)
end

function public.panel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    panel:SetBackdrop{bgFile='Interface\\Buttons\\WHITE8X8'}
    panel:SetBackdropColor(unpack(m.config.content_color))
    return panel
end

function public.button(parent, text_height, name)
    local button = CreateFrame('Button', name, parent)
    button:SetBackdrop{bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size}
    button:SetBackdropColor(unpack(m.config.content_color))
    button:SetBackdropBorderColor(unpack(m.config.content_border_color))
    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetAllPoints()
    highlight:SetTexture(1, 1, 1, .2)
    highlight:SetBlendMode('BLEND')
    button.highlight = highlight
    do
        local label = button:CreateFontString()
        label:SetFont(m.config.content_font, text_height)
        label:SetPoint('CENTER', 0, 0)
        label:SetJustifyH('CENTER')
        label:SetJustifyV('CENTER')
        label:SetHeight(text_height)
        label:SetTextColor(unpack(m.config.text_color.enabled))
        button:SetFontString(label)
    end
    button.default_Enable = button.Enable
    function button:Enable()
        self:GetFontString():SetTextColor(unpack(m.config.text_color.enabled))
        return self:default_Enable()
    end
    button.default_Disable = button.Disable
    function button:Disable()
        self:GetFontString():SetTextColor(unpack(m.config.text_color.disabled))
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
    function public.tab_group(parent, position)
        id = id + 1

        local frame = CreateFrame('Frame', nil, parent)
        frame:SetHeight(100)
        frame:SetWidth(100)

        local self = {
            id = id,
            frame = parent,
            tabs = {},
            on_select = function() end,
        }

        function self:create_tab(text)
            local id = getn(self.tabs) + 1

            local tab = CreateFrame('Button', 'aux_tab_group'..self.id..'_tab'..id, self.frame)
            tab.id = id
            tab.group = self
            tab:SetHeight(24)
            tab:SetBackdrop{bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size}
            tab:SetBackdropColor(0, 0, 0, 0)
            tab:SetBackdropBorderColor(unpack(m.config.frame_border_color))
            local image = tab:CreateTexture(nil, 'BACKGROUND')
            image:SetAllPoints()
            image:SetTexture(unpack(m.config.content_color))
            tab.image = image
            local dock = tab:CreateTexture(nil, 'OVERLAY')
            dock:SetHeight(3)
            if position == 'TOP' then
                dock:SetPoint('BOTTOMLEFT', 1, -1)
                dock:SetPoint('BOTTOMRIGHT', -1, -1)
            else
                dock:SetPoint('TOPLEFT', 1, 1)
                dock:SetPoint('TOPRIGHT', -1, 1)
            end
            dock:SetTexture(unpack(m.config.frame_color))
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
            tab.text:SetFont(m.config.content_font, 18)
            tab:SetFontString(tab.text)

            tab:SetText(text)

            tab:SetScript('OnClick', function()
                if this.id ~= this.group.selected then
--                    PlaySound('igCharacterInfoTab')
                    this.group:set_tab(this.id)
                end
            end)

            if getn(self.tabs) == 0 then
                if position == 'TOP' then
                    tab:SetPoint('BOTTOMLEFT', self.frame, 'TOPLEFT', 4, -1)
                else
                    tab:SetPoint('TOPLEFT', self.frame, 'BOTTOMLEFT', 4, 1)
                end
            else
                if position == 'TOP' then
                    tab:SetPoint('BOTTOMLEFT', self.tabs[getn(self.tabs)], 'BOTTOMRIGHT', 4, 0)
                else
                    tab:SetPoint('TOPLEFT', self.tabs[getn(self.tabs)], 'TOPRIGHT', 4, 0)
                end
            end

            m.resize_tab(tab, tab:GetFontString():GetStringWidth(), 4)

            -- tab:Show()
            tinsert(self.tabs, tab)
        end

        function self:set_tab(id)
            self.selected = id
            self.update_tabs()
            self.on_select(id)
        end

        function self.update_tabs()
            for _, tab in ipairs(self.tabs) do
                if tab.group.selected == tab.id then
--                    TSMAPI.Design:SetWidgetLabelColor(tab.text)
                    tab.text:SetTextColor(216/255, 225/255, 211/255) -- TODO
                    tab:Disable()
                    tab.image:SetTexture(unpack(m.config.frame_color))
                    tab.dock:Show()
                    tab:SetHeight(29)
                else
--                    TSMAPI.Design:SetWidgetTextColor(tab.text)
                    tab.text:SetTextColor(255/255, 254/255, 250/255) -- TODO
                    tab:Enable()
                    tab.image:SetTexture(unpack(m.config.content_color))
                    tab.dock:Hide()
                    tab:SetHeight(24)
                end
            end
        end

        return self
    end
end

function public.editbox(parent, name)

--        local frame = CreateFrame('Frame', name, parent)
--        frame:Hide()

    local editbox = CreateFrame('EditBox', name, parent)
    editbox:SetAutoFocus(false)
    editbox:SetTextInsets(0, 0, 3, 3)
    editbox:SetMaxLetters(256)
    editbox:SetHeight(19)
    editbox:SetFont(m.config.content_font, m.config.normal_font_size)
    editbox:SetShadowColor(0, 0, 0, 0)
    editbox:SetBackdrop{bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size}
    editbox:SetBackdropColor(unpack(m.config.content_color))
    editbox:SetBackdropBorderColor(unpack(m.config.content_border_color))

    editbox:SetScript('OnEditFocusLost', function()
        this:HighlightText(0, 0)
    end)

    editbox:SetScript('OnEscapePressed', function()
        this:ClearFocus()
    end)

    do
        local last_time, last_x, last_y

        editbox:SetScript('OnEditFocusGained', function()
            this:HighlightText()
        end)

        editbox:SetScript('OnMouseUp', function()
            local x, y = GetCursorPosition()
            if last_time and last_time > GetTime() - .5 and abs(x - last_x) < 10 and abs(y - last_y) < 10 then
                this:HighlightText()
                last_time = nil
            else
                last_time = GetTime()
                last_x, last_y = GetCursorPosition()
            end
        end)
    end

--        local label = frame:CreateFontString(nil, 'OVERLAY')
--        label:SetPoint('TOPLEFT', 0, -2)
--        label:SetPoint('TOPRIGHT', 0, -2)
--        label:SetJustifyH('LEFT')
--        label:SetJustifyV('CENTER')
--        label:SetHeight(18)
--        label:SetFont(m.config.content_font, m.config.normal_font_size)
--        label:SetShadowColor(0, 0, 0, 0)

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
        text:SetTextColor(unpack(m.config.text_color.enabled))
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

function public.label(parent, size)
    local label = parent:CreateFontString()
    label:SetFont(m.config.content_font, size or m.config.normal_font_size)
    label:SetTextColor(unpack(m.config.label_color.enabled))
    return label
end

function public.horizontal_line(parent, y_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, y_offset)
    texture:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -2, y_offset)
    texture:SetHeight(2)
    if inverted_color then
        texture:SetTexture(unpack(m.config.frame_color))
    else
        texture:SetTexture(unpack(m.config.content_color))
    end
    return texture
end

function public.vertical_line(parent, x_offset, top_offset, bottom_offset, inverted_color)
    local texture = parent:CreateTexture()
    texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', x_offset, top_offset or -2)
    texture:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', x_offset, bottom_offset or 2)
    texture:SetWidth(2)
    if inverted_color then
        texture:SetTexture(unpack(m.config.frame_color))
    else
        texture:SetTexture(unpack(m.config.content_color))
    end
    return texture
end

do
    local id = 0
    function public.dropdown(parent)
        id = id + 1

        local dropdown = CreateFrame('Frame', 'aux_dropdown'..id, parent, 'UIDropDownMenuTemplate')

        dropdown:SetBackdrop{bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size, insets={top=5,bottom=5}}
        dropdown:SetBackdropColor(unpack(m.config.content_color))
        dropdown:SetBackdropBorderColor(unpack(m.config.content_border_color))
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
        text:SetFont(m.config.content_font, 13)
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
    --    local left = _G[dropdown:GetName().."Left"]
    --    local middle = _G[dropdown:GetName().."Middle"]
    --    local right = _G[dropdown:GetName().."Right"]
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
    --
    --    local text = _G[dropdown:GetName().."Text"]
    --    text:ClearAllPoints()
    --    text:SetPoint("RIGHT", button, "LEFT", -2, 0)
    --    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    --    text:SetFont(TSMAPI.Design:GetContentFont("normal"))
    --    text:SetShadowColor(0, 0, 0, 0)
    --
    --    local label = frame:CreateFontString(nil, "OVERLAY")
    --    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    --    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    --    label:SetJustifyH("LEFT")
    --    label:SetHeight(18)
    --    label:SetFont(TSMAPI.Design:GetContentFont("small"))
    --    label:SetShadowColor(0, 0, 0, 0)
    --    label:Hide()
    --
    --    left:Hide()
    --    middle:Hide()
    --    right:Hide()
    --
    --    local widget = {
    --        frame = frame,
    --        label = label,
    --        dropdown = dropdown,
    --        text = text,
    --        button = button,
    --        count = count,
    --        alignoffset = 30,
    --        type = Type,
    --    }
    --    for method, func in pairs(methods) do
    --        widget[method] = func
    --    end
    --    frame.obj = widget
    --    dropdown.obj = widget
    --    text.obj = widget
    --    button.obj = widget

        return dropdown
    end
end

function public.slider(frame, name)

    local slider = CreateFrame('Slider', name, frame)
    slider:SetOrientation('HORIZONTAL')
    slider:SetHeight(6)
    slider:SetHitRectInsets(0, 0, -8, -8)
    slider:SetValue(0)
    slider:SetBackdrop{ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size }
    slider:SetBackdropColor(unpack(m.config.frame_color))
    slider:SetBackdropBorderColor(unpack(m.config.frame_border_color))
    local thumb_texture = slider:CreateTexture(nil, 'ARTWORK')
    thumb_texture:SetPoint('CENTER', 0, 0)
    thumb_texture:SetTexture(unpack(m.config.content_color))
    thumb_texture:SetHeight(15)
    thumb_texture:SetWidth(8)
    slider:SetThumbTexture(thumb_texture)

    local label = slider:CreateFontString(nil, 'OVERLAY')
    label:SetPoint('BOTTOMLEFT', slider, 'TOPLEFT', -3, 6)
    label:SetPoint('BOTTOMRIGHT', slider, 'TOPRIGHT', 6, 6)
    label:SetJustifyH('LEFT')
    label:SetHeight(13)
    label:SetFont(m.config.content_font, m.config.normal_font_size)
    label:SetTextColor(unpack(m.config.label_color.enabled))

    local editbox = CreateFrame('EditBox', nil, slider)
    editbox:SetAutoFocus(false)
    editbox:SetPoint('LEFT', slider, 'RIGHT', 5, 0)
    editbox:SetHeight(15)
    editbox:SetWidth(70)
    editbox:SetJustifyH('CENTER')
    editbox:EnableMouse(true)
    editbox:SetBackdrop{ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size }
    editbox:SetBackdropColor(unpack(m.config.content_color))
    editbox:SetBackdropBorderColor(unpack(m.config.content_border_color))
--    editbox:SetFont(m.config.content_font, m.config.normal_font_size)
    editbox:SetFont(m.config.content_font, m.config.normal_button_font_size)
    editbox:SetShadowColor(0, 0, 0, 0)
--
--    local button = CreateFrame('Button', nil, editbox, 'UIPanelButtonTemplate')
--    button:SetWidth(40)
--    button:SetHeight(20)
--    button:SetPoint('LEFT', editbox, 'RIGHT', 2, 0)
--    button:SetText(OKAY)
--    button:SetScript('OnClick', Button_OnClick)
--    button:Hide()
--
    slider.label = label
    slider.editbox = editbox
    return slider
end

--function m.checkbox()
--    local frame = CreateFrame('Button', nil, UIParent)
--    frame:Hide()
--    frame:EnableMouse(true)
--    frame:SetScript("OnEnter", Control_OnEnter)
--    frame:SetScript("OnLeave", Control_OnLeave)
--    frame:SetScript("OnMouseDown", CheckBox_OnMouseDown)
--    frame:SetScript("OnMouseUp", CheckBox_OnMouseUp)
--
--    local checkbox = CreateFrame('Button', nil, frame)
--    checkbox:EnableMouse(false)
--    checkbox:SetWidth(16)
--    checkbox:SetHeight(16)
--    checkbox:SetPoint('TOPLEFT', 4, -4)
--    checkbox:SetBackdrop({ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size })
--    checkbox:SetBackdropColor(unpack(m.config.content_color))
--    checkbox:SetBackdropBorderColor(unpack(m.config.content_border_color))
--    local highlight = checkbox:CreateTexture(nil, 'HIGHLIGHT')
--    highlight:SetAllPoints()
--    highlight:SetTexture(1, 1, 1, .2)
--    highlight:SetBlendMode('BLEND')
--
--    local check = checkbox:CreateTexture(nil, 'OVERLAY')
--    check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
--    check:SetTexCoord(.12, .88, .12, .88)
--    check:SetBlendMode('BLEND')
--    check:SetPoint('BOTTOMRIGHT')
--
--    local text = frame:CreateFontString(nil, 'OVERLAY')
--    text:SetJustifyH('LEFT')
--    text:SetHeight(18)
--    text:SetPoint('LEFT', checkbox, 'RIGHT')
--    text:SetPoint('RIGHT')
--    text:SetFont(m.config.content_font, m.config.normal_font_size)
--
--    checkbox.text = text
--    return checkbox
--end