local private, public = {}, {}
Aux.auction_listing = public

local RT_COUNT = 1
local HEAD_HEIGHT = 27
local HEAD_SPACE = 2
local AUCTION_PCT_COLORS = {
    {color='|cff2992ff', value=50}, -- blue
    {color='|cff16ff16', value=80}, -- green
    {color='|cffffff00', value=110}, -- yellow
    {color='|cffff9218', value=135}, -- orange
    {color='|cffff0000', value=Aux.huge}, -- red
}
local TIME_LEFT_STRINGS = {
    '|cffff000030m|r', -- Short
    '|cffff92182h|r', -- Medium
    '|cffffff008h|r', -- Long
    '|cff2992ff24h|r', -- Very Long
}

function public.percentage_market(pct, based_on_bid)
    local pctColor = '|cffffffff'

    if based_on_bid then
        pctColor = '|cffbbbbbb'
    else
        for i=1, getn(AUCTION_PCT_COLORS) do
            if pct < AUCTION_PCT_COLORS[i].value then
                pctColor = AUCTION_PCT_COLORS[i].color
                break
            end
        end
    end

    if pct > 10000 then
        pct = '>10000'
    end

    return format('%s%s%%|r', pctColor, pct)
end

function public.time_left(code)
    return TIME_LEFT_STRINGS[code]
end

local methods = {

    OnContentSizeChanged = function()
        local width = arg1
        local rt = this:GetParent()
        for i, cell in ipairs(rt.headCells) do
            cell:SetWidth(cell.info.width * width)
        end

        for _, row in ipairs(rt.rows) do
            for i, cell in ipairs(row.cells) do
                cell:SetWidth(rt.headCells[i].info.width * width)
            end
        end
    end,

    OnHeadColumnClick = function()
        local button = arg1
        local rt = this.rt
        if rt.disabled then return end

        if button == 'RightButton' and rt.headCells[this.columnIndex].info.isPrice then
            aux_price_per_unit = not aux_price_per_unit
            for i, cell in ipairs(rt.headCells) do
                if cell.info.isPrice then
                    cell:SetText(cell.info.name[aux_price_per_unit and 1 or 2])
                end
            end
            rt:SetSort()
            return
        end

        local descending = false
        if rt.sortInfo.columnIndex == this.columnIndex then
            descending = not rt.sortInfo.descending
        end
        rt:SetSort((descending and -1 or 1) * this.columnIndex)
    end,

    OnIconEnter = function()
        local rt = this:GetParent().row.rt
        local rowData = this:GetParent().row.data
        if rowData and rowData.record then
            Aux.info.set_tooltip(rowData.record.itemstring, rowData.record.EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
            Aux.info.set_shopping_tooltip(rowData.record.slot)
            rt.isShowingItemTooltip = true
        end
    end,

    OnIconLeave = function()
        GameTooltip:Hide()
        this:GetParent().row.rt.isShowingItemTooltip = nil
    end,

--    OnIconClick = function(self, ...)
--        if IsModifiedClick() then
--            HandleModifiedItemClick(self:GetParent().row.data.record.rawItemLink)
--        else
--            self:GetParent():GetScript("OnClick")(self:GetParent(), ...)
--        end
--    end,
--
--    OnIconDoubleClick = function(self, ...)
--        self:GetParent():GetScript("OnDoubleClick")(self:GetParent(), ...)
--    end,

    OnCellEnter = function()
        local rt = this.rt
        local row = this.row
        if rt.disabled then return end
        if this ~= row.cells[1] or not rt.isShowingItemTooltip then
            if rt.expanded[row.data.expandKey] then
                GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
                GameTooltip:AddLine('Double-click to collapse this item and show only the cheapest auction.', 1, 1, 1, true)
                GameTooltip:Show()
            elseif row.data.expandable then
                GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
                GameTooltip:AddLine('Double-click to expand this item and show all the auctions.', 1, 1, 1, true)
                GameTooltip:Show()
            end
        end

        -- show highlight for this row
        this.row.highlight:Show()
    end,

    OnCellLeave = function()
        GameTooltip:Hide()
        -- hide highlight if it's not selected
        if not this.rt.selected or this.rt.selected.search_signature ~= this.row.data.record.search_signature then
            this.row.highlight:Hide()
        end
    end,

    OnCellClick = function()
        local button = arg1
        if this.rt.disabled then return end
        if IsControlKeyDown() then
            DressUpItemLink(this.row.data.record.hyperlink)
        elseif IsShiftKeyDown() then
            if ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Insert(this.row.data.record.hyperlink)
            else
                Aux.search_frame.start_search(strlower(Aux.static.item_info(this.row.data.record.item_id).name)..'/exact')
            end
        elseif IsAltKeyDown() then
            if this.rt.handlers.OnCellAltClick then
                this.rt.handlers.OnCellAltClick(this, button)
            end
        else
            this.rt:SetSelectedRecord(this.row.data.record)
        end
    end,

    OnCellDoubleClick = function()
        local rt = this.rt
        local rowData = this.row.data
        local expand = not rt.expanded[rowData.expandKey]
        if rt.disabled or expand and not rowData.expandable then return end

        rt.expanded[rowData.expandKey] = expand
        rt:UpdateRowInfo()
        rt:UpdateRows()
        -- select this row if it's not indented
        if not rowData.indented then
            rt:SetSelectedRecord(this.row.data.record)
        end
    end,


    -- ============================================================================
    -- Internal Results Table Methods
    -- ============================================================================

    --    GetRowPrices = function(record, isPerUnit) return end, -- TODO
    GetRowPrices = function(record, per_unit)
        local bid_color
        if record.high_bidder then
            bid_color = '|cff16ff16'
        elseif record.high_bid ~= 0 then
            bid_color = '|cffff9218'
        end

        if per_unit then
            return ceil(record.unit_bid_price), ceil(record.unit_buyout_price), bid_color
        else
            return record.bid_price, record.buyout_price, bid_color
        end
    end,


    GetRecordPercent = function(self, record)
        if not record then return end
--      cache the market value on the record
        record.market_value = record.market_value or Aux.history.value(record.item_key) or 0
        if record.market_value > 0 then
            if record.unit_buyout_price > 0 then
                return Aux.round(100 * record.unit_buyout_price / record.market_value, 1)
            end
            return nil, Aux.round(100 * record.unit_bid_price / record.market_value, 1)
        end
    end,

    UpdateRowInfo = function(self)
        Aux.util.wipe(self.rowInfo)
        self.rowInfo.numDisplayRows = 0
        self.sortInfo.isSorted = nil
        self:SetSelectedRecord(nil, true)

        sort(self.records, function(a, b) return Aux.sort.multi_lt(a.search_signature, b.search_signature, tostring(a), tostring(b)) end)

        local records = self.records
        if getn(records) == 0 then return end

        -- Populate the row info from the database by combining identical auctions and auctions
        -- of the same base item. Also, get the number of rows which will be shown.
        for i=1, getn(records) do
            local record = records[i]
            local prevRecord = records[i-1]
            if prevRecord and record.search_signature == prevRecord.search_signature then
                -- it's an identical auction to the previous row so increment the number of auctions
                self.rowInfo[getn(self.rowInfo)].children[getn(self.rowInfo[getn(self.rowInfo)].children)].numAuctions = self.rowInfo[getn(self.rowInfo)].children[getn(self.rowInfo[getn(self.rowInfo)].children)].numAuctions + 1
            elseif prevRecord and record.item_key == prevRecord.item_key then
                -- it's the same base item as the previous row so insert a new auction
                tinsert(self.rowInfo[getn(self.rowInfo)].children, {numAuctions=1, record=record})
                if self.expanded[self.rowInfo[getn(self.rowInfo)].expandKey] then
                    self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
                end
            else
                -- it's a different base item from the previous row
                tinsert(self.rowInfo, {item_key=record.item_key, expandKey=record.item_key, children={{numAuctions=1, record=record}}})
                self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
            end
        end

        for _, info in ipairs(self.rowInfo) do
            local totalAuctions, totalPlayerAuctions = 0, 0
            for _, childInfo in ipairs(info.children) do
                totalAuctions = totalAuctions + childInfo.numAuctions
                if Aux.is_player(childInfo.record.owner) then
                    totalPlayerAuctions = totalPlayerAuctions + childInfo.numAuctions
                end
            end
            info.totalAuctions = totalAuctions
            info.totalPlayerAuctions = totalPlayerAuctions
        end
    end,

    UpdateRows = function(self)
        -- hide all the rows
        for _, row in ipairs(self.rows) do row:Hide() end

        -- update sorting highlights
        for _, cell in ipairs(self.headCells) do
            local tex = cell:GetNormalTexture()
            tex:SetTexture([[Interface\AddOns\Aux-AddOn\WorldStateFinalScore-Highlight]])
            tex:SetTexCoord(0.017, 1, 0.083, 0.909)
            tex:SetAlpha(0.5)
        end
        if self.sortInfo.descending then
            self.headCells[self.sortInfo.columnIndex]:GetNormalTexture():SetTexture(0.8, 0.6, 1, 0.8)
        else
            self.headCells[self.sortInfo.columnIndex]:GetNormalTexture():SetTexture(0.6, 0.8, 1, 0.8)
        end

        -- update the scroll frame
        FauxScrollFrame_Update(self.scrollFrame, self.rowInfo.numDisplayRows, getn(self.rows), self.ROW_HEIGHT)

        -- make sure the offset is not too high
        local maxOffset = max(self.rowInfo.numDisplayRows - getn(self.rows), 0)
        if FauxScrollFrame_GetOffset(self.scrollFrame) > maxOffset then
            FauxScrollFrame_SetOffset(self.scrollFrame, maxOffset)
        end

        if not self.sortInfo.isSorted then
            local function SortHelperFunc(a, b, sortKey)
                local hadSortKey = sortKey and true or false
                sortKey = sortKey or self.sortInfo.sortKey

                local record_a, record_b
                if a.children then
                    record_a = a.children[1].record
                    record_b = b.children[1].record
                else
                    record_a = a.record
                    record_b = b.record
                end

                if record_a.isFake then
                    return true
                elseif record_b.isFake then
                    return false
                end

                local aVal, bVal
                if sortKey == 'percent' then
                    aVal = self:GetRecordPercent(record_a)
                    bVal = self:GetRecordPercent(record_b)
                elseif sortKey == 'numAuctions' then
                    if a.children then
                        aVal = a.totalAuctions
                        bVal = b.totalAuctions
                    else
                        aVal = a.numAuctions
                        bVal = b.numAuctions
                    end
                elseif sortKey == 'unit_bid_price' or sortKey == 'bid_price' then
                    aVal = self.GetRowPrices(record_a, sortKey == 'unit_bid_price')
                    bVal = self.GetRowPrices(record_b, sortKey == 'unit_bid_price')
                elseif sortKey == 'unit_buyout_price' or sortKey == 'buyout_price' then
                    aVal = ({ self.GetRowPrices(record_a, sortKey == 'unit_buyout_price') })[2]
                    bVal = ({ self.GetRowPrices(record_b, sortKey == 'unit_buyout_price') })[2]
                else
                    aVal = record_a[sortKey]
                    bVal = record_b[sortKey]
                end
                if sortKey == 'buyout_price' or sortKey == 'unit_buyout_price' then
                    -- for buyout, put bid-only auctions at the bottom
                    if not aVal or aVal == 0 then
                        aVal = (self.sortInfo.descending and -1 or 1) * Aux.huge
                    end
                    if not bVal or bVal == 0 then
                        bVal = (self.sortInfo.descending and -1 or 1) * Aux.huge
                    end
                elseif sortKey == 'percent' then
                    -- for percent, put bid-only auctions at the bottom
                    aVal = aVal or ((self.sortInfo.descending and -1 or 1) * Aux.huge)
                    bVal = bVal or ((self.sortInfo.descending and -1 or 1) * Aux.huge)
                end
                if type(aVal) == 'string' or type(bVal) == 'string' then
                    aVal = aVal or ''
                    bVal = bVal or ''
                else
                    aVal = tonumber(aVal) or 0
                    bVal = tonumber(bVal) or 0
                end
                if aVal == bVal then
                    if sortKey == 'percent' then
                        -- sort by buyout
                        sortKey = aux_price_per_unit and 'unit_buyout_price' or 'buyout_price'
                        local result = SortHelperFunc(a, b, sortKey)
                        if result ~= nil then
                            return result
                        end
                    elseif sortKey == 'buyout_price' or sortKey == 'unit_buyout_price' then
                        -- sort by bid
                        sortKey = aux_price_per_unit and 'unit_bid_price' or 'bid_price'
                        local result = SortHelperFunc(a, b, sortKey)
                        if result ~= nil then
                            return result
                        end
                    elseif hadSortKey then
                        -- this was called recursively, so just return nil
                        return
                    else
                        -- sort by percent
                        return SortHelperFunc(a, b, 'percent')
                    end
                    -- as a last resort compare search signatures to ensure a total order
                    return record_a.search_signature < record_b.search_signature
                end
                if self.sortInfo.descending then
                    return aVal > bVal
                else
                    return aVal < bVal
                end
            end
            -- sort the row info
            for i, info in ipairs(self.rowInfo) do
                sort(info.children, SortHelperFunc)
            end
            sort(self.rowInfo, SortHelperFunc)
            self.sortInfo.isSorted = true
        end

        -- update all the rows
        local rowIndex = 1 - FauxScrollFrame_GetOffset(self.scrollFrame)
        for i, info in ipairs(self.rowInfo) do
            if self.expanded[info.expandKey] then
                -- show each of the rows for this base item since it's expanded
                for j, childInfo in ipairs(info.children) do
                    self:SetRowInfo(rowIndex, childInfo.record, childInfo.numAuctions, 0, j > 1, false, info.expandKey, childInfo.numAuctions)
                    rowIndex = rowIndex + 1
                end
            else
                -- just show one row for this base item since it's not expanded
                self:SetRowInfo(rowIndex, info.children[1].record, info.totalAuctions, getn(info.children) > 1 and info.totalPlayerAuctions or 0, false, getn(info.children) > 1, info.expandKey, info.children[1].numAuctions)
                rowIndex = rowIndex + 1
            end
        end
    end,

    SetRowInfo = function(self, rowIndex, record, displayNumAuctions, numPlayerAuctions, indented, expandable, expandKey, numAuctions)
        if rowIndex <= 0 or rowIndex > getn(self.rows) then return end
        local row = self.rows[rowIndex]
        -- show this row
        row:Show()
        if self.selected and record.search_signature == self.selected.search_signature then
            row.highlight:Show()
        else
            row.highlight:Hide()
        end
        row.data = {record=record, expandable=expandable, indented=indented, numAuctions=numAuctions, expandKey=expandKey}

        -- set first cell
        row.cells[1].icon:SetTexture(record.texture)
        if indented then
            row.cells[1].spacer:SetWidth(10)
            row.cells[1].icon:SetAlpha(0.5)
            row.cells[1]:GetFontString():SetAlpha(0.7)
        else
            row.cells[1].spacer:SetWidth(1)
            row.cells[1].icon:SetAlpha(1)
            row.cells[1]:GetFontString():SetAlpha(1)
        end
        row.cells[1]:SetText(gsub(record.hyperlink, '[%[%]]', ''))
        row.cells[2]:SetText(record.level)
        if record.isFake then
            row.cells[3]:SetText(0)
            row.cells[4]:SetText("---")
            row.cells[5]:SetText("---")
            row.cells[6]:SetText("<No Auctions>")
            row.cells[7]:SetText("---")
            row.cells[8]:SetText("---")
            row.cells[9]:SetText("---")
        else
            local numAuctionsText = expandable and (Aux.gui.inline_color(Aux.gui.config.link_color2)..displayNumAuctions..'|r') or displayNumAuctions
            if numPlayerAuctions > 0 then
                numAuctionsText = numAuctionsText..(' |cffffff00('..numPlayerAuctions..')|r')
            end
            row.cells[3]:SetText(numAuctionsText)
            row.cells[4]:SetText(record.aux_quantity)
            row.cells[5]:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '---')
            row.cells[6]:SetText(Aux.is_player(record.owner) and ('|cffffff00'..record.owner..'|r') or (record.owner or '---'))
            local bid, buyout, colorBid, colorBuyout = self.GetRowPrices(record, aux_price_per_unit)
            row.cells[7]:SetText(bid > 0 and Aux.money.to_string(bid, true, false, nil, colorBid) or '---')
            row.cells[8]:SetText(buyout > 0 and Aux.money.to_string(buyout, true, false, nil, colorBuyout) or '---')
            local pct, bidPct = self:GetRecordPercent(record)
            row.cells[9]:SetText((pct or bidPct) and public.percentage_market(pct or bidPct, not pct) or '---')
        end
    end,

    SetSelectedRecord = function(self, record, silent)
        if self.disabled then return end

        -- make sure the selected record still exists and get the data for the callback
        self.selected = record
        local selectedData = self:GetSelection()
        self.selected = selectedData and self.selected or nil

        -- show / hide highlight accordingly
        for _, row in ipairs(self.rows) do
            if self.selected and row.data and row.data.record.search_signature == self.selected.search_signature then
                row.highlight:Show()
            else
                row.highlight:Hide()
            end
        end

        if not silent and self.handlers.OnSelectionChanged and not self.scrollDisabled then
            self.handlers.OnSelectionChanged(self, selectedData or nil)
        end
    end,



    -- ============================================================================
    -- General Results Table Methods
    -- ============================================================================

    Clear = function(rt)
        Aux.util.wipe(rt.expanded)
        Aux.util.wipe(rt.records)
        rt:UpdateRowInfo()
        rt:UpdateRows()
        rt:SetSelectedRecord()
    end,

    SetDatabase = function(rt, database, filterFunc, filterHash)
        if database and database ~= rt.records then
            rt.records = database
        end

--            rt.dbView:SetFilter(filterFunc, filterHash)
--        elseif filterFunc then
--            rt.dbView:SetFilter(filterFunc, filterHash) -- TODO

        -- get index of selected row
        local prevSelectedIndex
        if rt.selected then
            for index, row in ipairs(rt.rows) do
                if row:IsVisible() and row.data and row.data.record == rt.selected then
                    prevSelectedIndex = index
                end
            end
        end

        rt:UpdateRowInfo()
        rt:UpdateRows()

        if not rt.selected and prevSelectedIndex then
            -- try to select the same row
            local row = rt.rows[prevSelectedIndex]
            if row and row:IsVisible() and row.data and row.data.record then
--                TSM:LOG_INFO("Selecting row from point 1")
                rt:SetSelectedRecord(row.data.record)
            end
            if not rt.selected then
                -- select the first row
                row = rt.rows[1]
                if row and row:IsVisible() and row.data and row.data.record then
--                    TSM:LOG_INFO("Selecting row from point 1")
                    rt:SetSelectedRecord(row.data.record)
                end
            end
        end
    end,

    RemoveAuctionRecord = function(self, record)
        local index = Aux.util.index_of(record, self.records)
        if index then
            tremove(self.records, index)
        end
        self:SetDatabase()
    end,

    RemoveSelectedRecord = function(self, count)
        count = count or 1
        for i=1, count do
            local index = Aux.util.index_of(self.selected, self.records)
            if index then
                tremove(self.records, index)
            end
        end
        self:SetDatabase()
    end,

    InsertAuctionRecord = function(self, record, count)
        count = count or 1
        for i=1, count do
            tinsert(self.records, record)
        end
        self:SetDatabase()
    end,

    ContainsRecord = function(rt, record)
        if Aux.util.index_of(record, rt.records) then
            return true
        end
    end,

    SetSort = function(self, sortIndex)
        local sortIndexLookup
        if aux_price_per_unit then
            sortIndexLookup = {'name', 'level', 'numAuctions', 'aux_quantity', 'duration', 'owner', 'unit_bid_price', 'unit_buyout_price', 'percent'}
        else
            sortIndexLookup = {'name', 'level', 'numAuctions', 'aux_quantity', 'duration', 'owner', 'bid_price', 'buyout_price', 'percent'}
        end
        if sortIndex then
            if sortIndex == self.sortInfo.index then return end
            self.sortInfo.descending = sortIndex < 0
            self.sortInfo.columnIndex = abs(sortIndex)
        end
--        TSMAPI:Assert(self.sortInfo.columnIndex > 0 and self.sortInfo.columnIndex <= getn(self.headCells))
        self.sortInfo.sortKey = sortIndexLookup[self.sortInfo.columnIndex]
        self.sortInfo.isSorted = nil
        self.sortInfo.index = sortIndex
        self:UpdateRows()
    end,

    SetScrollDisabled = function(self, disabled)
        self.scrollDisabled = disabled
    end,

    SetHandler = function(self, event, handler)
        self.handlers[event] = handler
    end,

    SetDisabled = function(self, disabled)
        self.disabled = disabled
        if not disabled then
            -- if there's only one item in the result, expand it
            if getn(self.rowInfo) == 1 and self.expanded[self.rowInfo[1].expandKey] == nil then
                self.expanded[self.rowInfo[1].expandKey] = true
                self.rowInfo.numDisplayRows = getn(self.rowInfo[1].children)
            end
            self:UpdateRows()
            -- select the first row
            self:SetSelectedRecord(getn(self.rowInfo) > 0 and self.rowInfo[1].children[1].record)
        end
    end,

    GetSelection = function(self)
        if not self.selected then return end
        local selectedData
        for _, info in ipairs(self.rowInfo) do
            for _, childInfo in ipairs(info.children) do
                if childInfo.record.search_signature == self.selected.search_signature then
                    selectedData = childInfo
                    break
                end
            end
        end
        return selectedData
    end,

    GetTotalAuctions = function(self)
        local numResults = 0
        for _, info in ipairs(self.rowInfo) do
            for _, childInfo in ipairs(info.children) do
                numResults = numResults + childInfo.numAuctions
            end
        end
        return numResults
    end,
}

function public.CreateAuctionResultsTable(parent)
    local colInfo = {
        {name='Item', width=0.35},
        {name='Lvl', width=0.035, align='CENTER'},
        {name='Auctions', width=0.06, align='CENTER'},
        {name='Stack Size', width=0.055, align='CENTER'},
        {name='Time Left', width=0.04, align='CENTER'},
        {name='Seller', width=0.13, align='CENTER'},
        {name={'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'}, width=0.125, align='RIGHT', isPrice=true},
        {name={'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'}, width=0.125, align='RIGHT', isPrice=true},
        {name='% Market Value', width=0.08, align='CENTER'},
    }

    local rtName = 'AuxAuctionResultsTable'..RT_COUNT
    RT_COUNT = RT_COUNT + 1
    local rt = CreateFrame('Frame', rtName, parent)
--    local numRows = TSM.db.profile.auctionResultRows
    local numRows = 16
    rt.ROW_HEIGHT = (parent:GetHeight() - HEAD_HEIGHT-HEAD_SPACE) / numRows
    rt.scrollDisabled = nil
    rt.expanded = {}
    rt.handlers = {}
    rt.sortInfo = {}
    rt.records = {}
    rt.rowInfo = { numDisplayRows=0 }

    for name, func in pairs(methods) do
        rt[name] = func
    end

    rt:SetScript('OnShow', function()
        for i, cell in ipairs(this.headCells) do
            if cell.info.isPrice then
                cell:SetText(cell.info.name[aux_price_per_unit and 1 or 2])
            end
        end
    end)

    local contentFrame = CreateFrame('Frame', rtName..'Content', rt)
    contentFrame:SetPoint('TOPLEFT', 0, 0)
    contentFrame:SetPoint('BOTTOMRIGHT', -15, 0)
--    contentFrame:SetScript('OnSizeChanged', rt.OnContentSizeChanged)
    rt.contentFrame = contentFrame

    -- frame to hold the header columns and the rows
    local scrollFrame = CreateFrame('ScrollFrame', rtName..'ScrollFrame', rt, 'FauxScrollFrameTemplate')
    scrollFrame:SetScript('OnVerticalScroll', function()
        if not rt.scrollDisabled then
            FauxScrollFrame_OnVerticalScroll(rt.ROW_HEIGHT, function() rt:UpdateRows() end)
        end
    end)
    scrollFrame:SetAllPoints(contentFrame)
    rt.scrollFrame = scrollFrame
    FauxScrollFrame_Update(rt.scrollFrame, 0, numRows, rt.ROW_HEIGHT)

    -- make the scroll bar consistent with the TSM theme
    local scrollBar = getglobal(scrollFrame:GetName()..'ScrollBar')
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint('BOTTOMRIGHT', rt, -4, 4)
    scrollBar:SetPoint('TOPRIGHT', rt, -4, -HEAD_HEIGHT)
    scrollBar:SetWidth(10)
    local thumbTex = scrollBar:GetThumbTexture()
    thumbTex:SetPoint('CENTER', 0, 0)
    thumbTex:SetTexture(unpack(Aux.gui.config.content_color))
    thumbTex:SetHeight(150)
    thumbTex:SetWidth(scrollBar:GetWidth())
    getglobal(scrollBar:GetName()..'ScrollUpButton'):Hide()
    getglobal(scrollBar:GetName()..'ScrollDownButton'):Hide()

    -- create the header cells
    rt.headCells = {}
    for i, info in ipairs(colInfo) do
        local cell = CreateFrame('Button', rtName..'HeadCol'..i, rt.contentFrame)
        cell:SetHeight(HEAD_HEIGHT)
        if i == 1 then
            cell:SetPoint('TOPLEFT', 0, 0)
        else
            cell:SetPoint('TOPLEFT', rt.headCells[i-1], 'TOPRIGHT')
        end
        cell.info = info
        cell.rt = rt
        cell.columnIndex = i
        cell:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        cell:SetScript('OnClick', rt.OnHeadColumnClick)

        local text = cell:CreateFontString()
        text:SetJustifyH('CENTER')
        text:SetJustifyV('CENTER')
        text:SetFont(Aux.gui.config.content_font, 12)
        text:SetTextColor(unpack(Aux.gui.config.label_color.enabled))
        cell:SetFontString(text)
        if not cell.info.isPrice then cell:SetText(info.name or '') end -- TODO
        text:SetAllPoints()

        local tex = cell:CreateTexture()
        tex:SetAllPoints()
        tex:SetTexture([[Interface\AddOns\Aux-AddOn\WorldStateFinalScore-Highlight]])
        tex:SetTexCoord(0.017, 1, 0.083, 0.909)
        tex:SetAlpha(0.5)
        cell:SetNormalTexture(tex)

        local tex = cell:CreateTexture()
        tex:SetAllPoints()
        tex:SetTexture([[Interface\Buttons\UI-Listbox-Highlight]])
        tex:SetTexCoord(0.025, 0.957, 0.087, 0.931)
        tex:SetAlpha(0.2)
        cell:SetHighlightTexture(tex)

        tinsert(rt.headCells, cell)
    end

    -- create the rows
    rt.rows = {}
    for i=1, numRows do
        local row = CreateFrame('Frame', rtName..'Row'..i, rt.contentFrame)
        row:SetHeight(rt.ROW_HEIGHT)
        if i == 1 then
            row:SetPoint('TOPLEFT', 0, -(HEAD_HEIGHT + HEAD_SPACE))
            row:SetPoint('TOPRIGHT', 0, -(HEAD_HEIGHT + HEAD_SPACE))
        else
            row:SetPoint('TOPLEFT', rt.rows[i-1], 'BOTTOMLEFT')
            row:SetPoint('TOPRIGHT', rt.rows[i-1], 'BOTTOMRIGHT')
        end
        local highlight = row:CreateTexture()
        highlight:SetAllPoints()
        highlight:SetTexture(1, .9, 0, .5)
        highlight:Hide()
        row.highlight = highlight
        row.rt = rt

        row.cells = {}
        for j=1, getn(colInfo) do
            local cell = CreateFrame('Button', nil, row)
            local text = cell:CreateFontString()
            text:SetFont(Aux.gui.config.content_font, min(14, rt.ROW_HEIGHT))
            text:SetJustifyH(colInfo[j].align or 'LEFT')
            text:SetJustifyV('CENTER')
            text:SetPoint('TOPLEFT', 1, -1)
            text:SetPoint('BOTTOMRIGHT', -1, 1)
            cell:SetFontString(text)
            cell:SetHeight(rt.ROW_HEIGHT)
            cell:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
            cell:SetScript('OnEnter', rt.OnCellEnter)
            cell:SetScript('OnLeave', rt.OnCellLeave)
            cell:SetScript('OnClick', rt.OnCellClick)
            cell:SetScript('OnDoubleClick', rt.OnCellDoubleClick)
            cell.rt = rt
            cell.row = row

            if j == 1 then
                cell:SetPoint('TOPLEFT', 0, 0)
            else
                cell:SetPoint('TOPLEFT', row.cells[j-1], 'TOPRIGHT')
            end

            -- slightly different color for every alternating column
            if mod(j,2) == 1 then
                local tex = cell:CreateTexture()
                tex:SetAllPoints()
                tex:SetTexture(0.3, 0.3, 0.3, 0.2)
                cell:SetNormalTexture(tex)
            end

            -- special first column to hold spacer / item name / item icon
            if j == 1 then
                local spacer = CreateFrame('Frame', nil, cell)
                spacer:SetPoint('TOPLEFT', 0, 0)
                spacer:SetHeight(rt.ROW_HEIGHT)
                spacer:SetWidth(1)
                cell.spacer = spacer

                local iconBtn = CreateFrame('Button', nil, cell)
                iconBtn:SetBackdrop({edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=1.5})
                iconBtn:SetBackdropBorderColor(0, 1, 0, 0)
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
                cell.iconBtn = iconBtn
                cell.icon = icon

                text:ClearAllPoints()
                text:SetPoint('TOPLEFT', iconBtn, 'TOPRIGHT', 2, 0)
                text:SetPoint('BOTTOMRIGHT', 0, 0)
            end
            tinsert(row.cells, cell)
        end

        -- slightly different color for every alternating
        if mod(i,2) == 0 then
            local tex = row:CreateTexture()
            tex:SetAllPoints()
            tex:SetTexture(0.3, 0.3, 0.3, 0.3)
        end

        tinsert(rt.rows, row)
    end

    rt:SetAllPoints()
    this = contentFrame -- TODO change, maybe use for resize without scrollbar?
    arg1 = contentFrame:GetWidth()
    rt:OnContentSizeChanged()
    return rt
end