module 'aux'

include 'T'

local info = require 'aux.util.info'
local money = require 'aux.util.money'
local cache = require 'aux.core.cache'
local history = require 'aux.core.history'
local stack = require 'aux.core.stack'
local post = require 'aux.core.post'
local scan = require 'aux.core.scan'

--aux_account_settings = {} -- TODO clean up the mess of savedvariables
--aux_character_settings = {}

function M.set_p(v)
	inspect(nil, v)
end

function M.print(...)
	temp(arg)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '[aux] ' .. join(map(arg, tostring), ' '))
end

local bids_loaded
function M.get_bids_loaded() return bids_loaded end

local current_owner_page
function M.get_current_owner_page() return current_owner_page end

local event_frame = CreateFrame('Frame')

for event in temp-S('ADDON_LOADED', 'VARIABLES_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE') do
	event_frame:RegisterEvent(event)
end

ADDON_LOADED = T
do
	local handlers, handlers2 = T, T
	function M.set_LOAD(f)
		tinsert(handlers, f)
	end
	function M.set_LOAD2(f)
		tinsert(handlers2, f)
	end
	event_frame:SetScript('OnEvent', function()
		if event == 'ADDON_LOADED' then
			(ADDON_LOADED[arg1] or nop)()
		elseif event == 'VARIABLES_LOADED' then
			for _, f in handlers do f() end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in handlers2 do f() end
		else
			_M[event]()
		end
	end)
end

tab_info = T
function M.TAB(name)
	local tab = O('name', name)
	local env = getfenv(2)
	function env.set_OPEN(f) tab.OPEN = f end
	function env.set_CLOSE(f) tab.CLOSE = f end
	function env.set_USE_ITEM(f) tab.USE_ITEM = f end
	function env.set_CLICK_LINK(f) tab.CLICK_LINK = f end
	function env.M.get_ACTIVE() return tab == active_tab end
	tinsert(tab_info, tab)
end

do
	local index
	function get_active_tab() return tab_info[index] end
	function on_tab_click(i)
		do (index and active_tab.CLOSE or nop)() end
		index = i
		do (index and active_tab.OPEN or nop)() end
	end
end

function SetItemRef(...)
	temp(arg)
	if arg[3] ~= 'RightButton' or not index(active_tab, 'CLICK_LINK') or not strfind(arg[1], '^item:%d+') then
		return orig.SetItemRef(unpack(arg))
	end
	local item_info = info.item(tonumber(select(3, strfind(arg[1], '^item:(%d+)'))))
	if item_info then
		return active_tab.CLICK_LINK(item_info)
	end
end

function UseContainerItem(...)
	temp(arg)
	if modified or not index(active_tab, 'USE_ITEM') then
		return orig.UseContainerItem(unpack(arg))
	end
	local item_info = info.container_item(arg[1], arg[2])
	if item_info then
		return active_tab.USE_ITEM(item_info)
	end
end

M.orig = setmetatable({[_G]=T}, {__index=function(self, key) return self[_G][key] end})
function M.hook(...)
	temp(arg)
	local name, object, handler
	if arg.n == 3 then
		name, object, handler = unpack(arg)
	else
		object, name, handler = _G, unpack(arg)
	end
	handler = handler or getfenv(2)[name]
	orig[object] = orig[object] or T
	assert(not orig[object][name], '"' .. name .. '" is already hooked into.')
	orig[object][name], object[name] = object[name], handler
	return hook
end

do
	local locked
	function M.get_bid_in_progress() return locked end
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
	function M.get_cancel_in_progress() return locked end
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

function M.is_player(name, current)
	local realm = GetCVar'realmName'
	return not current and index(aux_characters, realm, name) or UnitName'player' == name
end

function M.neutral_faction()
	return not UnitFactionGroup'npc'
end

function M.min_bid_increment(current_bid)
	return max(1, floor(current_bid / 100) * 5)
end

function AUCTION_HOUSE_SHOW()
	AuctionFrame:Hide()
	AuxFrame:Show()
	tab = 1
end

function AUCTION_HOUSE_CLOSED()
	bids_loaded = false
	current_owner_page = nil
	post.stop()
	stack.stop()
	scan.abort()
	tab = nil
	AuxFrame:Hide()
end

function AUCTION_BIDDER_LIST_UPDATE()
	bids_loaded = true
end

do
	local last_owner_page_requested
	function GetOwnerAuctionItems(...)
		temp(arg)
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
	hook('ShowUIPanel', function(...)
		temp(arg)
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
	function ADDON_LOADED.Blizzard_CraftUI()
		hook('CraftFrame_SetSelection', function(...)
			temp(arg)
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
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetCraftReagentInfo(id, i))
				local _, price, limited = cache.merchant_info(item_id)
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
	end
	function ADDON_LOADED.Blizzard_TradeSkillUI()
		hook('TradeSkillFrame_SetSelection', function(...)
			temp(arg)
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
				local item_id, suffix_id = info.parse_link(link)
				local count = select(3, GetTradeSkillReagentInfo(id, i))
				local _, price, limited = cache.merchant_info(item_id)
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
	end
end

function AuctionFrameAuctions_OnEvent(...)
	temp(arg)
    if AuctionFrameAuctions:IsVisible() then
	    return orig.AuctionFrameAuctions_OnEvent(unpack(arg))
    end
end