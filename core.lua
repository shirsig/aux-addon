local addon = aux_module()
aux = tremove(addon, 1)
local m, public, private = unpack(addon)

private.modules = {}
function private.initialize_module(public_declarator)
	public_declarator.LOAD = nil
end
m.initialize_module(public)
function public.module(name)
    local public_interface, private_interface, public_declarator, private_declarator = unpack(aux_module())
    m.initialize_module(public_declarator)
    tinsert(m.modules, public_interface)
    public[name] = public_interface
    return private_interface, public_declarator, private_declarator
end

private.tabs = {}
function public.tab(index, name)
    local ret = { m.module(name) }
    ret[2].ACTIVE = function()
        return m[name] == m.active_tab()
    end
    m.tabs[index] = m[name]
    return unpack(ret)
end
do
    local active_tab_index
    function private.active_tab()
        if active_tab_index then
            return m.tabs[active_tab_index]
        end
    end
    function private.on_tab_click(index)
        if m.active_tab() then
            m.active_tab().CLOSE()
        end
        active_tab_index = index
        if m.active_tab() then
            m.active_tab().OPEN()
        end
    end
end

do
	local x = 0
	function public.id()
		x = x + 1
		return x
	end
end

do
	local mt = {
		__newindex = function(self, name, method)
			if strsub(name, 1, 2) == '__' then
				self._metatable[name] = method
			else
				self._methods[name] = method
			end
		end,
		__call = function(self, ...)
			setmetatable(self._methods, self._metatable.__index)
			self._metatable.__index =self._methods
			local object = setmetatable({}, self._metatable)
			for name, method in self._methods do
				object[name] = method
			end
			self._constructor(object, unpack(arg))
			return object
		end,
	}
	function public.class(constructor)
		return setmetatable({_constructor=constructor, _methods={}, _metatable={}}, mt)
	end
end

public.this = {}
do
	local formal_parameters = {}
	for i=1,9 do
		local key = 'arg'..i
		public[key] = {}
		formal_parameters[m[key]] = i
	end
	local function call(f, arg1, arg2)
		local params = {}
		for i=1,arg1.n do
			if arg1[i] == m.this then
				tinsert(params, this)
			elseif formal_parameters[arg1[i]] then
				tinsert(params, arg2[formal_parameters[arg1[i]]])
			else
				tinsert(params, arg1[i])
			end
		end
		return f(unpack(params))
	end
	function public._(f, ...)
		local arg1 = arg
		return function(...)
			return call(f, arg1, arg)
		end
	end
end

do
    local mt = {
        __newindex = function(self, key, value)
	        self._f()[key] = value
        end,
        __index = function(self, key)
            return self._f()[key]
        end,
        __call = function(self)
            return self._f()
        end,
    }
    function public.dynamic_table(f)
        return setmetatable({_f=f}, mt)
    end
end

do
	local mt = {
		__index = function(self, key)
			return self:_cb(key)
		end,
		__call = function(self)
			return self:_cb()
		end,
	}
	function public.index_function(cb)
		return setmetatable({_cb = cb}, mt)
	end
end

function public.call(f, ...)
    if f then
        return f(unpack(arg))
    end
end

function public.index(t, ...)
	for i=1,arg.n do
		if t then
			t = t[arg[i]]
		end
	end
	return t
end

function public.on_load()
    public.version = '3.7.1'
    public.bids_loaded = false
    public.current_owner_page = nil
    public.last_owner_page_requested = nil
    private.auction_frame_loaded = nil

	m.log('aux v'..m.version..' loaded.')

    aux.gui.set_window_style(AuxFrame)
    tinsert(UISpecialFrames, 'AuxFrame')

    aux.control.event_listener('CURSOR_UPDATE', m.CURSOR_UPDATE)

    do
        local tab_group = m.gui.tab_group(AuxFrame, 'DOWN')
        tab_group:create_tab('Search')
        tab_group:create_tab('Post')
        tab_group:create_tab('Auctions')
        tab_group:create_tab('Bids')
        tab_group.on_select = m.on_tab_click
        public.tab_group = tab_group
    end

    do
        local btn = m.gui.button(AuxFrame, 16)
        btn:SetPoint('BOTTOMRIGHT', -6, 6)
        btn:SetWidth(65)
        btn:SetHeight(24)
        btn:SetText('Close')
        btn:SetScript('OnClick', m._(HideUIPanel, AuxFrame))
        public.close_button = btn
    end

    do
        local btn = m.gui.button(AuxFrame, 16)
        btn:SetPoint('RIGHT', m.close_button, 'LEFT' , -5, 0)
        btn:SetWidth(65)
        btn:SetHeight(24)
        btn:SetText('Default UI')
        btn:SetScript('OnClick',function()
            if AuctionFrame:IsVisible() then
                HideUIPanel(AuctionFrame)
            else
                ShowUIPanel(AuctionFrame)
            end
        end)
    end

    for _, module in m.modules do
	    m.call(module.LOAD)
    end
end

function public.on_event()
	if event == 'VARIABLES_LOADED' then
		m.on_load()
	elseif event == 'ADDON_LOADED' then
        m.call(m.on_addon_load[arg1])
	elseif event == 'AUCTION_HOUSE_SHOW' then
        m.on_auction_house_show()
	elseif event == 'AUCTION_HOUSE_CLOSED' then
        m.on_auction_house_closed()
        m.bids_loaded = false
        m.current_owner_page = nil
    elseif event == 'AUCTION_BIDDER_LIST_UPDATE' then
        m.bids_loaded = true
	elseif event == 'AUCTION_OWNED_LIST_UPDATE' then
        m.current_owner_page = m.last_owner_page_requested or 0
    end
end

private.on_addon_load = {}
function m.on_addon_load.Blizzard_AuctionUI()

    AuctionFrame:UnregisterEvent('AUCTION_HOUSE_SHOW')
    AuctionFrame:SetScript('OnHide', nil)

    m.hook('ShowUIPanel', function(...)
        if arg[1] == AuctionFrame then
            return AuctionFrame:Show()
        end
        return m.orig.ShowUIPanel(unpack(arg))
    end)

    m.hook('GetOwnerAuctionItems', m.GetOwnerAuctionItems)
    m.hook('PickupContainerItem', m.PickupContainerItem)
    m.hook('SetItemRef', m.SetItemRef)
    m.hook('UseContainerItem', m.UseContainerItem)
    m.hook('AuctionFrameAuctions_OnEvent', m.AuctionFrameAuctions_OnEvent)
end
do
    local function cost_label(cost)
        local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
        label = label..(cost and m.util.format_money(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'---'..FONT_COLOR_CODE_CLOSE)
        label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
        return label
    end

    function m.on_addon_load.Blizzard_CraftUI()
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
                local item_id, suffix_id = m.info.parse_hyperlink(link)
                local count = ({GetCraftReagentInfo(id, i)})[3]
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

    function m.on_addon_load.Blizzard_TradeSkillUI()
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
                local item_id, suffix_id = m.info.parse_hyperlink(link)
                local count = ({GetTradeSkillReagentInfo(id, i)})[3]
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
                    aux.call(on_success)
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

function public.log(...)
    local msg = '[aux]'
    for i=1,arg.n do
        msg = msg..' '..tostring(arg[i])
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
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

function public.neutral_faction()
    return not UnitFactionGroup('npc')
end

function private.on_auction_house_show()
    if AuctionFrame:IsVisible() then
        AuctionFrame:Hide()
    end
    AuxFrame:Show()
    m.tab_group:set_tab(1)
end

function private.on_auction_house_closed()
	m.post.stop()
	m.stack.stop()
	m.scan.abort()
    m.tab_group:set_tab()
	AuxFrame:Hide()
end

function public.min_bid_increment(current_bid)
    return max(1, floor(current_bid / 100) * 5)
end

function public.price_level_color(pct)
    if pct > 135 then
        return 1.0,0.0,0.0 -- red
    elseif pct > 110 then
        return 1.0,0.6,0.1 -- orange
    elseif pct > 80 then
        return 1.0,1.0,0.0 -- yellow
    elseif pct > 50 then
        return 0.1,1.0,0.1 -- green
    else
        return 0.2,0.6,1.0 -- blue
    end
end

do -- TODO make it work for other ways to pick up things
    local last_picked_up
    function private.CURSOR_UPDATE()
        last_picked_up = nil
    end
    function private.PickupContainerItem(...)
        local bag, slot = unpack(arg)
        aux.control.thread(function()
            last_picked_up = {bag, slot}
        end)
        return m.orig.PickupContainerItem(unpack(arg))
    end
    function public.cursor_item()
        if last_picked_up and CursorHasItem() then
            return m.info.container_item(unpack(last_picked_up))
        end
    end
end

function private.SetItemRef(...)
    local itemstring, text, button = unpack(arg)
    if m.search_tab.ACTIVE() and button == 'RightButton' then
        local item_info = m.info.item(tonumber(({strfind(itemstring, '^item:(%d+)')})[3]))
        if item_info then
            m.search_tab.set_filter(strlower(item_info.name)..'/exact')
            m.search_tab.execute(nil, false)
            return
        end
    end
    return m.orig.SetItemRef(unpack(arg))
end

function private.UseContainerItem(...)
    local bag, slot = unpack(arg)
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
        return m.orig.UseContainerItem(unpack(arg))
    end

    if m.search_tab.ACTIVE() then
        local item_info = m.info.container_item(bag, slot)
        item_info = item_info and m.info.item(item_info.item_id)
        if item_info then
            m.search_tab.set_filter(strlower(item_info.name)..'/exact')
            m.search_tab.execute(nil, false)
        end
        return
    end

    if m.post_tab.ACTIVE() then
        local item_info = m.info.container_item(bag, slot)
        if item_info then
            m.post_tab.select_item(item_info.item_key)
        end
        return
    end

	return m.orig.UseContainerItem(unpack(arg))
end

function public.is_player(name, current)
    local realm = GetCVar('realmName')
    return not current and aux.index(aux_characters, realm, name) or UnitName('player') == name
end

function public.unmodified()
    return not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown()
end

public.orig = {}
function public.hook(name, handler, object)
    local orig
    if object then
        m.orig[object] = m.orig[object] or {}
        orig = m.orig[object]
    else
        object = object or getfenv(0)
        orig = m.orig
    end

    if orig[name] then
        error('"'..name..'" is already hooked.')
    end

    orig[name] = object[name]
    object[name] = handler
end

public.huge = 2^100000

public.null = {}