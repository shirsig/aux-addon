module 'core'

public.bids_loaded = false
public.current_owner_page = nil

function LOAD()
	import :_ 'util' 'gui'
	do
		local frame = CreateFrame('Frame', gui.name, UIParent)
		tinsert(UISpecialFrames, 'aux_frame1')
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
		public.frame = frame
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
end

function public.log(...)
	local msg = '[aux]'
	for i=1,arg.n do msg = msg..' '..tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end

tabs = {}
function public.tab(index, name)
	local module_env = getfenv(2)
	local tab = {name=name, env=module_env}
	function module_env.public.accessor.ACTIVE() return tab == active_tab end
	for handler in tmp-set-from . OPEN . CLOSE . CLICK_LINK . USE_ITEM do module_env.mutable[handler] = nil end
	tabs[index] = tab
end
do
	local active_tab_index
	function accessor.active_tab() return tabs[active_tab_index] end
	function on_tab_click(index)
		call(active_tab_index and active_tab.env.CLOSE)
		active_tab_index = index
		call(active_tab_index and active_tab.env.OPEN)
	end
end

public.orig = setmetatable({[_g]={}}, {__index=function(self, key) return self[_g][key] end})
function public.hook(name, handler, object)
	handler = handler or getfenv(2)[name]
	object = object or _g
	orig[object] = orig[object] or {}
	assert(not orig[object][name], '"'..name..'" is already hooked into.')
	orig[object][name], object[name] = object[name], handler
end