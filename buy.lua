Aux.buy = {}

local record_auction, createOrder, updateOrder
local entries
local selectedEntries = {}
local searchQuery

-----------------------------------------

function Aux_AuctionFrameBids_Update()
	Aux.orig.AuctionFrameBids_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
	end
end

-----------------------------------------

function AuxBuySearchButton_OnClick()
	entries = nil
	selectedEntries = {}
	Aux_Buy_ScrollbarUpdate()
	searchQuery = Aux.scan.create_query{
		name = AuxBuySearchBox:GetText(),
		exactMatch = true
	}
	Aux.buy.set_message('Scanning auctions ...')
	Aux.scan.start{
			query = searchQuery,
			on_start_page = function(i)
				Aux.buy.set_message('Scanning auctions: page ' .. i .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)
				local stack_size = auction_item.charges or auction_item.count
				record_auction(auction_item.name, stack_size, auction_item.buyout_price, auction_item.quality, auction_item.owner, auction_item.itemlink)
			end,
			on_complete = function()
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

function Aux.buy.set_message(msg)
	AuxBuyMessage:SetText(msg)
	AuxBuyMessage:Show()
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
	
	Aux.buy.set_message('Scanning auctions ...')
	Aux.scan.start{
			query = searchQuery,
			on_start_page = function(i)
				Aux.buy.set_message('Scanning auctions: page ' .. i .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)

				if auction_item.name and auction_item.count and auction_item.buyout_price then
					local key = auction_item.name.."_"..auction_item.count.."_"..auction_item.buyout_price
					if order[key] then
					
						if GetMoney() >= auction_item.buyout_price then
							PlaceAuctionBid("list", i, auction_item.buyout_price)
							purchasedCount = purchasedCount + 1
						end
						
						if order[key] > 1 then
							order[key] = order[key] - 1
						else
							order[key] = nil
						end
					else
						local stack_size = auction_item.charges or auction_item.count
						record_auction(auction_item.name, stack_size, auction_item.charges, auction_item.buyout_price, auction_item.quality, auction_item.owner, auction_item.itemlink)
					end
				end
			end,
			on_complete = function()
				Aux_Buy_ScrollbarUpdate()
				AuxBuySearchButton:Enable()
				Aux_Buy_ShowReport(true, orderedCount, purchasedCount)
			end,
			on_abort = function()
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

function AuxBuyEntry_OnEnter()
	local entryIndex = this:GetID()
	local entry = entries[entryIndex]

	local found, _, itemString = string.find(entry.itemLink, "^|%x+|H(.+)|h%[.+%]")
	if(found) then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink(itemString);
		GameTooltip:Show();
		
		if(EnhTooltip ~= nil) then
			EnhTooltip.TooltipCall(GameTooltip, entry.name, entry.itemLink, entry.quality, entry.stackSize);
		end
	end
end

-----------------------------------------

function record_auction(name, stack_size, buyout_price, quality, owner, itemlink)
	entries = entries or {}
	
	if buyout_price > 0 and owner ~= UnitName("player") then
		tinsert(entries, {
				name		= name,
				stackSize	= stack_size,
				buyoutPrice	= buyout_price,
				itemPrice	= buyout_price / stack_size,
				quality		= quality,
				itemLink	= itemlink,
		})
	end
	
	table.sort(entries, function(a,b) return a.itemPrice < b.itemPrice end)
end

-----------------------------------------

function Aux_Buy_ScrollbarUpdate()
	if entries and getn(entries) == 0 then
		Aux.sell.set_message("No auctions were found")
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