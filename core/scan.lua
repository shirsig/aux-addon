select(2, ...) 'aux.core.scan'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'

local PAGE_SIZE = 50
local TIMEOUT = 30

function aux.handle.CLOSE()
	abort()
end

do
	local scan_states = {}

	function M.start(params)
		local old_state = scan_states[params.type]
		if old_state then
			abort(old_state.id)
		end
		do (params.on_scan_start or pass)() end
		local thread_id = aux.thread(scan)
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
				aux.kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in pairs(aborted) do
			do (state.params.on_abort or pass)() end
		end
	end

	function M.stop()
		get_state().stopped = true
	end

	function complete()
		local on_complete = get_state().params.on_complete
		scan_states[get_state().params.type] = nil
		do (on_complete or pass)() end
	end

	function get_state()
		for _, state in pairs(scan_states) do
			if state.id == aux.thread_id() then
				return state
			end
		end
	end
end

function get_query()
    local queries
    if get_state().params.type == 'list' then
        queries = get_state().params.queries
    else
        queries =  {{blizzard_query={}}}
    end
	return queries[get_state().query_index]
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
		do (get_state().params.on_start_query or pass)(get_state().query_index) end
		if get_query().blizzard_query then
			if (get_query().blizzard_query.first_page or 0) <= (get_query().blizzard_query.last_page or math.huge) then
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
        SortAuctionClearSort(get_state().params.type)
        SortAuctionItems(get_state().params.type, 'duration')
        SortAuctionItems(get_state().params.type, 'duration')
		if get_state().params.type == 'bidder' and not AuctionFrame.gotBids then
            GetBidderAuctionItems()
            AuctionFrame.gotBids = 1
		elseif get_state().params.type == 'owner' and not AuctionFrame.gotAuctions then
			GetOwnerAuctionItems()
            AuctionFrame.gotAuctions = 1
        else
			get_state().last_list_query = GetTime()
			local blizzard_query = get_query().blizzard_query or T.acquire()
            local category_filter
            if blizzard_query.class and blizzard_query.subclass and blizzard_query.slot then
                category_filter = AuctionCategories[blizzard_query.class].subCategories[blizzard_query.subclass].subCategories[blizzard_query.slot].filters
            elseif blizzard_query.class and blizzard_query.subclass then
                category_filter = AuctionCategories[blizzard_query.class].subCategories[blizzard_query.subclass].filters
            elseif blizzard_query.class then
                category_filter = AuctionCategories[blizzard_query.class].filters
            else
                -- not filtering by category, leave nil for all
            end
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
                get_state().page,
                blizzard_query.usable,
                blizzard_query.quality,
                false, -- getAll
                blizzard_query.class ~= 1 and blizzard_query.class ~= 2 and blizzard_query.exact, -- Doesn't work for suffix items
                category_filter
			)
		end
		return wait_for_results()
	end
	function submit_query()
		if get_state().stopped then return end
		if get_state().params.type ~= 'list' then
			return submit()
		else
			return aux.when(CanSendAuctionQuery, submit)
		end
	end
end

function scan_page(i)
	i = i or 1

    local page_size = get_state().params.type == 'list' and PAGE_SIZE or get_state().total_auctions
	if i > page_size then
		do (get_state().params.on_page_scanned or pass)() end
		if get_query().blizzard_query and get_state().page < last_page(get_state().total_auctions) then
			get_state().page = get_state().page + 1
			return submit_query()
		else
			return scan()
		end
	end

	local auction_info = info.auction(i, get_state().params.type)
	if auction_info and (auction_info.owner or get_state().params.ignore_owner or aux.account_data.ignore_owner) then
		auction_info.index = i
		auction_info.page = get_state().page
		auction_info.blizzard_query = get_query().blizzard_query
		auction_info.query_type = get_state().params.type

		history.process_auction(auction_info)

		if not get_query().validator or get_query().validator(auction_info) then
			do (get_state().params.on_auction or pass)(auction_info) end
		end
	end

	return scan_page(i + 1)
end

function wait_for_results()
    if get_state().params.type == 'bidder' then
        return accept_results()
    elseif get_state().params.type == 'owner' then
        return accept_results()
    elseif get_state().params.type == 'list' then
        return wait_for_list_results()
    end
end

function accept_results()
	_,  get_state().total_auctions = GetNumAuctionItems(get_state().params.type)
	do
		(get_state().params.on_page_loaded or pass)(
			get_state().page - (get_query().blizzard_query.first_page or 0) + 1,
			last_page(get_state().total_auctions) - (get_query().blizzard_query.first_page or 0) + 1,
			total_pages(get_state().total_auctions) - 1
		)
	end
	return scan_page()
end

function wait_for_list_results()
    local updated, last_update
    local listener_id = aux.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        last_update = GetTime()
        updated = true
    end)
    local timeout = aux.later(TIMEOUT, get_state().last_list_query)
    -- TODO retail is this still worth it? also needed for other types?
    return aux.when(function()
		if not last_update and timeout() then
			return true
		end
		if last_update and GetTime() - last_update > TIMEOUT then
			return true
		end
		-- short circuiting order important, owner_data_complete must be called iif an update has happened.
		if updated and (ignore_owner or data_complete()) then
			return true
		end
		updated = false
	end, function()
		aux.kill_listener(listener_id)
		if not last_update and timeout() then
			return submit_query()
		else
			return accept_results()
		end
	end)
end

function data_complete()
    local ignore_owner = get_state().params.ignore_owner or aux.account_data.ignore_owner
    for i = 1, PAGE_SIZE do
        local _, _, _, _, _, _, _, _, _, _, _, _, _, owner, _, _, _, has_all_info = GetAuctionItemInfo('list', i)
        if has_all_info == false or has_all_info and not ignore_owner and not owner then
	        return false
        end
    end
    return true
end