local private , public = {}, {}
Aux.scan = public

local PAGE_SIZE = 50

local state
local threads = {}

function private.default_next_page(page, total_pages)
    local last_page = max(total_pages - 1, 0)
    if page < last_page then
        return page + 1
    end
end

function private.current_query()
    return private.current_thread().params.queries[private.current_thread().query_index]
end

function private.current_thread()
    for _, thread in pairs(threads) do
        if thread.id == Aux.control.thread_id then
            return thread
        end
    end
end

function public.start(params)
    public.abort(params.type)

    local thread_id = Aux.control.new_thread(private.scan)
    threads[params.type] = {
        id = thread_id,
        params = params,
    }
end

function public.abort(type)
    for t, thread in pairs(threads) do
        if not type or type == t then
            if thread.params.on_abort then
                thread.params.on_abort()
            end
            threads[t] = nil
            Aux.control.kill_thread(thread.id)
        end
    end
end

function private.wait_for_results(k)
    if private.current_thread().params.type == 'bidder' then
        return Aux.control.wait_until(function() return Aux.bids_loaded end, k)
    elseif private.current_thread().params.type == 'owner' then
        return private.wait_for_owner_results(k)
    elseif private.current_thread().params.type == 'list' then
        return private.wait_for_list_results(k)
    end
end

function private.wait_for_owner_results(k)
    local updated
    if private.current_thread().page == Aux.current_owner_page then
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
        local ok = updated and private.owner_data_complete() or last_update and GetTime() - last_update > 5
        updated = false
        return ok
    end, function()
        listener:stop()
        return k()
    end)
end

function private.owner_data_complete()
    if private.current_thread().params.no_wait_owner then
        return true
    end
    local count, _ = GetNumAuctionItems(private.current_thread().params.type)
    for i=1,count do
        local auction_info = Aux.info.auction(i, private.current_thread().params.type)
        if auction_info and not auction_info.owner then
            return false
        end
    end
    return true
end

function private.wait_for_callback(args) -- the arguments must not be nil!
	local ok = true

    local f = tremove(args, 1)
    local k = tremove(args)

	if f then
		tinsert(args, {
			suspend = function() ok = false end,
			resume = function() ok = true end,
		})
		f(unpack(args))
	end

	if ok then
		return k()
    else
        return Aux.control.wait_until(function() return ok end, k)
	end
end


function private.scan()
    local start_query_index = private.current_thread().params.start_query_index or 1
    local next_query_index = private.current_thread().params.next_query_index or function(query_index) return query_index + 1 end

    private.current_thread().query_index = private.current_thread().query_index and next_query_index(private.current_thread().query_index) or start_query_index
    if private.current_query() then
        private.wait_for_callback{private.current_thread().params.on_start_query or Aux.util.pass, private.current_thread().query_index, function()
            private.current_thread().page = private.current_query().start_page
            return private.process_query()
        end }
    else
        local on_complete = private.current_thread().params.on_complete
        threads[private.current_thread().params.type] = nil
        if on_complete then
            return on_complete()
        end
    end
end

function private.process_query()

    private.submit_query(function()

        local count, _ = GetNumAuctionItems(private.current_thread().params.type)

        private.scan_auctions(count, function()

            private.wait_for_callback{private.current_thread().params.on_page_scanned or Aux.util.pass, function()
                if private.current_query().next_page then
                    private.current_thread().page = private.current_query().next_page(private.current_thread().page, private.current_thread().total_pages)
                else
                    private.current_thread().page = private.default_next_page(private.current_thread().page, private.current_thread().total_pages)
                end

                if private.current_thread().page then
                    return private.process_query()
                else
                    return private.scan()
                end
            end}
        end)
    end)
end

function private.scan_auctions(count, k)
	return private.scan_auctions_helper(1, count, k)
end

function private.scan_auctions_helper(i, n, k)
    local recurse = function()
        if i >= n then
            return k()
        else
            return private.scan_auctions_helper(i + 1, n, k)
        end
    end

    local auction_info = Aux.info.auction(i, private.current_thread().params.type)
    if auction_info then
        auction_info.index = i
        auction_info.page = private.current_thread().page
        auction_info.query = private.current_query()
        auction_info.query_type = private.current_thread().params.type

        Aux.history.process_auction(auction_info)

        if not private.current_query().validator or private.current_query().validator(auction_info) then
            return private.wait_for_callback{private.current_thread().params.on_read_auction or Aux.util.pass, auction_info, recurse }
        end
    end

    return recurse()
end

function private.submit_query(k)
	if private.current_thread().page then
        Aux.control.wait_until(function() return private.current_thread().params.type ~= 'list' or CanSendAuctionQuery() end, function()

            if private.current_thread().params.on_submit_query then
                private.current_thread().params.on_submit_query()
            end
            if private.current_thread().params.type == 'bidder' then
                GetBidderAuctionItems(private.current_thread().page)
            elseif private.current_thread().params.type == 'owner' then
                GetOwnerAuctionItems(private.current_thread().page)
            else
                QueryAuctionItems(
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'name'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'min_level'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'max_level'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'slot'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'class'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'subclass'},
                    private.current_thread().page,
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'usable'},
                    Aux.util.safe_index{private.current_query(), 'blizzard_query', 'quality'}
                )
            end
            private.wait_for_results(function()
                local _, total_count = GetNumAuctionItems(private.current_thread().params.type)
                private.current_thread().total_pages = math.ceil(total_count / PAGE_SIZE)
                if private.current_thread().total_pages >= private.current_thread().page + 1 then
                    private.wait_for_callback{private.current_thread().params.on_page_loaded or Aux.util.pass, private.current_thread().page, private.current_thread().total_pages, function()
                        return k()
                    end}
                else
                    return k()
                end
            end)
		end)
	else
		return k()
	end
end
