Aux.scan = {}

Aux.scan.MAX_AUCTIONS_PER_PAGE = 50

local current_job
local current_page
local page_state

local last_queried = GetTime()

local processing

-- forward declaration of local functions
local submit_query, start_processing_page

-----------------------------------------

function Aux.scan.on_event()
	if event == "AUCTION_ITEM_LIST_UPDATE" and current_job and not page_state and not processing then
		processing = true -- careful, race conditions
		start_processing_page()
	end
end

-----------------------------------------

function start_processing_page()
	page_state = {}
	local count, total_count = GetNumAuctionItems("list")
	page_state.index = 1
	page_state.count = count
	page_state.total_count = total_count
	
	if current_job.on_start_page then
		current_job.on_start_page(current_page)
	end
end

-----------------------------------------

function Aux.scan.on_update()

	if page_state and page_state.index <= page_state.count and current_job.on_read_auction then		
		current_job.on_read_auction(page_state.index)
	end
		
	if page_state and page_state.index == page_state.count then
		current_page = current_job.next_page and current_job.next_page(current_page, page_state.count, page_state.total_count)
		if current_page then
			page_state = nil
		else
			Aux.scan.complete()
		end
	end
		
	if page_state then
		page_state.index = min(page_state.index + 1, page_state.count)
	end
		
	if not page_state and current_job and CanSendAuctionQuery() then
		processing = false
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
	current_page = job.start_page
	
	if not current_page then
		start_processing_page()
	end
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
