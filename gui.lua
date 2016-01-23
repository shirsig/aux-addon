local m = {}
Aux.gui = m

m.config = {
    edge_size = 1.5,
    frame_color = {24/255, 24/255, 24/255, 1},
    frame_border_color = {1, 1, 1, .03},
    content_color = {42/255, 42/255, 42/255, 1},
    content_border_color = {0, 0, 0, 0},
    content_font = [[Fonts\ARIALN.TTF]],
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
    button:Show()
    local label = button:CreateFontString()
    label:SetFont(m.config.content_font, text_height)
    label:SetPoint('CENTER', 0, 0)
    label:SetJustifyH('CENTER')
    label:SetJustifyV('CENTER')
    label:SetHeight(text_height)
    label:SetTextColor(255/255, 254/255, 250/255)
--    TSM:Hook(button, "Enable", function() TSMAPI.Design:SetWidgetTextColor(label) end, true)
--    TSM:Hook(button, "Disable", function() TSMAPI.Design:SetWidgetTextColor(label, true) end, true)
    button:SetFontString(label)
    return button
end


function m.resize_tab(tab, width, padding)
    tab:SetWidth(width + padding + 8)
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
            local bottom = tab:CreateTexture(nil, 'OVERLAY')
            bottom:SetHeight(2)
            bottom:SetPoint('BOTTOMLEFT', 1, -1)
            bottom:SetPoint('BOTTOMRIGHT', -1, -1)
            bottom:SetTexture(unpack(m.config.frame_color))
            tab.bottom = bottom
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
                --        tab.bottom:Hide()
                if tab.group.selected == tab.id then
--                    TSMAPI.Design:SetWidgetLabelColor(tab.text)
                    tab.text:SetTextColor(255/255, 254/255, 250/255) -- TODO
                    tab:Disable()
                    tab.image:SetTexture(unpack(m.config.frame_color))
                    tab.bottom:Show()
                    tab:SetHeight(29)
                else
--                    TSMAPI.Design:SetWidgetTextColor(tab.text)
                    tab.text:SetTextColor(255/255, 254/255, 250/255) -- TODO
                    tab:Enable()
                    tab.image:SetTexture(unpack(m.config.content_color))
                    tab.bottom:Hide()
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