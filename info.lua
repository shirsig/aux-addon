Aux.info = {}

local link_item, id, tooltip, charges

function Aux.info.container_item(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	local container_item = link_item(link)
	
	local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagID, slot)
	container_item.texture = texture
	container_item.count = count
	
	container_item.tooltip = tooltip(GameTooltip.SetBagItem(bag, slot))
	container_item.charges = charges(container_item.tooltip)
	
	return container_item
end

function Aux.info.auction_sell_item()
	local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount = GetAuctionSellItemInfo()
	auction_sell_item = {
		name = name,
		texture = texture,
		count = count,
		quality = quality,
		can_use = canUse,
		price = price,
		unit_price = pricePerUnit,
		max_stack = stackCount,
		total_count = totalCount,
	}
	
	auction_sell_item.tooltip = tooltip(GameTooltip.SetAuctionSellItem)
	auction_sell_item.charges = charges(auction_sell_item.tooltip)
	
	return auction_sell_item
end

function Aux.info.auction_item(index)
	local link = GetAuctionItemLink("list", index)
	local auction_item = item(link)
	
	local _, texture, count, _, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index)
	auction_item.texture = texture
	auction_item.count = count
	auction_item.min_bid = minBid
	auction_item.bid_amount = bidAmount
	auction_item.buyout = buyoutPrice
	
	auction_item.tooltip = tooltip(GameTooltip.SetAuctionItem("list", index)
	auction_item.charges = charges(auction_item.tooltip)
	
	return auction_item
end

function charges(tooltip)
	for _, entry in ipairs(tooltip) do
		local chargesString = gsub(entry, "(%d+) Charges", "%1")
		return tonumber(chargesString)
		if charges then
			return charges
		end
	end
end	

function tooltip(setter)
	for j=1, 30 do
		leftEntry = getglobal('AuxScanTooltipTextLeft'..j):SetText()
		rightEntry = getglobal('AuxScanTooltipTextRight'..j):SetText()
	end
	AuxScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	AuxScanTooltip:setter()
	AuxScanTooltip:Show()
	local tooltip = Aux_Scan_ExtractTooltip()
	
	local tooltip = {}
	for j=1, 30 do
		local leftEntry = getglobal('AuxScanTooltipTextLeft'..j):GetText()
		if leftEntry then
			tinsert(tooltip, leftEntry)
		end
		local rightEntry = getglobal('AuxScanTooltipTextRight'..j):GetText()
		if rightEntry then
			tinsert(tooltip, rightEntry)
		end
	end
	
	for j=1, 30 do
		leftEntry = getglobal('AuxScanTooltipTextLeft'..j):SetText()
		rightEntry = getglobal('AuxScanTooltipTextRight'..j):SetText()
	end
	return tooltip
end

function id(itemlink)
	local id_string = string.gsub(itemLink, "^.-:(%d*).*", "%1")
	return tonumber(id_string)	
end

function link_item(link)
	local name, link, quality, level, type, subtype, max_stack = GetItemInfo(id(link))
	return {
		name = name,
		link = link,
		quality = quality,
		level = level,
		type = type,
		subtype = subtype,
		max_stack = max_stack,
	}
end