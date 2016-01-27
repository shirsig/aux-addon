local private , public = {}, {}
Aux.scan = public

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
	if state and state.params and state.params.on_abort then
		state.params.on_abort()
	end
	state = nil
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
	local t0 = time()
	return controller().wait(function()
		if time() - t0 > 5 then -- we won't wait longer than 5 seconds
			return true
		end
		local count, _ = GetNumAuctionItems(state.params.type)
		for i=1,count do
			local auction_info = Aux.info.auction(i, state.params.type)
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

    state.query_index = state.query_index and state.query_index + 1 or 1
    if current_query() then
        state.page = current_query().start_page
        return private.process_query()
    else
        if state.params.on_complete then
            return state.params.on_complete()
        end
    end
end


function private.process_query()

    submit_query(function()

        local count, _ = GetNumAuctionItems(current_query().type)

        scan_auctions(count, function()

            state.page = current_query().next_page and current_query().next_page(state.page, state.total_pages)

            if state.page then
                return private.process_query()
            else
                return private.scan()
            end
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

        local snapshot = Aux.persistence.load_snapshot()
        if not snapshot.contains(auction_info.signature) then
            snapshot.add(auction_info.signature, auction_info.duration)
            Aux.history.process_auction(auction_info)
        end

        wait_for_callback{state.params.on_read_auction or Aux.util.pass, auction_info, recurse}
    else
        recurse()
    end
end

function submit_query(k)
	if state.page then
		controller().wait(function() return current_query().type ~= 'list' or CanSendAuctionQuery() end, function()

            if state.params.on_submit_query then
                state.params.on_submit_query()
            end
            wait_for_results(function()
                --wait_for_owner_data(function()
                local _, total_count = GetNumAuctionItems(current_query().type)
                state.total_pages = math.ceil(total_count / PAGE_SIZE)
                if state.total_pages >= state.page + 1 then
					wait_for_callback{state.params.on_page_loaded or Aux.util.pass, state.page, state.total_pages, function()
						return k()
					end}
				else
					return k()
				end
                -- end)
            end)
            if current_query().type == 'bidder' then
                GetBidderAuctionItems(state.page)
            elseif current_query().type == 'owner' then
                GetOwnerAuctionItems(state.page)
            else
                QueryAuctionItems(
                    current_query().name,
                    current_query().min_level,
                    current_query().max_level,
                    current_query().slot,
                    current_query().class,
                    current_query().subclass,
                    state.page,
                    current_query().usable,
                    current_query().quality
                )
            end
		end)
	else
		return k()
	end
end
