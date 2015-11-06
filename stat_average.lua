private, public = {}, {}
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
		auction_count = 0,
		unit_count = 0,
		accumulated_buyout_price = 0,
	}
	
	
	item_record.auction_count = item_record.auction_count + 1
	item_record.unit_count = item_record.unit_count + auction_info.count
	item_record.accumulated_buyout_price = item_record.accumulated_buyout_price + auction_info.buyout_price


	--[[ data = {
		[1] = total buyout,
		[2] = seen count,
		[3] = today's minimum buyout,
		[4] = auctions count, (only recorded if different from seen count)
	}--]]

	
	if data0 then
		local aucs = data0[4]
		if aucs then
			data0[4] = aucs + 1
		elseif stack > 1 then
			-- no recorded auctions count, so auctions count must have been equal to seen count up to this point
			data0[4] = data0[2] + 1
		end
		local mbo = data0[3]
		if mbo == 0 or buyoutper < mbo then
			data0[3] = buyoutper
		end
		data0[2] = data0[2] + stack
		data0[1] = data0[1] + buyout
	end

	if dataP then
		local aucs = dataP[4]
		if aucs then
			dataP[4] = aucs + 1
		elseif stack > 1 then
			-- no recorded auctions count, so auctions count must have been equal to seen count up to this point
			dataP[4] = dataP[2] + 1
		end
		local mbo = dataP[3]
		if mbo == 0 or buyoutper < mbo then
			dataP[3] = buyoutper
		end
		dataP[2] = dataP[2] + stack
		dataP[1] = dataP[1] + buyout
	end

	private.WriteItemData(serverKey, storeID, storeProperty)
end

function private.push_data()
	local realmdata = SSRealmData[serverKey]
	if not realmdata then return end
	local daily, means = realmdata.daily, realmdata.means
	local lookupmeansdata, lookupmeansindex = {}, {}

	for storeID, itemstring in pairs(daily) do
		-- find the means data for this storeID, and build lookup tables to help cross-index
		-- we leave the last (DATA_DIVIDER) level of the data as strings for now; later we will fully unpack only the ones we need
		local itemstoremeans
		if means[storeID] then
			itemstoremeans = {strsplit(ITEM_DIVIDER, means[storeID])}
		else
			itemstoremeans = {}
		end
		for index, propertystring in ipairs(itemstoremeans) do
			local prop, datastringmeans = strsplit(PROPERTY_DIVIDER, propertystring)
			lookupmeansdata[prop] = datastringmeans
			lookupmeansindex[prop] = index -- remember where we got datastringmeans from, so we can put the revised datastring back in the same place
		end

		local itemsdaily = {strsplit(ITEM_DIVIDER, itemstring)}
		for index, propertystring in ipairs(itemsdaily) do
			-- extract daily data entries for this itemID & property
			local prop, datastringdaily = strsplit(PROPERTY_DIVIDER, propertystring)
			local dailybuy, dailyseen, dailymbo, dailyauctions = strsplit(DATA_DIVIDER, datastringdaily)
			dailybuy, dailyseen, dailymbo, dailyauctions = tonumber(dailybuy), tonumber(dailyseen), tonumber(dailymbo), tonumber(dailyauctions)
			local dailyavg = dailybuy
			-- dailyseen may be 0 for certain unusual items which do not modify property "0"
			-- our database format requires that there must always be a property "0" (which must always be at index 1)
			-- if no items of that base type with property "0" were seen today, the entry will be empty (all 0)
			if dailyseen > 0 then
				dailyavg = dailyavg / dailyseen
			end

			-- look for existing means data for this property
			local datastringmeans = lookupmeansdata[prop]
			if datastringmeans then
				if dailyseen > 0 then
					datameans = {strsplit(DATA_DIVIDER, datastringmeans)} -- seendays, seencount, EMA3, EMA7, EMA14, avgminbuy [, seenauctions]
					for k, v in ipairs(datameans) do
						datameans[k] = tonumber(v)
					end

					-- update means data for this entry
					local seendays = datameans[1]
					local newseendays = seendays + 1
					datameans[1] = newseendays
					datameans[2] = datameans[2] + dailyseen
					local seenauctions = datameans[7]
					if seenauctions then
						datameans[7] = seenauctions + (dailyauctions or dailyseen)
					else
						datameans[7] = dailyauctions -- may be nil
					end

					if seendays < 3 then
						-- for first 3 days perform plain average insead of EMAs
						datameans[3] = numberformat((datameans[3] * seendays + dailyavg) / newseendays) -- EMA3
						datameans[6] = numberformat((datameans[6] * seendays + dailymbo) / newseendays) -- average minimum buyout
						if newseendays == 3 then
							-- this is the third day, prep other EMAs for next time
							datameans[4] = datameans[3]
							datameans[5] = datameans[3]
						end
					else
						-- do normal EMA calculations
						datameans[3] = numberformat((datameans[3] * 2 + dailyavg) / 3) -- EMA3
						datameans[4] = numberformat((datameans[4] * 6 + dailyavg) / 7) -- EMA7
						datameans[5] = numberformat((datameans[5] * 13 + dailyavg) / 14) -- EMA14

						local avgmbo = datameans[6] -- average minimum buyout
						if avgmbo < 1 then
							datameans[6] = dailymbo
						else
							if dailymbo >= 1 then
								if avgmbo < dailymbo then
									if (avgmbo*10/dailymbo) < 9 then
										datameans[6] = numberformat((avgmbo+dailymbo)/2)
									else
										datameans[6] = numberformat((avgmbo*7+dailymbo)/8)
									end
								else
									if (dailymbo*10/avgmbo) < 9 then
										datameans[6] = numberformat((avgmbo+dailymbo)/2)
									else
										datameans[6] = numberformat((avgmbo*7+dailymbo)/8)
									end
								end
							end
						end
					end
					itemstoremeans[lookupmeansindex[prop]] = prop..PROPERTY_DIVIDER..tconcat(datameans, DATA_DIVIDER)
				end
			else
				-- this property has not been seen before, create a new entry for it
				-- we don't need to use an intermediate table, we can build the datastring directly
				-- there is no need to update lookupmeansdata[prop] or lookupmeansindex[prop], as each prop should only occur once for each storeID
				if dailyauctions then
					tinsert(itemstoremeans, newstringtemplate7:format(prop, dailyseen, dailyavg, dailymbo, dailyauctions)) -- represents data table with 7 entries
				else
					tinsert(itemstoremeans, newstringtemplate6:format(prop, dailyseen, dailyavg, dailymbo)) -- represents data table with 6 entries (missing seenauctions)
				end
			end
		end

		means[storeID] = tconcat(itemstoremeans, ITEM_DIVIDER)
		wipe(lookupmeansdata)
		wipe(lookupmeansindex)
	end

	realmdata.dailypush = time() + PUSHTIME
	wipe(daily)
end
