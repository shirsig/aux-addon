local private, public = {}, {}
Aux.stat_average = public

private.PUSH_INTERVAL = 57600
private.NEW_RECORD = '0:0:0:0:0:0:0:0'

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

	local buyout = auction_info.buyout_price / auction_info.count

	local item_record = public.read_record(auction_info.item_key)

	item_record[1] = item_record[1] + 1 -- auction count
	item_record[2] = item_record[2] + 1 -- daily auction count
	item_record[3] = item_record[3] + buyout -- daily accumulated buyout

	private.write_record(auction_info.item_key, item_record)
end

function public.get_price_data(item_key)
	local auction_count, daily_auction_count, daily_accumulated_buyout, seen_days, EMA3, EMA7, EMA14 = unpack(public.read_record(item_key))
	local daily_average = daily_accumulated_buyout / daily_auction_count
	return auction_count, seen_days, daily_average, EMA3, EMA7, EMA14
end

function private.push_data()
	local data = private.load_data()
	local item_data = data.item_data

	for item_key, _ in pairs(item_data) do

		local item_record = public.read_record(item_key)
		local _, daily_auction_count, daily_accumulated_buyout, seen_days, EMA3, EMA7, EMA14 = unpack(item_record)

		if daily_auction_count > 0 then

			local daily_average = daily_accumulated_buyout / daily_auction_count

			if seen_days < 3 then
				-- for first 3 days perform plain average instead of EMAs
				EMA3 = (EMA3 * seen_days + daily_average) / (seen_days + 1)
				EMA7 = EMA3
				EMA14 = EMA3
			else
				-- do normal EMA calculations
				EMA3 = (EMA3 * 2 + daily_average) / 3
				EMA7 = (EMA7 * 6 + daily_average) / 7
				EMA14 = (EMA14 * 13 + daily_average) / 14
			end

			item_record[2] = 0 -- daily auction count
			item_record[3] = 0 -- daily accumulated buyout
			item_record[4] = seen_days + 1 -- seen days
			item_record[5] = EMA3 -- EMA3
			item_record[6] = EMA7 -- EMA7
			item_record[7] = EMA14 -- EMA14

			private.write_record(item_key, item_record)
		end
	end

	data.next_push = time() + private.PUSH_INTERVAL
end