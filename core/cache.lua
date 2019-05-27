module 'aux.util.info'

local T = require 'T'
local aux = require 'aux'
local persistence = require 'aux.util.persistence'

local MIN_ITEM_ID = 1
local MAX_ITEM_ID = 30000

local items_schema = {'tuple', '#', {name='string'}, {quality='number'}, {level='number'}, {class='string'}, {subclass='string'}, {slot='string'}, {max_stack='number'}, {texture='string'}}
local merchant_buy_schema = {'tuple', '#', {unit_price='number'}, {limited='boolean'}}

function aux.handle.LOAD()
	scan_wdb()

	aux.event_listener('MERCHANT_SHOW', on_merchant_show)
	aux.event_listener('MERCHANT_CLOSED', on_merchant_closed)
	aux.event_listener('MERCHANT_UPDATE', on_merchant_update)
	aux.event_listener('BAG_UPDATE', on_bag_update)

	CreateFrame('Frame', nil, MerchantFrame):SetScript('OnUpdate', merchant_on_update)

	aux.event_listener('NEW_AUCTION_UPDATE', function()
		local data = auction_sell_item()
		if data then
			local item_id = item_id(data.name)
			if item_id then
				aux.account_data.merchant_sell[item_id] = data.vendor_price / (max_item_charges(item_id) or data.count)
			end
		end
	end)
end

do
	local characters = {}
	function M.is_player(name)
		return not not characters[name]
	end
	function aux.handle.LOAD()
		characters = aux.realm_data.characters
		for k, v in pairs(characters) do
			if GetTime() > v + 60 * 60 * 24 * 30 then
				characters[k] = nil
			end
		end
		characters[UnitName'player'] = GetTime()
	end
end

do
	local sell_scan_queued, incomplete_buy_data
	function on_merchant_show()
		merchant_sell_scan()
		incomplete_buy_data = not merchant_buy_scan()
	end
	function on_merchant_closed()
		sell_scan_queued = nil
		incomplete_buy_data = false
	end
	function on_merchant_update()
		if incomplete_buy_data then
			incomplete_buy_data = not merchant_buy_scan()
		end
	end
	function on_bag_update()
		if MerchantFrame:IsVisible() then
			sell_scan_queued = true
		end
	end
	function merchant_on_update()
		if sell_scan_queued then
			sell_scan_queued = nil
			merchant_sell_scan()
		end
	end
end

function merchant_loaded()
	for i = 1, GetMerchantNumItems() do
		if not GetMerchantItemLink(i) then
			return false
		end
	end
	return true
end

function M.merchant_info(item_id)
	local buy_info
	if aux.account_data.merchant_buy[item_id] then
		buy_info = persistence.read(merchant_buy_schema, aux.account_data.merchant_buy[item_id])
	end
	return aux.account_data.merchant_sell[item_id], buy_info and buy_info.unit_price, buy_info and buy_info.limited
end

function M.item_info(item_id)
	local data_string = aux.account_data.items[item_id]
	if data_string then
		local cached_data = persistence.read(items_schema, data_string)
		return T.map(
			'name', cached_data.name,
			'itemstring', 'item:' .. item_id .. ':0:0:0',
			'quality', cached_data.quality,
			'level', cached_data.level,
			'class', cached_data.class,
			'subclass', cached_data.subclass,
			'slot', cached_data.slot,
			'max_stack', cached_data.max_stack,
			'texture', cached_data.texture
		)
	end
end

function M.item_id(item_name)
	return aux.account_data.item_ids[strlower(item_name)]
end

function merchant_buy_scan()
	local incomplete_data
	for i = 1, GetMerchantNumItems() do
		local _, _, price, count, stock = GetMerchantItemInfo(i)
		local link = GetMerchantItemLink(i)
		if link then
			local item_id = parse_link(link)
			local new_unit_price, new_limited = price / count, stock >= 0
			if aux.account_data.merchant_buy[item_id] then
				local buy_info = persistence.read(merchant_buy_schema, aux.account_data.merchant_buy[item_id])

				local unit_price
				if buy_info.limited and not new_limited then
					unit_price = new_unit_price
				elseif new_limited and not buy_info.limited then
					unit_price = buy_info.unit_price
				else
					unit_price = min(buy_info.unit_price, new_unit_price)
				end

                aux.account_data.merchant_buy[item_id] = persistence.write(merchant_buy_schema, T.temp-T.map(
					'unit_price', unit_price,
					'limited', buy_info.limited and new_limited
				))
			else
				aux.account_data.merchant_buy[item_id] = persistence.write(merchant_buy_schema, T.temp-T.map(
					'unit_price', new_unit_price,
					'limited', new_limited
				))
			end
		else
			incomplete_data = true
		end
	end

	return not incomplete_data
end

function merchant_sell_scan()
	for slot in pairs(inventory()) do
		T.temp(slot)
		local item_info = T.temp-container_item(unpack(slot))
		if item_info then
			aux.account_data.merchant_sell[item_info.item_id] = item_info.tooltip_money / item_info.aux_quantity
		end
	end
end

function scan_wdb(item_id)
	item_id = item_id or MIN_ITEM_ID

	local processed = 0
	while processed <= 100 and item_id <= MAX_ITEM_ID do
		local itemstring = 'item:' .. item_id
		local name, _, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
		if name and not aux.account_data.item_ids[strlower(name)] then
            aux.account_data.item_ids[strlower(name)] = item_id
			aux.account_data.items[item_id] = persistence.write(items_schema, T.temp-T.map(
				'name', name,
				'quality', quality,
				'level', level,
				'class', class,
				'subclass', subclass,
				'slot', slot,
				'max_stack', max_stack,
				'texture', texture
			))
			local tooltip = tooltip('link', itemstring)
			if auctionable(tooltip, quality) then
				tinsert(aux.account_data.auctionable_items, strlower(name))
			end
			processed = processed + 1
		end
		item_id = item_id + 1
	end

	if item_id <= MAX_ITEM_ID then
		aux.thread(aux.when, aux.later(.5), scan_wdb, item_id)
	else
		sort(aux.account_data.auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
	end
end

function M.populate_wdb(item_id)
	item_id = item_id or MIN_ITEM_ID
	if item_id > MAX_ITEM_ID then
		aux.print('Cache populated.')
		return
	end
	if not GetItemInfo('item:' .. item_id) then
		aux.print('Fetching item ' .. item_id .. '.')
		AuxTooltip:SetHyperlink('item:' .. item_id)
	end
	aux.thread(populate_wdb, item_id + 1)
end