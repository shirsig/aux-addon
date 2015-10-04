Aux.buy = {}

local process_auction, set_message, report, tooltip_match, show_dialog
local entries
local selectedEntries = {}
local search_query
local tooltip_patterns = {}
local current_page
local refresh


function Aux.buy.exit()
	Aux.buy.dialog_cancel()
	current_page = nil
end

-----------------------------------------

function Aux_AuctionFrameBid_Update()
	Aux.orig.AuctionFrameBid_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
	end
end

-----------------------------------------

function Aux.buy.dialog_cancel()
	Aux.scan.abort()
	AuxBuyDialog:Hide()
	AuxBuySearchButton:Enable()
end

-----------------------------------------

function Aux.buy.StopButton_onclick()
	Aux.scan.abort()
end

-----------------------------------------

function Aux.buy.SearchButton_onclick()

	if not AuxBuySearchButton:IsVisible() then
		return
	end
	
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
		page = 0,
		on_start_page = function(ok, page, total_pages)
			current_page = page
			set_message('Scanning auctions: page ' .. page + 1 .. (total_pages and ' out of ' .. total_pages or '') .. ' ...')
			return ok()
		end,
		on_read_auction = function(ok, i)
			local auction_item = Aux.info.auction_item(i)
			if auction_item then
				if (auction_item.name == search_query.name or search_query.name == '' or not AuxBuyExactCheckButton:GetChecked()) and tooltip_match(tooltip_patterns, auction_item.tooltip) then
					process_auction(auction_item, current_page)
				end
			end
			return ok()
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
		next_page = function(page, total_pages)
			local last_page = max(total_pages - 1, 0)
			if page < last_page then
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

function show_dialog(buyout_mode, hyperlink, stack_size, amount)
	AuxBuyDialogActionButton:Disable()
	AuxBuyDialogHTML:SetFontObject('h1', GameFontWhite)
	AuxBuyDialogHTML:SetScript('OnHyperlinkClick', function() SetItemRef(arg1) end)
	AuxBuyDialogHTML:SetText(string.format(
			[[
			<html>
			<body>
				<h1>%s x %i</h1>
			</body>
			</html>
			]],
			hyperlink,
			stack_size
	))
	if buyout_mode then
		AuxBuyDialogActionButton:SetText('Buy')
		MoneyFrame_Update('AuxBuyDialogBuyoutPrice', amount)
		AuxBuyDialogBid:Hide()
		AuxBuyDialogBuyoutPrice:Show()
	else
		AuxBuyDialogActionButton:SetText('Bid')
		MoneyInputFrame_SetCopper(AuxBuyDialogBid, amount)
		AuxBuyDialogBuyoutPrice:Hide()
		AuxBuyDialogBid:Show()
	end
	AuxBuyDialog:Show()
end

-----------------------------------------

function AuxBuyEntry_OnClick(entry_index)
	local express_mode = IsAltKeyDown()
	local buyout_mode = arg1 == "LeftButton"
	
	local entry = entries[entry_index]
	
	if buyout_mode and not entry.buyout_price then
		return
	end
	
	if IsControlKeyDown() then 
		DressUpItemLink(entry.hyperlink)
		return
	end
	
	AuxBuySearchButton:Disable()
	
	local amount
	if buyout_mode then
		amount = entry.buyout_price
	else
		amount = entry.bid
	end
	
	if not express_mode then
		show_dialog(buyout_mode, entry.hyperlink, entry.stack_size, amount)
	end

	PlaySound("igMainMenuOptionCheckBoxOn")
	
	local found
	local order_key = Aux.auction_key(entry.tooltip, entry.stack_size, amount)
	
	Aux.scan.start{
		query = search_query,
		page = entry.page ~= current_page and entry.page,
		on_start_page = function(ok, page)
			current_page = page
			return ok()
		end,
		on_read_auction = function(ok, i)
			local auction_item = Aux.info.auction_item(i)
			
			if not auction_item then
				return ok()
			end
			
			local stack_size = auction_item.charges or auction_item.count
			local bid = (auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid) + auction_item.min_increment

			local auction_amount
			if buyout_mode then
				auction_amount = auction_item.buyout_price
			else
				auction_amount = bid
			end
			
			local key = Aux.auction_key(auction_item.tooltip, stack_size, auction_amount)
			
			if key == order_key then
				found = true
				
				if express_mode then
					if GetMoney() >= amount then
						tremove(entries, entry_index)
						refresh = true
					end
					
					PlaceAuctionBid("list", i, amount)				
					
					Aux.scan.abort()
				else
					Aux.buy.dialog_action = function()						
						if GetMoney() >= amount then
							tremove(entries, entry_index)
							refresh = true
						end
						
						PlaceAuctionBid("list", i, amount)
					
						Aux.scan.abort()
						AuxBuySearchButton:Enable()
						AuxBuyDialog:Hide()
					end
					AuxBuyDialogActionButton:Enable()
				end
			else
				return ok()
			end
		end,
		on_complete = function()
			if not found then
				tremove(entries, entry_index)
				refresh = true
				Aux.buy.dialog_cancel()
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

function AuxBuyEntry_OnEnter(entry_index)
	local entry = entries[entry_index]
	
	Aux.info.set_game_tooltip(this, entry.tooltip)
	
	if(EnhTooltip ~= nil) then
		EnhTooltip.TooltipCall(GameTooltip, entry.name, entry.hyperlink, entry.quality, entry.stack_size)
	end
end

-----------------------------------------

function process_auction(auction_item, current_page)
	entries = entries or {}
	
	local stack_size = auction_item.charges or auction_item.count
	local bid = auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid + auction_item.min_increment
	local buyout_price = auction_item.buyout_price > 0 and auction_item.buyout_price or nil
	local buyout_price_per_unit = buyout_price and Aux_Round(auction_item.buyout_price / stack_size)
	
	if auction_item.owner ~= UnitName("player") then
		tinsert(entries, {
				name = auction_item.name,
				tooltip = auction_item.tooltip,
				stack_size = stack_size,
				buyout_price = buyout_price,
				buyout_price_per_unit = buyout_price_per_unit,
				quality = auction_item.quality,
				hyperlink = auction_item.hyperlink,
				itemstring = auction_item.itemstring,
				page = current_page,
				bid = bid,
				bid_per_unit = Aux_Round(bid / stack_size),
				owner = auction_item.owner,
				duration = auction_item.duration,
		})
	end
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
	Aux.list.populate(AuxBuyList, entries or {})
	
	-- if entries then
		-- table.sort(entries, function(a,b) return a.buyout_price_per_unit < b.buyout_price_per_unit end)
	-- end
	
	if entries and getn(entries) == 0 then
		set_message("No auctions were found")
	else
		AuxBuyMessage:Hide()
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
