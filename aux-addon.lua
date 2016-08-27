--aux_account_settings = {} -- TODO clean up the mess of savedvariables
--aux_character_settings = {}

module()

public.version = '5.0.0'

do
	local modules = {core={env=M, interface=I}}
	_G.aux = setmetatable({}, {
		__metatable = false,
		__index = function(_, key) return modules[key].interface end,
		__newindex = function() end,
		__call = function(_, name)
			if not modules[name] then
				module(aux.core)
				modules[name] = {env=M, interface=I}
			end
			setfenv(2, modules[name].env)
		end,
	})
end

local bids_loaded
function public.bids_loaded.get() return bids_loaded end

local current_owner_page
function public.current_owner_page.get() return current_owner_page end

public.empty = setmetatable({}, {__metatable=false, __newindex=error})

do
	local pool, overflow_pool, transient = {}, setmetatable({}, {__mode='v'}), {}

	CreateFrame'Frame':SetScript('OnUpdate', function()
		for t in transient do recycle(t) end
		wipe(transient)
	end)

	function public.wipe(t) -- like with a cloth or something
		for k in t do t[k] = nil end
		t.reset = 1
		t.reset = nil
		table.setn(t, 0)
		return setmetatable(t, nil)
	end

	function public.recycle(t)
		wipe(t)
		if getn(pool) < 50 then
			tinsert(pool, t)
		else
			overflow_pool[t] = true
		end
--		log(getn(table_pool), '-', getn(weak_pool))
	end

	function public.t.get()
		return tremove(pool) or tremove(overflow_pool, next(overflow_pool)) or {}
	end
	function public.tt.get()
		local t = tremove(pool) or tremove(overflow_pool, next(overflow_pool)) or {}
		transient[t] = true
		return t
	end

	function public.operator_mt(f)
		local function apply(self, value)
			local raw = self.raw
			recycle(self)
			return raw and setmetatable(f(value), nil) or f(value)
		end
		return {__unm=function(self) self.raw = true end, __call=apply, __sub=apply}
	end
	do
		local mt = operator_mt(function(t) transient[t] = true return t end)
		public.temp
		{
			get = function() return setmetatable(t, mt) end,
			set = function(t) return make_transient(t) end,
		}
	end
	do
		local mt = operator_mt(function(t) transient[t] = nil return t end)
		public.perm
		{
			get = function() return setmetatable(t, mt) end,
			set = function(t) return make_persistent(t) end,
		}
	end

	local function insert_keys(t,k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,k17,k18,k19,k20,overflow)
		if overflow ~= nil then error 'Overflow.' end
		if k1 ~= nil then t[k1] = true end
		if k2 ~= nil then t[k2] = true end
		if k3 ~= nil then t[k3] = true end
		if k4 ~= nil then t[k4] = true end
		if k5 ~= nil then t[k5] = true end
		if k6 ~= nil then t[k6] = true end
		if k7 ~= nil then t[k7] = true end
		if k8 ~= nil then t[k8] = true end
		if k9 ~= nil then t[k9] = true end
		if k10 ~= nil then t[k10] = true end
		if k11 ~= nil then t[k11] = true end
		if k12 ~= nil then t[k12] = true end
		if k13 ~= nil then t[k13] = true end
		if k14 ~= nil then t[k14] = true end
		if k15 ~= nil then t[k15] = true end
		if k16 ~= nil then t[k16] = true end
		if k17 ~= nil then t[k17] = true end
		if k18 ~= nil then t[k18] = true end
		if k19 ~= nil then t[k19] = true end
		if k20 ~= nil then t[k20] = true end
		return t
	end
	local function insert_values(t,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,overflow)
		if overflow ~= nil then error 'Overflow.' end
		if v1 ~= nil then tinsert(t, v1) end
		if v2 ~= nil then tinsert(t, v2) end
		if v3 ~= nil then tinsert(t, v3) end
		if v4 ~= nil then tinsert(t, v4) end
		if v5 ~= nil then tinsert(t, v5) end
		if v6 ~= nil then tinsert(t, v6) end
		if v7 ~= nil then tinsert(t, v7) end
		if v8 ~= nil then tinsert(t, v8) end
		if v9 ~= nil then tinsert(t, v9) end
		if v10 ~= nil then tinsert(t, v10) end
		if v11 ~= nil then tinsert(t, v11) end
		if v12 ~= nil then tinsert(t, v12) end
		if v13 ~= nil then tinsert(t, v13) end
		if v14 ~= nil then tinsert(t, v14) end
		if v15 ~= nil then tinsert(t, v15) end
		if v16 ~= nil then tinsert(t, v16) end
		if v17 ~= nil then tinsert(t, v17) end
		if v18 ~= nil then tinsert(t, v18) end
		if v19 ~= nil then tinsert(t, v19) end
		if v20 ~= nil then tinsert(t, v20) end
		return t
	end
	local function insert_pairs(t,k1,v1,k2,v2,k3,v3,k4,v4,k5,v5,k6,v6,k7,v7,k8,v8,k9,v9,k10,v10,overflow)
		if overflow ~= nil then error 'Overflow.' end
		if k1 ~= nil then t[k1] = v1 end
		if k2 ~= nil then t[k2] = v2 end
		if k3 ~= nil then t[k3] = v3 end
		if k4 ~= nil then t[k4] = v4 end
		if k5 ~= nil then t[k5] = v5 end
		if k6 ~= nil then t[k6] = v6 end
		if k7 ~= nil then t[k7] = v7 end
		if k8 ~= nil then t[k8] = v8 end
		if k9 ~= nil then t[k9] = v9 end
		if k10 ~= nil then t[k10] = v10 end
		return t
	end
	local function collector_mt(f)
		return {__call=f, __unm=function(self) return setmetatable(self, nil) end}
	end
	local set_mt, list_mt, object_mt = collector_mt(insert_keys), collector_mt(insert_values), collector_mt(insert_pairs)
	public()
	function list() return setmetatable(t, list_mt) end
	function set() return setmetatable(t, set_mt) end
	function object() return setmetatable(t, object_mt) end
	private()
end

local event_frame = CreateFrame 'Frame'
for event in -temp-set('ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE') do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = t
do
	local handlers, handlers2 = t, t
	function public.LOAD.set(f) tinsert(handlers, f) end
	function public.LOAD2.set(f) tinsert(handlers2, f) end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			if ADDON_LOADED[arg1] then ADDON_LOADED[arg1]() end
		elseif event == 'VARIABLES_LOADED' then
			for _, f in handlers do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in handlers2 do f() end
			log('v'..version..' loaded.')

			-- TODO test __lt
		else
			M[event]()
		end
	end)
end

function public.log(...) temp=arg
	local msg = '[aux]'
	for i=1,arg.n do msg = msg..' '..tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end

tab_info = t
do
	local data = -temp-list('search_tab', 'Search', 'post_tab', 'Post', 'auctions_tab', 'Auctions', 'bids_tab', 'Bids')
	for i=1,getn(data),2 do
		log(data[i], data[i + 1])
		local tab = -object('name', data[i + 1])
		local env = (function() module(data[i]) return M end)()
		function env.OPEN.set(f) tab.OPEN = f end
		function env.CLOSE.set(f) tab.CLOSE = f end
		function env.USE_ITEM.set(f) tab.USE_ITEM = f end
		function env.CLICK_LINK.set(f) tab.CLICK_LINK = f end
		function env.public.ACTIVE.get() return tab == active_tab end
		tinsert(tab_info, tab)
	end
end

do
	local index
	function active_tab.get() return tab_info[index] end
	function on_tab_click(i)
		call(index and active_tab.CLOSE)
		index = i
		call(index and active_tab.OPEN)
	end
end

function SetItemRef(...) temp=arg
	if arg[3] ~= 'RightButton' or not index(active_tab, 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return orig.SetItemRef(unpack(arg))
	end
	for item_info in present(info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))) do
		return active_tab.CLICK_LINK(item_info)
	end
end

function UseContainerItem(...) temp=arg
	if modified or not index(active_tab, 'USE_ITEM') then
		return orig.UseContainerItem(unpack(arg))
	end
	for item_info in present(info.container_item(arg[1], arg[2])) do
		return active_tab.USE_ITEM(item_info)
	end
end

public.orig = setmetatable({[_G]=t}, {__index=function(self, key) return self[_G][key] end})
function public.hook(...) temp=arg
	local name, object, handler
	if arg.n == 3 then
		name, object, handler = unpack(arg)
	else
		object, name, handler = _G, unpack(arg)
	end
	handler = handler or getfenv(2)[name]
	orig[object] = orig[object] or t
	assert(not orig[object][name], '"'..name..'" is already hooked into.')
	orig[object][name], object[name] = object[name], handler
	return hook
end

do
	local locked
	function public.bid_in_progress.get() return locked end
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
	function public.cancel_in_progress.get() return locked end
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
	return not current and index(_G.aux_characters, realm, name) or UnitName 'player' == name
end

function public.neutral_faction()
	return not UnitFactionGroup 'npc'
end

function public.min_bid_increment(current_bid)
	return max(1, floor(current_bid / 100) * 5)
end

function AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	aux_frame:Show()
	tab = 1
end

function AUCTION_HOUSE_CLOSED()
	bids_loaded = false
	current_owner_page = nil
	post.stop()
	stack.stop()
	scan.abort()
	tab = nil
	aux_frame:Hide()
end

function AUCTION_BIDDER_LIST_UPDATE()
	bids_loaded = true
end

do
	local last_owner_page_requested
	function GetOwnerAuctionItems(...) temp=arg
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
	hook('ShowUIPanel', function(...) temp=arg
		if arg[1] == AuctionFrame then return AuctionFrame:Show() end
		return orig.ShowUIPanel(unpack(arg))
	end)
	hook 'GetOwnerAuctionItems' 'SetItemRef' 'UseContainerItem' 'AuctionFrameAuctions_OnEvent'
end

do
	local function cost_label(cost)
		local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
		label = label..(cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE)
		label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
		return label
	end
	function ADDON_LOADED.Blizzard_CraftUI()
		hook('CraftFrame_SetSelection', function(...) temp=arg
			local results = temp-{orig.CraftFrame_SetSelection(unpack(arg))}
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
		hook('TradeSkillFrame_SetSelection', function(...) temp=arg
			local results = temp-{orig.TradeSkillFrame_SetSelection(unpack(arg))}
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

function AuctionFrameAuctions_OnEvent(...) temp=arg
    if AuctionFrameAuctions:IsVisible() then
        return orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end