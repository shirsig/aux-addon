Aux.buy = {}

local create_auction_record, show_dialog, find_auction, hide_sheet, update_sheet, auction_alpha_setter, group_alpha_setter
local auctions
local selectedAuctions = {}
local search_query
local tooltip_patterns = {}
local current_page
local refresh

function auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function group_alpha_setter(cell, group)
    cell:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
end

local BUYOUT, BID, FULL = 1, 2, 3

Aux.buy.modes = {
	[BUYOUT] = {
		name = 'Buyout',
        on_cell_click = function (sheet, row_index, column_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            AuxBuyEntry_OnClick(Aux.util.filter(sheet.data[data_index], function(auction) return not auction.gone end)[1] or sheet.data[data_index][1])
        end,

        on_cell_enter = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
        end,

        on_cell_leave = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
        end,
        columns = {
            {
                title = 'Avail',
                width = 40,
                comparator = function(group1, group2) return Aux.util.compare(getn(Aux.util.filter(group1, function(auction) return not auction.gone end)), getn(Aux.util.filter(group2, function(auction) return not auction.gone end)), Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(getn(Aux.util.filter(group, function(auction) return not auction.gone end)))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Auction Item',
                width = 312,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].name, group2[1].name, Aux.util.GT) end,
                cell_initializer = function(cell)
                    local icon = CreateFrame('Button', nil, cell)
                    local icon_texture = icon:CreateTexture(nil, 'BORDER')
                    icon_texture:SetAllPoints(icon)
                    icon.icon_texture = icon_texture
                    local normal_texture = icon:CreateTexture(nil)
                    normal_texture:SetPoint('CENTER', 0, 0)
                    normal_texture:SetWidth(22)
                    normal_texture:SetHeight(22)
                    normal_texture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetNormalTexture(normal_texture)
                    icon:SetPoint('LEFT', cell)
                    icon:SetWidth(12)
                    icon:SetHeight(12)
                    icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                    icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                    icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_RIGHT', cell.EnhTooltip_info) end)
                    icon:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                    text:SetPoint('TOPRIGHT', cell)
                    text:SetPoint('BOTTOMRIGHT', cell)
                    text:SetJustifyV('TOP')
                    text:SetJustifyH('LEFT')
                    text:SetTextColor(0.8, 0.8, 0.8)
                    cell.text = text
                    cell.icon = icon
                end,
                cell_setter = function(cell, group)
                    cell.tooltip = group[1].tooltip
                    cell.EnhTooltip_info = group[1].EnhTooltip_info
                    cell.icon.icon_texture:SetTexture(group[1].texture)
                    if not group[1].usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..group[1].tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[group[1].quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Qty',
                width = 23,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].stack_size, group2[1].stack_size, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].stack_size)
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Buy/ea',
                width = 110,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price_per_unit, group2[1].buyout_price_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price_per_unit))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Buy',
                width = 110,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price, group2[1].buyout_price, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price))
                    group_alpha_setter(cell, group)
                end,
            },
        },
        sort_order = {{column = 2, order = 'ascending' }, {column = 4, order = 'ascending'}},
	},
	[BID] = {
		name = 'Bid',
        on_cell_click = function (sheet, row_index, column_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            AuxBuyEntry_OnClick(sheet.data[data_index])
        end,

        on_cell_enter = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
        end,

        on_cell_leave = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
        end,
        columns = {
            {
                title = 'Page',
                width = 40,
                comparator = function(row1, row2) return Aux.util.compare(row1.page, row2.page, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.page)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Auction Item',
                width = 206,
                comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
                cell_initializer = function(cell)
                    local icon = CreateFrame('Button', nil, cell)
                    local icon_texture = icon:CreateTexture(nil, 'BORDER')
                    icon_texture:SetAllPoints(icon)
                    icon.icon_texture = icon_texture
                    local normal_texture = icon:CreateTexture(nil)
                    normal_texture:SetPoint('CENTER', 0, 0)
                    normal_texture:SetWidth(22)
                    normal_texture:SetHeight(22)
                    normal_texture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetNormalTexture(normal_texture)
                    icon:SetPoint('LEFT', cell)
                    icon:SetWidth(12)
                    icon:SetHeight(12)
                    icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                    icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                    icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_RIGHT', cell.EnhTooltip_info) end)
                    icon:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                    text:SetPoint('TOPRIGHT', cell)
                    text:SetPoint('BOTTOMRIGHT', cell)
                    text:SetJustifyV('TOP')
                    text:SetJustifyH('LEFT')
                    text:SetTextColor(0.8, 0.8, 0.8)
                    cell.text = text
                    cell.icon = icon
                end,
                cell_setter = function(cell, datum)
                    cell.tooltip = datum.tooltip
                    cell.EnhTooltip_info = datum.EnhTooltip_info
                    cell.icon.icon_texture:SetTexture(datum.texture)
                    if not datum.usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..datum.tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[datum.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Left',
                width = 30,
                comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, datum)
                    local text
                    if datum.duration == 1 then
                        text = '30m'
                    elseif datum.duration == 2 then
                        text = '2h'
                    elseif datum.duration == 3 then
                        text = '8h'
                    elseif datum.duration == 4 then
                        text = '24h'
                    end
                    cell.text:SetText(text)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Status',
                width = 70,
                comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, auction)
                    cell.text:SetText(auction.status)
                    auction_alpha_setter(cell, auction)
                end,
            },
            {
                title = 'Qty',
                width = 23,
                comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.stack_size)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid/ea',
                width = 110,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid',
                width = 110,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid))
                    auction_alpha_setter(cell, datum)
                end,
            },
        },
        sort_order = {{column = 2, order = 'ascending' }, {column = 6, order = 'ascending' }, {column = 3, order = 'ascending'}},
	},
	[FULL] = {
		name = 'Full',
        on_cell_click = function (sheet, row_index, column_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            AuxBuyEntry_OnClick(sheet.data[data_index])
        end,

        on_cell_enter = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
        end,

        on_cell_leave = function (sheet, row_index, column_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
        end,
		columns = {
            {
                title = 'Qty',
                width = 23,
                comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.stack_size)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Auction Item',
                width = 157,
                comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
                cell_initializer = function(cell)
                    local icon = CreateFrame('Button', nil, cell)
                    local icon_texture = icon:CreateTexture(nil, 'BORDER')
                    icon_texture:SetAllPoints(icon)
                    icon.icon_texture = icon_texture
                    local normal_texture = icon:CreateTexture(nil)
                    normal_texture:SetPoint('CENTER', 0, 0)
                    normal_texture:SetWidth(22)
                    normal_texture:SetHeight(22)
                    normal_texture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetNormalTexture(normal_texture)
                    icon:SetPoint('LEFT', cell)
                    icon:SetWidth(12)
                    icon:SetHeight(12)
                    icon:SetNormalTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
                    icon:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
                    icon:SetScript('OnEnter', function() Aux.info.set_game_tooltip(this, cell.tooltip, 'ANCHOR_RIGHT', cell.EnhTooltip_info) end)
                    icon:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                    text:SetPoint('TOPRIGHT', cell)
                    text:SetPoint('BOTTOMRIGHT', cell)
                    text:SetJustifyV('TOP')
                    text:SetJustifyH('LEFT')
                    text:SetTextColor(0.8, 0.8, 0.8)
                    cell.text = text
                    cell.icon = icon
                end,
                cell_setter = function(cell, datum)
                    cell.tooltip = datum.tooltip
                    cell.EnhTooltip_info = datum.EnhTooltip_info
                    cell.icon.icon_texture:SetTexture(datum.texture)
                    if not datum.usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..datum.tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[datum.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Lvl',
                width = 23,
                comparator = function(row1, row2) return Aux.util.compare(row1.level, row2.level, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    local level = max(1, datum.level)
                    local text
                    if level > UnitLevel('player') then
                        text = RED_FONT_COLOR_CODE..level..FONT_COLOR_CODE_CLOSE
                    else
                        text = level
                    end
                    cell.text:SetText(text)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Left',
                width = 30,
                comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, datum)
                    local text
                    if datum.duration == 1 then
                        text = '30m'
                    elseif datum.duration == 2 then
                        text = '2h'
                    elseif datum.duration == 3 then
                        text = '8h'
                    elseif datum.duration == 4 then
                        text = '24h'
                    end
                    cell.text:SetText(text)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Owner',
                width = 70,
                comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.owner)
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid/ea',
                width = 70,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid_per_unit, row2.bid_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid_per_unit))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Buy/ea',
                width = 70,
                comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price_per_unit, row2.buyout_price_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.buyout_price_per_unit))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Bid',
                width = 70,
                comparator = function(row1, row2) return Aux.util.compare(row1.bid, row2.bid, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.bid))
                    auction_alpha_setter(cell, datum)
                end,
            },
            {
                title = 'Buy',
                width = 70,
                comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                    auction_alpha_setter(cell, datum)
                end,
            },
        },
        sort_order = {},
	},
}

function Aux.buy.exit()
	Aux.buy.dialog_cancel()
	current_page = nil
end

function Aux.buy.on_open()
	update_sheet()
end

function Aux_AuctionFrameBid_Update()
	Aux.orig.AuctionFrameBid_Update()
	if PanelTemplates_GetSelectedTab(AuctionFrame) == Aux.tabs.buy.index and AuctionFrame:IsShown() then
		Aux_HideElems(Aux.tabs.buy.hiddenElements)
	end
end

function Aux.buy.dialog_cancel()
	Aux.scan.abort()
	AuxBuyConfirmation:Hide()
	update_sheet()
	AuxBuySearchButton:Enable()
end

function Aux.buy.StopButton_onclick()
	Aux.scan.abort()
end

function update_sheet()
	AuxBuyBuyList:Hide()
	AuxBuyBidList:Hide()
	AuxBuyFullList:Hide()
	
    local mode = UIDropDownMenu_GetSelectedValue(AuxBuyModeDropDown)
    if mode == BUYOUT then
		AuxBuyBuyList:Show()
	elseif mode == BID then
		AuxBuyBidList:Show()
	elseif mode == FULL then
		AuxBuyFullList:Show()
	end
	
    local mode = UIDropDownMenu_GetSelectedValue(AuxBuyModeDropDown)
    if mode == BUYOUT then
		local buyout_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
		Aux.list.populate(AuxBuyBuyList.sheet, auctions and Aux.util.group_by(buyout_auctions, function(a1, a2) return a1.hyperlink == a2.hyperlink and a1.stack_size == a2.stack_size and a1.buyout_price == a2.buyout_price end) or {})
	elseif mode == BID then
		local bid_auctions = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') end) or {}
		Aux.list.populate(AuxBuyBidList.sheet, bid_auctions)
	elseif mode == FULL then
		Aux.list.populate(AuxBuyFullList.sheet, auctions or {})
	end
end

function hide_sheet()
	AuxBuyBuyList:Hide()
	AuxBuyBidList:Hide()
	AuxBuyFullList:Hide()
end

function Aux.buy.SearchButton_onclick()

	if not AuxBuySearchButton:IsVisible() then
		return
	end
	
	AuxBuySearchButton:Hide()
	AuxBuyStopButton:Show()
	
	auctions = nil
	selectedAuctions = {}
	
	refresh = true
	
	local category = UIDropDownMenu_GetSelectedValue(AuxBuyCategoryDropDown)
	local tooltip_patterns = Aux.util.set_to_array(tooltip_patterns)
	
	search_query = {
		name = AuxBuyNameInputBox:GetText(),
		min_level = AuxBuyMinLevel:GetText(),
		max_level = AuxBuyMaxLevel:GetText(),
		slot = category and category.slot,
		class = category and category.class,	
		subclass = category and category.subclass,
		quality = UIDropDownMenu_GetSelectedValue(AuxBuyQualityDropDown),
		usable = AuxBuyUsableCheckButton:GetChecked()
	}
	
	Aux.log('Starting scan')
	Aux.scan.start{
		query = search_query,
		page = AuxBuyAllPagesCheckButton:GetChecked() and 0 or AuxBuyPageEditBox:GetNumber(),
		on_submit_query = function()
			current_page = nil
		end,
		on_page_loaded = function(page)
			current_page = page
		end,
		on_start_page = function(page, total_pages)
			Aux.log('Scanning page ' .. page + 1 .. (total_pages > 0 and ' out of ' .. total_pages or ''))
		end,
		on_read_auction = function(i)
			local auction_item = Aux.info.auction_item(i)
			if auction_item then
				if (auction_item.name == search_query.name or search_query.name == '' or not AuxBuyExactCheckButton:GetChecked()) and Aux.info.tooltip_match(tooltip_patterns, auction_item.tooltip) then
                    auctions = auctions or {}
                    tinsert(auctions, create_auction_record(auction_item, current_page))
				end
			end
		end,
		on_complete = function()
			auctions = auctions or {}
            Aux.log('Scan completed: '..getn(auctions)..' auctions found')
			AuxBuyStopButton:Hide()
			AuxBuySearchButton:Show()
			refresh = true
		end,
		on_abort = function()
			auctions = auctions or {}
            Aux.log('Scan aborted: '..getn(auctions)..' auctions found')
			AuxBuyStopButton:Hide()
			AuxBuySearchButton:Show()
			refresh = true
		end,
		next_page = function(page, total_pages)
            if AuxBuyAllPagesCheckButton:GetChecked() then
                local last_page = max(total_pages - 1, 0)
                if page < last_page then
                    return page + 1
                end
            end
		end,
	}
end

function show_dialog(buyout_mode, entry, amount)
	AuxBuyConfirmation.tooltip = entry.tooltip
	AuxBuyConfirmation.EnhTooltip_info = entry.EnhTooltip_info
	
	AuxBuyConfirmationActionButton:Disable()
	AuxBuyConfirmationItem:SetNormalTexture(entry.texture)
	AuxBuyConfirmationItemName:SetText(entry.name)
	local color = ITEM_QUALITY_COLORS[entry.quality]
	AuxBuyConfirmationItemName:SetTextColor(color.r, color.g, color.b)

	if entry.stack_size > 1 then
		AuxBuyConfirmationItemCount:SetText(entry.stack_size);
		AuxBuyConfirmationItemCount:Show()
	else
		AuxBuyConfirmationItemCount:Hide()
	end
	if buyout_mode then
		AuxBuyConfirmationActionButton:SetText('Buy')
		MoneyFrame_Update('AuxBuyConfirmationBuyoutPrice', amount)
		AuxBuyConfirmationBid:Hide()
		AuxBuyConfirmationBuyoutPrice:Show()
	else
		AuxBuyConfirmationActionButton:SetText('Bid')
		MoneyInputFrame_SetCopper(AuxBuyConfirmationBid, amount)
		AuxBuyConfirmationBuyoutPrice:Hide()
		AuxBuyConfirmationBid:Show()
	end
	hide_sheet()
	AuxBuyConfirmation:Show()
end

function find_auction(entry, buyout_mode, express_mode)

	if entry.gone then
        Aux.log('Auction not available')
		return
	end
	
	if buyout_mode and not entry.buyout_price then
        Aux.log('Auction has no buyout price')
		return
	end

    Aux.log('Processing '..(buyout_mode and 'buyout' or 'bid')..' request')
	AuxBuySearchButton:Disable()
	
	local amount
	if buyout_mode then
		amount = entry.buyout_price
	else
		amount = entry.bid
	end
	
	if not express_mode then
		show_dialog(buyout_mode, entry, amount)
	end

	PlaySound('igMainMenuOptionCheckBoxOn')
	
	local found
	
	Aux.scan.start{
		query = search_query,
		page = entry.page ~= current_page and entry.page,
		on_submit_query = function()
			current_page = nil
		end,
		on_page_loaded = function(page)
			current_page = page
		end,
		on_read_auction = function(i, ctrl)
			local auction_item = Aux.info.auction_item(i)
			
			if not auction_item then
				return
			end
			
			local stack_size = auction_item.charges or auction_item.count
			local bid = (auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid) + auction_item.min_increment
			
			local signature = Aux.auction_signature(auction_item.hyperlink, stack_size, bid, auction_item.buyout_price)
			
			if entry.signature == signature then
				ctrl.suspend()
				found = true
                Aux.log('Matching auction found')
				
				if express_mode then
					if GetMoney() >= amount then
						PlaceAuctionBid("list", i, amount)
                        Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..entry.hyperlink..' x '..entry.stack_size)
						entry.gone = true
						refresh = true
					else
						Aux.log('Not enough money.')
					end
					Aux.scan.abort()
				else
					Aux.buy.dialog_action = function()						
						if GetMoney() >= amount then
							PlaceAuctionBid("list", i, amount)
                            Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..entry.hyperlink..' x '..entry.stack_size)
                            entry.gone = true
							refresh = true
						else
							Aux.log('Not enough money.')
						end				
						Aux.scan.abort()
						AuxBuySearchButton:Enable()
						AuxBuyConfirmation:Hide()
						update_sheet()
					end
					AuxBuyConfirmationActionButton:Enable()
				end
			end
		end,
		on_complete = function()
			if not found then
				entry.gone = true
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
		next_page = function(page, total_pages)
			if not page or page == entry.page then
				return entry.page - 1
			end
		end,
	}
end

function AuxBuyEntry_OnClick(entry)

	local express_mode = IsAltKeyDown()
	local buyout_mode = arg1 == 'LeftButton'
	
	if IsControlKeyDown() then 
		DressUpItemLink(entry.hyperlink)
	else
		find_auction(entry, buyout_mode, express_mode)
	end	
end

function create_auction_record(auction_item, current_page)
	
	local stack_size = auction_item.charges or auction_item.count
	local bid = (auction_item.current_bid > 0 and auction_item.current_bid or auction_item.min_bid) + auction_item.min_increment
	local buyout_price = auction_item.buyout_price > 0 and auction_item.buyout_price or nil
	local buyout_price_per_unit = buyout_price and Aux_Round(auction_item.buyout_price/stack_size)
    local status
    if auction_item.current_bid == 0 then
        status = 'No Bid'
    elseif auction_item.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE .. 'Other Bidder'..FONT_COLOR_CODE_CLOSE
    end

    return {
            signature = Aux.auction_signature(auction_item.hyperlink, stack_size, bid, auction_item.buyout_price),

            name = auction_item.name,
            level = auction_item.level,
            texture = auction_item.texture,
            tooltip = auction_item.tooltip,
            stack_size = stack_size,
            buyout_price = buyout_price,
            buyout_price_per_unit = buyout_price_per_unit,
            quality = auction_item.quality,
            hyperlink = auction_item.hyperlink,
            itemstring = auction_item.itemstring,
            page = current_page,
            bid = bid,
            bid_per_unit = Aux_Round(bid/stack_size),
            owner = auction_item.owner,
            duration = auction_item.duration,
            usable = auction_item.usable,
            high_bidder = auction_item.high_bidder,
            status = status,

            EnhTooltip_info = auction_item.EnhTooltip_info,
    }
end

function Aux.buy.onupdate()
	if refresh then
		refresh = false
		update_sheet()
	end
end

function AuxBuyCategoryDropDown_Initialize(arg1)
	local level = arg1 or 1
	
	if level == 1 then
		local value = {}
		UIDropDownMenu_AddButton({
			text = ALL,
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

function AuxBuyQualityDropDown_Initialize()

	UIDropDownMenu_AddButton{
		text = ALL,
		value = -1,
		func = AuxBuyQualityDropDown_OnClick,
	}
	for i=0,getn(ITEM_QUALITY_COLORS)-2 do
		UIDropDownMenu_AddButton{
			text = getglobal("ITEM_QUALITY"..i.."_DESC"),
			value = i,
			func = function()
				UIDropDownMenu_SetSelectedValue(AuxBuyQualityDropDown, this.value)
			end,
		}
	end
end

function AuxBuyTooltipButton_OnClick()
	local pattern = AuxBuyTooltipInputBox:GetText()
	if pattern ~= '' then
		Aux.util.set_add(tooltip_patterns, pattern)
		if DropDownList1:IsVisible() then
			Aux.buy.toggle_tooltip_dropdown()
		end
		Aux.buy.toggle_tooltip_dropdown()
	end
	AuxBuyTooltipInputBox:SetText('')
end

function AuxBuyTooltipDropDown_Initialize()
	for pattern, _ in tooltip_patterns do
		UIDropDownMenu_AddButton{
			text = pattern,
			value = pattern,
			func = AuxBuyTooltipDropDown_OnClick,
			notCheckable = true,
		}
	end
end

function AuxBuyTooltipDropDown_OnClick()
	Aux.util.set_remove(tooltip_patterns, this.value)
end

function Aux.buy.toggle_tooltip_dropdown()
	ToggleDropDownMenu(1, nil, AuxBuyTooltipDropDown, AuxBuyTooltipInputBox, -12, 4)
end

function AuxBuyModeDropDown_Initialize()

	for i, mode in ipairs(Aux.buy.modes) do
		UIDropDownMenu_AddButton{
			text = mode.name,
			value = i,
			func = function()
				UIDropDownMenu_SetSelectedValue(AuxBuyModeDropDown, this.value)
				update_sheet()
			end,
		}
	end
end
