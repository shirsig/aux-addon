local STATE_IDLE = 0
local STATE_PREQUERY = 1
local STATE_POSTQUERY = 2
local STATE_PROCESSING = 3 -- doesn't avoid race conditions completely!

local NUM_AUCTION_ITEMS_PER_PAGE = 50

local currentJob
local currentPage
local state = STATE_IDLE

local scanData

local timeOfLastUpdate = GetTime()

-- forward declaration of local functions
local submitQuery, processQueryResults

-----------------------------------------

function Aux_Scan_IsIdle()
	return state == STATE_IDLE
end

-----------------------------------------

function Aux_Scan_Complete()
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

function Aux_Scan_Abort()
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

function Aux_Scan_Start(job)

	Aux_SetMessage("Scanning auctions ...")

	if state ~= STATE_IDLE then
		Aux_Scan_Abort()
	end
	
	currentJob = job
	scanData = {}
	state = STATE_PREQUERY
end

-----------------------------------------

function Aux_Scan_CreateQuery(parameterMap)
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

function Aux_Scan_ExtractTooltip()
	local tooltip = {}
	for j=1, 30 do -- conveniently ignores nils
		local leftEntry = getglobal('AuxScanTooltipTextLeft'..j):GetText()
		if leftEntry then
			tinsert(tooltip, leftEntry)
		end
		local rightEntry = getglobal('AuxScanTooltipTextRight'..j):GetText()
		if rightEntry then
			tinsert(tooltip, rightEntry)
		end
	end
	return tooltip
end

-----------------------------------------

function Aux_Scan_ItemCharges(tooltip)
	for _, entry in ipairs(tooltip) do
		local chargesString = gsub(entry, "(%d+) Charges", "%1")
		local charges = tonumber(chargesString)
		if charges then
			return charges
		end
	end
end	

-----------------------------------------

function processQueryResults()
		
	-- SortAuctionItems("list", "buyout")
	-- if IsAuctionSortReversed("list", "buyout") then
		-- SortAuctionItems("list", "buyout")
	-- end
	
	local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

	Aux_SetMessage("Scanning auctions: page "..currentPage.." ...")
			
	for i = 1, numBatchAuctions do
	
		local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)
		local duration = GetAuctionItemTimeLeft("list", i)
		AuxScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		AuxScanTooltip:SetAuctionItem("list", i)
		AuxScanTooltip:Show()
		local tooltip = Aux_Scan_ExtractTooltip()
		-- for _, x in ipairs(tooltip) do Aux_Log(x) end
		count = Aux_Scan_ItemCharges(tooltip) or count

		local scanDatum = {
				name			= name,
				texture			= texture,
				count			= count,
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
		Aux_Scan_Complete()
	end
end

-----------------------------------------

function Aux_Scan_OnEvent()
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		if state == STATE_POSTQUERY then
			state = STATE_PROCESSING
			processQueryResults()
		end
	end
end

-----------------------------------------

function Aux_Scan_OnUpdate()
	if state == STATE_PREQUERY and GetTime() - timeOfLastUpdate > 0.5 then
	
		timeOfLastUpdate = GetTime()

		if CanSendAuctionQuery() then
			submitQuery()
		end
	end
end