select(2, ...) 'aux.core.scan'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'

local DEFAULT_PAGE_SIZE = 50
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
        local thread_id = aux.coro_thread(scan)
        scan_states[params.type] = {
			id = thread_id,
			params = params,
        }
        return thread_id
	end

	function M.abort(scan_id)
		local aborted = {}
		for type, state in pairs(scan_states) do
			if not scan_id or state.id == scan_id then
				aux.coro_kill(state.id)
                aux.kill_listener(state.listener_id)
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
			if state.id == aux.coro_id() then
				return state
			end
		end
	end
end

function get_query()
    local queries
    if get_state().params.type == 'list' and not get_state().params.get_all then
        queries = get_state().params.queries
    else
        queries =  { { blizzard_query = {} } }
    end
	return queries[get_state().query_index]
end

function total_pages(total_auctions)
    return page_size() == 0 and 0 or ceil(total_auctions / page_size())
end

function last_page(total_auctions)
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = get_query().blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function page_size()
    if get_state().params.type == 'list' and not get_state().params.get_all then
        return DEFAULT_PAGE_SIZE
    else
        return GetNumAuctionItems(get_state().params.type)
    end
end

function scan()
    aux.coro_wait() -- TODO remove this
    get_state().query_index = 1
	while get_query() and not get_state().stopped do
		do (get_state().params.on_start_query or pass)(get_state().query_index) end
		if get_query().blizzard_query then
            get_state().page = get_query().blizzard_query.first_page or 0
            while get_state().page <= (get_query().blizzard_query.last_page or math.huge) do
				submit_query()
                wait_for_results()
                get_state().page = get_state().page + 1
                if get_state().page > last_page(get_state().total_auctions) then
                    break
                end
            end
		else
			get_state().page = nil
			scan_page()
        end
        get_state().query_index = get_state().query_index + 1
    end
	complete()
end

function submit_query()
    if get_state().stopped then
        return
    end

    if get_state().params.type == 'list' then
        while not CanSendAuctionQuery() do
            aux.coro_wait()
        end

        SortAuctionClearSort(get_state().params.type)
        SortAuctionItems(get_state().params.type, 'duration')
        SortAuctionItems(get_state().params.type, 'duration')

        get_state().last_list_query = GetTime()
        local blizzard_query = get_query().blizzard_query or {}
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
            get_state().params.get_all,
            blizzard_query.class ~= 1 and blizzard_query.class ~= 2 and blizzard_query.exact, -- Doesn't work for suffix items
            category_filter
        )
    end
end

function scan_page(results)
    for i = 1, page_size() do
        if i % 1000 == 0 then -- Throttling for getAll scan
            local t0 = GetTime()
            while GetTime() < t0 + .1 do
                aux.coro_wait()
            end
        end
        local auction_info = results and results[i] or info.auction(i, get_state().params.type)
        if auction_info and (auction_info.owner or get_state().params.ignore_owner or aux.account_data.ignore_owner) then -- TODO
            auction_info.index = i
            auction_info.page = get_state().page
            auction_info.blizzard_query = get_query().blizzard_query
            auction_info.query_type = get_state().params.type

            history.process_auction(auction_info)

            if not get_query().validator or get_query().validator(auction_info) then
                do (get_state().params.on_auction or pass)(auction_info) end
            end
        end
    end
    do (get_state().params.on_page_scanned or pass)() end
end

function wait_for_results()
    if get_state().params.type == 'bidder' then
        accept_results()
    elseif get_state().params.type == 'owner' then
        accept_results()
    elseif get_state().params.type == 'list' then
        wait_for_list_results()
    end
end

function accept_results(results)
	_,  get_state().total_auctions = GetNumAuctionItems(get_state().params.type)
	do
		(get_state().params.on_page_loaded or pass)(
			get_state().page - (get_query().blizzard_query.first_page or 0) + 1,
			last_page(get_state().total_auctions) - (get_query().blizzard_query.first_page or 0) + 1,
			total_pages(get_state().total_auctions) - 1
		)
	end
	scan_page(results)
end

function wait_for_list_results()
    local scanned_auctions = {}
    local updated, last_update

    get_state().listener_id = aux.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        last_update = GetTime()
        updated = true
    end)

    local timeout = aux.later(TIMEOUT, get_state().last_list_query)

    while true do
        if not last_update and timeout() then
            break
        elseif last_update and GetTime() - last_update > TIMEOUT then
            break
        elseif updated then
            updated = false
            local complete = true
            local count = 0
            for i = 1, GetNumAuctionItems'list' do
                if not scanned_auctions[i] then
                    local auction = info.auction(i, 'list')
                    if auction then
                        scanned_auctions[i] = auction
                    else
                        complete = false
                    end
                    count = count + 1
                    if count % 100 == 0 then
                        local t0 = GetTime()
                        while GetTime() < t0 + .1 do
                            aux.coro_wait()
                        end
                    end
                end
            end
            if complete then
                break
            end
        end
        aux.coro_wait()
    end

    aux.kill_listener(get_state().listener_id)
    if not last_update and timeout() then
        submit_query()
        wait_for_results()
    else
        accept_results(scanned_auctions)
    end
end