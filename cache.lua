local private, public = {}, {}
Aux.cache = public

local MIN_ITEM_ID, MAX_ITEM_ID = 1, 30000

aux_items = {}
aux_item_ids = {}
aux_auctionable_items = {}
aux_merchant_buy = {}
aux_merchant_sell = {}

local items_schema = {'record', '#', {name='string'}, {quality='number'}, {level='number'}, {class='string'}, {subclass='string'}, {slot='string'}, {max_stack='number'}, {texture='string'}}
local merchant_buy_schema = {'record', '#', {unit_price='number'}, {limited='boolean'}}

function public.on_load()
	private.scan_wdb()
	Aux.control.event_listener('MERCHANT_SHOW', private.scan_merchant).start()
	Aux.control.event_listener('MERCHANT_UPDATE', private.scan_merchant).start()
	Aux.control.event_listener('BAG_UPDATE', function()
		if MerchantFrame:IsVisible() then
			private.scan_merchant()
		end
	end).start()
	Aux.control.event_listener('NEW_AUCTION_UPDATE', function()
		local info = Aux.info.auction_sell_item()
		if info then
			if Aux.cache.item_id(info.name) then
				aux_merchant_sell[Aux.cache.item_id(info.name)] = info.vendor_price / info.aux_quantity
			end
		end
	end).start()
end

function public.merchant_info(item_id)
	local buy_info
	if aux_merchant_buy[item_id] then
		buy_info = Aux.persistence.read(merchant_buy_schema, aux_merchant_buy[item_id])
	end

	return aux_merchant_sell[item_id], buy_info and buy_info.unit_price, buy_info and buy_info.limited
end

function public.item_info(item_id)
	local data_string = aux_items[item_id]
	if data_string then
		local cached_data = Aux.persistence.read(items_schema, data_string)
		return {
			name = cached_data.name,
			itemstring = 'item:'..item_id..':0:0:0',
			quality = cached_data.quality,
			level = cached_data.level,
			class = cached_data.class,
			subclass = cached_data.subclass,
			slot = cached_data.slot,
			max_stack = cached_data.max_stack,
			texture = cached_data.texture,
		}
	end
end

function public.item_id(item_name)
	return aux_item_ids[strlower(item_name)]
end

function private.scan_merchant()
	for slot in Aux.util.inventory() do
		local item_info = Aux.info.container_item(unpack(slot))
		if item_info then
			aux_merchant_sell[item_info.item_id] = item_info.tooltip.money / item_info.aux_quantity
		end
	end

	-- TODO maybe more detail? zone or  local merchant_name = UnitName('npc')
	local merchant_item_count = GetMerchantNumItems()
	for i=1,merchant_item_count do
		local link = GetMerchantItemLink(i)
		if link then
			local item_id = Aux.info.parse_hyperlink(link)
			local _, _, price, count, stock = GetMerchantItemInfo(i)
			local new_unit_price, new_limited = price / count, stock >= 0
			if aux_merchant_buy[item_id] then
				local buy_info = Aux.persistence.read(merchant_buy_schema, aux_merchant_buy[item_id])

				local unit_price
				if buy_info.limited and not new_limited then
					unit_price = new_unit_price
				elseif new_limited and not buy_info.limited then
					unit_price = buy_info.unit_price
				else
					unit_price = min(buy_info.unit_price, new_unit_price)
				end

				aux_merchant_buy[item_id] = Aux.persistence.write(merchant_buy_schema, {
					unit_price = unit_price,
					limited = buy_info.limited and new_limited,
				})
			else
				aux_merchant_buy[item_id] = Aux.persistence.write(merchant_buy_schema, {
					unit_price = new_unit_price,
					limited = new_limited,
				})
			end
		end
	end
end

function private.scan_wdb()

	local function helper(item_id)
		local processed = 0
		while processed <= 100 and item_id <= MAX_ITEM_ID do
			local itemstring = 'item:'..item_id
			local name, _, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
			if name and not aux_item_ids[strlower(name)] then
				aux_item_ids[strlower(name)] = item_id
				aux_items[item_id] = Aux.persistence.write(items_schema, {
					name = name,
					quality = quality,
					level = level,
					class = class,
					subclass = subclass,
					slot = slot,
					max_stack = max_stack,
					texture = texture,
				})
				local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink(itemstring) end)
				if Aux.info.auctionable(tooltip, quality) then
					tinsert(aux_auctionable_items, strlower(name))
				end
				processed = processed + 1
			end
			item_id = item_id + 1
		end

		if item_id <= MAX_ITEM_ID then
			local t0 = GetTime()
			Aux.control.as_soon_as(function() return GetTime() - t0 > 0.1 end, function()
				return helper(item_id)
			end)
		else
			sort(aux_auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
		end
	end

	helper(MIN_ITEM_ID)
end

function public.populate_wdb()

	local function helper(item_id)
		if item_id > MAX_ITEM_ID then
			Aux.log('Cache populated.')
			return
		end

		if not GetItemInfo('item:'..item_id) then
			Aux.log('Fetching item '..item_id..'.')
			AuxTooltip:SetHyperlink('item:'..item_id)
		end

		Aux.control.on_next_update(function()
			return helper(item_id + 1)
		end)
	end

	helper(MIN_ITEM_ID)
end