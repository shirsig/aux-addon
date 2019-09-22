select(2, ...) 'aux'

local T = require 'T'
local post = require 'aux.tabs.post'

function M.print(...)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<aux> ' .. join(map({...}, tostring), ' '))
end

local event_frame = CreateFrame'Frame'
for _, event in pairs{'ADDON_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED'} do
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
	event_frame:SetScript('OnEvent', function(_, event, arg1, ...)
		if event == 'ADDON_LOADED' then
            if arg1 == 'aux-addon' then
                for _, f in ipairs(handlers) do f(arg1, ...) end
            elseif arg1 == 'Blizzard_AuctionUI' then
                auction_ui_loaded()
			end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in ipairs(handlers2) do f(arg1, ...) end
            sort(account_data.auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
            print('loaded - /aux')
		else
			_M[event](arg1, ...)
		end
	end)
end

function handle.LOAD()
    _G.aux = aux or {}
    assign(aux, {
        account = {},
        realm = {},
        faction = {},
        character = {},
    })
    M.account_data = assign(aux.account, {
        scale = 1,
        ignore_owner = true,
        crafting_cost = true,
        post_bid = false,
        post_duration = post.DURATION_8,
        items = {},
        item_ids = {},
        unused_item_ids = {},
        auctionable_items = {},
        merchant_buy = {},
    })
    do
        local key = format('%s|%s', GetRealmName(), UnitName'player')
        aux.character[key] = aux.character[key] or {}
        M.character_data = assign(aux.character[key], {
            tooltip = {
                value = true,
                merchant_sell = true,
                merchant_buy = false,
                daily = false,
                disenchant_value = false,
                disenchant_distribution = false,
            }
        })
    end
    do
        local key = GetRealmName()
        aux.realm[key] = aux.realm[key] or {}
        M.realm_data = assign(aux.realm[key], {
            characters = {},
            recent_searches = {},
            favorite_searches = {},
        })
    end
    do
        local key = format('%s|%s', GetRealmName(), UnitFactionGroup 'player')
        aux.faction[key] = aux.faction[key] or {}
        M.faction_data = assign(aux.faction[key], {
            history = {},
            post = {},
        })
    end
end

tab_info = {}
function M.tab(name)
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
	function M.get_tab() return tab_info[index] end
	function on_tab_click(i)
		CloseDropDownMenus()
		do (index and get_tab().CLOSE or pass)() end
		index = i
		do (index and get_tab().OPEN or pass)() end
	end
end

M.orig = setmetatable({[_G]={}}, {__index=function(self, key) return self[_G][key] end})
function M.hook(...)
	local name, object, handler
	if select('#', ...) == 3 then
		name, object, handler = ...
	else
		object, name, handler = _G, ...
	end
	handler = handler or getfenv(3)[name]
	orig[object] = orig[object] or {}
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
				do (on_success or pass)() end
				locked = false
			end)
			thread(when, later(5), send_signal)
			event_listener('CHAT_MSG_SYSTEM', function(kill, arg1)
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
			do (on_success or pass)() end
			locked = false
		end)
		thread(when, later(5), send_signal)
		event_listener('CHAT_MSG_SYSTEM', function(kill, arg1)
			if arg1 == ERR_AUCTION_REMOVED then
				send_signal()
				kill()
			end
		end)
	end
end

function handle.LOAD2()
	frame:SetScale(account_data.scale)
end

function auction_ui_loaded()
    _G.AuctionFrame_Show, _M.AuctionFrame_Show  = nil, _G.AuctionFrame_Show
    AuctionFrame:SetScript('OnHide', nil)
end

function AUCTION_HOUSE_SHOW()
    frame:Show()
    set_tab(1)
    GetOwnerAuctionItems()
    GetBidderAuctionItems()
end

do
	local handlers = {}
	function set_handler.CLOSE(f)
		tinsert(handlers, f)
	end
	function AUCTION_HOUSE_CLOSED()
		for _, handler in pairs(handlers) do
			handler()
		end
		set_tab()
		frame:Hide()
	end
end