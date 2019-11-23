select(2, ...) 'aux.core.scan'

local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'

local PAGE_SIZE = 50
local TIMEOUT = 30

local state

function aux.event.CLOSE()
	abort()
end

function auctions(type)
    local auctions = {}
    for i = 1, GetNumAuctionItems(type) do
        local auction_record = info.auction(i, type)
        if auction_record then
            auctions[i] = auction_record
        end
    end
    return pairs(auctions)
end

function M.owner_auctions()
    return auctions('owner')
end

function M.bidder_auctions()
    return auctions('bidder')
end

function M.start(params)
    if state then
        abort()
    end
    do (params.on_scan_start or pass)() end
    aux.coro_thread(function()
        state = {
            id = aux.coro_id(),
            params = params,
        }
        scan()
    end)
end

function M.abort()
    if state then
        aux.coro_kill(state.id)
        aux.kill_listener(state.listener_id)
        local on_abort = state.params.on_abort
        state = nil
        do (on_abort or pass)() end
    end
end

function complete()
    local on_complete = state.params.on_complete
    state = nil
    do (on_complete or pass)() end
end

function get_query()
	return state.params.queries[state.query_index]
end

function total_pages()
    local page_size, total_auctions = GetNumAuctionItems'list'
    if not state.params.get_all then
        page_size = PAGE_SIZE
    end
    return page_size == 0 and 0 or ceil(total_auctions / page_size)
end

function last_page()
    local _, total_auctions = GetNumAuctionItems'list'
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = get_query().blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function scan()
    state.query_index = 1
	while get_query() do
		do (state.params.on_start_query or pass)(state.query_index) end
		if get_query().blizzard_query then
            local page = get_query().blizzard_query.first_page or 0
            while page <= (get_query().blizzard_query.last_page or math.huge) do
				repeat submit_query(page) until scan_page(page)
                page = page + 1
                if page > last_page() then
                    break
                end
            end
		elseif GetNumAuctionItems'list' <= PAGE_SIZE then
			for i, auction in auctions'list' do
                process_auction(auction, i)
            end
        end
        state.query_index = state.query_index + 1
    end
	complete()
end

function submit_query(page)
    while not CanSendAuctionQuery() do
        aux.coro_wait()
    end

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
    SortAuctionClearSort('list')
    QueryAuctionItems(
        blizzard_query.name,
        blizzard_query.min_level,
        blizzard_query.max_level,
        page,
        blizzard_query.usable,
        blizzard_query.quality,
        state.params.get_all,
        blizzard_query.class and blizzard_query.class ~= 1 and blizzard_query.class ~= 2 and blizzard_query.exact, -- Excluding suffix items
        category_filter
    )
end

function process_auction(auction, index, page)
    history.process_auction(auction)
    if auction.owner or state.params.ignore_owner or aux.account_data.ignore_owner then -- TODO
        auction.index = index
        auction.page = page
        auction.blizzard_query = get_query().blizzard_query
        if not get_query().validator or get_query().validator(auction) then
            do (state.params.on_auction or pass)(auction) end
        end
    end
end

function scan_page(page)
    local pending = {}
    local updated, last_update

    state.listener_id = aux.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        if not last_update then
            local page_size = GetNumAuctionItems'list'
            for i = 1, page_size do
                pending[i] = true
            end
            do
                (state.params.on_page_loaded or pass)(
                    page - (get_query().blizzard_query.first_page or 0) + 1,
                    last_page() - (get_query().blizzard_query.first_page or 0) + 1,
                    total_pages() - 1,
                    page_size
                )
            end
        end
        last_update = GetTime()
        updated = true
    end)

    local t0 = GetTime()
    while true do
        if not last_update and GetTime() - t0 > TIMEOUT and not state.params.get_all then
            break
        elseif last_update and GetTime() - last_update > TIMEOUT then
            break
        elseif updated then
            updated = false
            local count = 0
            for i = 1, GetNumAuctionItems'list' do
                if pending[i] then
                    local auction = info.auction(i, 'list')
                    if auction then
                        process_auction(auction, i, page)
                        pending[i] = nil
                    end
                    count = count + 1
                    if state.params.get_all and count % 10 == 0 then
                        aux.coro_wait()
                    end
                end
            end
            if not next(pending) then
                break
            end
        end
        aux.coro_wait()
    end

    aux.kill_listener(state.listener_id)

    if not last_update then
        return false
    else
        do (state.params.on_page_scanned or pass)() end
        return true
    end
end