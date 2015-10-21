local TOOLTIP_LENGTH = 30

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
	local name, texture, stack_size, quality, usable, vendor_price = GetAuctionSellItemInfo()

	if name then

        local deposit_factor = CalculateAuctionDeposit(120) / vendor_price
        local vendor_price_per_unit = vendor_price / stack_size

		auction_sell_item = {
			name = name,
			texture = texture,
			stack_size = stack_size,
			quality = quality,
			usable = usable,
            vendor_price_per_unit = vendor_price_per_unit,
			vendor_price = vendor_price,
			deposit_factor = deposit_factor,
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
	
	local name, texture, count, quality, usable, level, min_bid, min_increment, buyout_price, current_bid, high_bidder, owner, sale_status, id = GetAuctionItemInfo("list", index)
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
	auction_item.duration = duration
	auction_item.usable = usable
	auction_item.tooltip = Aux.info.tooltip(function(tt) tt:SetAuctionItem("list", index) end)
	auction_item.charges = item_charges(auction_item.tooltip)
	
	auction_item.EnhTooltip_info = {
		name = auction_item.name,
		hyperlink = auction_item.hyperlink,
		quality = auction_item.quality,
		count = auction_item.count,
	}
	
	return auction_item
end

function Aux.info.set_game_tooltip(owner, tooltip, anchor, EnhTooltip_info)
	GameTooltip:SetOwner(owner, anchor)
	for _, line in ipairs(tooltip) do
		GameTooltip:AddDoubleLine(line[1].text, line[2].text, line[1].r, line[1].b, line[1].g, line[2].r, line[2].b, line[2].g, true)
	end
	GameTooltip:Show()
	
	if EnhTooltip and EnhTooltip_info then
		EnhTooltip.TooltipCall(GameTooltip, EnhTooltip_info.name, EnhTooltip_info.hyperlink, EnhTooltip_info.quality, EnhTooltip_info.count)
	end
end

function Aux.info.tooltip_match(patterns, tooltip)
    return Aux.util.all(patterns, function(pattern)
        return Aux.util.any(tooltip, function(line)
            local left_match = line[1].text and strfind(strupper(line[1].text), strupper(pattern), 1, true)
            local right_match = line[2].text and strfind(strupper(line[2].text), strupper(pattern), 1, true)
            return left_match or right_match
        end)
    end)
end

function Aux.info.tooltip(setter)
	for i = 1, TOOLTIP_LENGTH do
		getglobal('AuxInfoTooltipTextLeft'..i):SetText()
		getglobal('AuxInfoTooltipTextRight'..i):SetText()
	end
	
	AuxInfoTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	setter(AuxInfoTooltip)
	AuxInfoTooltip:Show()
	
	local tooltip = {}
	for i = 1, TOOLTIP_LENGTH do
		local left, right = {}, {}
		
		left.text = getglobal('AuxInfoTooltipTextLeft'..i):GetText()
		left.r, left.b, left.g = getglobal('AuxInfoTooltipTextLeft'..i):GetTextColor()
		
		right.text = getglobal('AuxInfoTooltipTextRight'..i):GetText()
		right.r, right.b, right.g = getglobal('AuxInfoTooltipTextRight'..i):GetTextColor()
		
		tinsert(tooltip, {left or '', right or ''})
	end
	
	for i = 1, TOOLTIP_LENGTH do
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
