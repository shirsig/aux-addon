Aux.scan = {}

Aux.scan.MAX_AUCTIONS_PER_PAGE = 50

local ready
local continuation

local current_job
local current_page

local wait, wait_for_results, wait_after, wait_for_function, wait_until_can_query, scan, scan_page, ready -- TODO

-- forward declaration of local functions
local submit_query, start_processing_page


function Aux.scan.on_event()
	if current_job and ready and ready(event) then
		resume = nil
		continuation()
	end
end

function Aux.scan.on_update()
	if current_job and ready and ready() then
		resume = nil
		continuation()
	end
end

function Aux.scan.start(job)
	Aux.scan.abort()
	
	scan(job)
end

function wait(timeout)
	local start_time = GetTime()
	resume = function()
		return GetTime() - start_time >= timeout
	end
end

function wait_after()
	local last
	return function wait(timeout)
		resume = function()
			return GetTime() - last >= timeout
		end
		coroutine:yield()
	end,
	function()
		last = GetTime()
	end
end

function wait_for_results(k)
	continuation = k
	local start_time = GetTime()
	resume = function(event)
		return event == "AUCTION_ITEM_LIST_UPDATE"
	end
end

function wait_for_function(f, args, k)
	if not f then k() end
	local done
	tinsert(args, function() done = true end, 1)
	f(unpack(args))
	resume = function(event)
		return done
	end
end

function wait_until(p)
	resume = function()
		return p()
	end
end

function start_processing_page()
	page_state = {}
	local count, total_count = GetNumAuctionItems("list")
	page_state.index = 1
	page_state.count = count
	page_state.total_count = total_count
	
	if current_job.on_start_page then
		wait_for_function(current_job.on_start_page, {current_page})
	end
end


function Aux.scan.complete()
	if current_job and current_job.on_complete then
		current_job.on_complete()
	end
	
	current_job = nil
	current_page = nil
end


function Aux.scan.abort()
	if current_job and current_job.on_abort then
		current_job.on_abort()
	end
	
	current_job = nil
	current_page = nil
end


function scan()

	scan_page(current_page, function()
	
	current_page = current_job.next_page and current_job.next_page(current_page)
	if current_page then
		return Aux.scan.complete()
	else
		return scan()
	end
	
	end)
end

function scan_page(page, k)
	wait_for_function(current_job.on_start_page, {current_page}, function()
	
	submit_query(function()
	
	wait_for_results(function()
	
	local count, total_count = GetNumAuctionItems("list")
	
	scan_auctions(count, k)
	
	end)end)end)
end

function scan_auctions(count, k)
	scan_auctions_helper(1, count, k)
end

function scan_auctions_helper(i, n, k)
	wait_for_function(current_job.on_read_auction, {current_page}, function()
	
	if i == n then
		return k()
	else
		return scan_auctions_helper(i + 1, n, k)
	end
	
	end)
end

function submit_query(k)
	wait_until(CanSendAuctionQuery, function()
	QueryAuctionItems(
		current_job.query.name,
		current_job.query.min_level,
		current_job.query.max_level,
		current_job.query.slot,
		current_job.query.class,
		current_job.query.subclass,
		current_page,
		current_job.query.usable,
		current_job.query.quality
	)
	
	return k()
	end)
end
