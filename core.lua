aux.module ''

public.bids_loaded = false
public.current_owner_page = nil
public.last_owner_page_requested = nil

do
	local data = {}
	local mt = {
		__newindex = function(self, key, value)
			data[self].getter{public=self, private=data[self].state}[key] = value
		end,
		__index = function(self, key)
			return data[self].getter{public=self, private=data[self].state}[key]
		end,
		__call = function(self)
			return data[self].getter{public=self, private=data[self].state}
		end,
	}
	function public.dynamic_table(state, getter)
		local self = {}
		data[self] = {getter=getter, state=state}
		return setmetatable(self, mt)
	end
end

do
	local _state = setmetatable({}, {__mode='kv'})
	local __index = function(self, key)
		return _state[self].handler({public=self, private=_state[self].state}, key)
	end
	function public.index_function(state, handler)
		local state, self = {handler=handler, state=state}, {}
		_state[self] = state
		return setmetatable(self, {__metatable=false, __index=__index, state=state})
	end
end

function public.temp(object)
	getfenv(2).__ = object
	return object
end

function public.L(body_string)
	return loadstring 'function()'
end

private.tabs = {}
function public.tab(index, name)
	local module_env = getfenv(2)
	local tab = {name=name, env=module_env}
	module_env.public.ACTIVE = function()
		return tab == m.active_tab()
	end
	for _, handler in {'OPEN', 'CLOSE', 'CLICK_LINK', 'USE_ITEM'} do
		module_env.private[handler] = nil
	end
	m.tabs[index] = tab
end
do
	local active_tab_index
	private.active_tab = m.dynamic_table(nil, function()
		return m.tabs[active_tab_index]
	end)
	function private.on_tab_click(index)
		if active_tab_index then
			m.call(m.active_tab.env.m.CLOSE)
		end
		active_tab_index = index
		if active_tab_index then
			m.call(m.active_tab.env.m.OPEN)
		end
	end
end

function public.VARIABLES_LOADED()
	do
		local frame = CreateFrame('Frame', aux.gui.name(), UIParent)
		tinsert(UISpecialFrames, '_G.aux_frame1')
		m.gui.set_window_style(frame)
		frame:SetWidth(768)
		frame:SetHeight(447)
		frame:SetPoint('LEFT', 100, 0)
		frame:SetToplevel(true)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag 'LeftButton'
		frame:SetScript('OnDragStart', function()
			this:StartMoving()
		end)
		frame:SetScript('OnDragStop', function()
			this:StopMovingOrSizing()
		end)
		frame:SetScript('OnShow', function()
			PlaySound 'AuctionWindowOpen'
		end)
		frame:SetScript('OnHide', function()
			PlaySound 'AuctionWindowClose'
			CloseAuctionHouse()
		end)
		frame.content = CreateFrame('Frame', nil, frame)
		frame.content:SetPoint('TOPLEFT', 4, -80)
		frame.content:SetPoint('BOTTOMRIGHT', -4, 35)
		frame:Hide()
		public.frame = frame
	end
	do
		local tabs = m.gui.tabs(m.frame, 'DOWN')
		tabs._on_select = m.on_tab_click
		for _, tab in m.tabs do
			tabs:create_tab(tab.name)
		end
		function public.set_tab(id)
			tabs:select(id)
		end
	end
	do
		local btn = m.gui.button(m.frame, 16)
		btn:SetPoint('BOTTOMRIGHT', -6, 6)
		btn:SetWidth(65)
		btn:SetHeight(24)
		btn:SetText 'Close'
		btn:SetScript('OnClick', m.C(m.frame.Hide, m.frame))
		public.close_button = btn
	end
	do
		local btn = m.gui.button(m.frame, 16)
		btn:SetPoint('RIGHT', m.close_button, 'LEFT' , -5, 0)
		btn:SetWidth(65)
		btn:SetHeight(24)
		btn:SetText 'Default UI'
		btn:SetScript('OnClick',function()
			if AuctionFrame:IsVisible() then
				HideUIPanel(AuctionFrame)
			else
				ShowUIPanel(AuctionFrame)
			end
		end)
	end
end

function private.AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	m.frame:Show()
	m.set_tab(1)
end

function private.AUCTION_HOUSE_CLOSED()
	m.bids_loaded = false
	m.current_owner_page = nil
	m.post.stop()
	m.stack.stop()
	m.scan.abort()
	m.set_tab()
	m.frame:Hide()
end

function private.AUCTION_BIDDER_LIST_UPDATE()
	m.bids_loaded = true
end

function private.AUCTION_OWNED_LIST_UPDATE()
	m.current_owner_page = m.last_owner_page_requested or 0
end

function m.ADDON_LOADED.Blizzard_AuctionUI()
	AuctionFrame:UnregisterEvent('AUCTION_HOUSE_SHOW')
	AuctionFrame:SetScript('OnHide', nil)

	m.hook('ShowUIPanel', function(...)
		if arg[1] == AuctionFrame then
			return AuctionFrame:Show()
		end
		return m.orig.ShowUIPanel(unpack(arg))
	end)

	m.hook('GetOwnerAuctionItems', m.GetOwnerAuctionItems)
	m.hook('SetItemRef', m.SetItemRef)
	m.hook('UseContainerItem', m.UseContainerItem)
	m.hook('AuctionFrameAuctions_OnEvent', m.AuctionFrameAuctions_OnEvent)
end

do
	local function cost_label(cost)
		local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
		label = label..(cost and m.money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE)
		label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
		return label
	end

	function m.ADDON_LOADED.Blizzard_CraftUI()
		m.hook('CraftFrame_SetSelection', function(...)
			local results = {m.orig.CraftFrame_SetSelection(unpack(arg)) }

			local id = GetCraftSelectionIndex()
			local reagent_count = GetCraftNumReagents(id)

			local total_cost = 0
			for i=1,reagent_count do
				local link = GetCraftReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = m.info.parse_link(link)
				local count = aux.util.select(3, GetCraftReagentInfo(id, i))
				local _, price, limited = m.cache.merchant_info(item_id)
				local value = price and not limited and price or m.history.value(item_id..':'..suffix_id)
				if not value then
					total_cost = nil
					break
				else
					total_cost = total_cost + value * count
				end
			end

			CraftReagentLabel:SetText(SPELL_REAGENTS..' '..cost_label(total_cost))

			return unpack(results)
		end)
	end

	function m.ADDON_LOADED.Blizzard_TradeSkillUI()
		m.hook('TradeSkillFrame_SetSelection', function(...)
			local results = {m.orig.TradeSkillFrame_SetSelection(unpack(arg)) }

			local id = GetTradeSkillSelectionIndex()
			local reagent_count = GetTradeSkillNumReagents(id)

			local total_cost = 0
			for i=1,reagent_count do
				local link = GetTradeSkillReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = m.info.parse_link(link)
				local count = aux.util.select(3, GetTradeSkillReagentInfo(id, i))
				local _, price, limited = m.cache.merchant_info(item_id)
				local value = price and not limited and price or m.history.value(item_id..':'..suffix_id)
				if not value then
					total_cost = nil
					break
				else
					total_cost = total_cost + value * count
				end
			end

			TradeSkillReagentLabel:SetText(SPELL_REAGENTS..' '..cost_label(total_cost))

			return unpack(results)
		end)
	end
end

public.orig = {}
function public.hook(name, handler, object)
	local orig
	if object then
		m.orig[object] = m.orig[object] or {}
		orig = m.orig[object]
	else
		object = _G
		orig = m.orig
	end
	if orig[name] then
		error('"'..name..'" is already hooked.')
	end
	orig[name] = object[name]
	object[name] = handler
end

function private.GetOwnerAuctionItems(...)
    local page = arg[1]
    m.last_owner_page_requested = page
    return m.orig.GetOwnerAuctionItems(unpack(arg))
end

function private.AuctionFrameAuctions_OnEvent(...)
    if AuctionFrameAuctions:IsVisible() then
        return m.orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end

function private.SetItemRef(...)
	if arg[3] ~= 'RightButton' or not m.index(m.active_tab(), 'env', 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return m.orig.SetItemRef(unpack(arg))
	end
	for item_info in aux.util.present(m.info.item(tonumber(({strfind(arg[1], '^item:(%d+)')})[3]))) do
		return m.active_tab.env.m.CLICK_LINK(item_info)
	end
end

function private.UseContainerItem(...)
    if m.modified() or not m.index(m.active_tab(), 'env', 'USE_ITEM') then
        return m.orig.UseContainerItem(unpack(arg))
    end
    for item_info in aux.util.present(m.info.container_item(arg[1], arg[2])) do
        return m.active_tab.env.m.USE_ITEM(item_info)
    end
end

do
	local locked

	function public.bid_in_progress()
		return locked
	end

	function public.place_bid(type, index, amount, on_success)

		if locked then
			return
		end

		local money = GetMoney()
		PlaceAuctionBid(type, index, amount)
		if money >= amount then
			locked = true

			m.control.event_listener('CHAT_MSG_SYSTEM', function(kill)
				if arg1 == ERR_AUCTION_BID_PLACED then
					m.call(on_success)
					locked = false
					kill()
				end
			end)
		end
	end
end

do
	local locked

	function public.cancel_in_progress()
		return locked
	end

	function public.cancel_auction(index, on_success)

		if locked then
			return
		end

		locked = true

		CancelAuction(index)
		m.control.event_listener('CHAT_MSG_SYSTEM', function(kill)
			if arg1 == ERR_AUCTION_REMOVED then
				aux.call(on_success)
				locked = false
				kill()
			end
		end)
	end
end

public._this = {}
do
	local formal_parameters = {}
	for i=1,9 do
		local key = '_'..i
		public[key] = {}
		formal_parameters[m[key]] = i
	end
	local function call(f, arg1, arg2)
		local params = {}
		for i=1,arg1.n do
			if arg1[i] == m._this then
				tinsert(params, this)
			elseif formal_parameters[arg1[i]] then
				tinsert(params, arg2[formal_parameters[arg1[i]]])
			else
				tinsert(params, arg1[i])
			end
		end
		return f(unpack(params))
	end
	function public.C(f, ...)
		local arg1 = arg
		return function(...)
			return call(f, arg1, arg)
		end
	end
end

function public.call(f, ...)
	if f then
		return f(unpack(arg))
	end
end

function public.index(t, ...)
	for i=1,arg.n do
		t = t and t[arg[i]]
	end
	return t
end

public.huge = 1.8*10^308

function public.log(...)
	local msg = '[aux]'
	for i=1,arg.n do
		msg = msg..' '..tostring(arg[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end

function public.is_player(name, current)
    local realm = GetCVar 'realmName'
    return not current and m.index(_G.aux_characters, realm, name) or UnitName 'player' == name
end

function public.modified()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function public.neutral_faction()
	return not UnitFactionGroup 'npc'
end

function public.min_bid_increment(current_bid)
	return max(1, floor(current_bid / 100) * 5)
end