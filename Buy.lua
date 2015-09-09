local processScanResults
local entries
local selectedEntries = {}
local searchQuery

function AuctionatorBuySearchButton_OnClick()
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
	local selection = condensedSelection(selectedEntries)
	Auctionator_Scan_Start{
			query = searchQuery,
			onReadDatum = function(datum)
				local key = "_"..datum.stackSize.."_"..datum.buyoutPrice
				if selection[key] then
					-- Auctionator_Log("match: "..key)
					PlaceAuctionBid("list", datum.pageIndex, datum.buyoutPrice)
					if selection[key] > 1 then
						selection[key] = selection[key] - 1
					else
						selection[key] = nil
					end
				end
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