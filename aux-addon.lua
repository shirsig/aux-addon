--aux_account_settings = {} -- TODO clean up the mess of savedvariables
--aux_character_settings = {}

do
	local modules = {}
	local mt = {__metatable=false, __index=function(_, key) return modules[key]._I end, __newindex=error}
	aux = function(name)
		if not modules[name] then
			(function()
				modules[name] = module and _E
				import (green_t)
				private.aux = setmetatable(t, mt)
				private.p.set = function(v) inspect(nil, v) end
			end)()
		end
		modules[name].import (modules.core._I)
		setfenv(2, modules[name])
	end
end

aux 'core'

public.version = '5.0.0'

function public.print(...) auto[arg] = true
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '[aux] ' .. join(map(arg, tostring), ' '))
end

local bids_loaded
function public.bids_loaded.get() return bids_loaded end

local current_owner_page
function public.current_owner_page.get() return current_owner_page end

local event_frame = CreateFrame('Frame')

for event in temp-S('ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE') do
	event_frame:RegisterEvent(event)
end

private.ADDON_LOADED = t
do
	local handlers, handlers2 = t, t
	function public.LOAD.set(f)
		tinsert(handlers, f)
	end
	function public.LOAD2.set(f)
		tinsert(handlers2, f)
	end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			(ADDON_LOADED[arg1] or nop)()
		elseif event == 'VARIABLES_LOADED' then
			for _, f in handlers do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in handlers2 do f() end
			print('v' .. version .. ' loaded.')
		else
			_E[event]()
		end
	end)
end

private.tab_info = t
do
	for _, info in temp-A(temp-A('search_tab', 'Search'), temp-A('post_tab', 'Post'), temp-A('auctions_tab', 'Auctions'), temp-A('bids_tab', 'Bids')) do
		local tab = T('name', info[2])
		local env = (function() _G.aux(info[1]) return _E end)()
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
	function private.on_tab_click(i)
		do (index and active_tab.CLOSE or nop)() end
		index = i
		do (index and active_tab.OPEN or nop)() end
	end
end

function private.SetItemRef(...) auto[arg] = true
	if arg[3] ~= 'RightButton' or not index(active_tab, 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return orig.SetItemRef(unpack(arg))
	end
	for item_info in present(aux.info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))) do
		return active_tab.CLICK_LINK(item_info)
	end
end

function private.UseContainerItem(...) auto[arg] = true
	if modified or not index(active_tab, 'USE_ITEM') then
		return orig.UseContainerItem(unpack(arg))
	end
	for item_info in present(aux.info.container_item(arg[1], arg[2])) do
		return active_tab.USE_ITEM(item_info)
	end
end

public.orig = setmetatable({[_G]=t}, {__index=function(self, key) return self[_G][key] end})
function public.hook(...) auto[arg] = true
	local name, object, handler
	if arg.n == 3 then
		name, object, handler = unpack(arg)
	else
		object, name, handler = _G, unpack(arg)
	end
	handler = handler or getfenv(2)[name]
	orig[object] = orig[object] or t
	assert(not orig[object][name], '"' .. name .. '" is already hooked into.')
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
					(on_success or nop)()
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
				(on_success or nop)()
				locked = false
				kill()
			end
		end)
	end
end

function public.is_player(name, current)
	local realm = GetCVar('realmName')
	return not current and index(aux_characters, realm, name) or UnitName('player') == name
end

function public.neutral_faction()
	return not UnitFactionGroup('npc')
end

function public.min_bid_increment(current_bid)
	return max(1, floor(current_bid / 100) * 5)
end

function private.AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	aux_frame:Show()
	tab = 1
end

function private.AUCTION_HOUSE_CLOSED()
	bids_loaded = false
	current_owner_page = nil
	aux.post.stop()
	aux.stack.stop()
	aux.scan.abort()
	tab = nil
	aux_frame:Hide()
end

function private.AUCTION_BIDDER_LIST_UPDATE()
	bids_loaded = true
end

do
	local last_owner_page_requested
	function private.GetOwnerAuctionItems(...) auto[arg] = true
		local page = arg[1]
		last_owner_page_requested = page
		return orig.GetOwnerAuctionItems(unpack(arg))
	end
	function private.AUCTION_OWNED_LIST_UPDATE()
		current_owner_page = last_owner_page_requested or 0
	end
end

function ADDON_LOADED.Blizzard_AuctionUI()
	AuctionFrame:UnregisterEvent('AUCTION_HOUSE_SHOW')
	AuctionFrame:SetScript('OnHide', nil)
	hook('ShowUIPanel', function(...) auto[arg] = true
		if arg[1] == AuctionFrame then return AuctionFrame:Show() end
		return orig.ShowUIPanel(unpack(arg))
	end)
	hook 'GetOwnerAuctionItems' 'SetItemRef' 'UseContainerItem' 'AuctionFrameAuctions_OnEvent'
end

do
	local function cost_label(cost)
		local label = LIGHTYELLOW_FONT_COLOR_CODE .. '(Total Cost: ' .. FONT_COLOR_CODE_CLOSE
		label = label .. (cost and aux.money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE)
		label = label .. LIGHTYELLOW_FONT_COLOR_CODE .. ')' .. FONT_COLOR_CODE_CLOSE
		return label
	end
	function ADDON_LOADED.Blizzard_CraftUI()
		hook('CraftFrame_SetSelection', function(...) auto[arg] = true
			local ret = temp-A(orig.CraftFrame_SetSelection(unpack(arg)))
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
				local value = price and not limited and price or aux.history.value(item_id .. ':' .. suffix_id)
				if not value then
					total_cost = nil
					break
				else
					total_cost = total_cost + value * count
				end
			end
			CraftReagentLabel:SetText(SPELL_REAGENTS .. ' ' .. cost_label(total_cost))
			return unpack(ret)
		end)
	end
	function ADDON_LOADED.Blizzard_TradeSkillUI()
		hook('TradeSkillFrame_SetSelection', function(...) auto[arg] = true
			local ret = temp-A(orig.TradeSkillFrame_SetSelection(unpack(arg)))
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
				local value = price and not limited and price or aux.history.value(item_id .. ':' .. suffix_id)
				if not value then
					total_cost = nil
					break
				else
					total_cost = total_cost + value * count
				end
			end
			TradeSkillReagentLabel:SetText(SPELL_REAGENTS .. ' ' .. cost_label(total_cost))
			return unpack(ret)
		end)
	end
end

function private.AuctionFrameAuctions_OnEvent(...) auto[arg] = true
    if AuctionFrameAuctions:IsVisible() then
	    return orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end