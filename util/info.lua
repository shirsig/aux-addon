select(2, ...) 'aux.util.info'

local aux = require 'aux'

CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')

do
    local map = { [1] = 2, [2] = 8, [3] = 24 }
    function M.duration_hours(duration_code)
        return map[duration_code]
    end
end

function M.container_item(bag, slot)
	local link = GetContainerItemLink(bag, slot)
    if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = item(item_id, suffix_id, unique_id, enchant_id)
        if item_info then -- TODO apparently this can be undefined
            local texture, count, locked, quality, readable, lootable = GetContainerItemInfo(bag, slot) -- TODO quality not working?
            local durability, max_durability = GetContainerItemDurability(bag, slot)
            local tooltip = tooltip('bag', bag, slot)
            local auctionable = auctionable(tooltip) and durability == max_durability and not lootable
            local max_charges = max_item_charges(item_id)
            local charges = max_charges and item_charges(tooltip)
            if max_charges and not charges then -- TODO find better fix
                return
            end
            local aux_quantity = charges or count
            return {
                item_id = item_id,
                suffix_id = suffix_id,
                unique_id = unique_id,
                enchant_id = enchant_id,

                link = link,
                item_key = item_id .. ':' .. suffix_id,

                name = item_info.name,
                texture = texture,
                level = item_info.level,
                quality = item_info.quality,
                max_stack = item_info.max_stack,

                count = count,
                locked = locked,
                readable = readable,
                auctionable = auctionable,

                tooltip = tooltip,
                max_charges = max_charges,
                charges = charges,
                aux_quantity = aux_quantity,
            }
        end
    end
end

function M.auction_sell_item()
	for name, texture, count, quality, usable, vendor_price in GetAuctionSellItemInfo do
        return {
			name = name,
			texture = texture,
            quality = quality,
			count = count,
			usable = usable,
            vendor_price = vendor_price, -- it seems for charge items this is always the price for full charges
        }
	end
end

function M.auction(index, query_type)
    query_type = query_type or 'list'

    local name, texture, count, quality, usable, level, _, start_price, min_increment, buyout_price, high_bid, high_bidder, _, owner, _, sale_status, item_id, has_all_info = GetAuctionItemInfo(query_type, index)

--    local ignore_owner = get_state().params.ignore_owner or aux.account_data.ignore_owner TODO

    if has_all_info and (aux.account_data.ignore_owner or owner) then
        local link = GetAuctionItemLink(query_type, index)
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)

    	local duration = GetAuctionItemTimeLeft(query_type, index)
        local tooltip = tooltip('auction', query_type, index)
        local max_charges = max_item_charges(item_id)
        local charges = max_charges and item_charges(tooltip)
        if max_charges and not charges then -- TODO find better fix
            return
        end
        local aux_quantity = charges or count
        local blizzard_bid = high_bid > 0 and high_bid or start_price
        local bid_price = high_bid > 0 and (high_bid + min_increment) or start_price
        return {
            item_id = item_id,
            suffix_id = suffix_id,
            unique_id = unique_id,
            enchant_id = enchant_id,

            link = link,
            item_key = item_id .. ':' .. suffix_id,
            search_signature = aux.join({item_id, suffix_id, enchant_id, start_price, buyout_price, bid_price, aux_quantity, sale_status == 1 and 0 or duration, query_type == 'owner' and high_bidder or (high_bidder and 1 or 0), sale_status, aux.account_data.ignore_owner and (is_player(owner) and 0 or 1) or (owner or '?')}, ':'),
            sniping_signature = aux.join({item_id, suffix_id, enchant_id, start_price, buyout_price, aux_quantity, aux.account_data.ignore_owner and (is_player(owner) and 0 or 1) or (owner or '?')}, ':'),

            name = name,
            texture = texture,
            quality = quality,
            requirement = level,

            count = count,
            start_price = start_price,
            high_bid = high_bid,
            min_increment = min_increment,
            blizzard_bid = blizzard_bid,
            bid_price = bid_price,
            buyout_price = buyout_price,
            unit_blizzard_bid = blizzard_bid / aux_quantity,
            unit_bid_price = bid_price / aux_quantity,
            unit_buyout_price = buyout_price / aux_quantity,
            high_bidder = high_bidder,
            owner = owner,
            sale_status = sale_status,
            duration = duration,
            usable = usable,

            tooltip = tooltip,
            max_charges = max_charges,
            charges = charges,
            aux_quantity = aux_quantity,
        }
    end
end

function M.bid_update(auction_record)
    auction_record.high_bid = auction_record.bid_price
    auction_record.blizzard_bid = auction_record.bid_price
    auction_record.min_increment = max(1, floor(auction_record.bid_price / 100) * 5)
    auction_record.bid_price = auction_record.bid_price + auction_record.min_increment
    auction_record.unit_blizzard_bid = auction_record.blizzard_bid / auction_record.aux_quantity
    auction_record.unit_bid_price = auction_record.bid_price / auction_record.aux_quantity
    auction_record.high_bidder = 1
    auction_record.search_signature = aux.join({auction_record.item_id, auction_record.suffix_id, auction_record.enchant_id, auction_record.start_price, auction_record.buyout_price, auction_record.bid_price, auction_record.aux_quantity, auction_record.sale_status == 1 and 0 or auction_record.duration, 1, 0, aux.account_data.ignore_owner and (is_player(auction_record.owner) and 0 or 1) or (auction_record.owner or '?')}, ':')
end

function M.set_tooltip(itemstring, owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)
end

function M.tooltip_match(entry, tooltip)
    return aux.any(tooltip, function(text)
        return strupper(entry) == strupper(text)
    end)
end

function M.tooltip_find(pattern, tooltip)
    local count = 0
    for _, entry in pairs(tooltip) do
        if strfind(entry, pattern) then
            count = count + 1
        end
    end
    return count
end

function M.display_name(item_id, no_brackets, no_color)
	local item_info = item(item_id)
    if item_info then
        local name = item_info.name
        if not no_brackets then
            name = '[' .. name .. ']'
        end
        if not no_color then
            name = '|c' .. select(4, GetItemQualityColor(item_info.quality)) .. name .. FONT_COLOR_CODE_CLOSE
        end
        return name
    end
end

function M.auctionable(tooltip, quality)
    local status = tooltip[2]
    return (not quality or quality < 6)
            and status ~= ITEM_BIND_ON_PICKUP
            and status ~= ITEM_BIND_QUEST
            and status ~= ITEM_SOULBOUND
            and (not tooltip_match(ITEM_CONJURED, tooltip) or tooltip_find(ITEM_MIN_LEVEL, tooltip) > 1)
end

function M.tooltip(setter, arg1, arg2)
    AuxTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    if setter == 'auction' then
	    AuxTooltip:SetAuctionItem(arg1, arg2)
    elseif setter == 'bag' then
	    AuxTooltip:SetBagItem(arg1, arg2)
    elseif setter == 'inventory' then
	    AuxTooltip:SetInventoryItem(arg1, arg2)
    elseif setter == 'link' then
	    AuxTooltip:SetHyperlink(arg1)
    end
    local tooltip = {}
    for i = 1, AuxTooltip:NumLines() do
        for side in aux.iter('Left', 'Right') do
            local text = _G['AuxTooltipText' .. side .. i]:GetText()
            if text then
                tinsert(tooltip, text)
            end
        end
    end
    return tooltip
end

do
    local patterns = {}
    for i = 1, 10 do
        patterns[aux.pluralize(format(ITEM_SPELL_CHARGES, i))] = i
    end

	function item_charges(tooltip)
        for _, entry in pairs(tooltip) do
            if patterns[entry] then
                return patterns[entry]
            end
	    end
	end
end

do
	local data = {
		-- wizard oil
		[20744] = 5,
		[20746] = 5,
		[20750] = 5,
		[20749] = 5,

		-- mana oil
		[20745] = 5,
		[20747] = 5,
		[20748] = 5,

		-- discombobulator
		[4388] = 5,

		-- recombobulator
		[4381] = 10,
		[18637] = 10,

        -- deflector
        [4376] = 5,
        [4386] = 5,

		-- ... TODO
	}
	function M.max_item_charges(item_id)
	    return data[item_id]
	end
end

function M.item_key(link)
    local item_id, suffix_id = parse_link(link)
    return item_id .. ':' .. suffix_id
end

function M.parse_link(link)
    local _, _, item_id, enchant_id, suffix_id, unique_id, name = strfind(link, '|Hitem:(%d*):(%d*):::::(%d*):(%d*)[:0-9]*|h%[(.-)%]|h')
    return tonumber(item_id) or 0, tonumber(suffix_id) or 0, tonumber(unique_id) or 0, tonumber(enchant_id) or 0, name
end

function M.item(item_id, suffix_id)
    local itemstring = 'item:' .. (item_id or 0) .. '::::::' .. (suffix_id or 0)
    local name, link, quality, level, requirement, class, subclass, max_stack, slot, texture, sell_price = GetItemInfo(itemstring)
    return name and {
        name = name,
        link = link,
        quality = quality,
        level = level,
        requirement = requirement,
        class = class,
        subclass = subclass,
        slot = slot,
        max_stack = max_stack,
        texture = texture,
        sell_price = sell_price / (max_item_charges(item_id) or 1)
    } or item_info(item_id)
end

function M.category_index(category)
    if category == 'Weapon' then -- TODO retail apparently the names aren't always the same as from GetAuctionItemInfo?
        return 1
    end
    for i, v in ipairs(AuctionCategories) do
        if strupper(v.name) == strupper(category) then
            return i, v.name
        end
    end
end

function M.subcategory_index(category_index, subcategory)
    if category_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories or empty) do
            if strupper(v.name) == strupper(subcategory) then
                return i, v.name
            end
        end
    end
end

function M.subsubcategory_index(category_index, subcategory_index, subsubcategory)
    if category_index > 0 and subcategory_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories[subcategory_index].subCategories or empty) do
            if strupper(v.name) == strupper(subsubcategory) then
                return i, v.name
            end
        end
    end
end

function M.item_quality_index(item_quality)
    for i = 0, 4 do
        local quality = _G['ITEM_QUALITY' .. i .. '_DESC']
        if strupper(item_quality) == strupper(quality) then
            return i, quality
        end
    end
end

function M.inventory()
	local bag, slot = 0, 0
	return function()
		if slot >= GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until GetContainerNumSlots(bag) > 0 or bag > 4
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= 4 then return {bag, slot}, bag_type(bag) end
	end
end

function M.bag_type(bag)
	if bag == 0 then return 1 end
	local link = GetInventoryItemLink('player', ContainerIDToInventoryID(bag))
	if link then
		local item_id = parse_link(link)
		local item_info = item(item_id)
		return subcategory_index(3, item_info.subclass)
	end
end