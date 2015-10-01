Aux.scan = {}

local AUCTIONS_PER_PAGE = 50



local state, abort, new_job

-- forward declaration of local functions
local wait, wait_after, wait_for_function, wait_until, listen_for_event
local scan, scan_auctions, scan_auctions_helper, submit_query



function Aux.scan.on_update()
	if abort then
		if state and state.job and state.job.on_abort then
			state.job.on_abort()
		end
		state = nil
		abort = false
	elseif new_job then
		state = {
			job = new_job,
			page = new_job.page
		}
		new_job = nil
		scan()
	elseif state and state.ready and state.ready() then
		state.ready = nil
		state.continuation()
	end
end

function Aux.scan.start(job)
	abort = true
	new_job = job
end

function Aux.scan.abort()
	abort = true
end



function wait(timeout, k)
	state.continuation = k
	local start_time = GetTime()
	state.ready = function()
		return GetTime() - start_time >= timeout
	end
end

function wait_from()
	local from
	return function()
		from = GetTime()
	end,
	function(timeout, k)
		state.continuation = k
		state.ready = function()
			return from and GetTime() - from >= timeout
		end
	end
end

function listen_for_event(e)
	local occurred
	Aux.scan.on_event = function()
		if event == e then
			occurred = true
		end
	end
	return function(k)
		state.continuation = k
		state.ready = function()
			return occurred
		end
	end
end

function wait_for_function(f, args, k)
	state.continuation = k
	local complete
	state.ready = function()
		return complete
	end

	if not f then
		complete = true
	else
		tinsert(args, 1, function() complete = true end)
		f(unpack(args))
	end
end

function wait_until(p, k)
	state.continuation = k
	state.ready = function()
		return p()
	end
end



function scan()

	wait_for_function(state.job.on_start_page, {state.page}, function() --;
	
	submit_query(function() --;
		
	local count, total_count = GetNumAuctionItems("list")
	
	scan_auctions(count, function() --;
	
	local total_pages = math.ceil(total_count / AUCTIONS_PER_PAGE)
	
	state.page = state.job.next_page and state.job.next_page(state.page, total_pages)
	
	if state.page then
		return scan()
	else
		if state.job.on_complete then
			state.job.on_complete()
		end
	end
	
	end)end)end)
end

function scan_auctions(count, k)
	scan_auctions_helper(1, count, k)
end

function scan_auctions_helper(i, n, k)
	wait_for_function(state.job.on_read_auction, {i}, function() --;
	
	if i >= n then
		return k()
	else
		return scan_auctions_helper(i + 1, n, k)
	end
	
	end)
end

function submit_query(k)
	if state.page then
		wait_until(CanSendAuctionQuery, function() --;
		local wait_for_event = listen_for_event('AUCTION_ITEM_LIST_UPDATE')
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
		wait_for_event(k)
		
		end)
	else
		k()
	end
end