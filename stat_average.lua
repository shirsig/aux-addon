local private, public = {}, {}
Aux.stat_average = public

private.PUSH_INTERVAL = 57600

function private.load_data()
	local dataset = Aux.persistence.load_dataset()
	dataset.stat_average_data = dataset.stat_average_data or {}
	return dataset.stat_average_data
end

function private.get_item_key(auction_info)
	return auction_info.item_id..':'..auction_info.suffix_id
end

function private.process_auction(auction_info)
	if auction_info.buyout_price == 0 then
		return
	end
	
	local item_record = private.load_data()[get_item_key(auction_info)] or {
		daily_auction_count = 0,
		daily_unit_count = 0,
		accumulated_buyout_price = 0,
		seen_days = 0,
		EMA3 = 0,
		EMA7 = 0,
		EMA14 = 0,
		average_min_buyout = 0,
	}
	
	item_record.daily_auction_count = item_record.daily_auction_count + 1
	item_record.daily_unit_count = item_record.daily_unit_count + auction_info.count
	item_record.accumulated_buyout_price = item_record.accumulated_buyout_price + auction_info.buyout_price
	item_record.daily_min_buyout_price = item_record.daily_min_buyout_price and min(item_record.daily_min_buyout_price, auction_info.buyout_price / auction_info.count) or auction_info.buyout_price / auction_info.count
end

function private.push_data()
	local data = private.load_data()

	for item_key, item_record in pairs(data) do

		if item_record.daily_auction_count > 0 then
		
			local daily_average = item_record.daily_accumulated_buyout / item_record.daily_unit_count

			if item_record.seen_days < 3 then
				-- for first 3 days perform plain average instead of EMAs
				item_record.EMA3 = (item_record.EMA3 * item_record.seen_days + daily_average) / (item_record.seen_days + 1)
				item_record.average_min_buyout = (item_record.average_min_buyout * item_record.seen_days + item_record.daily_min_buyout) / (item_record.seen_days + 1)
				item_record.EMA7 = item_record.EMA3
				item_record.EMA14 = item_record.EMA3
			else
				-- do normal EMA calculations
				item_record.EMA3 = (item_record.EMA3 * 2 + daily_average) / 3)
				item_record.EMA7 = (item_record.EMA7 * 6 + daily_average) / 7)
				item_record.EMA14 = (item_record.EMA14 * 13 + daily_average) / 14)

				if item_record.daily_min_buyout / item_record.average_min_buyout < 0.9 then
					item_record.average_min_buyout = (item_record.average_min_buyout + item_record.daily_min_buyout) / 2
				else
					item_record.average_min_buyout = (item_record.average_min_buyout * 7 + item_record.daily_min_buyout) / 8
				end
			end
			
			item_record.count = item_record.unit_count + item_record.daily_unit_count
			item_record.count = item_record.auction_count + item_record.daily_auction_count
			item_record.seen_days = item_record.seen_days + 1
			
			item_record.daily_auction_count = 0
			item_record.daily_unit_count = 0
			item_record.daily_min_buyout = nil
			item_record.daily_accumulated_buyout = 0
		end
	end

	realmdata.dailypush = time() + PUSHTIME
end
