module 'aux.gui.auction_listing'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local sort_util = require 'aux.util.sort'
local money = require 'aux.util.money'
local history = require 'aux.core.history'
local gui = require 'aux.gui'
local tooltip = require 'aux.core.tooltip'

local price_per_unit = false

local HEAD_HEIGHT = 27
local HEAD_SPACE = 2

local TIME_LEFT_STRINGS = {
	aux.color.red'30m', -- Short
	aux.color.orange'2h', -- Medium
	aux.color.yellow'8h', -- Long
	aux.color.blue'24h', -- Very Long
}

function item_column_init(rt, cell)
    local spacer = CreateFrame('Frame', nil, cell)
    spacer:SetPoint('TOPLEFT', 0, 0)
    spacer:SetHeight(rt.ROW_HEIGHT)
    spacer:SetWidth(1)
    cell.spacer = spacer

    local iconBtn = CreateFrame('Button', nil, cell)
    iconBtn:SetPoint('TOPLEFT', spacer, 'TOPRIGHT')
    iconBtn:SetHeight(rt.ROW_HEIGHT)
    iconBtn:SetWidth(rt.ROW_HEIGHT)
    iconBtn:SetScript('OnEnter', rt.OnIconEnter)
    iconBtn:SetScript('OnLeave', rt.OnIconLeave)
    iconBtn:SetScript('OnClick', rt.OnIconClick)
    iconBtn:SetScript('OnDoubleClick', rt.OnIconDoubleClick)
    local icon = iconBtn:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', 2, -2)
    icon:SetPoint('BOTTOMRIGHT', -2, 2)
    icon:SetTexCoord(.08, .92, .08, .92)

    cell.iconBtn = iconBtn
    cell.icon = icon

    cell.text:ClearAllPoints()
    cell.text:SetPoint('TOPLEFT', iconBtn, 'TOPRIGHT', 2, 0)
    cell.text:SetPoint('BOTTOMRIGHT', 0, 0)
end

function item_column_fill(cell, record, _, _, _, indented)
	cell.icon:SetTexture(record.texture)
	if indented then
		cell.spacer:SetWidth(10)
		cell.icon:SetAlpha(.5)
		cell.text:SetAlpha(.7)
	else
		cell.spacer:SetWidth(1)
		cell.icon:SetAlpha(1)
		cell.text:SetAlpha(1)
	end
	cell.text:SetText(gsub(record.link, '[%[%]]', ''))
end

M.search_columns = {
    {
        title = 'Item',
        width = .35,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    {
        title = 'Lvl',
        width = .035,
        align = 'CENTER',
        fill = function(cell, record)
            local display_level = max(record.level, 1)
            display_level = UnitLevel'player' < record.level and aux.color.red(display_level) or display_level
            cell.text:SetText(display_level)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.level, record_b.level, desc)
        end,
    },
    {
        title = 'Auctions',
        width = .06,
        align = 'CENTER',
        fill = function(cell, record, count, own, expandable)
            local numAuctionsText = expandable and aux.color.link(count) or count
            if own > 0 then
                numAuctionsText = numAuctionsText .. (' ' .. aux.color.yellow('(' .. own .. ')'))
            end
            cell.text:SetText(numAuctionsText)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.EQ
--            if sortKey == 'numAuctions' then
--                if a.children then
--                    aVal = a.totalAuctions
--                    bVal = b.totalAuctions
--                else
--                    aVal = a.numAuctions
--                    bVal = b.numAuctions
--                end
--            end
        end,
    },
    {
        title = 'Stack\nSize',
        width = .055,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.aux_quantity)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.aux_quantity, record_b.aux_quantity, desc)
        end,
    },
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '?')
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.duration, record_b.duration, desc)
        end,
    },
    {
        title = 'Seller',
        width = .13,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(info.is_player(record.owner) and (aux.color.yellow(record.owner)) or (record.owner or '?'))
        end,
        cmp = function(record_a, record_b, desc)
            if not record_a.owner and not record_b.owner then
                return sort_util.EQ
            elseif not record_a.owner then
                return sort_util.GT
            elseif not record_b.owner then
                return sort_util.LT
            else
                return sort_util.compare(record_a.owner, record_b.owner, desc)
            end
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price_color
            if record.high_bidder then
	            price_color = aux.color.green
            elseif record.high_bid ~= 0 then
	            price_color = aux.color.orange
            end
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.aux_quantity) or record.high_bid
            else
                price = price_per_unit and ceil(record.unit_bid_price) or record.bid_price
            end
            cell.text:SetText(money.to_string(price, true, false, price_color))
        end,
        cmp = function(record_a, record_b, desc)
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.aux_quantity or record_a.high_bid
            else
                price_a = price_per_unit and record_a.unit_bid_price or record_a.bid_price
            end
            local price_b
            if record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.aux_quantity or record_b.high_bid
            else
                price_b = price_per_unit and record_b.unit_bid_price or record_b.bid_price
            end
            if record_a.high_bidder and not record_b.high_bidder then
	            return sort_util.GT
            elseif record_b.high_bidder and not record_a.high_bidder then
	            return sort_util.LT
            end
            if price_a == price_b then
				if record_a.high_bid == 0 and record_b.high_bid ~= 0 then
		            return sort_util.GT
	            elseif record_b.high_bid == 0 and record_a.high_bid ~= 0 then
		            return sort_util.LT
	            end
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -aux.huge or aux.huge)
            price_b = price_b > 0 and price_b or (desc and -aux.huge or aux.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = '% Hist.\nValue',
        width = .08,
        align = 'CENTER',
        fill = function(cell, record)
            local pct, bidPct = record_percentage(record)
            cell.text:SetText((pct or bidPct) and gui.percentage_historical(pct or bidPct, not pct) or '?')
        end,
        cmp = function(record_a, record_b, desc)
            local pct_a = record_percentage(record_a) or (desc and -aux.huge or aux.huge)
            local pct_b = record_percentage(record_b) or (desc and -aux.huge or aux.huge)
            return sort_util.compare(pct_a, pct_b, desc)
        end,
    },
}

M.auctions_columns = {
    {
        title = 'Item',
        width = .35,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    {
        title = 'Lvl',
        width = .035,
        align = 'CENTER',
        fill = function(cell, record)
            local display_level = max(record.level, 1)
            display_level = UnitLevel('player') < record.level and aux.color.red(display_level) or display_level
            cell.text:SetText(display_level)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.level, record_b.level, desc)
        end,
    },
    {
        title = 'Auctions',
        width = .06,
        align = 'CENTER',
        fill = function(cell, record, count, own, expandable)
            local numAuctionsText = expandable and aux.color.link(count) or count
            cell.text:SetText(numAuctionsText)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.EQ
            --            if sortKey == 'numAuctions' then
            --                if a.children then
            --                    aVal = a.totalAuctions
            --                    bVal = b.totalAuctions
            --                else
            --                    aVal = a.numAuctions
            --                    bVal = b.numAuctions
            --                end
            --            end
        end,
    },
    {
        title = 'Stack\nSize',
        width = .055,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.aux_quantity)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.aux_quantity, record_b.aux_quantity, desc)
        end,
    },
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '?')
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.duration, record_b.duration, desc)
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.aux_quantity) or record.high_bid
            else
                price = price_per_unit and ceil(record.start_price / record.aux_quantity) or record.start_price
            end
            cell.text:SetText(money.to_string(price, true))
        end,
        cmp = function(record_a, record_b, desc)
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.aux_quantity or record_a.high_bid
            else
                price_a = price_per_unit and record_a.start_price / record_b.aux_quantity or record_a.start_price
            end
            local price_b
            if record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.aux_quantity or record_b.high_bid
            else
                price_b = price_per_unit and record_b.start_price / record_b.aux_quantity or record_b.start_price
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -aux.huge or aux.huge)
            price_b = price_b > 0 and price_b or (desc and -aux.huge or aux.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = 'High Bidder',
        width = .21,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.high_bidder or aux.color.red 'No Bids')
        end,
        cmp = function(record_a, record_b, desc)
            if not record_a.high_bidder and not record_b.high_bidder then
                return sort_util.EQ
            elseif not record_a.high_bidder then
                return sort_util.GT
            elseif not record_b.high_bidder then
                return sort_util.LT
            else
                return sort_util.compare(record_a.high_bidder, record_b.high_bidder, desc)
            end
        end,
    },
}

M.bids_columns = {
    {
        title = 'Item',
        width = .35,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    {
        title = 'Auctions',
        width = .06,
        align = 'CENTER',
        fill = function(cell, record, count, own, expandable)
            local numAuctionsText = expandable and aux.color.link(count) or count
            cell.text:SetText(numAuctionsText)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.EQ
            --            if sortKey == 'numAuctions' then
            --                if a.children then
            --                    aVal = a.totalAuctions
            --                    bVal = b.totalAuctions
            --                else
            --                    aVal = a.numAuctions
            --                    bVal = b.numAuctions
            --                end
            --            end
        end,
    },
    {
        title = 'Stack\nSize',
        width = .055,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.aux_quantity)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.aux_quantity, record_b.aux_quantity, desc)
        end,
    },
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '?')
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.duration, record_b.duration, desc)
        end,
    },
    {
        title = 'Seller',
        width = .13,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(info.is_player(record.owner) and (aux.color.yellow(record.owner)) or (record.owner or '?'))
        end,
        cmp = function(record_a, record_b, desc)
            if not record_a.owner and not record_b.owner then
                return sort_util.EQ
            elseif not record_a.owner then
                return sort_util.GT
            elseif not record_b.owner then
                return sort_util.LT
            else
                return sort_util.compare(record_a.owner, record_b.owner, desc)
            end
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.aux_quantity) or record.high_bid
            else
                price = price_per_unit and ceil(record.unit_bid_price) or record.bid_price
            end
            cell.text:SetText(money.to_string(price))
        end,
        cmp = function(record_a, record_b, desc)
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.aux_quantity or record_a.high_bid
            else
                price_a = price_per_unit and record_a.unit_bid_price or record_a.bid_price
            end
            local price_b
            if record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.aux_quantity or record_b.high_bid
            else
                price_b = price_per_unit and record_b.unit_bid_price or record_b.bid_price
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        isPrice = true,
        fill = function(cell, record)
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -aux.huge or aux.huge)
            price_b = price_b > 0 and price_b or (desc and -aux.huge or aux.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = 'Status',
        width = .115,
        align = 'CENTER',
        fill = function(cell, record)
            local status
            if record.high_bidder then
                status = aux.color.yellow'High Bidder'
            else
                status = aux.color.red'Outbid'
            end
            cell.text:SetText(status)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.high_bidder and 1 or 0, record_b.high_bidder and 1 or 0, desc)
        end,
    },
}

function record_percentage(record)
    if not record then return end

    local historical_value = history.value(record.item_key) or 0
    if historical_value > 0 then
        if record.unit_buyout_price > 0 then
            return aux.round(100 * record.unit_buyout_price / historical_value)
        end
        return nil, aux.round(100 * record.unit_bid_price / historical_value)
    end
end

function M.time_left(code)
    return TIME_LEFT_STRINGS[code]
end

local methods = {

    ResizeColumns = function(self)
        local weight = 0
        for _, cell in pairs(self.headCells) do
            weight = weight + cell.info.width
        end
        weight = (self.contentFrame:GetRight() - self.contentFrame:GetLeft()) / weight
        for i, cell in pairs(self.headCells) do
            local width = cell.info.width * weight
            cell:SetWidth(width)
            for _, row in pairs(self.rows) do
                row.cells[i]:SetWidth(width)
            end
        end
    end,

    OnHeadColumnClick = function()
        local button = arg1
        local rt = this.rt

        if button == 'RightButton' and rt.headCells[this.columnIndex].info.isPrice then
            price_per_unit = not price_per_unit
            for _, cell in pairs(rt.headCells) do
                if cell.info.isPrice then
                    cell:SetText(cell.info.title[price_per_unit and 1 or 2])
                end
            end
            rt:SetSort()
            return
        end

        local descending = false
        if getn(rt.sorts) > 0 and rt.sorts[1].index == this.columnIndex then
            descending = not rt.sorts[1].descending
        end
        rt:SetSort((descending and -1 or 1) * this.columnIndex)
    end,

    OnIconEnter = function()
        local rt = this:GetParent().row.rt
        local row = this:GetParent().row
        if row.record then
	        GameTooltip:SetOwner(this, 'ANCHOR_RIGHT')
            info.load_tooltip(GameTooltip, row.record.tooltip)
	        tooltip.extend_tooltip(GameTooltip, row.record.link, row.record.aux_quantity)
            info.set_shopping_tooltip(row.record.slot)
        end
    end,

    OnIconLeave = function()
        GameTooltip:Hide()
    end,

    OnEnter = function()
        local rt = this.rt
        if rt.expanded[this.expandKey] then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:AddLine('Double-click to collapse this item and show only the cheapest auction.', 1, 1, 1, true)
            GameTooltip:Show()
        elseif this.expandable then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:AddLine('Double-click to expand this item and show all the auctions.', 1, 1, 1, true)
            GameTooltip:Show()
        end

        this.highlight:Show()
    end,

    OnLeave = function()
        GameTooltip:Hide()
        if not this.rt.selected or this.rt.selected.search_signature ~= this.record.search_signature then
            this.highlight:Hide()
        end
    end,

    OnClick = function()
        local button = arg1
        if IsControlKeyDown() then
            DressUpItemLink(this.record.link)
        elseif IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(this.record.link)
        else
            local selection = this.rt:GetSelection()
            if not selection or selection.record ~= this.record then
                this.rt:SetSelectedRecord(this.record)
            end
	        do (this.rt.handlers.OnClick or pass)(this, button) end
        end
    end,

    OnDoubleClick = function()
        local rt = this.rt
        local expand = not rt.expanded[this.expandKey]

        rt.expanded[this.expandKey] = expand
        rt:UpdateRowInfo()
        rt:UpdateRows()
        if not this.indented then
            rt:SetSelectedRecord(this.record)
        end
    end,

    UpdateRowInfo = function(self)
	    for _, v in ipairs(self.rowInfo) do
		    if type(v) == 'table' then
			    for _, child in pairs(v.children) do
				    T.release(child)
			    end
			    T.release(v.children)
			    T.release(v)
		    end
	    end
        T.wipe(self.rowInfo)
        self.rowInfo.numDisplayRows = 0
        self.isSorted = nil
        self:SetSelectedRecord(nil, true)

	    local records = self.records

	    local single_item = aux.all(records, function(record) return record.item_key == records[1].item_key end)

        sort(records, function(a, b) return a.search_signature < b.search_signature or a.search_signature == b.search_signature and tostring(a) < tostring(b) end)

        for i = 1, getn(records) do
            local record = records[i]
            local prevRecord = records[i - 1]
            if prevRecord and record.search_signature == prevRecord.search_signature then
                -- it's an identical auction to the previous row so increment the number of auctions
                self.rowInfo[getn(self.rowInfo)].children[getn(self.rowInfo[getn(self.rowInfo)].children)].count = self.rowInfo[getn(self.rowInfo)].children[getn(self.rowInfo[getn(self.rowInfo)].children)].count + 1
            elseif not single_item and prevRecord and record.item_key == prevRecord.item_key then
                -- it's the same base item as the previous row so insert a new auction
                tinsert(self.rowInfo[getn(self.rowInfo)].children, T.map('count', 1, 'record', record))
                if self.expanded[self.rowInfo[getn(self.rowInfo)].expandKey] then
                    self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
                end
            else
                -- it's a different base item from the previous row
                tinsert(self.rowInfo, T.map('item_key', record.item_key, 'expandKey', record.item_key, 'children', T.list(T.map('count', 1, 'record', record))))
                self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
            end
        end

	    for _, v in ipairs(self.rowInfo) do
            local totalAuctions, totalPlayerAuctions = 0, 0
            for _, childInfo in pairs(v.children) do
                totalAuctions = totalAuctions + childInfo.count
                if info.is_player(childInfo.record.owner) then
                    totalPlayerAuctions = totalPlayerAuctions + childInfo.count
                end
            end
            v.totalAuctions = totalAuctions
            v.totalPlayerAuctions = totalPlayerAuctions
	    end
    end,

    UpdateRows = function(self)
	    if self.rowInfo.numDisplayRows > getn(self.rows) then
		    self.contentFrame:SetPoint('BOTTOMRIGHT', -15, 0)
	    else
		    self.contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
	    end
	    self:ResizeColumns()

	    FauxScrollFrame_Update(self.scrollFrame, self.rowInfo.numDisplayRows, getn(self.rows), self.ROW_HEIGHT)

	    local maxOffset = max(self.rowInfo.numDisplayRows - getn(self.rows), 0)
	    if FauxScrollFrame_GetOffset(self.scrollFrame) > maxOffset then
		    FauxScrollFrame_SetOffset(self.scrollFrame, maxOffset)
	    end

        for _, cell in pairs(self.headCells) do
            local tex = cell:GetNormalTexture()
            tex:SetTexture[[Interface\AddOns\aux-AddOn\WorldStateFinalScore-Highlight]]
            tex:SetTexCoord(.017, 1, .083, .909)
            tex:SetAlpha(.5)
        end

        if getn(self.sorts) > 0 then
            local last_sort = self.sorts[1]
            if last_sort.descending then
                self.headCells[last_sort.index]:GetNormalTexture():SetTexture(.8, .6, 1, .8)
            else
                self.headCells[last_sort.index]:GetNormalTexture():SetTexture(.6, .8, 1, .8)
            end
        end

        if not self.isSorted then
            local function sort_helper(a, b)

                local record_a, record_b
                if a.children then
                    record_a = a.children[1].record
                    record_b = b.children[1].record
                else
                    record_a = a.record
                    record_b = b.record
                end

                for _, sort in pairs(self.sorts) do
                    local ordering = self.columns[sort.index].cmp and self.columns[sort.index].cmp(record_a, record_b, sort.descending) or sort_util.EQ

                    if ordering == sort_util.LT then
                        return true
                    elseif ordering == sort_util.GT then
                        return false
                    end
                end

                return tostring(a) < tostring(b)
            end

            for _, v in ipairs(self.rowInfo) do
                sort(v.children, sort_helper)
            end
            sort(self.rowInfo, sort_helper)
            self.isSorted = true
        end

	    for _, row in pairs(self.rows) do
		    row:Hide()
	    end
        local rowIndex = 1 - FauxScrollFrame_GetOffset(self.scrollFrame)
        for _, v in ipairs(self.rowInfo) do
            if self.expanded[v.expandKey] then
                for j, childInfo in ipairs(v.children) do
                    self:SetRowInfo(rowIndex, childInfo.record, childInfo.count, 0, j > 1, false, v.expandKey)
                    rowIndex = rowIndex + 1
                end
            else
                self:SetRowInfo(rowIndex, v.children[1].record, v.totalAuctions, getn(v.children) > 1 and v.totalPlayerAuctions or 0, false, getn(v.children) > 1, v.expandKey)
                rowIndex = rowIndex + 1
            end
        end
    end,

    SetRowInfo = function(self, rowIndex, record, totalAuctions, totalPlayerAuctions, indented, expandable, expandKey)
        if rowIndex <= 0 or rowIndex > getn(self.rows) then return end
        local row = self.rows[rowIndex]
        row:Show()
        if self.selected and record.search_signature == self.selected.search_signature then
            row.highlight:Show()
        else
            row.highlight:Hide()
        end

        row.record = record
        row.expandable = expandable
        row.indented = indented
        row.expandKey = expandKey

        for i, column in pairs(self.columns) do
	        column.fill(row.cells[i], record, totalAuctions, totalPlayerAuctions, expandable, indented)
        end
    end,

    SetSelectedRecord = function(self, record, silent)
        self.selected = record
        local selectedData = self:GetSelection()
        self.selected = selectedData and self.selected or nil

        for _, row in pairs(self.rows) do
            if self.selected and row.record and row.record.search_signature == self.selected.search_signature then
                row.highlight:Show()
            else
                row.highlight:Hide()
            end
        end

        if not silent and self.handlers.OnSelectionChanged then
            self.handlers.OnSelectionChanged(self, selectedData or nil)
        end
    end,

    Reset = function(self)
        T.wipe(self.expanded)
        self:UpdateRowInfo()
        self:UpdateRows()
        self:SetSelectedRecord()
    end,

    SetDatabase = function(self, database)
        if database and database ~= self.records then
            self.records = database
        end

        local prevSelectedIndex
        if self.selected then
            for i, row in pairs(self.rows) do
                if row:IsVisible() and row.record == self.selected then
                    prevSelectedIndex = i
                end
            end
        end

        self:UpdateRowInfo()
        self:UpdateRows()

        if not self.selected and prevSelectedIndex then
            -- try to select the same row
            local row = self.rows[prevSelectedIndex]
            if row and row:IsVisible() and row.record then
                self:SetSelectedRecord(row.record)
            end
            if not self.selected then
                -- select the first row
                row = self.rows[1]
                if row and row:IsVisible() and row.record then
                    self:SetSelectedRecord(row.record)
                end
            end
        end
    end,

    RemoveAuctionRecord = function(self, record)
        local index = aux.key(self.records, record)
        if index then
            tremove(self.records, index)
        end
        self:SetDatabase()
    end,

    ContainsRecord = function(self, record)
        if aux.key(self.records, record) then
            return true
        end
    end,

    SetSort = T.vararg-function(arg)
	    local self = tremove(arg, 1)
        for _, v in ipairs(arg) do
            for i, sort in ipairs(self.sorts) do
                if sort.index == abs(v) then
                    tremove(self.sorts, i)
                    break
                end
            end
            tinsert(self.sorts, 1, {index=abs(v), descending=v < 0})
        end

        self.isSorted = nil
        self:UpdateRows()
    end,

    SetHandler = function(self, event, handler)
        self.handlers[event] = handler
    end,

    GetSelection = function(self)
        if not self.selected then return end
        local selectedData
        for _, v in ipairs(self.rowInfo) do
            for _, childInfo in pairs(v.children) do
                if childInfo.record.search_signature == self.selected.search_signature then
                    selectedData = childInfo
                    break
                end
            end
        end
        return selectedData
    end,
}

function M.new(parent, rows, columns)
    local rt = CreateFrame('Frame', nil, parent)
    rt.columns = columns
    rt.ROW_HEIGHT = (parent:GetHeight() - HEAD_HEIGHT - HEAD_SPACE) / rows
    rt.expanded = {}
    rt.handlers = {}
    rt.sorts = {}
    rt.records = {}
    rt.rowInfo = {numDisplayRows=0}

    for name, func in pairs(methods) do
        rt[name] = func
    end

    rt:SetScript('OnShow', function()
        for _, cell in pairs(this.headCells) do
            if cell.info.isPrice then
                cell:SetText(cell.info.title[price_per_unit and 1 or 2])
            end
        end
    end)

    local contentFrame = CreateFrame('Frame', nil, rt)
    contentFrame:SetPoint('TOPLEFT', 0, 0)
    contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
    rt.contentFrame = contentFrame

    local scrollFrame = CreateFrame('ScrollFrame', gui.unique_name(), rt, 'FauxScrollFrameTemplate')
    scrollFrame:SetScript('OnVerticalScroll', function()
	    FauxScrollFrame_OnVerticalScroll(rt.ROW_HEIGHT, function() rt:UpdateRows() end)
    end)
    scrollFrame:SetAllPoints(contentFrame)
    rt.scrollFrame = scrollFrame
    FauxScrollFrame_Update(rt.scrollFrame, 0, rows, rt.ROW_HEIGHT)

    local scrollBar = _G[scrollFrame:GetName() .. 'ScrollBar']
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint('TOPRIGHT', rt, -4, -HEAD_HEIGHT)
    scrollBar:SetPoint('BOTTOMRIGHT', rt, -4, 4)
    scrollBar:SetWidth(10)
    local thumbTex = scrollBar:GetThumbTexture()
    thumbTex:SetPoint('CENTER', 0, 0)
    thumbTex:SetTexture(aux.color.content.background())
    thumbTex:SetHeight(150)
    thumbTex:SetWidth(scrollBar:GetWidth())
    _G[scrollBar:GetName() .. 'ScrollUpButton']:Hide()
    _G[scrollBar:GetName() .. 'ScrollDownButton']:Hide()

    rt.headCells = {}
    for i, column in ipairs(rt.columns) do
        local cell = CreateFrame('Button', nil, rt.contentFrame)
        cell:SetHeight(HEAD_HEIGHT)
        if i == 1 then
            cell:SetPoint('TOPLEFT', 0, 0)
        else
            cell:SetPoint('TOPLEFT', rt.headCells[i - 1], 'TOPRIGHT')
        end
        cell.info = column
        cell.rt = rt
        cell.columnIndex = i
        cell:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        cell:SetScript('OnClick', rt.OnHeadColumnClick)

        local text = cell:CreateFontString()
        text:SetJustifyH('CENTER')
        text:SetFont(gui.font, 12)
        text:SetTextColor(aux.color.label.enabled())
        cell:SetFontString(text)
        if not column.isPrice then cell:SetText(column.title or '') end -- TODO
        text:SetAllPoints()

        local tex = cell:CreateTexture()
        tex:SetAllPoints()
        tex:SetTexture([[Interface\AddOns\aux-AddOn\WorldStateFinalScore-Highlight]])
        tex:SetTexCoord(.017, 1, .083, .909)
        tex:SetAlpha(.5)
        cell:SetNormalTexture(tex)

        local tex = cell:CreateTexture()
        tex:SetAllPoints()
        tex:SetTexture([[Interface\Buttons\UI-Listbox-Highlight]])
        tex:SetTexCoord(.025, .957, .087, .931)
        tex:SetAlpha(.2)
        cell:SetHighlightTexture(tex)

        tinsert(rt.headCells, cell)
    end

    rt.rows = {}
    for i = 1, rows do
        local row = CreateFrame('Button', nil, rt.contentFrame)
        row.rt = rt
        row:SetHeight(rt.ROW_HEIGHT)
        row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        row:SetScript('OnEnter', rt.OnEnter)
        row:SetScript('OnLeave', rt.OnLeave)
        row:SetScript('OnClick', rt.OnClick)
        row:SetScript('OnDoubleClick', rt.OnDoubleClick)
        if i == 1 then
	        row:SetPoint('TOPLEFT', 0, -(HEAD_HEIGHT + HEAD_SPACE))
	        row:SetPoint('TOPRIGHT', 0, -(HEAD_HEIGHT + HEAD_SPACE))
        else
	        row:SetPoint('TOPLEFT', 0, -(HEAD_HEIGHT + HEAD_SPACE + (i - 1) * rt.ROW_HEIGHT))
	        row:SetPoint('TOPRIGHT', 0, -(HEAD_HEIGHT + HEAD_SPACE + (i - 1) * rt.ROW_HEIGHT))
        end
        local highlight = row:CreateTexture()
        highlight:SetAllPoints()
        highlight:SetTexture(1, .9, 0, .5)
        highlight:Hide()
        row.highlight = highlight

        row.cells = {}
        for j, column in ipairs(rt.columns) do
            local cell = CreateFrame('Frame', nil, row)
            local text = cell:CreateFontString()
            cell.text = text
            text:SetFont(gui.font, min(14, rt.ROW_HEIGHT))
            text:SetJustifyH(column.align or 'LEFT')
            text:SetJustifyV('CENTER')
            text:SetPoint('TOPLEFT', 1, -1)
            text:SetPoint('BOTTOMRIGHT', -1, 1)
            cell:SetHeight(rt.ROW_HEIGHT)
            cell.rt = rt
            cell.row = row

            if j == 1 then
                cell:SetPoint('TOPLEFT', 0, 0)
            else
                cell:SetPoint('TOPLEFT', row.cells[j - 1], 'TOPRIGHT')
            end

            if mod(j, 2) == 1 then
                local tex = cell:CreateTexture()
                tex:SetAllPoints()
                tex:SetTexture(.3, .3, .3, .2)
            end

            if column.init then
                column.init(rt, cell)
            end

            tinsert(row.cells, cell)
        end

        if mod(i, 2) == 0 then
            local tex = row:CreateTexture()
            tex:SetAllPoints()
            tex:SetTexture(.3, .3, .3, .3)
        end

        tinsert(rt.rows, row)
    end

    rt:SetAllPoints()
    rt:ResizeColumns()
    return rt
end