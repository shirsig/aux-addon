module 'aux.tabs.post'

include 'T'
include 'aux'

local info = require 'aux.util.info'
local sort_util = require 'aux.util.sort'
local persistence = require 'aux.util.persistence'
local money = require 'aux.util.money'
local scan_util = require 'aux.util.scan'
local post = require 'aux.core.post'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'
local item_listing = require 'aux.gui.item_listing'
local al = require 'aux.gui.auction_listing'

TAB 'Post'

local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440
local settings_schema = {'tuple', '#', {stack_size='number'}, {duration='number'}, {start_price='number'}, {buyout_price='number'}, {hidden='boolean'}}

function get_default_settings()
	return O('duration', DURATION_8 , 'stack_size', 1, 'start_price', 0, 'buyout_price', 0, 'hidden', false)
end

do
	local data
	function get_data()
		if not data then
			local dataset = persistence.dataset
			data = dataset.post or T
			dataset.post = data
		end
		return data
	end
end

function read_settings(item_key)
	item_key = item_key or selected_item.key
	return data[item_key] and persistence.read(settings_schema, data[item_key]) or default_settings
end

function write_settings(settings, item_key)
	item_key = item_key or selected_item.key
	data[item_key] = persistence.write(settings_schema, settings)
end

local scan_id, inventory_records, existing_auctions = 0, T, T

function refresh_button_click()
	scan.abort(scan_id)
	refresh_entries()
	refresh = true
end

do
	local item
	function get_selected_item() return item end
	function set_selected_item(v) item = v end
end

do
	local c = 0
	function get_refresh() return c end
	function set_refresh(v) c = v end
end

function OPEN()
    frame:Show()
    update_inventory_records()
    refresh = true
end

function CLOSE()
    selected_item = nil
    frame:Hide()
end

function USE_ITEM(item_info)
	select_item(item_info.item_key)
end

function get_unit_start_price()
    local money_text = unit_start_price_input:GetText()
    return money.from_string(money_text) or 0
end

function set_unit_start_price(amount)
    unit_start_price_input:SetText(money.to_string(amount, true, nil, 3, nil, true))
end

function get_unit_buyout_price()
    local money_text = unit_buyout_price_input:GetText()
    return money.from_string(money_text) or 0
end

function set_unit_buyout_price(amount)
    unit_buyout_price_input:SetText(money.to_string(amount, true, nil, 3, nil, true))
end

function update_inventory_listing()
	if not ACTIVE then return end
	local records = values(filter(copy(inventory_records), function(record)
		local settings = read_settings(record.key)
		return record.aux_quantity > 0 and (not settings.hidden or show_hidden_checkbox:GetChecked())
	end))
	sort(records, function(a, b) return a.name < b.name end)
	item_listing.populate(inventory_listing, records)
end

function update_auction_listing()
	if not ACTIVE then return end
    local auction_rows = T
    if selected_item then
        local unit_start_price = get_unit_start_price()
        local unit_buyout_price = get_unit_buyout_price()

        for i, auction_record in ipairs(existing_auctions[selected_item.key] or empty) do

            local blizzard_bid_undercut, buyout_price_undercut = undercut(auction_record, stack_size_slider:GetValue())
            blizzard_bid_undercut = money.from_string(money.to_string(blizzard_bid_undercut, true, nil, 3))
            buyout_price_undercut = money.from_string(money.to_string(buyout_price_undercut, true, nil, 3))

            local stack_blizzard_bid_undercut, stack_buyout_price_undercut = undercut(auction_record, stack_size_slider:GetValue(), true)
            stack_blizzard_bid_undercut = money.from_string(money.to_string(stack_blizzard_bid_undercut, true, nil, 3))
            stack_buyout_price_undercut = money.from_string(money.to_string(stack_buyout_price_undercut, true, nil, 3))

            local stack_size = stack_size_slider:GetValue()
            local historical_value = history.value(selected_item.key)

            local bid_color
            if blizzard_bid_undercut < unit_start_price and stack_blizzard_bid_undercut < unit_start_price then
                bid_color = color.red
            elseif blizzard_bid_undercut < unit_start_price then
                bid_color = color.orange
            elseif stack_blizzard_bid_undercut < unit_start_price then
                bid_color = color.yellow
            end

            local buyout_color
            if buyout_price_undercut < unit_buyout_price and stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = color.red
            elseif buyout_price_undercut < unit_buyout_price then
                buyout_color = color.orange
            elseif stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = color.yellow
            end

            tinsert(auction_rows, O(
                'cols', A(
                    O('value', auction_record.own and color.yellow(auction_record.count) or auction_record.count),
		            O('value', al.time_left(auction_record.duration)),
		            O('value', auction_record.stack_size == stack_size and color.yellow(auction_record.stack_size) or auction_record.stack_size),
		            O('value', money.to_string(auction_record.unit_blizzard_bid, true, nil, 3, bid_color)),
		            O('value', historical_value and al.percentage_historical(round(auction_record.unit_blizzard_bid / historical_value * 100)) or '---'),
		            O('value', auction_record.unit_buyout_price > 0 and money.to_string(auction_record.unit_buyout_price, true, nil, 3, buyout_color) or '---'),
		            O('value', auction_record.unit_buyout_price > 0 and historical_value and al.percentage_historical(round(auction_record.unit_buyout_price / historical_value * 100)) or '---')
                ),
                'record', auction_record
            ))
        end
        sort(auction_rows, function(a, b)
            return sort_util.multi_lt(
                    a.record.unit_buyout_price == 0 and huge or a.record.unit_buyout_price,
	                b.record.unit_buyout_price == 0 and huge or b.record.unit_buyout_price,

                    a.record.unit_blizzard_bid,
	                b.record.unit_blizzard_bid,

                    a.record.stack_size,
	                b.record.stack_size,

                    b.record.own and 1 or 0,
	                a.record.own and 1 or 0,

                    a.record.duration,
                    b.record.duration
            )
        end)
    end
    auction_listing:SetData(auction_rows)
end

function M.select_item(item_key)
    for _, inventory_record in filter(copy(inventory_records), function(record) return record.aux_quantity > 0 end) do
        if inventory_record.key == item_key then
            update_item(inventory_record)
            return
        end
    end
end

function price_update()
    if selected_item then
        local settings = read_settings()

        local start_price_input = get_unit_start_price()
        settings.start_price = start_price_input
        local historical_value = history.value(selected_item.key)
        start_price_percentage:SetText(historical_value and al.percentage_historical(round(start_price_input / historical_value * 100)) or '---')

        local buyout_price_input = get_unit_buyout_price()
        settings.buyout_price = buyout_price_input
        local historical_value = history.value(selected_item.key)
        buyout_price_percentage:SetText(historical_value and al.percentage_historical(round(buyout_price_input / historical_value * 100)) or '---')

        write_settings(settings)
    end
end

function post_auctions()
	if selected_item then
        local unit_start_price = get_unit_start_price()
        local unit_buyout_price = get_unit_buyout_price()
        local stack_size = stack_size_slider:GetValue()
        local stack_count
        stack_count = stack_count_slider:GetValue()
        local duration = UIDropDownMenu_GetSelectedValue(duration_dropdown)
		local key = selected_item.key

        local duration_code
		if duration == DURATION_4 then
            duration_code = 2
		elseif duration == DURATION_8 then
            duration_code = 3
		elseif duration == DURATION_24 then
            duration_code = 4
		end

		post.start(
			key,
			stack_size,
			duration,
            unit_start_price,
            unit_buyout_price,
			stack_count,
			function(posted)
				for i = 1, posted do
                    record_auction(key, stack_size, unit_start_price, unit_buyout_price, duration_code, UnitName'player')
                end
                update_inventory_records()
                selected_item = nil
                for _, record in inventory_records do
                    if record.key == key then
                        update_item(record)
	                    break
                    end
                end
                refresh = true
			end
		)
	end
end

function validate_parameters()
    if not selected_item then
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
    post_button:Enable()
end

function update_item_configuration()
	if not selected_item then
        refresh_button:Disable()

        item.texture:SetTexture(nil)
        item.count:SetText()
        item.name:SetTextColor(color.label.enabled())
        item.name:SetText('No item selected')

        unit_start_price_input:Hide()
        unit_buyout_price_input:Hide()
        stack_size_slider:Hide()
        stack_count_slider:Hide()
        deposit:Hide()
        duration_dropdown:Hide()
        historical_value_button:Hide()
        hide_checkbox:Hide()
    else
		unit_start_price_input:Show()
        unit_buyout_price_input:Show()
        stack_size_slider:Show()
        stack_count_slider:Show()
        deposit:Show()
        duration_dropdown:Show()
        historical_value_button:Show()
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
            local deposit_factor = neutral_faction() and .25 or .05
            local stack_size, stack_count = stack_size_slider:GetValue(), stack_count_slider:GetValue()
            local amount = floor(selected_item.unit_vendor_price * deposit_factor * (selected_item.max_charges and 1 or stack_size)) * stack_count * UIDropDownMenu_GetSelectedValue(duration_dropdown) / 120
            deposit:SetText('Deposit: ' .. money.to_string(amount, nil, nil, nil, color.text.enabled))
        end

        refresh_button:Enable()
	end
end

function undercut(record, stack_size, stack)
    local start_price = round(record.unit_blizzard_bid * (stack and record.stack_size or stack_size))
    local buyout_price = round(record.unit_buyout_price * (stack and record.stack_size or stack_size))
    if not record.own then
        start_price = max(0, start_price - 1)
        buyout_price = max(0, buyout_price - 1)
    end
    return start_price / stack_size, buyout_price / stack_size
end

function quantity_update(max_count)
    if selected_item then
        local max_stack_count = selected_item.max_charges and selected_item.availability[stack_size_slider:GetValue()] or floor(selected_item.availability[0] / stack_size_slider:GetValue())
        stack_count_slider:SetMinMaxValues(1, max_stack_count)
        if max_count then
            stack_count_slider:SetValue(max_stack_count)
        end
    end
    refresh = true
end

function unit_vendor_price(item_key)
    for slot in info.inventory do
	    temp(slot)
        local item_info = temp-info.container_item(unpack(slot))
        if item_info and item_info.item_key == item_key then
            if info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                ClearCursor()
                PickupContainerItem(unpack(slot))
                ClickAuctionSellItemButton()
                local auction_sell_item = temp-info.auction_sell_item()
                ClearCursor()
                ClickAuctionSellItemButton()
                ClearCursor()
                if auction_sell_item then
                    return auction_sell_item.vendor_price / auction_sell_item.count
                end
            end
        end
    end
end

function update_historical_value_button()
    if selected_item then
        local historical_value = history.value(selected_item.key)
        historical_value_button.amount = historical_value
        historical_value_button:SetText(historical_value and money.to_string(historical_value, true, nil, 3) or '---')
    end
end

function update_item(item)
    local settings = read_settings(item.key)

    item.unit_vendor_price = unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = 1
        write_settings(settings, item.key)
        refresh = true
        return
    end

    scan.abort(scan_id)

    selected_item = item

    UIDropDownMenu_Initialize(duration_dropdown, initialize_duration_dropdown) -- TODO, wtf, why is this needed
    UIDropDownMenu_SetSelectedValue(duration_dropdown, settings.duration)

    hide_checkbox:SetChecked(settings.hidden)

    stack_size_slider:SetMinMaxValues(1, selected_item.max_charges or selected_item.max_stack)
    stack_size_slider:SetValue(settings.stack_size)
    quantity_update(true)

    unit_start_price_input:SetText(money.to_string(settings.start_price, true, nil, 3, nil, true))
    unit_buyout_price_input:SetText(money.to_string(settings.buyout_price, true, nil, 3, nil, true))

    if not existing_auctions[selected_item.key] then
        refresh_entries()
    end

    write_settings(settings, item.key)
    refresh = true
end

function update_inventory_records()
    local auctionable_map = temp-T
    for slot in info.inventory do
	    temp(slot)
	    local item_info = temp-info.container_item(unpack(slot))
        if item_info then
            local charge_class = item_info.charges or 0
            if info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                if not auctionable_map[item_info.item_key] then
                    local availability = T
                    for i = 0, 10 do
                        availability[i] = 0
                    end
                    availability[charge_class] = item_info.count
                    auctionable_map[item_info.item_key] = O(
	                    'item_id', item_info.item_id,
	                    'suffix_id', item_info.suffix_id,
	                    'key', item_info.item_key,
	                    'itemstring', item_info.itemstring,
	                    'name', item_info.name,
	                    'texture', item_info.texture,
	                    'quality', item_info.quality,
	                    'aux_quantity', item_info.charges or item_info.count,
	                    'max_stack', item_info.max_stack,
	                    'max_charges', item_info.max_charges,
	                    'availability', availability
                    )
                else
                    local auctionable = auctionable_map[item_info.item_key]
                    auctionable.availability[charge_class] = (auctionable.availability[charge_class] or 0) + item_info.count
                    auctionable.aux_quantity = auctionable.aux_quantity + (item_info.charges or item_info.count)
                end
            end
        end
    end
    release(inventory_records)
    inventory_records = values(auctionable_map)
    refresh = true
end

function refresh_entries()
	if selected_item then
		local item_id, suffix_id = selected_item.item_id, selected_item.suffix_id
        local item_key = item_id .. ':' .. suffix_id
        existing_auctions[item_key] = nil
        local query = scan_util.item_query(item_id)
        status_bar:update_status(0,0)
        status_bar:set_text('Scanning auctions...')

		scan_id = scan.start{
            type = 'list',
            ignore_owner = true,
			queries = A(query),
			on_page_loaded = function(page, total_pages)
                status_bar:update_status((page - 1) / total_pages, 0) -- TODO
                status_bar:set_text(format('Scanning Page %d / %d', page, total_pages))
			end,
			on_auction = function(auction_record)
				if auction_record.item_key == item_key then
                    record_auction(
                        auction_record.item_key,
                        auction_record.aux_quantity,
                        auction_record.unit_blizzard_bid,
                        auction_record.unit_buyout_price,
                        auction_record.duration,
                        auction_record.owner
                    )
				end
			end,
			on_abort = function()
				existing_auctions[item_key] = nil
                update_historical_value_button()
                status_bar:update_status(1, 1)
                status_bar:set_text('Scan aborted')
			end,
			on_complete = function()
				existing_auctions[item_key] = existing_auctions[item_key] or T
                refresh = true
                status_bar:update_status(1, 1)
                status_bar:set_text('Scan complete')
            end,
		}
	end
end

function record_auction(key, aux_quantity, unit_blizzard_bid, unit_buyout_price, duration, owner)
    existing_auctions[key] = existing_auctions[key] or T
    local entry
    for _, record in existing_auctions[key] do
        if unit_blizzard_bid == record.unit_blizzard_bid and unit_buyout_price == record.unit_buyout_price and aux_quantity == record.stack_size and duration == record.duration and is_player(owner) == record.own then
            entry = record
        end
    end
    if not entry then
        entry = O('stack_size', aux_quantity, 'unit_blizzard_bid', unit_blizzard_bid, 'unit_buyout_price', unit_buyout_price, 'duration', duration, 'own', is_player(owner), 'count', 0)
        tinsert(existing_auctions[key], entry)
    end
    entry.count = entry.count + 1
    return entry
end

function on_update()
    if refresh then
        refresh = false
        price_update()
        update_historical_value_button()
        update_item_configuration()
        update_inventory_listing()
        update_auction_listing()
    end
    validate_parameters()
end

function initialize_duration_dropdown()
    local function on_click()
        UIDropDownMenu_SetSelectedValue(duration_dropdown, this.value)
        local settings = read_settings()
        settings.duration = this.value
        write_settings(settings)
        refresh = true
    end
    UIDropDownMenu_AddButton{
        text = '2 Hours',
        value = DURATION_4,
        func = on_click,
    }
    UIDropDownMenu_AddButton{
        text = '8 Hours',
        value = DURATION_8,
        func = on_click,
    }
    UIDropDownMenu_AddButton{
        text = '24 Hours',
        value = DURATION_24,
        func = on_click,
    }
end
