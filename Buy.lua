local processScanResults
local entries
local selectedEntries = {}
local searchQuery

function AuctionatorBuySearchButton_OnClick()
	entries = nil
	selectedEntries = {}
	Auctionator_Buy_ScrollbarUpdate()
	searchQuery = Auctionator_Scan_CreateQuery{
		name = AuctionatorBuySearchBox:GetText(),
		exactMatch = true
	}
	Auctionator_Scan_Start{
			query = searchQuery,
			onComplete = function(data)
				processScanResults(data)
				Auctionator_Buy_ScrollbarUpdate()
			end
	}
end

-----------------------------------------

function condensedSelection()
	local selection = {}
	for entry,_ in pairs(selectedEntries) do
		local key = "_"..entry.stackSize.."_"..entry.buyoutPrice
				
		if selection[key] then
			selection[key] = selection[key] + 1
		else			
			selection[key] = 1
		end
	end
	return selection;
end

-----------------------------------------

function AuctionatorBuyBuySelectedButton_OnClick()

	AuctionatorBuySearchButton:Disable()
	AuctionatorBuyBuySelectedButton:Disable()
	
	local selection = condensedSelection(selectedEntries)
	local selectedCount = Auctionator_SetSize(selectedEntries)
	local purchasedCount = 0
	entries = nil
	selectedEntries = {}
	
	Auctionator_Buy_ScrollbarUpdate()					
	
	Auctionator_Scan_Start{
			query = searchQuery,
			onReadDatum = function(datum)
				local key = "_"..datum.stackSize.."_"..datum.buyoutPrice
				if selection[key] then
				
					PlaceAuctionBid("list", datum.pageIndex, datum.buyoutPrice)
					purchasedCount = purchasedCount + 1
					Auctionator_Log(string.format("[Auctionator] Auction purchased", purchasedCount, selectedCount))
					if selection[key] > 1 then
						selection[key] = selection[key] - 1
					else
						selection[key] = nil
					end
					
					return false
				else
					return true
				end
			end,
			onComplete = function(data)
				Auctionator_Log(string.format("[Auctionator] Final report: %i out of %i auctions purchased", purchasedCount, selectedCount))
				processScanResults(data)
				Auctionator_Buy_ScrollbarUpdate()
				AuctionatorBuySearchButton:Enable()
				AuctionatorBuyBuySelectedButton:Enable()
			end,
			onAbort = function()
				Auctionator_Log(string.format("[Auctionator] Final report: %i out of %i auctions purchased", purchasedCount, selectedCount))
				AuctionatorBuySearchButton:Enable()
				AuctionatorBuyBuySelectedButton:Enable()
			end
	}
end

-----------------------------------------

function AuctionatorBuyEntry_OnClick()
	local entryIndex = this:GetID()

	local entry = entries[entryIndex]

	if Auctionator_SetContains(selectedEntries, entry) then
		Auctionator_RemoveFromSet(selectedEntries, entry)
	else
		Auctionator_AddToSet(selectedEntries, entry)
	end
	
	Auctionator_Buy_ScrollbarUpdate()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

-----------------------------------------

function processScanResults(rawData)

	entries = {}

	for _,rawDatum in ipairs(rawData) do
		
		if rawDatum.buyoutPrice > 0 and rawDatum.owner ~= UnitName("player") then
			tinsert(entries, {
					name		= rawDatum.name,
					stackSize	= rawDatum.stackSize,
					buyoutPrice	= rawDatum.buyoutPrice,
					itemPrice	= rawDatum.buyoutPrice / rawDatum.stackSize,
			})
		end
	end
	
	table.sort(entries, function(a,b) return a.itemPrice < b.itemPrice end)
end

-----------------------------------------

function Auctionator_Buy_ScrollbarUpdate()
	if entries and getn(entries) == 0 then
		Auctionator_SetMessage("No auctions were found")
	else
		AuctionatorBuyMessage:Hide()
	end

	local line -- 1 through 15 of our window to scroll
	local dataOffset -- an index into our data calculated from the scroll offset
	
	local numrows
	if not entries then
		numrows = 0
	else
		numrows = getn(entries)
	end
	
	FauxScrollFrame_Update(AuctionatorBuyScrollFrame, numrows, 19, 16);

	for line = 1,19 do

		dataOffset = line + FauxScrollFrame_GetOffset(AuctionatorBuyScrollFrame)
		local lineEntry = getglobal("AuctionatorBuyEntry"..line)
		
		if numrows <= 19 then
			lineEntry:SetWidth(800)
		else
			lineEntry:SetWidth(782)
		end
		
		lineEntry:SetID(dataOffset)
		
		if dataOffset <= numrows and entries[dataOffset] then
			
			local entry = entries[dataOffset]

			local lineEntry_name = getglobal("AuctionatorBuyEntry"..line.."_Name")
			local lineEntry_stackSize = getglobal("AuctionatorBuyEntry"..line.."_StackSize")

			lineEntry_name:SetText(entry.name)

			if Auctionator_SetContains(selectedEntries, entry) then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			lineEntry_stackSize:SetText(entry.stackSize)
			
			MoneyFrame_Update("AuctionatorBuyEntry"..line.."_UnitPrice", Auctionator_Round(entry.buyoutPrice/entry.stackSize))
			MoneyFrame_Update("AuctionatorBuyEntry"..line.."_TotalPrice", Auctionator_Round(entry.buyoutPrice))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
end