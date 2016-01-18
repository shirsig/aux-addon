local private, public = {}, {}
Aux.stat_average = public

private.PUSH_INTERVAL = 20
private.NEW_RECORD = '0:0:0:0:0:0:0:0:0'

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.stat_average_data = dataset.stat_average_data or { next_push = time() + private.PUSH_INTERVAL, item_data = {} }
	return dataset.stat_average_data
end

function public.read_record(item_key)
	local data = private.load_data()
	return Aux.util.map(Aux.persistence.deserialize(data.item_data[item_key] or private.NEW_RECORD, ':'), function(value)
		return tonumber(value)
	end)
end

function private.write_record(item_key, record)
	local data = private.load_data()
	data.item_data[item_key] = Aux.persistence.serialize(record, ':')
end

function public.process_auction(auction_info)

	if auction_info.buyout_price == 0 then
		return
	end

	local data = private.load_data()

	if data.next_push < time() then
		private.push_data()
	end

	local buyout = auction_info.buyout_price / auction_info.aux_quantity

	local item_record = public.read_record(auction_info.item_key)

	item_record[1] = item_record[1] + 1 -- auction count
	item_record[2] = item_record[2] + 1 -- daily auction count
	item_record[3] = item_record[3] + buyout -- daily accumulated buyout
	item_record[4] = item_record[4] ~= 0 and min(item_record[4], buyout) or buyout -- daily min buyout

	private.write_record(auction_info.item_key, item_record)
end

function public.get_price_data(item_key)
	local auction_count, daily_auction_count, daily_accumulated_buyout, daily_min_buyout, seen_days, avg_EMA5, avg_EMA30, min_EMA5, min_EMA30 = unpack(public.read_record(item_key))
	local daily_average = daily_accumulated_buyout / daily_auction_count
	return auction_count, seen_days, daily_average, daily_min_buyout, avg_EMA5, avg_EMA30, min_EMA5, min_EMA30
end

function public.get_mean(item_key)
	local _, daily_auction_count, daily_accumulated_buyout, daily_min_buyout, seen_days, avg_EMA5, avg_EMA30, min_EMA5, min_EMA30 = unpack(public.read_record(item_key))
--
--	local mean = 0
--	local daily_average = daily_accumulated_buyout / daily_auction_count
--
--	if seen_days == 0 then
--		if daily_auction_count > 0 then
--			mean = daily_average
--		end
--	elseif seen_days <= 3 then -- No EMAs before day 4
--		mean = EMA3
--		if daily_auction_count > 0 then
--			mean = (mean * seen_days + daily_average) / (seen_days + 1)
--		end
--	else
--		-- we have 4 or more days of data, potentially enough to perform mean and stddev calculations
--		local count = 0
--		local valueset, weightset = {}, {}
--
--		-- include daily data if available
--		if daily_auction_count > 0 then
--			count = 1
--			valueset[count] = daily_average
--			weightset[count] = 1
--		end
--
--		-- EMA3: standard weight 3, reduced if seenDays < 6, reduced if there was daily data, but never less than 1
--		local weight = 3 - count
--		if seen_days < 6 then
--			weight = seen_days - 3
--			if weight > 1 then
--				weight = weight - count
--			end
--		end
--		count = count + 1
--		valueset[count] = EMA3
--		weightset[count] = weight
--
--		-- EMA7: standard weight 4, reduced if seenDays < 10
--		if seen_days > 6 then
--			count = count + 1
--			valueset[count] = EMA7
--			if seen_days < 10 then
--				weightset[count] = seen_days - 6
--			else
--				weightset[count] = 4
--			end
--		end
--
--		-- EMA14: standard weight 7, reduced if seenDays < 17
--		if seen_days > 10 then
--			count = count + 1
--			valueset[count] = EMA14
--			if seen_days < 17 then
--				weightset[count] = seen_days - 10
--			else
--				weightset[count] = 7
--			end
--		end
--
--		-- we will use a weighted incremental algorithm, based on sample code by West and Knuth http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
--		local sumWeight, sumSquares = 0, 0 -- actually "sum of squares of differences from the (current) mean", but that's rather long for a variable name.
--		for i=1,count do
--			local value, weight = valueset[i], weightset[i]
--			local nextweight = weight + sumWeight
--			local valuediff = value - mean
--			local meanadjust = valuediff * weight / nextweight
--			mean = mean + meanadjust
--			sumSquares = sumSquares + sumWeight * valuediff * meanadjust
--			sumWeight = nextweight
--		end
--
--		--		stddev = sqrt(sumSquares / sumWeight * count / (count - 1))
--	end
--
--	return mean
end

function private.push_data()
	local data = private.load_data()
	local item_data = data.item_data

	for item_key, _ in pairs(item_data) do

		local item_record = public.read_record(item_key)
		local _, daily_auction_count, daily_accumulated_buyout, daily_min_buyout, seen_days, avg_EMA5, avg_EMA30, min_EMA5, min_EMA30 = unpack(item_record)

		if daily_auction_count > 0 then

			local daily_average = daily_accumulated_buyout / daily_auction_count

			if seen_days == 0 then
				avg_EMA5 = daily_average
				avg_EMA30 = daily_average
				min_EMA5 = daily_min_buyout
				min_EMA30 = daily_min_buyout
			else
				avg_EMA5 = 2/3 * avg_EMA5 + 1/3 * daily_average
				avg_EMA30 = 13/14 * avg_EMA30 + 1/14 * daily_average
				min_EMA5 = 2/3 * min_EMA5 + 1/3 * daily_min_buyout
				min_EMA30 = 13/14 * min_EMA30 + 1/14 * daily_min_buyout
			end

			item_record[2] = 0 -- daily auction count
			item_record[3] = 0 -- daily accumulated buyout
			item_record[4] = 0 -- daily min buyout
			item_record[5] = seen_days + 1 -- seen days
			item_record[6] = avg_EMA5 -- avg_EMA5
			item_record[7] = avg_EMA30 -- avg_EMA30
			item_record[8] = min_EMA5 -- min_EMA5
			item_record[9] = min_EMA30 -- min_EMA30

			private.write_record(item_key, item_record)
		end
	end

	data.next_push = time() + private.PUSH_INTERVAL
end