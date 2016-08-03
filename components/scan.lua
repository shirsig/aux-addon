local m, public, private = Aux.module'scan'

local PAGE_SIZE = 50

private.threads = {}
private.last_query_time = {}

private.state = Aux.dynamic_table(function()
    return Aux.util.filter(m.threads, function(thread) return thread.id == Aux.control.thread_id end)[1]
end)

private.q = Aux.dynamic_table(function()
    return m.state.params.queries[m.state.query_index]
end)

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

function private.total_pages(total_auctions)
    return math.ceil(total_auctions / PAGE_SIZE)
end

function private.last_page(total_auctions)
    local last_page = max(m.total_pages(total_auctions) - 1, 0)
    local last_page_limit = m.q.blizzard_query and m.q.blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function public.start(params)
    if m.threads[params.type] then
        m.abort(m.threads[params.type].id)
    end

    local thread_id = Aux.control.thread(Aux.f(m.wait_for_callback, params.on_scan_start, m.scan))

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

    for _, thread in aborted_threads do
        Aux.safe_call(thread.params.on_abort)
    end
end

function private.complete()
	local on_complete = m.state.params.on_complete
	m.threads[m.state.params.type] = nil
	if on_complete then
		return on_complete()
	end
end

function private.scan()
	Aux.log(Aux.control.thread_id)
	m.state.query_index = m.state.query_index and m.state.query_index + 1 or 1
	if m.q() then
		if m.q.blizzard_query then
			m.state.page = m.q.blizzard_query.first_page or 0
		else
			m.state.page = nil
		end
		return m.wait_for_callback(m.state.params.on_start_query, m.state.query_index, m.process_query)
	else
		m.complete()
	end
end

function private.process_query()
	if m.q.blizzard_query then
		return m.submit_query()
	else
		return m.scan_page()
	end
end

function private.submit_query()
	Aux.control.when(function() return m.state.params.type ~= 'list' or CanSendAuctionQuery() end, function()
		Aux.safe_call(m.state.params.on_submit_query)
		m.last_query_time[m.state.params.type] = GetTime()
		if m.state.params.type == 'bidder' then
			GetBidderAuctionItems(m.state.page)
		elseif m.state.params.type == 'owner' then
			GetOwnerAuctionItems(m.state.page)
		else
			local blizzard_query = m.q.blizzard_query or {}
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
				blizzard_query.slot,
				blizzard_query.class,
				blizzard_query.subclass,
				m.state.page,
				blizzard_query.usable,
				blizzard_query.quality
			)
		end
		return m.wait_for_results()
	end)
end

function private.scan_page(i)
	i = i or 1
	local recurse = function(retry)
		if i >= PAGE_SIZE then
			m.wait_for_callback(m.state.params.on_page_scanned, function()
				if m.q.blizzard_query and m.state.page < m.last_page(m.state.total_auctions) then
					m.state.page = m.state.page + 1
					return m.process_query()
				else
					return m.scan()
				end
			end)
		else
			return m.scan_page(retry and i or i + 1)
		end
	end

	local auction_info = Aux.info.auction(i, m.state.params.type)
	if auction_info and (auction_info.owner or m.state.params.ignore_owner or aux_ignore_owner) then
		auction_info.index = i
		auction_info.page = m.state.page
		auction_info.blizzard_query = m.q.blizzard_query
		auction_info.query_type = m.state.params.type

		Aux.history.process_auction(auction_info)

		if Aux.safe_call(m.state.params.auto_buy_validator, auction_info) then
			local c = Aux.control.await(recurse)
			Aux.place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, Aux.f(c, true))
			return Aux.control.thread(Aux.control.sleep, 10, Aux.f(c, false))
		elseif not m.q.validator or m.q.validator(auction_info) then
			return m.wait_for_callback(m.state.params.on_auction, auction_info, function(removed)
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

function private.timeout(type)
    return GetTime() - m.last_query_time[type] > 11
end

function private.wait_for_results()
    local c = Aux.control.await(function()
        if m.timeout(m.state.params.type) then
            return m.submit_query()
        else
            _,  m.state.total_auctions = GetNumAuctionItems(m.state.params.type)
            return m.wait_for_callback(
                m.state.params.on_page_loaded,
                m.state.page - (m.q.blizzard_query.first_page or 0) + 1,
                m.last_page(m.state.total_auctions) - (m.q.blizzard_query.first_page or 0) + 1,
                m.total_pages(m.state.total_auctions) - 1,
                m.scan_page
            )
        end
    end)

    local type = m.state.params.type
    Aux.control.as_soon_as(function() return -c or m.timeout(type) end, c)

    if m.state.params.type == 'bidder' then
        return Aux.control.as_soon_as(function() return Aux.bids_loaded end, c)
    elseif m.state.params.type == 'owner' then
        return m.wait_for_owner_results(c)
    elseif m.state.params.type == 'list' then
        return m.wait_for_list_results(c)
    end
end

function private.wait_for_owner_results(c)
    if m.state.page == Aux.current_owner_page then
        return c()
    else
        return Aux.control.on_next_event('AUCTION_OWNED_LIST_UPDATE', c)
    end
end

function private.wait_for_list_results(c)
    local updated, last_update
    Aux.control.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
	    Aux.control.kill(-c)
        last_update = GetTime()
        updated = true
    end)
    local ignore_owner = m.state.params.ignore_owner or aux_ignore_owner
    return Aux.control.as_soon_as(function()
        -- short circuiting order important, owner_data_complete must be called iif an update has happened.
        local ok = updated and (ignore_owner or m.owner_data_complete('list')) or last_update and GetTime() - last_update > 5
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
