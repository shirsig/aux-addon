local private, public = {}, {}
Aux.history = public

function private.next_push()
	local date = date('*t')
	date.hour, date.min, date.sec = 24, 0, 0
	return time(date)
end

function private.new_record()
	return { next_push = private.next_push(), data_points = {} }
end

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.history = dataset.history or {}
	return dataset.history
end

function public.test()
	local data = private.load_data()
	for key, _ in data do
		local record = private.read_record(key)
		record.next_push = 0
		private.write_record(key, record)
	end
end

function public.test2()
	local data = private.load_data()
	for key, _ in data do
		data[key] = data[key]..'5000@5000'
		for i=1,100 do
			data[key] = data[key]..';9999@9995'
		end
	end
end

function private.read_record(item_key)
	local data = private.load_data()

	local record
	if data[item_key] then
		local fields = Aux.util.split(data[item_key], '#')
		record = {
			next_push = tonumber(fields[1]),
			daily_min_buyout = tonumber(fields[2]),
			daily_max_price = tonumber(fields[3]),
			data_points = Aux.util.map(Aux.persistence.deserialize(fields[4], ';'), function(data_point)
				local market_value, time = unpack(Aux.util.split(data_point, '@'))
				return { market_value = tonumber(market_value), time = tonumber(time) }
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
	data[item_key] = Aux.util.join({
		record.next_push or '',
		record.daily_min_buyout or '',
		record.daily_max_price or '',
		Aux.persistence.serialize(Aux.util.map(record.data_points, function(data_point)
			return Aux.util.join({data_point.market_value, data_point.time}, '@')
		end), ';'),
	},'#')
end

function public.process_auction(auction_record)
	local item_record = private.read_record(auction_record.item_key)

	local unit_bid_price = ceil(auction_record.bid_price / auction_record.aux_quantity)
	local unit_buyout_price = ceil(auction_record.buyout_price / auction_record.aux_quantity)

	if auction_record.buyout_price > 0 then
		item_record.daily_min_buyout = item_record.daily_min_buyout and min(item_record.daily_min_buyout, unit_buyout_price) or unit_buyout_price
	end

	item_record.daily_max_price = max(item_record.daily_max_price or 0, unit_buyout_price, unit_bid_price)

	private.write_record(auction_record.item_key, item_record)
end

function public.price_data(item_key)
	local item_record = private.read_record(item_key)
	return item_record.daily_min_buyout, item_record.daily_max_price, item_record.data_points
end

function public.value(item_key)
	local item_record = private.read_record(item_key)

	local i = 1
	local median_list = {}
	while getn(median_list) <= 11 and i <= getn(item_record.data_points) do
		tinsert(median_list, item_record.data_points[i].market_value)
		i = i + 1
	end

	if getn(median_list) > 0 then
		return private.median(median_list)
	else
		return private.market_value(item_record)
	end
end

function public.market_value(item_key)
	local item_record = private.read_record(item_key)
	return private.market_value(item_record)
end

function private.market_value(item_record)
	return item_record.daily_min_buyout and min(ceil(item_record.daily_min_buyout * 1.15), item_record.daily_max_price)
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
		tinsert(item_record.data_points, 1, { market_value = market_value, time = time() })
		while getn(item_record.data_points) > 100 do
			tremove(item_record.data_points)
		end
	end

	item_record.daily_min_buyout = nil
	item_record.daily_max_price = nil
	item_record.next_push = private.next_push()
end