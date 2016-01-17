local private, public = {}, {}
Aux.stat_histogram = public

private.NEW_RECORD = '0:0:0:0'

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.stat_histogram_data = dataset.stat_histogram_data or { item_data = {} }
	return dataset.stat_histogram_data
end

function private.read_current_record(item_key)
	if private.current_item_key ~= item_key then
		local data = private.load_data()
		local record = Aux.persistence.deserialize(data.item_data[item_key] or private.NEW_RECORD, ':')
		private.current_record = {
			min = tonumber(record[1]),
			max = tonumber(record[2]),
			step = tonumber(record[3]),
			count = tonumber(record[4]),
		}
		local values = Aux.persistence.deserialize(record[5], ',')
		for i, value in ipairs(values) do
			values[i] = tonumber(value)
		end
		private.current_record.values = values
		private.current_item_key = item_key
	end
end

function private.write_current_record()
	local data = private.load_data()

	data.item_data[private.current_item_key] = Aux.persistence.serialize({
		private.current_record.min,
		private.current_record.max,
		private.current_record.step,
		private.current_record.count,
		Aux.persistence.serialize(private.current_record.values, ','),
	}, ':')
end

function public.GetPriceData(item_key)
	private.read_current_record(item_key)

	local median = 0
	local Qone = 0
	local Qthree = 0
	local percent40 = 0
	local percent30 = 0
	local recount = 0

	if private.current_record.min == private.current_record.max then
		median = private.current_record.min * private.current_record.step
	else
		for i = private.current_record.min, private.current_record.max do
			recount = recount + private.current_record.values[i]
			if Qone == 0 and private.current_record.count > 4 then -- Q1 is meaningless with very little data
				if recount >= private.current_record.count / 4 then
					Qone = i * private.current_record.step
				end
			end
			if percent30 == 0 then
				if recount >= private.current_record.count * 0.3 then
					percent30 = i * private.current_record.step
				end
			end
			if percent40 == 0 then
				if recount >= private.current_record.count * 0.4 then
					percent40 = i * private.current_record.step
				end
			end
			if median == 0 then
				if recount >= private.current_record.count / 2 then
					median = i * private.current_record.step
				end
			end
			if Qthree == 0 and private.current_record.count > 4 then -- Q3 is meaningless with very little data
				if recount >= private.current_record.count * 3 / 4 then
					Qthree = i * private.current_record.step
				end
			end
		end
	end

	if private.current_record.count > 20 then
		if private.current_record.step > median / 85 and private.current_record.step > 1 then
			private.refactor(median * 3, 300)
			private.write_current_record()
			return private.GetPriceData()
		elseif private.current_record.step < median / 115 then
			private.refactor(median * 3, 300)
			private.write_current_record()
			return private.GetPriceData()
		end
	end

	return median, Qone, Qthree, private.current_record.step, percent40, percent30, private.current_record.count
end

function public.process_auction(auction_info)

	if auction_info.buyout_price == 0 then
		return
	end

	private.read_current_record(auction_info.item_key)

	local buyout = auction_info.buyout_price / auction_info.count

	if private.current_record.count == 0 then
		private.current_record.step = ceil(buyout / 100)
	end

	local index = ceil(buyout / private.current_record.step)

	if private.current_record.count <= 20 then

		if index > 100 then
			private.refactor(buyout, 100)
			index = 100
		end

		if not private.current_record.min then
			private.current_record.min = index
			private.current_record.max = index
			private.current_record.values[index] = 0
		elseif private.current_record.min > index then
			for i = index, private.current_record.min - 1 do
				private.current_record.values[i] = 0
			end
			private.current_record.min = index
		end

		private.current_record.values[index] = private.current_record.values[index] + 1
		private.current_record.count = private.current_record.count + 1

		private.write_record()

	elseif index <= 300 then

		if not private.current_record.min then
			private.current_record.min = index
			private.current_record.max = index
			private.current_record.values[index] = 0
		elseif private.current_record.min > index then
			for i = index, private.current_record.min - 1 do
				private.current_record.values[i] = 0
			end
			private.current_record.min = index
		elseif private.current_record.max < index then
			for i = private.current_record.max + 1, index do
				private.current_record.values[i] = 0
			end
			private.current_record.max = index
		end

		private.current_record.values[index] = private.current_record.values[index] + 1
		private.current_record.count = private.current_record.count + 1

		private.write_record()

	end
end

function private.refactor(pmax, precision)

	local new_step = ceil(pmax / precision)
	local conversion = private.current_record.step / new_step
	local new_min = ceil(conversion * private.current_record.min)
	local new_max = ceil(conversion * private.current_record.max)
	local new_values = {}

	if new_max > 300 then
		--we need to crop off the top end
		new_max = 300
		private.current_record.max = floor(300 / conversion)
	end
	for i = new_min, new_max do
		new_values[i] = 0
	end
	local new_count = 0
	for i = private.current_record.min, private.current_record.max do
		local j = ceil(conversion * i)
		new_values[j] = new_values[j] + private.current_record.values[i]
		new_count = new_count + private.current_record.values[i]
	end

	private.current_record.min = new_min
	private.current_record.max = new_max
	private.current_record.max = new_step
	private.current_record.count = new_count
	private.current_record.values = new_values
end