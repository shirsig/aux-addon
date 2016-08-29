--aux_account_settings = {} -- TODO clean up the mess of savedvariables
--aux_character_settings = {}

module()

public.version = '5.0.0'

function public.log(...) temp=arg
	local msg = '[aux]'
	for i = 1, arg.n do msg = msg..' '..tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..msg)
end

do
	local modules = {core={env=M, interface=I}}
	_G.aux = setmetatable({}, {
		__metatable = false,
		__index = function(_, key) return modules[key].interface end,
		__newindex = error,
		__call = function(self, name)
			if not modules[name] then
				module()
				private.aux = self
				modules[name] = {env=M, interface=I}
			end
			modules[name].env.import(modules.core.interface)
			setfenv(2, modules[name].env)
		end,
	})
end
local aux = aux

local bids_loaded
function public.bids_loaded.get() return bids_loaded end

local current_owner_page
function public.current_owner_page.get() return current_owner_page end

--do
--	local mt = {__call=function(self,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20) return self.f(unpack(self)) end}
--	function public.F.get(arg) arg.f = tremove(arg, 1) return setmetatable(arg, mt) end
--end

do
	local pool, overflow_pool, tmp = {}, setmetatable({}, {__mode='v'}), {}

	CreateFrame'Frame':SetScript('OnUpdate', function()
		for t in tmp do recycle(t) end
		wipe(tmp)
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
			tinsert(overflow_pool, t)
		end
--		log(getn(pool), '-', getn(overflow_pool))
	end
	
	function public.t.get()
		return tremove(pool) or tremove(overflow_pool, next(overflow_pool)) or {}
	end
	function public.tt.get()
		local t = tremove(pool) or tremove(overflow_pool, next(overflow_pool)) or {}
		tmp[t] = true
		return t
	end

	function public.modifier_mt(f)
		local function apply(self, value)
			recycle(self)
			return f(value)
		end
		return {__call=apply, __sub=apply}
	end
	do
		local mt = modifier_mt(function(t) tmp[t] = true; return t end)
		public.temp
		{
			get = function() return setmetatable(t, mt) end,
			set = function(t) tmp[t] = true end,
		}
	end
	do
		local mt = modifier_mt(function(t) tmp[t] = nil; return t end)
		public.perm
		{
			get = function() return setmetatable(t, mt) end,
			set = function(t) tmp[t] = nil end,
		}
	end

	local function insert_keys(t,k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,k17,k18,k19,k20,overflow)
		if k1 == nil then return end; t[k1] = true
		if k2 == nil then return end; t[k2] = true
		if k3 == nil then return end; t[k3] = true
		if k4 == nil then return end; t[k4] = true
		if k5 == nil then return end; t[k5] = true
		if k6 == nil then return end; t[k6] = true
		if k7 == nil then return end; t[k7] = true
		if k8 == nil then return end; t[k8] = true
		if k9 == nil then return end; t[k9] = true
		if k10 == nil then return end; t[k10] = true
		if k11 == nil then return end; t[k11] = true
		if k12 == nil then return end; t[k12] = true
		if k13 == nil then return end; t[k13] = true
		if k14 == nil then return end; t[k14] = true
		if k15 == nil then return end; t[k15] = true
		if k16 == nil then return end; t[k16] = true
		if k17 == nil then return end; t[k17] = true
		if k18 == nil then return end; t[k18] = true
		if k19 == nil then return end; t[k19] = true
		if k20 == nil then return end; t[k20] = true
		if overflow ~= nil then error('Overflow.') end
	end
	local function insert_values(t,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,overflow)
		local n = getn(t)
		if v1 == nil then return t end; t[n + 1] = v1
		if v2 == nil then table.setn(t, n + 1); return end; t[n + 2] = v2
		if v3 == nil then table.setn(t, n + 2); return end; t[n + 3] = v3
		if v4 == nil then table.setn(t, n + 3); return end; t[n + 4] = v4
		if v5 == nil then table.setn(t, n + 4); return end; t[n + 5] = v5
		if v6 == nil then table.setn(t, n + 5); return end; t[n + 6] = v6
		if v7 == nil then table.setn(t, n + 6); return end; t[n + 7] = v7
		if v8 == nil then table.setn(t, n + 7); return end; t[n + 8] = v8
		if v9 == nil then table.setn(t, n + 8); return end; t[n + 9] = v9
		if v10 == nil then table.setn(t, n + 9); return end; t[n + 10] = v10
		if v11 == nil then table.setn(t, n + 10); return end; t[n + 11] = v11
		if v12 == nil then table.setn(t, n + 11); return end; t[n + 12] = v12
		if v13 == nil then table.setn(t, n + 12); return end; t[n + 13] = v13
		if v14 == nil then table.setn(t, n + 13); return end; t[n + 14] = v14
		if v15 == nil then table.setn(t, n + 14); return end; t[n + 15] = v15
		if v16 == nil then table.setn(t, n + 15); return end; t[n + 16] = v16
		if v17 == nil then table.setn(t, n + 16); return end; t[n + 17] = v17
		if v18 == nil then table.setn(t, n + 17); return end; t[n + 18] = v18
		if v19 == nil then table.setn(t, n + 18); return end; t[n + 19] = v19
		if v20 == nil then table.setn(t, n + 19); return end; t[n + 20] = v20; table.setn(t, n + 20)
		if overflow ~= nil then error('Overflow.') end
	end
	local function insert_pairs(t,k1,v1,k2,v2,k3,v3,k4,v4,k5,v5,k6,v6,k7,v7,k8,v8,k9,v9,k10,v10,overflow)
		if k1 == nil then return end t[k1] = v1
		if k2 == nil then return end t[k2] = v2
		if k3 == nil then return end t[k3] = v3
		if k4 == nil then return end t[k4] = v4
		if k5 == nil then return end t[k5] = v5
		if k6 == nil then return end t[k6] = v6
		if k7 == nil then return end t[k7] = v7
		if k8 == nil then return end t[k8] = v8
		if k9 == nil then return end t[k9] = v9
		if k10 == nil then return end t[k10] = v10
		if overflow ~= nil then error('Overflow.') end
	end
	local function constructor_mt(insert)
		return {
			__call=function(self,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,overflow)
				local t, n = rawget(self, 't') or t, rawget(self, 'n') or 1
				insert(t,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,overflow)
				if n > 1 then
					self.t, self.n = t, n - 1
					return self
				end
				return t
			end,
			__index=function(self, key) self.n = key; return self end,
		}
	end
	local set_mt, list_mt, table_mt = constructor_mt(insert_keys), constructor_mt(insert_values), constructor_mt(insert_pairs)
	public()
	function set.get() return setmetatable(tt, set_mt) end
	function list.get() return setmetatable(tt, list_mt) end
	function T.get() return setmetatable(tt, table_mt) end
	private()
end

local event_frame = CreateFrame('Frame')
for event in temp-set('ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE') do
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
		else
			M[event]()
		end
	end)
end

tab_info = t
do
	for _, info in temp-list(temp-list('search_tab', 'Search'), temp-list('post_tab', 'Post'), temp-list('auctions_tab', 'Auctions'), temp-list('bids_tab', 'Bids')) do
		local tab = T('name', info[2])
		local env = (function() aux(info[1]) return M end)()
		function env.private.OPEN.set(f) tab.OPEN = f end
		function env.private.CLOSE.set(f) tab.CLOSE = f end
		function env.private.USE_ITEM.set(f) tab.USE_ITEM = f end
		function env.private.CLICK_LINK.set(f) tab.CLICK_LINK = f end
		function env.public.ACTIVE.get() return tab == active_tab end
		tinsert(tab_info, tab)
	end
end

do
	local index
	function private.active_tab.get() return tab_info[index] end
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
	local realm = GetCVar('realmName')
	return not current and index(_G.aux_characters, realm, name) or UnitName 'player' == name
end

function public.neutral_faction()
	return not UnitFactionGroup('npc')
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
	aux.post.stop()
	aux.stack.stop()
	aux.scan.abort()
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
	AuctionFrame:UnregisterEvent('AUCTION_HOUSE_SHOW')
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
			for i = 1, reagent_count do
				local link = GetCraftReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = aux.info.parse_link(link)
				local count = select(3, GetCraftReagentInfo(id, i))
				local _, price, limited = aux.cache.merchant_info(item_id)
				local value = price and not limited and price or aux.history.value(item_id..':'..suffix_id)
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
			for i = 1, reagent_count do
				local link = GetTradeSkillReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = aux.info.parse_link(link)
				local count = select(3, GetTradeSkillReagentInfo(id, i))
				local _, price, limited = aux.cache.merchant_info(item_id)
				local value = price and not limited and price or aux.history.value(item_id..':'..suffix_id)
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