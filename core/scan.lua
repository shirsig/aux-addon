module 'aux.core.scan'

include 'aux'

local T = require 'T'

local info = require 'aux.util.info'
local history = require 'aux.core.history'

local PAGE_SIZE = 50

do
	local scan_states = {}

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
		local aborted = T.acquire()
		for type, state in pairs(scan_states) do
			if not scan_id or state.id == scan_id then
				kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in pairs(aborted) do
			do (state.params.on_abort or nop)() end
		end
	end

	function M.stop()
		get_state().stopped = true
	end

	function complete()
		local on_complete = get_state().params.on_complete
		scan_states[get_state().params.type] = nil
		do (on_complete or nop)() end
	end

	function get_state()
		for _, state in pairs(scan_states) do
			if state.id == thread_id() then
				return state
			end
		end
	end
end

function get_query()
	return get_state().params.queries[get_state().query_index]
end

function total_pages(total_auctions)
    return ceil(total_auctions / PAGE_SIZE)
end

function last_page(total_auctions)
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = get_query().blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function scan()
	get_state().query_index = get_state().query_index and get_state().query_index + 1 or 1
	if get_query() and not get_state().stopped then
		do (get_state().params.on_start_query or nop)(get_state().query_index) end
		if get_query().blizzard_query then
			if (get_query().blizzard_query.first_page or 0) <= (get_query().blizzard_query.last_page or huge) then
				get_state().page = get_query().blizzard_query.first_page or 0
				return submit_query()
			end
		else
			get_state().page = nil
			return scan_page()
		end
	end
	return complete()
end

do
	local function submit()
		if get_state().params.type == 'bidder' then
			GetBidderAuctionItems(get_state().page)
		elseif get_state().params.type == 'owner' then
			GetOwnerAuctionItems(get_state().page)
		else
			get_state().last_list_query = GetTime()
			local blizzard_query = get_query().blizzard_query or T.acquire()
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
				blizzard_query.slot,
				blizzard_query.class,
				blizzard_query.subclass,
				get_state().page,
				blizzard_query.usable,
				blizzard_query.quality
			)
		end
		return wait_for_results()
	end
	function submit_query()
		if get_state().stopped then return end
		if get_state().params.type ~= 'list' then
			return submit()
		else
			return when(CanSendAuctionQuery, submit)
		end
	end
end

function scan_page(i)
	i = i or 1

	if i > PAGE_SIZE then
		do (get_state().params.on_page_scanned or nop)() end
		if get_query().blizzard_query and get_state().page < last_page(get_state().total_auctions) then
			get_state().page = get_state().page + 1
			return submit_query()
		else
			return scan()
		end
	end

	local auction_info = info.auction(i, get_state().params.type)
	if auction_info and (auction_info.owner or get_state().params.ignore_owner or aux_ignore_owner) then
		auction_info.index = i
		auction_info.page = get_state().page
		auction_info.blizzard_query = get_query().blizzard_query
		auction_info.query_type = get_state().params.type

		history.process_auction(auction_info)

		if (get_state().params.auto_buy_validator or nop)(auction_info) then
			local send_signal, signal_received = signal()
			when(signal_received, scan_page, i)
			return place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, send_signal)
		elseif not get_query().validator or get_query().validator(auction_info) then
			do (get_state().params.on_auction or nop)(auction_info) end
		end
	end

	return scan_page(i + 1)
end

function wait_for_results()
    if get_state().params.type == 'bidder' then
        return when(function() return bids_loaded() end, accept_results)
    elseif get_state().params.type == 'owner' then
        return wait_for_owner_results()
    elseif get_state().params.type == 'list' then
        return wait_for_list_results()
    end
end

function accept_results()
	_,  get_state().total_auctions = GetNumAuctionItems(get_state().params.type)
	do
		(get_state().params.on_page_loaded or nop)(
			get_state().page - (get_query().blizzard_query.first_page or 0) + 1,
			last_page(get_state().total_auctions) - (get_query().blizzard_query.first_page or 0) + 1,
			total_pages(get_state().total_auctions) - 1
		)
	end
	return scan_page()
end

function wait_for_owner_results()
    if get_state().page == current_owner_page() then
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
    local timeout = later(5, get_state().last_list_query)
    local ignore_owner = get_state().params.ignore_owner or aux_ignore_owner
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