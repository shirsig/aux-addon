module 'aux'

local T = require 'T'

local info = require 'aux.util.info'
local money = require 'aux.util.money'
local history = require 'aux.core.history'
local stack = require 'aux.core.stack'
local post = require 'aux.core.post'
local scan = require 'aux.core.scan'
local search_tab = require 'aux.tabs.search'

_G.aux_scale = 1

_G.aux = {
	character = {},
	faction = {},
	realm = {},
	account = {},
}

M.print = T.vararg-function(arg)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<aux> ' .. join(map(arg, tostring), ' '))
end

local bids_loaded
function M.bids_loaded() return bids_loaded end

local current_owner_page
function M.current_owner_page() return current_owner_page end

local event_frame = CreateFrame'Frame'
for event in pairs(T.temp-T.set('ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE')) do
	event_frame:RegisterEvent(event)
end

local set_handler = {}
M.handle = setmetatable({}, {__metatable=false, __newindex=function(_, k, v) set_handler[k](v) end})

do
	local handlers, handlers2 = {}, {}
	function set_handler.LOAD(f)
		tinsert(handlers, f)
	end
	function set_handler.LOAD2(f)
		tinsert(handlers2, f)
	end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			if arg1 == 'Blizzard_AuctionUI' then
				Blizzard_AuctionUI()
			elseif arg1 == 'Blizzard_CraftUI' then
				Blizzard_CraftUI()
			elseif arg1 == 'Blizzard_TradeSkillUI' then
				Blizzard_TradeSkillUI()
			end
		elseif event == 'VARIABLES_LOADED' then
			for _, f in pairs(handlers) do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in pairs(handlers2) do f() end
			print('loaded - /aux')
		else
			_M[event]()
		end
	end)
end

do
	local cache = {}
	function handle.LOAD()
		cache.account = aux.account
		do
			local key = format('%s|%s', GetCVar'realmName', UnitName'player')
			aux.character[key] = aux.character[key] or {}
			cache.character = aux.character[key]
		end
		do
			local key = GetCVar'realmName'
			aux.realm[key] = aux.realm[key] or {}
			cache.realm = aux.realm[key]
		end
	end
	function handle.LOAD2()
		do
			local key = format('%s|%s', GetCVar'realmName', UnitFactionGroup'player')
			aux.faction[key] = aux.faction[key] or {}
			cache.faction = aux.faction[key]
		end
	end
	for scope in pairs(T.temp-T.set('character', 'faction', 'realm', 'account')) do
		local scope = scope
		M[scope .. '_data'] = function(key, init)
			if not cache[scope] then error('Cache for ' .. scope .. ' data not ready.', 2) end
			cache[scope][key] = cache[scope][key] or {}
			for k, v in pairs(init or T.empty) do
				if cache[scope][key][k] == nil then
					cache[scope][key][k] = v
				end
			end
			return cache[scope][key]
		end
	end
end

tab_info = {}
function M.TAB(name)
	local tab = T.map('name', name)
	local tab_event = {
		OPEN = function(f) tab.OPEN = f end,
		CLOSE = function(f) tab.CLOSE = f end,
		USE_ITEM = function(f) tab.USE_ITEM = f end,
		CLICK_LINK = function(f) tab.CLICK_LINK = f end,
	}
	tinsert(tab_info, tab)
	return setmetatable({}, {__metatable=false, __newindex=function(_, k, v) tab_event[k](v) end})
end

do
	local index
	function get_active_tab() return tab_info[index] end
	function on_tab_click(i)
		CloseDropDownMenus()
		do (index and get_active_tab().CLOSE or nop)() end
		index = i
		do (index and get_active_tab().OPEN or nop)() end
	end
end

SetItemRef = T.vararg-function(arg)
	if arg[3] ~= 'RightButton' or not index(get_active_tab(), 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return orig.SetItemRef(unpack(arg))
	end
	local item_info = info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))
	if item_info then
		return get_active_tab().CLICK_LINK(item_info)
	end
end

UseContainerItem = T.vararg-function(arg)
	if modified() or not get_active_tab() then
		return orig.UseContainerItem(unpack(arg))
	end
	local item_info = info.container_item(arg[1], arg[2])
	if item_info and get_active_tab().USE_ITEM then
		get_active_tab().USE_ITEM(item_info)
	end
end

M.orig = setmetatable({[_G]=T.acquire()}, {__index=function(self, key) return self[_G][key] end})
M.hook = T.vararg-function(arg)
	local name, object, handler
	if getn(arg) == 3 then
		name, object, handler = unpack(arg)
	else
		object, name, handler = _G, unpack(arg)
	end
	handler = handler or getfenv(3)[name]
	orig[object] = orig[object] or T.acquire()
	assert(not orig[object][name], '"' .. name .. '" is already hooked into.')
	orig[object][name], object[name] = object[name], handler
	return hook
end

do
	local locked
	function M.bid_in_progress() return locked end
	function M.place_bid(type, index, amount, on_success)
		if locked then return end
		local money = GetMoney()
		PlaceAuctionBid(type, index, amount)
		if money >= amount then
			locked = true
			local send_signal, signal_received = signal()
			thread(when, signal_received, function()
				do (on_success or nop)() end
				locked = false
			end)
			thread(when, later(5), send_signal)
			event_listener('CHAT_MSG_SYSTEM', function(kill)
				if arg1 == ERR_AUCTION_BID_PLACED then
					send_signal()
					kill()
				end
			end)
		end
	end
end

do
	local locked
	function M.cancel_in_progress() return locked end
	function M.cancel_auction(index, on_success)
		if locked then return end
		locked = true
		CancelAuction(index)
		local send_signal, signal_received = signal()
		thread(when, signal_received, function()
			do (on_success or nop)() end
			locked = false
		end)
		thread(when, later(5), send_signal)
		event_listener('CHAT_MSG_SYSTEM', function(kill)
			if arg1 == ERR_AUCTION_REMOVED then
				send_signal()
				kill()
			end
		end)
	end
end

function handle.LOAD2()
	AuxFrame:SetScale(aux_scale)
end

function AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	AuxFrame:Show()
	set_tab(1)
end

function AUCTION_HOUSE_CLOSED()
	bids_loaded = false
	current_owner_page = nil
	post.stop()
	stack.stop()
	scan.abort()
	set_tab()
	AuxFrame:Hide()
end

function AUCTION_BIDDER_LIST_UPDATE()
	bids_loaded = true
end

do
	local last_owner_page_requested
	function GetOwnerAuctionItems(index)
		local page = index
		last_owner_page_requested = index
		return orig.GetOwnerAuctionItems(index)
	end
	function AUCTION_OWNED_LIST_UPDATE()
		current_owner_page = last_owner_page_requested or 0
	end
end

function Blizzard_AuctionUI()
	AuctionFrame:UnregisterEvent('AUCTION_HOUSE_SHOW')
	AuctionFrame:SetScript('OnHide', nil)
	hook('ShowUIPanel', T.vararg-function(arg)
		if arg[1] == AuctionFrame then return AuctionFrame:Show() end
		return orig.ShowUIPanel(unpack(arg))
	end)
	hook 'GetOwnerAuctionItems' 'SetItemRef' 'UseContainerItem' 'AuctionFrameAuctions_OnEvent'
end

do
	local function cost_label(cost)
		local label = LIGHTYELLOW_FONT_COLOR_CODE .. '(Total Cost: ' .. FONT_COLOR_CODE_CLOSE
		label = label .. (cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE .. '---' .. FONT_COLOR_CODE_CLOSE)
		label = label .. LIGHTYELLOW_FONT_COLOR_CODE .. ')' .. FONT_COLOR_CODE_CLOSE
		return label
	end
	local function hook_quest_item(f)
		f:SetScript('OnMouseUp', function()
			if arg1 == 'RightButton' then
				if get_active_tab() then
					set_tab(1)
					search_tab.set_filter(_G[this:GetName() .. 'Name']:GetText() .. '/exact')
					search_tab.execute(nil, false)
				end
			end
		end)
	end
	function Blizzard_CraftUI()
		hook('CraftFrame_SetSelection', T.vararg-function(arg)
			local ret = T.temp-T.list(orig.CraftFrame_SetSelection(unpack(arg)))
			local id = GetCraftSelectionIndex()
			local total_cost = 0
			for i = 1, GetCraftNumReagents(id) do
				local link = GetCraftReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetCraftReagentInfo(id, i))
				local _, price, limited = info.merchant_info(item_id)
				local value = price and not limited and price or history.value(item_id .. ':' .. suffix_id)
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
		for i = 1, 8 do
			hook_quest_item(_G['CraftReagent' .. i])
		end
	end
	function Blizzard_TradeSkillUI()
		hook('TradeSkillFrame_SetSelection', T.vararg-function(arg)
			local ret = T.temp-T.list(orig.TradeSkillFrame_SetSelection(unpack(arg)))
			local id = GetTradeSkillSelectionIndex()
			local total_cost = 0
			for i = 1, GetTradeSkillNumReagents(id) do
				local link = GetTradeSkillReagentItemLink(id, i)
				if not link then
					total_cost = nil
					break
				end
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetTradeSkillReagentInfo(id, i))
				local _, price, limited = info.merchant_info(item_id)
				local value = price and not limited and price or history.value(item_id .. ':' .. suffix_id)
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
		for i = 1, 8 do
			hook_quest_item(_G['TradeSkillReagent' .. i])
		end
	end
end

AuctionFrameAuctions_OnEvent = T.vararg-function(arg)
    if AuctionFrameAuctions:IsVisible() then
	    return orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end