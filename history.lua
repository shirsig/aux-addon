local private, public = {}, {}
Aux.history = public

private.PUSH_INTERVAL = 57600

aux_market_value_type = 'buyout'

local data

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.history = dataset.history or {
		item_records = {},
		next_push = time() + private.PUSH_INTERVAL,
	}
	return dataset.history
end

function public.on_login()
	data = private.load_data()
	for item_key, _ in pairs(data.item_records) do
		data.item_records[item_key] = private.deserialize_item_record(data.item_records[item_key])
	end
end

function public.on_logout()
	for item_key, _ in pairs(data.item_records) do
		data.item_records[item_key] = private.serialize_item_record(data.item_records[item_key])
	end
end

function private.serialize_item_record(item_record)
	return Aux.persistence.serialize({
		Aux.persistence.serialize(item_record.daily_bid_values, ';'),
		Aux.persistence.serialize(item_record.daily_buyout_values, ';'),
		Aux.persistence.serialize(item_record.bids_of_today:values(), ';'),
		Aux.persistence.serialize(item_record.buyouts_of_today:values(), ';'),
	}, '#')
end

function private.deserialize_item_record(data_string)
	local fields = Aux.persistence.deserialize(data_string, '#')

	local bids_of_today = Aux.util.set()
	bids_of_today:add_all(Aux.util.map(Aux.persistence.deserialize(fields[3], ';'), function(value)
		return tonumber(value)
	end))

	local buyouts_of_today = Aux.util.set()
	buyouts_of_today:add_all(Aux.util.map(Aux.persistence.deserialize(fields[4], ';'), function(value)
		return tonumber(value)
	end))

	return {
		daily_bid_values = Aux.util.map(Aux.persistence.deserialize(fields[1], ';'), function(value)
			return tonumber(value)
		end),
		daily_buyout_values = Aux.util.map(Aux.persistence.deserialize(fields[2], ';'), function(value)
			return tonumber(value)
		end),
		bids_of_today = bids_of_today,
		buyouts_of_today = buyouts_of_today,
	}
end

function private.new_item_record()
	return { daily_bid_values = {}, daily_buyout_values = {}, bids_of_today = Aux.util.set(), buyouts_of_today = Aux.util.set() }
end

function private.price_class(price)
	return Aux.round(math.log(price) / math.log(1.1))
end

function private.price_class_price(class)
	return 1.1^class
end

function public.process_auction(auction_info)

	if data.next_push < time() then
		private.push_data()
	end

	if auction_info.high_bid > 0 then
		data.item_records[auction_info.item_key] = data.item_records[auction_info.item_key] or private.new_item_record()
		local bid = Aux.round(auction_info.high_bid / auction_info.aux_quantity)
		data.item_records[auction_info.item_key].bids_of_today:add(bid)
--		data.item_records[auction_info.item_key].bids_of_today:add(private.price_class(auction_info.high_bid / auction_info.aux_quantity))
	end

	if auction_info.buyout_price > 0 then
		data.item_records[auction_info.item_key] = data.item_records[auction_info.item_key] or private.new_item_record()
		local buyout = Aux.round(auction_info.buyout_price / auction_info.aux_quantity)
		data.item_records[auction_info.item_key].buyouts_of_today:add(buyout)
--		data.item_records[auction_info.item_key].buyouts_of_today:add(private.price_class(auction_info.buyout_price / auction_info.aux_quantity))
	end
end

--function public.price_data(item_key)
--	local item_record = private.read_record(item_key)
--	return item_record.auction_count, item_record.day_count, private.daily_market_value(item_record.histogram), private.median(item_record.last_daily_values)
--end

function public.market_value(item_key)
	local record = data.item_records[item_key]

	if not record then
		return
	end

	local daily_values = aux_market_value_type == 'buyout' and record.daily_buyout_values or record.daily_bid_values

	if getn(daily_values) == 0 then
		if aux_market_value_type == 'buyout' then
			return private.daily_buyout_value(item_key)
		elseif aux_market_value_type == 'bid' then
			return private.daily_bid_value(item_key)
		end
	else
		return private.median(daily_values)
	end
end

function private.daily_bid_value(item_key)
	local prices = data.item_records[item_key].bids_of_today:values()

	if getn(prices) == 0 then
		return
	end
	sort(prices, function(a,b) return b < a end)

	local acc = 0
	local cutoff = ceil(getn(prices) * 0.2)
	for i=1,cutoff do
		acc = acc + prices[i]
--		acc = acc + private.price_class_price(prices[i])
	end

	return acc / cutoff
end

function private.daily_buyout_value(item_key)
	local data = private.load_data()
	local prices = data.item_records[item_key].buyouts_of_today:values()

	if getn(prices) == 0 then
		return
	end
	sort(prices)

	local acc = 0
	local cutoff = ceil(getn(prices) * 0.2)
	for i=1,cutoff do
		acc = acc + prices[i]
--		acc = acc + private.price_class_price(prices[i])
	end

	return acc / cutoff
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

function public.push_data()

	for item_key, record in pairs(data.item_records) do

		local daily_bid_value = private.daily_bid_value(item_key)
		if daily_bid_value then
			tinsert(record.daily_bid_values, Aux.round(daily_bid_value))
		end
		while getn(record.daily_bid_values) > 11 do
			tremove(record.daily_bid_values, 1)
		end
		record.bids_of_today = Aux.util.set()

		local daily_buyout_value = private.daily_buyout_value(item_key)
		if daily_buyout_value then
			tinsert(record.daily_buyout_values, Aux.round(daily_buyout_value))
		end
		while getn(record.daily_buyout_values) > 11 do
			tremove(record.daily_buyout_values, 1)
		end
		record.buyouts_of_today = Aux.util.set()

	end

	data.next_push = time() + private.PUSH_INTERVAL
end