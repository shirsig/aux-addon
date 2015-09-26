Aux.scan = {}

local STATE_IDLE = 0
local STATE_PREQUERY = 1
local STATE_POSTQUERY = 2
local STATE_PROCESSING = 3 -- doesn't avoid race conditions completely!

local NUM_AUCTION_ITEMS_PER_PAGE = 50

local currentJob
local currentPage
local state = STATE_IDLE

local timeOfLastUpdate = GetTime()

-- forward declaration of local functions
local submitQuery, processQueryResults

-----------------------------------------

function Aux.scan.on_event()
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		if state == STATE_POSTQUERY then
			state = STATE_PROCESSING
			processQueryResults()
		end
	end
end

-----------------------------------------

function Aux.scan.on_update()
	if state == STATE_PREQUERY and GetTime() - timeOfLastUpdate > 0.5 then
	
		timeOfLastUpdate = GetTime()

		if CanSendAuctionQuery() then
			submitQuery()
		end
	end
end

-----------------------------------------

function Aux.scan.idle()
	return state == STATE_IDLE
end

-----------------------------------------

function Aux.scan.complete()
	if state ~= STATE_IDLE then
		if currentJob.on_complete then
			currentJob.on_complete()
		end
		
		currentJob = nil
		currentPage = nil
		state = STATE_IDLE
	end
end

-----------------------------------------

function Aux.scan.abort()
	if state ~= STATE_IDLE then
		if currentJob and currentJob.on_abort then
			currentJob.on_abort()
		end
		
		currentJob = nil
		currentPage = nil
		state = STATE_IDLE
	end
end

-----------------------------------------

function Aux.scan.start(job)

	if state ~= STATE_IDLE then
		Aux.scan.abort()
	end
	
	currentJob = job
	state = STATE_PREQUERY
end

-----------------------------------------

function Aux.scan.create_query(parameterMap)
	local query = {
		name = nil,
		minLevel = "",
		maxLevel = "",
		invTypeIndex = nil,
		classIndex = nil,
		subclassIndex = nil,
		isUsable = nil,
		qualityIndex = nil
	}
	
	for k,v in pairs(parameterMap) do
		query[k] = v
	end
	
	return query
end

-----------------------------------------

function submitQuery()
	QueryAuctionItems(
		currentJob.query.name,
		currentJob.query.minLevel,
		currentJob.query.maxLevel,
		currentJob.query.invTypeIndex,
		currentJob.query.classIndex,
		currentJob.query.subclassIndex,
		currentPage,
		currentJob.query.isUsable,
		currentJob.query.qualityIndex
	)
	state = STATE_POSTQUERY
	currentPage = currentPage and currentPage + 1 or 1
end

-----------------------------------------

function processQueryResults()
	
	local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

	if currentJob.on_start_page then
		currentJob.on_start_page(currentPage)
	end
			
	for i = 1, numBatchAuctions do	
		if currentJob.on_read_auction then
			currentJob.on_read_auction(i)
		end
	end

	if numBatchAuctions == NUM_AUCTION_ITEMS_PER_PAGE then			
		state = STATE_PREQUERY
	else
		Aux.scan.complete()
	end
end