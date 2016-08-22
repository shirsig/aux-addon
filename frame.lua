module 'aux' import 'gui'

do
	local frame = CreateFrame('Frame', 'aux_frame', UIParent)
	tinsert(UISpecialFrames, 'aux_frame')
	gui.set_window_style(frame)
	gui.set_size(frame, 768, 447)
	frame:SetPoint('LEFT', 100, 0)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag 'LeftButton'
	frame:SetScript('OnDragStart', function() this:StartMoving() end)
	frame:SetScript('OnDragStop', function() this:StopMovingOrSizing() end)
	frame:SetScript('OnShow', function() PlaySound 'AuctionWindowOpen' end)
	frame:SetScript('OnHide', function() PlaySound 'AuctionWindowClose' CloseAuctionHouse() end)
	frame.content = CreateFrame('Frame', nil, frame)
	frame.content:SetPoint('TOPLEFT', 4, -80)
	frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
	frame:Hide()
	public.aux_frame = frame
end
do
	local tabs = gui.tabs(frame, 'DOWN')
	tabs._on_select = on_tab_click
	for _, tab in _m.tabs do tabs:create_tab(tab.name) end
	function public.set_tab(id) tabs:select(id) end
end
do
	local btn = gui.button(frame, 16)
	btn:SetPoint('BOTTOMRIGHT', -6, 6)
	gui.set_size(btn, 65, 24)
	btn:SetText 'Close'
	btn:SetScript('OnClick', L(frame.Hide, frame))
	public.close_button = btn
end
do
	local btn = gui.button(frame, 16)
	btn:SetPoint('RIGHT', close_button, 'LEFT' , -5, 0)
	gui.set_size(btn, 65, 24)
	btn:SetText 'Default UI'
	btn:SetScript('OnClick',function()
		if AuctionFrame:IsVisible() then HideUIPanel(AuctionFrame) else ShowUIPanel(AuctionFrame) end
	end)
end