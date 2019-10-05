select(2, ...) 'aux'

local gui = require 'aux.gui'

function event.AUX_LOADED()
	for _, v in ipairs(tab_info) do
		tabs:create_tab(v.name)
	end
end

do
	local frame = CreateFrame('Frame', 'aux_frame', UIParent)
	tinsert(UISpecialFrames, 'aux_frame')
	gui.set_window_style(frame)
	gui.set_size(frame, 768, 447)
	frame:SetPoint('LEFT', 100, 0)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
--	frame:CreateTitleRegion():SetAllPoints() TODO classic why
	frame:SetScript('OnShow', function() PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN) end)
	frame:SetScript('OnHide', function() PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE); CloseAuctionHouse() end)
	frame.content = CreateFrame('Frame', nil, frame)
	frame.content:SetPoint('TOPLEFT', 4, -80)
	frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
	frame:Hide()
	M.frame = frame
end
do
    local status_bar = gui.status_bar(frame.content)
    status_bar:SetWidth(265)
    status_bar:SetHeight(27)
    status_bar:SetPoint('TOPLEFT', frame.content, 'BOTTOMLEFT', 0, -3)
    status_bar:update_status(1, 1)
    M.status_bar = status_bar
end
do
	tabs = gui.tabs(frame, 'DOWN')
	tabs._on_select = on_tab_click
	function M.set_tab(id) tabs:select(id) end
end
do
	local btn = gui.button(frame)
	btn:SetPoint('BOTTOMRIGHT', -5, 5)
	gui.set_size(btn, 60, 24)
	btn:SetText('Close')
	btn:SetScript('OnClick', function() frame:Hide() end)
	close_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetPoint('RIGHT', close_button, 'LEFT' , -5, 0)
	gui.set_size(btn, 60, 24)
	btn:SetText(color.blizzard'Blizzard UI')
	btn:SetScript('OnClick',function()
		if AuctionFrame:IsVisible() then
            AuctionFrame_Hide()
        else
            AuctionFrame_Show()
        end
	end)
end