local m, public, private = Aux.module'scan'

local PAGE_SIZE = 50

private.threads = {}

function private.total_pages(total_auctions)
    return math.ceil(total_auctions / PAGE_SIZE)
end

function private.last_page(total_auctions)
    local last_page = max(m.total_pages(total_auctions) - 1, 0)
    local last_page_limit = Aux.util.safe_index(m.current_query().blizzard_query, 'last_page') or last_page
    return min(last_page_limit, last_page)
end

function private.current_query()
    return m.current_thread().params.queries[m.current_thread().query_index]
end

function private.current_thread()
    for _, thread in m.threads do
        if thread.id == Aux.control.thread_id then
            return thread
        end
    end
end

function public.start(params)
    if m.threads[params.type] then
        m.abort(m.threads[params.type].id)
    end

    local thread_id = Aux.control.new_thread(function()
        return m.wait_for_callback(m.current_thread().params.on_scan_start, m.scan)
    end)
    m.threads[params.type] = {
        id = thread_id,
        params = params,
    }
    return thread_id
end

function public.abort(scan_id)
    local aborted_threads = {}
    for t, thread in m.threads do
        if not scan_id or thread.id == scan_id then
            Aux.control.kill_thread(thread.id)
            m.threads[t] = nil
            tinsert(aborted_threads, thread)
        end
    end

    for _, thread in ipairs(aborted_threads) do
        if thread.params.on_abort then
            thread.params.on_abort()
        end
    end
end

function private.wait_for_results(k)
    if m.current_thread().params.type == 'bidder' then
        return Aux.control.wait_until(function() return Aux.bids_loaded end, k)
    elseif m.current_thread().params.type == 'owner' then
        return m.wait_for_owner_results(k)
    elseif m.current_thread().params.type == 'list' then
        return m.wait_for_list_results(k)
    end
end

function private.wait_for_owner_results(k)
    local updated
    if m.current_thread().page == Aux.current_owner_page then
        updated = true
    else
        Aux.control.on_next_event('AUCTION_OWNED_LIST_UPDATE', function()
            updated = true
        end)
    end

    Aux.control.wait_until(function() return updated end, k)
end

function private.wait_for_list_results(k)
    local updated, last_update
    local listener = Aux.control.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        last_update = GetTime()
        updated = true
    end)
    listener:start()
    Aux.control.wait_until(function()
        -- order important, owner_data_complete must be called after an update to request missing data
        local ok = updated and m.owner_data_complete() or last_update and GetTime() - last_update > 5
        updated = false
        return ok
    end, function()
        listener:stop()
        return k()
    end)
end

function private.owner_data_complete()
    if m.current_thread().params.ignore_owner or aux_ignore_owner then
        return true
    end
    local count = GetNumAuctionItems(m.current_thread().params.type)
    for i=1,count do
        local auction_info = Aux.info.auction(i, m.current_thread().params.type)
        if auction_info and not auction_info.owner then
            return false
        end
    end
    return true
end

function private.wait_for_callback(...)
	local ok = true

    local f = tremove(arg, 1)
    local k = tremove(arg)

	if f then
		tinsert(arg, {
			suspend = function() ok = false end,
			resume = function() ok = true end,
		})
		f(unpack(arg))
	end

	if ok then
		return k()
    else
        return Aux.control.wait_until(function() return ok end, k)
	end
end

function private.scan()
    m.current_thread().query_index = m.current_thread().query_index and m.current_thread().query_index + 1 or 1
    if m.current_query() then
        if m.current_query().blizzard_query then
            m.current_thread().page = m.current_query().blizzard_query.first_page or 0
        else
            m.current_thread().page = nil
        end
        m.wait_for_callback(m.current_thread().params.on_start_query, m.current_thread().query_index, m.process_query)
    else
        local on_complete = m.current_thread().params.on_complete
        m.threads[m.current_thread().params.type] = nil
        if on_complete then
            return on_complete()
        end
    end
end

function private.process_query()
    if m.current_query().blizzard_query then
        return m.submit_query(m.scan_page)
    else
        return m.scan_page()
    end
end

function private.scan_page()
    m.scan_auctions(function()

        m.wait_for_callback(m.current_thread().params.on_page_scanned, function()

            if m.current_query().blizzard_query and m.current_thread().page < m.last_page(m.current_thread().total_auctions) then
                m.current_thread().page = m.current_thread().page + 1
                return m.process_query()
            else
                return m.scan()
            end

        end)
    end)
end

function private.scan_auctions(k)
	return m.scan_auctions_helper(1, k)
end

function private.scan_auctions_helper(i, k)
    local recurse = function()
        if i >= (m.current_thread().page_auctions or GetNumAuctionItems(m.current_thread().params.type)) then
            return k()
        else
            return m.scan_auctions_helper(i + 1, k)
        end
    end

    local auction_info = Aux.info.auction(i, m.current_thread().params.type)
    if auction_info and (auction_info.owner or m.current_thread().params.ignore_owner or aux_ignore_owner) then
        auction_info.index = i
        auction_info.page = m.current_thread().page
        auction_info.blizzard_query = m.current_query().blizzard_query
        auction_info.query_type = m.current_thread().params.type

        Aux.history.process_auction(auction_info)

        if m.current_thread().params.auto_buy_validator and m.current_thread().params.auto_buy_validator(auction_info) then
            Aux.place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price)
        end
        if not m.current_query().validator or m.current_query().validator(auction_info) then
            return m.wait_for_callback(m.current_thread().params.on_auction, auction_info, recurse)
        end
    end

    return recurse()
end

function private.submit_query(k)
    Aux.control.wait_until(function() return m.current_thread().params.type ~= 'list' or CanSendAuctionQuery() end, function()

        if m.current_thread().params.on_submit_query then
            m.current_thread().params.on_submit_query()
        end
        if m.current_thread().params.type == 'bidder' then
            GetBidderAuctionItems(m.current_thread().page)
        elseif m.current_thread().params.type == 'owner' then
            GetOwnerAuctionItems(m.current_thread().page)
        else
            QueryAuctionItems(
                Aux.util.safe_index(m.current_query().blizzard_query, 'name'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'min_level'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'max_level'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'slot'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'class'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'subclass'),
                m.current_thread().page,
                Aux.util.safe_index(m.current_query().blizzard_query, 'usable'),
                Aux.util.safe_index(m.current_query().blizzard_query, 'quality')
            )
        end
        m.wait_for_results(function()
            m.current_thread().page_auctions,  m.current_thread().total_auctions = GetNumAuctionItems(m.current_thread().params.type)
            m.wait_for_callback(
                m.current_thread().params.on_page_loaded,
                m.current_thread().page - (m.current_query().blizzard_query.first_page or 0) + 1,
                m.last_page(m.current_thread().total_auctions) - (m.current_query().blizzard_query.first_page or 0) + 1,
                m.total_pages(m.current_thread().total_auctions) - 1,
                k
            )
        end)
    end)
end
