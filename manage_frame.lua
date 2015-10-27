local on_open, on_close

local bid_records, auctions_records, create_maybe_bid_record, create_maybe_auction_record

local bid_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        set_auction(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        if not (current_auction and sheet.data[data_index] == current_auction) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
    end,

    row_setter = function(row, datum)
        if current_auction and datum == current_auction then
            row.highlight:SetAlpha(.5)
        else
            row.highlight:SetAlpha(0)
        end
    end,

    columns = {
        {
            title = 'Qty',
            width = 23,
            comparator = function(datum1, datum2) return Aux.util.compare(datum1.aux_quantity, datum2.aux_quantity, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.aux_quantity)
            end,
        },
        {
            title = 'Item',
            width = 186,
            comparator = function(row1, row2) return Aux.util.compare(row1.name, row2.name, Aux.util.GT) end,
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
                cell.icon.icon_texture:SetTexture(datum.texture)
                cell.text:SetText('['..datum.name..']')
                local color = ITEM_QUALITY_COLORS[datum.quality]
                cell.text:SetTextColor(color.r, color.g, color.b)
            end,
        },
    },
    sort_order = {{column = 2, order = 'ascending' }},
}

local auction_listing_config = {
    on_cell_click = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        AuxSellEntry_OnClick(sheet.data[data_index])
    end,

    on_cell_enter = function (sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_cell_leave = function (sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        local datum = sheet.data[data_index]
        if not (datum and current_auction and Aux.util.safe_index{auxSellEntries, current_auction.name, 'selected', 'key'} == datum.key) then
            sheet.rows[row_index].highlight:SetAlpha(0)
        end
    end,

    row_setter = function(row, datum)
        if datum and current_auction and Aux.util.safe_index{auxSellEntries, current_auction.name, 'selected', 'key'} == datum.key then
            row.highlight:SetAlpha(.5)
        else
            row.highlight:SetAlpha(0)
        end
    end,

    columns = {
        {
            title = 'Avail',
            width = 40,
            comparator = function(row1, row2) return Aux.util.compare(row1.count, row2.count, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.count)
            end,
        },
        {
            title = 'Yours',
            width = 40,
            comparator = function(row1, row2) return Aux.util.compare(row1.yours, row2.yours, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.yours)
            end,
        },
        {
            title = 'Max Left',
            width = 55,
            comparator = function(row1, row2) return Aux.util.compare(row1.max_time_left, row2.max_time_left, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
            cell_setter = function(cell, datum)
                local text
                if datum.max_time_left == 1 then
                    text = '30m'
                elseif datum.max_time_left == 2 then
                    text = '2h'
                elseif datum.max_time_left == 3 then
                    text = '8h'
                elseif datum.max_time_left == 4 then
                    text = '24h'
                end
                cell.text:SetText(text)
            end,
        },
        {
            title = 'Buy/ea',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.unit_buyout_price, row2.unit_buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(Aux.util.money_string(row.unit_buyout_price))
            end,
        },
        {
            title = 'Qty',
            width = 23,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(row.stack_size)
            end,
        },
        {
            title = 'Buy',
            width = 70,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, row)
                cell.text:SetText(Aux.util.money_string(row.buyout_price))
            end,
        },
    },
    sort_order = {{column = 4, order = 'ascending' }, {column = 4, order = 'ascending'}},
}

function on_open()

    if not bid_records then
        GetBidderAuctionItems()
        bid_records = {}
        local i = 0
        while true do
			local maybe_bid_record = create_maybe_bid_record(i)
			
			if maybe_bid_record.present() then
				tinsert(auction_records, maybe_bid_record.get())
			else
				break
			end
			i = i + 1
        end 
    end
    AuctionFrameBid.page = 0
    AuctionFrameBid_Update()

    if not auctions_records then
        GetOwnerAuctionItems()
        auction_records = {}
        local i = 0
        while true do
			local maybe_auction_record = create_maybe_auction_record(i)
			
			if maybe_auction_record.present() then
				tinsert(auction_records, maybe_auction_record.get())
			else
				break
			end
			i = i + 1
        end 
    end
    AuctionFrameAuctions.page = 0
    AuctionFrameAuctions_Update()
end

function on_close()
end

Aux.manage_frame = {
    on_open = on_open,
    on_close = on_close,
    bid_listing_config = bid_listing_config,
    auction_listing_config = auction_listing_config,
}

function create_maybe_auction_record(index)
	GetAuctionItemInfo('owner', index)
end

function create_maybe_bid_record(index)
	GetAuctionItemInfo('bidder', index)
end


