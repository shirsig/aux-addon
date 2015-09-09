local STATE_IDLE = 0
local STATE_PREQUERY = 1
local STATE_POSTQUERY = 2

local NUM_AUCTION_ITEMS_PER_PAGE = 50

local currentJob
local currentPage
local state = STATE_IDLE

local scanData

local timeOfLastUpdate = GetTime()

-- forward declaration of local functions
local submitQuery, processQueryResults

-----------------------------------------

function Auctionator_Scan_IsIdle()
	return state == STATE_IDLE
end

-----------------------------------------

function Auctionator_Scan_Complete()
	if state ~= STATE_IDLE then
		if currentJob.onComplete then
			currentJob.onComplete(scanData)
		end
		
		currentJob = nil
		currentPage = nil
		scanData = nil
		state = STATE_IDLE
	end
end

-----------------------------------------

function Auctionator_Scan_Abort()
	if state ~= STATE_IDLE then
		if currentJob and currentJob.onAbort then
			currentJob.onAbort()
		end
		
		currentJob = nil
		currentPage = nil
		scanData = nil
		state = STATE_IDLE
	end
end

-----------------------------------------

function Auctionator_Scan_Start(job)

	Auctionator_SetMessage("Scanning auctions ...")

	if state ~= STATE_IDLE then
		Auctionator_Scan_Abort()
	end
	
	currentJob = job
	currentPage = 0
	scanData = {}
	state = STATE_PREQUERY
end

-----------------------------------------

function Auctionator_Scan_CreateQuery(parameterMap)
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
	currentPage = currentPage + 1
end

-----------------------------------------

function processQueryResults()
	
	-- SortAuctionItems("list", "buyout")
	-- if IsAuctionSortReversed("list", "buyout") then
		-- SortAuctionItems("list", "buyout")
	-- end
	
	local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

	if totalAuctions >= NUM_AUCTION_ITEMS_PER_PAGE then
		Auctionator_SetMessage("Scanning auctions: page "..currentPage.." ...")
	end
			
	for i = 1, numBatchAuctions do
	
		local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)
		local duration = GetAuctionItemTimeLeft("list", i)

		local scanDatum = {		
				name			= name,
				texture			= texture,
				stackSize		= count,
				quality			= quality,
				canUse			= canUse,
				level			= level,
				minBid			= minBid,
				minIncrement	= minIncrement,
				buyoutPrice		= buyoutPrice,
				bidAmount		= bidAmount,
				highBidder		= highBidder,
				owner			= owner,
				duration		= duration,
				page			= currentPage,
				pageIndex		= i
		}
		
		if currentJob.onReadDatum then
			local keepDatum = currentJob.onReadDatum(scanDatum)
			if keepDatum then
				tinsert(scanData, scanDatum)
			end
		else
			tinsert(scanData, scanDatum)
		end
	end

	if numBatchAuctions == NUM_AUCTION_ITEMS_PER_PAGE then			
		state = STATE_PREQUERY	
	else
		Auctionator_Scan_Complete()
	end
end

-----------------------------------------

function Auctionator_Scan_OnEvent()
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		if state == STATE_POSTQUERY then
			processQueryResults()
		end
	end
end

-----------------------------------------

function Auctionator_Scan_OnUpdate()
	if state == STATE_PREQUERY and GetTime() - timeOfLastUpdate > 0.5 then
	
		timeOfLastUpdate = GetTime()

		if CanSendAuctionQuery() then
			submitQuery()
		end
	end
end