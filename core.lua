local addon = Aux_module()
Aux = tremove(addon, 1)
local m, public, private = unpack(addon)

private.modules = { Aux }
function public.module(name)
    local module = Aux_module()
    local public_interface = tremove(module, 1)
    tinsert(m.modules, public_interface)
    public[name] = public_interface
    return unpack(module)
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

function public.get(table, key)
    return table[key]
end

function public.set(table, key, value)
    table[key] = value
end

function public.f(func, ...)
    local params = arg
    return function(...)
        for i=1,arg.n do
            tinsert(params, arg[i])
        end
        return func(unpack(params))
    end
end

do
    local safe_nil = setmetatable({}, {
        __index = function(self) return self end,
        __call = function(self) return self end,
        __div = function(_, value) return value end
    })

    function public.safe(object)
        return (object == nil or object == safe_nil) and safe_nil or setmetatable({}, {
            __index = function(_, key)
                return m.safe(key) ~= safe_nil and m.safe(object[key]) or safe_nil
            end,
            __call = function(_, ...)
                for i=1,arg.n do
                    if safe(arg[i]) == safe_nil then
                        return safe_nil
                    end
                end
                return object(unpack(arg))
            end,
            __div = function() return object end
        })
    end
end

do
    local x = 0

    function public.unique()
        x = x + 1
        return x
    end
end

function public.on_load()
    public.version = '3.5.3'
    public.bids_loaded = false
    public.current_owner_page = nil
    public.last_owner_page_requested = nil
    private.auction_frame_loaded = nil

	m.log('Aux v'..m.version..' loaded.')

    Aux.gui.set_window_style(AuxFrame)
    tinsert(UISpecialFrames, 'AuxFrame')

    CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')
    AuxTooltip:SetScript('OnTooltipAddMoney', function()
        this.money = arg1
    end)

    do
        local tab_group = m.gui.tab_group(AuxFrame, 'BOTTOM')
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
        btn:SetScript('OnClick', m.f(HideUIPanel, AuxFrame))
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
        if module('LOAD') then
            module.LOAD()
        end
    end
end

function public.on_event()
	if event == 'VARIABLES_LOADED' then
		m.on_load()
	elseif event == 'ADDON_LOADED' then
        m.safe(m.on_addon_load[arg1])()
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
    m.hook('PickupInventoryItem', m.PickupInventoryItem)
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

            local listener = m.control.event_listener('CHAT_MSG_SYSTEM')
            listener:set_action(function()
                if arg1 == ERR_AUCTION_BID_PLACED then
                    listener:stop()
                    if on_success then
                        on_success()
                    end
                    locked = false
                end
            end)
            listener:start()
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
        local listener = m.control.event_listener('CHAT_MSG_SYSTEM')
        listener:set_action(function()
            if arg1 == ERR_AUCTION_REMOVED then
                listener:stop()
                if on_success then
                    on_success()
                end
                locked = false
            end
        end)
        listener:start()
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

function public.round(v)
	return floor(v + 0.5)
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
    function private.PickupContainerItem(...)
        local bag, slot = unpack(arg)
        last_picked_up = { bag, slot }
        return m.orig.PickupContainerItem(unpack(arg))
    end
    function private.PickupInventoryItem(...)
        last_picked_up = nil
        return m.orig.PickupInventoryItem(unpack(arg))
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

function public.item_class_index(item_class)
    for i, class in ipairs({ GetAuctionItemClasses() }) do
        if strupper(class) == strupper(item_class) then
            return i
        end
    end
end

function public.item_subclass_index(class_index, item_subclass)
    for i, subclass in ipairs({ GetAuctionItemSubClasses(class_index) }) do
        if strupper(subclass) == strupper(item_subclass) then
            return i
        end
    end
end

function public.item_slot_index(class_index, subclass_index, slot_name)
    for i, slot in ipairs({ GetAuctionInvTypes(class_index, subclass_index) }) do
        if strupper(getglobal(slot)) == strupper(slot_name) then
            return i
        end
    end
end

function public.item_quality_index(item_quality)
    for i=0,4 do
        local quality = getglobal('ITEM_QUALITY'..i..'_DESC')
        if strupper(item_quality) == strupper(quality) then
            return i
        end
    end
end

function public.is_player(name, current)
    local realm = GetCVar('realmName')
    return (not current and m.safe(aux_characters)[realm][name]/false) or UnitName('player') == name
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
        error('"'..name..'" is already hooked!')
    end

    orig[name] = object[name]
    object[name] = handler
end

public.huge = 2^100000

public.null = {}