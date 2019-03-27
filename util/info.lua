module 'aux.util.info'

local T = require 'T'
local aux = require 'aux'

CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')
AuxTooltip:SetScript('OnTooltipAddMoney', function()
	this.money = arg1
end)

do
	local inventory_index_map = {
		INVTYPE_AMMO = {0},
		INVTYPE_HEAD = {1},
		INVTYPE_NECK = {2},
		INVTYPE_SHOULDER = {3},
		INVTYPE_BODY = {4},
		INVTYPE_CHEST = {5},
		INVTYPE_ROBE = {5},
		INVTYPE_WAIST = {6},
		INVTYPE_LEGS = {7},
		INVTYPE_FEET = {8},
		INVTYPE_WRIST = {9},
		INVTYPE_HAND = {10},
		INVTYPE_FINGER = {11, 12},
		INVTYPE_TRINKET = {13, 14},
		INVTYPE_CLOAK = {15},
		INVTYPE_2HWEAPON = {16, 17},
		INVTYPE_WEAPONMAINHAND = {16, 17},
		INVTYPE_WEAPON = {16, 17},
		INVTYPE_WEAPONOFFHAND = {16, 17},
		INVTYPE_HOLDABLE = {16, 17},
		INVTYPE_SHIELD = {16, 17},
		INVTYPE_RANGED = {18},
		INVTYPE_RANGEDRIGHT = {18},
		INVTYPE_TABARD = {19},
	}
	function M.inventory_index(slot)
	    return unpack(inventory_index_map[slot] or T.temp-T.acquire())
	end
end

function M.container_item(bag, slot)
	local link = GetContainerItemLink(bag, slot)
    if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = T.temp-item(item_id, suffix_id, unique_id, enchant_id)

        local texture, count, locked, quality, readable, lootable = GetContainerItemInfo(bag, slot) -- quality not working?
        local tooltip, tooltip_money = tooltip('bag', bag, slot)
        local max_charges = max_item_charges(item_id)
        local charges = max_charges and item_charges(tooltip)
        local aux_quantity = charges or count
        return T.map(
            'item_id', item_id,
            'suffix_id', suffix_id,
            'unique_id', unique_id,
            'enchant_id', enchant_id,

            'link', link,
            'itemstring', item_info.itemstring,
            'item_key', item_id .. ':' .. suffix_id,

            'name', item_info.name,
            'texture', texture,
            'level', item_info.level,
            'type', item_info.type,
            'subtype', item_info.subtype,
            'slot', item_info.slot,
            'quality', item_info.quality,
            'max_stack', item_info.max_stack,

            'count', count,
            'locked', locked,
            'readable', readable,
            'lootable', lootable,

            'tooltip', tooltip,
    	    'tooltip_money', tooltip_money,
            'max_charges', max_charges,
            'charges', charges,
            'aux_quantity', aux_quantity
        )
    end
end

function M.auction_sell_item()
	for name, texture, count, quality, usable, vendor_price in GetAuctionSellItemInfo do
        return T.map(
			'name', name,
			'texture', texture,
            'quality', quality,
			'count', count,
			'usable', usable,
            'vendor_price', vendor_price -- it seems for charge items this is always the price for full charges
		)
	end
end

function M.auction(index, query_type)
    query_type = query_type or 'list'

    local link = GetAuctionItemLink(query_type, index)
	if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = T.temp-item(item_id, suffix_id, unique_id, enchant_id)

        local name, texture, count, quality, usable, level, start_price, min_increment, buyout_price, high_bid, high_bidder, owner, sale_status = GetAuctionItemInfo(query_type, index)

    	local duration = GetAuctionItemTimeLeft(query_type, index)
        local tooltip, tooltip_money = tooltip('auction', query_type, index)
        local max_charges = max_item_charges(item_id)
        local charges = max_charges and item_charges(tooltip)
        local aux_quantity = charges or count
        local blizzard_bid = high_bid > 0 and high_bid or start_price
        local bid_price = high_bid > 0 and (high_bid + min_increment) or start_price

        return T.map(
            'item_id', item_id,
            'suffix_id', suffix_id,
            'unique_id', unique_id,
            'enchant_id', enchant_id,

            'link', link,
            'itemstring', item_info.itemstring,
            'item_key', item_id .. ':' .. suffix_id,
            'search_signature', aux.join(T.temp-T.list(item_id, suffix_id, enchant_id, start_price, buyout_price, bid_price, aux_quantity, duration, query_type == 'owner' and high_bidder or (high_bidder and 1 or 0), aux.account_data.ignore_owner and (is_player(owner) and 0 or 1) or (owner or '?')), ':'),
            'sniping_signature', aux.join(T.temp-T.list(item_id, suffix_id, enchant_id, start_price, buyout_price, aux_quantity, aux.account_data.ignore_owner and (is_player(owner) and 0 or 1) or (owner or '?')), ':'),

            'name', name,
            'texture', texture,
            'level', item_info.level,
            'type', item_info.type,
            'subtype', item_info.subtype,
            'slot', item_info.slot,
            'quality', quality,
            'max_stack', item_info.max_stack,

            'count', count,
            'start_price', start_price,
            'high_bid', high_bid,
            'min_increment', min_increment,
            'blizzard_bid', blizzard_bid,
            'bid_price', bid_price,
            'buyout_price', buyout_price,
            'unit_blizzard_bid', blizzard_bid / aux_quantity,
            'unit_bid_price', bid_price / aux_quantity,
            'unit_buyout_price', buyout_price / aux_quantity,
            'high_bidder', high_bidder,
            'owner', owner,
            'sale_status', sale_status,
            'duration', duration,
            'usable', usable,

            'tooltip', tooltip,
    	    'tooltip_money', tooltip_money,
            'max_charges', max_charges,
            'charges', charges,
            'aux_quantity', aux_quantity
        )
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
    auction_record.search_signature = aux.join(T.temp-T.list(auction_record.item_id, auction_record.suffix_id, auction_record.enchant_id, auction_record.start_price, auction_record.buyout_price, auction_record.bid_price, auction_record.aux_quantity, auction_record.duration, 1, aux.account_data.ignore_owner and (is_player(auction_record.owner) and 0 or 1) or (auction_record.owner or '?')), ':')
end

function M.set_tooltip(itemstring, owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)
end

function M.set_shopping_tooltip(slot)
    local index1, index2 = inventory_index(slot)
    local tooltips = T.temp-T.acquire()
    if index1 then
        local tooltip = tooltip('inventory', 'player', index1)
        if getn(tooltip) > 0 then
            tinsert(tooltips, tooltip)
        end
    end
    if index2 then
        local tooltip = tooltip('inventory', 'player', index2)
        if getn(tooltip) > 0 then
            tinsert(tooltips, tooltip)
        end
    end

    if tooltips[1] then
        tinsert(tooltips[1], 1, T.temp-T.map('left_text', 'Currently Equipped', 'left_color', T.temp-T.list(.5, .5, .5)))
        ShoppingTooltip1:SetOwner(GameTooltip, 'ANCHOR_NONE')
        ShoppingTooltip1:SetPoint('TOPLEFT', GameTooltip, 'TOPRIGHT', 0, -10)
        load_tooltip(ShoppingTooltip1, tooltips[1])
    end

    if tooltips[2] then
        tinsert(tooltips[2], 1, T.temp-T.map('left_text', 'Currently Equipped', 'left_color', T.temp-T.list(.5, .5, .5)))
        ShoppingTooltip2:SetOwner(ShoppingTooltip1, 'ANCHOR_NONE')
        ShoppingTooltip2:SetPoint('TOPLEFT', ShoppingTooltip1, 'TOPRIGHT')
        load_tooltip(ShoppingTooltip2, tooltips[2])
    end
end

function M.tooltip_match(entry, tooltip)
    return aux.any(tooltip, function(line)
        local left_match = line.left_text and strupper(line.left_text) == strupper(entry)
        local right_match = line.right_text and strupper(line.right_text) == strupper(entry)
        return left_match or right_match
    end)
end

function M.tooltip_find(pattern, tooltip)
    local count = 0
    for _, line in tooltip do
        if line.left_text and strfind(line.left_text, pattern) then
            count = count + 1
        end
        if line.right_text and strfind(line.right_text, pattern) then
            count = count + 1
        end
    end
    return count
end

function M.load_tooltip(frame, tooltip)
    frame:ClearLines()
    for _, line in ipairs(tooltip) do
        if line.right_text then
            frame:AddDoubleLine(line.left_text, line.right_text, line.left_color[1], line.left_color[2], line.left_color[3], line.right_color[1], line.right_color[2], line.right_color[3])
        else
            frame:AddLine(line.left_text, line.left_color[1], line.left_color[2], line.left_color[3], true)
        end
    end
    for i = 1, getn(tooltip) do -- TODO why is this needed?
	    _G[frame:GetName() .. 'TextLeft' .. i]:SetJustifyH('LEFT')
	    _G[frame:GetName() .. 'TextRight' .. i]:SetJustifyH('LEFT')
    end
    frame:Show()
end

function M.display_name(item_id, no_brackets, no_color)
	local item_info = item(item_id)
    if item_info then
        local name = item_info.name
        if not no_brackets then
            name = '[' .. name .. ']'
        end
        if not no_color then
            name = aux.select(4, GetItemQualityColor(item_info.quality)) .. name .. FONT_COLOR_CODE_CLOSE
        end
        return name
    end
end

function M.auctionable(tooltip, quality, strict)
    local status = tooltip[2] and tooltip[2].left_text
    local durability, max_durability = durability(tooltip)
    return (not quality or quality < 6)
            and status ~= ITEM_BIND_ON_PICKUP
            and status ~= ITEM_BIND_QUEST
            and status ~= ITEM_SOULBOUND
            and (not tooltip_match(ITEM_CONJURED, tooltip) or tooltip_find(ITEM_MIN_LEVEL, tooltip) > 1)
            and not (strict and durability and durability < max_durability)
end

function M.tooltip(setter, arg1, arg2)
    AuxTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    AuxTooltip.money = 0
    if setter == 'auction' then
	    AuxTooltip:SetAuctionItem(arg1, arg2)
    elseif setter == 'bag' then
	    AuxTooltip:SetBagItem(arg1, arg2)
    elseif setter == 'inventory' then
	    AuxTooltip:SetInventoryItem(arg1, arg2)
    elseif setter == 'link' then
	    AuxTooltip:SetHyperlink(arg1)
    end
    local tooltip = T.acquire()
    for i = 1, AuxTooltip:NumLines() do
        tinsert(tooltip, T.map(
            'left_text', _G['AuxTooltipTextLeft' .. i]:GetText(),
            'left_color', T.list(_G['AuxTooltipTextLeft' .. i]:GetTextColor()),
            'right_text', _G['AuxTooltipTextRight' .. i]:IsVisible() and _G['AuxTooltipTextRight' .. i]:GetText(),
            'right_color', T.list(_G['AuxTooltipTextRight' .. i]:GetTextColor())
        ))
    end
    return tooltip, AuxTooltip.money
end

do
	local pattern = '^' .. gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)') .. '$'
	function item_charges(tooltip)
		for _, line in tooltip do
	        local _, _, left_charges_string = strfind(line.left_text or '', pattern)
	        local _, _, right_charges_string = strfind(line.right_text or '', pattern)

	        local charges = tonumber(left_charges_string) or tonumber(right_charges_string)
			if charges then
				return max(1, charges) -- TODO kronos bug? should never be 0
			end
	    end
	    return 1
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

do
	local pattern = '^' .. gsub(gsub(DURABILITY_TEMPLATE, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)') .. '$'
	function M.durability(tooltip)
	    for _, line in tooltip do
	        local _, _, left_durability_string, left_max_durability_string = strfind(line.left_text or '', pattern)
	        local _, _, right_durability_string, right_max_durability_string = strfind(line.right_text or '', pattern)
	        local durability = tonumber(left_durability_string) or tonumber(right_durability_string)
	        local max_durability = tonumber(left_max_durability_string) or tonumber(right_max_durability_string)
	        if durability then
	            return durability, max_durability
	        end
	    end
	end
end

function M.item_key(link)
    local item_id, suffix_id = parse_link(link)
    return item_id .. ':' .. suffix_id
end

function M.parse_link(link)
    local _, _, item_id, enchant_id, suffix_id, unique_id, name = strfind(link, '|c%x%x%x%x%x%x%x%x|Hitem:(%d*):(%d*):(%d*):(%d*)[:0-9]*|h%[(.-)%]|h|r')
    return tonumber(item_id) or 0, tonumber(suffix_id) or 0, tonumber(unique_id) or 0, tonumber(enchant_id) or 0, name
end

function M.itemstring(item_id, suffix_id, unique_id, enchant_id)
    return 'item:' .. (item_id or 0) .. ':' .. (enchant_id or 0) .. ':' .. (suffix_id or 0) .. ':' .. (unique_id or 0)
end

function M.item(item_id, suffix_id)
    local itemstring = 'item:' .. (item_id or 0) .. ':0:' .. (suffix_id or 0) .. ':0'
    local name, itemstring, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
    return name and T.map(
        'name', name,
        'itemstring', itemstring,
        'quality', quality,
        'level', level,
        'class', class,
        'subclass', subclass,
        'slot', slot,
        'max_stack', max_stack,
        'texture', texture
    ) or item_info(item_id)
end

function M.item_class_index(item_class)
    for i, class in T.temp-T.list(GetAuctionItemClasses()) do
        if strupper(class) == strupper(item_class) then
            return i, class
        end
    end
end

function M.item_subclass_index(class_index, item_subclass)
    for i, subclass in T.temp-T.list(GetAuctionItemSubClasses(class_index)) do
        if strupper(subclass) == strupper(item_subclass) then
            return i, subclass
        end
    end
end

function M.item_slot_index(class_index, subclass_index, slot_name)
    for i, slot in T.temp-T.list(GetAuctionInvTypes(class_index, subclass_index)) do
        if strupper(_G[slot]) == strupper(slot_name) then
            return i, _G[slot]
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
		if not GetBagName(bag) or slot >= GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until GetBagName(bag) or bag > 4
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= 4 then return T.list(bag, slot), bag_type(bag) end
	end
end

function M.bag_type(bag)
	if bag == 0 then return 1 end
	local link = GetInventoryItemLink('player', ContainerIDToInventoryID(bag))
	if link then
		local item_id = parse_link(link)
		local item_info = item(item_id)
		return item_subclass_index(3, item_info.subclass)
	end
end