aux.module 'scan'

private.PAGE_SIZE = 50

do
	local scan_states = {}

	function public.start(params)
		for _, old_state in {scan_states[params.type]} do
			m.abort(old_state.id)
		end
		local thread_id = aux.control.thread(aux.C(m.wait_for_callback, params.on_scan_start, m.scan))
		scan_states[params.type] = {
			id = thread_id,
			params = params,
		}
		return thread_id
	end

	function public.abort(scan_id)
		local aborted = {}
		for type, state in scan_states do
			if not scan_id or state.id == scan_id then
				aux.control.kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in aborted do
			aux.call(state.params.on_abort)
		end
	end

	function private.complete()
		local on_complete = m.state.params.on_complete
		scan_states[m.state.params.type] = nil
		aux.call(on_complete)
	end

	private.state = aux.dynamic_table(scan_states, function(self)
		local _, state = next(aux.util.filter(self.private, function(state) return state.id == aux.control.thread_id end))
		return state
	end)
end

private.query = aux.dynamic_table(nil, function()
    return m.state.params.queries[m.state.query_index]
end)

function private.wait_for_callback(...)
	local send_signal, signal_received = aux.util.signal()
	local suspended
	local ret

	local f = tremove(arg, 1)
	local k = tremove(arg)

	if f then
		tinsert(arg, {
			suspend = function() suspended = true end,
			resume = send_signal,
		})
		f(unpack(arg))
	end
	if not suspended then
		send_signal()
	end

	return aux.control.when(signal_received, function() return k(unpack(signal_received())) end)
end

function private.total_pages(total_auctions)
    return ceil(total_auctions / m.PAGE_SIZE)
end

function private.last_page(total_auctions)
    local last_page = max(m.total_pages(total_auctions) - 1, 0)
    local last_page_limit = m.query.blizzard_query and m.query.blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function private.scan()
	m.state.query_index = m.state.query_index and m.state.query_index + 1 or 1
	if m.query() and (aux.index(m.query.blizzard_query, 'first_page') or 0) <= (aux.index(m.query.blizzard_query, 'last_page') or aux.huge) then
		if m.query.blizzard_query then
			m.state.page = m.query.blizzard_query.first_page or 0
		else
			m.state.page = nil
		end
		return m.wait_for_callback(m.state.params.on_start_query, m.state.query_index, m.process_query)
	else
		m.complete()
	end
end

function private.process_query()
	if m.query.blizzard_query then
		return m.submit_query()
	else
		return m.scan_page()
	end
end

function private.submit_query()
	aux.control.when(function() return m.state.params.type ~= 'list' or CanSendAuctionQuery() end, function()
		aux.call(m.state.params.on_submit_query)
		m.state.last_query_time = GetTime()
		if m.state.params.type == 'bidder' then
			GetBidderAuctionItems(m.state.page)
		elseif m.state.params.type == 'owner' then
			GetOwnerAuctionItems(m.state.page)
		else
			local blizzard_query = m.query.blizzard_query or {}
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
		if i >= m.PAGE_SIZE then
			m.wait_for_callback(m.state.params.on_page_scanned, function()
				if m.query.blizzard_query and m.state.page < m.last_page(m.state.total_auctions) then
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

	local auction_info = aux.info.auction(i, m.state.params.type)
	if auction_info and (auction_info.owner or m.state.params.ignore_owner or _G.aux_ignore_owner) then
		auction_info.index = i
		auction_info.page = m.state.page
		auction_info.blizzard_query = m.query.blizzard_query
		auction_info.query_type = m.state.params.type

		aux.history.process_auction(auction_info)

		if aux.call(m.state.params.auto_buy_validator, auction_info) then
			local send_signal, signal_received = aux.util.signal()
			aux.control.when(signal_received, recurse)
			aux.place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, aux.C(send_signal, true))
			return aux.control.thread(aux.control.when, aux.util.later(GetTime(), 10), aux.C(send_signal, false))
		elseif not m.query.validator or m.query.validator(auction_info) then
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

function private.wait_for_results()
	local timeout = aux.util.later(m.state.last_query_time, 10)
	local send_signal, signal_received = aux.util.signal()
	aux.control.when(signal_received, function()
        if timeout() then
            return m.submit_query()
        else
            _,  m.state.total_auctions = GetNumAuctionItems(m.state.params.type)
            return m.wait_for_callback(
                m.state.params.on_page_loaded,
                m.state.page - (m.query.blizzard_query.first_page or 0) + 1,
                m.last_page(m.state.total_auctions) - (m.query.blizzard_query.first_page or 0) + 1,
                m.total_pages(m.state.total_auctions) - 1,
                m.scan_page
            )
        end
    end)

    aux.control.thread(aux.control.when, timeout, send_signal)

    if m.state.params.type == 'bidder' then
        return aux.control.thread(aux.control.when, function() return aux.bids_loaded end, send_signal)
    elseif m.state.params.type == 'owner' then
        return m.wait_for_owner_results(send_signal)
    elseif m.state.params.type == 'list' then
        return m.wait_for_list_results(send_signal, signal_received)
    end
end

function private.wait_for_owner_results(send_signal)
    if m.state.page == aux.current_owner_page then
        return send_signal()
    else
        return aux.control.on_next_event('AUCTION_OWNED_LIST_UPDATE', send_signal)
    end
end

function private.wait_for_list_results(send_signal, signal_received)
    local updated, last_update
    aux.control.event_listener('AUCTION_ITEM_LIST_UPDATE', function(kill)
	    kill(signal_received())
        last_update = GetTime()
        updated = true
    end)
    local ignore_owner = m.state.params.ignore_owner or _G.aux_ignore_owner
    return aux.control.thread(aux.control.when, function()
        -- short circuiting order important, owner_data_complete must be called iif an update has happened.
        local ok = updated and (ignore_owner or m.owner_data_complete('list')) or last_update and GetTime() - last_update > 5
        updated = false
        return ok
    end, send_signal)
end

function private.owner_data_complete(type)
    for i=1,m.PAGE_SIZE do
        local auction_info = aux.info.auction(i, type)
        if auction_info and not auction_info.owner then
            return false
        end
    end
    return true
end
