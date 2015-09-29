Aux.info = {}

local hyperlink_item, item_id, item_charges

function Aux.info.container_item(bag, slot)
	local hyperlink = GetContainerItemLink(bag, slot)
	
	if not hyperlink then
		return
	end
	
	local container_item = hyperlink_item(hyperlink)
	
	local texture, count, locked, quality, readable, lootable, hyperlink = GetContainerItemInfo(bag, slot)
	container_item.texture = texture
	container_item.count = count
	container_item.locked = locked
	container_item.readable = readable
	container_item.lootable = lootable
	container_item.hyperlink = hyperlink
	
	container_item.tooltip = Aux.info.tooltip(function(tt) tt:SetBagItem(bag, slot) end)
	container_item.charges = item_charges(container_item.tooltip)
	
	return container_item
end

function Aux.info.auction_sell_item()
	local name, texture, count, quality, usable, price, unit_price, max_stack, total_count = GetAuctionSellItemInfo()
	auction_sell_item = {
		name = name,
		texture = texture,
		count = count,
		quality = quality,
		usable = usable,
		price = price,
		unit_price = unit_price,
		max_stack = max_stack,
		total_count = total_count,
	}
	
	auction_sell_item.tooltip = Aux.info.tooltip(function(tt) tt:SetAuctionSellItem() end)
	auction_sell_item.charges = item_charges(auction_sell_item.tooltip)
	
	return auction_sell_item
end

function Aux.info.auction_item(index)
	local hyperlink = GetAuctionItemLink("list", index)
	
	if not hyperlink then
		return
	end
	
	local auction_item = hyperlink_item(hyperlink)
	
	local name, texture, count, quality, usable, level, min_bid, min_increment, buyout_price, bid_amount, high_bidder, owner, sale_status, id, has_all_info = GetAuctionItemInfo("list", index)
	local duration = GetAuctionItemTimeLeft("list", index)
	
	auction_item.texture = texture
	auction_item.count = count
	auction_item.min_bid = min_bid
	auction_item.min_increment = min_increment
	auction_item.buyout_price = buyout_price
	auction_item.bid_amount = bid_amount
	auction_item.high_bidder = high_bidder
	auction_item.owner = owner
	auction_item.sale_status = sale_status
	auction_item.id = id
	auction_item.has_all_info = has_all_info
	auction_item.duration = duration
	
	auction_item.tooltip = Aux.info.tooltip(function(tt) tt:SetAuctionItem("list", index) end)
	auction_item.charges = item_charges(auction_item.tooltip)
	
	return auction_item
end

function Aux.info.tooltip(setter)
	for j = 1, 30 do
		leftEntry = getglobal('AuxInfoTooltipTextLeft'..j):SetText()
		rightEntry = getglobal('AuxInfoTooltipTextRight'..j):SetText()
	end
	
	AuxInfoTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	setter(AuxInfoTooltip)
	AuxInfoTooltip:Show()
	
	local tooltip = {}
	for j = 1, 30 do
		local leftEntry = getglobal('AuxInfoTooltipTextLeft'..j):GetText()
		if leftEntry then
			tinsert(tooltip, leftEntry)
		end
		local rightEntry = getglobal('AuxInfoTooltipTextRight'..j):GetText()
		if rightEntry then
			tinsert(tooltip, rightEntry)
		end
	end
	
	for j = 1, 30 do
		leftEntry = getglobal('AuxInfoTooltipTextLeft'..j):SetText()
		rightEntry = getglobal('AuxInfoTooltipTextRight'..j):SetText()
	end
	
	return tooltip
end

function item_charges(tooltip)
	for _, entry in ipairs(tooltip) do
		local _, _, charges_string = strfind(entry, "(%d+) Charges")
		local charges = tonumber(charges_string)
		if charges then
			return charges
		end
	end
end	

function item_id(hyperlink)
	local _, _, id_string = strfind(hyperlink, "^.-:(%d*).*")
	return tonumber(id_string)	
end

function hyperlink_item(hyperlink)
	local name, link, quality, level, type, subtype, max_stack = GetItemInfo(item_id(hyperlink))
	return {
		name = name,
		hyperlink = link,
		quality = quality,
		level = level,
		type = type,
		subtype = subtype,
		max_stack = max_stack,
	}
end