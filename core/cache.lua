module 'cache' import 'info'

MIN_ITEM_ID = 1
MAX_ITEM_ID = 30000

items_schema = {'record', '#', {name='string'}, {quality='number'}, {level='number'}, {class='string'}, {subclass='string'}, {slot='string'}, {max_stack='number'}, {texture='string'}}
merchant_buy_schema = {'record', '#', {unit_price='number'}, {limited='boolean'}}

_g.aux_items = {}
_g.aux_item_ids = {}
_g.aux_auctionable_items = {}
_g.aux_merchant_buy = {}
_g.aux_merchant_sell = {}
_g.aux_characters = {}

function LOAD()
	import 'persistence' 'info'
	scan_wdb()

	event_listener('MERCHANT_SHOW', on_merchant_show)
	event_listener('MERCHANT_CLOSED', on_merchant_closed)
	event_listener('MERCHANT_UPDATE', on_merchant_update)
	event_listener('BAG_UPDATE', on_bag_update)

	CreateFrame('Frame', nil, MerchantFrame):SetScript('OnUpdate', merchant_on_update)

	event_listener('NEW_AUCTION_UPDATE', function()
		for info in present(info.auction_sell_item()) do
			for item_id in present(item_id(info.name)) do
				_g.aux_merchant_sell[_m.item_id(info.name)] = info.vendor_price / (_m.info.max_item_charges(item_id) or info.count)
			end
		end
	end)
end

do
	local sell_scan_countdown, incomplete_buy_data

	function on_merchant_show()
		merchant_sell_scan()
		incomplete_buy_data = not merchant_buy_scan()
	end

	function on_merchant_closed()
		sell_scan_countdown = nil
		incomplete_buy_data = false
	end

	function on_merchant_update()
		if incomplete_buy_data then
			incomplete_buy_data = not merchant_buy_scan()
		end
	end

	function on_bag_update()
		if MerchantFrame:IsVisible() then
			sell_scan_countdown = 10
		end
	end

	function merchant_on_update()
		if sell_scan_countdown == 0 then
			sell_scan_countdown = nil
			merchant_sell_scan()
		elseif sell_scan_countdown then
			sell_scan_countdown = sell_scan_countdown - 1
		end
	end
end

function merchant_loaded()
	for i=1,GetMerchantNumItems() do
		if not GetMerchantItemLink(i) then
			return false
		end
	end
	return true
end

function public.merchant_info(item_id)
	local buy_info
	if _g.aux_merchant_buy[item_id] then
		buy_info = persistence.read(merchant_buy_schema, _g.aux_merchant_buy[item_id])
	end

	return _g.aux_merchant_sell[item_id], buy_info and buy_info.unit_price, buy_info and buy_info.limited
end

function public.item_info(item_id)
	local data_string = _g.aux_items[item_id]
	if data_string then
		local cached_data = persistence.read(items_schema, data_string)
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
	return _g.aux_item_ids[strlower(item_name)]
end

function merchant_buy_scan()

	local incomplete_data
	for i=1,GetMerchantNumItems() do
		local _, _, price, count, stock = GetMerchantItemInfo(i)
		local link = GetMerchantItemLink(i)
		if link then
			local item_id = info.parse_link(link)
			local new_unit_price, new_limited = price / count, stock >= 0
			if _g.aux_merchant_buy[item_id] then
				local buy_info = persistence.read(merchant_buy_schema, _g.aux_merchant_buy[item_id])

				local unit_price
				if buy_info.limited and not new_limited then
					unit_price = new_unit_price
				elseif new_limited and not buy_info.limited then
					unit_price = buy_info.unit_price
				else
					unit_price = min(buy_info.unit_price, new_unit_price)
				end

				_g.aux_merchant_buy[item_id] = persistence.write(merchant_buy_schema, {
					unit_price = unit_price,
					limited = buy_info.limited and new_limited,
				})
			else
				_g.aux_merchant_buy[item_id] = persistence.write(merchant_buy_schema, {
					unit_price = new_unit_price,
					limited = new_limited,
				})
			end
		else
			incomplete_data = true
		end
	end

	return not incomplete_data
end

function merchant_sell_scan()
	for slot in info.inventory do temp=slot
		local item_info = temp-info.container_item(unpack(slot))
		if item_info then
			_g.aux_merchant_sell[item_info.item_id] = item_info.tooltip_money / item_info.aux_quantity
		end
	end
end

function scan_wdb(item_id)
	item_id = item_id or MIN_ITEM_ID

	local processed = 0
	while processed <= 100 and item_id <= MAX_ITEM_ID do
		local itemstring = 'item:'..item_id
		local name, _, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
		if name and not _g.aux_item_ids[strlower(name)] then
			_g.aux_item_ids[strlower(name)] = item_id
			_g.aux_items[item_id] = persistence.write(items_schema, {
				name = name,
				quality = quality,
				level = level,
				class = class,
				subclass = subclass,
				slot = slot,
				max_stack = max_stack,
				texture = texture,
			})
			local tooltip = info.tooltip(function(tt) tt:SetHyperlink(itemstring) end)
			if info.auctionable(tooltip, quality) then
				tinsert(_g.aux_auctionable_items, strlower(name))
			end
			processed = processed + 1
		end
		item_id = item_id + 1
	end

	if item_id <= MAX_ITEM_ID then
		local t0 = GetTime()
		thread(when, function() return GetTime() - t0 > 0.1 end, scan_wdb, item_id)
	else
		sort(_g.aux_auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
	end
end

function public.populate_wdb(item_id)
	item_id = item_id or MIN_ITEM_ID

	if item_id > MAX_ITEM_ID then
		log 'Cache populated.'
		return
	end

	if not GetItemInfo('item:'..item_id) then
		log('Fetching item '..item_id..'.')
		AuxTooltip:SetHyperlink('item:'..item_id)
	end

	thread(populate_wdb, item_id + 1)
end