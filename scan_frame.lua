local MAX_HISTORY_SIZE = 100
local MIN_SEEN = 1
local UNDERCUT_FACTOR = 0.2

Aux.history = {}

local process_auction, balanced_list, update_snapshot
local get_market_price, get_usable_median, get_historical_median, get_median, get_percentile

local signature_cache

function Aux.history.on_close()

end

function Aux.history.on_open()

end

function Aux.history.start_scan()

    if not AuxHistoryScanButton:IsVisible() then
        return
    end

    AuxHistoryScanButton:Hide()
    AuxHistoryStopButton:Show()

    signature_cache = Aux.util.set()

    Aux.log('Scanning auctions ...')
    Aux.scan.start{
        query = {},
        page = 0,
        on_page_loaded = function(page, total_pages)
            Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(i)
            process_auction(i)
        end,
        on_complete = function()
            update_snapshot()

            AuxHistoryStopButton:Hide()
            AuxHistoryScanButton:Show()
        end,
        on_abort = function()
            update_snapshot()

            AuxHistoryStopButton:Hide()
            AuxHistoryScanButton:Show()
        end,
        next_page = function(page, total_pages)
            if AuxBuyAllPagesCheckButton:GetChecked() then
                local last_page = max(total_pages - 1, 0)
                if page < last_page then
                    return page + 1
                end
            end
        end,
    }
end

function update_snapshot()
    local snapshot = Aux.persistence.get_snapshot()
    snapshot.remove_all(signature_cache.values())
    Aux.persistence.save_snapshot(snapshot)
end

function Aux.history.stop_scan()
    Aux.scan.abort()
end

function process_auction(index)
    local auction_info = Aux.info.auction_item(index)
    local buyout_price = Aux.util.safe_index{auction_info, 'buyout_price'}
    if buyout_price and buyout_price > 0 then
        local aux_quantity = auction_info.charges or auction_info.count
        local price = ceil(buyout_price / aux_quantity)
        local item_key = auction_info.item_signature

        local signature = Aux.info.auction_signature(index)
        signature_cache.add(signature)

        local snapshot = Aux.persistence.get_snapshot()
        if not snapshot.contains(signature) then
            snapshot.add(signature)
            Aux.persistence.save_snapshot(snapshot)
--
--            local item_record = Aux.persistence.get_item_record(item_key)
--
--            item_record = item_record or {
--                count = 0,
--                accumulated_price = 0,
--                price_list = {},
--            }
--
--            local price_list = balanced_list(MAX_HISTORY_SIZE)
--            price_list.add_all(item_record.price_list)
--            price_list.add(price)
--
--            Aux.persistence.save_item_record(item_key, {
--                count = item_record.count + 1,
--                accumulated_price = item_record.accumulated_price + price,
--                price_list = price_list.values(),
--            })
--
        end
    end
end

function Aux.history.get_market_price(key)
    local price

    local median = get_usable_median(key)
--    local avgMin, avgBuy, avgBid, bidPct, buyPct, avgQty, meanCount = getMeans(key, realm)

    -- assign the best common buyout
    if median and median > 0 then
        price = median
--    elseif meanCount and meanCount > 0 then
--        -- if a usable median does not exist, use the average buyout instead
--        price = avgBuy;
    end

    return price
end

function get_usable_median(item_key)

    local historical_median, historical_count = get_historical_median(item_key)

    if historical_count >= MIN_SEEN then
        return historical_median, historical_count
    end
end

function get_historical_median(item_key)
    local price_list = Aux.util.safe_index{Aux.persistence.get_item_record(item_key), 'price_list'}

    return get_median(price_list or {})
end

function get_median(values)
    return get_percentile(values, 0.5)
end

-- Return weighted average percentile such that returned value
-- is larger than or equal to (100*pct)% of the table values
-- 0 <= pct <= 1
function get_percentile(values, pct)

    local _percentile = function(sorted_values, pct, first, last)
        local f = (last - first) * pct + first
        local i1, i2 = floor(f), ceil(f)
        f = f - i1

        return sorted_values[i1] * (1 - f) + sorted_values[i2] * f
    end

    local n = getn(values)

    if n == 0 then
        return 0, 0 -- if there is an empty table, returns median = 0, count = 0
    elseif n == 1 then
        return tonumber(values[1]), 1
    end

    -- The following calculations require a sorted table
    table.sort(values)

    -- Skip IQR calculations if table is too small to have outliers
    if n <= 4 then
        return _percentile(values, pct, 1, n), n
    end

    --  REWORK by Karavirs to use IQR*1.5 to ignore outliers
    -- q1 is median 1st quartile q2 is median of set q3 is median of 3rd quartile iqr is q3 - q1
    local q1 = _percentile(values, 0.25, 1, n)
    local q3 = _percentile(values, 0.75, 1, n)

    local iqr = (q3 - q1) * 1.5
    local iqlow, iqhigh = q1 - iqr, q3 + iqr

    -- Find first and last index to include in median calculation
    local first, last = 1, n

    -- Skip low outliers
    while values[first] < iqlow do
        first = first + 1
    end

    -- Skip high outliers
    while values[last] > iqhigh do
        last = last - 1
    end

    return _percentile(values, pct, first, last), last - first + 1
end

function balanced_list(max_size, cmp)
    local self = {}

    local values = {}

    cmp = cmp or Aux.util.compare

    function self.add(value)

        local left = 1
        local right = getn(values)
        local middle_value
        local middle

        local destination
        while left <= right do
            middle = floor((right - left) / 2) + left
            middle_value = values[middle]
            if cmp(value, middle_value) == Aux.util.LT then
                right = middle - 1
            elseif cmp(value, middle_value) == Aux.util.GT then
                left = middle + 1
            else
                destination = middle
                break
            end
        end
        destination = destination or left

        tinsert(values, destination, value)

        if max_size and getn(values) > max_size then
            if destination <= floor(max_size / 2) + 1 then
                tremove(values)
            else
                tremove(values, 1)
            end
        end
    end

    function self.add_all(array)
        self.clear()
        for _, value in ipairs(array) do
            self.add(value)
        end
    end

    function self.clear()
        values = {}
    end

    function self.values()
        local result = {}
        for _, value in ipairs(values) do
            tinsert(result, value)
        end
        return result
    end

    function self.size()
        return getn(values)
    end

    function self.get(index)
        return values[index]
    end

    function self.max_size()
        return max_size
    end

    return self
end

function Aux.history.get_price_suggestion(key, quantity)
    local market_price = Aux.history.get_market_price(key)
    return market_price and market_price * quantity * UNDERCUT_FACTOR or 0
end