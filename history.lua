local private, public = {}, {}
Aux.history = public

private.PUSH_INTERVAL = 57600

function private.new_record()
	return { next_push = time() + private.PUSH_INTERVAL, market_values = {}, max_bids = {} }
end

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.history = dataset.history or { item_records = {} }
	return dataset.history
end

function private.read_record(item_key)
	local data = private.load_data()

	local record
	if data.item_records[item_key] then
		local fields = Aux.persistence.deserialize(data.item_records[item_key], '#')
		record = {
			next_push = tonumber(fields[1]),
			daily_max_bid = tonumber(fields[2]),
			daily_min_buyout = tonumber(fields[3]),
			daily_max_buyout = tonumber(fields[4]),
			market_values = Aux.util.map(Aux.persistence.deserialize(fields[5], ';'), function(value)
				return tonumber(value)
			end),
			max_bids = Aux.util.map(Aux.persistence.deserialize(fields[6], ';'), function(value)
				return tonumber(value)
			end),
		}
	else
		record = private.new_record()
	end

	if record.next_push < time() then
		private.push_record(record)
		private.write_record(item_key, record)
	end

	return record
end

function private.write_record(item_key, record)
	local data = private.load_data()
	data.item_records[item_key] = Aux.persistence.serialize({
		record.next_push or '',
		record.daily_max_bid or '',
		record.daily_min_buyout or '',
		record.daily_max_buyout or '',
		Aux.persistence.serialize(record.market_values, ';'),
		Aux.persistence.serialize(record.max_bids, ';', 'x'),
	},'#')
end

function public.process_auction(auction_info)

	local item_record = private.read_record(auction_info.item_key)

	--	item_record.auction_count = item_record.auction_count + 1

	if auction_info.high_bid > 0 then
		local unit_high_bid = ceil(auction_info.high_bid / auction_info.aux_quantity)
		item_record.daily_max_bid = item_record.daily_max_bid and max(item_record.daily_max_bid, unit_high_bid) or unit_high_bid
	end

	if auction_info.buyout_price > 0 then
		local unit_buyout_price = ceil(auction_info.buyout_price / auction_info.aux_quantity)
		item_record.daily_max_buyout = item_record.daily_max_buyout and max(item_record.daily_max_buyout, unit_buyout_price) or unit_buyout_price
		item_record.daily_min_buyout = item_record.daily_min_buyout and min(item_record.daily_min_buyout, unit_buyout_price) or unit_buyout_price
	end

	private.write_record(auction_info.item_key, item_record)
end

function public.price_data(item_key)
	local item_record = private.read_record(item_key)
	return item_record.daily_max_bid, item_record.daily_min_buyout, item_record.daily_max_buyout, item_record.market_values, item_record.max_bids
end

function public.value(item_key)
	if aux_conservative_history then
		return private.conservative_historical_value(item_key)
	else
		return private.historical_value(item_key)
	end
end

function private.historical_value(item_key)
	local item_record = private.read_record(item_key)

	if getn(item_record.market_values) > 0 then
		return private.median(item_record.market_values)
	else
		return private.market_value(item_record)
	end
end

function private.conservative_historical_value(item_key)
	local item_record = private.read_record(item_key)

	if getn(item_record.max_bids) > 0 then
		return private.median(item_record.max_bids)
	else
		return item_record.daily_max_bid
	end
end

function private.market_value(item_record)
	local estimate

	if item_record.daily_min_buyout and item_record.daily_max_bid then
		estimate = max(item_record.daily_min_buyout, item_record.daily_max_bid)
	elseif item_record.daily_min_buyout then
		estimate = item_record.daily_min_buyout
	else
		estimate = item_record.daily_max_bid
	end

	if item_record.daily_max_buyout and item_record.daily_max_buyout > estimate then
		estimate = min(ceil(estimate * 1.15), item_record.daily_max_buyout)
	end

	return estimate
end

function private.median(list)
	if getn(list) == 0 then
		return
	end

	local sorted_list = {}
	for _, v in ipairs(list) do
		tinsert(sorted_list, v)
	end
	sort(sorted_list)

	local middle = (getn(sorted_list) + 1) / 2
	return (sorted_list[floor(middle)] + sorted_list[ceil(middle)]) / 2
end

function private.push_record(item_record)
	local market_value = private.market_value(item_record)
	if market_value then
		tinsert(item_record.market_values, market_value)
		while getn(item_record.market_values) > 11 do
			tremove(item_record.market_values, 1)
		end
	end

	if item_record.daily_max_bid then
		tinsert(item_record.max_bids, item_record.daily_max_bid)
		while getn(item_record.max_bids) > 11 do
			tremove(item_record.max_bids, 1)
		end
	end

	item_record.daily_max_bid = nil
	item_record.daily_min_buyout = nil
	item_record.daily_max_buyout = nil
	item_record.next_push = time() + private.PUSH_INTERVAL
end