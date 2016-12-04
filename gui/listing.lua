module 'aux.gui.listing'

include 'T'
include 'aux'

local gui = require 'aux.gui'

local ST_COUNT = 0

local ST_ROW_HEIGHT = 15
local ST_ROW_TEXT_SIZE = 14
local ST_HEAD_HEIGHT = 27
local ST_HEAD_SPACE = 2
local DEFAULT_COL_INFO = {{width=1}}

local handlers = {
    OnEnter = function()
        this.row.mouseover = true
        if not this.row.data then return end
        if not this.st.highlightDisabled then
            this.row.highlight:Show()
        end

        local handler = this.st.handlers.OnEnter
        if handler then
            handler(this.st, this.row.data, this)
        end
    end,

    OnLeave = function()
        this.row.mouseover = false
        if not this.row.data then return end
        if this.st.selectionDisabled or not this.st.selected or this.st.selected ~= key(this.st.rowData, this.row.data) then
            this.row.highlight:Hide()
        end

        local handler = this.st.handlers.OnLeave
        if handler then
            handler(this.st, this.row.data, this)
        end
    end,

    OnMouseDown = function()
        if not this.row.data then return end
        this.st:ClearSelection()
        this.st.selected = key(this.st.rowData, this.row.data)
        this.row.highlight:Show()

        local handler = this.st.handlers.OnClick
        if handler then
            handler(this.st, this.row.data, this, arg1)
        end
    end,
}

local methods = {
    Update = function(self)
	    if getn(self.colInfo) > 1 or self.colInfo[1].name then
		    self.sizes.headHeight = ST_HEAD_HEIGHT
	    else
		    self.sizes.headHeight = 0
	    end
	    self.sizes.numRows = max(floor((self:GetParent():GetHeight() - self.sizes.headHeight - ST_HEAD_SPACE) / ST_ROW_HEIGHT), 0)

	    self.scrollBar:ClearAllPoints()
	    self.scrollBar:SetPoint('BOTTOMRIGHT', self, -1, 1)
	    self.scrollBar:SetPoint('TOPRIGHT', self, -1, -self.sizes.headHeight - ST_HEAD_SPACE - 1)

	    if getn(self.rowData or empty) > self.sizes.numRows then
		    self.contentFrame:SetPoint('BOTTOMRIGHT', -15, 0)
	    else
		    self.contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
	    end

	    local width = self.contentFrame:GetRight() - self.contentFrame:GetLeft()

	    while getn(self.headCols) < getn(self.colInfo) do
		    self:AddColumn()
	    end

	    for i, col in self.headCols do
		    if self.colInfo[i] then
			    col:Show()
			    col:SetWidth(self.colInfo[i].width * width)
			    col:SetHeight(self.sizes.headHeight)
			    col.text:SetText(self.colInfo[i].name or '')
			    col.text:SetJustifyH(self.colInfo[i].headAlign or 'CENTER')
		    else
			    col:Hide()
		    end
	    end

	    while getn(self.rows) < self.sizes.numRows do
		    self:AddRow()
	    end

	    for i, row in self.rows do
		    if i > self.sizes.numRows then
			    row.data = nil
			    row:Hide()
		    else
			    row:Show()
			    while getn(row.cols) < getn(self.colInfo) do
				    self:AddRowCol(i)
			    end
			    for j, col in row.cols do
				    if self.headCols[j] and self.colInfo[j] then
					    col:Show()
					    col:SetWidth(self.colInfo[j].width * width)
					    col.text:SetJustifyH(self.colInfo[j].align or 'LEFT')
				    else
					    col:Hide()
				    end
			    end
		    end
	    end
	    
        if not self.rowData then return end
        FauxScrollFrame_Update(self.scrollFrame, getn(self.rowData), self.sizes.numRows, ST_ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
        self.offset = offset

        for i = 1, self.sizes.numRows do
            self.rows[i].data = nil
            if i > getn(self.rowData) then
                self.rows[i]:Hide()
            else
                self.rows[i]:Show()
                local data = self.rowData[i + offset]
                if not data then break end
                self.rows[i].data = data

                if (self.selected == key(self.rowData, data) and not self.selectionDisabled)
                        or (self.highlighted and self.highlighted == key(self.rowData, data))
                        or self.rows[i].mouseover
                then
                    self.rows[i].highlight:Show()
                else
                    self.rows[i].highlight:Hide()
                end

                for j, col in self.rows[i].cols do
                    if self.colInfo[j] then
                        local colData = data.cols[j]
                        if type(colData.value) == 'function' then
	                        col.text:SetText(colData.value(unpack(colData.args)))
                        else
                            col.text:SetText(colData.value)
                        end
                    end
                end
            end
        end
    end,

    SetData = function(self, rowData)
	    for _, row in self.rowData or empty do
		    for _, col in row.cols do release(col) end
		    release(row.cols)
		    release(row)
	    end
        self.rowData = rowData
        self.updateSort = true
        self:Update()
    end,

    SetSelection = function(self, predicate)
        self:ClearSelection()
        for i, rowDatum in self.rowData do
            if predicate(rowDatum) then
                    self.selected = i
                    self:Update()
                break
            end
        end
    end,

    GetSelection = function(self)
        return self.selected
    end,

    ClearSelection = function(self)
        self.selected = nil
        self:Update()
    end,

    DisableSelection = function(self, value)
        self.selectionDisabled = value
    end,

    AddColumn = function(self)
        local colNum = getn(self.headCols) + 1
        local col = CreateFrame('Frame', self:GetName() .. 'HeadCol' .. colNum, self.contentFrame)
        if colNum == 1 then
            col:SetPoint('TOPLEFT', 0, 0)
        else
            col:SetPoint('TOPLEFT', self.headCols[colNum - 1], 'TOPRIGHT')
        end
        col.st = self
        col.colNum = colNum

	    local text = col:CreateFontString()
	    text:SetAllPoints()
	    text:SetFont(gui.font, 12)
	    text:SetTextColor(color.label.enabled())
        col.text = text

	    local tex = col:CreateTexture()
	    tex:SetAllPoints()
	    tex:SetTexture([[Interface\AddOns\aux-AddOn\WorldStateFinalScore-Highlight]])
	    tex:SetTexCoord(.017, 1, .083, .909)
	    tex:SetAlpha(.5)

        tinsert(self.headCols, col)

        -- add new cells to the rows
        for i, row in self.rows do
            while getn(row.cols) < getn(self.headCols) do
                self:AddRowCol(i)
            end
        end
    end,

    AddRowCol = function(self, rowNum)
        local row = self.rows[rowNum]
        local colNum = getn(row.cols) + 1
        local col = CreateFrame('Frame', nil, row)
        local text = col:CreateFontString()
        col.text = text
        text:SetFont(gui.font, ST_ROW_TEXT_SIZE)
        text:SetJustifyV('CENTER')
        text:SetPoint('TOPLEFT', 1, -1)
        text:SetPoint('BOTTOMRIGHT', -1, 1)
        col:SetHeight(ST_ROW_HEIGHT)
        col:EnableMouse(true)
        for name, func in handlers do
            col:SetScript(name, func)
        end
        col.st = self
        col.row = row

        if colNum == 1 then
            col:SetPoint('TOPLEFT', 0, 0)
        else
            col:SetPoint('TOPLEFT', row.cols[colNum - 1], 'TOPRIGHT')
        end
        tinsert(row.cols, col)
    end,

    AddRow = function(self)
        local row = CreateFrame('Frame', nil, self.contentFrame)
        row:SetHeight(ST_ROW_HEIGHT)
        local rowNum = getn(self.rows) + 1
        if rowNum == 1 then
            row:SetPoint('TOPLEFT', 2, -(self.sizes.headHeight + ST_HEAD_SPACE))
            row:SetPoint('TOPRIGHT', 0, -(self.sizes.headHeight + ST_HEAD_SPACE))
        else
            row:SetPoint('TOPLEFT', 2, -(self.sizes.headHeight + ST_HEAD_SPACE + (rowNum - 1) * ST_ROW_HEIGHT))
            row:SetPoint('TOPRIGHT', 0, -(self.sizes.headHeight + ST_HEAD_SPACE + (rowNum - 1) * ST_ROW_HEIGHT))
        end
        local highlight = row:CreateTexture()
        highlight:SetAllPoints()
        highlight:SetTexture(1, .9, .9, .1)
        highlight:Hide()
        row.highlight = highlight
        row.st = self

        row.cols = T
        self.rows[rowNum] = row
        for i = 1, getn(self.colInfo) do
            self:AddRowCol(rowNum)
        end
    end,

    SetHandler = function(st, event, handler)
        st.handlers[event] = handler
    end,

    SetColInfo = function(st, colInfo)
        colInfo = colInfo or DEFAULT_COL_INFO
        st.colInfo = colInfo
        st:Update()
    end,
}

function M.new(parent)
    ST_COUNT = ST_COUNT + 1
    local st = CreateFrame('Frame', 'TSMScrollingTable' .. ST_COUNT, parent)
    st:SetAllPoints()

    local contentFrame = CreateFrame('Frame', nil, st)
    contentFrame:SetPoint('TOPLEFT', 0, 0)
    contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
    st.contentFrame = contentFrame

    local scrollFrame = CreateFrame('ScrollFrame', st:GetName() .. 'ScrollFrame', st, 'FauxScrollFrameTemplate')
    scrollFrame:SetScript('OnVerticalScroll', function()
        FauxScrollFrame_OnVerticalScroll(ST_ROW_HEIGHT, function() st:Update() end)
    end)
    scrollFrame:SetAllPoints(contentFrame)
    st.scrollFrame = scrollFrame

    local scrollBar = _G[scrollFrame:GetName() .. 'ScrollBar']
    scrollBar:SetWidth(12)
    st.scrollBar = scrollBar
    local thumbTex = scrollBar:GetThumbTexture()
    thumbTex:SetPoint('CENTER', 0, 0)
    thumbTex:SetTexture(color.content.background())
    thumbTex:SetHeight(50)
    thumbTex:SetWidth(12)
    _G[scrollBar:GetName() .. 'ScrollUpButton']:Hide()
    _G[scrollBar:GetName() .. 'ScrollDownButton']:Hide()

    for name, func in methods do
        st[name] = func
    end

    st.isTSMScrollingTable = true
    st.sizes = T
    st.headCols = T
    st.rows = T
    st.handlers = T
    st.colInfo = DEFAULT_COL_INFO

    return st
end