Aux.buy = {}

local record_auction, set_message, report, tooltip_match
local entries
local selectedEntries = {}
local search_query
local tooltip_patterns = {}
local current_page
local refresh


function Aux.buy.exit()

	Aux.buy.buyout_dialog_cancel()
	current_page = nil
end

-----------------------------------------

function Aux_AuctionFrameBids_Update()
	Aux.orig.AuctionFrameBids_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
	end
end

-----------------------------------------

function Aux.buy.buyout_dialog_cancel()
	Aux.scan.abort()
	AuxBuyBuyoutDialog:Hide()
	AuxBuySearchButton:Enable()
end

-----------------------------------------

function Aux.buy.StopButton_onclick()
	Aux.scan.abort()
end

-----------------------------------------

function Aux.buy.SearchButton_onclick()

	AuxBuySearchButton:Hide()
	AuxBuyStopButton:Show()
	
	entries = nil
	selectedEntries = {}
	
	refresh = true
	
	local category = UIDropDownMenu_GetSelectedValue(AuxBuyCategoryDropDown)
	local tooltip_patterns = Aux.util.set_to_array(tooltip_patterns)
	
	search_query = {
		name = AuxBuyNameInputBox:GetText(),
		slot = category and category.slot,
		class = category and category.class,	
		subclass = category and category.subclass,
		usable = AuxBuyUsableCheckButton:GetChecked()
	}
	
	set_message('Scanning auctions ...')
	Aux.scan.start{
			query = search_query,
			start_page = 0,
			on_start_page = function(i)
				current_page = i
				set_message('Scanning auctions: page ' .. i + 1 .. ' ...')
			end,
			on_read_auction = function(i)
				local auction_item = Aux.info.auction_item(i)
				if not auction_item then
					return
				end
				local stack_size = auction_item.charges or auction_item.count
				if (auction_item.name == search_query.name or search_query.name == '' or not AuxBuyExactCheckButton:GetChecked()) and tooltip_match(tooltip_patterns, auction_item.tooltip) then
					record_auction(
						auction_item.name,
						auction_item.tooltip,
						stack_size,
						auction_item.buyout_price,
						auction_item.quality,
						auction_item.owner,
						auction_item.hyperlink,
						auction_item.itemstring,
						current_page
				)
				end
			end,
			on_complete = function()
				entries = entries or {}
				AuxBuyStopButton:Hide()
				AuxBuySearchButton:Show()
				refresh = true
			end,
			on_abort = function()
				entries = entries or {}
				AuxBuyStopButton:Hide()
				AuxBuySearchButton:Show()
				refresh = true
			end,
			next_page = function(page, auctions)
				if auctions == Aux.scan.MAX_AUCTIONS_PER_PAGE then
					return page + 1
				end
			end,
	}
end

-----------------------------------------

function set_message(msg)
	AuxBuyMessage:SetText(msg)
	AuxBuyMessage:Show()
end

-----------------------------------------

function AuxBuyEntry_OnClick()
	local express_mode = IsControlKeyDown()
	
	AuxBuySearchButton:Disable()
	
	local entry_index = this:GetID()
	local entry = entries[entry_index]
	
	if not express_mode then
		AuxBuyBuyoutDialogBuyButton:Disable()
		AuxBuyBuyoutDialogHTML:SetText(string.format(
			[[
			<html>
			<body>
				<h1>%s</h1>
				<br/>
				<p>
					Stack Size: %i
					<br/><br/>
					Buyout Price: %s
					<br/><br/>
					Unit Price: %s
				</p>
			</body>
			</html>
			]],
			entry.name,
			entry.stack_size,
			Aux.util.format_money(entry.buyout_price),
			Aux.util.format_money(entry.item_price)
		))
		AuxBuyBuyoutDialog:Show()
	end

	PlaySound("igMainMenuOptionCheckBoxOn")
	
	local found
	local order_key = Aux.auction_key(entry.tooltip, entry.stack_size, entry.buyout_price)
	
	Aux.scan.start{
		query = search_query,
		start_page = entry.page ~= current_page and entry.page,
		on_read_auction = function(i)
			local auction_item = Aux.info.auction_item(i)
			
			if not auction_item then
				return
			end
			
			local stack_size = auction_item.charges or auction_item.count
			
			if not auction_item.tooltip or not stack_size or not auction_item.buyout_price then
				return
			end

			local key = Aux.auction_key(auction_item.tooltip, stack_size, auction_item.buyout_price)
			if key == order_key then
				found = true
			
				if express_mode then			
					if GetMoney() >= auction_item.buyout_price then
						tremove(entries, entry_index)
						refresh = true
					end
					
					PlaceAuctionBid("list", i, auction_item.buyout_price)				
					
					Aux.scan.abort()
				else
					Aux.buy.buyout_dialog_buy = function()						
						if GetMoney() >= auction_item.buyout_price then
							tremove(entries, entry_index)
							refresh = true
						end
						
						PlaceAuctionBid("list", i, auction_item.buyout_price)
					
						Aux.scan.abort()
						AuxBuySearchButton:Enable()
						AuxBuyBuyoutDialog:Hide()
					end
					AuxBuyBuyoutDialogBuyButton:Enable()
				end
			end
		end,
		on_complete = function()
			if not found then
				tremove(entries, entry_index)
				refresh = true
				Aux.buy.buyout_dialog_cancel()
			end
			if express_mode then
				AuxBuySearchButton:Enable()
			end
		end,
		on_abort = function()
			if express_mode then
				AuxBuySearchButton:Enable()
			end
		end,
	}
end

function AuxBuyEntry_OnEnter()
	local i = this:GetID()
	local entry = entries[i]
	
	Aux.info.set_game_tooltip(this, entry.tooltip)
	
	if(EnhTooltip ~= nil) then
		EnhTooltip.TooltipCall(GameTooltip, entry.name, entry.hyperlink, entry.quality, entry.stack_size)
	end
end

-----------------------------------------

function record_auction(name, tooltip, stack_size, buyout_price, quality, owner, hyperlink, itemstring, page)
	entries = entries or {}
	
	if buyout_price > 0 and owner ~= UnitName("player") then
		tinsert(entries, {
				name = name,
				tooltip = tooltip,
				stack_size = stack_size,
				buyout_price = buyout_price,
				item_price = buyout_price / stack_size,
				quality = quality,
				hyperlink = hyperlink,
				itemstring = itemstring,
				page = current_page,
		})
	end
	
	table.sort(entries, function(a,b) return a.item_price < b.item_price end)
end

-----------------------------------------

function Aux.buy.onupdate()
	if refresh then
		refresh = false
		Aux_Buy_ScrollbarUpdate()
	end
end

-----------------------------------------

function Aux_Buy_ScrollbarUpdate()
	if entries and getn(entries) == 0 then
		set_message("No auctions were found")
	else
		AuxBuyMessage:Hide()
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
			local lineEntry_stack_size = getglobal("AuxBuyEntry"..line.."_StackSize")
			
			local color = "ffffffff"
			if Aux_QualityColor(entry.quality) then
				color = Aux_QualityColor(entry.quality)
			end
			
			lineEntry_name:SetText("\124c" .. color ..  entry.name .. "\124r")

			if Aux.util.set_contains(selectedEntries, entry) then
				lineEntry:LockHighlight()
			else
				lineEntry:UnlockHighlight()
			end

			lineEntry_stack_size:SetText(entry.stack_size)
			
			MoneyFrame_Update("AuxBuyEntry"..line.."_UnitPrice", Aux_Round(entry.buyout_price/entry.stack_size))
			MoneyFrame_Update("AuxBuyEntry"..line.."_TotalPrice", Aux_Round(entry.buyout_price))

			lineEntry:Show()
		else
			lineEntry:Hide()
		end
	end
end

-----------------------------------------

function tooltip_match(patterns, tooltip)	
	return Aux.util.all(patterns, function(pattern)
		return Aux.util.any(tooltip, function(line)
			local left_match = line[1].text and strfind(strupper(line[1].text), strupper(pattern), 1, true)
			local right_match = line[2].text and strfind(strupper(line[2].text), strupper(pattern), 1, true)
			return left_match or right_match
		end)
	end)
end

-----------------------------------------

function AuxBuyCategoryDropDown_Initialize(arg1)
	local level = arg1 or 1
	
	if level == 1 then
		local value = {}
		UIDropDownMenu_AddButton({
			text= 'All',
			value = value,
			func = AuxBuyCategoryDropDown_OnClick,
		}, 1)
		
		for i, class in pairs({ GetAuctionItemClasses() }) do
			local value = { class = i }
			UIDropDownMenu_AddButton({
				hasArrow = GetAuctionItemSubClasses(value.class),
				text = class,
				value = value,
				func = AuxBuyCategoryDropDown_OnClick,
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
				func = AuxBuyCategoryDropDown_OnClick,
			}, 2)
		end
	end
	
	if level == 3 then
		local menu_value = UIDROPDOWNMENU_MENU_VALUE
		for i, slot in pairs({ GetAuctionInvTypes(menu_value.class, menu_value.subclass) }) do
			local slot_name = getglobal(slot)
			local value = { class = menu_value.class, subclass = menu_value.subclass, slot = i }
			UIDropDownMenu_AddButton({
				text = slot_name,
				value = value,
				func = AuxBuyCategoryDropDown_OnClick,
			}, 3)
		end
	end
end

function AuxBuyCategoryDropDown_OnClick()
	local qualified_name = ({ GetAuctionItemClasses() })[this.value.class] or 'All'
	if this.value.subclass then
		local subclass_name = ({ GetAuctionItemSubClasses(this.value.class) })[this.value.subclass]
		qualified_name = qualified_name .. ' - ' .. subclass_name
		if this.value.slot then
			local slot_name = getglobal(({ GetAuctionInvTypes(this.value.class, this.value.subclass) })[this.value.slot])
			qualified_name = qualified_name .. ' - ' .. slot_name
		end
	end

	UIDropDownMenu_SetSelectedValue(AuxBuyCategoryDropDown, this.value)
	UIDropDownMenu_SetText(qualified_name, AuxBuyCategoryDropDown)
	CloseDropDownMenus(1)
end

function AuxBuySlotDropDown_Initialize()

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


function AuxBuyTooltipButton_OnClick()
	local pattern = AuxBuyTooltipInputBox:GetText()
	if pattern ~= '' then
		Aux.util.set_add(tooltip_patterns, pattern)
	end
	AuxBuyTooltipInputBox:SetText('')
	if DropDownList1:IsVisible() then
		Aux.buy.toggle_tooltip_dropdown()
	end
	Aux.buy.toggle_tooltip_dropdown()
end

function AuxBuyTooltipRemoveButton_OnClick()
	Aux.util.set_remove(tooltip_patterns, AuxBuyTooltipInputBox:GetText())
	AuxBuyTooltipInputBox:SetText('')
	if DropDownList1:IsVisible() then
		Aux.buy.toggle_tooltip_dropdown()
	end
	Aux.buy.toggle_tooltip_dropdown()
end

function AuxBuyTooltipDropDown_Initialize()
	for pattern, _ in tooltip_patterns do
		UIDropDownMenu_AddButton{
			text = pattern,
			value = pattern,
			func = AuxBuyTooltipDropDown_OnClick,
		}
	end
end

function AuxBuyTooltipDropDown_OnClick()
	Aux.util.set_remove(tooltip_patterns, this.value)
end

function Aux.buy.toggle_tooltip_dropdown()
	ToggleDropDownMenu(1, nil, AuxBuyTooltipDropDown, AuxBuyTooltipInputBox, -12, 4)
end
