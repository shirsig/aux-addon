local private , public = {}, {}
Aux.scan = public

aux_max_bids = {}

local PAGE_SIZE = 50

local controller = (function()
	local controller
	return function()
		controller = controller or Aux.control.controller()
		return controller
	end
end)()

local state

local scan_auctions, scan_auctions_helper, submit_query, wait_for_callback, wait_for_results, wait_for_owner_data, on_abort, current_query

function private.default_next_page(page, total_pages)
    local last_page = max(total_pages - 1, 0)
    if page < last_page then
        return page + 1
    end
end

function current_query()
    return state.params.queries[state.query_index]
end

function public.start(params)
    return controller().wait(function() return true end, function()
        on_abort()

        state = {
            params = params,
        }

        private.scan()
    end)
end

function public.abort(k)
    return controller().wait(function() return true end, function()
        on_abort()

        state = nil

        if k then
            return k()
        end
    end)
end

function on_abort()
    local on_abort = Aux.util.safe_index{state, 'params', 'on_abort' }
    state = nil
	if on_abort then
		return on_abort()
	end
end

function wait_for_results(k)
	local ok
    if current_query().type == 'bidder' then
        Aux.control.as_soon_as(function() return Aux.bids_loaded end, function()
            ok = true
        end)
    elseif current_query().type == 'owner' then
        if state.page == Aux.current_owner_page then
            ok = true
        else
            Aux.control.on_next_event('AUCTION_OWNED_LIST_UPDATE', function()
                ok = true
            end)
        end
    else
        Aux.control.on_next_event('AUCTION_ITEM_LIST_UPDATE', function()
            ok = true
        end)
    end

	return controller().wait(function() return ok end, k)
end

function wait_for_owner_data(k)
    if state.params.no_wait_owners then
        return k()
    end
	local t0 = time()
	return controller().wait(function()
		if time() - t0 > 30 then -- we won't wait longer than 30 seconds
			return true
		end
		local count, _ = GetNumAuctionItems(current_query().type)
		for i=1,count do
			local auction_info = Aux.info.auction(i, current_query().type)
			if auction_info and not auction_info.owner then
				return false
			end
		end
		return true
	end, k)
end

function wait_for_callback(args) -- the arguments must not be nil!
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
		return controller().wait(function() return ok end, k)
	end
end


function private.scan()
    local start_query_index = state.params.start_query_index or 1
    local next_query_index = state.params.next_query_index or function(query_index) return query_index + 1 end

    state.query_index = state.query_index and next_query_index(state.query_index) or start_query_index
    if current_query() then
        wait_for_callback{state.params.on_start_query or Aux.util.pass, state.query_index, function()
            state.page = current_query().start_page
            return private.process_query()
        end }
    else
        local on_complete = state.params.on_complete
        state = nil
        if on_complete then
            return on_complete()
        end
    end
end

function private.process_query()

    submit_query(function()

        local count, _ = GetNumAuctionItems(current_query().type)

        scan_auctions(count, function()

            wait_for_callback{state.params.on_page_scanned or Aux.util.pass, function()
                if current_query().next_page then
                    state.page = current_query().next_page(state.page, state.total_pages)
                else
                    state.page = private.default_next_page(state.page, state.total_pages)
                end

                if state.page then
                    return private.process_query()
                else
                    return private.scan()
                end
            end}
        end)
    end)
end

function scan_auctions(count, k)
	return scan_auctions_helper(1, count, k)
end

function scan_auctions_helper(i, n, k)
    local recurse = function()
        if i >= n then
            return k()
        else
            return scan_auctions_helper(i + 1, n, k)
        end
    end

    local auction_info = Aux.info.auction(i, current_query().type)
    if auction_info then
        auction_info.index = i
        auction_info.page = state.page
        auction_info.query = current_query()

        Aux.history.process_auction(auction_info)

        if not current_query().validator or current_query().validator(auction_info) then
            return wait_for_callback{state.params.on_read_auction or Aux.util.pass, auction_info, recurse }
        end
    end

    return recurse()
end

function submit_query(k)
	if state.page then
		controller().wait(function() return current_query().type ~= 'list' or CanSendAuctionQuery() end, function()

            if state.params.on_submit_query then
                state.params.on_submit_query()
            end
            wait_for_results(function()
                wait_for_owner_data(function()
                    local _, total_count = GetNumAuctionItems(current_query().type)
                    state.total_pages = math.ceil(total_count / PAGE_SIZE)
                    if state.total_pages >= state.page + 1 then
                        wait_for_callback{state.params.on_page_loaded or Aux.util.pass, state.page, state.total_pages, function()
                            return k()
                        end}
                    else
                        return k()
                    end
                end)
            end)
            if current_query().type == 'bidder' then
                GetBidderAuctionItems(state.page)
            elseif current_query().type == 'owner' then
                GetOwnerAuctionItems(state.page)
            else
                QueryAuctionItems(
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'name'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'min_level'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'max_level'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'slot'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'class'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'subclass'},
                    state.page,
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'usable'},
                    Aux.util.safe_index{current_query(), 'blizzard_query', 'quality'}
                )
            end
		end)
	else
		return k()
	end
end
