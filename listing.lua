local private, public = {}
Aux.listing = public
local RT_COUNT = 1
local HEAD_HEIGHT = 27
local HEAD_SPACE = 2
local AUCTION_PCT_COLORS = {
    {color="|cff2992ff", value=50}, -- blue
    {color="|cff16ff16", value=80}, -- green
    {color="|cffffff00", value=110}, -- yellow
    {color="|cffff9218", value=135}, -- orange
    {color="|cffff0000", value=Aux.huge}, -- red
}
local TIME_LEFT_STRINGS = {
    "|cffff000030m|r", -- Short
    "|cffff92182h|r", -- Medium
    "|cffffff0012h|r", -- Long
    "|cff2992ff48h|r", -- Very Long
}


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

--    OnIconEnter = function()
--        local rt = this:GetParent().row.rt
--        local rowData = this:GetParent().row.data
--        if rowData and rowData.record then
--            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
--            TSMAPI.Util:SafeTooltipLink(rowData.record.rawItemLink)
--            GameTooltip:Show()
--            rt.isShowingItemTooltip = true
--        end
--    end,
--
--    OnIconLeave = function()
--        GameTooltip:ClearLines()
--        GameTooltip:Hide()
--        this:GetParent().row.rt.isShowingItemTooltip = nil
--    end,

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
                GameTooltip:SetOwner(this, 'ANCHOR_NONE')
                GameTooltip:SetPoint('BOTTOMLEFT', this, 'TOPLEFT')
                GameTooltip:AddLine('Double-click to collapse this item and show only the cheapest auction.', 1, 1, 1, true)
                GameTooltip:Show()
            elseif row.data.expandable then
                GameTooltip:SetOwner(this, 'ANCHOR_NONE')
                GameTooltip:SetPoint('BOTTOMLEFT', this, 'TOPLEFT')
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
        if not this.rt.selected or this.rt.selected.hash2 ~= this.row.data.record.hash2 then
            this.row.highlight:Hide()
        end
    end,

    OnCellClick = function()
        local button = arg1
        if this.rt.disabled then return end
        this.rt:SetSelectedRecord(this.row.data.record)
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

    -- default functions which will be overridden
    GetMarketValue = function(itemString) return end,
--    GetRowPrices = function(record, isPerUnit) return end, -- TODO
    GetRowPrices = function(record, isPerUnit)
        return record.bid_price, record.buyout_price
    end,


    GetRecordPercent = function(rt, record)
        if not record then return end
        -- cache the market value on the record
--        record.marketValue = record.marketValue or rt.GetMarketValue(record.item_key) or 0
--        if record.marketValue > 0 then
--            if record.itemBuyout > 0 then
--                return Aux.round(100 * record.itemBuyout / record.marketValue, 1)
--            end
--            return nil, Aux.round(100 * record.itemDisplayedBid / record.marketValue, 1)
--        end
    end,

    UpdateRowInfo = function(rt)
        Aux.util.wipe(rt.rowInfo)
        rt.rowInfo.numDisplayRows = 0
        rt.sortInfo.isSorted = nil
        rt:SetSelectedRecord(nil, true)

        local function search_signature(record)
            return Aux.util.join({record.item_key, record.buyout_price, record.bid_price, record.aux_quantity, record.duration, record.owner}, ':')
        end

        sort(rt.records, function(a,b) return search_signature(a) < search_signature(b) end)

        local records = rt.records
        if getn(records) == 0 then return end

        -- Populate the row info from the database by combining identical auctions and auctions
        -- of the same base item. Also, get the number of rows which will be shown.
        for i=1, getn(records) do
            local record = records[i]
            local prevRecord = records[i-1]
            if prevRecord and search_signature(record) == search_signature(prevRecord) then
                -- it's an identical auction to the previous row so increment the number of auctions
                rt.rowInfo[getn(rt.rowInfo)].children[getn(rt.rowInfo[getn(rt.rowInfo)].children)].numAuctions = rt.rowInfo[getn(rt.rowInfo)].children[getn(rt.rowInfo[getn(rt.rowInfo)].children)].numAuctions + 1
            elseif prevRecord and record.item_key == prevRecord.item_key then
                -- it's the same base item as the previous row so insert a new auction
                tinsert(rt.rowInfo[getn(rt.rowInfo)].children, {numAuctions=1, record=record})
                if rt.expanded[rt.rowInfo[getn(rt.rowInfo)].expandKey] then
                    rt.rowInfo.numDisplayRows = rt.rowInfo.numDisplayRows + 1
                end
            else
                -- it's a different base item from the previous row
                tinsert(rt.rowInfo, {item_key=record.item_key, expandKey=record.item_key, children={{numAuctions=1, record=record}}})
                rt.rowInfo.numDisplayRows = rt.rowInfo.numDisplayRows + 1
            end
        end

        for _, info in ipairs(rt.rowInfo) do
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

    UpdateRows = function(rt)
        -- hide all the rows
        for _, row in ipairs(rt.rows) do row:Hide() end

        -- update sorting highlights
        for _, cell in ipairs(rt.headCells) do
            local tex = cell:GetNormalTexture()
            tex:SetTexture([[Interface\AddOns\Aux-AddOn\WorldStateFinalScore-Highlight]])
            tex:SetTexCoord(0.017, 1, 0.083, 0.909)
            tex:SetAlpha(0.5)
        end
        if rt.sortInfo.descending then
            rt.headCells[rt.sortInfo.columnIndex]:GetNormalTexture():SetTexture(0.8, 0.6, 1, 0.8)
        else
            rt.headCells[rt.sortInfo.columnIndex]:GetNormalTexture():SetTexture(0.6, 0.8, 1, 0.8)
        end

        -- update the scroll frame
        FauxScrollFrame_Update(rt.scrollFrame, rt.rowInfo.numDisplayRows, getn(rt.rows), rt.ROW_HEIGHT)

        -- make sure the offset is not too high
        local maxOffset = max(rt.rowInfo.numDisplayRows - getn(rt.rows), 0)
        if FauxScrollFrame_GetOffset(rt.scrollFrame) > maxOffset then
            FauxScrollFrame_SetOffset(rt.scrollFrame, maxOffset)
        end

        if not rt.sortInfo.isSorted then
            local function SortHelperFunc(a, b, sortKey)
                local hadSortKey = sortKey and true or false
                sortKey = sortKey or rt.sortInfo.sortKey
                local aVal, bVal
                if a.children then
                    aVal = a.children[1].record
                    bVal = b.children[1].record
                else
                    aVal = a.record
                    bVal = b.record
                end
                if aVal.isFake then
                    return true
                elseif bVal.isFake then
                    return false
                end
                if sortKey == "percent" then
                    aVal = rt:GetRecordPercent(aVal)
                    bVal = rt:GetRecordPercent(bVal)
                elseif sortKey == "numAuctions" then
                    aVal = a.totalAuctions
                    bVal = b.totalAuctions
                elseif sortKey == "itemDisplayedBid" or sortKey == "displayedBid" then
                    aVal = rt.GetRowPrices(aVal, sortKey == "itemDisplayedBid")
                    bVal = rt.GetRowPrices(bVal, sortKey == "itemDisplayedBid")
                elseif sortKey == "itemBuyout" or sortKey == "buyout" then
                    aVal = ({ rt.GetRowPrices(aVal, sortKey == "itemBuyout") })[2]
                    bVal = ({ rt.GetRowPrices(bVal, sortKey == "itemBuyout") })[2]
                else
                    aVal = aVal[sortKey]
                    bVal = bVal[sortKey]
                end
                if sortKey == "buyout" or sortKey == "itemBuyout" then
                    -- for buyout, put bid-only auctions at the bottom
                    if not aVal or aVal == 0 then
                        aVal = (rt.sortInfo.descending and -1 or 1) * Aux.huge
                    end
                    if not bVal or bVal == 0 then
                        bVal = (rt.sortInfo.descending and -1 or 1) * Aux.huge
                    end
                elseif sortKey == "percent" then
                    -- for percent, put bid-only auctions at the bottom
                    aVal = aVal or ((rt.sortInfo.descending and -1 or 1) * Aux.huge)
                    bVal = bVal or ((rt.sortInfo.descending and -1 or 1) * Aux.huge)
                end
                if type(aVal) == "string" or type(bVal) == "string" then
                    aVal = aVal or ""
                    bVal = bVal or ""
                else
                    aVal = tonumber(aVal) or 0
                    bVal = tonumber(bVal) or 0
                end
                if aVal == bVal then
                    if sortKey == "percent" then
                        -- sort by buyout
                        sortKey = aux_price_per_unit and "itemBuyout" or "buyout"
                        local result = SortHelperFunc(a, b, sortKey)
                        if result ~= nil then
                            return result
                        end
                    elseif sortKey == "buyout" or sortKey == "itemBuyout" then
                        -- sort by bid
                        sortKey = aux_price_per_unit and "itemDisplayedBid" or "displayedBid"
                        local result = SortHelperFunc(a, b, sortKey)
                        if result ~= nil then
                            return result
                        end
                    elseif hadSortKey then
                        -- this was called recursively, so just return nil
                        return
                    else
                        -- sort by percent
                        return SortHelperFunc(a, b, "percent")
                    end
                    -- sort arbitrarily, but make sure the sort is stable
                    return tostring(a) < tostring(b)
                end
                if rt.sortInfo.descending then
                    return aVal > bVal
                else
                    return aVal < bVal
                end
            end
            -- sort the row info
            for i, info in ipairs(rt.rowInfo) do
                sort(info.children, SortHelperFunc)
            end
            sort(rt.rowInfo, SortHelperFunc)
            rt.sortInfo.isSorted = true
        end

        -- update all the rows
        local rowIndex = 1 - FauxScrollFrame_GetOffset(rt.scrollFrame)
        for i, info in ipairs(rt.rowInfo) do
            if rt.expanded[info.expandKey] then
                -- show each of the rows for this base item since it's expanded
                for j, childInfo in ipairs(info.children) do
                    rt:SetRowInfo(rowIndex, childInfo.record, childInfo.numAuctions, 0, j > 1, false, info.expandKey, childInfo.numAuctions)
                    rowIndex = rowIndex + 1
                end
            else
                -- just show one row for this base item since it's not expanded
                rt:SetRowInfo(rowIndex, info.children[1].record, info.totalAuctions, getn(info.children) > 1 and info.totalPlayerAuctions or 0, false, getn(info.children) > 1, info.expandKey, info.children[1].numAuctions)
                rowIndex = rowIndex + 1
            end
        end
    end,

    SetRowInfo = function(rt, rowIndex, record, displayNumAuctions, numPlayerAuctions, indented, expandable, expandKey, numAuctions)
        if rowIndex <= 0 or rowIndex > getn(rt.rows) then return end
        local row = rt.rows[rowIndex]
        -- show this row
        row:Show()
        if rt.selected and record.hash2 == rt.selected.hash2 then
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
        row.cells[1]:SetText(gsub(record.hyperlink, "[%[%]]", ""))
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
            local numAuctionsText = expandable and (Aux.gui.inline_color(Aux.gui.config.link_color2)..displayNumAuctions.."|r") or displayNumAuctions
            if numPlayerAuctions > 0 then
                numAuctionsText = numAuctionsText..(" |cffffff00("..numPlayerAuctions..")|r")
            end
            row.cells[3]:SetText(numAuctionsText)
            row.cells[4]:SetText(record.aux_quantity)
            row.cells[5]:SetText(TIME_LEFT_STRINGS[record.duration or 0] or "---")
            row.cells[6]:SetText(Aux.is_player(record.owner) and ("|cffffff00"..record.owner.."|r") or record.owner)
            local bid, buyout, colorBid, colorBuyout = rt.GetRowPrices(record, aux_price_per_unit)
            row.cells[7]:SetText(bid > 0 and Aux.money.to_string(bid, true, false, colorBid) or "---")
            row.cells[8]:SetText(buyout > 0 and Aux.money.to_string(buyout, true, false, colorBuyout) or "---")
            local pct, bidPct = rt:GetRecordPercent(record)
            local pctColor = "|cffffffff"
            if pct then
                for i=1, getn(AUCTION_PCT_COLORS) do
                    if pct < AUCTION_PCT_COLORS[i].value then
                        pctColor = AUCTION_PCT_COLORS[i].color
                        break
                    end
                end
            elseif bidPct then
                pctColor = "|cffbbbbbb"
                pct = bidPct
            end
            if pct and pct > 10000 then
                pct = ">10000"
            end
            row.cells[9]:SetText(pct and format("%s%s%%|r", pctColor, pct) or "---")
        end
    end,

    SetSelectedRecord = function(rt, record, silent)
        if rt.disabled then return end

        -- make sure the selected record still exists and get the data for the callback
        rt.selected = record
        local selectedData = rt:GetSelection()
        rt.selected = selectedData and rt.selected or nil

        -- show / hide highlight accordingly
        for _, row in ipairs(rt.rows) do
            if rt.selected and row.data and row.data.record.hash2 == rt.selected.hash2 then
                row.highlight:Show()
            else
                row.highlight:Hide()
            end
        end

        if not silent and rt.handlers.OnSelectionChanged and not rt.scrollDisabled then
            rt.handlers.OnSelectionChanged(rt, selectedData or nil)
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
        local prevSelectedIndex = nil
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

    RemoveSelectedRecord = function(rt, count)
--        TSMAPI:Assert(rt.selected)
        count = count or 1
        for i=1, count do
            local index = Aux.util.index_of(rt.selected, rt.records)
            if index then
                tremove(rt.records, index)
            end
        end
        rt:SetDatabase()
    end,

    InsertAuctionRecord = function(rt, record, count)
        count = count or 1
        for i=1, count do
            tinsert(rt.records, record)
        end
        rt:SetDatabase()
    end,

    SetSort = function(rt, sortIndex)
        local sortIndexLookup
        if aux_price_per_unit then
            sortIndexLookup = {"name", "itemLevel", "numAuctions", "stackSize", "timeLeft", "seller", "itemDisplayedBid", "itemBuyout", "percent"}
        else
            sortIndexLookup = {"name", "itemLevel", "numAuctions", "stackSize", "timeLeft", "seller", "displayedBid", "buyout", "percent"}
        end
        if sortIndex then
            if sortIndex == rt.sortInfo.index then return end
            rt.sortInfo.descending = sortIndex < 0
            rt.sortInfo.columnIndex = abs(sortIndex)
        end
--        TSMAPI:Assert(rt.sortInfo.columnIndex > 0 and rt.sortInfo.columnIndex <= getn(rt.headCells))
        rt.sortInfo.sortKey = sortIndexLookup[rt.sortInfo.columnIndex]
        rt.sortInfo.isSorted = nil
        rt.sortInfo.index = sortIndex
        rt:UpdateRows()
    end,

    SetScrollDisabled = function(rt, disabled)
        rt.scrollDisabled = disabled
    end,

    SetHandler = function(rt, event, handler)
--        TSMAPI:Assert(event == "OnSelectionChanged")
        rt.handlers[event] = handler
    end,

    SetPriceInfo = function(rt, info)
        -- update the header text
        rt.headCells[7].info.name = info.headers[1]
        rt.headCells[8].info.name = info.headers[2]
        rt.headCells[9].info.name = info.pctHeader
        for i=7, 9 do
            if rt.headCells[i].info.isPrice then
                rt.headCells[i]:SetText(rt.headCells[i].info.name[aux_price_per_unit and 1 or 2])
            else
                rt.headCells[i]:SetText(rt.headCells[i].info.name)
            end
        end
        rt.GetRowPrices = info.GetRowPrices
        rt.GetMarketValue = info.GetMarketValue
    end,

    SetDisabled = function(rt, disabled)
        rt.disabled = disabled
        if not disabled then
            -- if there's only one item in the result, expand it
            if getn(rt.rowInfo) == 1 and rt.expanded[rt.rowInfo[1].expandKey] == nil then
                rt.expanded[rt.rowInfo[1].expandKey] = true
                rt.rowInfo.numDisplayRows = getn(rt.rowInfo[1].children)
            end
            rt:UpdateRows()
            -- select the first row
            rt:SetSelectedRecord(getn(rt.rowInfo) > 0 and rt.rowInfo[1].children[1].record)
        end
    end,

    GetSelection = function(rt)
        if not rt.selected then return end
        local selectedData = nil
        for i, info in ipairs(rt.rowInfo) do
            if rt.expanded[info.expandKey] then
                for _, childInfo in ipairs(info.children) do
                    if childInfo.record.hash2 == rt.selected.hash2 then
                        selectedData = childInfo
                        break
                    end
                end
                if selectedData then break end
            elseif info.children[1].record.hash2 == rt.selected.hash2 then
                selectedData = info.children[1]
                break
            end
        end
        return selectedData
    end,

    GetTotalAuctions = function(rt)
        local numResults = 0
        for _, info in ipairs(rt.rowInfo) do
            for _, childInfo in ipairs(info.children) do
                numResults = numResults + childInfo.numAuctions
            end
        end
        return numResults
    end,
}

function CreateAuctionResultsTable(parent)
    local colInfo = {
        {name="Item", width=0.35},
        {name="Lvl", width=0.035, align="CENTER"},
        {name="Auctions", width=0.06, align="CENTER"},
        {name="Stack Size", width=0.055, align="CENTER"},
        {name='Time Left', width=0.04, align="CENTER"},
        {name='Seller', width=0.13, align="CENTER"},
        {name={"??", "??"}, width=0.125, align="RIGHT", isPrice=true},
        {name={"??", "??"}, width=0.125, align="RIGHT", isPrice=true},
        {name="", width=0.08, align="CENTER"},
    }

    local rtName = 'TSMAuctionResultsTable'..RT_COUNT
    RT_COUNT = RT_COUNT + 1
    local rt = CreateFrame('Frame', rtName, parent)
--    local numRows = TSM.db.profile.auctionResultRows
    local numRows = 10
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
--                cell:SetText(cell.info.name[TSM.db.profile.pricePerUnit and 1 or 2])
                cell:SetText(cell.info.name[2])
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
    scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
        if not rt.scrollDisabled then
            FauxScrollFrame_OnVerticalScroll(self, offset, rt.ROW_HEIGHT, function() rt:UpdateRows() end)
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
--    TSMAPI.Design:SetContentColor(thumbTex)
    thumbTex:SetHeight(150)
    thumbTex:SetWidth(scrollBar:GetWidth())
    getglobal(scrollBar:GetName()..'ScrollUpButton'):Hide()
    getglobal(scrollBar:GetName()..'ScrollDownButton'):Hide()

    -- create the header cells
    rt.headCells = {}
    for i, info in ipairs(colInfo) do
        snipe.log(i)
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
            text:SetJustifyV('MIDDLE')
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
    this = contentFrame -- TODO hack
    arg1 = contentFrame:GetWidth() -- TODO hack
    rt:OnContentSizeChanged() -- TODO hack
    return rt
end