local m = {}
Aux.scan_util = m

function m.default_filter(str)
    return {
        arity = 0,
        test = function()
            return function(auction_record)
                return Aux.util.any(auction_record.tooltip, function(entry)
                    return strfind(strupper(entry.left_text or ''), strupper(str or ''), 1, true) or strfind(strupper(entry.right_text or ''), strupper(str or ''), 1, true)
                end)
            end
        end,
    }
end

m.filters = {

    ['utilizable'] = {
        arity = 0,
        test = function()
            return function(auction_record)
                return auction_record.usable and not Aux.info.tooltip_match(ITEM_SPELL_KNOWN, auction_record.tooltip)
            end
        end,
    },

    ['tt'] = {
        arity = 1,
        test = function(str)
            if str then
                return m.default_filter(str).test()
            else
                return false, {}, 'Erroneous Tooltip Modifier'
            end
        end,
    },

    ['item'] = {
        arity = 1,
        test = function(name)
            if not name then
                return false, aux_auctionable_items, 'Erroneous Item Modifier'
            end

            return function(auction_record)
                return strlower(Aux.info.item(auction_record.item_id)) == name
            end
        end
    },

    ['left'] = {
        arity = 1,
        test = function(duration)
            if not duration then
                return false, {'30m', '2h', '8h', '24h'}, 'Erroneous Time Left Modifier'
            end

            local code = ({
                ['30m'] = 1,
                ['2h'] = 2,
                ['8h'] = 3,
                ['24h'] = 4,
            })[duration or '']

            if not code then
                return false, {}, 'Erroneous Time Left Modifier'
            end

            return function(auction_record)
                return auction_record.duration == code
            end
        end
    },

    ['rarity'] = {
        arity = 1,
        test = function(rarity)
            if not rarity then
                return false, {'poor', 'common', 'uncommon', 'rare', 'epic'}, 'Erroneous Time Left Modifier'
            end

            local code = ({
                ['poor'] = 1,
                ['common'] = 2,
                ['uncommon'] = 3,
                ['rare'] = 4,
                ['epic'] = 5,
            })[rarity or '']
            if not code then
                return false, {}, 'Erroneous Time Left Modifier'
            end

            return function(auction_record)
                return auction_record.quality == code
            end
        end
    },

    ['min-lvl'] = {
        arity = 1,
        test = function(level)
            level = tonumber(level or '')
            if level then
                return function(auction_record)
                    return auction_record.level >= level
                end
            else
                return false, {}, 'Erroneous Min Level Modifier'
            end
        end
    },

    ['max-lvl'] = {
        arity = 1,
        test = function(level)
            level = tonumber(level or '')
            if level then
                return function(auction_record)
                    return auction_record.level <= level
                end
            else
                return false, {}, 'Erroneous Max Level Modifier'
            end
        end
    },

    ['min-bid'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return auction_record.unit_bid_price >= amount
                end
            else
                return false, {}, 'Erroneous Min Bid Modifier'
            end
        end
    },

    ['min-buyout'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return auction_record.unit_buyout_price >= amount
                end
            else
                return false, {}, 'Erroneous Min Buyout Modifier'
            end
        end
    },

    ['max-bid'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return auction_record.unit_bid_price <= amount
                end
            else
                return false, {}, 'Erroneous Max Bid Modifier'
            end
        end
    },

    ['max-buyout'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return auction_record.buyout_price > 0 and auction_record.unit_buyout_price <= amount
                end
            else
                return false, {}, 'Erroneous Max Buyout Modifier'
            end
        end
    },

    ['bid-pct'] = {
        arity = 1,
        test = function(pct)
            pct = tonumber(pct)
            if pct then
                return function(auction_record)
                    return auction_record.unit_buyout_price > 0
                            and Aux.history.value(auction_record.item_key)
                            and auction_record.unit_buyout_price / Aux.history.value(auction_record.item_key) * 100 <= pct
                end
            else
                return false, {}, 'Erroneous Bid Percentage Modifier'
            end
        end
    },

    ['buyout-pct'] = {
        arity = 1,
        test = function(pct)
            pct = tonumber(pct)
            if pct then
                return function(auction_record)
                    return auction_record.unit_buyout_price > 0
                            and Aux.history.value(auction_record.item_key)
                            and auction_record.unit_buyout_price / Aux.history.value(auction_record.item_key) * 100 <= pct
                end
            else
                return false, {}, 'Erroneous Buyout Percentage Modifier'
            end
        end
    },

    ['bid-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return Aux.history.value(auction_record.item_key) and Aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.bid_price >= amount
                end
            else
                return false, {}, 'Erroneous Bid Profit Modifier'
            end
        end
    },

    ['buyout-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    return auction_record.buyout_price > 0 and Aux.history.value(auction_record.item_key) and Aux.history.value(auction_record.item_key) * auction_record.aux_quantity - auction_record.buyout_price >= amount
                end
            else
                return false, {}, 'Erroneous Buyout Profit Modifier'
            end
        end
    },

    ['bid-disenchant-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    local disenchant_value = Aux.disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                    return disenchant_value and disenchant_value - auction_record.bid_price >= amount
                end
            else
                return false, {}, 'Erroneous Bid Disenchant Profit Modifier'
            end
        end
    },

    ['buyout-disenchant-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    local disenchant_value = Aux.disenchant.value(auction_record.slot, auction_record.quality, auction_record.level)
                    return auction_record.buyout_price > 0 and disenchant_value and disenchant_value - auction_record.buyout_price >= amount
                end
            else
                return false, {}, 'Erroneous Buyout Disenchant Profit Modifier'
            end
        end
    },

    ['bid-vendor-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    local vendor_price = Aux.merchant.info(auction_record.item_id)
                    return vendor_price and vendor_price * auction_record.aux_quantity - auction_record.bid_price >= amount
                end
            else
                return false, {}, 'Erroneous Bid Vendor Profit Modifier'
            end
        end
    },

    ['buyout-vendor-profit'] = {
        arity = 1,
        test = function(amount)
            amount = Aux.money.from_string(amount or '') or 0
            if amount > 0 then
                return function(auction_record)
                    local vendor_price = Aux.merchant.info(auction_record.item_id)
                    return auction_record.buyout_price > 0 and vendor_price and vendor_price * auction_record.aux_quantity - auction_record.buyout_price >= amount
                end
            else
                return false, {}, 'Erroneous Buyout Vendor Profit Modifier'
            end
        end
    },

    ['discard'] = {
        arity = 0,
        test = function()
            return false
        end
    },
}

function m.find(auction_record, status_bar, on_abort, on_failure, on_success)

    local function test(index)
        local auction_info = Aux.info.auction(index, auction_record.query_type)
        return auction_info and auction_info.search_signature == auction_record.search_signature
    end

    Aux.scan.abort(auction_record.query_type)

    status_bar:update_status(0, 0)
    status_bar:set_text('Searching auction...')

    local pages = auction_record.page > 0 and { auction_record.page, auction_record.page - 1 } or { auction_record.page }

    local query = {
        validator = function(auction_info) return test(auction_info.index) end,
        blizzard_query = auction_record.query.blizzard_query,
        next_page = function()
            if getn(pages) == 1 then
                status_bar:update_status(50, 50)
            end
            local page = pages[1]
            tremove(pages, 1)
            return page
        end,
    }

    local found
    Aux.scan.start{
        type = auction_record.query_type,
        queries = { query },
        on_read_auction = function(auction_info, ctrl)
            if test(auction_info.index) then
                found = true
                ctrl.suspend()
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction found')
                return on_success(auction_info.index)
            end
        end,
        on_abort = function()
            if not found then
                status_bar:update_status(100, 100)
                status_bar:set_text('Auction not found')
                return on_abort()
            end
        end,
        on_complete = function()
            status_bar:update_status(100, 100)
            status_bar:set_text('Auction not found')
            return on_failure()
        end,
    }
end

function m.filter_builder()
    local filter = ''
    return {
        append = function(self, modifier)
            modifier = modifier
            filter = filter == '' and modifier or filter..'/'..modifier
        end,
        prepend = function(self, modifier)
            modifier = modifier
            filter = filter == '' and modifier or modifier..'/'..filter
        end,
        get = function(self)
            return filter
        end
    }
end

function m.create_item_query(item_id)

    local item_info = Aux.info.item(item_id)

    if item_info then
        local filter = m.filter_from_string(item_info.name..'/exact')
        return {
            start_page = 0,
            validator = filter.validator,
            blizzard_query = filter.blizzard_query,
        }
    end
end

function m.parse_filter_string(filter_string)
    local parts = Aux.util.split(filter_string, ';')

    local filters = {}
    for _, str in ipairs(parts) do
        str = Aux.util.trim(str)

        local filter, _, error = m.filter_from_string(str)

        if not filter then
            Aux.log('Invalid filter: '..error)
            return
        elseif filter.name and strlen(filter.name) > 63 then

        else
            tinsert(filters, filter)
        end
    end

    return filters
end

function m.filter_from_string(filter_term)
    local parts = Aux.util.map(Aux.util.split(filter_term, '/'), function(part) return strlower(Aux.util.trim(part)) end)

    local blizzard_filter = {}
    local post_filter = {}
    local prettified = m.filter_builder()
    local polish_notation_counter = 0
    local i = 1

    local function non_blizzard_modifier(str)
        local filter = m.filters[str]
        if filter then
            prettified:append('|cffffff00'..str..'|r')
        else
            filter = filter or m.default_filter(str)
            prettified:append('|cffff9218'..str..'|r')
        end

        local args = {}
        for j=1, filter.arity do
            local arg = parts[i - 1 + j]
            if arg then
                tinsert(args, arg)
                prettified:append('|cffff9218'..arg..'|r')
            end
        end
        i = i + filter.arity

        local test, suggestions, error = filter.test(unpack(args))
        if test then
            tinsert(post_filter, test)
        else
            return error, i > getn(parts) and suggestions or {}
        end
    end

    while i <= getn(parts) do
        local str = parts[i]
        i = i + 1

        if polish_notation_counter > 0 or str == 'and' or str == 'or' or str == 'not' then
            polish_notation_counter = polish_notation_counter == 0 and polish_notation_counter + 1 or polish_notation_counter
            if str == 'and' or str == 'or' then
                polish_notation_counter = polish_notation_counter + 1
                tinsert(post_filter, str)
                prettified:append('|cffffff00'..str..'|r')
            elseif str == 'not' then
                tinsert(post_filter, str)
                prettified:append('|cffffff00'..str..'|r')
            elseif str ~= '' then
                polish_notation_counter = polish_notation_counter - 1
                local error, suggestions = non_blizzard_modifier(str)
                if error then
                    return false, suggestions, error
                end
            end
        elseif tonumber(str) then
            if not blizzard_filter.min_level then
                blizzard_filter.min_level = tonumber(str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            elseif not blizzard_filter.max_level and tonumber(str) >= blizzard_filter.min_level then
                blizzard_filter.max_level = tonumber(str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Level Range Modifier'
            end
        elseif Aux.item_class_index(str) and not (blizzard_filter.class and not blizzard_filter.subclass and str == strlower(({ GetAuctionItemClasses() })[10])) then
            if not blizzard_filter.class then
                blizzard_filter.class = Aux.item_class_index(str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Item Class Modifier'
            end
        elseif blizzard_filter.class and Aux.item_subclass_index(blizzard_filter.class, str) then
            if not blizzard_filter.subclass then
                blizzard_filter.subclass = Aux.item_subclass_index(blizzard_filter.class, str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Item Subclass Modifier'
            end
        elseif blizzard_filter.subclass and Aux.item_slot_index(blizzard_filter.class, blizzard_filter.subclass, str) then
            if not blizzard_filter.slot then
                blizzard_filter.slot = Aux.item_slot_index(blizzard_filter.class, blizzard_filter.subclass, str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Item Slot Modifier'
            end
        elseif Aux.item_quality_index(str) then
            if not blizzard_filter.quality then
                blizzard_filter.quality = Aux.item_quality_index(str)
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Rarity Modifier'
            end
        elseif str == 'usable' then
            if not blizzard_filter.usable then
                blizzard_filter.usable = true
                prettified:append(Aux.gui.inline_color({216, 225, 211, 1})..str..'|r')
            else
                return false, {}, 'Erroneous Usable Only Modifier'
            end
        elseif str == 'exact' then
            if not blizzard_filter.exact then
                blizzard_filter.exact = true
            else
                return false, {}, 'Erroneous Exact Only Modifier'
            end
        elseif i == 2 and not m.filters[str] then
            blizzard_filter.name = str
        elseif str ~= '' then
            local error, suggestions = non_blizzard_modifier(str)
            if error then
                return false, suggestions, error
            end
        else
            return false, {}, 'Empty Modifier'
        end
    end

    if polish_notation_counter ~= 0 then
        local suggestions = {}
        for filter, _ in pairs(m.filters) do
            tinsert(suggestions, strlower(filter))
            tinsert(suggestions, 'and')
            tinsert(suggestions, 'or')
            tinsert(suggestions, 'not')
        end
        return false, i > getn(parts) and suggestions, 'Malformed Expression'
    end

    if blizzard_filter.exact then
        if blizzard_filter.min_level
                or blizzard_filter.max_level
                or blizzard_filter.class
                or blizzard_filter.subclass
                or blizzard_filter.slot
                or blizzard_filter.quality
                or blizzard_filter.usable
                or not blizzard_filter.name
        then
            return false, {}, 'Erroneous Exact Only Modifier'
        else
            prettified:prepend(Aux.info.display_name(Aux.item_cache.item_id(blizzard_filter.name)) or Aux.gui.inline_color({216, 225, 211, 1})..'['..blizzard_filter.name..']|r')
        end
    elseif blizzard_filter.name then
        if blizzard_filter.name == '' then
            prettified:prepend('|cffff0000'..'No Filter'..'|r')
        else
            prettified:prepend(Aux.gui.inline_color({216, 225, 211, 1})..blizzard_filter.name..'|r')
        end
    end

    return {
        blizzard_query = m.blizzard_query(blizzard_filter),
        validator = m.validator(blizzard_filter, post_filter),
        prettified = prettified:get(),
    }, m.suggestions(blizzard_filter, getn(parts))
end

function m.suggestions(blizzard_filter, num_parts)

    local suggestions = {}

    if blizzard_filter.name
            and not blizzard_filter.min_level
            and not blizzard_filter.max_level
            and not blizzard_filter.class
            and not blizzard_filter.subclass
            and not blizzard_filter.slot
            and not blizzard_filter.quality
            and not blizzard_filter.usable
    then
        tinsert(suggestions, 'exact')
    end

    tinsert(suggestions, 'and')
    tinsert(suggestions, 'or')
    tinsert(suggestions, 'not')
    tinsert(suggestions, 'tt')

    for filter, _ in pairs(m.filters) do
        tinsert(suggestions, strlower(filter))
    end

    -- classes
    if not blizzard_filter.class then
        for _, class in ipairs({ GetAuctionItemClasses() }) do
            tinsert(suggestions, class)
        end
    end

    -- subclasses
    if blizzard_filter.class and not blizzard_filter.subclass then
        for _, subclass in ipairs({ GetAuctionItemSubClasses(blizzard_filter.class) }) do
            tinsert(suggestions, subclass)
        end
    end

    -- slots
    if blizzard_filter.class and blizzard_filter.subclass and not blizzard_filter.slot then
        for _, invtype in ipairs({ GetAuctionInvTypes(blizzard_filter.class, blizzard_filter.subclass) }) do
            tinsert(suggestions, getglobal(invtype))
        end
    end

    -- usable
    if not blizzard_filter.usable then
        tinsert(suggestions, 'usable')
    end

    -- rarities
    if not blizzard_filter.quality then
        for i=0,4 do
            tinsert(suggestions, getglobal('ITEM_QUALITY'..i..'_DESC'))
        end
    end

    -- item names
    if num_parts == 1 and blizzard_filter.name == '' then
        for _, name in aux_auctionable_items do
            tinsert(suggestions, name..'/exact')
        end
    end

    return suggestions
end

function m.blizzard_query(filter)

    local item_info, class_index, subclass_index, slot_index
    if filter.exact then
        local item_id = Aux.item_cache.item_id(filter.name)
        item_info = Aux.info.item(item_id)
        class_index = item_info and Aux.item_class_index(item_info.class)
        subclass_index = class_index and item_info.subclass and Aux.item_subclass_index(class_index, item_info.subclass)
        slot_index = subclass_index and item_info.slot and Aux.item_slot_index(class_index, subclass_index, item_info.slot)
    end

    return {
        name = filter.name,
        min_level = item_info and item_info.level or filter.min_level,
        max_level = item_info and item_info.level or filter.max_level,
        class = item_info and class_index or filter.class,
        subclass = item_info and subclass_index or filter.subclass,
        slot = item_info and item_info.class and slot_index or filter.slot,
        usable = item_info and item_info.usable or filter.usable and 1 or 0,
        quality = item_info and item_info.quality or filter.quality,
    }
end

function m.validator(blizzard_filter, post_filter)

    return function(record)
        if blizzard_filter.exact and strlower(Aux.info.item(record.item_id).name) ~= blizzard_filter.name then
            return
        end
        if blizzard_filter.min_level and record.level < blizzard_filter.min_level then
            return
        end
        if blizzard_filter.max_level and record.level > blizzard_filter.max_level then
            return
        end
        if getn(post_filter) > 0 then
            local stack = {}
            for i=getn(post_filter),1,-1 do
                local op = post_filter[i]
                if op == 'and' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a and b)
                elseif op == 'or' then
                    local a, b = tremove(stack), tremove(stack)
                    tinsert(stack, a or b)
                elseif op == 'not' then
                    tinsert(stack, not tremove(stack))
                else
                    tinsert(stack, op(record) and true or false)
                end
            end
            return Aux.util.all(stack, Aux.util.id)
        end
        return true
    end
end