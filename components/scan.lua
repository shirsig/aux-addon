local m, public, private = Aux.module'scan'

local PAGE_SIZE = 50

private.threads = {}
private.last_query_time = {}

private.th = Aux.dynamic_table(function()
    return Aux.util.filter(m.threads, function(thread) return thread.id == Aux.control.thread_id end)[1]
end)

private.q = Aux.dynamic_table(function()
    return m.th.params.queries[m.th.query_index]
end)

function private.total_pages(total_auctions)
    return math.ceil(total_auctions / PAGE_SIZE)
end

function private.last_page(total_auctions)
    local last_page = max(m.total_pages(total_auctions) - 1, 0)
    local last_page_limit = Aux.index(m.q.blizzard_query).last_page/last_page
    return min(last_page_limit, last_page)
end

function public.start(params)
    m.abort(Aux.index(m.threads[params.type]).id/0)

    local thread_id = Aux.control.new_thread(Aux.f(m.wait_for_callback, params.on_scan_start, m.scan))

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
        Aux.call(thread.params.on_abort)
    end
end

function private.timeout(type)
    return GetTime() - m.last_query_time[type] > 11
end

function private.wait_for_results()
    local c = Aux.control.await(function()
        if m.timeout(m.th.params.type) then
            return m.submit_query()
        else
            _,  m.th.total_auctions = GetNumAuctionItems(m.th.params.type)
            return m.wait_for_callback(
                m.th.params.on_page_loaded,
                m.th.page - (m.q.blizzard_query.first_page or 0) + 1,
                m.last_page(m.th.total_auctions) - (m.q.blizzard_query.first_page or 0) + 1,
                m.total_pages(m.th.total_auctions) - 1,
                m.scan_page
            )
        end
    end)
    Aux.control.as_soon_as(Aux.f(m.timeout, m.th.params.type), c)
    if m.th.params.type == 'bidder' then
        return Aux.control.as_soon_as(function() return Aux.bids_loaded end, c)
    elseif m.th.params.type == 'owner' then
        return m.wait_for_owner_results(c)
    elseif m.th.params.type == 'list' then
        return m.wait_for_list_results(c)
    end
end

function private.wait_for_owner_results(c)
    if m.th.page == Aux.current_owner_page then
        return c()
    else
        return Aux.control.on_next_event('AUCTION_OWNED_LIST_UPDATE', c)
    end
end

function private.wait_for_list_results(c)
    local updated, last_update
    Aux.control.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        if -c then
            return Aux.control.kill
        end
        last_update = GetTime()
        updated = true
    end)
    local type = m.th.params.type
    local ignore_owner = m.th.params.ignore_owner or aux_ignore_owner
    return Aux.control.as_soon_as(function()
        -- short circuiting order important, owner_data_complete must be called iif an update has happened.
        local ok = updated and (ignore_owner or m.owner_data_complete(type)) or last_update and GetTime() - last_update > 5
        updated = false
        return ok
    end, c)
end

function private.owner_data_complete(type)
    for i=1,PAGE_SIZE do
        local auction_info = Aux.info.auction(i, type)
        if auction_info and not auction_info.owner then
            return false
        end
    end
    return true
end

function private.wait_for_callback(...)
	local ok = true
    local ret

    local f = tremove(arg, 1)
    local k = tremove(arg)

	if f then
		tinsert(arg, {
			suspend = function() ok = false end,
			resume = function(...) ok = true ret = arg end,
		})
		f(unpack(arg))
	end

	if ok then
		return k()
    else
        return Aux.control.when(function() return ok end, function() return k(unpack(ret)) end)
	end
end

function private.scan()
    m.th.query_index = m.th.query_index and m.th.query_index + 1 or 1
    if m.q() then
        if m.q.blizzard_query then
            m.th.page = m.q.blizzard_query.first_page or 0
        else
            m.th.page = nil
        end
        return m.wait_for_callback(m.th.params.on_start_query, m.th.query_index, m.process_query)
    else
        local on_complete = m.th.params.on_complete
        m.threads[m.th.params.type] = nil
        if on_complete then
            return on_complete()
        end
    end
end

function private.process_query()
    if m.q.blizzard_query then
        return m.submit_query()
    else
        return m.scan_page()
    end
end

function private.scan_page()
	return m.scan_page_helper(1)
end

function private.scan_page_helper(i)
    local recurse = function(retry)
        if i >= PAGE_SIZE then
            m.wait_for_callback(m.th.params.on_page_scanned, function()
                if m.q.blizzard_query and m.th.page < m.last_page(m.th.total_auctions) then
                    m.th.page = m.th.page + 1
                    return m.process_query()
                else
                    return m.scan()
                end
            end)
        else
            return m.scan_page_helper(retry and i or i + 1)
        end
    end

    local auction_info = Aux.info.auction(i, m.th.params.type)
    if auction_info and (auction_info.owner or m.th.params.ignore_owner or aux_ignore_owner) then
        auction_info.index = i
        auction_info.page = m.th.page
        auction_info.blizzard_query = m.q.blizzard_query
        auction_info.query_type = m.th.params.type

        Aux.history.process_auction(auction_info)

        if Aux.call(m.th.params.auto_buy_validator, auction_info)/false then
            local c = Aux.control.await(recurse)
            Aux.place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, Aux.f(c, true))
            return Aux.control.new_thread(Aux.control.sleep, 10, Aux.f(c, false))
        elseif Aux.call(m.q.validator, auction_info)/true then
            return m.wait_for_callback(m.th.params.on_auction, auction_info, function(removed)
                if removed then
                    return recurse(true)
                else
                    return recurse()
                end
            end)
        end
    end

    return recurse()
end

function private.submit_query()
    Aux.control.when(function() return m.th.params.type ~= 'list' or CanSendAuctionQuery() end, function()
        Aux.call(m.th.params.on_submit_query)
        m.last_query_time[m.th.params.type] = GetTime()
        if m.th.params.type == 'bidder' then
            GetBidderAuctionItems(m.th.page)
        elseif m.th.params.type == 'owner' then
            GetOwnerAuctionItems(m.th.page)
        else
            local blizzard_query = Aux.option(m.q.blizzard_query)/{}
            QueryAuctionItems(
                blizzard_query.name,
                blizzard_query.min_level,
                blizzard_query.max_level,
                blizzard_query.slot,
                blizzard_query.class,
                blizzard_query.subclass,
                m.th.page,
                blizzard_query.usable,
                blizzard_query.quality
            )
        end
        return m.wait_for_results()
    end)
end
