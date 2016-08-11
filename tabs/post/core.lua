local m, public, private = aux.tab(2, 'Post', 'post_tab')

local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440
local settings_schema = {'record', '#', {stack_size='number'}, {duration='number'}, {start_price='number'}, {buyout_price='number'}, {hidden='boolean'}}

private.existing_auctions = {}
private.inventory_records = nil
private.scan_id = 0
private.selected_item = nil
private.refresh = nil

function m.LOAD()
	m.create_frames()
end

function m.OPEN()
    m.frame:Show()

    m.deposit:SetText('Deposit: '..aux.money.to_string(0, nil, nil, nil, aux.gui.inline_color.text.enabled))

    m.set_unit_start_price(0)
    m.set_unit_buyout_price(0)

    m.update_inventory_records()

    m.refresh = true
end

function m.CLOSE()
    m.selected_item = nil
    m.frame:Hide()
end

function m.USE_ITEM(item_info)
	m.select_item(item_info.item_key)
end

function private.default_settings()
    return {
        duration = DURATION_8,
        stack_size = 1,
        start_price = 0,
        buyout_price = 0,
        hidden = false,
    }
end

function private.read_settings(item_key)
    item_key = item_key or m.selected_item.key
    local dataset = aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    local settings
    if dataset.post[item_key] then
        settings = aux.persistence.read(settings_schema, dataset.post[item_key])
    else
        settings = m.default_settings()
    end
    return settings
end

function private.write_settings(settings, item_key)
    item_key = item_key or m.selected_item.key

    local dataset = aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    dataset.post[item_key] = aux.persistence.write(settings_schema, settings)
end

function private.get_unit_start_price()
    local money_text = m.unit_start_price:GetText()
    return aux.money.from_string(money_text) or 0
end

function private.set_unit_start_price(amount)
    m.unit_start_price:SetText(aux.money.to_string(amount, true, nil, 3))
end

function private.get_unit_buyout_price()
    local money_text = m.unit_buyout_price:GetText()
    return aux.money.from_string(money_text) or 0
end

function private.set_unit_buyout_price(amount)
    m.unit_buyout_price:SetText(aux.money.to_string(amount, true, nil, 3))
end

function private.update_inventory_listing()
    if not m.ACTIVE() then
        return
    end

    aux.item_listing.populate(m.item_listing, aux.util.values(aux.util.filter(m.inventory_records, function(record)
        local settings = m.read_settings(record.key)
        return record.aux_quantity > 0 and (not settings.hidden or m.show_hidden_checkbox:GetChecked())
    end)))
end

function private.update_auction_listing()
    if not m.ACTIVE() then
        return
    end

    local auction_rows = {}
    if m.selected_item then
        local unit_start_price = m.get_unit_start_price()
        local unit_buyout_price = m.get_unit_buyout_price()

        for i, auction_record in m.existing_auctions[m.selected_item.key] or {} do

            local blizzard_bid_undercut, buyout_price_undercut = m.undercut(auction_record, m.stack_size_slider:GetValue())
            blizzard_bid_undercut = aux.money.from_string(aux.money.to_string(blizzard_bid_undercut, true, nil, 3))
            buyout_price_undercut = aux.money.from_string(aux.money.to_string(buyout_price_undercut, true, nil, 3))

            local stack_blizzard_bid_undercut, stack_buyout_price_undercut = m.undercut(auction_record, m.stack_size_slider:GetValue(), true)
            stack_blizzard_bid_undercut = aux.money.from_string(aux.money.to_string(stack_blizzard_bid_undercut, true, nil, 3))
            stack_buyout_price_undercut = aux.money.from_string(aux.money.to_string(stack_buyout_price_undercut, true, nil, 3))

            local stack_size = m.stack_size_slider:GetValue()
            local historical_value = aux.history.value(m.selected_item.key)

            local bid_color
            if blizzard_bid_undercut < unit_start_price and stack_blizzard_bid_undercut < unit_start_price then
                bid_color = aux.auction_listing.colors.RED
            elseif blizzard_bid_undercut < unit_start_price then
                bid_color = aux.auction_listing.colors.ORANGE
            elseif stack_blizzard_bid_undercut < unit_start_price then
                bid_color = aux.auction_listing.colors.YELLOW
            end

            local buyout_color
            if buyout_price_undercut < unit_buyout_price and stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = aux.auction_listing.colors.RED
            elseif buyout_price_undercut < unit_buyout_price then
                buyout_color = aux.auction_listing.colors.ORANGE
            elseif stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = aux.auction_listing.colors.YELLOW
            end

            tinsert(auction_rows, {
                cols = {
                    { value=auction_record.own and aux.auction_listing.colors.GREEN..auction_record.count..FONT_COLOR_CODE_CLOSE or auction_record.count },
                    { value=aux.auction_listing.time_left(auction_record.duration) },
                    { value=auction_record.stack_size == stack_size and aux.auction_listing.colors.GREEN..auction_record.stack_size..FONT_COLOR_CODE_CLOSE or auction_record.stack_size },
                    { value=aux.money.to_string(auction_record.unit_blizzard_bid, true, nil, 3, bid_color) },
                    { value=historical_value and aux.auction_listing.percentage_historical(aux.util.round(auction_record.unit_blizzard_bid / historical_value * 100)) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and aux.money.to_string(auction_record.unit_buyout_price, true, nil, 3, buyout_color) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and historical_value and aux.auction_listing.percentage_historical(aux.util.round(auction_record.unit_buyout_price / historical_value * 100)) or '---' },
                },
                record = auction_record,
            })
        end
        sort(auction_rows, function(a, b)
            return aux.sort.multi_lt(
                {
                    a.record.unit_buyout_price == 0 and aux.huge or a.record.unit_buyout_price,
                    a.record.unit_blizzard_bid,
                    a.record.stack_size,
                    b.record.own and 1 or 0,
                    a.record.duration,
                },
                {
                    b.record.unit_buyout_price == 0 and aux.huge or b.record.unit_buyout_price,
                    b.record.unit_blizzard_bid,
                    b.record.stack_size,
                    a.record.own and 1 or 0,
                    b.record.duration,
                }
            )
        end)
    end
    m.auction_listing:SetData(auction_rows)
end

function public.select_item(item_key)
    for _, inventory_record in aux.util.filter(m.inventory_records, function(record) return record.aux_quantity > 0 end) do
        if inventory_record.key == item_key then
            m.set_item(inventory_record)
            break
        end
    end
end

function private.price_update()
    if m.selected_item then
        local settings = m.read_settings()

        local start_price_input = m.get_unit_start_price()
        settings.start_price = start_price_input
        local historical_value = aux.history.value(m.selected_item.key)
        m.start_price_percentage:SetText(historical_value and aux.auction_listing.percentage_historical(aux.util.round(start_price_input / historical_value * 100)) or '---')

        local buyout_price_input = m.get_unit_buyout_price()
        settings.buyout_price = buyout_price_input
        local historical_value = aux.history.value(m.selected_item.key)
        m.buyout_price_percentage:SetText(historical_value and aux.auction_listing.percentage_historical(aux.util.round(buyout_price_input / historical_value * 100)) or '---')

        m.write_settings(settings)
    end
end

function private.post_auctions()
	if m.selected_item then
        local unit_start_price = m.get_unit_start_price()
        local unit_buyout_price = m.get_unit_buyout_price()
        local stack_size = m.stack_size_slider:GetValue()
        local stack_count
        stack_count = m.stack_count_slider:GetValue()
        local duration = UIDropDownMenu_GetSelectedValue(m.duration_dropdown)
		local key = m.selected_item.key

        local duration_code
		if duration == DURATION_4 then
            duration_code = 2
		elseif duration == DURATION_8 then
            duration_code = 3
		elseif duration == DURATION_24 then
            duration_code = 4
		end

		aux.post.start(
			key,
			stack_size,
			duration,
            unit_start_price,
            unit_buyout_price,
			stack_count,
			function(posted)
                local new_auction_record
				for i=1,posted do
                    new_auction_record = m.record_auction(key, stack_size, unit_start_price, unit_buyout_price, duration_code, UnitName('player'))
                end

                m.update_inventory_records()
                m.selected_item = nil
                for _, record in m.inventory_records do
                    if record.key == key then
                        m.set_item(record)
                    end
                end

                m.refresh = true
			end
		)
	end
end

function private.validate_parameters()

    if not m.selected_item then
        m.post_button:Disable()
        return
    end

    if m.get_unit_buyout_price() > 0 and m.get_unit_start_price() > m.get_unit_buyout_price() then
        m.post_button:Disable()
        return
    end

    if m.get_unit_start_price() == 0 then
        m.post_button:Disable()
        return
    end

    if m.stack_count_slider:GetValue() == 0 then
        m.post_button:Disable()
        return
    end

    m.post_button:Enable()
end

function private.update_item_configuration()

	if not m.selected_item then
        m.refresh_button:Disable()

        m.item.texture:SetTexture(nil)
        m.item.count:SetText()
        m.item.name:SetTextColor(unpack(aux.gui.color.label.enabled))
        m.item.name:SetText('No item selected')

        m.start_price_frame:Hide()
        m.buyout_price_frame:Hide()
        m.stack_size_slider:Hide()
        m.stack_count_slider:Hide()
        m.deposit:Hide()
        m.duration_dropdown:Hide()
        m.historical_value_button:Hide()
        m.hide_checkbox:Hide()
    else
        m.start_price_frame:Show()
        m.buyout_price_frame:Show()
        m.stack_size_slider:Show()
        m.stack_count_slider:Show()
        m.deposit:Show()
        m.duration_dropdown:Show()
        m.historical_value_button:Show()
        m.hide_checkbox:Show()

        m.item.texture:SetTexture(m.selected_item.texture)
        m.item.name:SetText('['..m.selected_item.name..']')
        local color = ITEM_QUALITY_COLORS[m.selected_item.quality]
        m.item.name:SetTextColor(color.r, color.g, color.b)
		if m.selected_item.aux_quantity > 1 then
            m.item.count:SetText(m.selected_item.aux_quantity)
		else
            m.item.count:SetText()
        end

        m.stack_size_slider.editbox:SetNumber(m.stack_size_slider:GetValue())
        m.stack_count_slider.editbox:SetNumber(m.stack_count_slider:GetValue())

        do
            local deposit_factor = aux.neutral_faction() and 0.25 or 0.05
            local stack_size = m.stack_size_slider:GetValue()
            local stack_count
            stack_count = m.stack_count_slider:GetValue()
            local deposit = floor(m.selected_item.unit_vendor_price * deposit_factor * (m.selected_item.max_charges and 1 or stack_size)) * stack_count * UIDropDownMenu_GetSelectedValue(m.duration_dropdown) / 120

            m.deposit:SetText('Deposit: '..aux.money.to_string(deposit, nil, nil, nil, aux.gui.inline_color.text.enabled))
        end

        m.refresh_button:Enable()
	end
end

function private.undercut(record, stack_size, stack)
    local start_price = aux.util.round(record.unit_blizzard_bid * (stack and record.stack_size or stack_size))
    local buyout_price = aux.util.round(record.unit_buyout_price * (stack and record.stack_size or stack_size))

    if not record.own then
        start_price = max(0, start_price - 1)
        buyout_price = max(0, buyout_price - 1)
    end

    return start_price / stack_size, buyout_price / stack_size
end

function private.quantity_update(max_count)
    if m.selected_item then
        local max_stack_count = m.selected_item.max_charges and m.selected_item.availability[m.stack_size_slider:GetValue()] or floor(m.selected_item.availability[0] / m.stack_size_slider:GetValue())
        m.stack_count_slider:SetMinMaxValues(1, max_stack_count)
        if max_count then
            m.stack_count_slider:SetValue(max_stack_count)
        end
    end
    m.refresh = true
end

function private.unit_vendor_price(item_key)

    for slot in aux.util.inventory() do

        local item_info = aux.info.container_item(unpack(slot))
        if item_info and item_info.item_key == item_key then

            if aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                ClearCursor()
                PickupContainerItem(unpack(slot))
                ClickAuctionSellItemButton()
                local auction_sell_item = aux.info.auction_sell_item()
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

function private.update_historical_value_button()
    if m.selected_item then
        local historical_value = aux.history.value(m.selected_item.key)
        m.historical_value_button.amount = historical_value
        m.historical_value_button:SetText(historical_value and aux.money.to_string(historical_value, true, nil, 3) or '---')
    end
end

function private.set_item(item)
    local settings = m.read_settings(item.key)

    item.unit_vendor_price = m.unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = 1
        m.write_settings(settings, item.key)
        m.refresh = true
        return
    end

    aux.scan.abort(m.scan_id)

    m.selected_item = item

    UIDropDownMenu_Initialize(m.duration_dropdown, m.initialize_duration_dropdown) -- TODO, wtf, why is this needed
    UIDropDownMenu_SetSelectedValue(m.duration_dropdown, settings.duration)

    m.hide_checkbox:SetChecked(settings.hidden)

    m.stack_size_slider:SetMinMaxValues(1, m.selected_item.max_charges or m.selected_item.max_stack)
    m.stack_size_slider:SetValue(settings.stack_size)
    m.quantity_update(true)

    m.unit_start_price:SetText(aux.money.to_string(settings.start_price, true, nil, 3, nil, true))
    m.unit_buyout_price:SetText(aux.money.to_string(settings.buyout_price, true, nil, 3, nil, true))

    if not m.existing_auctions[m.selected_item.key] then
        m.refresh_entries()
    end

    m.write_settings(settings, item.key)
    m.refresh = true
end

function private.update_inventory_records()
    m.inventory_records = {}
    m.refresh = true

    local auction_candidate_map = {}

    for slot in aux.util.inventory() do

        local item_info = aux.info.container_item(unpack(slot))
        if item_info then
            local charge_class = item_info.charges or 0

            if aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                if not auction_candidate_map[item_info.item_key] then

                    local availability = {}
                    for i=0,10 do
                        availability[i] = 0
                    end
                    availability[charge_class] = item_info.count

                    auction_candidate_map[item_info.item_key] = {
                        item_id = item_info.item_id,
                        suffix_id = item_info.suffix_id,

                        key = item_info.item_key,
                        itemstring = item_info.itemstring,

                        name = item_info.name,
                        texture = item_info.texture,
                        quality = item_info.quality,
                        aux_quantity = item_info.charges or item_info.count,
                        max_stack = item_info.max_stack,
                        max_charges = item_info.max_charges,
                        availability = availability,
                    }
                else
                    local candidate = auction_candidate_map[item_info.item_key]
                    candidate.availability[charge_class] = (candidate.availability[charge_class] or 0) + item_info.count
                    candidate.aux_quantity = candidate.aux_quantity + (item_info.charges or item_info.count)
                end
            end
        end
    end

    m.inventory_records = {}
    for _, auction_candidate in auction_candidate_map do
        tinsert(m.inventory_records, auction_candidate)
    end
    sort(m.inventory_records, function(a, b) return a.name < b.name end)
    m.refresh = true
end

function private.refresh_entries()
	if m.selected_item then
		local item_id, suffix_id = m.selected_item.item_id, m.selected_item.suffix_id
        local item_key = item_id..':'..suffix_id

        m.existing_auctions[item_key] = nil

        local query = aux.scan_util.item_query(item_id)

        m.status_bar:update_status(0,0)
        m.status_bar:set_text('Scanning auctions...')

		m.scan_id = aux.scan.start{
            type = 'list',
            ignore_owner = true,
			queries = { query },
			on_page_loaded = function(page, total_pages)
                m.status_bar:update_status(100 * (page - 1) / total_pages, 0) -- TODO
                m.status_bar:set_text(format('Scanning Page %d / %d', page, total_pages))
			end,
			on_auction = function(auction_record)
				if auction_record.item_key == item_key then
                    m.record_auction(
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
				m.existing_auctions[item_key] = nil
                m.update_historical_value_button()
                m.status_bar:update_status(100, 100)
                m.status_bar:set_text('Scan aborted')
			end,
			on_complete = function()
				m.existing_auctions[item_key] = m.existing_auctions[item_key] or {}
                m.refresh = true
                m.status_bar:update_status(100, 100)
                m.status_bar:set_text('Scan complete')
            end,
		}
	end
end

function private.record_auction(key, aux_quantity, unit_blizzard_bid, unit_buyout_price, duration, owner)
    m.existing_auctions[key] = m.existing_auctions[key] or {}
    local entry
    for _, existing_entry in m.existing_auctions[key] do
        if unit_blizzard_bid == existing_entry.unit_blizzard_bid and unit_buyout_price == existing_entry.unit_buyout_price and aux_quantity == existing_entry.stack_size and duration == existing_entry.duration and aux.is_player(owner) == existing_entry.own then
            entry = existing_entry
        end
    end

    if not entry then
        entry = {
            stack_size = aux_quantity,
            unit_blizzard_bid = unit_blizzard_bid,
            unit_buyout_price = unit_buyout_price,
            duration = duration,
            own = aux.is_player(owner),
            count = 0,
        }
        tinsert(m.existing_auctions[key], entry)
    end

    entry.count = entry.count + 1

    return entry
end

function private.on_update()
    if m.refresh then
        m.refresh = false
        m.price_update()
        m.update_historical_value_button()
        m.update_item_configuration()
        m.update_inventory_listing()
        m.update_auction_listing()
    end

    m.validate_parameters()
end

function private.initialize_duration_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(m.duration_dropdown, this.value)
        local settings = m.read_settings()
        settings.duration = this.value
        m.write_settings(settings)
        m.refresh = true
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
