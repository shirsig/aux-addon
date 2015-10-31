Aux.scan = {}

local PAGE_SIZE = 50

local controller = (function()
	local controller
	return function()
		controller = controller or Aux.control.controller()
		return controller
	end
end)()

local state, abort, new_job

local scan, scan_auctions, scan_auctions_helper, submit_query, wait_for_callback, wait_for_results, wait_for_owner_data, abort

function Aux.scan.start(job)
	Aux.control.on_next_update(function()
		abort()
        job.type = job.type or 'list'
        state = {
			job = job,
			page = job.page
        }

		return scan()
	end)
end

function Aux.scan.abort(k)
	Aux.control.on_next_update(function()
		abort()
		
		if k then
			return k()
		end
	end)
end

function abort()
	controller().reset()
	if state and state.job and state.job.on_abort then
		state.job.on_abort()
	end
	state = nil
end

function wait_for_results(k)
	local ok
    if state.job.type == 'bidder' then
		ok = true
    elseif state.job.type == 'owner' then
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
	return controller().wait(function()
		local count, _ = GetNumAuctionItems(state.job.type)
		for i=1,count do
			local auction_item_info = Aux.info.auction_item(i)
			if auction_item_info and not auction_item_info.owner then
				return false
			end
		end
		return true
	end, k)
end

function wait_for_callback(args)
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

function scan()
	
	submit_query(function()
		
        local count, _ = GetNumAuctionItems(state.job.type)

        scan_auctions(count, function()

            state.page = state.job.next_page and state.job.next_page(state.page, state.total_pages)

            if state.page then
                return scan()
            else
                if state.job.on_complete then
                    state.job.on_complete()
                end
                state = nil
            end

        end)
    end)
end

function scan_auctions(count, k)
	return scan_auctions_helper(1, count, k)
end

function scan_auctions_helper(i, n, k)
	wait_for_callback{state.job.on_read_auction, i, function()
	
        if i >= n then
            return k()
        else
            return scan_auctions_helper(i + 1, n, k)
        end
	
	end}
end

function submit_query(k)
	if state.page then
		controller().wait(function() return state.job.type ~= 'list' or CanSendAuctionQuery() end, function()

            if state.job.on_submit_query then
                state.job.on_submit_query()
            end
            wait_for_results(function()
                --wait_for_owner_data(function()
                local _, total_count = GetNumAuctionItems(state.job.type)
                state.total_pages = math.ceil(total_count / PAGE_SIZE)
                if state.total_pages >= state.page + 1 then
					wait_for_callback{state.job.on_page_loaded, state.page, state.total_pages, function()
						return k()
					end}
				else
					return k()
				end
                -- end)
            end)
            if state.job.type == 'bidder' then
                GetBidderAuctionItems(state.page)
            elseif state.job.type == 'owner' then
                GetOwnerAuctionItems(state.page)
            else
                QueryAuctionItems(
                    state.job.query.name,
                    state.job.query.min_level,
                    state.job.query.max_level,
                    state.job.query.slot,
                    state.job.query.class,
                    state.job.query.subclass,
                    state.page,
                    state.job.query.usable,
                    state.job.query.quality
                )
            end
		end)
	else
		return k()
	end
end
