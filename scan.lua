Aux.scan = {}

local NUM_AUCTION_ITEMS_PER_PAGE = 50

local current_job
local current_page
local page_state

local last_queried = GetTime()

local timeout

-- forward declaration of local functions
local submit_query, process_query_results

-----------------------------------------

function Aux.scan.on_event()
	if event == "AUCTION_ITEM_LIST_UPDATE" and current_job and not page_state and not timeout then
		timeout = true
		page_state = {} -- careful, race conditions
		local count, total_count = GetNumAuctionItems("list")
		page_state.index = 1
		page_state.count = count
		page_state.total_count = total_count
		
		if current_job.on_start_page then
			current_job.on_start_page(current_page)
		end
	end
end

-----------------------------------------

function Aux.scan.on_update()
	if current_job and CanSendAuctionQuery() then
		timeout = false
	end
	
	if page_state then
		if page_state.index <= page_state.count and current_job.on_read_auction then		
			current_job.on_read_auction(page_state.index)
		end
		
		if page_state.index == page_state.count then
			if page_state.index == NUM_AUCTION_ITEMS_PER_PAGE then
				page_state = nil
				current_page = current_page + 1
			else
				Aux.scan.complete()
			end
		end
		
		if page_state then
			page_state.index = min(page_state.index + 1, page_state.count)
		end
		
	elseif current_job and not timeout then
		submit_query()
	end
end

-----------------------------------------

function Aux.scan.idle()
	return not current_job
end

-----------------------------------------

function Aux.scan.complete()
	if current_job and current_job.on_complete then
		current_job.on_complete()
	end
	
	current_job = nil
	current_page = nil
	page_state = nil
end

-----------------------------------------

function Aux.scan.abort()
	if current_job and current_job.on_abort then
		current_job.on_abort()
	end
	
	current_job = nil
	current_page = nil
	page_state = nil
end

-----------------------------------------

function Aux.scan.start(job)
	Aux.scan.abort()
	
	current_job = job
	current_page = 0
end

-----------------------------------------

function submit_query()
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
end
