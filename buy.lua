Aux.buy = {}

local record_auction, createOrder, updateOrder, set_message, report
local entries
local selectedEntries = {}
local search_query

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
	
	local category = UIDropDownMenu_GetSelectedValue(AuxBuyCategoryDropDown)
	
	search_query = Aux.scan.create_query{
		name = AuxBuySearchBox:GetText(),
		invTypeIndex = category and category.type,
		classIndex = category and category.class,	
		subclassIndex = category and category.subclass,
	}
	
	set_message('Scanning auctions ...')
	Aux.scan.start{
			query = search_query,
			on_start_page = function(i)
				set_message('Scanning auctions: page ' .. i + 1 .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)
				if not auction_item then
					return
				end
				
				local stack_size = auction_item.charges or auction_item.count
				if auction_item.name == search_query.name or name == '' or not AuxBuyExactCheckButton:GetChecked() then
					record_auction(auction_item.name, auction_item.tooltip, stack_size, auction_item.buyout_price, auction_item.quality, auction_item.owner, auction_item.hyperlink)
				end
			end,
			on_complete = function()
				entries = entries or {}
				Aux_Buy_ScrollbarUpdate()
			end,
			on_abort = function()
				entries = nil
			end
	}
end

-----------------------------------------

function createOrder()
	local order = {}
	for entry,_ in pairs(selectedEntries) do
		local key = Aux.auction_key(entry.tooltip, entry.stackSize, entry.buyoutPrice)
				
		if order[key] then
			order[key] = order[key] + 1
		else			
			order[key] = 1
		end
	end
	return order
end

-----------------------------------------

function set_message(msg)
	AuxBuyMessage:SetText(msg)
	AuxBuyMessage:Show()
end

-----------------------------------------

function AuxBuyBuySelectedButton_OnClick()
	
	local order = createOrder(selectedEntries)
	local orderedCount = Aux_SetSize(selectedEntries)
	
	entries = nil
	selectedEntries = {}
	
	Aux_Buy_ScrollbarUpdate()	
	AuxBuySearchButton:Disable()
	AuxBuyBuySelectedButton:Disable()
	
	local progress = {
		auctions = 0,
		units = 0,
		expense = 0,
	}				
	
	set_message('Scanning auctions ...')
	Aux.scan.start{
			query = search_query,
			on_start_page = function(i)
				set_message('Scanning auctions: page ' .. i + 1 .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)
				
				if not auction_item then
					return
				end
				
				local stack_size = auction_item.charges or auction_item.count
				
				if not auction_item.name or not stack_size or not auction_item.buyout_price then
					return
				end

				local key = Aux.auction_key(auction_item.tooltip, stack_size, auction_item.buyout_price)
				if order[key] then
				
					if GetMoney() >= auction_item.buyout_price then
						PlaceAuctionBid("list", i, auction_item.buyout_price)
						progress.auctions = progress.auctions + 1
						progress.units = progress.units + stack_size
						progress.expense = progress.expense + auction_item.buyout_price
					end
					
					if order[key] > 1 then
						order[key] = order[key] - 1
					else
						order[key] = nil
					end
				else
					if auction_item.name == search_query.name then
						record_auction(auction_item.name, auction_item.tooltip, stack_size, auction_item.buyout_price, auction_item.quality, auction_item.owner, auction_item.hyperlink)
					end
				end
			end,
			on_complete = function()
				entries = entries or {}
				Aux_Buy_ScrollbarUpdate()
				AuxBuySearchButton:Enable()
				report(true, search_query.name, orderedCount, progress)
			end,
			on_abort = function()
				entries = nil
				AuxBuySearchButton:Enable()
				report(false, search_query.name, orderedCount, progress)
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

	local _, _, itemString = strfind(entry.hyperlink, "^|%x+|H(.+)|h%[.+%]")
	if itemString then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(itemString)
		GameTooltip:Show()
		
		if(EnhTooltip ~= nil) then
			EnhTooltip.TooltipCall(GameTooltip, entry.name, entry.hyperlink, entry.quality, entry.stackSize)
		end
	end
end

-----------------------------------------

function record_auction(name, tooltip, stack_size, buyout_price, quality, owner, hyperlink)
	entries = entries or {}
	
	if buyout_price > 0 and owner ~= UnitName("player") then
		tinsert(entries, {
				name		= name,
				tooltip		= tooltip,
				stackSize	= stack_size,
				buyoutPrice	= buyout_price,
				itemPrice	= buyout_price / stack_size,
				quality		= quality,
				hyperlink	= hyperlink,
		})
	end
	
	table.sort(entries, function(a,b) return a.itemPrice < b.itemPrice end)
end

-----------------------------------------

function Aux_Buy_ScrollbarUpdate()
	if entries and getn(entries) == 0 then
		set_message("No auctions were found")
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
end

-----------------------------------------

function report(completed, item_name, ordered_count, progress)
	
	AuxBuyReportHTML:SetText(string.format(
			[[
			<html>
			<body>
				<h1>Aux Buy Report%s</h1>
				<br/>
				<p>
					%i out of %i ordered auctions of %s purchased
					<br/><br/>
					Total units purchased: %i
					<br/>
					Total expense: %s
				</p>
			</body>
			</html>
			]],
			completed and '' or ' (Aborted)',
			progress.auctions,
			ordered_count,
			item_name,
			progress.units,
			Aux.util.format_money(progress.expense)
	))
		
	AuxBuyReportHTML:SetSpacing(3)
	
	AuxBuyReport:Show()
end

-----------------------------------------

function AuxBuyCategoryDropDown_Initialize(arg1)
	local level = arg1 or 1
	
	if level == 1 then
		local value = {}
		UIDropDownMenu_AddButton({
			text= 'All',
			value = value,
			func = AuxBuyCategoryDropDown_OnClick('All', value),
		}, 1)
		
		for i, class in pairs({ GetAuctionItemClasses() }) do
			local value = { class = i }
			UIDropDownMenu_AddButton({
				hasArrow = GetAuctionItemSubClasses(value.class),
				text = class,
				value = value,
				func = AuxBuyCategoryDropDown_OnClick(class, value),
			}, 1)
		end
	end
	
	if level == 2 then
		local menu_value = UIDROPDOWNMENU_MENU_VALUE
		for i, subclass in pairs({ GetAuctionItemSubClasses(menu_value.class) }) do
			local value = { class = menu_value.class, subclass = i }
			UIDropDownMenu_AddButton({
				hasArrow = GetAuctionInvTypes(value.class, value.subclass),
				text = subclass,
				value = value,
				func = AuxBuyCategoryDropDown_OnClick(subclass, value),
			}, 2)
		end
	end
	
	if level == 3 then
		local menu_value = UIDROPDOWNMENU_MENU_VALUE
		for i, type in pairs({ GetAuctionInvTypes(menu_value.class, menu_value.subclass) }) do
			local type_name = getglobal(type)
			local value = { class = menu_value.class, subclass = menu_value.subclass, type = i }
			UIDropDownMenu_AddButton({
				text = type_name,
				value = value,
				func = AuxBuyCategoryDropDown_OnClick(type_name, value),
			}, 3)
		end
	end
end

function AuxBuyCategoryDropDown_OnClick(text, value)
	return function()
		UIDropDownMenu_SetSelectedValue(AuxBuyCategoryDropDown, value)
		UIDropDownMenu_SetText(text, AuxBuyCategoryDropDown) -- shouldn't be necessary ...
		CloseDropDownMenus(1) -- nor this
	end
end

function AuxBuySlotDropDown_Initialize(arg1)

	UIDropDownMenu_AddButton{
		text= 'All',
		value = value,
		func = AuxBuySlotDropDown_OnClick('All', value),
	}
	
	-- for i, type in pairs({ GetAuctionInvTypes() }) do
		-- UIDropDownMenu_AddButton{
			-- text = class,
			-- value = i,
			-- func = AuxBuySlotDropDown_OnClick(),
		-- }
	-- end
end

function AuxBuySlotDropDown_OnClick()
	UIDropDownMenu_SetSelectedValue(AuxBuySlotDropDown, this.value)
end