local private, public = {}, {}
Aux.history = public

private.PUSH_INTERVAL = 57600

local item_records, next_push

function private.encode_item_records(item_records)
	local record_strings = {}
	for item_key, record in pairs(item_records) do
		tinsert(record_strings, private.encode_item_record(item_key, record))
	end
	return  Aux.persistence.serialize(record_strings, '|')
end

function private.encode_item_record(item_key, record)
	return Aux.persistence.serialize({
		item_key,
		Aux.persistence.serialize(record.daily_bid_values, ';'),
		Aux.persistence.serialize(record.daily_buyout_values, ';'),
		Aux.persistence.serialize(record.bids_of_today:values(), ';'),
		Aux.persistence.serialize(record.buyouts_of_today:values(), ';'),
	}, '#')
end

function private.decode_item_records(data_string)
	local item_records = {}
	for _, record_string in Aux.persistence.deserialize(data_string, '|') do
		local item_key, record = private.decode_item_record(record_string)
		item_records[item_key] = record
	end
	return item_records
end

function private.decode_item_record(data_string)
	local fields = Aux.persistence.deserialize(data_string, '#')

	local bids_of_today = Aux.util.set()
	bids_of_today:add_all(Aux.util.map(Aux.persistence.deserialize(fields[4], ';'), function(value)
		return tonumber(value)
	end))

	local buyouts_of_today = Aux.util.set()
	buyouts_of_today:add_all(Aux.util.map(Aux.persistence.deserialize(fields[5], ';'), function(value)
		return tonumber(value)
	end))

	return fields[1], {
		daily_bid_values = Aux.util.map(Aux.persistence.deserialize(fields[2], ';'), function(value)
			return tonumber(value)
		end),
		daily_buyout_values = Aux.util.map(Aux.persistence.deserialize(fields[3], ';'), function(value)
			return tonumber(value)
		end),
		bids_of_today = bids_of_today,
		buyouts_of_today = buyouts_of_today,
	}
end

function public.on_login()
	local dataset = Aux.persistence.load_dataset()
	local fields = Aux.persistence.deserialize(dataset.history, '/')
	next_push = tonumber(fields[1]) or time() + private.PUSH_INTERVAL
	item_records = private.decode_item_records(fields[2])
end

function public.on_logout()
	local dataset = Aux.persistence.load_dataset()
	dataset.history = Aux.util.join({ next_push, private.encode_item_records(item_records) }, '/')
end

function private.new_item_record()
	return { daily_bid_values = {}, daily_buyout_values = {}, bids_of_today = Aux.util.set(), buyouts_of_today = Aux.util.set() }
end

function public.process_auction(auction_info)

	if next_push < time() then
		private.push_data()
	end

	if auction_info.high_bid > 0 then
		item_records[auction_info.item_key] = item_records[auction_info.item_key] or private.new_item_record()
		local bid = Aux.round(auction_info.high_bid / auction_info.aux_quantity)
		item_records[auction_info.item_key].bids_of_today:add(bid)
	end

	if auction_info.buyout_price > 0 then
		item_records[auction_info.item_key] = item_records[auction_info.item_key] or private.new_item_record()
		local buyout = Aux.round(auction_info.buyout_price / auction_info.aux_quantity)
		item_records[auction_info.item_key].buyouts_of_today:add(buyout)
	end
end

--function public.price_data(item_key)
--	local item_record = private.read_record(item_key)
--	return item_record.auction_count, item_record.day_count, private.daily_market_value(item_record.histogram), private.median(item_record.last_daily_values)
--end

function public.market_value(item_key)
	local record = item_records[item_key]

	if not record then
		return
	end

	if getn(record.daily_buyout_values) == 0 then
		return private.daily_buyout_value(item_key)
	else
		return private.median(record.daily_buyout_values)
	end
end

function private.daily_bid_value(item_key)
	local prices = item_records[item_key].bids_of_today:values()

	if getn(prices) == 0 then
		return
	end
	sort(prices, function(a,b) return b < a end)

	local acc = 0
	local cutoff = ceil(getn(prices) * 0.2)
	for i=1,cutoff do
		acc = acc + prices[i]
	end

	return acc / cutoff
end

function private.daily_buyout_value(item_key)
	local prices = item_records[item_key].buyouts_of_today:values()

	if getn(prices) == 0 then
		return
	end
	sort(prices)

	local acc = 0
	local cutoff = ceil(getn(prices) * 0.2)
	for i=1,cutoff do
		acc = acc + prices[i]
	end

	return acc / cutoff
end

--function private.daily_market_value(histogram)
--
--	local auction_count = 0
--	for _, frequency in ipairs(histogram) do
--		auction_count = auction_count + frequency
--	end
--
--	if auction_count == 0 then
--		return 0
--	end
--
--	-- average of lowest 25%
--	local sum, count = 0, 0
--	local limit = auction_count * 0.25
--	for i, frequency in ipairs(histogram) do
--		local limited_frequency = min(frequency, limit - count)
--		sum = sum + 1.1 ^ (i - 1) * 1.05 * limited_frequency
--		count = count + limited_frequency
--		if count >= limit then
--			break
--		end
--	end
--	return sum / limit
--end

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

	for item_key, record in pairs(item_records) do

		local daily_bid_value = private.daily_bid_value(item_key)
		if daily_bid_value then
			tinsert(record.daily_bid_values, Aux.round(daily_bid_value))
		end
		while getn(record.daily_bid_values) > 11 do
			tremove(record.daily_bid_values, 1)
		end
		record.bids_of_today = {}

		local daily_buyout_value = private.daily_buyout_value(item_key)
		if daily_buyout_value then
			tinsert(record.daily_buyout_values, Aux.round(daily_buyout_value))
		end
		while getn(record.daily_buyout_values) > 11 do
			tremove(record.daily_buyout_values, 1)
		end
		record.buyouts_of_today = {}

	end

	next_push = time() + private.PUSH_INTERVAL
end