local processScanResults, createOrder, updateOrder
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

function createOrder()
	local order = {}
	for entry,_ in pairs(selectedEntries) do
		local key = entry.name.."_"..entry.stackSize.."_"..entry.buyoutPrice
				
		if order[key] then
			order[key] = order[key] + 1
		else			
			order[key] = 1
		end
	end
	return order
end

-----------------------------------------

function AuctionatorBuyBuySelectedButton_OnClick()
	
	AuctionatorBuySearchButton:Disable()
	AuctionatorBuyBuySelectedButton:Disable()
	
	local order = createOrder(selectedEntries)
	local orderedCount = Auctionator_SetSize(selectedEntries)
	local purchasedCount = 0

	entries = nil
	selectedEntries = {}
	
	Auctionator_Buy_ScrollbarUpdate()					
	
	Auctionator_Scan_Start{
			query = searchQuery,
			onReadDatum = function(datum)
				local key = datum.name.."_"..datum.stackSize.."_"..datum.buyoutPrice
				if order[key] then
				
					if GetMoney() >= datum.buyoutPrice then
						PlaceAuctionBid("list", datum.pageIndex, datum.buyoutPrice)
						purchasedCount = purchasedCount + 1
					else
						
					end
					
					if order[key] > 1 then
						order[key] = order[key] - 1
					else
						order[key] = nil
					end
					
					return false
				else
					return true
				end
			end,
			onComplete = function(data)
				processScanResults(data)
				Auctionator_Buy_ScrollbarUpdate()
				AuctionatorBuySearchButton:Enable()
				Auctionator_Buy_ShowReport(true, orderedCount, purchasedCount)
			end,
			onAbort = function()
				AuctionatorBuySearchButton:Enable()
				Auctionator_Buy_ShowReport(false, orderedCount, purchasedCount)
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
					quality		= rawDatum.quality,
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
	
	local total = 0
	for entry, _ in selectedEntries do
		total = total + entry.buyoutPrice
	end	
	MoneyFrame_Update("AuctionatorBuyTotal", Auctionator_Round(total))
	
	if Auctionator_SetSize(selectedEntries) > 0 and GetMoney() >= total then
		AuctionatorBuyBuySelectedButton:Enable()
	else
		AuctionatorBuyBuySelectedButton:Disable()
	end
	
	local numrows
	if not entries then
		numrows = 0
	else
		numrows = getn(entries)
	end
	
	FauxScrollFrame_Update(AuctionatorBuyScrollFrame, numrows, 19, 16);
	
	for line = 1,19 do

		local dataOffset = line + FauxScrollFrame_GetOffset(AuctionatorBuyScrollFrame)
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
			
			local color = "ffffffff"
			if(type(Auctionator.item_colors[entry.quality+1]) == "string") then color = Auctionator.item_colors[entry.quality+1]; end
			
			lineEntry_name:SetText("\124c" .. color ..  entry.name .. "\124r")

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
	
	function Auctionator_Buy_ShowReport(completed, orderedCount, purchasedCount)
		AuctionatorBuyReport:Show()
		
		AuctionatorBuyReportHTML:SetText("<html><body>"
				.."<h1>Auctionator Buy Report</h1><br/>"
				.."<h1>Status: "..(completed and "Completed" or "Aborted").."</h1><br/>"
				.."<p>"
				..string.format("%i out of the %i ordered auctions have been purchased", purchasedCount, orderedCount)
				.."</p>"
				.."</body></html>")
			
		AuctionatorBuyReportHTML:SetSpacing(3)
	end
end