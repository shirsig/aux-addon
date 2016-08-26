aux 'history' local persistence = aux.persistence

local history_schema = {'record', '#', {next_push='number'}, {daily_min_buyout='number'}, {daily_max_price='number'}, {data_points={'list', ';', {'record', '@', {market_value='number'}, {time='number'}}}} }

value_cache = t

do
	local data
	function property.data.get()
		if not data then
			local dataset = persistence.dataset
			data = dataset.history or t
			dataset.history = data
		end
		return data
	end
end

do
	local next_push = 0
	function property.next_push.get()
		if time() > next_push then
			local date = date '*t'
			date.hour, date.min, date.sec = 24, 0, 0
			next_push = time(date)
		end
		return next_push
	end
end

function property.new_record.get()
	return -object('next_push', next_push, 'data_points', t)
end

function read_record(item_key)
	local record = data[item_key] and persistence.read(history_schema, data[item_key]) or new_record
	if record.next_push <= time() then
		push_record(record)
		write_record(item_key, record)
	end
	return record
end

function write_record(item_key, record)
	value_cache[item_key] = nil
	data[item_key] = persistence.write(history_schema, record)
end

function public.process_auction(auction_record)
	local item_record = read_record(auction_record.item_key)
	local unit_bid_price = ceil(auction_record.bid_price / auction_record.aux_quantity)
	local unit_buyout_price = ceil(auction_record.buyout_price / auction_record.aux_quantity)
	local max_unit_price = max(unit_buyout_price, unit_bid_price)
	local changed
	if unit_buyout_price > 0 and unit_buyout_price < (item_record.daily_min_buyout or huge) then
		item_record.daily_min_buyout = unit_buyout_price
		changed = true
	end
	if max_unit_price > (item_record.daily_max_price or 0) then
		item_record.daily_max_price = max_unit_price
		changed = true
	end
	if not changed then return end
	write_record(auction_record.item_key, item_record)
end

function public.price_data(item_key)
	local item_record = read_record(item_key)
	return item_record.daily_min_buyout, item_record.daily_max_price, item_record.data_points
end

function public.value(item_key)
	if not value_cache[item_key] or value_cache[item_key].next_push <= time() then
		local item_record, value
		item_record = read_record(item_key)
		if getn(item_record.data_points) > 0 then
			local total_weight, weighted_values = 0, tt
			for _, data_point in item_record.data_points do
				local weight = .99 ^ round((item_record.data_points[1].time - data_point.time) / (60 * 60 * 24))
				total_weight = total_weight + weight
				tinsert(weighted_values, -object('value', data_point.market_value, 'weight', weight))
			end
			for _, weighted_value in weighted_values do
				weighted_value.weight = weighted_value.weight / total_weight
			end
			value = weighted_median(weighted_values)
		else
			value = calculate_market_value(item_record)
		end
		value_cache[item_key] = -object('value', value, 'next_push', item_record.next_push)
	end
	return value_cache[item_key].value
end

function public.market_value(item_key)
	return calculate_market_value(read_record(item_key))
end

function calculate_market_value(item_record)
	return item_record.daily_min_buyout and min(ceil(item_record.daily_min_buyout * 1.15), item_record.daily_max_price)
end

function weighted_median(list)
	sort(list, function(a,b) return a.value < b.value end)
	local weight = 0
	for _, element in list do
		weight = weight + element.weight
		if weight >= .5 then
			return element.value
		end
	end
end

function push_record(item_record)
	for market_value in present(calculate_market_value(item_record)) do
		tinsert(item_record.data_points, 1, -object('market_value', market_value, 'time', item_record.next_push))
		while getn(item_record.data_points) > 11 do
			tremove(item_record.data_points)
		end
	end
	item_record.next_push, item_record.daily_min_buyout, item_record.daily_max_price = next_push, nil, nil
end