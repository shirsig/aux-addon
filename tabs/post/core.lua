select(2, ...) 'aux.tabs.post'

local aux = require 'aux'
local info = require 'aux.util.info'
local sort_util = require 'aux.util.sort'
local persistence = require 'aux.util.persistence'
local money = require 'aux.util.money'
local scan_util = require 'aux.util.scan'
local stack = require 'aux.core.stack'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'
local item_listing = require 'aux.gui.item_listing'
local al = require 'aux.gui.auction_listing'
local gui = require 'aux.gui'

local tab = aux.tab 'Post'

local settings_schema = {'tuple', '#', {duration='number'}, {start_price='number'}, {buyout_price='number'}, {hidden='boolean'}}

local inventory_records, bid_records, buyout_records = {}, {}, {}

M.DURATION_2, M.DURATION_8, M.DURATION_24 = 1, 2, 3

refresh = true

posting = nil

selected_item = nil

function get_default_settings()
	return { duration = aux.account_data.post_duration, start_price = 0, buyout_price = 0, hidden = false }
end

function aux.event.AUX_LOADED()
    aux.event_listener('BAG_UPDATE', function()
        if posting == 'single' then
            posting = nil
        end
    end)
    aux.event_listener('AUCTION_MULTISELL_FAILURE', function()
        if posting == 'multi' then
            posting = nil
        end
    end)
    aux.event_listener('AUCTION_MULTISELL_UPDATE', function(count, total)
        if posting == 'multi' and count == total then
            posting = 'single'
        end
    end)
end

function aux.event.PLAYER_LOGIN()
	data = aux.faction_data.post
end

function read_settings(item_key)
	item_key = item_key or selected_item.key
	return data[item_key] and persistence.read(settings_schema, data[item_key]) or get_default_settings()
end
function write_settings(settings, item_key)
	item_key = item_key or selected_item.key
	data[item_key] = persistence.write(settings_schema, settings)
end

do
	local bid_selections, buyout_selections = {}, {}
	function get_bid_selection()
		return bid_selections[selected_item.key]
	end
	function set_bid_selection(record)
		bid_selections[selected_item.key] = record
	end
	function get_buyout_selection()
		return buyout_selections[selected_item.key]
	end
	function set_buyout_selection(record)
		buyout_selections[selected_item.key] = record
	end
end

function refresh_button_click()
	scan.abort()
	refresh_entries()
	refresh = true
end

function tab.OPEN()
    frame:Show()
    update_inventory_records(true)
    refresh = true
end

function tab.CLOSE()
    selected_item = nil
    ClearCursor()
    ClickAuctionSellItemButton()
    ClearCursor()
    frame:Hide()
end

function tab.USE_ITEM(item_id, suffix_id)
	select_item(item_id .. ':' .. suffix_id)
end

function get_unit_start_price()
	return selected_item and read_settings().start_price or 0
end

function set_unit_start_price(amount)
	local settings = read_settings()
	settings.start_price = amount
	write_settings(settings)
end

function get_unit_buyout_price()
	return selected_item and read_settings().buyout_price or 0
end

function set_unit_buyout_price(amount)
	local settings = read_settings()
	settings.buyout_price = amount
	write_settings(settings)
end

function update_inventory_listing()
	local records = aux.values(aux.filter(aux.copy(inventory_records), function(record)
		local settings = read_settings(record.key)
		return record.aux_quantity > 0 and (not settings.hidden or show_hidden_checkbox:GetChecked())
	end))
	sort(records, function(a, b) return a.name < b.name end)
	item_listing.populate(inventory_listing, records)
end

function update_auction_listing(listing, records, reference)
	local rows = {}
	if selected_item then
		local historical_value = history.value(selected_item.key)
		local stack_size = stack_size_slider:GetValue()
		for _, record in pairs(records[selected_item.key] or empty) do
			local price_color = undercut(record, stack_size_slider:GetValue(), listing == 'bid') < reference and aux.color.red
			local price = record.unit_price * (listing == 'bid' and record.stack_size or 1)
			tinsert(rows, {
				cols = {
                { value = record.own and aux.color.green(record.count) or record.count },
				{ value = al.time_left(record.duration) },
				{ value = record.stack_size == stack_size and aux.color.green(record.stack_size) or record.stack_size },
				{ value = money.to_string(price, true, nil, price_color) },
				{ value = historical_value and gui.percentage_historical(aux.round(price / historical_value * 100)) or '---' },
            },
				record = record,
            })
		end
		if historical_value then
			tinsert(rows, {
				cols = {
				{ value = '---' },
				{ value = '---' },
				{ value = '---' },
				{ value = money.to_string(historical_value * (listing == 'bid' and stack_size_slider:GetValue() or 1), true, nil, aux.color.green) },
				{ value = historical_value and gui.percentage_historical(100) or '---' },
            },
				record = { historical_value = true, stack_size = stack_size, unit_price = historical_value, own = true }
            })
		end
		sort(rows, function(a, b)
			return sort_util.multi_lt(
				a.record.unit_price * (listing == 'bid' and a.record.stack_size or 1),
				b.record.unit_price * (listing == 'bid' and b.record.stack_size or 1),

				a.record.historical_value and 1 or 0,
				b.record.historical_value and 1 or 0,

				b.record.own and 0 or 1,
				a.record.own and 0 or 1,

				a.record.stack_size,
				b.record.stack_size,

				a.record.duration,
				b.record.duration
			)
		end)
	end
	if listing == 'bid' then
		bid_listing:SetData(rows)
	elseif listing == 'buyout' then
		buyout_listing:SetData(rows)
	end
end

function update_auction_listings()
	update_auction_listing('bid', bid_records, get_unit_start_price())
	update_auction_listing('buyout', buyout_records, get_unit_buyout_price())
end

function M.select_item(item_key)
    for _, inventory_record in pairs(aux.filter(aux.copy(inventory_records), function(record) return record.aux_quantity > 0 end)) do
        if inventory_record.key == item_key then
            update_item(inventory_record)
            return
        end
    end
end

function price_update()
    if selected_item then
        local historical_value = history.value(selected_item.key)
        if get_bid_selection() or get_buyout_selection() then
	        set_unit_start_price(undercut(get_bid_selection() or get_buyout_selection(), stack_size_slider:GetValue(), get_bid_selection()))
	        unit_start_price_input:SetText(money.to_string(get_unit_start_price(), true, nil, nil, true))
        end
        if get_buyout_selection() then
	        set_unit_buyout_price(undercut(get_buyout_selection(), stack_size_slider:GetValue()))
	        unit_buyout_price_input:SetText(money.to_string(get_unit_buyout_price(), true, nil, nil, true))
        end
        start_price_percentage:SetText(historical_value and gui.percentage_historical(aux.round(get_unit_start_price() / historical_value * 100)) or '---')
        buyout_price_percentage:SetText(historical_value and gui.percentage_historical(aux.round(get_unit_buyout_price() / historical_value * 100)) or '---')
    end
end

function post_auction()
    local item_key = selected_item.key
    local max_charges = selected_item.max_charges

    local unit_start_price = get_unit_start_price()
    local unit_buyout_price = get_unit_buyout_price()
    local stack_size = stack_size_slider:GetValue()
    local stack_count = stack_count_slider:GetValue()
    local start_price = max(1, floor(get_unit_start_price() * stack_size))
    local buyout_price = floor(get_unit_buyout_price() * stack_size)
    local duration = duration_dropdown:GetIndex()

    for slot in info.inventory() do
        local item_info = info.container_item(unpack(slot))
        if item_info and item_info.auctionable and not item_info.locked and item_info.item_key == item_key and (not item_info.max_charges or item_info.charges == stack_size)  then
            ClearCursor()
            ClickAuctionSellItemButton()
            ClearCursor()
            PickupContainerItem(unpack(slot))
            ClickAuctionSellItemButton()
            ClearCursor()
            break
        end
    end

    PostAuction(start_price, buyout_price, duration, max_charges and 1 or stack_size, stack_count)

    posting = stack_count == 1 and 'single' or 'multi'
    aux.coro_thread(function()
        while posting do
            aux.coro_wait()
            if not frame:IsShown() then
                return
            end
        end

        update_inventory_records()
        local all_posted = true
        for _, record in pairs(inventory_records) do
            if record.key == item_key then
                all_posted = false
                break
            end
        end
        if selected_item and selected_item.key == item_key then
            if all_posted then
                selected_item = nil
            else
                update_item(selected_item)
            end
        end
        refresh = true
    end)
end

function validate_parameters()
    if posting or not selected_item then
        post_button:Disable()
        return
    end
    if get_unit_buyout_price() > 0 and get_unit_start_price() > get_unit_buyout_price() then
        post_button:Disable()
        return
    end
    if get_unit_start_price() == 0 then
        post_button:Disable()
        return
    end
    if stack_count_slider:GetValue() == 0 then
        post_button:Disable()
        return
    end
    -- TODO what if cannot afford deposit
    post_button:Enable()
end

function update_item_configuration()
	if not selected_item then
        refresh_button:Disable()

        item.texture:SetTexture(nil)
        item.count:SetText()
        item.name:SetTextColor(aux.color.label.enabled())
        item.name:SetText('No item selected')

        unit_start_price_input:Hide()
        unit_buyout_price_input:Hide()
        stack_size_slider:Hide()
        stack_count_slider:Hide()
        deposit:Hide()
        duration_dropdown:Hide()
        hide_checkbox:Hide()
    else
		unit_start_price_input:Show()
        unit_buyout_price_input:Show()
        stack_size_slider:Show()
        stack_count_slider:Show()
        deposit:Show()
        duration_dropdown:Show()
        hide_checkbox:Show()

        item.texture:SetTexture(selected_item.texture)
        item.name:SetText('[' .. selected_item.name .. ']')
		do
	        local color = ITEM_QUALITY_COLORS[selected_item.quality]
	        item.name:SetTextColor(color.r, color.g, color.b)
        end
		if selected_item.aux_quantity > 1 then
            item.count:SetText(selected_item.aux_quantity)
		else
            item.count:SetText()
        end

        stack_size_slider.editbox:SetNumber(stack_size_slider:GetValue())
        stack_count_slider.editbox:SetNumber(stack_count_slider:GetValue())

        do
            local deposit_factor = UnitFactionGroup'npc' and .05 or .25
            local duration_factor = info.duration_hours(duration_dropdown:GetIndex()) / 2
            local stack_size, stack_count = selected_item.max_charges and 1 or stack_size_slider:GetValue(), stack_count_slider:GetValue()
            local amount = floor(selected_item.unit_vendor_price * deposit_factor * stack_size) * stack_count * duration_factor
            deposit:SetText('Deposit: ' .. money.to_string(amount, nil, nil, aux.color.text.enabled))
        end

        refresh_button:Enable()
	end
end

function undercut(record, stack_size, stack)
    local price = ceil(record.unit_price * (stack and record.stack_size or stack_size))
    if not record.own then
	    price = price - 1
    end
    return price / stack_size
end

function quantity_update(maximize_count)
    if selected_item then
        local max_stack_count = selected_item.max_charges and min(1, selected_item.availability[stack_size_slider:GetValue()]) or floor(selected_item.availability[0] / stack_size_slider:GetValue())
        stack_count_slider:SetMinMaxValues(min(1, max_stack_count), max_stack_count)
        if maximize_count then
            stack_count_slider:SetValue(max_stack_count)
        end
    end
    refresh = true
end

function unit_vendor_price(item_key)
    for slot in info.inventory() do
        local item_info = info.container_item(unpack(slot))
        if item_info and item_info.item_key == item_key and item_info.auctionable then
            ClearCursor()
            ClickAuctionSellItemButton()
            ClearCursor()
            PickupContainerItem(unpack(slot))
            ClickAuctionSellItemButton()
            local auction_sell_item = info.auction_sell_item()
            ClearCursor()
            ClickAuctionSellItemButton()
            ClearCursor()
            if auction_sell_item then
                return auction_sell_item.vendor_price / auction_sell_item.count
            end
        end
    end
end

function update_item(item)
    local settings = read_settings(item.key)

    item.unit_vendor_price = unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = true
        write_settings(settings, item.key)
        refresh = true
        return
    end

    scan.abort()

    do
        local options = {}
        for _, i in ipairs{2, 8, 24} do
            tinsert(options, aux.pluralize(i .. ' ' .. HOURS))
        end
        duration_dropdown:SetOptions(options)
    end
    duration_dropdown:SetIndex(settings.duration)

    hide_checkbox:SetChecked(settings.hidden)

    selected_item = item -- must be here for quantity_update triggered by slider change
    if item.max_charges then
	    for i = item.max_charges, 1, -1 do
			if item.availability[i] > 0 then
				stack_size_slider:SetMinMaxValues(1, i)
				break
			end
	    end
    else
	    stack_size_slider:SetMinMaxValues(1, min(item.max_stack, item.aux_quantity))
    end
    stack_size_slider:SetValue(math.huge)
    quantity_update(true)

    unit_start_price_input:SetText(money.to_string(settings.start_price, true, nil, nil, true))
    unit_buyout_price_input:SetText(money.to_string(settings.buyout_price, true, nil, nil, true))
    write_settings(settings, item.key)

    if not bid_records[item.key] then
        refresh_entries()
    end

    refresh = true
end

function update_inventory_records(reset)
    local auctionable_map = {}
    for slot in info.inventory() do
	    local item_info = info.container_item(unpack(slot))
        local charge_class = item_info and item_info.charges or 0
        if item_info and item_info.auctionable then
            if not auctionable_map[item_info.item_key] then
                local availability = {}
                for i = 0, 10 do
                    availability[i] = 0
                end
                availability[charge_class] = item_info.count
                auctionable_map[item_info.item_key] = {
                    item_id = item_info.item_id,
                    suffix_id = item_info.suffix_id,
                    key = item_info.item_key,
                    link = item_info.link,
                    name = item_info.name,
                    texture = item_info.texture,
                    quality = item_info.quality,
                    aux_quantity = item_info.charges or item_info.count,
                    max_stack = item_info.max_stack,
                    max_charges = item_info.max_charges,
                    availability = availability,
                }
            else
                local auctionable = auctionable_map[item_info.item_key]
                auctionable.availability[charge_class] = (auctionable.availability[charge_class] or 0) + item_info.count
                auctionable.aux_quantity = auctionable.aux_quantity + (item_info.charges or item_info.count)
            end
        end
    end

    if reset then
        inventory_records = aux.values(auctionable_map)
    else
        for i = #inventory_records, 1, -1 do
            local new_record = auctionable_map[inventory_records[i].key]
            if new_record then
                for k in pairs(new_record) do
                    inventory_records[i][k] = new_record[k]
                end
            else
                tremove(inventory_records, i)
            end
        end
    end
end

function refresh_entries()
	if selected_item then
        local item_key = selected_item.key
		set_bid_selection()
        set_buyout_selection()
        bid_records[item_key], buyout_records[item_key] = nil, nil
        local query = scan_util.item_query(selected_item.item_id)

		scan.start{
            type = 'list',
            ignore_owner = true,
			queries = {query},
            on_scan_start = function()
                aux.status_bar:update_status(0, 0)
            end,
			on_page_loaded = function(page, total_pages)
                aux.status_bar:update_status(page / total_pages, 0)
			end,
			on_auction = function(auction_record)
				if auction_record.item_key == item_key then
                    record_auction(auction_record)
				end
			end,
			on_abort = function()
				bid_records[item_key], buyout_records[item_key] = nil, nil
                aux.status_bar:update_status(1, 1)
			end,
			on_complete = function()
				bid_records[item_key] = bid_records[item_key] or {}
				buyout_records[item_key] = buyout_records[item_key] or {}
                refresh = true
                aux.status_bar:update_status(1, 1)
            end,
		}
	end
end

function M.clear_auctions()
    bid_records, buyout_records = {}, {}
end

function M.record_auction(auction)
    bid_records[auction.item_key] = bid_records[auction.item_key] or {}
    do
	    local entry
	    for _, record in pairs(bid_records[auction.item_key]) do
	        if auction.unit_blizzard_bid == record.unit_price and auction.aux_quantity == record.stack_size and auction.duration == record.duration and info.is_player(auction.owner) == record.own then
	            entry = record
	        end
	    end
	    if not entry then
	        entry =  { stack_size = auction.aux_quantity, unit_price = auction.unit_blizzard_bid, duration = auction.duration, own = info.is_player(auction.owner), count = 0 }
	        tinsert(bid_records[auction.item_key], entry)
	    end
	    entry.count = entry.count + 1
    end
    buyout_records[auction.item_key] = buyout_records[auction.item_key] or {}
    if auction.unit_buyout_price == 0 then return end
    do
	    local entry
	    for _, record in pairs(buyout_records[auction.item_key]) do
		    if auction.unit_buyout_price == record.unit_price and auction.aux_quantity == record.stack_size and auction.duration == record.duration and info.is_player(auction.owner) == record.own then
			    entry = record
		    end
	    end
	    if not entry then
		    entry = { stack_size = auction.aux_quantity, unit_price = auction.unit_buyout_price, duration = auction.duration, own = info.is_player(auction.owner), count = 0 }
		    tinsert(buyout_records[auction.item_key], entry)
	    end
	    entry.count = entry.count + 1
    end
end

function on_update()
    if refresh then
        refresh = false
        price_update()
        update_item_configuration()
        update_inventory_listing()
        update_auction_listings()
    end
    validate_parameters()
end

function duration_selection_change()
    if selected_item then
        local settings = read_settings()
        settings.duration = duration_dropdown:GetIndex()
        write_settings(settings)
        refresh = true
    end
end
