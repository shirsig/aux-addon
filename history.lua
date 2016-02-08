local private, public = {}, {}
Aux.history = public

aux_conservative_value = false

private.PUSH_INTERVAL = 57600
private.NEW_RECORD = '####'

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.history = dataset.history or { next_push = time() + private.PUSH_INTERVAL, item_records = {} }
	return dataset.history
end

function private.read_record(item_key)
	local data = private.load_data()

	if data.next_push < time() then
		data.next_push = time() + private.PUSH_INTERVAL
		private.push_data()
	end

	local fields = Aux.persistence.deserialize(data.item_records[item_key] or private.NEW_RECORD, '#')
	return {
--		auction_count = tonumber(record[1]),
--		day_count = tonumber(record[2]),
		daily_max_bid = tonumber(fields[1]),
		daily_min_buyout = tonumber(fields[2]),
		daily_max_buyout = tonumber(fields[3]),
		market_values = Aux.util.map(Aux.persistence.deserialize(fields[4], ';'), function(value)
			return tonumber(value)
		end),
		conservative_market_values = Aux.util.map(Aux.persistence.deserialize(fields[5], ';'), function(value)
			return tonumber(value)
		end),
	}
end

function private.write_record(item_key, record)
	local data = private.load_data()
	data.item_records[item_key] = Aux.persistence.serialize({
		record.daily_max_bid or '',
		record.daily_min_buyout or '',
		record.daily_max_buyout or '',
		Aux.persistence.serialize(record.market_values, ';'),
		Aux.persistence.serialize(record.conservative_market_values, ';', 'x'),
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

--function public.price_data(item_key)
--	local item_record = private.read_record(item_key)
--	return item_record.auction_count, item_record.day_count, private.daily_market_value(item_record.histogram), private.median(item_record.last_daily_values)
--end

function public.value(item_key)
	local item_record = private.read_record(item_key)

	local past_market_values
	if aux_conservative_value then
		past_market_values = item_record.conservative_market_values
	else
		past_market_values = item_record.market_values
	end

	if getn(past_market_values) > 0 then
		return private.median(past_market_values)
	elseif aux_conservative_value then
		return private.conservative_market_value(item_key)
	else
		return private.market_value(item_key)
	end
end

function private.market_value(item_key)
	local item_record = private.read_record(item_key)

	local buyout_estimate = item_record.daily_min_buyout and min(ceil(item_record.daily_min_buyout * 1.15), item_record.daily_max_buyout)

	if buyout_estimate and item_record.daily_max_bid then
		return max(item_record.daily_max_bid, buyout_estimate)
	elseif buyout_estimate then
		return buyout_estimate
	else
		return item_record.daily_max_bid
	end
end

function private.conservative_market_value(item_key)
	local item_record = private.read_record(item_key)

	if item_record.daily_max_bid and item_record.daily_min_buyout then
		return min(item_record.daily_max_bid, item_record.daily_min_buyout)
	elseif item_record.daily_max_bid then
		return item_record.daily_max_bid
	end
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

function private.push_data()
	local data = private.load_data()

	for item_key, _ in pairs(data.item_records) do

		local item_record = private.read_record(item_key)

		local market_value = private.market_value(item_key)
		if market_value then
			tinsert(item_record.market_values, market_value)
			while getn(item_record.market_values) > 11 do
				tremove(item_record.market_values, 1)
			end
		end

		local conservative_market_value = private.conservative_market_value(item_key)
		if conservative_market_value then
			tinsert(item_record.conservative_market_values, conservative_market_value)
			while getn(item_record.conservative_market_values) > 11 do
				tremove(item_record.conservative_market_values, 1)
			end
		end

		item_record.daily_max_bid = nil
		item_record.daily_min_buyout = nil
		item_record.daily_max_buyout = nil

		if market_value or conservative_market_value then
			private.write_record(item_key, item_record)
		end
	end
end