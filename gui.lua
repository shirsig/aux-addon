local m = {}
Aux.gui = m

m.config = {
    edge_size = 1.5,
    frame_color = {24/255, 24/255, 24/255, 1},
    frame_border_color = {1, 1, 1, .03},
    content_color = {42/255, 42/255, 42/255, 1},
    content_border_color = {0, 0, 0, 0},
--    content_font = [[Fonts\ARIALN.TTF]],
    content_font = [[Interface\AddOns\Aux-Addon\ARIALN.TTF]],
    normal_font_size = 15,
    text_color = { enabled = { 255/255, 254/255, 250/255, 1 }, disabled = { 147/255, 151/255, 139/255, 1 } },
    label_color = { enabled = { 216/255, 225/255, 211/255, 1 }, disabled = { 150/255, 148/255, 140/255, 1 } },

}

function m.button(parent, text_height, name)
    local button = CreateFrame('Button', name, parent)
    button:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size})
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


function m.resize_tab(tab, width, padding)
    tab:SetWidth(width + padding + 10)
end

function m.update_tab(tab)

end

do
    local id = 0
    function m.tab_group(parent, position)
        id = id + 1

        local frame = CreateFrame('Frame', nil, parent)
        frame:SetHeight(100)
        frame:SetWidth(100)
--        frame:SetFrameStrata('FULLSCREEN_DIALOG')

--        local border = CreateFrame('Frame', nil, frame)
--        border:SetPoint('TOPLEFT', 1, -30)
--        border:SetPoint('BOTTOMRIGHT', -1, 3)
--        border:SetBackdrop({ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size })
--        border:SetBackdropColor(unpack(m.config.frame_color))
--        border:SetBackdropBorderColor(unpack(m.config.frame_border_color))

--        local content = CreateFrame('Frame', nil, border)
--        content:SetPoint('TOPLEFT', 8, -8)
--        content:SetPoint('BOTTOMRIGHT', -8, 8)

        local self = {
            id = id,
            frame = parent,
--            border = border,
            tabs = {},
            on_select = function() end,
        }

        function self:create_tab(text)
            local id = getn(self.tabs) + 1

            local tab = CreateFrame('Button', 'aux_tab_group'..self.id..'_tab'..id, self.frame)
            tab.id = id
            tab.group = self
            tab:SetHeight(24)
            tab:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size})
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
                --    if tab.disabled then
                --        TSMAPI.Design:SetWidgetLabelColor(tab.text, true)
                --        tab:Disable()
                --        tab.text = tab:GetText()
                --        tab.dock:Hide()
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


--            ["OnWidthSet"] = function(self, width)
--                local content = self.content
--                local contentwidth = width - 60
--                if contentwidth < 0 then
--                    contentwidth = 0
--                end
--                content:SetWidth(contentwidth)
--                content.width = contentwidth
--                self:BuildTabs(self)
--                self.frame:SetScript("OnUpdate", BuildTabsOnUpdate)
--            end,
--
--            ["OnHeightSet"] = function(self, height)
--                local content = self.content
--                local contentheight = height - 30
--                if contentheight < 0 then
--                    contentheight = 0
--                end
--                content:SetHeight(contentheight)
--                content.height = contentheight
--            end,
--
--            ["LayoutFinished"] = function(self, width, height)
--                if self.noAutoHeight then return end
--                self:SetHeight((height or 0) + 30)
--            end

        return self
    end
end

function m.editbox(parent, name)

--        local frame = CreateFrame('Frame', name, parent)
--        frame:Hide()

    local editbox = CreateFrame('EditBox', name, parent)
    editbox.selector = Aux.completion.selector(editbox)
    editbox:SetAutoFocus(false)
    editbox:SetTextInsets(0, 0, 3, 3)
    editbox:SetMaxLetters(256)
    editbox:SetHeight(19)
    editbox:SetFont(m.config.content_font, m.config.normal_font_size)
    editbox:SetShadowColor(0, 0, 0, 0)
    editbox:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=m.config.edge_size})
    editbox:SetBackdropColor(unpack(m.config.content_color))
    editbox:SetBackdropBorderColor(unpack(m.config.content_border_color))

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

function m.status_bar(parent)
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
--        local ag = status_bar:CreateAnimationGroup()
--        local alpha = ag:CreateAnimation('Alpha')
--        alpha:SetDuration(1)
--        alpha:SetChange(-.5)
--        ag:SetLooping('Bounce')
--        status_bar.ag = ag
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
--        local ag = status_bar:CreateAnimationGroup()
--        local alpha = ag:CreateAnimation('Alpha')
--        alpha:SetDuration(1)
--        alpha:SetChange(-.5)
--        ag:SetLooping('Bounce')
--        status_bar.ag = ag
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
--            if major_status == 100 then
--                self.major_status_bar.ag:Stop()
--            elseif not self.major_status_bar.ag:IsPlaying() then
--                self.major_status_bar.ag:Play()
--            end
        end
        if minor_status then
            self.minor_status_bar:SetValue(minor_status)
--            if minor_status == 100 then
--                self.minor_status_bar.ag:Stop()
--            elseif not self.minor_status_bar.ag:IsPlaying() then
--                self.minor_status_bar.ag:Play()
--            end
        end
    end

    function self:set_text(text)
        self.text:SetText(text)
    end

    return self
end

function m.label(parent, size)
    local label = parent:CreateFontString()
    label:SetFont(m.config.content_font, size or m.config.normal_font_size)
    label:SetTextColor(unpack(m.config.label_color.enabled))
    return label
end

function m.CreateHorizontalLine(parent, ofsy, relativeFrame, invertedColor)
    relativeFrame = relativeFrame or parent
    local barTex = parent:CreateTexture()
    barTex:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", 2, ofsy)
    barTex:SetPoint("TOPRIGHT", relativeFrame, "TOPRIGHT", -2, ofsy)
    barTex:SetHeight(2)
    if invertedColor then
        TSMAPI.Design:SetFrameColor(barTex)
    else
        TSMAPI.Design:SetContentColor(barTex)
    end
    return barTex
end

function m.CreateVerticalLine(parent, ofsx, relativeFrame, invertedColor)
    relativeFrame = relativeFrame or parent
    local barTex = parent:CreateTexture()
    barTex:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", ofsx, -2)
    barTex:SetPoint("BOTTOMLEFT", relativeFrame, "BOTTOMLEFT", ofsx, 2)
    barTex:SetWidth(2)
    if invertedColor then
        TSMAPI.Design:SetFrameColor(barTex)
    else
        TSMAPI.Design:SetContentColor(barTex)
    end
    return barTex
end

function m.dropdown()
    local count = AceGUI:GetNextWidgetNum(Type)

    local frame = CreateFrame("Frame", nil, UIParent)
    local dropdown = CreateFrame("Frame", "TSMDropDown"..count, frame, "UIDropDownMenuTemplate")

    frame:SetScript("OnHide", Dropdown_OnHide)

    dropdown:ClearAllPoints()
    dropdown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 0)
    dropdown:SetScript("OnHide", nil)
    dropdown:SetScript("OnEnter", Control_OnEnter)
    dropdown:SetScript("OnLeave", Control_OnLeave)
    dropdown:SetScript("OnMouseUp", function(self, button) Dropdown_TogglePullout(self.obj.button, button) end)
    TSMAPI.Design:SetContentColor(dropdown)

    local left = _G[dropdown:GetName().."Left"]
    local middle = _G[dropdown:GetName().."Middle"]
    local right = _G[dropdown:GetName().."Right"]

    middle:ClearAllPoints()
    right:ClearAllPoints()

    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    right:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 17)

    local button = _G[dropdown:GetName().."Button"]
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnEnter", Control_OnEnter)
    button:SetScript("OnLeave", Control_OnLeave)
    button:SetScript("OnClick", Dropdown_TogglePullout)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", dropdown, 0, 0)

    local text = _G[dropdown:GetName().."Text"]
    text:ClearAllPoints()
    text:SetPoint("RIGHT", button, "LEFT", -2, 0)
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetFont(TSMAPI.Design:GetContentFont("normal"))
    text:SetShadowColor(0, 0, 0, 0)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetHeight(18)
    label:SetFont(TSMAPI.Design:GetContentFont("small"))
    label:SetShadowColor(0, 0, 0, 0)
    label:Hide()

    left:Hide()
    middle:Hide()
    right:Hide()

    local widget = {
        frame = frame,
        label = label,
        dropdown = dropdown,
        text = text,
        button = button,
        count = count,
        alignoffset = 30,
        type = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    frame.obj = widget
    dropdown.obj = widget
    text.obj = widget
    button.obj = widget

    return AceGUI:RegisterAsWidget(widget)
end