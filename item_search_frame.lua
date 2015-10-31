local private, public = {}, {}
Aux.item_search_frame = public

local create_auction_record, show_dialog, find_auction, hide_sheet, update_listing, auction_alpha_setter, group_alpha_setter, create_auction_record
local auctions
local search_query
local tooltip_patterns = {}
local current_page
local refresh
local recently_searched = {}

function auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function group_alpha_setter(cell, group)
    cell:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
end

local BUYOUT, BID, FULL = 1, 2, 3

public.recently_searched_config = {
    on_row_click = function (sheet, row_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        public.set_item(sheet.data[data_index].item_id)
    end,
    on_row_enter = function (sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,
    on_row_leave = function (sheet, row_index)
        sheet.rows[row_index].highlight:SetAlpha(0)
    end,
    columns = {
        {
            title = 'Item',
            width = 163,
            comparator = function(datum1, datum2)
                return Aux.util.compare(datum1.time, datum2.time, Aux.util.GT)
            end,
            cell_initializer = function(cell)
                local icon = CreateFrame('Button', nil, cell)
                icon:EnableMouse(false)
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
                local info = { GetItemInfo(datum.item_id) }
                cell.icon.icon_texture:SetTexture(info[9])
                cell.text:SetText('['..info[1]..']')
                local color = ITEM_QUALITY_COLORS[info[3]]
                cell.text:SetTextColor(color.r, color.g, color.b)
            end,
        },
    },
    sort_order = {},
}
public.views = {
	[BUYOUT] = {
		name = 'Buyout',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(Aux.util.filter(sheet.data[data_index], function(auction) return not auction.gone end)[1] or sheet.data[data_index][1])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_game_tooltip(this, sheet.rows[row_index].tooltip, 'ANCHOR_CURSOR', sheet.rows[row_index].EnhTooltip_info)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
            GameTooltip:Hide()
        end,
        row_setter = function(row, group)
            row.tooltip = group[1].tooltip
            row.EnhTooltip_info = group[1].EnhTooltip_info
        end,
        columns = {
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
                title = 'Buy',
                width = 93,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price, group2[1].buyout_price, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price))
                    group_alpha_setter(cell, group)
                end,
            },
            {
                title = 'Buy/ea',
                width = 93,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].buyout_price_per_unit, group2[1].buyout_price_per_unit, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(Aux.util.money_string(group[1].buyout_price_per_unit))
                    group_alpha_setter(cell, group)
                end,
            },
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
        },
        sort_order = {{column = 3, order = 'ascending' }},
	},
	[BID] = {
		name = 'Bid',
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_game_tooltip(this, sheet.rows[row_index].tooltip, 'ANCHOR_CURSOR', sheet.rows[row_index].EnhTooltip_info)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
            GameTooltip:Hide()
        end,
        row_setter = function(row, datum)
            row.tooltip = datum.tooltip
            row.EnhTooltip_info = datum.EnhTooltip_info
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
        on_row_click = function (sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            public.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(.5)
            Aux.info.set_game_tooltip(this, sheet.rows[row_index].tooltip, 'ANCHOR_CURSOR', sheet.rows[row_index].EnhTooltip_info)
        end,
        on_row_leave = function (sheet, row_index)
            sheet.rows[row_index].highlight:SetAlpha(0)
            GameTooltip:Hide()
        end,
        row_setter = function(row, datum)
            row.tooltip = datum.tooltip
            row.EnhTooltip_info = datum.EnhTooltip_info
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

function public.on_close()
    if AuxItemSearchFrameAuctionsConfirmation:IsVisible() then
	    public.dialog_cancel()
    end
	current_page = nil
end

function public.on_open()
    public.set_view(1)
    public.update_item()
    private.update_recently_searched()
	update_listing()
end

function public.dialog_cancel()
    Aux.log('Canceled.')
	Aux.scan.abort()
    AuxItemSearchFrameAuctionsConfirmation:Hide()
	update_listing()
    AuxItemSearchFrameItemSearchButton:Enable()
end

function public.stop_search()
	Aux.scan.abort()
end

function update_listing()
	AuxItemSearchFrameAuctionsBuyListing:Hide()
    AuxItemSearchFrameAuctionsBidListing:Hide()
    AuxItemSearchFrameAuctionsFullListing:Hide()

    if private.view == BUYOUT then
		AuxItemSearchFrameAuctionsBuyListing:Show()
        local buy_records = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
        Aux.list.populate(AuxItemSearchFrameAuctionsBuyListing.sheet, auctions and Aux.util.group_by(buy_records, function(a1, a2) return a1.hyperlink == a2.hyperlink and a1.stack_size == a2.stack_size and a1.buyout_price == a2.buyout_price end) or {})
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsBuyListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 20)
	elseif private.view == BID then
		AuxItemSearchFrameAuctionsBidListing:Show()
        local bid_records = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') end) or {}
        Aux.list.populate(AuxItemSearchFrameAuctionsBidListing.sheet, bid_records)
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsBidListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 20)
	elseif private.view == FULL then
		AuxItemSearchFrameAuctionsFullListing:Show()
        Aux.list.populate(AuxItemSearchFrameAuctionsFullListing.sheet, auctions or {})
        AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsFullListing:GetWidth() + 40)
        AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 20)
	end
end

function hide_sheet()
	AuxItemSearchFrameAuctionsBuyListing:Hide()
	AuxItemSearchFrameAuctionsBidListing:Hide()
	AuxItemSearchFrameAuctionsFullListing:Hide()
end

function public.set_view(view)
    for i=1,3 do
        getglobal('AuxItemSearchFrameAuctionsTab'..i):SetAlpha(i == view and 1 or 0.5)
    end
    private.view = view
    update_listing()
end

function private.update_recently_searched()
    Aux.list.populate(AuxItemSearchFrameRecentlySearchedListing.sheet, recently_searched)
end

function public.set_item(item_id)
    if item_id ~= private.item_id then
        private.item_id = item_id
        public.update_item()
        tinsert(recently_searched, 1, { item_id=item_id, time=time() })
        private.update_recently_searched()
        public.start_search()
    end
end

function public.update_item()
    if private.item_id and not AuxItemSearchFrameItemItemInputBox:IsVisible() then
        local info = { GetItemInfo(private.item_id) }
        AuxItemSearchFrameItemItemIconTexture:SetTexture(info[9])
        AuxItemSearchFrameItemItemName:SetText(info[1])
        local color = ITEM_QUALITY_COLORS[info[3]]
        AuxItemSearchFrameItemItemName:SetTextColor(color.r, color.g, color.b)
        AuxItemSearchFrameItemItem:Show()
        AuxItemSearchFrameItemItemInputBox:Hide()
    else
        AuxItemSearchFrameItemItem:Hide()
    end
end

function public.start_search()

	if not AuxItemSearchFrameItemSearchButton:IsVisible() then
		return
	end
	
	AuxItemSearchFrameItemSearchButton:Hide()
	AuxItemSearchFrameItemStopButton:Show()
	
	auctions = nil
	
	refresh = true

    local name = GetItemInfo(private.item_id)
	
	search_query = {
		name = name,
--		min_level = AuxBuyMinLevel:GetText(),
--		max_level = AuxBuyMaxLevel:GetText(),
--		slot = category and category.slot,
--		class = category and category.class,
--		subclass = category and category.subclass,
--		quality = UIDropDownMenu_GetSelectedValue(AuxBuyQualityDropDown),
--		usable = AuxBuyUsableCheckButton:GetChecked()
	}
	
	Aux.log('Scanning auctions ...')
	Aux.scan.start{
		query = search_query,
		page = AuxItemSearchFrameItemAllPagesCheckButton:GetChecked() and 0 or AuxItemSearchFrameItemPageEditBox:GetNumber(),
		on_submit_query = function()
			current_page = nil
		end,
		on_page_loaded = function(page, total_pages)
            Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
            current_page = page
		end,
		on_read_auction = function(i)
			local auction_item = Aux.info.auction_item(i)
			if auction_item then
				if auction_item.name == search_query.name then
                    auctions = auctions or {}
                    tinsert(auctions, create_auction_record(auction_item, current_page))
				end
			end
		end,
		on_complete = function()
			auctions = auctions or {}
            Aux.log('Scan complete: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')

            AuxItemSearchFrameItemStopButton:Hide()
			AuxItemSearchFrameItemSearchButton:Show()
			refresh = true
		end,
		on_abort = function()
			auctions = auctions or {}
            Aux.log('Scan aborted: '..getn(auctions)..' '..Aux_PluralizeIf('auction', getn(auctions))..' found.')
			AuxItemSearchFrameItemStopButton:Hide()
			AuxItemSearchFrameItemSearchButton:Show()
			refresh = true
		end,
		next_page = function(page, total_pages)
            if AuxItemSearchFrameItemAllPagesCheckButton:GetChecked() then
                local last_page = max(total_pages - 1, 0)
                if page < last_page then
                    return page + 1
                end
            end
		end,
	}
end

function show_dialog(buyout_mode, entry, amount)
	AuxItemSearchFrameAuctionsConfirmationContentItem.tooltip = entry.tooltip
    AuxItemSearchFrameAuctionsConfirmationContentItem.EnhTooltip_info = entry.EnhTooltip_info

    AuxItemSearchFrameAuctionsConfirmationContentActionButton:Disable()
    AuxItemSearchFrameAuctionsConfirmationContentItemIconTexture:SetTexture(entry.texture)
    AuxItemSearchFrameAuctionsConfirmationContentItemName:SetText(entry.tooltip[1][1].text)
	local color = ITEM_QUALITY_COLORS[entry.quality]
    AuxItemSearchFrameAuctionsConfirmationContentItemName:SetTextColor(color.r, color.g, color.b)

	if entry.stack_size > 1 then
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:SetText(entry.stack_size);
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:Show()
	else
        AuxItemSearchFrameAuctionsConfirmationContentItemCount:Hide()
	end
	if buyout_mode then
        AuxItemSearchFrameAuctionsConfirmationContentActionButton:SetText('Buy')
		MoneyFrame_Update('AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice', amount)
        AuxItemSearchFrameAuctionsConfirmationContentBid:Hide()
        AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice:Show()
	else
        AuxItemSearchFrameAuctionsConfirmationContentActionButton:SetText('Bid')
		MoneyInputFrame_SetCopper(AuxItemSearchFrameAuctionsConfirmationContentBid, amount)
        AuxItemSearchFrameAuctionsConfirmationContentBuyoutPrice:Hide()
        AuxItemSearchFrameAuctionsConfirmationContentBid:Show()
	end
    AuxItemSearchFrameAuctionsConfirmation:Show()
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

    local amount
    if buyout_mode then
        amount = entry.buyout_price
    else
        amount = entry.bid
    end

    Aux.log('Processing '..(buyout_mode and 'buyout' or 'bid')..' request for '..entry.hyperlink..' x '..entry.stack_size..' at '..Aux.util.money_string(amount)..' ...')
	AuxItemSearchFrameItemSearchButton:Disable()
	
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
                Aux.log('Matching auction found.'..(express_mode and '' or ' Awaiting confirmation ...'))
				
				if express_mode then
					if GetMoney() >= amount then
						PlaceAuctionBid("list", i, amount)
                        Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..entry.hyperlink..' x '..entry.stack_size..' at '..Aux.util.money_string(amount)..'.')
						entry.gone = true
						refresh = true
					else
						Aux.log((buyout_mode and 'Purchase' or 'Bid')..' failed: Not enough money.')
					end
					Aux.scan.abort()
				else
					Aux.buy.dialog_action = function()						
						if GetMoney() >= amount then
							PlaceAuctionBid("list", i, amount)
                            Aux.log((buyout_mode and 'Purchased ' or 'Bid on ')..entry.hyperlink..' x '..entry.stack_size..' at '..Aux.util.money_string(amount)..'.')
                            entry.gone = true
							refresh = true
						else
							Aux.log('Not enough money.')
						end				
						Aux.scan.abort()
						AuxItemSearchFrameItemSearchButton:Enable()
						AuxItemSearchFrameAuctionsConfirmation:Hide()
						update_listing()
					end
					AuxItemSearchFrameAuctionsConfirmationContentActionButton:Enable()
				end
			end
		end,
		on_complete = function()
			if not found then
                Aux.log('No matching auction found. Removing entry from the cache.')
				entry.gone = true
				refresh = true
				public.dialog_cancel()
			end
			if express_mode then
				AuxItemSearchFrameItemSearchButton:Enable()
			end
		end,
		on_abort = function()
			if express_mode then
				AuxItemSearchFrameItemSearchButton:Enable()
			end
		end,
		next_page = function(page, total_pages)
			if not page or page == entry.page then
				return entry.page - 1
			end
		end,
	}
end

function public.on_row_click(entry)

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
        status = 'Other Bidder'
    end

    return {
            key = auction_item.item_signature,
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

function public.on_update()
	if refresh then
		refresh = false
		update_listing()
	end
end