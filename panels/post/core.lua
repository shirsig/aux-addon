local private, public = {}, {}
Aux.post_frame = public

local existing_auctions = {}
local inventory_records
local scan_id = 0

local settings_schema = {'record', '#', {stack_size='number'}, {duration='number'}, {start_price='number'}, {buyout_price='number'}, {hidden='boolean'}}

local DURATION_4, DURATION_8, DURATION_24 = 120, 480, 1440

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
    item_key = item_key or private.selected_item.key
    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    local settings
    if dataset.post[item_key] then
        settings = Aux.persistence.read(settings_schema, dataset.post[item_key])
    else
        settings = private.default_settings()
    end
    return settings
end

function private.write_settings(settings, item_key)
    item_key = item_key or private.selected_item.key

    local dataset = Aux.persistence.load_dataset()
    dataset.post = dataset.post or {}

    dataset.post[item_key] = Aux.persistence.write(settings_schema, settings)
end

function private.get_unit_start_price()
    local money_text = private.unit_start_price:GetText()
    return Aux.money.from_string(money_text) or (tonumber(money_text) and tonumber(money_text) * 10000) or 0
end

function private.set_unit_start_price(amount)
    private.unit_start_price:SetText(Aux.money.to_string(amount, true, nil, 3))
end

function private.get_unit_buyout_price()
    local money_text = private.unit_buyout_price:GetText()
    return Aux.money.from_string(money_text) or (tonumber(money_text) and tonumber(money_text) * 10000) or 0
end

function private.set_unit_buyout_price(amount)
    private.unit_buyout_price:SetText(Aux.money.to_string(amount, true, nil, 3))
end

function private.update_inventory_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    Aux.item_listing.populate(private.item_listing, Aux.util.filter(inventory_records, function(record)
        local settings = private.read_settings(record.key)
        return record.aux_quantity > 0 and (not settings.hidden or private.show_hidden_checkbox:GetChecked())
    end))
end

function private.update_auction_listing()
    if not AuxPostFrame:IsVisible() then
        return
    end

    local auction_rows = {}
    if private.selected_item then
        local unit_start_price = private.get_unit_start_price()
        local unit_buyout_price = private.get_unit_buyout_price()

        for i, auction_record in ipairs(existing_auctions[private.selected_item.key] or {}) do

            local blizzard_bid_undercut, buyout_price_undercut = private.undercut(auction_record, private.stack_size_slider:GetValue())
            blizzard_bid_undercut = Aux.money.from_string(Aux.money.to_string(blizzard_bid_undercut, true, nil, 3))
            buyout_price_undercut = Aux.money.from_string(Aux.money.to_string(buyout_price_undercut, true, nil, 3))

            local stack_blizzard_bid_undercut, stack_buyout_price_undercut = private.undercut(auction_record, private.stack_size_slider:GetValue(), true)
            stack_blizzard_bid_undercut = Aux.money.from_string(Aux.money.to_string(stack_blizzard_bid_undercut, true, nil, 3))
            stack_buyout_price_undercut = Aux.money.from_string(Aux.money.to_string(stack_buyout_price_undercut, true, nil, 3))

            local stack_size = private.stack_size_slider:GetValue()
            local historical_value = Aux.history.value(private.selected_item.key)

            local bid_color
            if blizzard_bid_undercut < unit_start_price and stack_blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffff0000'
            elseif blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffff9218'
            elseif stack_blizzard_bid_undercut < unit_start_price then
                bid_color = '|cffffff00'
            end

            local buyout_color
            if buyout_price_undercut < unit_buyout_price and stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffff0000'
            elseif buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffff9218'
            elseif stack_buyout_price_undercut < unit_buyout_price then
                buyout_color = '|cffffff00'
            end

            tinsert(auction_rows, {
                cols = {
                    { value=auction_record.own and GREEN_FONT_COLOR_CODE..auction_record.count..FONT_COLOR_CODE_CLOSE or auction_record.count },
                    { value=Aux.auction_listing.time_left(auction_record.duration) },
                    { value=auction_record.stack_size == stack_size and GREEN_FONT_COLOR_CODE..auction_record.stack_size..FONT_COLOR_CODE_CLOSE or auction_record.stack_size },
                    { value=Aux.money.to_string(auction_record.unit_blizzard_bid, true, nil, 3, bid_color) },
                    { value=historical_value and Aux.auction_listing.percentage_historical(Aux.round(auction_record.unit_blizzard_bid / historical_value * 100)) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and Aux.money.to_string(auction_record.unit_buyout_price, true, nil, 3, buyout_color) or '---' },
                    { value=auction_record.unit_buyout_price > 0 and historical_value and Aux.auction_listing.percentage_historical(Aux.round(auction_record.unit_buyout_price / historical_value * 100)) or '---' },
                },
                record = auction_record,
            })
        end
        sort(auction_rows, function(a, b)
            return Aux.sort.multi_lt(
                {
                    a.record.unit_buyout_price == 0 and Aux.huge or a.record.unit_buyout_price,
                    a.record.unit_blizzard_bid,
                    a.record.stack_size,
                    b.record.own and 1 or 0,
                    a.record.duration,
                },
                {
                    b.record.unit_buyout_price == 0 and Aux.huge or b.record.unit_buyout_price,
                    b.record.unit_blizzard_bid,
                    b.record.stack_size,
                    a.record.own and 1 or 0,
                    b.record.duration,
                }
            )
        end)
    end
    private.auction_listing:SetData(auction_rows)
end

function public.select_item(item_key)
    for _, inventory_record in ipairs(Aux.util.filter(inventory_records, function(record) return record.aux_quantity > 0 end)) do
        if inventory_record.key == item_key then
            private.set_item(inventory_record)
            break
        end
    end
end

function public.on_load()
    public.create_frames(private, public)
end

function private.price_update()
    if private.selected_item then
        local settings = private.read_settings()

        local start_price_input = private.get_unit_start_price()
        settings.start_price = start_price_input
        local historical_value = Aux.history.value(private.selected_item.key)
        private.start_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(start_price_input / historical_value * 100)) or '---')

        local buyout_price_input = private.get_unit_buyout_price()
        settings.buyout_price = buyout_price_input
        local historical_value = Aux.history.value(private.selected_item.key)
        private.buyout_price_percentage:SetText(historical_value and Aux.auction_listing.percentage_historical(Aux.round(buyout_price_input / historical_value * 100)) or '---')

        private.write_settings(settings)
    end
end

function public.on_open()
    private.deposit:SetText('Deposit: '..Aux.money.to_string(0, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))

    private.set_unit_start_price(0)
    private.set_unit_buyout_price(0)

    private.update_inventory_records()

    private.refresh = true
end

function public.on_close()
    private.selected_item = nil
end

function private.post_auctions()
	if private.selected_item then
        local unit_start_price = private.get_unit_start_price()
        local unit_buyout_price = private.get_unit_buyout_price()
        local stack_size = private.stack_size_slider:GetValue()
        local stack_count
        stack_count = private.stack_count_slider:GetValue()
        local duration = UIDropDownMenu_GetSelectedValue(private.duration_dropdown)
		local key = private.selected_item.key

        local duration_code
		if duration == DURATION_4 then
            duration_code = 2
		elseif duration == DURATION_8 then
            duration_code = 3
		elseif duration == DURATION_24 then
            duration_code = 4
		end

		Aux.post.start(
			key,
			stack_size,
			duration,
            unit_start_price,
            unit_buyout_price,
			stack_count,
			function(posted)
                local new_auction_record
				for i = 1, posted do
                    new_auction_record = private.record_auction(key, stack_size, unit_start_price, unit_buyout_price, duration_code, UnitName('player'))
                end

                private.update_inventory_records()
                private.selected_item = nil
                for _, record in ipairs(inventory_records) do
                    if record.key == key then
                        private.set_item(record)
                    end
                end

                private.refresh = true
			end
		)
	end
end

function private.validate_parameters()

    if not private.selected_item then
        private.post_button:Disable()
        return
    end

    if private.get_unit_buyout_price() > 0 and private.get_unit_start_price() > private.get_unit_buyout_price() then
        private.post_button:Disable()
        return
    end

    if private.get_unit_start_price() == 0 then
        private.post_button:Disable()
        return
    end

    if private.stack_count_slider:GetValue() == 0 then
        private.post_button:Disable()
        return
    end

    private.post_button:Enable()
end

function private.update_item_configuration()

	if not private.selected_item then
		private.refresh_button:Disable()

		AuxPostParametersItemIconTexture:SetTexture(nil)
        AuxPostParametersItemCount:SetText()
        AuxPostParametersItemName:SetTextColor(unpack(Aux.gui.config.label_color.enabled))
        AuxPostParametersItemName:SetText('No item selected')

        private.unit_start_price:Hide()
        private.unit_buyout_price:Hide()
        private.stack_size_slider:Hide()
        private.stack_count_slider:Hide()
        private.deposit:Hide()
        private.duration_dropdown:Hide()
        private.historical_value_button:Hide()
        private.hide_checkbox:Hide()
    else
        private.unit_start_price:Show()
        private.unit_buyout_price:Show()
        private.stack_size_slider:Show()
        private.stack_count_slider:Show()
        private.deposit:Show()
        private.duration_dropdown:Show()
        private.historical_value_button:Show()
        private.hide_checkbox:Show()

        AuxPostParametersItemIconTexture:SetTexture(private.selected_item.texture)
        AuxPostParametersItemName:SetText('['..private.selected_item.name..']')
        local color = ITEM_QUALITY_COLORS[private.selected_item.quality]
        AuxPostParametersItemName:SetTextColor(color.r, color.g, color.b)
		if private.selected_item.aux_quantity > 1 then
            AuxPostParametersItemCount:SetText(private.selected_item.aux_quantity)
		else
            AuxPostParametersItemCount:SetText()
        end

        private.stack_size_slider.editbox:SetNumber(private.stack_size_slider:GetValue())
        private.stack_count_slider.editbox:SetNumber(private.stack_count_slider:GetValue())

        do
            local deposit_factor = Aux.neutral_faction() and 0.25 or 0.05
            local stack_size = private.stack_size_slider:GetValue()
            local stack_count
            stack_count = private.stack_count_slider:GetValue()
            local deposit = floor(private.selected_item.unit_vendor_price * deposit_factor * (private.selected_item.max_charges and 1 or stack_size)) * stack_count * UIDropDownMenu_GetSelectedValue(private.duration_dropdown) / 120

            private.deposit:SetText('Deposit: '..Aux.money.to_string(deposit, nil, nil, nil, Aux.gui.inline_color({255, 254, 250, 1})))
        end

        private.refresh_button:Enable()
	end
end

function private.undercut(record, stack_size, stack)
    local start_price = Aux.round(record.unit_blizzard_bid * (stack and record.stack_size or stack_size))
    local buyout_price = Aux.round(record.unit_buyout_price * (stack and record.stack_size or stack_size))

    if not record.own then
        start_price = max(0, start_price - 1)
        buyout_price = max(0, buyout_price - 1)
    end

    return start_price / stack_size, buyout_price / stack_size
end

function private.quantity_update(max_count)
    if private.selected_item then
        local max_stack_count = private.selected_item.max_charges and private.selected_item.availability[private.stack_size_slider:GetValue()] or floor(private.selected_item.availability[0] / private.stack_size_slider:GetValue())
        private.stack_count_slider:SetMinMaxValues(1, max_stack_count)
        if max_count then
            private.stack_count_slider:SetValue(max_stack_count)
        end
    end
    private.refresh = true
end

function private.unit_vendor_price(item_key)

    for slot in Aux.util.inventory() do

        local item_info = Aux.info.container_item(unpack(slot))
        if item_info and item_info.item_key == item_key then

            if Aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
                ClearCursor()
                PickupContainerItem(unpack(slot))
                ClickAuctionSellItemButton()
                local auction_sell_item = Aux.info.auction_sell_item()
                ClearCursor()
                ClickAuctionSellItemButton()
                ClearCursor()

                if auction_sell_item then
                    return auction_sell_item.unit_vendor_price
                end
            end
        end
    end
end

function private.update_historical_value_button()
    if private.selected_item then
        local historical_value = Aux.history.value(private.selected_item.key)
        private.historical_value_button.amount = historical_value
        private.historical_value_button:SetText(historical_value and Aux.money.to_string(historical_value, true, nil, 3) or '---')
    end
end

function private.set_item(item)
    local settings = private.read_settings(item.key)

    item.unit_vendor_price = private.unit_vendor_price(item.key)
    if not item.unit_vendor_price then
        settings.hidden = 1
        private.write_settings(settings, item.key)
        private.refresh = true
        return
    end

    Aux.scan.abort(scan_id)

    private.selected_item = item

    UIDropDownMenu_Initialize(private.duration_dropdown, private.initialize_duration_dropdown) -- TODO, wtf, why is this needed
    UIDropDownMenu_SetSelectedValue(private.duration_dropdown, settings.duration)

    private.hide_checkbox:SetChecked(settings.hidden)

    private.stack_size_slider:SetMinMaxValues(1, private.selected_item.max_charges or private.selected_item.max_stack)
    private.stack_size_slider:SetValue(settings.stack_size)
    private.quantity_update(true)

    private.unit_start_price:SetText(Aux.money.to_string(settings.start_price, true, nil, 3, nil, true))
    private.unit_buyout_price:SetText(Aux.money.to_string(settings.buyout_price, true, nil, 3, nil, true))

    if not existing_auctions[private.selected_item.key] then
        private.refresh_entries()
    end

    private.write_settings(settings, item.key)
    private.refresh = true
end

function private.update_inventory_records()
    inventory_records = {}
    private.refresh = true

    local auction_candidate_map = {}

    for slot in Aux.util.inventory() do

        local item_info = Aux.info.container_item(unpack(slot))
        if item_info then
            local charge_class = item_info.charges or 0

            if Aux.info.auctionable(item_info.tooltip, nil, item_info.lootable) then
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

    inventory_records = {}
    for _, auction_candidate in pairs(auction_candidate_map) do
        tinsert(inventory_records, auction_candidate)
    end
    sort(inventory_records, function(a, b) return a.name < b.name end)
    private.refresh = true
end

function private.refresh_entries()
	if private.selected_item then
		local item_id, suffix_id = private.selected_item.item_id, private.selected_item.suffix_id
        local item_key = item_id..':'..suffix_id

        existing_auctions[item_key] = nil

        local query = Aux.scan_util.item_query(item_id)

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

		scan_id = Aux.scan.start{
            type = 'list',
            ignore_owner = true,
			queries = { query },
			on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page - 1) / total_pages, 0) -- TODO
                private.status_bar:set_text(format('Scanning Page %d / %d', page, total_pages))
			end,
			on_auction = function(auction_record)
				if auction_record.item_key == item_key then
                    private.record_auction(
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
                private.update_historical_value_button()
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
			end,
			on_complete = function()
				existing_auctions[item_key] = existing_auctions[item_key] or {}
                private.refresh = true
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')
            end,
		}
	end
end

function private.record_auction(key, aux_quantity, unit_blizzard_bid, unit_buyout_price, duration, owner)
    existing_auctions[key] = existing_auctions[key] or {}
    local entry
    for _, existing_entry in ipairs(existing_auctions[key]) do
        if unit_blizzard_bid == existing_entry.unit_blizzard_bid and unit_buyout_price == existing_entry.unit_buyout_price and aux_quantity == existing_entry.stack_size and duration == existing_entry.duration and Aux.is_player(owner) == existing_entry.own then
            entry = existing_entry
        end
    end

    if not entry then
        entry = {
            stack_size = aux_quantity,
            unit_blizzard_bid = unit_blizzard_bid,
            unit_buyout_price = unit_buyout_price,
            duration = duration,
            own = Aux.is_player(owner),
            count = 0,
        }
        tinsert(existing_auctions[key], entry)
    end

    entry.count = entry.count + 1

    return entry
end

function public.on_update()
    if private.refresh then
        private.refresh = false
        private.price_update()
        private.update_historical_value_button()
        private.update_item_configuration()
        private.update_inventory_listing()
        private.update_auction_listing()
    end

    private.validate_parameters()
end

function private.initialize_duration_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.duration_dropdown, this.value)
        local settings = private.read_settings()
        settings.duration = this.value
        private.write_settings(settings)
        private.refresh = true
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
