module 'aux'

local gui = require 'aux.gui'

function handle.LOAD()
	for _, v in ipairs(tab_info) do
		tabs:create_tab(v.name)
	end
end

do
	local frame = CreateFrame('Frame', 'AuxFrame', UIParent)
	tinsert(UISpecialFrames, 'AuxFrame')
	gui.set_window_style(frame)
	gui.set_size(frame, 768, 447)
	frame:SetPoint('LEFT', 100, 0)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', function() this:StartMoving() end)
	frame:SetScript('OnDragStop', function() this:StopMovingOrSizing() end)
	frame:SetScript('OnShow', function() PlaySound('AuctionWindowOpen') end)
	frame:SetScript('OnHide', function() PlaySound('AuctionWindowClose'); CloseAuctionHouse() end)
	frame.content = CreateFrame('Frame', nil, frame)
	frame.content:SetPoint('TOPLEFT', 4, -80)
	frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
	frame:Hide()
	M.AuxFrame = frame
end
do
	tabs = gui.tabs(AuxFrame, 'DOWN')
	tabs._on_select = on_tab_click
	function M.set_tab(id) tabs:select(id) end
end
do
	local btn = gui.button(AuxFrame)
	btn:SetPoint('BOTTOMRIGHT', -5, 5)
	gui.set_size(btn, 60, 24)
	btn:SetText('Close')
	btn:SetScript('OnClick', function() AuxFrame:Hide() end)
	close_button = btn
end
do
	local btn = gui.button(AuxFrame, gui.font_size.small)
	btn:SetPoint('RIGHT', close_button, 'LEFT' , -5, 0)
	gui.set_size(btn, 60, 24)
	btn:SetText(color.blizzard'Blizzard UI')
	btn:SetScript('OnClick',function()
		if AuctionFrame:IsVisible() then HideUIPanel(AuctionFrame) else ShowUIPanel(AuctionFrame) end
	end)
end