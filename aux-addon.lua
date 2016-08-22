module 'core'
public.version = '5.0.0'

public.bids_loaded = false
public.current_owner_page = nil

do
	local table_pool, temporary = {}, {}

	CreateFrame'Frame':SetScript('OnUpdate', function()
		for t in temporary do
			recycle(t)
			log(getn(table_pool))
		end
		wipe(temporary)
	end)

	function public.wipe(t) -- like with a cloth or something
		for k in t do
			t[k] = nil
		end
		table.setn(t, 0)
		setmetatable(t, nil)
	end

	function public.recycle(t)
		temporary[t] = nil
		wipe(t)
		tinsert(table_pool, t)
	end

	function public.accessor.t() return
		tremove(table_pool) or {}
	end

	function public.accessor.tt()
		local t = tremove(table_pool) or {}
		temporary[t] = true
		return t
	end

	do
		local T = t
		local mt = {__unm=function(self) T = t; return setmetatable(self, nil) end}
		function public.accessor.T()
			wipe(T)
			return setmetatable(T, mt)
		end
	end

	function public.modifier_mt(f)
		local function apply(_, value) return f(value) end
		return {
			__call=apply, __add=apply, __sub=apply, __mul=apply, __div=apply, __pow=apply, __concat=apply, __lt=apply, __le=apply,
			__unm=function(self) return self end,
		}
	end
	do
		local mt = modifier_mt(function(t) temporary[t] = true; return t end)
		function public.accessor.temp()
			return setmetatable(T, mt)
		end
	end
	do
		local mt = modifier_mt(function(t) temporary[t] = false; return t end)
		function public.accessor.perm()
			return setmetatable(T, mt)
		end
	end

	function public.collector_mt(f)
		return {
			__unm=function(self)
				setmetatable(self, nil)
			end,
			__index=function(self, key)
				f(self, key)
				return self
			end,
			__call=function(self, arg1, arg2)
				f(self, arg2 or arg1)
				return self
			end,
		}
	end
	do
		local mt = collector_mt(tinsert)
		function public.accessor.list()
			return setmetatable(T, mt)
		end
	end
	do
		local mt = collector_mt(function(self, value)
			rawset(self, value, true)
		end)
		function public.accessor.set()
			return setmetatable(T, mt)
		end
	end
	do
		local key
		local mt = collector_mt(function(self, value)
			if key ~= nil then
				rawset(self, key, value)
			else
				key = value
			end
		end)
		function public.accessor.map()
			return setmetatable(T, mt)
		end
	end
end

local event_frame = CreateFrame 'Frame'
for event in perm <- set 'ADDON_LOADED' 'VARIABLES_LOADED' 'PLAYER_LOGIN' 'AUCTION_HOUSE_SHOW' 'AUCTION_HOUSE_CLOSED' 'AUCTION_BIDDER_LIST_UPDATE' 'AUCTION_OWNED_LIST_UPDATE' do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = t
do
	local variables_loaded_hooks, player_login_hooks = t, t
	function public.mutator.LOAD(f) tinsert(variables_loaded_hooks, f) end
	function public.mutator.LOAD2(f) tinsert(player_login_hooks, f) end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			if ADDON_LOADED[arg1] then ADDON_LOADED[arg1]() end
		elseif event == 'VARIABLES_LOADED' then
			for _, f in variables_loaded_hooks do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in player_login_hooks do f() end
			log('v'..version..' loaded.')
		else
			_m[event]()
		end
	end)
end

function public.log(...)
	local msg = '[aux]'
	for i=1,arg.n do msg = msg..' '..tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end

map :search_tab 'Search' :post_tab 'Post' :auctions_tab 'Auctions' :bids_tab 'Bids'
tabs = t
for _, name in from (from 'Search') 'Post' 'Auctions' 'Bids' do
	tinsert(tabs)
end
function public.tab(index, name)
	local module_env = getfenv(2)
	local tab = {name=name, env=module_env}
	function module_env.public.accessor.ACTIVE() return tab == active_tab end
	for handler in temp-set-from 'OPEN' 'CLOSE' 'CLICK_LINK' 'USE_ITEM' do module_env.mutable[handler] = nil end
	tabs[index] = tab
end
do
	local active_tab_index
	function accessor.active_tab() return tabs[active_tab_index] end
	function on_tab_click(index)
		call(active_tab_index and active_tab.CLOSE)
		active_tab_index = index
		call(active_tab_index and active_tab.OPEN)
	end
end
function SetItemRef(...)
	if arg[3] ~= 'RightButton' or not index(active_tab, 'env', 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return orig.SetItemRef(unpack(arg))
	end
	for item_info in present(info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))) do
		return active_tab.CLICK_LINK(item_info)
	end
end
function UseContainerItem(...)
	if modified or not index(active_tab, 'env', 'USE_ITEM') then
		return orig.UseContainerItem(unpack(arg))
	end
	for item_info in present(info.container_item(arg[1], arg[2])) do
		return active_tab.env.USE_ITEM(item_info)
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

do
	local locked
	function public.accessor.bid_in_progress() return locked end
	function public.place_bid(type, index, amount, on_success)
		if locked then return end
		local money = GetMoney()
		PlaceAuctionBid(type, index, amount)
		if money >= amount then
			locked = true
			event_listener('CHAT_MSG_SYSTEM', function(kill)
				if arg1 == ERR_AUCTION_BID_PLACED then
					call(on_success)
					locked = false
					kill()
				end
			end)
		end
	end
end

do
	local locked
	function public.accessor.cancel_in_progress() return locked end
	function public.cancel_auction(index, on_success)
		if locked then return end
		locked = true
		CancelAuction(index)
		event_listener('CHAT_MSG_SYSTEM', function(kill)
			if arg1 == ERR_AUCTION_REMOVED then
				call(on_success)
				locked = false
				kill()
			end
		end)
	end
end

function public.is_player(name, current)
	local realm = GetCVar 'realmName'
	return not current and index(_g.aux_characters, realm, name) or UnitName 'player' == name
end

function public.neutral_faction()
	return not UnitFactionGroup 'npc'
end

function public.min_bid_increment(current_bid)
	return max(1, floor(current_bid / 100) * 5)
end

function AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	frame:Show()
	set_tab(1)
end

function AUCTION_HOUSE_CLOSED()
	bids_loaded = false
	current_owner_page = nil
	post.stop()
	stack.stop()
	scan.abort()
	set_tab()
	frame:Hide()
end

function AUCTION_BIDDER_LIST_UPDATE()
	bids_loaded = true
end

do
	local last_owner_page_requested
	function GetOwnerAuctionItems(...)
		local page = arg[1]
		last_owner_page_requested = page
		return orig.GetOwnerAuctionItems(unpack(arg))
	end
	function AUCTION_OWNED_LIST_UPDATE()
		current_owner_page = last_owner_page_requested or 0
	end
end

function ADDON_LOADED.Blizzard_AuctionUI()
	AuctionFrame:UnregisterEvent 'AUCTION_HOUSE_SHOW'
	AuctionFrame:SetScript('OnHide', nil)
	hook('ShowUIPanel', function(...)
		if arg[1] == AuctionFrame then return AuctionFrame:Show() end
		return orig.ShowUIPanel(unpack(arg))
	end)
	hook('GetOwnerAuctionItems', GetOwnerAuctionItems)
	hook('SetItemRef', SetItemRef)
	hook('UseContainerItem', UseContainerItem)
	hook('AuctionFrameAuctions_OnEvent', AuctionFrameAuctions_OnEvent)
end

do
	local function cost_label(cost)
		local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
		label = label..(cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE)
		label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
		return label
	end
	function ADDON_LOADED.Blizzard_CraftUI()
		hook('CraftFrame_SetSelection', function(...)
			local results = {orig.CraftFrame_SetSelection(unpack(arg))}
			local id = GetCraftSelectionIndex()
			local reagent_count = GetCraftNumReagents(id)
			local total_cost = 0
			for i=1,reagent_count do
				local link = GetCraftReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetCraftReagentInfo(id, i))
				local _, price, limited = cache.merchant_info(item_id)
				local value = price and not limited and price or history.value(item_id..':'..suffix_id)
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
	function ADDON_LOADED.Blizzard_TradeSkillUI()
		hook('TradeSkillFrame_SetSelection', function(...)
			local results = {orig.TradeSkillFrame_SetSelection(unpack(arg))}
			local id = GetTradeSkillSelectionIndex()
			local reagent_count = GetTradeSkillNumReagents(id)
			local total_cost = 0
			for i=1,reagent_count do
				local link = GetTradeSkillReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetTradeSkillReagentInfo(id, i))
				local _, price, limited = cache.merchant_info(item_id)
				local value = price and not limited and price or history.value(item_id..':'..suffix_id)
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

function AuctionFrameAuctions_OnEvent(...)
    if AuctionFrameAuctions:IsVisible() then
        return orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end