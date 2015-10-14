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
	local name, texture, stack_size, quality, usable, vendor_price, vendor_price_per_unit, max_stack, total_count = GetAuctionSellItemInfo()
	local base_deposit = CalculateAuctionDeposit(120) / stack_size
	
	if name then
		auction_sell_item = {
			name = name,
			texture = texture,
			stack_size = stack_size,
			quality = quality,
			usable = usable,
			vendor_price = vendor_price,
			vendor_price_per_unit = vendor_price_per_unit,
			max_stack = max_stack,
			total_count = total_count,
			base_deposit = base_deposit,
		}
		
		auction_sell_item.tooltip = Aux.info.tooltip(function(tt) tt:SetAuctionSellItem() end)
		auction_sell_item.charges = item_charges(auction_sell_item.tooltip)
		
		return auction_sell_item
	end
end

function Aux.info.auction_item(index)
	local hyperlink = GetAuctionItemLink("list", index)
	
	if not hyperlink then
		return
	end
	
	local auction_item = hyperlink_item(hyperlink)
	
	local name, texture, count, quality, usable, level, min_bid, min_increment, buyout_price, current_bid, high_bidder, owner, sale_status, id, has_all_info = GetAuctionItemInfo("list", index)
	local duration = GetAuctionItemTimeLeft("list", index)
	
	auction_item.texture = texture
	auction_item.count = count
	auction_item.min_bid = min_bid
	auction_item.min_increment = min_increment
	auction_item.buyout_price = buyout_price
	auction_item.current_bid = current_bid
	auction_item.high_bidder = high_bidder
	auction_item.owner = owner
	auction_item.sale_status = sale_status
	auction_item.id = id
	auction_item.has_all_info = has_all_info
	auction_item.duration = duration
	auction_item.usable = usable
	
	auction_item.tooltip = Aux.info.tooltip(function(tt) tt:SetAuctionItem("list", index) end)
	auction_item.charges = item_charges(auction_item.tooltip)
	
	return auction_item
end

function Aux.info.set_game_tooltip(owner, tooltip, anchor)
	GameTooltip:SetOwner(owner, anchor)
	for _, line in ipairs(tooltip) do
		GameTooltip:AddDoubleLine(line[1].text, line[2].text, line[1].r, line[1].b, line[1].g, line[2].r, line[2].b, line[2].g, true)
	end
	GameTooltip:Show()
end

function Aux.info.tooltip(setter)
	for i = 1, 30 do
		getglobal('AuxInfoTooltipTextLeft'..i):SetText()
		getglobal('AuxInfoTooltipTextRight'..i):SetText()
	end
	
	AuxInfoTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	setter(AuxInfoTooltip)
	AuxInfoTooltip:Show()
	
	local tooltip = {}
	for i = 1, 30 do
		local left, right = {}, {}
		
		left.text = getglobal('AuxInfoTooltipTextLeft'..i):GetText()
		left.r, left.b, left.g = getglobal('AuxInfoTooltipTextLeft'..i):GetTextColor()
		
		right.text = getglobal('AuxInfoTooltipTextRight'..i):GetText()
		right.r, right.b, right.g = getglobal('AuxInfoTooltipTextRight'..i):GetTextColor()
		
		tinsert(tooltip, {left, right})
	end
	
	for i = 1, 30 do
		getglobal('AuxInfoTooltipTextLeft'..i):SetText()
		getglobal('AuxInfoTooltipTextRight'..i):SetText()
	end
	
	return tooltip
end

function item_charges(tooltip)
	for _, line in ipairs(tooltip) do
		local _, _, left_charges_string = strfind(line[1].text or '', "^(%d+) Charges")
		local _, _, right_charges_string = strfind(line[2].text or '', "^(%d+) Charges$")
		local charges = tonumber(left_charges_string) or tonumber(right_charges_string)
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
	local name, itemstring, quality, level, type, subtype, max_stack = GetItemInfo(item_id(hyperlink))
	return {
		name = name,
		hyperlink = hyperlink,
		itemstring = itemstring,
		quality = quality,
		level = level,
		type = type,
		subtype = subtype,
		max_stack = max_stack,
	}
end