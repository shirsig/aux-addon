module 'aux.core.scan'

include 'T'
include 'aux'

local info = require 'aux.util.info'
local history = require 'aux.core.history'

local PAGE_SIZE = 50

do
	local scan_states = T

	function M.start(params)
		local old_state = scan_states[params.type]
		if old_state then
			abort(old_state.id)
		end
		do (params.on_scan_start or nop)() end
		local thread_id = thread(scan)
		scan_states[params.type] = {
			id = thread_id,
			params = params,
		}
		return thread_id
	end

	function M.abort(scan_id)
		local aborted = T
		for type, state in scan_states do
			if not scan_id or state.id == scan_id then
				kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in aborted do
			do (state.params.on_abort or nop)() end
		end
	end

	function M.stop()
		state.stopped = true
	end

	function complete()
		local on_complete = state.params.on_complete
		scan_states[state.params.type] = nil
		do (on_complete or nop)() end
	end

	function get_state()
		for _, state in scan_states do
			if state.id == thread_id then
				return state
			end
		end
	end
end

function get_query()
	return state.params.queries[state.query_index]
end

function total_pages(total_auctions)
    return ceil(total_auctions / PAGE_SIZE)
end

function last_page(total_auctions)
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = query.blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function scan()
	state.query_index = state.query_index and state.query_index + 1 or 1
	if query and not state.stopped then
		do (state.params.on_start_query or nop)(state.query_index) end
		if query.blizzard_query then
			if (query.blizzard_query.first_page or 0) <= (query.blizzard_query.last_page or huge) then
				state.page = query.blizzard_query.first_page or 0
				return submit_query()
			end
		else
			state.page = nil
			return scan_page()
		end
	end
	return complete()
end

do
	local function submit()
		if state.params.type == 'bidder' then
			GetBidderAuctionItems(state.page)
		elseif state.params.type == 'owner' then
			GetOwnerAuctionItems(state.page)
		else
			state.last_list_query = GetTime()
			local blizzard_query = query.blizzard_query or T
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
				blizzard_query.slot,
				blizzard_query.class,
				blizzard_query.subclass,
				state.page,
				blizzard_query.usable,
				blizzard_query.quality
			)
		end
		return wait_for_results()
	end
	function submit_query()
		if state.stopped then return end
		if state.params.type ~= 'list' then
			return submit()
		else
			return when(CanSendAuctionQuery, submit)
		end
	end
end

function scan_page(i)
	i = i or 1

	if i > PAGE_SIZE then
		do (state.params.on_page_scanned or nop)() end
		if query.blizzard_query and state.page < last_page(state.total_auctions) then
			state.page = state.page + 1
			return submit_query()
		else
			return scan()
		end
	end

	local auction_info = info.auction(i, state.params.type)
	if auction_info and (auction_info.owner or state.params.ignore_owner or aux_ignore_owner) then
		auction_info.index = i
		auction_info.page = state.page
		auction_info.blizzard_query = query.blizzard_query
		auction_info.query_type = state.params.type

		history.process_auction(auction_info)

		if (state.params.auto_buy_validator or nop)(auction_info) then
			local send_signal, signal_received = signal()
			when(signal_received, scan_page, i)
			return place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, send_signal)
		elseif not query.validator or query.validator(auction_info) then
			do (state.params.on_auction or nop)(auction_info) end
		end
	end

	return scan_page(i + 1)
end

function wait_for_results()
    if state.params.type == 'bidder' then
        return when(function() return bids_loaded end, accept_results)
    elseif state.params.type == 'owner' then
        return wait_for_owner_results()
    elseif state.params.type == 'list' then
        return wait_for_list_results()
    end
end

function accept_results()
	_,  state.total_auctions = GetNumAuctionItems(state.params.type)
	do
		(state.params.on_page_loaded or nop)(
			state.page - (query.blizzard_query.first_page or 0) + 1,
			last_page(state.total_auctions) - (query.blizzard_query.first_page or 0) + 1,
			total_pages(state.total_auctions) - 1
		)
	end
	return scan_page()
end

function wait_for_owner_results()
    if state.page == current_owner_page then
	    return accept_results()
    else
	    local updated
        on_next_event('AUCTION_OWNED_LIST_UPDATE', function() updated = true end)
	    return when(function() return updated end, accept_results)
    end
end

function wait_for_list_results()
    local updated, last_update
    local listener_id = event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        last_update = GetTime()
        updated = true
    end)
    local timeout = later(5, state.last_list_query)
    local ignore_owner = state.params.ignore_owner or aux_ignore_owner
	return when(function()
		if not last_update and timeout() then
			return true
		end
		if last_update and GetTime() - last_update > 5 then
			return true
		end
		-- short circuiting order important, owner_data_complete must be called iif an update has happened.
		if updated and (ignore_owner or owner_data_complete()) then
			return true
		end
		updated = false
	end, function()
		kill_listener(listener_id)
		if not last_update and timeout() then
			return submit_query()
		else
			return accept_results()
		end
	end)
end

function owner_data_complete()
    for i = 1, PAGE_SIZE do
        local auction_info = info.auction(i, 'list')
        if auction_info and not auction_info.owner then
	        return false
        end
    end
    return true
end