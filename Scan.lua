local SCAN_STATE_IDLE = 0
local SCAN_STATE_PREQUERY = 1
local SCAN_STATE_POSTQUERY = 2

NUM_AUCTION_ITEMS_PER_PAGE = 50

local currentQuery
local currentPage
local scanState = SCAN_STATE_IDLE

local scanData

-----------------------------------------

function Auctionator_Scan_State_Idle()
	return scanState == SCAN_STATE_IDLE
end

function Auctionator_Scan_State_Prequery()
	return scanState == SCAN_STATE_PREQUERY
end

function Auctionator_Scan_State_Postquery()
	return scanState == SCAN_STATE_POSTQUERY
end

-----------------------------------------

function Auctionator_Scan_Complete()
	
	if currentQuery.onComplete then
		currentQuery.onComplete(scanData);
	end
	
	currentQuery = nil
	currentPage = nil
	scanData = nil
	scanState = SCAN_STATE_IDLE
end

-----------------------------------------

function Auctionator_Scan_Abort()

	if currentQuery and currentQuery.onAbort then
		currentQuery.onAbort();
	end
	
	currentQuery = nil
	currentPage = nil
	scanData = nil
	scanState = SCAN_STATE_IDLE
end

-----------------------------------------

function Auctionator_Scan_Query()
	if scanState == SCAN_STATE_PREQUERY then
		
		QueryAuctionItems(
			currentQuery.name,
			currentQuery.minLevel,
			currentQuery.maxLevel,
			currentQuery.invTypeIndex,
			currentQuery.classIndex,
			currentQuery.subclassIndex,
			currentPage,
			currentQuery.isUsable,
			currentQuery.qualityIndex
		)
		scanState = SCAN_STATE_POSTQUERY
		currentPage = currentPage + 1
	end
end

-----------------------------------------

function Auctionator_Scan_Process()
	
	if scanState == SCAN_STATE_POSTQUERY then
	
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
					duration		= duration
			}
			
			if not currentQuery.exactMatch or (currentQuery.name == scanDatum.name and scanDatum.buyoutPrice > 0) then -- TODO separate option for buyout price
				tinsert(scanData, scanDatum)
				if currentQuery.onReadDatum then
					currentQuery.onReadDatum(scanDatum)
				end
			end
		end

		if numBatchAuctions == NUM_AUCTION_ITEMS_PER_PAGE then			
			scanState = SCAN_STATE_PREQUERY	
		else
			Auctionator_Scan_Complete()
		end
	end
end

-----------------------------------------

function Auctionator_Scan_Start(query)
	
	Auctionator_SetMessage("Scanning auctions ...")

	if scanState ~= SCAN_STATE_IDLE then
		Auctionator_Scan_Abort()
	end
	
	currentQuery = query
	currentPage = 0
	scanData = {}
	scanState = SCAN_STATE_PREQUERY
end

-----------------------------------------

function Auctionator_Scan_CreateQuery(parameterMap)
	local query = {
		name = nil,
		exactMatch = false,
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