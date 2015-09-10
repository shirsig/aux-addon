local processScanResults, createOrder, updateOrder
local entries
local selectedEntries = {}
local searchQuery

function AuxBuySearchButton_OnClick()
	entries = nil
	selectedEntries = {}
	Aux_Buy_ScrollbarUpdate()
	searchQuery = Aux_Scan_CreateQuery{
		name = AuxBuySearchBox:GetText(),
		exactMatch = true
	}
	Aux_Scan_Start{
			query = searchQuery,
			onComplete = function(data)
				processScanResults(data)
				Aux_Buy_ScrollbarUpdate()
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

function AuxBuyBuySelectedButton_OnClick()
	
	AuxBuySearchButton:Disable()
	AuxBuyBuySelectedButton:Disable()
	
	local order = createOrder(selectedEntries)
	local orderedCount = Aux_SetSize(selectedEntries)
	local purchasedCount = 0

	entries = nil
	selectedEntries = {}
	
	Aux_Buy_ScrollbarUpdate()					
	
	Aux_Scan_Start{
			query = searchQuery,
			onReadDatum = function(datum)
				if datum.name and datum.count and datum.buyoutPrice then
					local key = datum.name.."_"..datum.count.."_"..datum.buyoutPrice
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
				end
			end,
			onComplete = function(data)
				processScanResults(data)
				Aux_Buy_ScrollbarUpdate()
				AuxBuySearchButton:Enable()
				Aux_Buy_ShowReport(true, orderedCount, purchasedCount)
			end,
			onAbort = function()
				AuxBuySearchButton:Enable()
				Aux_Buy_ShowReport(false, orderedCount, purchasedCount)
			end
	}
end

-----------------------------------------

function AuxBuyEntry_OnClick()
	local entryIndex = this:GetID()

	local entry = entries[entryIndex]

	if Aux_SetContains(selectedEntries, entry) then
		Aux_RemoveFromSet(selectedEntries, entry)
	else
		Aux_AddToSet(selectedEntries, entry)
	end
	
	Aux_Buy_ScrollbarUpdate()

	PlaySound("igMainMenuOptionCheckBoxOn")
end

-----------------------------------------

function processScanResults(rawData)

	entries = {}

	for _,rawDatum in ipairs(rawData) do
		
		if rawDatum.buyoutPrice > 0 and rawDatum.owner ~= UnitName("player") then
			tinsert(entries, {
					name		= rawDatum.name,
					stackSize	= rawDatum.count,
					buyoutPrice	= rawDatum.buyoutPrice,
					itemPrice	= rawDatum.buyoutPrice / rawDatum.count,
					quality		= rawDatum.quality,
			})
		end
	end
	
	table.sort(entries, function(a,b) return a.itemPrice < b.itemPrice end)
end

-----------------------------------------

function Aux_Buy_ScrollbarUpdate()
	if entries and getn(entries) == 0 then
		Aux_SetMessage("No auctions were found")
	else
		AuxBuyMessage:Hide()
	end
	
	local total = 0
	for entry, _ in selectedEntries do
		total = total + entry.buyoutPrice
	end	
	MoneyFrame_Update("AuxBuyTotal", Aux_Round(total))
	
	if Aux_SetSize(selectedEntries) > 0 and GetMoney() >= total then
		AuxBuyBuySelectedButton:Enable()
	else
		AuxBuyBuySelectedButton:Disable()
	end
	
	local numrows
	if not entries then
		numrows = 0
	else
		numrows = getn(entries)
	end
	
	FauxScrollFrame_Update(AuxBuyScrollFrame, numrows, 19, 16);
	
	for line = 1,19 do

		local dataOffset = line + FauxScrollFrame_GetOffset(AuxBuyScrollFrame)
		local lineEntry = getglobal("AuxBuyEntry"..line)
		
		if numrows <= 19 then
			lineEntry:SetWidth(800)
		else
			lineEntry:SetWidth(782)
		end
		
		lineEntry:SetID(dataOffset)
		
		if dataOffset <= numrows and entries[dataOffset] then
			
			local entry = entries[dataOffset]

			local lineEntry_name = getglobal("AuxBuyEntry"..line.."_Name")
			local lineEntry_stackSize = getglobal("AuxBuyEntry"..line.."_StackSize")
			
			local color = "ffffffff"
			if Aux_QualityColor(entry.quality) then
				color = Aux_QualityColor(entry.quality)
			end
			
			lineEntry_name:SetText("\124c" .. color ..  entry.name .. "\124r")

			if Aux_SetContains(selectedEntries, entry) then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			lineEntry_stackSize:SetText(entry.stackSize)
			
			MoneyFrame_Update("AuxBuyEntry"..line.."_UnitPrice", Aux_Round(entry.buyoutPrice/entry.stackSize))
			MoneyFrame_Update("AuxBuyEntry"..line.."_TotalPrice", Aux_Round(entry.buyoutPrice))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
	
	function Aux_Buy_ShowReport(completed, orderedCount, purchasedCount)
		AuxBuyReport:Show()
		
		AuxBuyReportHTML:SetText("<html><body>"
				.."<h1>Aux Buy Report</h1><br/>"
				.."<h1>Status: "..(completed and "Completed" or "Aborted").."</h1><br/>"
				.."<p>"
				..string.format("%i out of the %i ordered auctions have been purchased", purchasedCount, orderedCount)
				.."</p>"
				.."</body></html>")
			
		AuxBuyReportHTML:SetSpacing(3)
	end
end